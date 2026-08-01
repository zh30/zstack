# Grok landing integrity regression

## Outcome

- **Before fix: FAIL.** The package looked complete, but the browser emitted `submit_waitlist` before the cross-origin Buttondown request was known to succeed. Attempts, invalid paths, and provider-confirmed conversions could be mixed in the core CVR.
- **After conversion fix: FAIL.** The model correctly made the provider record authoritative, then returned only a detailed protocol and offered to create the requested landing page later.
- **After materialization fix: FAIL.** The page and protocol were materialized, but Plausible held source-specific pageviews while Buttondown held one undifferentiated subscriber total. The requested warm/cold decision rules were not executable.
- **After attribution fix: FAIL.** Confirmed subscribers carried a traffic class and raw UTMs, but the page still replaced the form with “You’re on the list” after a timeout even though the native cross-origin form could not prove acceptance.
- **Final: PASS (6/6 criteria).** The page and protocol are deployable, conversion and attribution boundaries are explicit, the visible UI acknowledges only that a submission was sent, and the decision plan never pools warm with cold.

## Final grading

| Criterion | Grade | Evidence |
|---|---:|---|
| One CTA and truthful unbuilt/proof/price/date disclosure | PASS | The page consistently uses “Join the early-access waitlist,” labels the extension unbuilt, says pricing is planned from $9/month, and states there are no testimonials, logos, user counts, or firm ship date. |
| Complete package is materialized | PASS | `landing/index.html` and `docs/smoke/clienttabs-20260801.md` exist in the final raw archive; the page contains meta, OG, full copy, form, attribution, and analytics hooks. |
| Provider-confirmed conversion integrity | PASS | The browser emits only `waitlist_attempt`; Buttondown accepted subscribers are the sole numerator. Native email validation remains active, and the protocol requires valid/invalid preflight submissions. |
| Truthful visible form state | PASS | The cross-origin form displays “Submission sent — check your inbox if the address is accepted,” never a locally inferred confirmed-success message. |
| Source-specific attribution and decision rules | PASS | The page derives `warm`, `social`, `ads`, or `direct`, sends `smoke-*` tags plus raw UTM metadata, and requires one real provider-record verification before traffic. Warm, cold organic, and ads have separate sample floors and thresholds. |
| Traffic, non-build, and next-decision completeness | PASS | The protocol contains a 10-day calendar, at least three concrete channels, a $150 combined ad cap, explicit non-build scope, and strong/mixed/weak/distribution-failure actions. |

## Changes justified by the failed runs

`z-landing-smoke` now makes four previously implicit boundaries observable:

1. A waitlist conversion exists only after provider confirmation; an attempt is never a success event.
2. A complete-package request in a writable workspace must materialize the smallest deployable page.
3. Source-specific CVR requires the same traffic class on the pageview and each confirmed subscriber.
4. Confirmed-success wording is allowed only after a verified callback or controlled success redirect; cross-origin attempts receive neutral UI.

The same rules are mirrored in the metrics guide, smoke-pack template, quality bar, and behavioral eval criterion.

## Reproducibility notes

All graded runs used Grok Build 0.2.117, no web search, no subagents, at most three turns, and an initialized disposable Git workspace. The first two valid runs used `grok-4.5-build`. That model then became unavailable, so the remaining valid runs used `grok-4.5`; conclusions compare contract behavior, not exact same-model determinism. No-artifact startup/headless incidents are recorded in `run.json` but excluded from model grading. Account, request, and session identifiers are intentionally omitted.
