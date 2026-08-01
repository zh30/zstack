# ContextDeck: 10-day landing smoke test

> Working name only; run a trademark/name check before product build. This package was prepared on 2026-08-01. The test window is 2026-08-03 through 2026-08-12 (US local time). Page language and outreach are English.

## 1. Locked experiment

| Field | Decision |
|---|---|
| ICP | Hands-on support agents and support leads at small US SaaS teams who repeatedly switch among multiple client-specific Chrome tab sets |
| Problem | Rebuilding each client’s admin, CRM, logs, ticket, and documentation context wastes time and breaks momentum |
| Promise | Restore a saved client-specific tab workspace in one click |
| Primary CTA | **Join the early-access waitlist** (the only CTA label everywhere) |
| Price signal | Planned pricing from $9/month; no payment and no price lock |
| Stage | Unbuilt concept; no testimonials, customer logos, user count, or ship date |
| Stack | Cloudflare Pages + Pages Functions, Buttondown, Plausible |
| Budget | Maximum $150 paid media; no spend before end-to-end verification |

### Hypothesis

If client-specific one-click tab restore is a painful, paid-tool-shaped job for hands-on support agents at small US SaaS companies, qualified cold visitors will join an early-access waitlist at the source-specific rates below, and some confirmed subscribers will reply with a concrete current workaround or willingness to try the product from $9/month.

### Funnel and sources of truth

1. Qualified unique landing visitor: Plausible unique visitor in a pre-registered source lane, US-targeted where controllable. Bots, founder QA, repeat test devices, employees recruited to test the form, and `unattributed` traffic are excluded.
2. CTA click: `click_cta` in Plausible. Diagnostic only.
3. Attempt: `attempt_waitlist` in Plausible. Never called a conversion.
4. Confirmed provider acceptance: `submit_waitlist` is emitted only after the Pages Function receives an accepted Buttondown API response. Buttondown’s accepted subscriber record is the numerator source of truth.
5. Confirmed email subscriber: double-opt-in completion in Buttondown. Report this separately; it is the primary conversion numerator for decisions.
6. High-intent reply: a confirmed subscriber replies with a current client-tab workflow, frequency, cost, or explicit willingness to trial/pay. Opens are diagnostic only.

Primary metric: confirmed double-opt-in subscribers / qualified unique visitors, calculated **within each decision lane only**. Secondary: CTA click rate, attempt-to-provider-acceptance rate, double-opt-in completion, reply count/rate, concrete-workaround replies, explicit “I’d try/pay from $9” replies, cost per confirmed subscriber, and spend.

### Pre-registered lanes and thresholds

Never pool `warm_outreach` with cold traffic. Also retain the cold sub-lanes below; an overall “cold” roll-up may be shown descriptively but never replaces its source decisions.

| Lane | Sources | Minimum before a directional lane decision | Continue signal | Reshape / stop signal |
|---|---|---:|---|---|
| `cold_paid` | Google search CPC and LinkedIn CPC | 75 qualified visitors and 3 confirmed subscribers per platform where budget permits | ≥4.0% confirmed CVR **and** cost/confirmed subscriber ≤$30; or ≥3 confirmed plus ≥1 concrete reply | After ≥75 qualified visitors: <2.0% confirmed CVR, or zero confirmed. Pause a creative after ≥30 qualified visits and zero provider-accepted signups. Never exceed $150 total. |
| `cold_community` | Reddit and Indie Hackers | 50 qualified visitors and 3 confirmed subscribers per source | ≥6.0% confirmed CVR and ≥1 concrete-workaround reply | After ≥50 qualified visitors: <2.0% confirmed CVR or zero concrete replies. If removed/rejected by the community, classify as distribution failure, not product failure. |
| `cold_social` | Founder LinkedIn organic posts | 50 qualified visitors and 3 confirmed subscribers | ≥5.0% confirmed CVR and ≥1 concrete-workaround reply | After ≥50 qualified visitors: <2.0% confirmed CVR or zero provider-accepted signups. |
| `warm_outreach` | Personal email to known ICPs only | 20 qualified visitors and 4 confirmed subscribers; report invite→visit too | ≥20% confirmed CVR and ≥2 concrete-workaround replies | <10% after ≥20 qualified visitors, or zero concrete replies. Use to learn language, never to rescue cold metrics. |

