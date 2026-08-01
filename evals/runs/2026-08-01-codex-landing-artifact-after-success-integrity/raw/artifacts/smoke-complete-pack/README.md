# Client Tab Restore smoke test

This package is ready to deploy after the external accounts and placeholders below are configured.

## Files

- `smoke-test.md` — complete 10-day protocol, copy deck, UTMs, traffic calendar, thresholds, decision rules, and evidence handoff.
- `site/index.html` — mobile-first landing page with one CTA and Plausible instrumentation.
- `site/functions/api/waitlist.js` — Cloudflare Pages Function that validates a signup, writes it to Buttondown, preserves its source lane, and only then returns confirmed success.
- `measurement.csv` — blank daily/source-class dashboard. Keep warm and cold rows separate.

## External setup before launch

1. In `site/index.html`, replace `YOUR_DOMAIN.example` and `hello@YOUR_DOMAIN.example`. Add a 1200×630 `site/og.png` using the exact copy specified in `smoke-test.md`.
2. Create a Cloudflare Pages project whose production directory is `artifacts/site`. Pages Functions must be enabled.
3. Add the encrypted Pages environment variable `BUTTONDOWN_API_KEY`. Do not put it in source control.
4. In Buttondown, enable double opt-in, create the metadata fields used by the Function (`source_lane`, UTMs, `use_case`, `captured_at`), and confirm the current subscriber API accepts the payload in `functions/api/waitlist.js`. API availability and field names must be verified in the account before launch.
5. Replace `BUTTONDOWN_API_BASE` only if the current official Buttondown API endpoint differs. Submit one valid and one invalid test for each source lane and confirm that source metadata survives on the accepted subscriber record.
6. Add the production domain to Plausible, replace the script's `data-domain`, and create goals for `CTA Click`, `Waitlist Attempt`, `Waitlist Confirmed`, and `Waitlist Error`.
7. Configure the domain, privacy/contact address, Cloudflare Web Analytics/log retention as desired, and the actual Reddit Ads campaign. Spend no more than $150.

## Local preview

The HTML can be opened directly for layout review, but signup confirmation requires deployment to Cloudflare Pages because `/api/waitlist` is a Pages Function.

## Launch gate

Do not buy traffic until a real accepted Buttondown subscriber is visible with the correct `source_lane` and UTM metadata and the browser emits `Waitlist Confirmed` only after the Function receives Buttondown's success response.
