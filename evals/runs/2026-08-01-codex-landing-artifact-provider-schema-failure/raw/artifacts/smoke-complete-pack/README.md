# Client Workspace Restore smoke-test package

This folder contains a deployable, pre-product demand test for a planned Chrome extension for hands-on support agents at small US SaaS teams.

## Files

- `smoke-test-plan.md` — the 10-day protocol, final copy, source-specific thresholds, traffic calendar, decision rules, and evidence handoff.
- `landing/index.html` — the one-page English landing page with the single CTA, Plausible events, allow-listed UTM capture, and truthful form states.
- `landing/functions/api/waitlist.js` — a Cloudflare Pages Function that validates the request, maps exact UTMs to a Buttondown tag, and keeps the Buttondown API token server-side.
- `landing/og-card.png` — the 1200×630 Open Graph share image.
- `landing/og-card.svg` — editable source for the share image.
- `measurement-template.csv` — daily/source ledger. Never combine `warm_dm` with cold rows.

## Publish checklist

1. Create a Buttondown publication, enable double opt-in, and create tags for `warm_dm`, `reddit_organic`, `support_driven`, `x_organic`, `reddit_ads`, and `unattributed`. Copy their immutable tag IDs.
2. Create a Cloudflare Pages project whose root directory is `artifacts/landing`. Set the encrypted secret `BUTTONDOWN_API_KEY` and variable `BUTTONDOWN_TAG_MAP_JSON` using the shape documented in `smoke-test-plan.md`.
3. Replace all `YOUR_DOMAIN.example` and `hello@YOUR_DOMAIN.example` placeholders in `landing/index.html`.
4. Add the production domain to Plausible and replace the Plausible `data-domain` placeholder. Confirm the installed script/event syntax against the current Plausible account snippet, and register `CTA Click`, `Waitlist Attempt`, `Waitlist Accepted`, and `Waitlist Error` if the account requires explicit goals.
5. Submit one valid test for every allow-listed UTM link and one invalid/unknown test. Confirm each accepted record has the expected Buttondown tag; confirm unknowns are tagged `unattributed`.
6. Install the confirmation and welcome copy from `smoke-test-plan.md`. Confirm the active-subscriber export after double opt-in is the waitlist conversion source of truth. Plausible's client-side `Waitlist Accepted` event is only a diagnostic.
7. Test mobile layout, privacy copy, confirmation email, unsubscribe link, and all production URLs before spending. Obtain community posting permission and create the Reddit Ads campaign with a $150 lifetime cap.

No live traffic, provider records, or market evidence were available while creating this package. All performance fields remain pre-registered assumptions until the test runs.
