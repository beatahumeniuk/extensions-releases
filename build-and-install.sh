#!/usr/bin/env bash

set -uo pipefail

# Windows/Git Bash: node.exe nie rozumie sciezek MSYS (/c/...), wiec pod
# Windowsem bierzemy sciezke w stylu C:/... ktora rozumie i bash, i node.
ROOT="$(cd "$(dirname "$0")" && { pwd -W 2>/dev/null || pwd; })"

# npm gada z rejestrem przy kazdym wywolaniu: audyt, zbiorka na open source
# i sprawdzanie nowej wersji npm. Przy kilkunastu wywolaniach npm/npx w jednym
# przebiegu to minuty czekania, a zadna z tych rzeczy nie jest nam potrzebna.
# Ustawione przez srodowisko, wiec dziedziczy to takze npm odpalony z npm run.
export npm_config_audit=false
export npm_config_fund=false
export npm_config_update_notifier=false
export npm_config_prefer_offline=true

# Ile rozszerzen budujemy naraz. Budowy sa niezalezne (osobne katalogi, osobne
# node_modules), wiec czekanie na siec przy jednym nakłada sie na prace innych.
# Domyslnie liczba rdzeni, ale nie wiecej niz 4 — powyzej npm zaczyna sie bic
# o dysk i o ten sam cache, i robi sie wolniej zamiast szybciej.
default_jobs() {
  local n
  n="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
  [[ "$n" =~ ^[0-9]+$ ]] || n=4
  (( n > 4 )) && n=4
  (( n < 1 )) && n=1
  echo "$n"
}
JOBS="${JOBS:-$(default_jobs)}"

# Skad brac gotowe paczki w trybie domyslnym. To osobne, publiczne repozytorium
# z samymi paczkami — zrodla moga byc prywatne, a pobieranie i tak idzie zwyklym
# HTTPS, bez tokena i bez logowania.
REPO="${REPO:-beatahumeniuk/extensions-releases}"
TAG="${TAG:-latest-build}"

usage() {
  cat <<'EOF'
build-and-install.sh [--build] [nazwa ...]

Bez --build: pobiera gotowe paczki .vsix zbudowane przez CI z ostatniego
merge do main i instaluje je w VS Code. Nie wymaga Node.js ani npm.

Z --build: buduje rozszerzenia lokalnie z zrodel w tym katalogu, a potem
instaluje. Do pracy nad kodem rozszerzenia.

Bez nazw obejmuje wszystkie rozszerzenia; nazwy zawezaja do wskazanych.

Zmienne srodowiskowe:
  FORCE=1         przebuduj/zainstaluj mimo braku zmian
  SKIP_INSTALL=1  zbuduj, ale nie instaluj w edytorze (tylko --build)
  JOBS=n          ile rozszerzen budowac naraz (tylko --build)
  EDITOR_CLI=...  sciezka do CLI VS Code, gdy autowykrywanie zawiedzie
  REPO=, TAG=     skad pobierac gotowe paczki
EOF
}

MODE=download
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --build)      MODE=build ;;
    --download)   MODE=download ;;
    -h|--help)    usage; exit 0 ;;
    -*)           echo "Nieznana opcja: $arg" >&2; usage >&2; exit 2 ;;
    *)            ARGS+=("$arg") ;;
  esac
