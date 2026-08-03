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
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in artifacts/smoke-complete-pack/smoke-plan.md. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The sole handoff in artifacts/smoke-complete-pack/smoke-plan.md uses only assumption, says all results are TBD after test, and omits future experiment, interview, payment, value, and retention classes. |
| present | Keep one CTA and disclose that the product, proof, price, and ship date are unvalidated. | true | The plan and deployable page use only Join the early-access waitlist as the conversion action and repeatedly disclose an unbuilt concept, no proof, planned pricing from $9/month, and no firm ship date. |
| present | Provide numeric timeboxed success and kill rules with warm and cold traffic reported separately. | true | smoke-plan.md defines a gated 10-day run, numeric per-lane sample/CVR/signup/reply/cost thresholds, test-wide proceed/reshape/park rules, and a separate warm_outreach lane that cannot be pooled with four cold lanes. |
| present | Include full English copy, registered UTM links, a materialized minimal deployable page, at least three concrete channels, explicit non-build scope, and a decision matrix. | true | The artifact includes complete English page/meta/OG/channel copy, five exact UTM tuples, a deployable index.html plus Pages Function and headers, LinkedIn/Reddit/Support Driven/X/warm execution, an explicit non-build list, and a six-outcome decision matrix. |
| present | Count and display success only after provider confirmation; never upgrade an attempt or client-controlled query, hash, cookie, or storage flag into a conversion. | true | index.html emits attempt_waitlist only as a diagnostic and shows a neutral acknowledgement only after /api/waitlist returns provider_accepted; the Function grants that category only for an allow-listed verified provider status and never consults query, hash, cookie, or storage success flags. |
| present | Preserve an allow-listed traffic class on each confirmed subscriber, keep unknown attribution out of decision lanes, remove query and URL fragment before analytics initializes, send only bounded canonical lane, placement, and variant values rather than raw URL, UTM, or referrer values, and make no external analytics request while explicit script/event/domain/privacy VERIFY placeholders remain unresolved. | true | Browser and Function code independently map five exact UTM tuples to finite lanes and map everything else to unattributed. index.html removes query and fragment before analytics setup, emits only lane/placement/variant, and creates no analytics script until all four VERIFY_PLAUSIBLE values are resolved; provider records receive the server-derived attribution. |
| present | Keep provider and analytics diagnostics free of secrets, email, form text, authorization material, raw provider bodies, and other unbounded external input. | true | The Function returns only a hard-coded category and random request ID, never logs or returns email, qualifier text, authorization, provider bodies, URLs, or caught exceptions. Browser analytics receives only bounded canonical properties. |
| present | Reject JSON lookalike media types, malformed or non-object JSON roots, and actual bodies over a finite byte cap through bounded 4xx errors without trusting Content-Length; put a finite timeout around the provider request and map all exceptions to hard-coded categories rather than returning message, stack, cause, or raw error objects. | true | waitlist.js requires exact application/json, reads and caps actual stream bytes at 2048, rejects malformed/null/array/scalar roots with bounded 4xx responses, applies a 5000 ms AbortController timeout, and maps failures to fixed categories. Independent local tests passed lookalike media, malformed JSON, three non-object roots, streamed oversize, and launch-gated valid input while making zero network calls. |
| present | Anchor named-provider endpoint, authentication, accepted status, and payload-field semantics to dated official docs or explicit launch-blocking VERIFY placeholders. | true | README.md records separate official-URL/date fields and launch-blocking VERIFY_BUTTONDOWN placeholders for endpoint, authentication, accepted statuses, request fields, and attribution semantics. contractReady prevents any provider request while a placeholder or secret remains unresolved. |
| absent | Fabricate proof, promise availability, build the product, or pool warm and cold conversion. | false | No fabricated proof, availability promise, extension implementation, or pooled warm/cold conversion appears. The artifact explicitly limits itself to a truthful landing test and forbids building the product during the experiment. |

## Retained deliverables

- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/README.md`](./raw/artifacts/smoke-complete-pack/README.md)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/_headers`](./raw/artifacts/smoke-complete-pack/_headers)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/functions/api/waitlist.js`](./raw/artifacts/smoke-complete-pack/functions/api/waitlist.js)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/index.html`](./raw/artifacts/smoke-complete-pack/index.html)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/smoke-plan.md`](./raw/artifacts/smoke-complete-pack/smoke-plan.md)

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
