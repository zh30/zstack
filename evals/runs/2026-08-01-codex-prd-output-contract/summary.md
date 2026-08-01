# Codex PRD output-contract regressions

## Outcome

- **Before fix: FAIL (2/7 criteria).** The PRD passed the older content-quality
  happy path but had no stable handoff table and used 6,047 words.
- **After handoff fix: FAIL (5/7 criteria).** The seven-field interface became
  correct, but the core grew to 6,907 words, 680 lines, and 30 requirement rows.
  It repeated decisions and carried more implementation detail than this
  six-week solo MVP needed.
- **After artifact-budget fix: PASS (7/7 criteria).** The same prompt, host,
  model, permissions, and reasoning effort produced a 4,755-word, 445-line core.
  It retained 12 P0 functional and 7 P0 non-functional requirements with
  concrete acceptance criteria, plus the complete handoff table.

The final artifact is about 31% shorter by word count than the handoff-only
revision. It passed by removing repetition and over-detail, not by dropping P0
testability or evidence boundaries.

## Grading

| Criterion | Before | After handoff | After budget | Evidence |
|-----------|:------:|:-------------:|:------------:|----------|
| One table with all seven exact field labels | FAIL | PASS | PASS | Before omitted `Evidence classes`, `Contradictions / exclusions`, and `Source anchors` as explicit fields. Both later outputs contain exactly one row for every label. |
| Only canonical vocabulary in `Evidence classes` | FAIL | PASS | PASS | Before had no canonical field. Later class cells use only allowed values: `primary behavior`, `observed experiment`, and `assumption`. |
| Preserve source separation, unknowns, counterevidence, anchors, and a bounded next test | PASS | PASS | PASS | Every output keeps 27/300 cold separate from 12/40 warm, says no payment was requested, retains supplied exclusions and source facts, and proposes a real pilot plus post-use price test. |
| Default full core is at most 5,000 whitespace-delimited words while every P0 remains testable | FAIL | FAIL | PASS | Word counts are 6,047 → 6,907 → 4,755. The final output still gives acceptance criteria for FR-001–FR-012 and NFR-001–NFR-007, all P0. |
| Do not replace the contract table or labels with custom prose/subsections | FAIL | PASS | PASS | Before used a ledger and custom subsections in place of the interface. Both later outputs preserve the fixed table. |
| Do not pool traffic or promote signup/pilot interest to payment or retention | PASS | PASS | PASS | All three explicitly reject a blended 39/340 rate and state that signup and pilot interest prove neither payment nor retention. |
| Do not inflate the core with repeated decisions or unrequested implementation detail | FAIL | FAIL | PASS | The final output consolidates scope and evidence, reduces requirement rows from 30 to 21 total, stays conceptual on data boundaries, and omits exhaustive schemas/test matrices while retaining the requested journeys, metrics, risks, milestones, and slice. |

## Changes justified by the failed runs

First, `z-write-prd` made the Evidence handoff a fixed interoperability
interface: seven immutable field labels, canonical class vocabulary, and no
prose-only substitute. Second, it added an artifact budget: roughly 1,000–2,500
words for quick PRDs and 3,000–5,000 for default full cores. Runtime instructions
and the quality bar say to remove repetition and implementation-level detail
before touching P0 acceptance criteria or the handoff.

The `prd-output-contract` case intentionally reuses the established
evidence-rich scenario. Its separate criteria preserve historical grading for
`prd-evidence-rich-mvp` while making downstream interoperability and solo-owner
maintenance cost observable.

## Reproducibility notes

All three attempts used Codex CLI 0.146.0 with `gpt-5.6-sol`, medium reasoning,
read-only sandboxing, approval policy `never`, no web search, disabled subagents,
one user turn, a separate initialized disposable Git workspace, and an
ephemeral session. Codex exited successfully after each final response.

Startup emitted state-database fallback messages, a Cloudflare MCP OAuth
`invalid_grant` warning, and a skill-description context-budget warning. No run
invoked Cloudflare or any other MCP connector; explicit skill invocation loaded
the current `z-write-prd` references and all PRD tasks completed. Raw files are
the verbatim final messages written by `--output-last-message`; CLI preambles
and session identifiers are not part of those artifacts.
