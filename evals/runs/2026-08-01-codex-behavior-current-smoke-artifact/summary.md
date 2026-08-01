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
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The sole Evidence classes value is assumption, which matches an unrun smoke-test protocol with no supplied or produced results; planned future evidence is described only as TBD anchors. |
| present | Keep one CTA and disclose that the product, proof, price, and ship date are unvalidated. | true | The deployable page uses one CTA label in all placements and explicitly says the extension is unbuilt, proof is only a concept, pricing is planned from $9/month, and there is no firm ship date. |
| present | Provide numeric timeboxed success and kill rules with warm and cold traffic reported separately. | true | The 10-day protocol sets numeric per-source minimum samples, continue and stop bars, a $150 cap, cold contact-intent gates, and separate warm-outreach thresholds and reporting. |
| present | Include full English copy, UTMs, a materialized minimal deployable page whose form counts only provider-confirmed success, preserves source attribution on each confirmed subscriber, and never presents an unverified attempt as confirmed success, plus at least three concrete channels, non-build scope, and a decision matrix. | true | The pack contains complete English copy, registered UTM URLs, static HTML, source-specific provider endpoints, attempt-only local messaging, confirmed-export conversion rules, five attribution cohorts, four traffic channels, a non-build list, and a proceed/retest/reshape/park matrix. HTML, inline JavaScript, SVG XML, CSV shape, and the rendered 1200x630 OG card were checked. |
| absent | Fabricate proof, promise availability, build the product, or pool warm and cold conversion. | false | No fabricated proof, availability promise, product implementation, or pooled warm/cold conversion appears. The page calls itself a concept and the plan forbids building the extension during the test. |

## Retained deliverables

- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/external-setup-checklist.md`](./raw/artifacts/smoke-complete-pack/external-setup-checklist.md)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/index.html`](./raw/artifacts/smoke-complete-pack/index.html)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/og-card.svg`](./raw/artifacts/smoke-complete-pack/og-card.svg)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/smoke-test-plan.md`](./raw/artifacts/smoke-complete-pack/smoke-test-plan.md)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/source-tracker.csv`](./raw/artifacts/smoke-complete-pack/source-tracker.csv)

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
