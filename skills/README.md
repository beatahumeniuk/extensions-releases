# analyst-skills

Skille analityka w formacie **Agent Skills** (otwarty standard,
[agentskills.io](https://agentskills.io)) — zwykłe foldery z `SKILL.md`,
niezależne od harnessu.

Mieszkają tutaj, a nie w osobnym repozytorium, bo ich kontrakt jest tutaj:
schemat wyjścia, wygenerowana lista kluczy pól i walidator, na którym
`view-from-code` opiera swój ostatni krok, są w `ui-design/schema/`
i `ui-design/vscode-extension/scripts/`. Trzymane osobno rozjeżdżały
się z nimi po cichu — test w rozszerzeniu pilnuje teraz schematu, a skille
widzą go w tym samym drzewie.

## Podział odpowiedzialności: rozszerzenie vs skill

Jedno kryterium rozstrzyga, gdzie mieszka funkcja:

**Rozszerzenie VS Code** robi wyłącznie to, co jest **deterministyczne** —
ma zamknięty format wejścia, jedną poprawną odpowiedź i test golden:
edycja modelu w GUI, rendering modelu → md, parsing **własnego** md → model
(round-trip), transport Confluence (fetch/publish/sync), zapis w ustalone
ścieżki `solution-design/`, strukturalna detekcja **własnych** formatów (zamknięta
lista literałów; wszystko inne uczciwie dostaje `confluence-page`).

**Skill agenta** robi wszystko, co wymaga **osądu i rozumienia treści** —
scenariuszy jest zbyt wiele, żeby ogrywać je kodem: klasyfikacja i adopcja
nieformatowych plików, restrukturyzacja prozy do formatu, audyt zestawu
i sprzeczności, zakres zmiany, wywiad z analitykiem, destylacja
spec/test-spec, delta z historii gita, decyzja „którego klocka użyć teraz".

Reguła na przyszłość: jeśli nowa funkcja potrzebuje rozumienia treści,
pytania do człowieka albo obsługi „to zależy" — to skill (albo wcale),
nigdy rozszerzenie.

## Gdzie który skill mieszka

Skill, który pisze **format jednego rozszerzenia**, mieszka w tym rozszerzeniu
i jedzie w jego `.vsix` — jedna wersja dla czytnika i dla piszącego, pilnowana
tą samą regułą podbijania wersji co reszta rozszerzenia:

| Skill | Katalog | Instalacja |
|---|---|---|
| `flow-from-code` | `logic-design/skill/` | komenda **Logic Design: Zainstaluj skill dla agenta** |
| `view-from-code` | `ui-design/vscode-extension/skill/` | komenda **UI Design: Zainstaluj skill dla agenta** |
| `handoff-package` | tutaj | ręcznie, patrz niżej |
| `md-adopt` | tutaj | ręcznie, patrz niżej |

Tutaj zostają skille **poprzeczne**: `handoff-package` czyta projekty ze
wszystkich rozszerzeń naraz, `md-adopt` normalizuje całe drzewo `solution-design/` —
żadnego z nich nie da się przypisać do jednego rozszerzenia.

Skille rozszerzeń mają **jedno wspólne ustawienie**: **`agentSkills.harness`**
mówi, **który agent wykonuje skille**, gdy uruchamia je rozszerzenie (np.
znaczek „Opisz flow z kodu" nad endpointem w Logic Design), i **dokąd
instaluje się `SKILL.md`** — katalog wynika z harnessu, niczego więcej się
nie ustawia:

| Harness | Co robi znaczek/komenda | Katalog skilli |
|---|---|---|
| `chat` (domyślne) | czat agenta w oknie VS Code; brak czatu → schowek | `~/.agents/skills` — lokalizacja standardu, czytana też przez Cursora i Copilota |
| `claude-code` | `claude "…"` w zintegrowanym terminalu, w korzeniu projektu | `~/.claude/skills` |
| `copilot-cli` | `copilot -p "…"` w zintegrowanym terminalu, w korzeniu projektu | `~/.copilot/skills` |
| `clipboard` | samo skopiowanie polecenia — wklejasz dowolnemu agentowi | `~/.agents/skills` |
| `custom` | własne polecenie terminalowe — rozszerzenie pyta o nie przy pierwszym użyciu i pamięta (`{prompt}` podstawiane w cudzysłowie) | `~/.agents/skills` |

Instalacja to **katalog, nie format**: `SKILL.md` idzie bajt w bajt, bez
konwersji na format harnessu. Agenta, który nie czyta skilli sam z siebie,
wywołujesz wskazując mu ten plik.

## Instalacja skilli poprzecznych (raz, na swojej maszynie)

Skopiuj foldery do **`~/.agents/skills/`** — osobistej lokalizacji standardu,
czytanej m.in. przez GitHub Copilota, Cursora i Codexa we wszystkich projektach:

```bash
mkdir -p ~/.agents/skills && cp -R handoff-package md-adopt ~/.agents/skills/
```

Windows, w wierszu poleceń (`cmd`) — bez PowerShella, jak wszędzie w tym repo:

```bat
md "%USERPROFILE%\.agents\skills" 2>nul
for %d in (handoff-package md-adopt) do xcopy /E /I /Y "%d" "%USERPROFILE%\.agents\skills\%d"
```

W pliku `.bat` podwój znak procenta w pętli (`%%d`).

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

Dwa pierwsze mieszkają w swoich rozszerzeniach (patrz tabela wyżej), dwa
kolejne — tutaj.

- **flow-from-code** (`logic-design/skill/`) — z kodu endpointu buduje szkic
  pakietu Logic Design (`solution-design/api/<endpoint>/api.json` + `endpoint.json`
  i przykłady: kroki w kolejności wykonania, integracje z bibliotekami
  klienckimi, odpowiedzi per status HTTP, kwestie otwarte z dowodami
  `plik:linia`).
- **view-from-code** (`ui-design/vscode-extension/skill/`) — z kodu
  zaimplementowanego widoku wypełnia `solution-design/ui/<widok>/view-mapping.json`
  (typy komponentów, reguły walidacji, warunki widoczności, test id,
  endpointy, kwestie otwarte z dowodami `plik:linia`). Widoku nigdy
  nieprzeniesionego z Figmy zakłada od zera — `view.json` pisze wtedy
  `scripts/seed-view.ts`, nie skill. Test ID bierze w kolejności: kod →
  projekt → dopiero reguła, a istniejącego nie rusza; rozjazd między kodem
  a projektem zapisuje jako konflikt (`GEN-003`) i zostawia do rozstrzygnięcia
  analitykowi.
- **handoff-package** — składa z materiału w `solution-design/` commitowany folder
  zmiany `context/changes/<feature-id>/` (nazewnictwo 10x: `change.md`,
  `spec.md`, `test-spec.md`, `open-questions.md`) dla programisty i testera —
  z linkami do artefaktów w `solution-design/`, bez kopii. Inventory-first: wejście
  w dowolnym punkcie procesu.
- **md-adopt** — wciąga istniejące pliki md do drzewa `solution-design/`
  (frontmatter, lokalizacja, kanoniczne sekcje, opcjonalny podział na indeks
  i części). Kontrakt formatu:
  [md-adopt/references/frontmatter-schema.md](md-adopt/references/frontmatter-schema.md).

Zasada wspólna skilli `*-from-code`: emitują **natywny pakiet roboczy
narzędzia** (to, co rozszerzenie otwiera wprost), nigdy markdown — kanoniczny
md powstaje zawsze jednym eksportem z narzędzia, po weryfikacji analityka.
Dzięki temu nigdy nie istnieją dwa konkurencyjne renderingi tego samego projektu.

**Projekt jest podzielony na pliki.** Eksport daje indeks (`<widok>.md`,
`api.md`) i obok niego części — sekcje widoku w `sections/`, kroki przepływu
w `parts/` — każda z `type: <artefakt>-part`, `part:` i `parent:`. Skille liczą
i linkują **indeks**, a czytają **części**: projekt policzony po plikach to
sześć artefaktów zamiast jednego. Dokument jednoplikowy (pisany ręcznie,
starszy eksport, strona wrócona z Confluence) jest równie poprawny i czyta się
go wprost.

W Logic Design **`parts/` to wyłącznie kroki procesu**. Kontrakt wejścia
i wyjścia oraz kwestie otwarte krokami nie są, więc leżą obok indeksu
(`request.md`, `responses.md`, `open-questions.md`) i dodatkowo są wydrukowane
w `api.md` — indeks czyta się od góry do dołu i widać z niego wszystko poza
szczegółami kroków.

Skille zakładają format dokumentacji generowany przez rozszerzenia VS Code
z repo `extensions` (API Designer, Schema Mapper, UI Design,
Logic Design, DB Playground, Confluence to md) — ale działają na każdym
drzewie `solution-design/` zgodnym z kontraktem frontmattera.
