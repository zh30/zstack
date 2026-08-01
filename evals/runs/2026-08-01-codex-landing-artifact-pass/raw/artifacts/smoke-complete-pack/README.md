# Client Restore smoke package

This directory is a deployable Cloudflare Pages smoke test, not a Chrome extension.

## Included artifacts

- `site/index.html` — complete one-page landing page, responsive styles, three registered headline variants, waitlist UI, and Plausible events
- `functions/api/waitlist.ts` — Cloudflare Pages Function that validates requests and submits to Buttondown server-side
- `wrangler.toml` — Pages configuration and non-secret placeholders
- `site/og-card.svg` — 1200×630 social card
- `smoke-test-package.md` — protocol, copy, thresholds, UTMs, 10-day calendar, channel drafts, and decisions
- `measurement-template.csv` — source/variant ledger

## External setup required before launch

1. Create a Buttondown list for Client Restore. Enable double opt-in, set the welcome message, and confirm the account plan/API supports subscriber `metadata`.
2. In Cloudflare Pages, add the encrypted secret `BUTTONDOWN_API_KEY`. Never place it in HTML, `wrangler.toml`, or git.
3. Confirm Buttondown's current subscriber endpoint in its account/API documentation. Set `BUTTONDOWN_SUBSCRIBERS_ENDPOINT` in `wrangler.toml` or Pages variables if it differs from the placeholder.
4. Create the Plausible site, enable the five custom events listed in the protocol if the account requires goal registration, and replace both `YOUR_DOMAIN` values in the Plausible/canonical/OG markup.
5. Replace all `YOUR_DOMAIN` and `YOUR_EMAIL` placeholders. Set `ALLOWED_ORIGIN` to the exact deployed origin, including `https://` and no trailing slash.
6. Add the custom domain in Cloudflare Pages. If a social network does not accept SVG preview images, export `site/og-card.svg` to a 1200×630 PNG and update `og:image` / `twitter:image`.
7. Manually verify current Reddit/community rules and ad-policy eligibility before posting. No live web or browser access was available while this pack was produced.

## Deploy

From this `artifacts/` directory with Wrangler authenticated:

```bash
pnpm dlx wrangler pages project create client-restore-smoke
pnpm dlx wrangler pages secret put BUTTONDOWN_API_KEY --project-name client-restore-smoke
pnpm dlx wrangler pages deploy site --project-name client-restore-smoke
```

Cloudflare Pages Git integration is also valid: set this directory as the project root, use no build command, and use `site` as the output directory. Confirm that Pages Functions are included in the selected deployment workflow.

Do not deploy production or buy ads until the preflight below passes.

## Required preflight

Use the internal QA UTM from the protocol and verify each item against the actual provider dashboards:

1. Valid email + consent returns 201, shows confirmed-success copy, and creates exactly one Buttondown subscriber.
2. Subscriber metadata contains every UTM, `variant`, `traffic_class`, optional pain, and consent source.
3. Invalid email and missing consent are rejected and do not create a subscriber.
4. Duplicate submission behavior is documented and is not counted twice.
5. Wrong-origin request is rejected.
6. Plausible records `Landing View`, `CTA Click`, `Waitlist Attempt`, and—only after Buttondown accepts—`Waitlist Confirmed` with matching properties.
7. Provider failure shows the error state and records no confirmed event.
8. Mobile, keyboard, focus, contrast, reduced motion, and the anchor CTA are checked in a real browser.
9. Page title, description, canonical, OG URL/image, contact email, privacy wording, and domain are final.
10. Exclude `internal_test` traffic and test subscribers from experiment data before day 1.

If Buttondown does not retain source metadata, stop. Use provider-supported tags or distinct source forms/lists and re-run the full valid/invalid attribution test; source-specific decisions are otherwise invalid.

## Local evidence limit

This environment had no web, browser, app, computer-use, or external-service access. The package can be checked statically, but Cloudflare deployment, current Buttondown API behavior, provider metadata persistence, Plausible receipt, browser rendering, channel rules, ad inventory, and actual demand remain unverified until the owner completes the preflight and runs the test.
