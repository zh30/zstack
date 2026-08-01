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
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in artifacts/smoke-complete-pack/smoke-test.md. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only the canonical assumption class; experiment, interview, payment, and retention classes are omitted because no live test or external research ran. |
| present | Keep one CTA and disclose that the product, proof, price, and ship date are unvalidated. | true | The page uses only 'Join the early-access waitlist' and repeatedly labels the extension unbuilt, the visual a concept, customer proof absent, $9/month planned, and the ship date unknown. |
| present | Provide numeric timeboxed success and kill rules with warm and cold traffic reported separately. | true | smoke-test.md defines a dated 10-day window, a $150 cap, minimum samples and numeric continue/retest/stop thresholds for cold_paid, cold_community_social, and warm_outreach, with an explicit no-pooling rule. |
| present | Include full English copy, UTMs, a materialized minimal deployable page whose form counts only provider-confirmed success, preserves source attribution on each confirmed subscriber, and never presents an unverified attempt as confirmed success, plus at least three concrete channels, non-build scope, and a decision matrix. | true | Five retained files provide full page/meta/OG copy, source URLs, Cloudflare page/Function, Buttondown metadata, Plausible events, paid/community/social/warm channels, non-build scope, and decision matrix. Direct contract tests confirmed local success occurs only after a successful Buttondown response, provider rejection remains an error, and source_lane is stored on the accepted subscriber payload; query parameters are used only for attribution and cannot trigger success UI. |
| absent | Fabricate proof, promise availability, build the product, or pool warm and cold conversion. | false | The concept visual is labeled, no testimonials/logos/counts or availability promise appear, product construction is excluded, and every dashboard/decision rule keeps warm and cold lanes separate. |

## Retained deliverables

- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/README.md`](./raw/artifacts/smoke-complete-pack/README.md)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/measurement.csv`](./raw/artifacts/smoke-complete-pack/measurement.csv)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/site/functions/api/waitlist.js`](./raw/artifacts/smoke-complete-pack/site/functions/api/waitlist.js)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/site/index.html`](./raw/artifacts/smoke-complete-pack/site/index.html)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/smoke-test.md`](./raw/artifacts/smoke-complete-pack/smoke-test.md)

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
