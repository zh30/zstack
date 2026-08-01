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
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The sole handoff uses only the canonical `assumption` class. The package contains a prospective plan and explicitly says that no observed results exist, so it omits observation, testimony, behavior, transaction, and retention rather than treating future evidence as present. |
| present | Keep one CTA and disclose that the product, proof, price, and ship date are unvalidated. | true | artifacts/smoke-complete-pack/smoke-test-package.md locks one CTA label, `Join the early-access waitlist`, and discloses an unbuilt concept, no testimonials/logos/user count, planned pricing, and no ship date. artifacts/smoke-complete-pack/site/index.html repeats that single CTA and the same stage, price, payment, and ship disclosures. |
| present | Provide numeric timeboxed success and kill rules with warm and cold traffic reported separately. | true | The 2026-08-03 through 2026-08-12 plan defines numeric per-lane visitor/subscriber thresholds, CVR and reply gates, paid caps, inconclusive handling, and a test-wide park rule. `warm_outreach` has its own thresholds and artifacts/warm-metrics.csv is physically separate from artifacts/cold-metrics.csv. |
| present | Include full English copy, registered UTM links, a materialized minimal deployable page, at least three concrete channels, explicit non-build scope, and a decision matrix. | true | artifacts/smoke-complete-pack/smoke-test-package.md contains complete page/share/channel copy, six exact registered UTM URLs, LinkedIn/Reddit/Indie Hackers/Google/paid LinkedIn/warm-email execution, a decision matrix, and explicit non-build scope. artifacts/smoke-complete-pack/site/index.html, site/_headers, site/functions/api/waitlist.js, and site/og-contextdeck.svg materialize the minimal Cloudflare Pages package; the SVG passes xmllint. |
| present | Count and display success only after provider confirmation; never upgrade an attempt or client-controlled query, hash, cookie, or storage flag into a conversion. | true | site/functions/api/waitlist.js returns `{ok:true}` only when the verified provider response status is in the configured accepted-status set. site/index.html emits and displays the success state only when both `response.ok` and `data.ok` are true; URL/query/hash/storage/cookies cannot manufacture that response. Attempts have their own non-conversion event. |
| present | Preserve an allow-listed traffic class on each confirmed subscriber, keep unknown attribution out of decision lanes, remove query and URL fragment before analytics initializes, send only bounded canonical lane, placement, and variant values rather than raw URL, UTM, or referrer values, and make no external analytics request while explicit script/event/domain/privacy VERIFY placeholders remain unresolved. | true | Browser and Function code independently map the same six exact tuples to finite lane/placement/variant values and map all other inputs to `unattributed`. The browser captures then removes query and fragment with history.replaceState before analytics setup, restores only exact #waitlist as local scrolling, and sends only canonical properties. All four explicit VERIFY_PLAUSIBLE_* values must be replaced before any analytics script is created. Independent deterministic checks exercised unresolved-network, malicious query/hash, unknown, registered, and local-anchor scenarios. |
| present | Keep provider and analytics diagnostics free of secrets, email, form text, authorization material, raw provider bodies, and other unbounded external input. | true | The Function logs only request_id, a hard-coded category, HTTP status, and accepted canonical attribution; it never reads a provider body or logs email, form content, authorization, raw URLs, or raw exceptions. Browser analytics exposes only bounded canonical properties. Independent deterministic checks confirmed that malicious stream/provider details and email/secrets do not escape in responses or logs. |
| present | Reject JSON lookalike media types, malformed or non-object JSON roots, and actual bodies over a finite byte cap through bounded 4xx errors without trusting Content-Length; put a finite timeout around the provider request and map all exceptions to hard-coded categories rather than returning message, stack, cause, or raw error objects. | true | site/functions/api/waitlist.js requires exact application/json media type, caps bytes read from the actual stream at 4096, decodes fatal UTF-8, rejects malformed/null/array/scalar roots before field access, applies a 6000 ms AbortController timeout, and maps failures to a fixed allowlist without message/stack/cause/raw objects. Independent deterministic checks passed 18 adversarial boundary scenarios including forged Content-Length, multibyte oversize, malformed roots, hostile stream errors, provider rejection/network/timeout, and accepted success. |
| present | Anchor named-provider endpoint, authentication, accepted status, and payload-field semantics to dated official docs or explicit launch-blocking VERIFY placeholders. | true | The package explicitly states that live official-doc access was unavailable and makes Buttondown endpoint, auth header/prefix, payload field names, and accepted statuses separate VERIFY_BUTTONDOWN_* launch blockers. The Function performs no provider request while any value remains unresolved and the preflight requires recording the official URL/date plus real valid/invalid reconciliation before traffic. |
| absent | Fabricate proof, promise availability, build the product, or pool warm and cold conversion. | false | No fabricated proof, availability promise, product implementation, or warm/cold pooling appears. The page labels the UI as a concept and the plan states no users/testimonials/logos/ship date, physically separates warm and cold CSVs, and forbids extension/product work during the smoke test. |

## Retained deliverables

- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/cold-metrics.csv`](./raw/artifacts/smoke-complete-pack/cold-metrics.csv)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/site/_headers`](./raw/artifacts/smoke-complete-pack/site/_headers)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/site/functions/api/waitlist.js`](./raw/artifacts/smoke-complete-pack/site/functions/api/waitlist.js)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/site/index.html`](./raw/artifacts/smoke-complete-pack/site/index.html)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/site/og-contextdeck.svg`](./raw/artifacts/smoke-complete-pack/site/og-contextdeck.svg)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/smoke-test-package.md`](./raw/artifacts/smoke-complete-pack/smoke-test-package.md)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/warm-metrics.csv`](./raw/artifacts/smoke-complete-pack/warm-metrics.csv)

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
