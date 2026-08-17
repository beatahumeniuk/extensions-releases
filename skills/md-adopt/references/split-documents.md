# Split documents (index + parts)

The full contract for a design split into an index plus part files. Read this
before proposing or executing a split (Krok 3 of `/md-adopt`); for everyday
reading and classification the summary in `frontmatter-schema.md` is enough.

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
parent: ../login.md        # albo ../api.md; część leżąca obok indeksu
                           # (request · responses · open-questions przepływu)
                           # ma parent bez ../
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