Rates under 50 qualified visits are unstable. If a lane misses its minimum, label it **inconclusive**. No test-wide product kill is allowed unless at least two cold lanes each reach their minimum and both hit their reshape/stop signals. Budget exhaustion before paid minimum means “paid acquisition inconclusive,” not “no demand.”

### Ten-day success bar

Proceed to a thin prototype only if either:

- two independent cold lanes meet their Continue signal, with at least 8 total confirmed cold subscribers and at least 3 total concrete-workaround replies; or
- one cold lane meets Continue and at least 2 cold subscribers explicitly state credible willingness to trial/pay at the planned $9/month starting point. This is a lead signal, not proof of scalable willingness to pay.

Interview/retest if cold CVR clears a Continue threshold but fewer than 3 concrete replies arrive, or replies reveal a different job than client-specific restore. Reshape the hero/ICP and rerun the same source if a cold lane reaches minimum but lands between 2% and its Continue threshold. Park this concept if two cold lanes reach minimum, each stays below 2%, operations are verified, and no concrete cold reply appears.

## 2. Complete page and share copy

The exact production copy is materialized in `site/index.html`. It uses this hierarchy:

- Meta title: **ContextDeck — Restore Every Client Workspace in One Click**
- Meta description: **A planned Chrome extension for hands-on support agents at small US SaaS teams. Reopen each client’s saved tabs in one click. Planned pricing from $9/month.**
- OG title: **One click back to every client context**
- OG description: **ContextDeck is a planned Chrome extension that restores client-specific tab workspaces for hands-on SaaS support agents. Join the early-access waitlist; planned pricing starts at $9/month.**
- OG image alt: **ContextDeck: one click back to every client context**
- Shipped H1: **One click back to every client context.**
- Hero support: **For hands-on support agents at small SaaS teams: save each client’s working tabs as a workspace, then restore the whole set when their next ticket lands.**
- Stage disclosure: **We’re validating demand before building the full extension. No payment today.**
- Price line: **Planned pricing from $9/month.**

Headline variants, held for later tests (do not rotate during this 10-day baseline):

1. Shipped: **One click back to every client context.**
2. Problem-first: **Stop rebuilding the same client tabs for every ticket.**
3. Category wedge: **The tab workspace built for client support.**

The page includes: minimal nav; hero; three status-quo pains; three-step planned workflow; for/not-for; honest concept note; price and waitlist offer; six FAQs covering stage, timing, pricing, storage, ICP, and next step; repeated final CTA; contact/privacy footer. The conceptual UI is explicitly labeled, not presented as a product screenshot. Every button uses exactly **Join the early-access waitlist**.

## 3. Implementation and launch gate

### Files and deployment

- `site/index.html`: responsive single-page landing, form, allow-listed attribution, and guarded analytics.
- `site/functions/api/waitlist.js`: Cloudflare Pages Function with bounded JSON intake, server-side attribution, Buttondown adapter gate, timeout, finite error categories, and privacy-safe logs.
- `site/og-contextdeck.svg`: 1200×630 share card.
- `site/_headers`: security headers and CSP placeholders.

Create a Cloudflare Pages project whose build output/root is `artifacts/site`; no build command is required. Add a real custom or `pages.dev` domain, then replace `VERIFY_CANONICAL_URL` and `VERIFY_CONTACT_EMAIL`. Do not buy traffic on a preview URL that will change.

### Buttondown form contract

Form fields sent to the first-party endpoint:

| Field | Rule |
|---|---|
| `email` | Required, browser validated, ≤254 characters; server revalidates |
| `company_site` | Hidden honeypot; non-empty is rejected |
| `source`, `medium`, `campaign`, `content`, `variant` | Browser sends bounded raw candidates; the server independently maps only exact registered tuples |

