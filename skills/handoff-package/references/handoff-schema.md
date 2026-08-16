# Handoff change folder — schema

The contract for everything `/handoff-package` writes. Section names, file
names, frontmatter keys and status literals are **parser literals** — agents
and re-runs grep for them. Change them only together with the skill.

Body prose is Polish; frontmatter keys, status values, file and folder names
are English. File and folder naming follows the 10x convention
(`context/changes/<id>/`, `change.md`) so the analyst repo reads like any 10x
project.

## Where it lives

The handoff is **committed to the analyst repo** — the developer and the
tester (and their agents) read it from the repository, not from an
out-of-band copy. Artifacts stay where they are in `analysis/` and are
**linked, never copied**: one repo, one home per fact.

```
context/changes/<feature-id>/
  change.md             # the spine — identity, scope, artifact map, start prompts
  spec.md               # developer path through the evidence
  test-spec.md          # tester path: risks, edge cases, gaps
  open-questions.md     # every gap, each with Block: yes|no
```

All links inside these files are repo-relative (`../../analysis/ui/login/login.md`)
and must resolve within the repository.

An analysis in `analysis/` is an **index plus its parts** — `login.md` with
`sections/*.md` beside it, `api.md` with `parts/*.md`. Link the index when you
mean the analysis, link the part when you mean one thing inside it
(`../../analysis/ui/login/sections/section-01.md`). Both are links into the
same artifact; only one of them makes the reader scroll.

## change.md

```markdown
---
type: change
feature: <feature-id>
generated: <YYYY-MM-DD>
generator: handoff-package
audience: [developer, tester]
mode: new | update | mixed  # nowa funkcjonalność, zmiana w istniejącej, albo część nowa/część zmiana
status: draft | ready
blockers: <n>              # open questions with Block: yes
---
# <Nazwa funkcjonalności>

## Zakres
## Stan zastany
## Czego NIE robimy
## Artefakty
## Kolejność czytania
## Kwestie otwarte
## Start
```

- **Zakres** — 3–8 zdań: co budujemy, z linkami do artefaktów w `analysis/`
  (`[widok logowania](../../analysis/ui/login/login.md)`).
- **Stan zastany** — co już istnieje i działa zanim ten change powstał:
  wdrożony kod, wcześniejsze wersje kontraktów, części procesu zrobione
  wcześniej. Per pozycja: jedno zdanie + skąd to wiadomo (artefakt albo
  „wywiad"). Ta sekcja mówi odbiorcy, czego change celowo NIE opisuje, bo już
  działa — przy `mode: new` bez stanu zastanego wpisz `Brak — całość jest
  nowa.` Nigdy nie zgaduj stanu kodu: co niepotwierdzone → Open Question.
- **Czego NIE robimy** — jawne wykluczenia zakresu (wzorzec z 10x-plan).
  Jeśli nic nie wykluczono w wywiadzie, wpisz `# TODO: potwierdź zakres
  wykluczeń` i dodaj Open Question.
- **Artefakty** — tabela: `| Artefakt | Typ | Źródło | Wygenerowano | Status |`.
  `Artefakt` = repo-relative link do **indeksu** artefaktu w `analysis/`
  (analiza podzielona na pliki jest **jednym wierszem**, nie sześcioma —
  części nie mają tu własnych wierszy); `Źródło` i
  `Wygenerowano` przepisane z frontmattera artefaktu; `Status` = `fresh` |
  `stale` (źródło nowsze niż eksport) | `unknown` (brak danych). Fragmenty
  zależności (`analysis/external/<klient>/dependency.xml`) też są wierszami tej tabeli.
  **Per widok w zakresie tabela ma dodatkowy wiersz `Makieta`** z linkiem do
  Figmy (klucz `mockup:` z frontmattera analizy; gdy go brak — dopytany w
  wywiadzie). Programista i tester dostają link do makiety zawsze, wprost
  z change.md.
- **Kolejność czytania** — numerowana lista dla agenta odbiorcy: 1. change.md,
  2. spec.md / test-spec.md (wg roli), 3. widoki, 4. kontrakty, 5. mapowania,
  6. kontekst biznesowy. Odchylenia uzasadnij jednym zdaniem.
- **Kwestie otwarte** — tylko licznik + link:
  `N kwestii (M blokujących) → [open-questions.md](open-questions.md)`.
- **Start** — dwa gotowe prompty w blokach kodu: jeden dla agenta programisty
  (wejście: `context/changes/<id>/spec.md`), jeden dla agenta testera
  (wejście: `context/changes/<id>/test-spec.md`). Prompty zakładają, że
  odbiorca ma sklonowane to repo — wskazują ścieżki w repo, niczego nie
  każą kopiować.

`status: ready` only when `blockers: 0` and no artifact is `stale`.
Otherwise `draft`.

## open-questions.md

```markdown
---
type: open-questions
feature: <feature-id>
generated: <YYYY-MM-DD>
---
# Kwestie otwarte

## Q-01: <temat>
- Źródło: <link do artefaktu lub „wywiad">
- Pytanie: <jedno zdanie>
- Block: yes | no
- Dotyczy: developer | tester | both
```

IDs `Q-NN`, append-only within a run. Every open issue imported from a view
analysis (`sections/open-questions.md`), from a
flow analysis (`parts/open-questions.md`), every `## Braki` entry from a mapping,
and every cross-check failure lands here. Rozwiązane i „nie dotyczy" nie są
kwestiami otwartymi i nie trafiają tu wcale. `Źródło` links the file the issue was
read from — the section, not the index. **Never resolved by the skill** —
only the user or the source artifacts resolve them.

## spec.md

```markdown
---
type: spec
feature: <feature-id>
generated: <YYYY-MM-DD>
---
# Specyfikacja: <nazwa>

## Intencja
## Widoki i akcje
## Kontrakty
## Mapowania pól
## Zależności
## Decyzje i kontekst biznesowy
## Czego tu nie ma
```

Rules:
- **Signal, not knowledge** (wzorzec z 10x-test-plan): the file points at
  evidence in `analysis/` (`[POST /api/login](../../analysis/api/contracts/auth.md)`), it
  does not restate tables that already exist in the artifacts, and it
  **never** references files or line numbers in the developer's own repo.
- **Widoki i akcje** — per view: one paragraph of intent + link to the
  analysis in `analysis/ui/` **and the Figma mockup link** (`mockup:` frontmatter);
  list only the actions with non-obvious flow (error branches, modals), each
  pointing at the section file where its component is described.
- **Mapowania pól** — per mapping: target schema, sources, link; call out
  every `transform` and `whenNull` rule as implementation obligations.
- **Zależności** — table `| Plik | Po co |`, one row per
  `analysis/external/<klient>/dependency.xml` in scope, each a repo-relative link to
  the paste-ready Maven fragment. Never quote the XML inline. Omit the
  section when no fragments are in scope.
- **Czego tu nie ma** — honest list: things the developer must decide or
  discover themselves (with matching `Q-NN` refs where applicable).

## test-spec.md

```markdown
---
type: test-spec
feature: <feature-id>
generated: <YYYY-MM-DD>
---
# Specyfikacja testów: <nazwa>

## Ryzyka
## Reguły walidacji per komponent
## Przypadki brzegowe z ograniczeń
## Luki wykryte przez analizę
## Kwestie otwarte istotne dla testów
```

Rules:
- **Ryzyka** — table `| Ryzyko | Dowód | Najtańsza warstwa testu |`, ordered
  by leverage. `Dowód` links into `analysis/` (validation finding code, contract
  constraint, mapping gap) — at the section file that carries it, not at the
  index. No invented risks: every
  row cites evidence.
- **Reguły walidacji per komponent** — distilled from the view's section files
  (wymagane, długości, wzorce, zakresy, warunki widoczności) — this is the
  tester's checklist, one table per view.
- **Przypadki brzegowe z ograniczeń** — derived mechanically from contract
  constraints (enum values, min/max, response codes) and mapping cardinality
  (`może być null`, listy) — enumerate, don't editorialize.
- **Luki wykryte przez analizę** — every `⨯`/`△` finding and `— brak obsługi
  błędu` from the artifacts, verbatim with its rule code. These are
  must-challenge items.
- The file **plans no test implementation** — no test code, no framework
  choices. It is evidence for the tester's own agent.

## Delivery copy (optional, into the developer's repo)

When the team keeps per-feature docs in the developer's repository (e.g.
`docs/features/<feature-id>/` with `adr.md`, `spec.md`, `tech.md`), the
handoff can additionally be **delivered** there:

