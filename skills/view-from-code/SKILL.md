---
name: view-from-code
description: >
  Fill in a UI Analysis view analysis from the implemented code:
  component types, validation rules, visibility conditions, test ids, the
  endpoints the view calls — every claim backed by file:line, everything
  uncertain routed to open issues. Writes view-mapping.json into a package
  the analyst already imported from Figma; never invents components or ids.
  Use when the user says "opisz widok z kodu", "wygeneruj analizę widoku
  z implementacji", "describe this screen from code", "reverse-engineer the
  view".
---

# view-from-code

The screen exists, the analysis does not. This skill reads the
implementation and fills in `analysis/ui/<package>/view-mapping.json` — the
analyzer's own input — so the analyst opens a seeded analysis, verifies it,
and exports the markdown from there.

**Figma is the anchor.** The view's structure and every component id come
from the Figma import, never from this skill. You match your findings onto
components that already exist. Read `references/contract.md` before writing.

## Preconditions — check first, cheaply

`analysis/ui/<package>/analysis-model.json` must exist. If it does not, stop:

> Ten widok nie jest jeszcze pobrany z Figmy. Zrób najpierw „Pobierz widok
> z Figmy", potem uruchom mnie ponownie.

Do not create the package. Do not invent ids. A view analysis not anchored
to the mockup cannot be merged with one later.

## What this skill does NOT do

- Does not modify code. Reading only.
- Does not write `view.json` — that is the Figma import's output.
- Does not write markdown — the extension exports it on save. Writing it
  here would create a second, competing rendering.
- Does not overwrite what a human entered. An existing value in
  `view-mapping.json` wins; you fill gaps only.
- Does not guess business intent. Code shows WHAT the view does; WHY —
  business rules, wording, dictionary meanings — becomes an open issue with
  a `plik:linia` pointer.

## Procedure

### 1. Catalogue (one query, not a file read)

```bash
jq -c '[.sections[] | {section: .name, elements: [.elements[] | {id: .figmaNodeId, name, label}]}]' \
  analysis/ui/<package>/analysis-model.json
```

That is what you match against. Do not read the file — it carries geometry,
inner texts and properties you do not need.

### 2. Evidence sweep — extraction, not reading

Never read a component or template as a file. Pull values with `rg -o`; see
`references/angular.md` for the command set (templates, child selectors,
`data-testid`, `Validators.*`, store selectors and dispatches, HTTP calls).

**One subcomponent per pass.** Get the child selector list first, then
process each child separately, appending findings to a scratch file. The
window never holds the whole tree — that is the single biggest saving in a
component-heavy Angular view.

For a wide tree (4+ subcomponents) spawn read-only sub-agents, one per
subcomponent, each returning only a findings table with `file:line`. Their
context is separate; only the table costs you.

### 3. Match to the catalogue

In this order, and stop at the first that hits:

1. **Test ID** — `data-testid` in the template equals `testId` in the
   analysis. Certain.
2. **Name** — the extension's own `NameMatcher`
   (`ui-analysis/vscode-extension/src/core/matching/NameMatcher.ts`):
   diacritics stripped, camelCase split, PL↔EN suggestions. Do not write
   your own — two normalisations give two different matches for the same
   view, and the analyst cannot tell why one run hit and the next missed.
3. **Nothing** — do not guess. Write an open issue saying what was found and
   where.

### 4. Write `view-mapping.json`

Per `references/contract.md`. Only evidenced fields — no placeholders.
Anything inferred rather than read gets `suggested: true` so the analyst
sees `_(auto)_` and knows what to confirm.

Merge, do not replace: read the existing file if there is one and keep every
value already in it.

### 5. Validate your own output

Before saying you are done:

```bash
npx tsx scripts/validate-mapping.ts \
  analysis/ui/<package>/view-mapping.json \
  analysis/ui/<package>/analysis-model.json
```

Non-zero exit means something you wrote will be lost or — worse — silently
replaced when the analyzer reads it. A misspelled `role` does not fail: it
turns the binding around and puts the field on the other side of the API. A
misspelled issue `status` deletes the whole open question, which is where
everything you could not establish was parked.

Fix and re-run. Do not report success on a non-zero exit; the analyst must not
be the mechanism that discovers this.

### 6. Report and stop

Package path, how many components were matched, how many rules were found,
how many open issues were raised, and what is next — „Otwórz widok" in UI
Flow Designer, verify, save. Do not run other skills.

## Token budget

The CLI runs outside the context window; only its result costs anything.
Every file read whole instead of queried is wasted budget.

- `field-keys.json` is 31 KB. Query the types actually present instead:
  `jq -c '.byType | with_entries(select(.key | IN("Input","Button")))'`.
  1.1 KB for four types — 27× less.
- `analysis-model.json` — the `jq` in step 1, never the file.
- Templates and components — `rg -o` returns the value, not the line.
- One subcomponent per pass, findings appended to a file.

A view of ~30 components across ~4 subcomponents lands around 6–9k tokens.
Reading the same tree as files is 15–25k before any reasoning.

## Edge cases

- **Validation only server-side** — an open issue, never copied into the
  view's rules as if the front-end enforced it.
- **Feature flags / A-B branches** — describe the enabled branch, flag the
  other with the flag name.
- **Generated or obfuscated frontend** — stop; the code is not readable
  evidence. Recommend describing from the running application.
- **Component in the code with no counterpart in the mockup** — an open
  issue. The mockup is the anchor; the code disagreeing with it is a finding,
  not a licence to add components.
