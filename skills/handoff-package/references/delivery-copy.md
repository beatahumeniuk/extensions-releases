# Delivery copy (optional, into the developer's repo)

The contract for Step 7 of `/handoff-package` — read only when the user gave
a delivery target. Everything else the skill writes is specified in
`handoff-schema.md`.

When the team keeps per-feature docs in the developer's repository (e.g.
`docs/features/<feature-id>/` with `adr.md`, `spec.md`, `tech.md`), the
handoff can additionally be **delivered** there:

```
<dev-repo>/docs/features/<feature-id>/
  spec.md        # copy of the change's spec.md — a THIN INDEX, never a container
  test-spec.md   # copy of the change's test-spec.md
  solution-design/      # the depth: delivered copies of the scoped solution-design/ artifacts
    views/<view>/<view>.md      # the index…
    views/<view>/sections/*.md  # …and its sections, beside it
    flows/<flow>/api.md         # likewise for a flow design…
    flows/<flow>/parts/*.md     # …and its parts
    contracts/<name>.md
    db/<name>-schema.md
    dependencies/<name>.pom.xml
```

A split design keeps its package folder in the delivery: the links inside an
index are relative to it (`sections/section-01.md`), so a flattened copy would arrive
with every link broken. Single-file artifacts (contracts, mappings, schemas,
dependency fragments) are delivered as the single files they are.

`spec.md` is deliberately small: intent, scope, stan zastany, reading order
and links — it never inlines tables or rules that live in the artifacts.
Whatever does not fit a paragraph belongs in `solution-design/` as a whole file,
so the feature folder scales with the feature while `spec.md` stays a
two-page entry point.

Rules:

- The canonical home stays `context/changes/<feature-id>/` (and `solution-design/`) in
  the analyst repo — the delivery is an export, refreshed on re-runs. Copies
  across repos are fine: this is a different repository, and the copies are
  machine-refreshed, never hand-edited.
- Links inside delivered `spec.md`/`test-spec.md` are rewritten to relative
  `solution-design/...` paths, so the feature folder works offline and in merge
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
