# Codex CLI behavioral run

## Outcome

**0/1 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| smoke-complete-pack | z-landing-smoke | fail |

## Criterion review

### `smoke-complete-pack`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in artifacts/smoke-complete-pack/smoke-test-plan.md. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only assumption and omits experiment, interview, payment, and retention classes because no live test ran. |
| present | Keep one CTA and disclose that the product, proof, price, and ship date are unvalidated. | true | The page uses only Join the early-access waitlist and labels the product unbuilt, proof absent, $9/month planned, and ship date unknown. |
| present | Provide numeric timeboxed success and kill rules with warm and cold traffic reported separately. | true | smoke-test-plan.md defines August 3–12, a $150 cap, per-lane minimums/continue/weak rules, and forbids warm/cold pooling. |
| present | Include full English copy, UTMs, a materialized minimal deployable page whose form counts only provider-confirmed success, preserves allow-listed source attribution on each confirmed subscriber, keeps unknown attribution out of decision lanes, never logs secrets, PII, form text, or raw provider bodies, and never presents an unverified attempt as confirmed success, plus at least three concrete channels, non-build scope, and a decision matrix. | false | The files correctly allow-list lanes, isolate unattributed traffic, avoid raw logging, and wait for a successful server-side provider response. However, README.md requires immutable Buttondown tag IDs and the Function sends that ID in the tags array. Buttondown's official Creating a subscriber documentation (https://docs.buttondown.com/api-subscribers-create, checked 2026-08-01) defines tags as tag names, not IDs. The named-provider integration is therefore not verified deployable and may fail to preserve the intended lane. |
| absent | Fabricate proof, promise availability, build the product, or pool warm and cold conversion. | false | No fake proof, availability promise, product build, or pooled warm/cold conversion appears. |

## Retained deliverables

- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/README.md`](./raw/artifacts/smoke-complete-pack/README.md)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/landing/functions/api/waitlist.js`](./raw/artifacts/smoke-complete-pack/landing/functions/api/waitlist.js)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/landing/index.html`](./raw/artifacts/smoke-complete-pack/landing/index.html)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/landing/og-card.png`](./raw/artifacts/smoke-complete-pack/landing/og-card.png)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/landing/og-card.svg`](./raw/artifacts/smoke-complete-pack/landing/og-card.svg)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/measurement-template.csv`](./raw/artifacts/smoke-complete-pack/measurement-template.csv)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/smoke-test-plan.md`](./raw/artifacts/smoke-complete-pack/smoke-test-plan.md)

## Execution controls

Codex CLI 0.146.0 used `gpt-5.6-sol` with
medium reasoning, one ephemeral turn per case,
exact copied skill snapshots, generated prompts through stdin, isolated
initialized Git workspaces, a minimal per-case `CODEX_HOME`, a workspace-write sandbox, approval policy
`never`, and disabled web/browser/apps/computer access and subagents.
Post-run auditing rejected writes outside `artifacts/` and any change to
the copied skill; retained deliverables are covered by exact hashes.

## Runner incidents

No recognized runner incidents were recorded.

Private runner records corroborated host, requested and actual model, permissions,
isolation flags, workspaces, prompt bytes, response bytes, and incident counts, then
were excluded because they contain ephemeral session identifiers and local
paths. Results apply to the retained skill snapshots and execution controls.