```
<dev-repo>/docs/features/<feature-id>/
  spec.md        # copy of the change's spec.md — a THIN INDEX, never a container
  test-spec.md   # copy of the change's test-spec.md
  analysis/      # the depth: delivered copies of the scoped analysis/ artifacts
    views/<view>/<view>.md      # the index…
    views/<view>/sections/*.md  # …and its sections, beside it
    flows/<flow>/api.md         # likewise for a flow analysis…
    flows/<flow>/parts/*.md     # …and its parts
    contracts/<name>.md
    db/<name>-schema.md
    dependencies/<name>.pom.xml
```

A split analysis keeps its package folder in the delivery: the links inside an
index are relative to it (`sections/section-01.md`), so a flattened copy would arrive
with every link broken. Single-file artifacts (contracts, mappings, schemas,
dependency fragments) are delivered as the single files they are.

`spec.md` is deliberately small: intent, scope, stan zastany, reading order
and links — it never inlines tables or rules that live in the artifacts.
Whatever does not fit a paragraph belongs in `analysis/` as a whole file,
so the feature folder scales with the feature while `spec.md` stays a
two-page entry point.

Rules:

- The canonical home stays `context/changes/<feature-id>/` (and `analysis/`) in
  the analyst repo — the delivery is an export, refreshed on re-runs. Copies
  across repos are fine: this is a different repository, and the copies are
  machine-refreshed, never hand-edited.
- Links inside delivered `spec.md`/`test-spec.md` are rewritten to relative
  `analysis/...` paths, so the feature folder works offline and in merge
  requests. Additionally `change.md` (analyst repo) records the delivery
  commit, and each delivered file carries `deliveredFrom:` (analyst repo
  remote + feature id + commit sha) — the provenance pin.
- Files that already exist in the target folder and were not written by a
  previous delivery (no `deliveredFrom:` in frontmatter) are never
  overwritten — `adr.md` and `tech.md` belong to the developer.
- Provenance pin: when the analyst workspace is a git repo with the scoped
  artifacts committed, `deliveredFrom:` carries the commit sha; otherwise it
  carries the delivery date and the report warns that the delivery is not
  pinned to a verifiable version (weaker audit trail, delivery still
  proceeds).

## Re-runs and archiving

On a re-run for an existing `<feature-id>`, refresh in place (update links,
merge new `Q-NN`, keep resolved questions annotated); when `change.md`
counters change, first copy the previous `change.md` to
`change-<YYYY-MM-DD>.md` alongside. Moving a finished change to
`context/archive/` is the user's (or `/10x-archive`'s) job, not this skill's.

## Status literals

`fresh` / `stale` / `unknown` (artifact freshness), `draft` / `ready`
(change), `yes` / `no` (Block). English, lowercase, exact.
