# flow-from-code — output format

The output is a **Logic Analysis package**, not markdown: the Logic Analysis
extension's source of truth is `analysis/api/<endpoint>/api.json` (+ samples), and
markdown is what Logic Analysis itself exports after the analyst verifies the draft
there. Emitting the package means the analyst opens Logic Analysis on a seeded,
step-complete analysis instead of retyping anything.

## Files

```
analysis/api/<endpoint-path>/
  api.json         # the draft analysis — this skill's main output
  request.json     # minimal sample payload from the request DTO
  response.json    # minimal sample payload from the success-response DTO
docs/dependencies/<client>.pom.xml   # one per client library found
```

Existing files always win: skip any file that already exists and say so.
Sample skeleton rules: typed placeholders (string → `""`, boolean → `false`,
array → `[]`, object → nested), fields sorted alphabetically, 2-space
indent, trailing newline.

## api.json — the draft shape

Emit only the fields below; Logic Analysis' `normalizeFlow` fills the rest. Every
step gets a unique `id` string (e.g. `"code-1"`, `"code-2"`).

```json
{
  "version": 1,
  "name": "<nazwa>",
  "endpoint": "<METODA /ścieżka>",
  "description": "Szkic wygenerowany z kodu (flow-from-code, <YYYY-MM-DD>). Źródło: <ścieżka handlera>.",
  "request": { "sample": { "format": "json", "body": "<treść request.json>" }, "notes": "" },
  "responses": [
    { "kind": "success", "httpStatus": "200", "description": "", "sample": { "format": "json", "body": "<treść response.json>" } },
    { "kind": "error", "httpStatus": "400", "description": "Kiedy występuje: <warunek z kodu>", "sample": { "format": "json", "body": "" } }
  ],
  "steps": [ ...w kolejności wykonania... ],
  "clients": [ { "name": "<klient>", "dependency": "<zawartość fragmentu pom>", "notes": "" } ]
}
```

Step objects, per Logic Analysis' vocabulary (emit only evidenced fields):

- `{ "id", "type": "validation", "title", "description", "rules": [{ "check", "onFail" }] }`
- `{ "id", "type": "dbRead", "title", "datasource", "sql", "resultUsage" }` /
  `"dbWrite"` without `resultUsage`
- `{ "id", "type": "mapping", "title", "target", "entries": [{ "from", "to", "transform", "whenNull" }], "notes" }`
- `{ "id", "type": "externalCall", "title", "serviceName", "clientName", "operation", "description", "errorHandling" }`
  (+ `requestSample`/`responseSample` as `{ "format", "body" }` when the code
  shows payloads; mappings as `requestMapping`/`responseMapping` blocks with
  `entries`)
- `{ "id", "type": "transformation", "title", "description", "logic" }`
- `{ "id", "type": "kafkaEvent", "title", "topic", "description", "sample" }`
- `{ "id", "type": "other", "title", "description" }`

## Open questions

The package has no "Kwestie otwarte" section, so:

- a question tied to a step goes into that step's `description` (or
  `notes` for mapping steps), prefixed `OTWARTE:` and ending with the
  `plik:linia` evidence;
- the full list is printed in the final chat report, so the analyst sees it
  before opening Logic Analysis.

`plik:linia` never appears anywhere else in the package — samples and SQL
must stay paste-ready.
