# analyst-skills

Skille analityczne w formacie **Agent Skills** (otwarty standard,
[agentskills.io](https://agentskills.io)) — zwykłe foldery z `SKILL.md`,
niezależne od harnessu.

Mieszkają tutaj, a nie w osobnym repozytorium, bo ich kontrakt jest tutaj:
schemat wyjścia, wygenerowana lista kluczy pól i walidator, na którym
`view-from-code` opiera swój ostatni krok, są w `ui-analysis/schema/`
i `ui-analysis/vscode-extension/scripts/`. Trzymane osobno rozjeżdżały
się z nimi po cichu — test w rozszerzeniu pilnuje teraz schematu, a skille
widzą go w tym samym drzewie.

## Podział odpowiedzialności: rozszerzenie vs skill

Jedno kryterium rozstrzyga, gdzie mieszka funkcja:

**Rozszerzenie VS Code** robi wyłącznie to, co jest **deterministyczne** —
ma zamknięty format wejścia, jedną poprawną odpowiedź i test golden:
edycja modelu w GUI, rendering modelu → md, parsing **własnego** md → model
(round-trip), transport Confluence (fetch/publish/sync), zapis w ustalone
ścieżki `docs/`, strukturalna detekcja **własnych** formatów (zamknięta
lista literałów; wszystko inne uczciwie dostaje `confluence-page`).

**Skill agenta** robi wszystko, co wymaga **osądu i rozumienia treści** —
scenariuszy jest zbyt wiele, żeby ogrywać je kodem: klasyfikacja i adopcja
nieformatowych plików, restrukturyzacja prozy do formatu, audyt zestawu
i sprzeczności, zakres zmiany, wywiad z analitykiem, destylacja
spec/test-spec, delta z historii gita, decyzja „którego klocka użyć teraz".

Reguła na przyszłość: jeśli nowa funkcja potrzebuje rozumienia treści,
pytania do człowieka albo obsługi „to zależy" — to skill (albo wcale),
nigdy rozszerzenie.

## Instalacja (raz, na swojej maszynie)

Skopiuj foldery skilli do **`~/.agents/skills/`** — osobistej lokalizacji
standardu, czytanej m.in. przez GitHub Copilota, Cursora i Codexa we
wszystkich projektach:

```bash
mkdir -p ~/.agents/skills && cp -R handoff-package md-adopt ~/.agents/skills/
```

Windows (PowerShell):

```powershell
New-Item -ItemType Directory -Force "$HOME\.agents\skills" | Out-Null
Copy-Item -Recurse -Force handoff-package,md-adopt "$HOME\.agents\skills\"
```

Aktualizacja = `git pull` + ponowne skopiowanie (albo trzymaj sklonowane repo
i podlinkuj foldery symlinkiem zamiast kopiować).

Uwagi per harness:

- **GitHub Copilot** czyta też `~/.copilot/skills/`; projektowo:
  `.github/skills/`, `.claude/skills/`, `.agents/skills/`.
- **Cursor** czyta `~/.agents/skills/` i `~/.cursor/skills/`.
- **Claude Code** czyta `~/.claude/skills/` — podlinkuj:
  `ln -s ~/.agents/skills/handoff-package ~/.claude/skills/handoff-package`
  (symlinki są oficjalnie wspierane).
- Gdy harness nie zna skilli w ogóle, każdy `SKILL.md` jest samowystarczalny —
  wystarczy wskazać go agentowi: „przeczytaj i wykonaj ten plik".

## Dostępne skille

- **handoff-package** — składa z `docs/` projektu commitowany folder zmiany
  `context/changes/<feature-id>/` (nazewnictwo 10x: `change.md`, `spec.md`,
  `test-spec.md`, `open-questions.md`) dla programisty i testera — z linkami
  do artefaktów w `docs/`, bez kopii. Inventory-first: wejście w dowolnym
  punkcie procesu.
- **md-adopt** — dostosowuje istniejące pliki md do formatu `docs/`
  (frontmatter, lokalizacja, kanoniczne sekcje). Kontrakt formatu:
  [md-adopt/references/frontmatter-schema.md](md-adopt/references/frontmatter-schema.md).
- **view-from-code** — z kodu zaimplementowanego widoku buduje szkic pakietu
  UI Analysis (`views/<widok>/view.json` + `view-mapping.json`:
  sekcje, typy komponentów, reguły walidacji, endpointy, kwestie otwarte
  z dowodami `plik:linia`).
- **flow-from-code** — z kodu endpointu buduje szkic pakietu Logic Analysis
  (`analysis/api/<endpoint>/api.json` + `request.json`/`response.json`: kroki
  w kolejności wykonania, integracje z bibliotekami klienckimi, odpowiedzi
  per status HTTP).

Zasada wspólna skilli `*-from-code`: emitują **natywny pakiet roboczy
narzędzia** (to, co rozszerzenie otwiera wprost), nigdy markdown — kanoniczny
md w `docs/` powstaje zawsze jednym eksportem z narzędzia, po weryfikacji
analityka. Dzięki temu nigdy nie istnieją dwa konkurencyjne renderingi tej
samej analizy.

Skille zakładają format dokumentacji generowany przez rozszerzenia VS Code
z repo `extensions` (API Designer, Schema Mapper, UI Analysis,
Logic Analysis, DB Playground, Confluence to md) — ale działają na każdym `docs/` zgodnym
z kontraktem frontmattera.
