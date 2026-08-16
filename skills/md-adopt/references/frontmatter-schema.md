# Docs markdown contract — frontmatter + tree

The single source of truth for the structured-markdown format used across the
analyst toolchain (the VS Code extensions, `/docs-review`, `/handoff-package`,
`/md-adopt`). Keys, values and section names below are parser literals.

Frontmatter keys, status values, and ALL file/folder/package names (slugs,
feature ids, package directories) are English; body headings, prose and
display names inside documents are Polish.

## Gdzie trafiają adoptowane pliki

Dwa drzewa, jedna zasada: **`analysis/` jest generowane i tam wchodzi adopcja,
`docs/` jest pisane ręcznie i żadne narzędzie ani skill tam nie zapisuje.**
`docs/` to dokumentacja docelowa dla programisty i testera — recenzowana,
trwała, i nie może zginąć pod przebiegiem narzędzia.

```
analysis/
  ui/<widok>/<widok>.md         # type: view-analysis   (UI Analysis)
  api/<ścieżka>/api.md          # type: api-analysis    (Logic Analysis)
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
| `type` | yes | `contract` · `field-mapping` · `view-analysis` · `api-analysis` · `db-playground-schema` · `confluence-page` | what the document is |
| `generator` | yes | `<tool>@<version>` or `manual` | `manual` = written by a person, editable |
| `generated` | when known | `YYYY-MM-DD` | when the CONTENT was produced; never guessed |
| `adopted` | adoption only | `YYYY-MM-DD` | when `/md-adopt` brought the file into the format and `generated` is unknown |
| `source` | when known | workspace-relative path or URL | the source of truth this document renders/describes |
| `sourceId` | per type | page id, record name | identity within the source system |
| `mockup` | view-analysis | Figma URL (with `node-id`) | link to the mockup the view was analyzed from; recorded by the Figma import and carried through every round trip |
| `operation` | contract only | operation label | per-service narrowed export |
| `space` | confluence only | space key | |
| `status` | per type | `draft` · `complete` | computed by generators; set by hand for manual docs |
| `components` / `openIssues` / `coverage` | view-analysis only | numbers | counters computed at export |
| `managed` | tool exports only | `true` | fully regenerated from `source` — **never hand-edited**; a hand-written file must NOT carry it |

The `managed: true` / `generator: manual` distinction is load-bearing:
`/docs-review` refuses content edits on managed files (fix the source,
regenerate) and allows them on manual ones.

## Canonical section sets per type

Used by generators, by `/md-adopt`'s optional restructuring, and by importers.
H1 is always the document title.

- **contract** — meta table under H1 (`| Wersja kontraktu | … |`, `| Format | … |`), then `## Endpointy` (`### <tag>` → `#### `METHOD /path``) and/or `## Operacje` / `## Elementy główne`, then `## Model danych` (`### <Klasa>` + fields table `| Pole | Typ | Wymagane | Ograniczenia | Opis |`).
- **field-mapping** — meta table, `## Źródła`, `## Mapowania pól` (`### <grupa>.*` + table `| Pole docelowe | Typ | Liczność | Źródło | Pole źródłowe | Konwersja / agregacja | Gdy NULL | Status |`), optional `## Braki`, `## Notatki`. *Being phased out:* Schema Mapper is absorbed by Logic Analysis (mappings become flow steps); the type stays valid for existing exports, new mappings are documented inside `api-analysis`.
- **view-analysis** — numbered `## N. <sekcja>`; nazwy sekcji zależą od
  ustawień zespołu, więc rozpoznawaj po kształcie: sekcja struktury to ta,
  w której są wiersze komponentów ``- **Etykieta** (`Typ`) — reguły``,
  a `### <sekcja> _(typ)_` otwiera sekcję w jej obrębie. Numeracja jest
  dynamiczna — sekcja bez treści nie pojawia się wcale, więc numery nie są
  stałe.
- **api-analysis** — export of the Logic Analysis extension (flow analysis of
  a process/service): H1 `# API: <nazwa>`, numbered step sections
  (walidacja, odczyt/zapis bazy, mapowanie, wywołanie usługi zewnętrznej,
  przekształcenie, event Kafka), response sections per HTTP status, closing
  „Biblioteki klientów". Source of truth: `analysis/api/<ścieżka>/api.json`.
  Documents written before the rename carry `type: process-flow-analysis`
  and H1 `# Analiza flow: <nazwa>`; both are still recognised on read.
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

## Dependency fragments (`analysis/external/<klient>/dependency.xml`)

Libraries the implementation will need are **never embedded in markdown as
code blocks** — a docs review would rightly flag them, and pasted XML drifts.
Instead each set lives as a plain XML fragment file, exactly as it will be
pasted into `pom.xml`:

- Content: one or more `<dependency>` elements (a `<dependencies>` wrapper is
  allowed but not required). Nothing else — the file must stay paste-ready.
- Provenance goes in an XML comment header, since XML has no frontmatter:
  `<!-- feature: <id> · added: YYYY-MM-DD · why: <one line> -->`.
- A markdown document that needs to mention dependencies links to the file
  (`[Zależności](../dependencies/<name>.pom.xml)`) instead of quoting it —
  and often no link is needed at all, because `/handoff-package` collects
  the fragments into the package on its own.
- File naming follows the artifact it supports (feature id, contract name);
  the name is given by the author, never generated.
