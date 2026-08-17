# Docs markdown contract — frontmatter + tree

The single source of truth for the structured-markdown format used across the
analyst toolchain (the VS Code extensions, `/docs-review`, `/handoff-package`,
`/md-adopt`). Keys, values and section names below are parser literals.

Frontmatter keys, status values, and ALL file/folder/package names (slugs,
feature ids, package directories) are English; body headings, prose and
display names inside documents are Polish.

## Gdzie trafiają adoptowane pliki

Dwa drzewa, jedna zasada: **`solution-design/` jest generowane i tam wchodzi adopcja,
`docs/` jest pisane ręcznie i żadne narzędzie ani skill tam nie zapisuje.**
`docs/` to dokumentacja docelowa dla programisty i testera — recenzowana,
trwała, i nie może zginąć pod przebiegiem narzędzia.

```
solution-design/
  ui/<widok>/<widok>.md         # type: view-design   (UI Design) — indeks
  ui/<widok>/sections/*.md      # type: view-design-part — sekcje projektu
  api/<ścieżka>/api.md          # type: api-design    (Logic Design) — indeks
  api/<ścieżka>/parts/*.md      # type: api-design-part — części przepływu
  api/contracts/<nazwa>.md      # type: contract        (API Designer)
  api/<ścieżka>/<cel>.mapping.md # type: field-mapping  (Schema Mapper)
  db/model/<źródło>-schema.md   # type: db-playground-schema (DB Playground)
  dictionary/<nazwa>.md         # type: value-dictionary (API Designer)
  external/<klient>/dependency.xml  # fragmenty zależności Maven
  confluence/<slug>.md          # type: confluence-page (Confluence to md)
```

Adoptowany plik pisany ręcznie idzie do podkatalogu odpowiadającego jego
`type`; plik niepasujący do żadnego typu zostaje tam, gdzie jest — adopcji
się nie wymusza.

**Powiązanie z Confluence** nie ma osobnego pliku indeksu. Siedzi we front
matterze samego dokumentu, jako blok `confluence:` z `url` i `version`.
Adopcja go nie tworzy i nie rusza — zapisuje go rozszerzenie przy publikacji.

## Frontmatter keys

Order is fixed; omit a key rather than write an empty value.

| Key | Required | Values / format | Notes |
|---|---|---|---|
| `type` | yes | `contract` · `field-mapping` · `view-design` · `api-design` · `db-playground-schema` · `confluence-page` · `<artefakt>-part` | what the document is; `-part` = jedna część projektu podzielonego na pliki |
| `generator` | yes | `<tool>@<version>` or `manual` | `manual` = written by a person, editable |
| `generated` | when known | `YYYY-MM-DD` | when the CONTENT was produced; never guessed |
| `adopted` | adoption only | `YYYY-MM-DD` | when `/md-adopt` brought the file into the format and `generated` is unknown |
| `source` | when known | workspace-relative path or URL | the source of truth this document renders/describes |
| `sourceId` | per type | page id, record name | identity within the source system |
| `mockup` | view-design | Figma URL (with `node-id`) | link to the mockup the view comes from; recorded by the Figma import and carried through every round trip |
| `operation` | contract only | operation label | per-service narrowed export |
| `space` | confluence only | space key | |
| `status` | per type | `draft` · `complete` | computed by generators; set by hand for manual docs |
| `components` / `openIssues` / `coverage` | view-design only | numbers | counters computed at export |
| `part` | `-part` only | nazwa części (`section-01`, `endpoints`, `open-questions`, `step-01`…) | która to część projektu |
| `parent` | `-part` only | ścieżka względna do indeksu | plik, którego spis treści linkuje tę część |
| `managed` | tool exports only | `true` | fully regenerated from `source` — **never hand-edited**; a hand-written file must NOT carry it |

The `managed: true` / `generator: manual` distinction is load-bearing:
`/docs-review` refuses content edits on managed files (fix the source,
regenerate) and allows them on manual ones.

## Canonical section sets per type

Used by generators, by `/md-adopt`'s optional restructuring, and by importers.
H1 is always the document title.