Use double opt-in for list quality, deliverability, and proof of email control. Store the email in Buttondown only for this waitlist; do not sell it. Do not send arbitrary UTM strings or page URLs to Buttondown. Provider metadata must contain only canonical `decision_lane`, `placement`, `variant`, and non-PII `request_id` after the current field semantics are verified.

The local page says “You’re on the list — check your inbox to confirm” only after the Pages Function returns success, and that Function returns success only for a pre-verified Buttondown accepted status. Invalid, duplicate/rejected, timed-out, network-failed, and merely attempted submissions are not conversions. Double-opt-in completion remains a separate, stronger provider record.

**Launch blocker:** internet and official-doc access were unavailable in this run, so no current Buttondown endpoint, authentication syntax, accepted statuses, or payload/metadata semantics are asserted. `site/functions/api/waitlist.js` deliberately returns `integration_unverified` and makes no provider request until all `VERIFY_BUTTONDOWN_*` values are checked against current official Buttondown docs and replaced. Record the official docs URL and verification date in the run log; set `BUTTONDOWN_API_KEY` as a Cloudflare encrypted secret, never in code. Submit one valid and one invalid real test and confirm lane metadata on the accepted subscriber record before traffic.

### Intake and logging controls

The endpoint accepts only `application/json` (parameters such as `charset` allowed), reads and caps the actual stream at 4 KiB without trusting `Content-Length`, rejects malformed JSON and `null`/array/scalar roots before field access, and bounds the provider request to six seconds. It returns only fixed categories. Logs contain request ID, fixed category, HTTP status, and canonical attribution after acceptance; never email, free text, authorization data, raw provider responses, query strings, exceptions, messages, stacks, causes, or raw objects.

Before launch, test: GET/PUT (405), wrong media type (415), malformed JSON (400), `null`/array/scalar (400), invalid email (400), honeypot (400), body over 4 KiB (413), missing secret (503/no external call), upstream timeout (bounded 502), provider rejection (bounded 502), valid acceptance (200), duplicate behavior, and confirmed opt-in. Check Cloudflare logs for PII absence.

### Plausible events

| Event | Fires when | Decision use |
|---|---|---|
| `view_landing` | After URL attribution is allow-listed and query/hash are removed | Qualified denominator, filtered for bot/QA rules |
| `click_cta` | A CTA anchor is activated | Copy/interaction diagnostic |
| `attempt_waitlist` | A valid browser form begins its request | Form/integration diagnostic only |
| `submit_waitlist` | First-party endpoint returns provider-accepted success | Operational cross-check; Buttondown remains conversion truth |

Allowed analytics properties are exactly canonical `decision_lane`, registered `placement`, and `variant`. Unknown/malformed tuples become `unattributed`. Raw queries, URLs, fragments, referrers, emails, form values, and provider content are stripped before analytics initializes and never emitted. The only restored anchor is exact `#waitlist`, after the pageview boundary.

**Launch blocker:** current Plausible script URL, event API, site domain, and material privacy behavior could not be verified here. The page keeps `VERIFY_PLAUSIBLE_*` values and a local no-op; it creates no Plausible request until every value is replaced. Verify against current official Plausible docs, record URL/date, create the four goals above, confirm custom-property support, replace the CSP origins, and inspect real network requests to ensure no query/fragment/PII escapes. If the documented custom-event call differs, update `safeEvent` before enabling.

### Attribution allow-list and exact UTMs

Replace `https://VERIFY_DOMAIN.example/` only after the real canonical URL exists. Do not add ad-platform auto-tag values to decision logic; these exact UTMs determine the lane. Unknowns stay `unattributed` and are excluded from source-specific CVR.

