---
name: handoff-package
description: >
  Assemble a committed handoff change folder (context/changes/<feature-id>/,
  10x naming) for a developer and a tester from the markdown in solution-design/
  (view designs, endpoint flows, contracts, field mappings, dictionaries).
  Cross-checks the artifacts, writes change.md + spec.md + test-spec.md with
  links into solution-design/, routes every gap to open questions, and stops. Use when
  the user says "przygotuj pakiet dla programisty", "zbuduj handoff",
  "przygotuj change dla zespołu", "prepare handoff package",
  "package the design for dev/QA".
---

# Handoff Package

Turn the analyst artifacts in `solution-design/` into a **change folder committed to the repo** — `context/changes/<feature-id>/` (10x naming: `change.md`, `spec.md`, `test-spec.md`) — that the developer's and tester's agents read straight from the repository. No out-of-band handover, no copies: artifacts stay where they were generated and the change folder **links** to them — one repo, one home per fact. The skill distills existing evidence — it invents nothing: every statement traces to an artifact or to the user's answer, and every gap becomes an explicit open question.

**Inventory-first, not stage-first.** There is no required upstream process: the team enters at any point, parts of the work may already be built, and documentation often trails code. The skill starts from what exists (the inventory), computes gaps against the requested deliverable only, and never demands artifacts "earlier stages should have produced". Already-implemented parts belong in `change.md` → "Stan zastany", not in scope.

The output contract lives in `references/handoff-schema.md`. Read it before writing anything; its section names and status literals are parser literals.

## Input resolution

`$ARGUMENTS` is a feature id (English, kebab-case — it becomes the folder name) optionally followed by artifact hints:

- `/handoff-package login-flow`
- `/handoff-package login-flow views/login views/reset-password`
- empty → **Ask the user** for the feature id. Do not guess.

Artifacts are discovered **by their frontmatter `type:`, scanning `solution-design/`** — not by folder. The tree is organised by subject rather than by tool, so a view design, the flows of the endpoints it calls and the dictionaries they use sit in different branches:

| `type:` | Gdzie leży |
|---|---|
| `view-design` | `solution-design/ui/<widok>/<widok>.md` (indeks; sekcje w `sections/*.md` jako `view-design-part`) |
| `api-design` | `solution-design/api/<ścieżka>/api.md` (indeks; kroki przepływu w `parts/*.md`, a `request.md` / `responses.md` / `open-questions.md` obok indeksu — wszystkie jako `api-design-part`) |
| `contract` | `solution-design/api/contracts/<nazwa>.md` |
| `field-mapping` | `solution-design/api/<ścieżka>/<cel>.mapping.md` |
| `value-dictionary` | `solution-design/dictionary/<nazwa>.md` |
| `db-playground-schema` | `solution-design/db/model/<źródło>-schema.md` |
| `confluence-page` | gdzie ustawiono `confluenceToMd.downloadFolder` (np. `solution-design/confluence/<slug>.md`); domyślnie strona ląduje tam, gdzie pracował analityk — poza `solution-design/` skanowanie jej nie znajdzie |

**A design is an index plus its parts, and the artifact is the whole.** The
file carrying `view-design` / `api-design` is the index: identity,
frontmatter, counters and a list of links. The `-part` files it links —
`sections/*.md` next to a view, `parts/*.md` next to a flow — are that same
artifact's sections, and they are where the content is. So:

- **count and link the index**, never a part; a part listed as an artifact of
  its own turns one view design into seven rows and seven freshness checks;
- **read the parts for evidence** — endpoints, actions, open issues and
  validation findings are in the section files, and an index read alone looks
  like an empty design;
- a `-part` whose `parent:` resolves to nothing is an **orphan** (its index was
  deleted or moved): report it, do not promote it.

A file without recognizable frontmatter is listed but never auto-included.
`docs/` is not scanned: it is the hand-written deliverable, and a handoff is
assembled from evidence, not from another summary of it.

## What this skill does NOT do

