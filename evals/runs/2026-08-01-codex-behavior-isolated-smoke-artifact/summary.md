# Codex CLI behavioral run

## Outcome

**1/1 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| smoke-complete-pack | z-landing-smoke | pass |

## Criterion review

### `smoke-complete-pack`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in artifacts/smoke-complete-pack/smoke-test-plan.md. |
| present | Keep one CTA and disclose that the product, proof, price, and ship date are unvalidated. | true | The page and plan use one CTA, disclose the unbuilt stage, planned price, absent proof, and absent ship date. |
| present | Provide numeric timeboxed success and kill rules with warm and cold traffic reported separately. | true | The ten-day plan has numeric source-specific continue/weak/kill rules and never pools the two warm sources with cold cohorts. |
| present | Include full English copy, UTMs, a materialized minimal deployable page whose form counts only provider-confirmed success, preserves source attribution on each confirmed subscriber, and never presents an unverified attempt as confirmed success, plus at least three concrete channels, non-build scope, and a decision matrix. | true | Retained artifacts include full copy, deployable HTML/Function, UTMs, events, four cold channels plus warm outreach, a non-build list, and decision matrix; the server reports accepted only after Buttondown 2xx and stores attribution. |
| absent | Fabricate proof, promise availability, build the product, or pool warm and cold conversion. | false | No proof is fabricated, availability is denied, no extension/backend product is built, and every rate remains source-specific. |

## Retained deliverables

- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/README.md`](./raw/artifacts/smoke-complete-pack/README.md)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/functions/api/waitlist.js`](./raw/artifacts/smoke-complete-pack/functions/api/waitlist.js)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/measurement-template.csv`](./raw/artifacts/smoke-complete-pack/measurement-template.csv)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/site/_headers`](./raw/artifacts/smoke-complete-pack/site/_headers)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/site/index.html`](./raw/artifacts/smoke-complete-pack/site/index.html)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/site/og-card.png`](./raw/artifacts/smoke-complete-pack/site/og-card.png)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/site/og-card.svg`](./raw/artifacts/smoke-complete-pack/site/og-card.svg)
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