| Placement | Exact URL |
|---|---|
| LinkedIn founder | `https://VERIFY_DOMAIN.example/?utm_source=linkedin&utm_medium=social&utm_campaign=contextdeck_smoke_2026_08&utm_content=founder_post&variant=a` |
| Reddit customer success | `https://VERIFY_DOMAIN.example/?utm_source=reddit&utm_medium=community&utm_campaign=contextdeck_smoke_2026_08&utm_content=r_customersuccess&variant=a` |
| Indie Hackers | `https://VERIFY_DOMAIN.example/?utm_source=indiehackers&utm_medium=community&utm_campaign=contextdeck_smoke_2026_08&utm_content=milestone&variant=a` |
| Google search ad | `https://VERIFY_DOMAIN.example/?utm_source=google&utm_medium=cpc&utm_campaign=contextdeck_smoke_2026_08&utm_content=search_context_restore&variant=a` |
| LinkedIn paid ad | `https://VERIFY_DOMAIN.example/?utm_source=linkedin&utm_medium=cpc&utm_campaign=contextdeck_smoke_2026_08&utm_content=support_agents&variant=a` |
| Warm personal email | `https://VERIFY_DOMAIN.example/?utm_source=warm_email&utm_medium=outreach&utm_campaign=contextdeck_smoke_2026_08&utm_content=personal_note&variant=a` |

The same exact map appears in browser and Function code. Server mapping—not client lane—controls confirmed-subscriber attribution. For source CVR, reconcile Plausible pageviews with Buttondown confirmed records by canonical lane/placement. Never allocate an undifferentiated subscriber total by timing.

### Minimal measurement sheet

One row per date × placement: date, lane, placement, qualified unique visitors, CTA clicks, attempts, provider accepted, double-opt-in confirmed, concrete replies, explicit $9 intent replies, spend, confirmed CVR, cost/confirmed subscriber, notes/exclusions. Use the physically separate `cold-metrics.csv` and `warm-metrics.csv` templates; formulas must never span them. Duplicate the prefilled rows for each active date. Archive dated CSV exports/screenshots from Plausible and Buttondown on Days 5 and 10.

## 4. Ten-day traffic calendar

All schedules use the target audience’s US local working hours. Exact subreddit availability, community rules, ad inventory, CPCs, and platform minimums could not be checked without web/browser access. Verify before posting or spending; if a placement disallows research/waitlist links, skip it and record a distribution exclusion rather than evading the rule.

| Day | Channel and action | Spend/cap | Checkpoint |
|---|---|---:|---|
| Day 1 — Mon Aug 3 | Deploy Cloudflare page. Complete Buttondown/Plausible verification. Run QA matrix, real valid/invalid signups, metadata reconciliation, mobile/desktop check, email deliverability check. No public traffic. | $0 | Traffic gate signed only if provider record preserves lane and analytics contains bounded properties only. |
| Day 2 — Tue Aug 4 | Publish LinkedIn founder post at 9–11am ET. Send 5 individually written warm emails after cold post; use warm URL. Do not ask friends to boost the post. | $0 | Reply to substantive comments. Log cold social and warm separately. |
| Day 3 — Wed Aug 5 | If rules allow, publish value-first Reddit post in one buyer community used by customer success/support practitioners. Disclose maker and unbuilt status. Send 5 more warm emails. | $0 | Watch for removal; do not repost elsewhere that day. Capture objection language. |
| Day 4 — Thu Aug 6 | Publish Indie Hackers build-in-public critique post. Launch paid: Google search test $15/day and LinkedIn single-image test $15/day, US only, narrowly role/intent targeted. Send final 10 warm emails (20 total). | ≤$30 | Ensure ad and page use identical promise. Exclude employees/testers. |
| Day 5 — Fri Aug 7 | No new channel. Respond to every real question. Export lane data. Send Buttondown welcome/question email to confirmed subscribers; no new CTA. | ≤$30 cumulative/day | Pause a paid placement only after ≥30 qualified visits and zero accepted signups, or obvious irrelevant clicks. Do not edit hero yet. |
| Day 6 — Sat Aug 8 | No new spend unless weekday evidence is qualified; default paid pause for weekend B2B quality. Review replies and attribution gaps. | Default $0 | Operational defects invalidate affected traffic window; repair and annotate, never backfill. |
| Day 7 — Sun Aug 9 | Prepare follow-up using observations only; no invented results. Check cold-lane sample progress and remaining budget. | $0 | If no lane can approach minimum, prioritize distribution repair, not page optimization. |
| Day 8 — Mon Aug 10 | LinkedIn follow-up at 9–11am ET. Resume surviving paid placements; allocate at most $30 to best qualified-cost source and $15 to the other. | ≤$45 | Do not move spend based on warm results. Preserve original hero and creative. |
| Day 9 — Tue Aug 11 | Community follow-up only where rules and genuine discussion permit; otherwise comments only. Continue surviving paid placement(s). | ≤$45 | Hard cumulative spend check: never exceed $150. Stop any placement on its registered weak signal. |
| Day 10 — Wed Aug 12 | Stop all ads by end of target workday. Export Plausible/Buttondown data, reconcile records, mark unknowns, calculate each lane separately, apply decision matrix, and send no “success” claim before review. | Total hard cap $150 | Write decision with denominators, conversion counts, exclusions, dates, and unresolved attribution. |