- Does not read or reference the developer's implementation repo — the change carries **evidence and intent**, never `file:line` anchors into implementation code (signal, not knowledge).
- Does not copy artifacts into the change folder — it links to their home in `solution-design/`. Copies inside one repo are duplication a docs review would rightly flag.
- Does not read or write `docs/`. That tree is written by hand, for a different audience, and nothing here belongs in it.
- Does not commit or push. It writes files; version control stays in the user's hands.
- Does not edit, fix, or regenerate any source artifact. A defect found in an artifact becomes an open question or a "regenerate" recommendation, not an edit.
- Does not resolve open issues, gaps, or contradictions on its own — they route to `open-questions.md` with the user deciding `Block: yes|no` for anything ambiguous.
- Does not write test plans or code. `test-spec.md` is distilled evidence, not a strategy (that is a downstream skill's job).
- Does not auto-chain into any other skill. It writes the package and stops.

## Procedure

### Step 1 — Inventory

List every markdown file under `solution-design/` with frontmatter `type`, `source`, `generated`, plus every Maven fragment under `solution-design/external/<klient>/dependency.xml` (provenance from its XML comment header). Present a table grouped by type. Note files with missing/foreign frontmatter as excluded.

**One row per design, not per file.** A `type` ending in `-part` is not an artifact: fold it into its `parent:` and, if it helps the user pick scope, say how many parts the index has (`login.md (6 sekcji)`). Orphan parts get their own line under excluded, with the reason.

### Step 2 — Select scope (interactive, max 2 questions)

Propose the artifact set for the feature: start from the view(s) matching `$ARGUMENTS` hints or the feature id, then pull in **referenced** artifacts — contracts whose endpoints appear in the views' "Dane"/"Akcje" sections, mappings whose `source:` points at a contract in the set or whose target schema name appears in a contract's `## Model danych`, Confluence pages the user points at, and dependency fragments whose header `feature:` matches the feature id or which a scoped artifact links to. Show the proposed set with a one-line reason per artifact and **Ask the user** to confirm/adjust. If nothing matches the feature id, ask instead of guessing.

The references live in the section files, so follow the index links rather than grepping the index — and follow them rather than guessing file names, because a view's section files are numbered and the numbers shift when a section is added — the index lists titles and links, and nothing else. Scoping a design in always scopes in all of its parts; they are not selectable separately.

### Step 3 — Cross-check (self-review before writing)

Run these checks on the confirmed set; each failure becomes an open question (`Block` per severity) — none of them silently blocks the package except the abort condition:

1. **Endpoint coverage** — every endpoint named in a view design (`sections/endpoints.md`, and the section files that map onto it) has a contract in the set that documents it. Missing → Q with `Block: yes` for endpoints used by actions, `no` for display-only.
2. **Mapping linkage** — every mapping's target schema is used by a contract or view in the set; orphan mappings are surfaced (include? drop?).
3. **Freshness** — for every artifact compare frontmatter `generated:` with the last-modified date of its `source:` (git/filesystem, when resolvable). Source newer → mark `stale` in the `change.md` artifact table and add a "regenerate with <generator>" Q. **Judge freshness at the index only.** A part is rewritten solely when its own content changed, so an untouched section legitimately carries an older `generated:` than the index — comparing part dates against each other would report a whole shelf of false staleness.
4. **Open issues import** — collect every "Kwestie otwarte" row from view designs (`sections/open-questions.md`) **and from flow designs** (`open-questions.md` next to `api.md` — a flow's `parts/` holds only its steps), plus every `## Braki` entry from mappings; they become `Q-NN` entries verbatim. Both designs use the same five statuses, so filter them the same way: `Do uzupełnienia` / `Do ustalenia` / `Czeka na dane` are still open, `Nie dotyczy` / `Rozwiązane` are not and do not become questions.
5. **Completeness of the set** — a view whose actions call an endpoint with no request/response samples, a contract in the set referenced by nothing — surface, ask.
6. **Mockup link** — every view in scope carries a `mockup:` frontmatter key. Missing → collect the Figma link in the interview (the mockup always exists); it lands in the `change.md` artifact table, never as an open question.
7. **Parts resolve** — every link in an index points at a file that exists, and every `-part` file in the package is linked by its index. A missing target means the design was hand-edited or half-copied; a file nothing links is a leftover a reader would trust by mistake. Either way: Q with `Block: no`, and a "regenerate with <generator>" recommendation — never patch the index by hand.
**Abort condition:** if more than half the artifacts are `stale` or a view design in scope has `status: draft` with 0% coverage, stop before writing and report — a change built on that would hand off noise.

### Step 4 — Interview (max 3 questions, with Recommends)

Only what artifacts cannot answer, one question at a time, each with a recommended option first:

1. **Stan zastany i zakres** — "Co z tego już istnieje/działa (kod, wdrożone części), a czego świadomie NIE robimy w tej iteracji?" Answers feed `mode:` (new/update/mixed), the "Stan zastany" section, and "Czego NIE robimy". For `mode: update`, first check the artifact's git history (previous committed version of the `solution-design/` file vs current) and present the diff summary as the proposed delta scope — the user confirms or trims it. Never guess the state of code — unconfirmed claims become Open Questions.
2. **Block flags** — for gaps where severity is ambiguous, batch into one question: which of these block the developer?
3. **Nazwa funkcjonalności** — only if the feature id doesn't translate into an obvious Polish title (never auto-fill a human-facing name the user didn't give).

Skip any question the artifacts or `$ARGUMENTS` already answer. Never exceed 3.

### Step 5 — Write the change folder

Create `context/changes/<feature-id>/` per `references/handoff-schema.md`, in this order:

1. **open-questions.md** — all `Q-NN` from Steps 3–4.
2. **test-spec.md** and **spec.md** — distilled per schema; every claim links (repo-relative) to its artifact in `solution-design/`. Nothing is copied — `solution-design/` stays the single home of every artifact, including dependency fragments and PNG previews.

   **Link at the depth of the claim.** Referring to the design as a whole (the artifact table, "the login view") links the index; citing one thing (a validation finding, a table's columns, a processing step) links the part that holds it — `.../login/sections/section-01.md`, `.../wnioski/parts/step-03-mapowanie.md`. That is what the split bought: a reader lands on the evidence instead of on a table of contents.
3. **change.md** — last, so its counters (`blockers`, per-artifact freshness) are true. `status: ready` only when `blockers: 0` and nothing is `stale`.

### Step 6 — Self-review before finishing

Verify, and fix before reporting: every repo-relative link in the change folder resolves inside the repository — including the ones that point into a `sections/` or `parts/` file, which is exactly where a hand-typed path goes wrong; every section literal from the schema is present; no `file:line` anchors into implementation code; no invented facts (check every risk row cites an `solution-design/` file); `change.md` counters match reality (artifact count counts designs, not their parts). If a check fails and can't be fixed from the evidence, downgrade to `status: draft` and add a Q — never patch silently with guesses.

### Step 7 — Optional delivery to the developer's repo

Only when the user provided a delivery target (a path to the developer
repo, in `$ARGUMENTS` or when asked for): write
`docs/features/<feature-id>/` **in that repo** per the "Delivery copy" section
of the schema — `spec.md` and `test-spec.md` (links rewritten to relative
`solution-design/...` paths) plus an `solution-design/` folder holding copies of every scoped
artifact from our `solution-design/` tree, each stamped with `deliveredFrom:` (feature id + commit sha when the
scoped artifacts are committed, else the delivery date + a warning in the
report). **A split design is delivered whole and in shape**: the index keeps
its own folder and its `sections/` (or `parts/`) beside it, because the links
inside it are relative — flattening the package would deliver an index whose
every link is broken. Never overwrite the developer's own files (`adr.md`,
`tech.md`, or any file without `deliveredFrom:` frontmatter). No target
given → skip this step silently.

### Step 8 — Hand off and STOP

Report: change folder path, artifact count, blockers count, freshness summary, the delivery path when Step 7 ran, and a note that the folders are ready to commit (committing is the user's call). Print the recipient prompt from `change.md` → `## Start` as the final code block, so the user can hand it to the recipient's agent. **Stop.** Do not propose running other skills unless asked.

## Edge cases

- **`solution-design/` missing or empty** — stop; point at the generating extensions (API Designer, Schema Mapper, UI Design, Confluence to md) and their export commands.
- **Artifact without frontmatter** — list as excluded with reason `brak frontmattera`; offer to include manually only if the user insists (then mark `Status: unknown`).
- **Re-run for an existing feature id** — read the existing change folder first; propose refresh (update links, merge new Qs, keep resolved Qs annotated) instead of blind overwrite. Copy the previous `change.md` to `change-<YYYY-MM-DD>.md` when counters change.
- **Two changes share an artifact** — both link the same `solution-design/` file; that is the point of links over copies.
- **A single-file design (no `sections/` / `parts/`)** — read it as it is. Documents written before the split, hand-written ones adopted with `generator: manual`, and pages fetched back from Confluence all arrive whole; the sections are `## N.` blocks inside one file instead of files. Nothing here requires the split — only the reading path differs.
- **The user points at a part** (`.../sections/section-01.md` as an artifact hint) — take it as pointing at its `parent:` and say so in one line. The hint is about the view, not about one of its files.
- **User asks for dev-only or test-only** — write the whole change folder anyway but say which file is theirs; the other audience file costs nothing and keeps the contract stable.
