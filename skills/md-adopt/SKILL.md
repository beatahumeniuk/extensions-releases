---
name: md-adopt
description: >
  Adopt existing markdown files into the analysis/ tree: detect the
  document type, add or repair the YAML frontmatter, move the file to its
  place in the analysis/ tree, and optionally align section names to the
  canonical set — always with approval, never inventing metadata. Use when
  the user says "dostosuj te md do formatu", "dodaj frontmatter",
  "wciągnij ten plik do analizy", "znormalizuj dokumentację md",
  "adopt this markdown", "bring these files into the docs format".
---

# md-adopt: Bring Existing Markdown Into the analysis/ Tree

The team enters the process at any point: plenty of markdown already exists —
written by hand, exported by older tool versions, pasted from Confluence
before the pipeline existed. This skill is the on-ramp: it brings such files
into the structured format (frontmatter + location + canonical section names)
so `/docs-review`, `/handoff-package` and the extension importers can see
them — **without regenerating or rewriting their content**.

The format contract lives in `references/frontmatter-schema.md`. Read it
before touching any file; it defines the keys, the tree, and the per-type
section sets.

## What this skill does NOT do

- **Never writes into `docs/`.** That tree is the deliverable written by
  hand for developers and testers; no tool and no skill touches it. Adoption
  lands in `analysis/`. A file already sitting in `docs/` is left alone.

- Does not regenerate tool exports. If a file is an outdated copy of
  something an extension can export (a contract md whose spec still exists,
  a view analysis whose `view.json` is present), the right move is
  **re-export from the tool**, not adoption — say so and stop for that file.
- Does not mark adopted files `managed: true`. That flag is reserved for
  tool-generated renderings; hand-written files get `generator: manual` and
  stay editable.
- Does not invent metadata. Unknown `source` or `generated` is omitted (or
  asked about once), never inferred from the filename or the content's style.
  The adoption date goes in `adopted:`, not `generated:`.
- Does not rewrite prose, translate, merge duplicates, or resolve
  contradictions — that is `/docs-review`'s territory.
- Does not modify any file without showing the proposed change first.

## Input resolution

`$ARGUMENTS`: one or more file paths, a folder, or empty.

- Files/folder given → those are the candidates.
- Empty → scan the workspace for `*.md` outside `analysis/` and `docs/`
  (excluding
  `node_modules/`, `README*`, `AGENTS*`, `CLAUDE*`, `.cursor/rules/`,
  `.github/copilot-instructions.md`, `*.mdc`, `.windsurfrules`, and
  `context/`) plus files inside `analysis/` with missing/invalid frontmatter.
  Present the candidate list; the user picks.

## Procedure

### Step 1 — Classify

Detect the `type` from the document's **shape, not the wording of its
headings**. The exports are translatable — a team can set its own texts, and
the same document exists in English and in Polish — so a heading match works
only until someone changes a setting, which is exactly when it is not needed.
Match on what the format guarantees:

| Typ | Kształt, po którym poznajesz |
|---|---|
| view-analysis | wiersze komponentów ``- **Nazwa** (`Typ`)`` pod nagłówkiem `##`, gdzie `Typ` jest jednym z typów analitycznych |
| field-mapping | tabela mapowań: kolumna ze ścieżką pola źródłowego i docelowego w grawisach |
| contract | tabela modelu danych z kolumnami typu i ograniczeń plus lista operacji |
| api-analysis | blok kodu z sekwencją kroków `1. <rodzaj>` i gałęziami `success`/`error` |
| value-dictionary | tabela dwukolumnowa kod → opis, przy `type: value-dictionary` we frontmatterze |
| confluence-page | blok `confluence:` we frontmatterze albo URL źródłowy |

Frontmatter, jeśli jest, wygrywa z heurystyką — `type` zapisany w pliku jest
deklaracją autora, nie zgadywanką.

A file matching nothing is reported as "poza formatem" and skipped — adoption
is not forced.

### Step 2 — Check for a living source

For each classified file, look for its source of truth in the workspace
(spec file, `.mapping.json`, `view.json`). Found and newer than the md →
recommend re-export from the tool instead of adoption. Found and the md is
just a copy of a current export → recommend deleting the stray copy and
pointing at the export. Not found → proceed with adoption.

### Step 3 — Propose, per file

Show a compact proposal: detected `type`, target path in the analysis/ tree,
the exact frontmatter block to be added (with every unknown key omitted and
listed as "nieznane — pominięte"), and — if section names deviate from the
canonical set — the rename list (`## Pola` → `## Model danych`). Body content
is never changed beyond section-heading renames and dependency extraction
(below), each only when the user opts in.

**Dependency extraction.** If the body embeds a Maven fragment (a code block
or raw XML containing `<dependency>` elements), propose moving it out: write
the fragment to `analysis/external/<klient>/dependency.xml` (client proposed
from the
document, confirmed by the user) with the provenance comment header per the
schema, and replace the block in the md with a link to it. This keeps XML out of the
markdown — a docs review flags embedded code, and pasted XML drifts.

Ask once, in batch: one question listing every file (with its proposed
target and renames); the user approves all, or a subset by naming files.

### Step 4 — Apply

For approved files: write the frontmatter, move the file (real move, so git
tracks the rename), apply approved heading renames, and update links that
pointed at the old path from within analysis/. One file = one logical change.

### Step 5 — Report and STOP

List adopted files (old path → new path), skipped files with reasons, and
any recommended re-exports. Suggest `/docs-review analysis/` as the natural next
check — but do not run it.

## Edge cases

- **File already conforming** — report "zgodny, bez zmian"; never rewrite a
  correct frontmatter just to reorder keys.
- **Frontmatter present but foreign** (Jekyll, Docusaurus) — preserve the
  existing keys, add the contract keys alongside; never delete keys you do
  not own without approval.
- **A `managed: true` file with a live generator** — never adopt-edit it;
  it belongs to its extension (regenerate instead).
- **Polish/English mixed content** — leave the language alone; adoption is
  about structure, not prose.
- **Huge folder** — process in batches of ~10 with a checkpoint list, so an
  interrupted run can resume from the report.
