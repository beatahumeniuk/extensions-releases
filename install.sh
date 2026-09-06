#!/usr/bin/env bash
#
# Installs the VS Code extension packages from this repository.
#
#   ./install.sh                 install everything that is out of date
#   ./install.sh logic-spec      install only the named packages
#   ./install.sh --local         install .vsix files sitting next to this script
#   FORCE=1 ./install.sh         reinstall even what is already current
#
# Needs curl (or wget) and the VS Code CLI. No Node.js, no npm.

set -uo pipefail

REPO="${REPO:-beatahumeniuk/extensions-releases}"
BRANCH="${BRANCH:-main}"
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/$REPO/$BRANCH}"

# On Windows/Git Bash a C:/... path is understood by both bash and the CLI,
# while an MSYS /c/... path is not.
ROOT="$(cd "$(dirname "$0")" && { pwd -W 2>/dev/null || pwd; })"

usage() {
  cat <<'EOF'
install.sh [--download|--local] [name ...]

  --download   (default) fetch the packages over HTTPS and install them
  --local      install the .vsix files next to this script (or in LOCAL_DIR)

Without names all packages are covered; names narrow it down.

Environment:
  FORCE=1         install even when the same version is already present
  EDITOR_CLI=...  path to the VS Code CLI when autodetection fails
  LOCAL_DIR=...   directory holding the .vsix files (--local only)
  REPO=, BRANCH=  where to fetch the packages from
EOF
}

MODE=download
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --download) MODE=download ;;
    --local)    MODE=local ;;
    -h|--help)  usage; exit 0 ;;
    -*)         echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
    *)          ARGS+=("$arg") ;;
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
    echo "VS Code CLI not found. Set EDITOR_CLI=..." >&2
    exit 1
  fi
fi

fetch_to_stdout() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then wget -qO- "$1"
  else echo "curl or wget is required." >&2; return 1
  fi
}

fetch_to_file() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL -o "$2" "$1"
  else wget -qO "$2" "$1"
  fi
}

wanted() {
  local a
  [[ $# -eq 1 ]] && return 0
  local name="$1"; shift
  for a in "$@"; do [[ "$a" == "$name" ]] && return 0; done
  return 1
}

summary() {
  echo ""
  echo "──────────── summary ────────────"
  local line
  for line in "${OK[@]:-}";      do [[ -n "$line" ]] && echo "  + $line"; done
  for line in "${SKIPPED[@]:-}"; do [[ -n "$line" ]] && echo "  · $line — unchanged"; done
  for line in "${FAILED[@]:-}";  do [[ -n "$line" ]] && echo "  x $line"; done
  [[ ${#OK[@]} -eq 0 ]] || echo "
Reload the VS Code window (Ctrl+Shift+P -> Developer: Reload Window)."
}

OK=() ; SKIPPED=() ; FAILED=()

# ── Default mode: fetch the packages and install them ───────────────────────

download_and_install() {
  local manifest installed tmp rc=0 name id ver asset have

  echo "Reading the version list from $REPO..."
  # A download can fail for reasons no script can fix. Packages already on
  # disk are still worth installing, so fall through to the local mode
  # instead of ending with nothing.
  manifest="$(fetch_to_stdout "$BASE_URL/versions.txt")" || {
    echo "x Could not fetch $BASE_URL/versions.txt" >&2
    echo "  Looking for packages on disk..." >&2
    echo "" >&2
    install_local "$@"
    return $?
  }
  [[ -n "$manifest" ]] || { echo "x $REPO holds no packages." >&2; return 1; }

  installed=""
  if [[ "${FORCE:-0}" != "1" ]]; then
    installed="$("$EDITOR_CLI" --list-extensions --show-versions 2>/dev/null | tr -d '\r' || true)"
  fi

  tmp="$(mktemp -d)"

  while IFS='|' read -r name id ver asset; do
    [[ -n "${name:-}" && -n "${asset:-}" ]] || continue
    wanted "$name" "$@" || continue

    if [[ -n "$installed" ]] && grep -qixF "$id@$ver" <<<"$installed"; then
      echo "· $name $ver — already current"
      SKIPPED+=("$name $ver")
      continue
    fi

    have="$(grep -i "^$id@" <<<"$installed" | head -1 || true)"
    if [[ -n "$have" ]]; then
      echo "> $name: ${have#*@} -> $ver"
    else
      echo "> $name: new, $ver"
    fi

    if ! fetch_to_file "$BASE_URL/$asset" "$tmp/$asset"; then
      echo "  x download failed" >&2
      FAILED+=("$name (download)")
      continue
    fi

    if "$EDITOR_CLI" --install-extension "$tmp/$asset" --force; then
      OK+=("$name $ver")
    else
      FAILED+=("$name (install)")
    fi
  done <<<"$manifest"

  rm -rf "$tmp"
  summary
  [[ ${#FAILED[@]} -eq 0 ]] || rc=1
  return $rc
}

# ── Local mode: install the .vsix files already on disk ─────────────────────

# Most specific first: an explicit directory, the script's own directory, the
# current directory, then Downloads — including the subdirectory Windows
# creates when an archive is unpacked.
find_local_dir() {
  local d dl
  for dl in "${USERPROFILE:-}/Downloads" "$HOME/Downloads"; do
    [[ -d "$dl" ]] && break
  done
  for d in "${LOCAL_DIR:-}" "$ROOT" "$PWD" "$dl" "$dl"/*/; do
    [[ -n "$d" && -d "$d" ]] || continue
    if ls "$d"/*.vsix >/dev/null 2>&1; then
      echo "${d%/}"
      return 0
    fi
  done
  return 1
}

install_local() {
  local dir rc=0 vsix name

  # An explicitly named directory is used or reported — falling through to
  # the search is only allowed when nothing was named.
  if [[ -n "${LOCAL_DIR:-}" ]] && ! ls "${LOCAL_DIR}"/*.vsix >/dev/null 2>&1; then
    echo "x No .vsix file in LOCAL_DIR:" >&2
    echo "  $LOCAL_DIR" >&2
    return 1
  fi

  dir="$(find_local_dir)" || {
    echo "x No .vsix file found." >&2
    echo "  Looked in: this script's directory, the current directory, Downloads." >&2
    echo "  Name one directly: LOCAL_DIR=/path bash install.sh --local" >&2
    return 1
  }

  echo "Installing .vsix packages from:"
  echo "  $dir"
  echo ""

  for vsix in "$dir"/*.vsix; do
    [[ -f "$vsix" ]] || continue
    name="$(basename "$vsix" .vsix)"
    wanted "$name" "$@" || continue

    echo "> $name"
    if "$EDITOR_CLI" --install-extension "$vsix" --force; then
      OK+=("$name")
    else
      FAILED+=("$name")
    fi
  done

  if [[ ${#OK[@]} -eq 0 && ${#FAILED[@]} -eq 0 ]]; then
    echo "x $dir holds packages, but none match the given names." >&2
    return 1
  fi

  summary
  [[ ${#FAILED[@]} -eq 0 ]] || rc=1
  return $rc
}

if [[ "$MODE" == "local" ]]; then
  install_local "$@"
else
  download_and_install "$@"
fi
exit $?
