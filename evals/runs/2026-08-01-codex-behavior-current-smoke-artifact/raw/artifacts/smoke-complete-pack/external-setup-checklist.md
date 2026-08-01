# External setup checklist

The files are deployable static assets, but no external account was accessible in this run. Complete every checkbox before sending traffic.

## Cloudflare Pages

- [ ] Create the Pages project and deploy `index.html` plus `og-card.svg` from the same public root.
- [ ] Record the production hostname and replace all `REPLACE_WITH_CLOUDFLARE_DOMAIN` placeholders.
- [ ] Confirm HTTPS, canonical URL, OG asset response, mobile layout, and the contact link.
- [ ] Configure cache/deploy behavior so a correction can be published quickly.

## Buttondown

- [ ] Create the account/list and set a monitored reply-to address.
- [ ] Enable double opt-in.
- [ ] Create five distinct, provider-supported capture configurations whose confirmed records retain: `reddit_organic`, `x_cold`, `reddit_paid`, `warm_outreach`, and `direct_unknown`.
- [ ] Replace all `REPLACE_*_FORM` endpoints in `index.html`.
- [ ] Install the welcome email from `smoke-test-plan.md`.
- [ ] Verify one valid confirmation per cohort appears in the confirmed export with the right cohort.
- [ ] Verify invalid, duplicate, and unconfirmed attempts do not enter the numerator.
- [ ] Verify unsubscribe and reply routing.

## Plausible

- [ ] Add the production hostname and replace `REPLACE_WITH_PLAUSIBLE_DOMAIN`.
- [ ] Enable/verify `CTA Click` and `Waitlist Attempt` custom events and their properties.
- [ ] Verify UTM source, medium, campaign, and content dimensions.
- [ ] Exclude maker/QA traffic using the provider’s current supported method.
- [ ] Save a day-1 QA screenshot/export, then exclude QA data from results.

## Paid and channel operations

- [ ] Create one US Reddit Ads campaign using the registered paid URL and copy.
- [ ] Enforce a lifetime spend limit of $150 including applicable fees/taxes; do not launch if enforceability is uncertain.
- [ ] Prepare $30 / $60 / $60 staged budget gates.
- [ ] Check current subreddit rules and ad-platform requirements manually before posting; they were not web-verified in this run.
- [ ] Keep the warm-only URL out of public posts and the cold URLs out of personal outreach.

## Final go/no-go gate

- [ ] `rg 'REPLACE_' index.html` returns no matches in the deploy directory.
- [ ] All five real-valid attribution tests pass after double opt-in.
- [ ] The local page never shows confirmed-success language after a mere attempt.
- [ ] `source-tracker.csv` is copied to the experiment workspace and has a named owner.
- [ ] Start/end timestamps and US Eastern reporting cutoff are recorded.
