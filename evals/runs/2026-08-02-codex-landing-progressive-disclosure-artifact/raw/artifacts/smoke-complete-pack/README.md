# ContextDock smoke-test package

This directory is the deployable and operational package for a 10-day pre-build demand test.

## Files

- `index.html` — complete English landing page, metadata, form, allow-listed UTMs, guarded Plausible integration, and honest attempt state.
- `functions/api/waitlist.js` — Cloudflare Pages Function with bounded validation, independent server attribution, a Buttondown contract gate, timeout, and finite non-PII errors.
- `_headers` — baseline browser security and privacy headers.
- `smoke-plan.md` — hypothesis, copy inventory, event contract, traffic calendar, post drafts, thresholds, decision rules, QA, and evidence handoff.

## Evidence limit

Web/browser access was unavailable while this package was produced on 2026-08-02. Therefore no live Buttondown or Plausible documentation, community rules, ad inventory, provider behavior, market demand, or funnel result was verified. The integrations deliberately make no external request while `VERIFY_*` values remain. This is a safe launch block, not a wired production integration.

## External setup required

1. Create a Cloudflare Pages project whose output directory is this `artifacts/` directory and whose Functions directory is `artifacts/functions/`. Set the production custom domain.
2. Replace `VERIFY_DOMAIN` references in the plan, add real `og:url`, and host a truthful 1200×630 concept image before adding `og:image`.
3. Replace `VERIFY_CONTACT_EMAIL` in `index.html` with a monitored address.
4. Create the Buttondown list/account. From current official documentation, verify and record below the endpoint, authentication scheme, accepted status codes, exact email field, exact metadata/tag contract, duplicate behavior, consent/double-opt-in behavior, and confirmed-subscriber export semantics.
5. Only after that verification, replace every `VERIFY_BUTTONDOWN_*` constant in `functions/api/waitlist.js`. Add `BUTTONDOWN_API_KEY` as an encrypted Cloudflare Pages environment variable. Never put it in HTML or git.
6. Create one welcome automation using the copy in `smoke-plan.md`. Ensure sender identity, unsubscribe, deletion handling, and a privacy notice are operational.
7. Create the Plausible site. From current official documentation, verify and record below the script URL, custom-event call/API, domain value, pageview behavior, and material privacy behavior. Replace every `VERIFY_PLAUSIBLE_*` constant only after verification. Update `_headers` so `script-src` and `connect-src` allow only the verified Plausible origins; the shipped self-only CSP intentionally blocks them.
8. Run every QA case in the plan. In particular, make one real valid provider-confirmed subscriber for all five lanes plus `unattributed`, and prove the canonical lane survives on each provider record. Delete QA records before launch.
9. Check the current rules and obtain permission where needed for Support Driven and Reddit. Confirm current LinkedIn audience availability and billing controls. Traffic is not authorized until the launch checklist passes.

## Provider verification record (complete before launch)

| Contract | Official URL | Verified date | Verified value / behavior |
|---|---|---|---|
| Buttondown endpoint + API version | TBD | TBD | `VERIFY_BUTTONDOWN_ENDPOINT` |
| Buttondown authentication | TBD | TBD | `VERIFY_BUTTONDOWN_AUTH_SCHEME` |
| Buttondown request fields | TBD | TBD | `VERIFY_BUTTONDOWN_EMAIL_FIELD`; `VERIFY_BUTTONDOWN_ATTRIBUTION_FIELD` |
| Buttondown accepted status + duplicate semantics | TBD | TBD | `VERIFY_BUTTONDOWN_ACCEPTED_STATUS` |
| Buttondown double opt-in + provider-confirmed record | TBD | TBD | TBD |
| Plausible script + site domain | TBD | TBD | `VERIFY_PLAUSIBLE_SCRIPT_URL`; `VERIFY_PLAUSIBLE_SITE_DOMAIN` |
| Plausible custom-event API | TBD | TBD | `VERIFY_PLAUSIBLE_EVENT_API` |
| Plausible privacy + pageview behavior | TBD | TBD | `VERIFY_PLAUSIBLE_PRIVACY` |

## Deployment gates

- While a `VERIFY_*` Plausible value remains, the browser creates no analytics script or request and events are no-ops.
- While a `VERIFY_*` Buttondown value remains or the secret is absent, `/api/waitlist` returns the bounded `not_configured` category and creates no provider request.
- A provider-accepted API response causes only a neutral local acknowledgement. The provider-confirmed subscriber record remains the sole conversion source of truth.
- Do not purchase traffic merely because the page deploys. Launch only after the full QA checklist passes.