done
if [[ ${#ARGS[@]} -gt 0 ]]; then set -- "${ARGS[@]}"; else set --; fi

EDITOR_CLI="${EDITOR_CLI:-}"
if [[ -z "$EDITOR_CLI" ]]; then
  for c in \
    "${LOCALAPPDATA:-}/Programs/Microsoft VS Code/bin/code.cmd" \
    "${PROGRAMFILES:-}/Microsoft VS Code/bin/code.cmd" \
    "/c/Program Files/Microsoft VS Code/bin/code.cmd" \
    "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
    "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"; do
    [[ -f "$c" ]] && EDITOR_CLI="$c" && break
  done
  if [[ -z "$EDITOR_CLI" ]] && command -v code >/dev/null 2>&1; then
    EDITOR_CLI=code
  fi
  if [[ -z "$EDITOR_CLI" ]]; then
    echo "Nie znaleziono CLI VS Code. Ustaw EDITOR_CLI=..." >&2
    exit 1
  fi
fi

# ── Tryb domyslny: pobranie gotowych paczek z release'u ─────────────────────
# CI buduje wszystkie rozszerzenia po kazdym merge do main i doczepia je do
# rolujacego release'u pod stalymi nazwami, wiec adresy sie nie zmieniaja.
# Wersje jada obok, w versions.txt, zeby dalo sie pominac to, co juz aktualne.

fetch_to_stdout() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$1"
  else
    echo "Potrzebny curl albo wget do pobrania paczek." >&2
    return 1
  fi
}

fetch_to_file() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$2" "$1"
  else
    wget -qO "$2" "$1"
  fi
}

download_and_install() {
  local base="${BASE_URL:-https://github.com/$REPO/releases/download/$TAG}"
  local manifest installed tmp rc=0
  local name id ver asset have

  echo "Pobieram listę wersji z release'u '$TAG'..."
  manifest="$(fetch_to_stdout "$base/versions.txt")" || {
    echo "✗ Nie udało się pobrać $base/versions.txt" >&2
    return 1
  }
  [[ -n "$manifest" ]] || { echo "✗ Release '$TAG' nie zawiera żadnych paczek." >&2; return 1; }

  installed=""
  if [[ "${FORCE:-0}" != "1" ]]; then
    installed="$("$EDITOR_CLI" --list-extensions --show-versions 2>/dev/null | tr -d '\r' || true)"
  fi

  tmp="$(mktemp -d)"
  local OKD=() SKIPD=() FAILD=()

  while IFS='|' read -r name id ver asset; do
    [[ -n "${name:-}" && -n "${asset:-}" ]] || continue

    # Nazwy podane w argumentach zawezaja liste.
    if [[ $# -gt 0 ]]; then
      local wanted=0 a
      for a in "$@"; do [[ "$a" == "$name" ]] && wanted=1; done
      (( wanted )) || continue
    fi

    if [[ -n "$installed" ]] && grep -qixF "$id@$ver" <<<"$installed"; then
      echo "· $name $ver — już aktualne"
      SKIPD+=("$name $ver")
      continue
    fi

    have="$(grep -i "^$id@" <<<"$installed" | head -1 || true)"
    if [[ -n "$have" ]]; then
      echo "▶ $name: ${have#*@} → $ver"
    else
      echo "▶ $name: nowe, $ver"
    fi

    if ! fetch_to_file "$base/$asset" "$tmp/$asset"; then
      echo "  ✗ pobieranie nie powiodło się" >&2
      FAILD+=("$name (pobieranie)")
      continue
    fi

    if "$EDITOR_CLI" --install-extension "$tmp/$asset" --force; then
      OKD+=("$name $ver")
    else
      FAILD+=("$name (instalacja)")
    fi
  done <<<"$manifest"

  rm -rf "$tmp"

  echo ""
  echo "══════════════ PODSUMOWANIE ══════════════"
  for line in "${OKD[@]:-}";    do [[ -n "$line" ]] && echo "  ✓ $line"; done
  for line in "${SKIPD[@]:-}";  do [[ -n "$line" ]] && echo "  · $line — bez zmian"; done
  for line in "${FAILD[@]:-}";  do [[ -n "$line" ]] && echo "  ✗ $line"; done
  [[ ${#OKD[@]} -eq 0 ]] || echo "
Przeładuj okno VS Code (Ctrl+Shift+P → Developer: Reload Window)."
  [[ ${#FAILD[@]} -eq 0 ]] || rc=1
  return $rc
}

if [[ "$MODE" == "download" ]]; then
  download_and_install "$@"
  exit $?
fi

manifest_for() {
  local pkg
  for pkg in "$1/package.json" "$1"/*/package.json; do
    [[ -f "$pkg" ]] || continue
    [[ "$pkg" == */node_modules/* ]] && continue
    if node -e "const p=require('$pkg');process.exit(p.publisher&&p.version?0:1)" 2>/dev/null; then
      echo "$pkg"
      return 0
    fi
  done
  return 1
}

# Odcisk zrodel rozszerzenia: liczy sie zawartosc plikow, a nie numer wersji,
# wiec rozszerzenie bez zmian jest pomijane nawet bez podbicia wersji.
# Pomijane sa katalogi wytworcze (node_modules, dist, out) i same paczki .vsix.
CACHE="$ROOT/.build-cache"

source_hash() {
  node -e '
    const fs = require("fs"), path = require("path"), crypto = require("crypto");
    const root = process.argv[1];
    const skipDirs = new Set(["node_modules", ".git", "dist", "out", ".vscode-test"]);
    const files = [];
    (function walk(d) {
      let entries;
      try { entries = fs.readdirSync(d, { withFileTypes: true }); } catch { return; }
      for (const e of entries) {
        if (e.isDirectory()) { if (!skipDirs.has(e.name)) walk(path.join(d, e.name)); }
        else if (!e.name.endsWith(".vsix")) files.push(path.join(d, e.name));
      }
    })(root);
    files.sort();
    const h = crypto.createHash("sha1");
    for (const f of files) {
      h.update(path.relative(root, f).replace(/\\/g, "/"));
      h.update(fs.readFileSync(f));
    }
    console.log(h.digest("hex"));
  ' "$1"
}

INSTALLED=""
if [[ "${FORCE:-0}" != "1" && "${SKIP_INSTALL:-0}" != "1" ]]; then
  INSTALLED="$("$EDITOR_CLI" --list-extensions --show-versions 2>/dev/null | tr -d '\r' || true)"
  if [[ -z "$INSTALLED" ]]; then
    echo "! Nie udalo sie odczytac listy zainstalowanych rozszerzen z: $EDITOR_CLI" >&2
    echo "  (pomijanie oprze sie wylacznie na zmianach w plikach)" >&2
  fi
fi

if [[ $# -gt 0 ]]; then
  DIRS=("$@")
else
  # Jedno wywolanie node na cale repo zamiast jednego na katalog.
  DIRS=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && DIRS+=("$line")
  done < <(node -e '
    const fs = require("fs"), path = require("path");
    const root = process.argv[1];
    for (const e of fs.readdirSync(root, { withFileTypes: true })) {
      if (!e.isDirectory() || e.name.startsWith(".") || e.name === "node_modules") continue;
      try {
        const p = require(path.join(root, e.name, "package.json"));
        if (p.scripts && p.scripts.package) console.log(e.name);
      } catch {}
    }
  ' "$ROOT")
fi

# ── Faza 0: co w ogole trzeba zbudowac ──────────────────────────────────────
# Odsiew robimy przed budowaniem, zeby pasek postepu pokazywal prawdziwa liczbe
# zadan, a nie mieszal pominietych z realna praca.

TODO=() ; SKIPPED=() ; FAILED=()

for name in "${DIRS[@]:-}"; do
  [[ -n "$name" ]] || continue
  dir="$ROOT/$name"
  hash_now=""

  # 1) Zrodla nie zmienily sie od ostatniej udanej budowy — pomijamy.
  if [[ "${FORCE:-0}" != "1" && -d "$dir" ]]; then
    hash_now="$(source_hash "$dir")"
    if [[ -n "$hash_now" && -f "$CACHE/$name" ]] && [[ "$hash_now" == "$(cat "$CACHE/$name")" ]]; then
      echo "· $name: bez zmian od ostatniej budowy — pomijam (FORCE=1 wymusza budowę)"
      SKIPPED+=("$name (bez zmian)")
      continue
    fi
  fi

  # 2) Zapas: dokladnie ta wersja siedzi juz w edytorze.
  if [[ -n "$INSTALLED" ]] && manifest="$(manifest_for "$dir")"; then
    id_ver="$(node -e "const p=require('$manifest');console.log(p.publisher+'.'+p.name+'@'+p.version)")"
    if grep -qixF "$id_ver" <<<"$INSTALLED"; then
      echo "· $name: $id_ver już zainstalowane — pomijam (FORCE=1 wymusza budowę)"
      [[ -n "$hash_now" ]] && mkdir -p "$CACHE" && printf '%s' "$hash_now" > "$CACHE/$name"
      SKIPPED+=("$name ($id_ver)")
      continue
    fi
  fi

  if [[ ! -f "$dir/package.json" ]]; then
    echo "✗ pominięto: brak package.json w $name" >&2
    FAILED+=("$name (brak package.json)")
    continue
  fi

  TODO+=("$name")
done

# ── Faza 1: budowanie (rownolegle) ──────────────────────────────────────────

LOGDIR=""
BUILT_NAMES=() ; BUILT_VSIX=()
cleanup() { [[ -n "$LOGDIR" && -d "$LOGDIR" ]] && rm -rf "$LOGDIR"; return 0; }
trap cleanup EXIT

# Jedna budowa rozszerzenia: instalacja zaleznosci + npm run package + odcisk.
# Cale wyjscie idzie do pliku, bo przy kilku budowach naraz przeplatane linie
# z roznych rozszerzen sa nie do czytania.
build_one() {
  local name="$1" dir="$ROOT/$1" rc=0

  if needs_install "$dir"; then
    echo "… instalacja zależności ($name)"
    if [[ -f "$dir/package-lock.json" ]]; then
      # npm ci jest szybsze i powtarzalne, ale przewraca sie, gdy lock rozjedzie
      # sie z package.json — wtedy schodzimy do zwyklego npm install.
      (cd "$dir" && npm ci --no-audit --no-fund) \
        || (cd "$dir" && npm install --no-audit --no-fund) || return 10
    else
      (cd "$dir" && npm install --no-audit --no-fund) || return 10
    fi
  else
    echo "· zależności aktualne ($name) — pomijam instalację"
  fi

  (cd "$dir" && npm run package) || return 11

  local vsix
  vsix="$(find "$dir" -name '*.vsix' -not -path '*/node_modules/*' -print0 \
          | xargs -0 ls -t 2>/dev/null | head -1)"
  [[ -n "$vsix" ]] || return 12

  printf '%s' "$vsix" > "$LOGDIR/$name.vsix"
  # Odcisk liczony po budowie: npm install / npm run package moga dotknac
  # package-lock.json, wiec zapisujemy stan koncowy — inaczej kolejny przebieg
  # znow uznalby rozszerzenie za zmienione.
  source_hash "$dir" > "$LOGDIR/$name.hash"
  return $rc
}

# node_modules bywa nieaktualne, a nie tylko nieobecne: po zmianie package.json
# albo package-lock.json stara instalacja jest do wymiany. npm zapisuje w
# node_modules/.package-lock.json stan, na ktorym skonczyl, wiec wystarczy
# porownac daty — bez tego skrypt budowal na starych zaleznosciach.
needs_install() {
  local dir="$1"
  [[ -d "$dir/node_modules" ]] || return 0
  [[ -f "$dir/package-lock.json" ]] || return 1
  [[ "$dir/node_modules/.package-lock.json" -nt "$dir/package-lock.json" ]] && return 1
  return 0
}

if [[ ${#TODO[@]} -gt 0 ]]; then
  LOGDIR="$(mktemp -d 2>/dev/null || echo "$ROOT/.build-tmp.$$")"
  mkdir -p "$LOGDIR"

  # Wszystkie rozszerzenia wolaja to samo vsce przez npx. Pierwsze wywolanie
  # sciaga je z rejestru, kolejne biora z cache — wiec robimy to raz, przed
  # rozejsciem sie budow, zamiast pozwolic kilku naraz sciagac to samo.
  VSCE_SPEC="$(sed -n 's|.*\(@vscode/vsce@[0-9][0-9.]*\).*|\1|p' "$ROOT"/*/package.json 2>/dev/null | head -1)"
  if [[ -n "$VSCE_SPEC" ]]; then
    echo "… przygotowanie $VSCE_SPEC (raz dla wszystkich rozszerzeń)"
    npx --yes --loglevel=error "$VSCE_SPEC" --version >/dev/null 2>&1 || true
  fi

  echo ""
  echo "▶ budowanie: ${#TODO[@]} rozszerzeń, ${JOBS} naraz"

  run_names=() ; run_pids=() ; run_start=()
  next=0 ; started_at="$(date +%s)"

  # Jedna linia stanu nadpisywana w miejscu, zeby bylo widac, ze cos sie dzieje.
  # npm install przy pierwszym uruchomieniu potrafi milczec minutami (esbuild
  # dociaga swoj plik wykonywalny w postinstall) — bez tego licznika ekran
  # wyglada na zawieszony.
  tty_status=0 ; [[ -t 1 ]] && tty_status=1
  last_beat=0

  show_status() {
    local now line i
    now="$(date +%s)"
    line=""
    for ((i = 0; i < ${#run_pids[@]}; i++)); do
      [[ -n "${run_pids[$i]}" ]] || continue
      line+="${run_names[$i]} $(( now - run_start[$i] ))s  "
    done
    [[ -n "$line" ]] || return 0
    if (( tty_status )); then
      printf '\r\033[K  ⏳ %s(%ss)' "$line" "$(( now - started_at ))"
    elif (( now - last_beat >= 30 )); then
      last_beat="$now"
      printf '  ⏳ %s(%ss)\n' "$line" "$(( now - started_at ))"
    fi
  }

  clear_status() { (( tty_status )) && printf '\r\033[K'; return 0; }

  reap() {
    local i rc
    for ((i = 0; i < ${#run_pids[@]}; i++)); do
      [[ -n "${run_pids[$i]}" ]] || continue
      kill -0 "${run_pids[$i]}" 2>/dev/null && continue
      wait "${run_pids[$i]}" ; rc=$?
      local name="${run_names[$i]}" took=$(( $(date +%s) - run_start[$i] ))
      run_pids[$i]=""
      clear_status
      echo ""
      echo "══════════════════════════════════════════════"
      echo "▶ $name (${took}s)"
      echo "══════════════════════════════════════════════"
      cat "$LOGDIR/$name.log" 2>/dev/null
      case "$rc" in
        0)
          local vsix ; vsix="$(cat "$LOGDIR/$name.vsix")"
          echo "✓ zbudowano: ${vsix#$ROOT/}"
          BUILT_NAMES+=("$name") ; BUILT_VSIX+=("$vsix") ;;
        10) FAILED+=("$name (npm install)") ;;
        11) FAILED+=("$name (npm run package)") ;;
        12) FAILED+=("$name (nie znaleziono .vsix)") ;;
        *)  FAILED+=("$name (budowa, kod $rc)") ;;
      esac
    done
  }

  active() {
    local i n=0
    for ((i = 0; i < ${#run_pids[@]}; i++)); do
      [[ -n "${run_pids[$i]}" ]] && n=$(( n + 1 ))
    done
    echo "$n"
  }

  while (( next < ${#TODO[@]} )) || (( $(active) > 0 )); do
    while (( next < ${#TODO[@]} )) && (( $(active) < JOBS )); do
      name="${TODO[$next]}"
      build_one "$name" > "$LOGDIR/$name.log" 2>&1 &
      run_names+=("$name") ; run_pids+=("$!") ; run_start+=("$(date +%s)")
      next=$(( next + 1 ))
    done
    sleep 1
    reap
    show_status
  done
  clear_status
fi

# ── Faza 2: instalacja w edytorze (po kolei) ────────────────────────────────
# code --install-extension rusza ten sam katalog rozszerzen dla kazdej paczki,
# wiec rownolegle instalacje potrafia sobie wejsc w droge. Budowa byla
# rownolegla, instalacja jest szeregowa — i tak trwa sekundy, nie minuty.

OK=()

for ((i = 0; i < ${#BUILT_NAMES[@]}; i++)); do
  name="${BUILT_NAMES[$i]}" ; vsix="${BUILT_VSIX[$i]}"

  if [[ "${SKIP_INSTALL:-0}" != "1" ]]; then
    if "$EDITOR_CLI" --install-extension "$vsix" --force; then
      echo "✓ zainstalowano ($name) w: $EDITOR_CLI"
    else
      FAILED+=("$name (instalacja)")
      continue
    fi
  fi

  mkdir -p "$CACHE" && cp "$LOGDIR/$name.hash" "$CACHE/$name"
  OK+=("$name → $(basename "$vsix")")
done

echo ""
echo "══════════════ PODSUMOWANIE ══════════════"
for line in "${OK[@]:-}";      do [[ -n "$line" ]] && echo "  ✓ $line"; done
for line in "${SKIPPED[@]:-}"; do [[ -n "$line" ]] && echo "  · $line — pominięte"; done
for line in "${FAILED[@]:-}";  do [[ -n "$line" ]] && echo "  ✗ $line"; done
[[ ${#FAILED[@]} -eq 0 ]]