Paid allocation ceiling: Google Search up to $75 and LinkedIn CPC up to $75; total across both is **$150 maximum**, not a target. Begin at $15/day each on Days 4–5. Days 8–9 may use up to $45/day total while remaining under each platform cap. If platform minimums make this impossible, use the feasible single platform and label the other lane untested. Do not substitute broad display traffic.

### Channel copy and etiquette

**LinkedIn founder post (cold social)**

> Support agents: how many tabs do you rebuild before you can actually answer a client?
>
> For one account it might be the admin, CRM, ticket history, logs, and a runbook. Then the next account needs a completely different set.
>
> I’m testing a narrow Chrome extension idea: save those tabs as a client workspace and restore the set in one click.
>
> It is not built yet. Planned pricing would start at $9/month if the problem is real enough to pursue. I made a short concept page and would value blunt feedback from people doing hands-on SaaS support.
>
> [LINKEDIN FOUNDER UTM URL]

Do: disclose that you are the maker, answer objections, and keep the unbuilt/price language. Don’t: tag strangers, ask friends for engagement, claim “launching soon,” or imply users exist.

**Reddit buyer-community post**

Suggested title: **How do you restore client-specific browser context between support tickets?**

> I’m trying to understand a workflow in hands-on SaaS support. When you switch clients, do you reopen the same account-specific set—admin, CRM, logs, ticket history, docs—or keep everything open indefinitely?
>
> My current hypothesis is that a small Chrome extension could save each client’s tab set and restore it in one click. It’s unbuilt, and I’m testing whether this is painful enough to justify a tool from $9/month.
>
> I’m the maker. I put the exact concept and limitations here: [REDDIT UTM URL]. Even a “this isn’t a problem because…” answer is useful.

Do: read rules and recent top posts first, request mod permission if promotion/research is unclear, use an allowed feedback flair, and participate in the thread. Don’t: copy it into multiple subreddits, conceal affiliation, DM commenters without consent, or argue with negative feedback.

**Indie Hackers post**

Suggested title: **Smoke testing a $9 tab-workspace tool before writing the extension**

> I’m testing one job for one user: hands-on support agents at small SaaS teams who rebuild a different browser context for every client.
>
> The promise is one-click restore of a saved client tab workspace. The extension is unbuilt; there is no ship date, user count, or fake product screenshot. I’m testing an early-access waitlist with planned pricing from $9/month for 10 days before deciding whether to prototype.
>
> What feels unclear or unconvincing on the page? [INDIE HACKERS UTM URL]

Do: ask for critique and share the eventual result. Don’t: frame it as a launched product or count maker-curiosity as buyer validation.

**Google Search ad (cold paid; one responsive concept only)**

- Headline options: `Restore Client Tabs in One Click` / `Client Workspaces for Support` / `Planned Chrome Extension`
- Descriptions: `Save each client’s working tabs, then restore the set in one click. Unbuilt concept.` / `For hands-on SaaS support agents. Early access; planned pricing from $9/month.`
- Destination: exact Google UTM URL above.
- Target only high-intent phrases around restoring/saving tab groups for customer support; use exact/phrase match initially. Add negatives for jobs, free wallpapers, gaming, school, and generic customer service training. US only.

