---
name: flow-from-code
description: >
  Reverse-engineer an implemented service endpoint into a draft Logic Analysis
  package (analysis/api/<endpoint>/api.json + request.json + response.json):
  validations, database reads/writes, external service calls with client
  libraries, Kafka events, every response with its condition — each claim
  backed by code, unknowns routed to open questions. The analyst opens the
  package in the Logic Analysis extension, verifies, and exports the canonical md
  from there. Use when the user says "opisz flow usługi z kodu", "wygeneruj
  analizę endpointa z implementacji", "describe this endpoint from code",
  "reverse-engineer the service flow".
---

# flow-from-code: A Draft Logic Analysis Package From Implemented Code

The service is running, the analysis was never written — and the next change
request needs it. This skill reads the endpoint's implementation and produces
a **draft Logic Analysis package** (`analysis/api/<endpoint>/api.json` + sample payloads) —
Logic Analysis' own input format — so the analyst opens the extension on a seeded,
step-complete analysis, verifies it against reality, and exports the
canonical `docs/flows/` markdown from there. No markdown is emitted here:
the md is Logic Analysis' export, and generating it twice would create two competing
renderings.

The output contract lives in `references/output-format.md`. Read it before
writing; the api.json field vocabulary is the Logic Analysis extension's model.

## What this skill does NOT do

- Does not modify any code. Reading only.
- Does not invent business rationale. Code shows WHAT the endpoint does;
  WHY — the meaning of a validation, the reason for a mapping rule — goes to
  "Kwestie otwarte" with a `plik:linia` pointer, never guessed.
- Does not write to `docs/flows/` at all — that markdown is Logic Analysis' export;
  the analyst produces it from the verified package with one click.
- Does not overwrite existing files: an existing `analysis/api/<endpoint>/` file
  (api.json or a sample) always wins and is skipped, with a report line.
- Does not paste `<dependency>` XML anywhere inline — client-library
  fragments go to `docs/dependencies/<name>.pom.xml` and are referenced by
  the package's `clients` entries.

## Input resolution

`$ARGUMENTS`: an endpoint path (`POST /api/wnioski`), a handler/controller
path or class name, or empty.

- Endpoint given → locate its handler (routing tables, controller
  annotations); several matches → list them and **Ask the user**.
- Code path/class given → that is the entry point; derive the endpoint from
  its routing metadata.
- Empty → **Ask the user** for the endpoint or handler. Do not guess.

## Procedure

### Step 1 — Read the entry point fully

Read the handler/controller and its direct collaborators (request/response
DTOs, the service class it delegates to) completely in the main context
before spawning anything.

### Step 2 — Parallel evidence sweep (read-only)

Spawn 2–4 read-only sub-agents in one message, each with a dimension and the
requirement to return `file:line` evidence:

1. **Przebieg** — the execution order: validations, transformations,
   repository calls (with the SQL when visible), the branches.
2. **Integracje** — external service calls: client class, the library
   behind it (from the build file), operation, request/response mapping,
   error handling around the call; Kafka producers with topics.
3. **Kontrakt wejścia/wyjścia** — request/response DTO shapes (field paths
   and types for the sample skeletons), every status code or exception
   mapping the endpoint can produce, with its condition.
4. *(only when dimension 2 found 3+ client libraries)* **Zależności** — the
   `<dependency>` entries for each client library found in dimension 2.

Wait for all agents before synthesizing.

### Step 3 — Interview (max 2 questions)

1. **Nazwa analizy** — propose one derived from the endpoint; the user
   confirms or gives their own (it becomes H1 and the file slug).
2. **Zakres kroków** — only when the handler fans out into more than ~7
   steps: which parts matter for this analysis (all, or a named subset)?

### Step 4 — Write the package

Emit, exactly per `references/output-format.md`:

1. `analysis/api/<endpoint-path>/request.json` + `response.json` (skip each file
   that already exists),
2. `docs/dependencies/<client>.pom.xml` per client library (skip existing),
3. `analysis/api/<endpoint-path>/api.json` — steps in execution order in Logic Analysis'
   field vocabulary, every response with its evidenced condition, `clients`
   entries carrying the dependency fragments.

Every step, rule and response must trace to Step 2 evidence; ambiguities
(dead branch, config-dependent behavior, unclear rule intent) become
`OTWARTE:` notes on their step with `plik:linia`. A step or field with
nothing evidenced is omitted — no placeholder content.

### Step 5 — Report and STOP

Report: files written, step count, response count, the full open-questions
list, and the follow-up path — "Logic Analysis: Otwórz analizę flow"
opens the seeded package; the canonical `docs/flows/` markdown comes from
Logic Analysis' "Eksport md" after verification. Do not run other skills.

## Edge cases

- **Endpoint delegating to a queue/async worker** — describe the
  synchronous part as the flow; the worker becomes a "publikacja eventu" or
  "inny krok" with a pointer, and a candidate for its own analysis.
- **Framework magic (AOP, interceptors, global filters)** — include an
  interceptor as a step only when it changes the data or can produce a
  response (auth → "Błąd — HTTP 401"); ignore pure logging.
- **No build file / non-Maven project** — skip the dependency fragments and
  say so; the client table lists the library name with `# TODO`.
- **Config-dependent behavior** (feature flags, per-environment branches) —
  describe the default branch; flag alternatives in "Kwestie otwarte" with
  the flag/property name.