- **contract** — meta table under H1 (`| Wersja kontraktu | … |`, `| Format | … |`), then `## Endpointy` (`### <tag>` → `#### `METHOD /path``) and/or `## Operacje` / `## Elementy główne`, then `## Model danych` (`### <Klasa>` + fields table `| Pole | Typ | Wymagane | Ograniczenia | Opis |`).
- **field-mapping** — meta table, `## Źródła`, `## Mapowania pól` (`### <grupa>.*` + table `| Pole docelowe | Typ | Liczność | Źródło | Pole źródłowe | Konwersja / agregacja | Gdy NULL | Status |`), optional `## Braki`, `## Notatki`. *Being phased out:* Schema Mapper is absorbed by Logic Design (mappings become flow steps); the type stays valid for existing exports, new mappings are documented inside `api-design`.
- **view-design** — numbered `## N. <sekcja>`; nazwy sekcji zależą od
  ustawień zespołu, więc rozpoznawaj po kształcie: sekcja struktury to ta,
  w której są wiersze komponentów ``- **Etykieta** (`Typ`) — reguły``,
  a nagłówek z typem w nawiasie — `## 1. Dane klienta  _(Sekcja)_` w pliku
  sekcji, `### Dane klienta  _(Sekcja)_` w dokumencie jednoplikowym — otwiera
  sekcję. Numeracja jest dynamiczna, więc numery nie są stałe.
  **Dokument jest podzielony na pliki** (patrz „Split documents"): jeden plik
  na sekcję widoku, więc wierszy komponentów szukaj w `sections/`, nie
  w indeksie — indeks ich nie ma.
- **api-design** — export of the Logic Design extension (flow design of
  a process/service): H1 `# API: <nazwa>`, numbered step sections
  (walidacja, odczyt/zapis bazy, mapowanie, wywołanie usługi zewnętrznej,
  przekształcenie, event Kafka) and response sections per HTTP status. Source
  of truth: `solution-design/api/<ścieżka>/api.json`.
  Documents older than the current naming declare a different `type` and a
  different H1; detection goes by the shape of the document, not by the type
  it declares, so they are still recognised on read.
  **Dokument jest podzielony na pliki** (patrz „Split documents"): pod
  `## Przebieg` diagram i linki do kroków, a treść kroków w `parts/` — tylko
  ich. Kontrakt (`request.md`, `responses.md`) i kwestie otwarte
  (`open-questions.md`) leżą obok indeksu i są w nim też wydrukowane
  w całości. Sekcja „Kwestie otwarte" to tabela
  `| Czego dotyczy | Krok | Status | Komentarz |` z tym samym zestawem
  statusów co w projekcie widoku.
- **db-playground-schema** — export of DB Playground: summary table, one section per
  table/collection (columns with types, constraints, indexes), relations
  table + Mermaid ER diagram for SQL sources. Extra frontmatter:
  `sourceFormat` (sql/csv/json), `dialect`, `tables`. Source of truth: the
  dump/profile file and `<source>.db-playground.json` beside it. Documents
  written before the rename carry `type: db-schema`; it is still recognised
  on read.
- **confluence-page** — free-form body; only the frontmatter is contractual.

A document does not need every section — but a section it does have must use
the canonical name, or importers and `/handoff-package` will not see it.

## Split documents (index + parts)

`view-design` and `api-design` are written as **an index plus one file per
part**. The other types are single files.

**The index** carries the artifact's frontmatter (`type`, `generator`,
`generated`, `source`, counters, `managed`), the H1, and the links. A view
index has no content of its own — every section is a link. A flow index is
read end to end: it prints the contract and the open questions in full and
links only the steps, because they are the long part.

| Typ | Katalog | Kształt spisu |
|---|---|---|
| `view-design` | `sections/` | `N. [tytuł](sections/plik.md)` pod nagłówkiem spisu treści, N = pozycja w spisie |
| `api-design` | `parts/` | `- [tytuł](parts/plik.md)` pod `## Przebieg`, po diagramie Mermaid — linkowane są wyłącznie kroki |

**A part** is one block of the document — its own `## ` heading included —
under a short frontmatter. For a view that block is **one section of the view**,
carrying its components together with their mappings, actions, columns and
validation findings; only the endpoint catalogue and the open questions cut
across sections and stay separate.

```yaml
type: view-design-part   # albo api-design-part
part: section-01           # widok: section-NN, albo endpoints · open-questions
                           # przepływ: request · step-01 · step-02 · … ·
                           #           responses · open-questions
parent: ../login.md        # albo ../api.md
generator: ui-design@0.14.0
generated: 2026-08-16
managed: true              # tylko gdy indeks też jest managed
```

**File names.** A view design has **one file per section of the view**,
numbered (`section-01.md`) rather than named after it — without a heading in
the mockup a section's name is built out of its first few labels, so adding one
field would rename the file. Each carries that section's components together
with their mappings, actions, columns and validation findings — a part is a
subject, not an aspect. Two files are not sections and have fixed names:
`endpoints.md` (the catalogue of operations the view calls, cross-cutting
because one endpoint serves several sections) and `open-questions.md` (one
list, with each component name linking into the section that describes it).
Deliberately without an ordinal in the name, so a section that empties out does
not rename the ones that stay. A flow's `parts/` holds `step-NN-<type>.md` and
nothing else — the ordinal because order is the content there, the step type
because file names are English everywhere in the tree and a step's title is
written in the analyst's own language. `request.md`, `responses.md` and
`open-questions.md` have fixed names and sit **next to the index**, not in
`parts/` — they are not steps of the process — still typed `api-design-part`,
with the open questions last in reading order, after everything the design
does know.
Client libraries are not a part: the pom fragment lives in
`solution-design/external/<klient>/dependency.xml` and the step that calls the service
links to it.

**Regeneration.** Parts are written together with the index: a section with
nothing to report gets no file, and a file the index no longer links is
deleted. So a part legitimately carries an older `generated:` than its index —
it means the section did not change, not that it is stale.

Reading rules for every consumer: **count and link the index, read the parts**.
A single-file document (hand-written, an older export, a page fetched back from
Confluence) is equally valid — it simply has no links to follow.

## Dependency fragments (`solution-design/external/<klient>/dependency.xml`)

Libraries the implementation will need are **never embedded in markdown as
code blocks** — a docs review would rightly flag them, and pasted XML drifts.
Instead each set lives as a plain XML fragment file, exactly as it will be
pasted into `pom.xml`:

- Content: one or more `<dependency>` elements (a `<dependencies>` wrapper is
  allowed but not required). Nothing else — the file must stay paste-ready.
- Provenance goes in an XML comment header, since XML has no frontmatter:
  `<!-- feature: <id> · added: YYYY-MM-DD · why: <one line> -->`.
- A markdown document that needs to mention dependencies links to the file
  (`[Zależności](../../external/<klient>/dependency.xml)`) instead of quoting
  it — and often no link is needed at all, because `/handoff-package` collects
  the fragments into the package on its own.
- The folder is the client the libraries belong to (`external/crm-client/`),
  named by the author, never generated; the file inside is always
  `dependency.xml`, so a link to it is predictable from the client name alone.