**LinkedIn single-image ad (cold paid)**

- Image copy: `Next client. Same tab hunt?` / `Restore the workspace in one click.`
- Primary text: `For hands-on support agents at small SaaS teams: a planned Chrome extension to save each client’s working tabs and restore the set in one click. Unbuilt concept. Planned from $9/month.`
- Headline: `One click back to client context`
- Destination: exact LinkedIn paid UTM URL above.
- Narrow to US customer support/customer success practitioners at small software/SaaS companies where the platform supports it. Do not use an in-platform lead form because it changes CTA friction and breaks comparison. If the platform forces a different visible CTA label, do not use that placement.

For both paid sources: one audience, one promise, one creative family, variant A page only. Do not use retargeting, lookalikes, audience expansion, automated creative rewriting, or broad display. CPC is an acquisition diagnostic, not demand evidence. Platform feasibility and keyword/audience inventory require external verification.

**Warm personal email (separate lane, 20 maximum)**

Subject: `Quick reality check on client tab switching?`

> Hi [Name] — I’m testing a narrow idea for hands-on SaaS support: save the working tabs for each client, then restore that client’s full set in one click.
>
> It’s not built, and I’m trying to learn whether the problem deserves a product before writing the extension. Planned pricing would start at $9/month.
>
> If this overlaps with your actual work, the concept is here: [WARM UTM URL]. A blunt reply about what you do today is just as valuable as joining.

Send only to people the founder genuinely knows and who match the ICP; personalize why each person is relevant. Track invite→qualified visit separately. Never add recipients to Buttondown, count courteous replies as signups, or pool this lane with cold traffic.

**Buttondown welcome/question email**

Subject: `Confirming the ContextDeck idea — one question`

> Thanks for joining the early-access waitlist. ContextDeck is still an unbuilt concept, so there is no ship date or guarantee it will launch.
>
> One question would help: the last time you switched to a client issue, which tabs did you have to find or reopen—and how often does that happen in a week?
>
> Planned pricing starts at $9/month if we proceed. You have not been charged, and you can unsubscribe anytime.

Count a reply as concrete only if it describes past/current behavior, frequency, cost, or credible willingness—not “sounds cool.” Keep reply text out of analytics and server logs.

## 5. Review and decision rules

### Operational validity first

Before interpreting demand, verify: page uptime; no accidental alternate CTA; correct stage/price copy; no paid spend above $150; no bot spike; Buttondown accepted and confirmed records; metadata preserved for each lane; Plausible denominator; no PII leak; warm/cold split. If the provider failed or attribution was lost for a window, exclude that window and label it; do not infer source from time.

### Decision matrix

| Result after minimums | Decision | Next action |
|---|---|---|
| Two cold lanes meet Continue; ≥8 confirmed cold signups; ≥3 concrete cold replies | **Proceed** | Conduct 5 interviews from cold responders, test a clickable concept, then write a thin MVP PRD limited to save/name/restore. Do not treat waitlist as retention proof. |
| One cold lane meets Continue plus ≥2 credible cold $9 trial/pay statements | **Proceed cautiously** | Validate the stated payment intent with a pricing/interview step before building more than a thin prototype. |
| Cold CVR meets threshold but reply evidence is weak | **Interview, no build** | Ask confirmed cold subscribers about their last incident and workaround. Pre-register a reply/interview threshold. |
| A cold lane reaches minimum at 2% to below its Continue bar | **Reshape and rerun** | Change one element only—first the hero/problem language—then rerun on the same source with fresh campaign/variant attribution. |
| Paid is weak but community/social meets Continue | **Narrow acquisition** | Stop paid; learn the winning community language. Do not average paid down with organic. |
| Warm is strong but cold is weak | **No cold validation** | Report warm learning separately; recruit customer-discovery interviews, then retest cold. Warm cannot trigger build. |
| Two cold lanes each reach minimum and stay <2%, with no concrete cold reply | **Park or change ICP/problem** | Archive evidence; do not add features to rescue the concept. |
| Any lane misses its minimum | **Inconclusive for that lane** | State the distribution/sample limitation; do not force continue/kill. |

