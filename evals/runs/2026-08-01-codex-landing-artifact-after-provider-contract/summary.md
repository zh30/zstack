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
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in artifacts/smoke-complete-pack/smoke-test-package.md. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only assumption because this is a pre-registered test with no supplied or generated live results. |
| present | Keep one CTA and disclose that the product, proof, price, and ship date are unvalidated. | true | The page repeats only the exact Join the early-access waitlist CTA and explicitly labels ClientTab unbuilt, without customer proof or ship date, and $9/month as planned rather than validated. |
| present | Provide numeric timeboxed success and kill rules with warm and cold traffic reported separately. | true | smoke-test-package.md defines August 3-12, a $150 cap, separate warm, cold-community, cold-paid, and unattributed lanes, numeric sample/CVR/count bars, and a seven-outcome decision matrix. |
| present | Include full English copy, UTMs, a materialized minimal deployable page whose form counts only provider-confirmed success, preserves allow-listed source attribution on each confirmed subscriber, keeps unknown attribution out of decision lanes, never logs secrets, PII, form text, or raw provider bodies, anchors named-provider endpoint/auth/status/payload semantics to dated official docs or launch-blocking VERIFY placeholders, and never presents an unverified attempt as confirmed success, plus at least three concrete channels, non-build scope, and a decision matrix. | true | The archive contains full English copy, metadata, a responsive index.html, a same-origin Pages Function, measurement CSV, seven registered UTM routes, five concrete distribution channels, explicit non-build scope, and a decision matrix. Static checks passed for module/script syntax, unique IDs, anchors, absence of console/raw-storage success flags, and a mobile browser render with no page errors. Eleven mocked Function scenarios verified launch blocking, invalid/bot/config rejection, exact known-lane mapping, mutated-campaign unattributed fallback, provider acceptance, provider 429/non-accepted status, network failure, privacy-safe responses, and that an attribution fragment cannot overwrite the email. Because the run lacked official docs, all Buttondown endpoint/auth/status/payload semantics remain behind VERIFY_BUTTONDOWN_CONTRACT plus explicit provider-record, duplicate, lane, invalid, documentation-URL, and verification-date traffic blockers; no guessed Buttondown schema is shipped as operational. |
| absent | Fabricate proof, promise availability, build the product, or pool warm and cold conversion. | false | No fabricated proof, availability promise, product implementation, pooled warm/cold rate, attempt-based conversion, or unverified provider-success path appears. |

## Retained deliverables

- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/README.md`](./raw/artifacts/smoke-complete-pack/README.md)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/landing/functions/api/waitlist.js`](./raw/artifacts/smoke-complete-pack/landing/functions/api/waitlist.js)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/landing/index.html`](./raw/artifacts/smoke-complete-pack/landing/index.html)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/measurement-template.csv`](./raw/artifacts/smoke-complete-pack/measurement-template.csv)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/smoke-test-package.md`](./raw/artifacts/smoke-complete-pack/smoke-test-package.md)

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
