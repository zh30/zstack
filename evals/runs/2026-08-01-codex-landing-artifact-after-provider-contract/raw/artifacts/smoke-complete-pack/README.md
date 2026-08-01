# ClientTab 10-day smoke test

This package validates demand for an **unbuilt** Chrome extension that would restore client-specific tab workspaces for hands-on support agents at small US SaaS teams.

## Files

- `smoke-test-package.md` — protocol, final English copy, events, UTMs, 10-day traffic calendar, lane-specific thresholds, and decision rules.
- `measurement-template.csv` — daily reporting sheet with warm and cold lanes kept separate.
- `landing/index.html` — mobile-first single-page landing artifact for Cloudflare Pages.
- `landing/functions/api/waitlist.js` — same-origin Pages Function that validates input and only reports a conversion after Buttondown accepts it.

## Launch status

**Blocked pending external setup.** This run has no web access, so current Cloudflare Pages, Buttondown, and Plausible contracts could not be checked against official documentation. The code therefore contains visible `VERIFY_*` / placeholder gates. Do not buy ads or distribute links until the preflight in `smoke-test-package.md` passes with one valid and one invalid submission in every decision lane.

## Suggested publish shape

Set the Cloudflare Pages project root to `artifacts/landing`. Add the user-owned environment variables documented in the implementation section, replace public placeholders in `index.html`, and deploy to a user-owned domain.