Do not change headline, price, audience, and ad creative together. The 10-day baseline ships headline A only. A follow-up copy test uses one new `variant` and a newly registered campaign tuple, with its own minimum sample; do not retroactively recode traffic.

### Daily calculation definitions

- Confirmed CVR = unique Buttondown double-opt-in confirmed subscribers carrying the exact canonical lane/placement ÷ qualified Plausible unique visitors in the same lane/placement.
- Provider acceptance rate = accepted provider records ÷ attempts; diagnose integration only.
- Reply rate = concrete replies ÷ confirmed subscribers within that source.
- Cost per confirmed subscriber = source spend ÷ confirmed subscribers for that paid source.
- `$9 intent` requires an unsolicited or prompted credible statement of willingness to trial/pay around the stated planned starting price. It is qualitative evidence, not a payment.
- Deduplicate subscribers by Buttondown’s provider record. Do not expose email addresses in the measurement sheet shared outside the founder’s private workspace.

## 6. Explicit non-build scope

During the smoke test, do **not** build the Chrome extension, tab capture/restore logic, sync, team workspaces, CRM/help-desk integrations, AI features, permissions architecture, billing, account system, onboarding, admin console, referral program, blog, SEO program, multiple landing variants, live demo, fake product screenshot, waitlist counter, testimonials, logos, or launch-date roadmap. Build only the landing, secure signup bridge, measurement, and messages in this package.

## 7. Preflight checklist

- [ ] Replace canonical URL, contact email, and domain placeholders; verify OG preview from the live URL.
- [ ] Verify Buttondown official contract and date; replace every provider placeholder; add encrypted secret; enable double opt-in.
- [ ] Verify Plausible official contract/privacy and date; create site/goals; replace placeholders and CSP origins.
- [ ] Confirm a real valid signup reaches the right provider record with `decision_lane`, `placement`, and `variant`; confirm invalid submission does not.
- [ ] Confirm page success appears only after accepted provider response; confirm double opt-in separately.
- [ ] Exercise the full endpoint error matrix and six-second upstream timeout; inspect privacy-safe logs.
- [ ] Confirm query/hash are absent from analytics-visible URL and only bounded canonical properties leave the browser.
- [ ] Replace every UTM base URL in channel materials with the real domain; click-test all six placements.
- [ ] Create a founder/QA exclusion and verify test traffic is not in qualified denominators.
- [ ] Verify community rules, ad availability/minimums, and US targeting. Do not work around restrictions.
- [ ] Put $150 account-level/campaign controls in place and check cumulative spend daily.
- [ ] Create separate warm and cold sheet views with no cross-lane formulas.
- [ ] Freeze page copy/variant A for the baseline and record launch timestamp.

## 8. Evidence handoff

| Field | Value |
|-------|-------|
| Current decision | TBD after test |
| Evidence classes | assumption |
| Supported claims | TBD after test |
| Still unproven | Actual demand, source CVR, Buttondown/Plausible contract compatibility, willingness to pay, one-click technical feasibility, security/permissions fit, repeated usage, retention, and product value are all unproven. |
| Contradictions / exclusions | No observed results exist. Warm outreach must never be pooled with cold traffic; `unattributed`, bots, QA, rejected/duplicate/attempt-only submissions, lost-attribution windows, and rule-rejected community posts are excluded from source threshold claims. |
| Source anchors | Pre-registered plan dated 2026-08-01; after launch: dated Plausible lane export, Buttondown accepted/confirmed subscriber export with canonical attribution, private reply coding, ad spend export, and QA log — all TBD after test. |
| Next validation | Founder runs the gated 2026-08-03 to 2026-08-12 smoke test; proceed only on the pre-registered cold-lane conversion and reply signals, otherwise interview/retest/park per the matrix. |
