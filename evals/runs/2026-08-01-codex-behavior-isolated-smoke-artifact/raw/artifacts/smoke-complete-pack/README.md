# ClientTabs smoke-test package

This directory is a deployable, pre-registered 10-day demand test for **ClientTabs**, an unbuilt Chrome extension concept for hands-on support agents at small US SaaS teams.

## Files

- `smoke-test-plan.md` — hypothesis, copy deck, source-specific thresholds, 10-day traffic calendar, decision rules, and evidence handoff.
- `site/index.html` — mobile-first English landing page with the single CTA **“Join the early-access waitlist”**.
- `functions/api/waitlist.js` — Cloudflare Pages Function that validates submissions and calls Buttondown server-side.
- `site/_headers` — baseline security and privacy headers.
- `measurement-template.csv` — daily, source-separated experiment log.

## Publish on Cloudflare Pages

1. Create a Pages project whose project/root directory is `artifacts` and whose build output directory is `site`. No build command is needed. Keep `functions/` at the Pages project root so Cloudflare deploys `/api/waitlist` with the static site.
2. Add the encrypted environment variable `BUTTONDOWN_API_KEY` in both Preview and Production. Never put it in the page or repository.
3. Replace every `YOUR_DOMAIN.example` in `site/index.html` with the final production hostname. Replace `founder@example.com` with a monitored address.
4. In Plausible, add the same production hostname, enable the custom events listed in the plan, and verify that pageviews and custom events arrive.
5. In Buttondown, configure double opt-in, the welcome email from the plan, and the expected tags/metadata. Confirm the current API accepts `tags` and `metadata`; the package cannot verify current provider documentation without web access.
6. Deploy, then run the launch gate in `smoke-test-plan.md`, including one valid and one invalid form submission for every traffic class. Confirm the valid record and its UTM metadata in Buttondown before spending money.

## Truth boundary

The page is implemented, but external accounts, credentials, hostname, deliverability, Buttondown’s current API contract, Plausible receipt, and Cloudflare deployment are not configured or verified here. A browser/web run was unavailable, so no visits, signups, replies, or conversion results are claimed.
