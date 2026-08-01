# Landing smoke test: ClientTabs

## Contents

1. Locked test design
2. Metrics and source-specific thresholds
3. Landing-page, meta, and OG copy
4. Implementation, form, events, and attribution
5. UTMs and channel copy
6. Ten-day traffic calendar
7. Decision rules and non-build scope
8. Evidence handoff

| Field | Locked value |
|---|---|
| Date prepared | 2026-08-01 |
| Test window | 2026-08-03 through 2026-08-12 (10 calendar days) |
| ICP | Hands-on support and customer-success agents at small US SaaS teams who repeatedly reopen several browser tabs per client |
| Problem | Reconstructing a client’s ticket, admin, CRM, docs, billing, or logs context tab by tab |
| Single promise | Restore a saved client-specific tab workspace in one click |
| Product stage | Unbuilt Chrome extension concept |
| Single CTA | **Join the early-access waitlist** |
| Price signal | Planned pricing from $9/month; not a locked price and no charge during this test |
| Page language | English |
| Stack | Static Cloudflare Pages + Cloudflare Pages Function + Buttondown + Plausible |
| Paid cap | $150 hard lifetime cap, USD |

## 1. Locked test design

### Hypothesis

If ClientTabs offers one-click restoration of client-specific tab workspaces to hands-on support agents at small US SaaS teams, qualified cold visitors will leave a work email at the source-specific rates below, and some will reply with a concrete repeated workflow and price interest at a planned starting price of $9/month.

This tests message-to-waitlist intent, not whether the extension works, whether users will pay, whether Chrome Web Store review will succeed, or whether customers retain.

### Primary metric

`accepted waitlist CVR = Buttondown-accepted new subscribers attributed to a source ÷ Plausible unique landing visitors from that same source`

- The denominator is Plausible unique visitors to the canonical landing page with the exact UTM source/medium slice, excluding internal QA, obvious bots, and repeat refreshes according to Plausible’s normal counting.
- The numerator is new records accepted by Buttondown with matching `utm_source`, `utm_medium`, `utm_campaign`, and `traffic_class` metadata. Duplicate, invalid, rejected, honeypot-screened, and merely attempted submissions do not count.
- Double-opted-in subscribers are tracked separately as a list-quality diagnostic.
- No warm visitor or signup is included in any cold numerator, denominator, rate, or threshold. Cold paid, cold community, cold social, and warm outreach stay on separate rows throughout.

### Secondary metrics

| Metric | Definition | Why it matters |
|---|---|---|
| CTA click-through | `click_cta` events / same-source unique visitors | Message-to-form interest; diagnostic only |
| Form attempt rate | `attempt_waitlist` events / same-source unique visitors | Finds form friction; not a conversion |
| Double-opt-in rate | Confirmed Buttondown subscribers / accepted Buttondown subscribers, same source | Deliverability and list-quality diagnostic |
| Qualified contact intent | A reply naming at least two tabs/tools reopened for a real client workflow and frequency | Stronger evidence of a repeated job |
| Price-positive reply | A reply explicitly saying $9/month is reasonable, they would expense it, or asking to buy/pilot | Directional paid intent; not payment |
| Welcome opens | Buttondown unique opens / delivered welcome emails | Noisy diagnostic only; never a build/kill criterion |
| Cost per accepted signup | Paid spend / Buttondown-accepted new subscribers from `reddit / cpc` | Paid acquisition diagnostic |

### Welcome email and reply prompt

**Subject:** What do you reopen for each client?

**Body:**

> Thanks for joining the ClientTabs early-access waitlist. This is still an unbuilt Chrome extension concept, and there is no firm ship date.
>
> I’m testing one job: saving a workspace for each client, then restoring its tabs in one click. Planned pricing starts from $9/month; joining does not start a subscription.
>
> Would you reply with three quick answers?
>
> 1. Which tabs or tools do you reopen for a typical client?
> 2. How often do you rebuild that context?
> 3. If it worked reliably, would $9/month feel reasonable, too high, or too low—and who would pay?
>
> Your reply will shape whether this gets built at all. You can unsubscribe anytime.

Buttondown should use double opt-in. Speed is not worth mixing invalid addresses into a small B2B signal; accepted and double-confirmed states remain separate.

## 2. Metrics and source-specific thresholds

Reference ranges are directional assumptions, not observed benchmarks for this product. A cohort receives a rate verdict only after its own minimum sample. If a source misses its minimum, label it **distribution inconclusive** rather than good or bad demand.

| Source cohort (never pooled) | Target / minimum qualified unique visitors | Continue signal | Weak signal after minimum | Inconclusive middle |
|---|---:|---|---|---|
| Reddit ads: `reddit / cpc` | 75 / 50 | At least 3 accepted and CVR ≥5% | 0–1 accepted and CVR ≤2% | Any other result |
| Reddit organic: `reddit / community` | 50 / 40 | At least 4 accepted and CVR ≥10% | 0 accepted | 1–3 accepted, or rate below 10% |
| LinkedIn organic: `linkedin / social` | 50 / 40 | At least 4 accepted and CVR ≥8% | 0–1 accepted and CVR ≤2.5% | Any other result |
| Warm personal email: `warm_email / outreach` | 15 / 10 | At least 3 accepted and CVR ≥20% | 0 accepted | Any other result |
| Warm LinkedIn DM: `warm_linkedin / outreach` | 15 / 10 | At least 3 accepted and CVR ≥20% | 0 accepted | Any other result |
| Direct/unknown | No target | Observe only | Never decides | Attribution is inadequate |

Warm email and warm LinkedIn DM are not pooled with each other for rate calculation, and neither may rescue a failing cold cohort. Their replies can improve interview recruitment only.

### Contact-intent bars

- **Strong cold contact intent:** at least two qualified replies from each of two independently passing cold cohorts, with at least one price-positive reply in each cohort.
- **Soft interest:** waitlist threshold passes but the same cohort produces no qualified replies within 72 hours of the welcome email.
- **Price lead:** any same-source reply asking to pay, expense, or pilot at/around $9/month. Follow up for an interview; one lead is not proof of scalable demand.
- **Operational fault:** more than 20% of valid-looking submissions error, or fewer than 60% of Buttondown-accepted emails are delivered. Stop traffic and fix capture/deliverability before interpreting demand.

### Sample and timing rules

- Freeze hero A, audience, form, and price wording for all 10 days. Ad creative A/B may vary only by problem framing and is recorded in `utm_content`.
- Do not decide from a cohort with fewer than its minimum unique visitors.
- Do not combine source rates to manufacture sample size. Show every source and `utm_content` row.
- Allow 72 hours after the final welcome email before finalizing reply metrics. The landing traffic window still closes after day 10.
- If no cold cohort reaches its minimum, the outcome is **distribution failed/inconclusive**, not a product rejection.

## 3. Landing-page, meta, and OG copy

The implemented source of record is `site/index.html`. The copy deck below makes review possible without parsing HTML.

### Meta and social copy

- **Meta title:** ClientTabs — Restore every client tab in one click
- **Meta description:** A planned Chrome extension for hands-on support agents at small SaaS teams. Save each client’s working tabs and restore the full context in one click. Planned pricing from $9/month.
- **Canonical URL:** `https://YOUR_DOMAIN.example/` (replace before deploy)
- **OG title:** Restore every client tab in one click
- **OG description:** Stop rebuilding client context tab by tab. ClientTabs is a planned Chrome extension for hands-on support agents at small US SaaS teams, with planned pricing from $9/month.
- **OG image alt:** ClientTabs: Restore every client tab in one click
- **Twitter/X description:** A planned Chrome extension for hands-on support agents at small SaaS teams. Planned pricing from $9/month.
- **Share image:** `site/og-card.png`, 1200×630; URL becomes `https://YOUR_DOMAIN.example/og-card.png`.

### Headline variants

1. **Ship for this test:** Restore every client tab in one click.
2. Stop rebuilding client context tab by tab.
3. The client workspace switcher for hands-on SaaS support.

Variants 2 and 3 are held back during this 10-day run. If the offer is reshaped, change only the headline/subhead in a separately dated round.

### Full page copy

**Navigation:** ClientTabs · **Join the early-access waitlist**

**Hero eyebrow:** For hands-on SaaS support agents

**Hero headline:** Restore every client tab in one click.

**Hero body:** Stop hunting through history and reopening the same admin, CRM, docs, and ticket tabs for every client. ClientTabs is a planned Chrome extension that saves a workspace per client and brings the full context back together.

**Price chip:** Planned from $9/month

**Stage disclosure:** Not built yet. We’re validating the workflow before development—no firm ship date.

**Hero CTA:** **Join the early-access waitlist**

**Problem heading:** Your next client is waiting. Their tabs aren’t.

- **Rebuild from memory:** You reopen the ticket, admin, CRM, docs, and logs one tab at a time.
- **Work in the wrong account:** Similar dashboards make a hurried client switch riskier than it should be.
- **Lose the investigation:** A browser restart or urgent escalation scatters the trail you were following.

**Solution heading:** Save the context once. Restore it when the client returns.

1. **Name the workspace:** Group the tabs you already use under a client name.
2. **Switch to the next case:** Keep client workspaces separate instead of leaving everything open.
3. **Restore in one click:** Bring the saved client tabs back together when the case resumes.

**Built for — Small-team support operators**

- Hands-on support and customer-success agents
- US SaaS teams where one person handles several client accounts
- Browser-heavy workflows repeated across tickets and escalations

**Not designed for — A replacement for your support stack**

- Teams looking for a ticketing system or CRM
- Workflows that do not happen primarily in Chrome
- Anyone expecting the extension to log in or take actions on their behalf

**Proof section heading:** No customer wall. No invented launch date.

**Founder note:** ClientTabs is a concept, not a finished extension. This page tests whether client-specific tab restore is painful and valuable enough to build. Early-access members will receive a short validation update and may be invited to shape the smallest useful version. There are no customer claims yet.

**FAQ**

1. **Is ClientTabs available now?** No. It is an unbuilt Chrome extension concept under validation. Joining signals interest; it does not guarantee access or a delivery date.
2. **What would it cost?** The planned starting price is $9/month. Pricing may change as the useful scope becomes clearer, and joining the waitlist does not start a subscription.
3. **What would the extension store?** The concept is to save client workspace names and tab URLs needed for restoration—not page contents or passwords. The exact architecture and privacy model are still unbuilt and will be documented before any install is offered.
4. **Will it open or act inside client accounts?** The proposed one-click action restores saved tabs. It would not log in, send messages, or perform account actions for you.
5. **What happens after I join?** Buttondown will ask you to confirm your email. You’ll receive a short welcome note asking about your current workflow, plus occasional product-validation updates. You can unsubscribe at any time.
6. **How will my information be used?** Your email and optional answers are stored in Buttondown for this early-access list and will not be sold. Plausible provides aggregate, cookie-free page analytics. Contact the founder to request deletion.

**Final block headline:** Spend less time rebuilding client context.

**Final block body:** Tell us just enough to distinguish real support workflows from casual interest. Only email is required. **Planned pricing from $9/month. No charge today.**

**Form fields:** Work email (required); role, support team size, and “What do you reopen for each client?” (optional).

**Consent line:** By joining, you agree to receive validation and early-access email from ClientTabs. Unsubscribe anytime. Your details are stored in Buttondown and are not sold.

**Form CTA:** **Join the early-access waitlist**

**Accepted state:** Buttondown accepted your request. Check your inbox to confirm your email.

**Footer:** © 2026 ClientTabs · An unbuilt product concept · Questions or deletion requests: `founder@example.com` (replace before deploy).

There are intentionally no testimonials, customer logos, user counts, ratings, availability claim, or firm ship date.

## 4. Implementation, form, events, and attribution

### Architecture

```text
UTM landing view → Plausible pageview
CTA anchor click → Plausible click_cta
Form submit attempt → Plausible attempt_waitlist
POST /api/waitlist → Cloudflare Pages Function validates + derives traffic class
Buttondown API 2xx → accepted UI + diagnostic Plausible waitlist_accepted_client
Buttondown subscriber export → authoritative conversion numerator
```

| Item | Specification |
|---|---|
| Host | Cloudflare Pages; static output `site/`, Pages Functions at `functions/` |
| Form endpoint | Same-origin `POST /api/waitlist`; Buttondown key stays in encrypted `BUTTONDOWN_API_KEY` |
| Required field | `email` |
| Optional fields | `role`, `team_size`, `pain` |
| Bot field | Invisible `company_website`; screened submissions never reach Buttondown |
| Attribution | Browser sends four UTM fields; server sanitizes them and derives `traffic_class`; Buttondown stores both as metadata and tags |
| Consent | Explicit consent line plus Buttondown double opt-in |
| Accepted UI | Only after the server receives Buttondown 2xx; errors remain errors |
| Source of truth | Buttondown accepted-subscriber export joined by exact UTM slice; client event is diagnostic only |
| Privacy | Buttondown stores submitted details; Plausible supplies aggregate cookie-free analytics; no sale of list |

### Plausible events

| Event | Trigger | Properties | Counts as conversion? |
|---|---|---|---|
| automatic pageview | Plausible script loads | URL/UTMs handled by Plausible | Denominator only |
| `click_cta` | Nav or hero CTA click | `source_class`, `location` | No |
| `attempt_waitlist` | Locally valid form submit begins | `source_class` | No |
| `waitlist_accepted_client` | Same-origin endpoint reports Buttondown 2xx | `source_class` | No; diagnostic mirror only |

Do not create a `submit_waitlist` browser event and do not use `waitlist_accepted_client` as the conversion numerator. Network blockers can suppress Plausible while Buttondown accepts a record; Buttondown remains authoritative.

### Server-derived traffic classes

| Rule | Class |
|---|---|
| `utm_medium=outreach` and source is `warm_email` or `warm_linkedin` | `warm_outreach` |
| `utm_medium=cpc` | `cold_paid` |
| `utm_medium=community` | `cold_community` |
| `utm_medium=social` | `cold_social` |
| Anything else | `direct_or_unknown` |

This server derivation prevents a client-provided class from silently mixing warm and cold. Report the two warm sources separately even though they share a class tag.

### Preflight launch gate

1. Replace domain and email placeholders; deploy Preview, then Production.
2. Verify the production page, canonical, OG image, mobile layout, keyboard focus, and FAQ interactions in real browsers.
3. Check Buttondown’s current API schema for `email_address`, `tags`, and `metadata`; update only if official docs require it.
4. Submit one invalid email per cohort: it must not create a Buttondown record or accepted UI.
5. Submit one real valid email using each UTM link. Confirm Buttondown accepts it, stores the exact UTM values and traffic class, sends double opt-in, and the page shows accepted UI only after 2xx.
6. Confirm duplicates/rejections do not show accepted UI and are not counted.
7. Confirm Plausible receives pageview, `click_cta`, `attempt_waitlist`, and the diagnostic accepted event with the expected properties.
8. Tag all operator checks `utm_source=internal&utm_medium=qa&utm_campaign=clienttabs_smoke_202608` and exclude them from every result.
9. Set the ad platform lifetime cap to exactly $150, US only, and take a screenshot of the cap before launch.
10. Do not buy traffic until steps 1–9 pass.

External-provider behavior is not verified in this offline package. In particular, Buttondown’s live API fields and Plausible’s live event receipt must be confirmed in owned accounts before launch.

## 5. UTMs and channel copy

Use the final HTTPS origin in place of `https://YOUR_DOMAIN.example/`. Never shorten links in the experiment log; if a platform wraps them, preserve the original UTM destination.

| Source | Exact landing URL |
|---|---|
| Reddit organic | `https://YOUR_DOMAIN.example/?utm_source=reddit&utm_medium=community&utm_campaign=clienttabs_smoke_202608&utm_content=customersuccess_problem` |
| LinkedIn organic post 1 | `https://YOUR_DOMAIN.example/?utm_source=linkedin&utm_medium=social&utm_campaign=clienttabs_smoke_202608&utm_content=founder_problem_post` |
| LinkedIn organic post 2 | `https://YOUR_DOMAIN.example/?utm_source=linkedin&utm_medium=social&utm_campaign=clienttabs_smoke_202608&utm_content=workflow_followup` |
| Reddit ad A | `https://YOUR_DOMAIN.example/?utm_source=reddit&utm_medium=cpc&utm_campaign=clienttabs_smoke_202608&utm_content=ad_a_rebuild_tabs` |
| Reddit ad B | `https://YOUR_DOMAIN.example/?utm_source=reddit&utm_medium=cpc&utm_campaign=clienttabs_smoke_202608&utm_content=ad_b_resume_case` |
| Warm personal email | `https://YOUR_DOMAIN.example/?utm_source=warm_email&utm_medium=outreach&utm_campaign=clienttabs_smoke_202608&utm_content=personal_note` |
| Warm LinkedIn DM | `https://YOUR_DOMAIN.example/?utm_source=warm_linkedin&utm_medium=outreach&utm_campaign=clienttabs_smoke_202608&utm_content=personal_note` |

### Reddit organic draft

**Suggested community:** r/CustomerSuccess. Verify that it exists, that the audience includes hands-on SaaS support operators, and that current rules allow maker research before posting. If linking is disallowed, do not evade the rule; skip the post and record distribution failure for this source.

**Title:** How do you rebuild client context when a support case comes back?

**Body:**

> I keep seeing a browser-heavy support pattern: a case comes back, and the agent reopens the ticket, customer admin, CRM, docs, billing, and logs one tab at a time. The tabs are predictable; reconstructing them is not useful work.
>
> I’m the maker testing an unbuilt Chrome extension concept called ClientTabs. The narrow idea is to save a tab workspace per client and restore it in one click. It would not log in or take actions for the agent. Planned pricing would start from $9/month, but there is no firm ship date.
>
> Is this a repeated problem on small SaaS support teams, or do existing browser profiles/tab groups already solve it? Concrete workflows and objections are more useful than encouragement.
>
> If this is your workflow: **Join the early-access waitlist:** [UTM link]

**Do:** disclose maker status, answer every substantive reply, invite objections, use one link only. **Don’t:** repost identical copy across subreddits, claim the tool exists, argue with moderators, or DM commenters without permission.

### LinkedIn cold-social draft 1

> A reopened support case often starts with five tiny chores:
>
> Find the ticket. Open the customer admin. Pull up the CRM. Find the right runbook. Reopen the logs.
>
> I’m validating ClientTabs, an unbuilt Chrome extension concept for hands-on agents at small SaaS teams: save one tab workspace per client, then restore the context in one click.
>
> It is not available yet, there is no firm ship date, and planned pricing starts from $9/month. I want to learn whether this is painful enough to build before writing the extension.
>
> **Join the early-access waitlist:** [UTM link]

### LinkedIn cold-social draft 2

> Tab groups organize a browser. But do they preserve the context of Client A, Client B, and Client C in the way a support agent actually switches cases?
>
> That distinction is the whole ClientTabs smoke test: client-specific workspaces, restored in one click. Still unbuilt. Planned from $9/month. No invented launch date.
>
> If your support work lives across tickets, admin, CRM, docs, and logs, **join the early-access waitlist:** [UTM link]

### Warm personal email / DM draft

Send only to people the founder genuinely knows and reasonably believes match the ICP. Personalize the first line; never mass blast.

> Hi [Name] — I remember you mentioning [specific support/client workflow]. I’m testing an unbuilt Chrome extension idea before deciding whether to build it: save a tab workspace for each client, then restore the ticket/admin/CRM/docs context in one click. Planned pricing would start from $9/month; no firm ship date.
>
> If that matches your own workflow, **join the early-access waitlist:** [warm-source UTM link]. A blunt “we already solve this with X” is equally useful.

### Reddit ad copy

Target US desktop users in currently available customer-success/support/SaaS buyer communities; verify platform availability and policy in the ad account. Do not use broad Chrome-extension-interest targeting.

**Ad A**

- Headline: Reopen the same client tabs every time?
- Body: ClientTabs is a planned Chrome extension for hands-on SaaS support agents. Save a workspace per client and restore it in one click. Planned from $9/month. Not built yet.
- CTA text in copy: **Join the early-access waitlist**

**Ad B**

- Headline: Resume a client case with its context intact
- Body: Restore the ticket, admin, CRM, docs, and logs tabs you saved for that client. An unbuilt Chrome extension concept for small SaaS support teams. Planned from $9/month.
- CTA text in copy: **Join the early-access waitlist**

Run both creatives 50/50 against the same audience and page. Do not change targeting, hero, form, or price. Record each `utm_content`; the pre-registered paid-cohort verdict may combine A and B because audience, medium, offer, and page are identical, but creative diagnostics remain separate. Nothing paid is pooled with organic or warm traffic.

## 6. Ten-day traffic calendar

| Day / date | Channel | Action | Spend | Evidence/stop condition |
|---|---|---|---:|---|
| 1 · Mon Aug 3 | Internal QA only | Deploy Cloudflare; complete all 10 launch-gate steps; save screenshots and provider records | $0 | No public traffic until capture and attribution pass |
| 2 · Tue Aug 4 | Dry run | Test all seven UTM URLs, welcome/double-opt-in, mobile, OG preview where available; prepare community post after checking rules | $0 | QA traffic tagged and excluded |
| 3 · Wed Aug 5 | Reddit organic + warm email | Publish one value-first r/CustomerSuccess post if permitted; send 5 personalized warm emails | $0 | Reply to comments; never DM commenters unsolicited |
| 4 · Thu Aug 6 | LinkedIn organic + warm LinkedIn | Publish cold-social post 1; send 5 personalized warm DMs | $0 | Log the two sources separately |
| 5 · Fri Aug 7 | Reddit ads | Launch A/B at $15 each; US desktop, one verified buyer-community audience | $30 | Confirm landing traffic and spend cap; pause immediately for capture faults |
| 6 · Sat Aug 8 | Reddit ads + replies | Keep A/B at $15 each; answer Reddit/LinkedIn comments; send 5 more warm emails | $30 | Creative with zero landing visits is eligible to pause; reallocate only within paid cohort |
| 7 · Sun Aug 9 | Reddit ads | Keep total daily budget $30; inspect source rows without changing page or audience | $30 | If paid CPC implies fewer than 50 visits at full cap, continue only to learn distribution feasibility; do not call demand weak |
| 8 · Mon Aug 10 | Reddit ads + LinkedIn | Spend $30; publish LinkedIn post 2; send 5 more warm DMs | $30 | Stop any channel attracting clearly non-US/non-ICP traffic and document exclusion |
| 9 · Tue Aug 11 | Reddit ads + follow-up | Spend final $30; answer comments; send welcome reminder only through Buttondown’s consent-safe flow | $30 | Lifetime spend reaches, never exceeds, $150 |
| 10 · Wed Aug 12 | All sources | Stop acquisition; export Plausible and Buttondown slices; reconcile accepted records; send direct reply prompt to confirmed subscribers if needed | $0 | Freeze traffic dataset; wait 72 hours for replies before final intent verdict |

**Budget control:** Configure a platform lifetime budget of $150, not merely a daily estimate. Planned spend is 5 × $30 = **$150 maximum**. Taxes, credits, or platform overdelivery must not cause cash spend above $150; lower the platform cap if the account applies tax on top. No other paid channel is authorized.

**Traffic-quality note:** Reddit and LinkedIn community availability, rules, audience size, and ad pricing were not checked because web/browser access was unavailable. If a named placement is unavailable or disallows the post, skip it and mark that source as distribution inconclusive; do not substitute a broad untargeted audience mid-test.

## 7. Decision rules and non-build scope

### Decision matrix

| Result after minimum samples and reply window | Decision | Next action |
|---|---|---|
| Two independent cold cohorts each pass their own CVR bar, and each produces ≥2 qualified replies including ≥1 price-positive reply | **Continue to a thin MVP definition** | Interview those respondents; test a paid pilot/deposit before implementing tab storage |
| One cold cohort passes; another is middle/inconclusive; warm sources are strong | **Narrow and retest** | Follow the passing cold source/role; do not use warm CVR as proof; run one controlled headline retest |
| A cold cohort passes CVR but yields zero qualified replies after 72 hours | **Soft demand—interview first** | Ask accepted subscribers about current workaround, frequency, security, and buyer; no build authorization |
| Cold cohorts miss minimum visitors | **Distribution inconclusive** | Improve access/placement and rerun; do not alter the product conclusion |
| Every cold cohort that reaches minimum is weak, with no cold price-positive replies | **Reshape/park the current offer** | Do not build; revisit ICP/problem language. Warm success does not override this |
| Operational fault threshold is hit | **Invalid test** | Pause spend, repair provider/attribution/deliverability, restart with a new dated dataset |
| One “invoice me” or pilot request appears | **Paid-intent lead, not scale proof** | Interview and offer a truthful paid-intent test only after defining refund/delivery terms |

A weak 10-day run does not prove the underlying problem is dead. Permanently killing the idea requires a second controlled offer/headline round and roughly 200 qualified cold visits across the two rounds with sustained sub-2% accepted CVR, adequate attribution, and no credible paid-intent replies.

### Dashboard procedure

1. Copy `measurement-template.csv` into a dated working sheet.
2. Keep one row per date × exact source × medium × campaign × content. Never add warm and cold rows together for CVR.
3. Export Plausible unique visitors and events by exact UTM slice.
4. Export Buttondown accepted and double-confirmed subscribers with metadata. Deduplicate by Buttondown subscriber ID/email; do not back-allocate unattributed records by time.
5. Calculate each row and cohort only when numerator and denominator attribution match. Place direct/unknown records in their own non-decision row.
6. Attach dated screenshots/exports to the result record and write exclusions before applying the matrix.

### What not to build during this smoke

- No Chrome extension, tab permission flow, sync engine, authentication, billing, team admin, CRM/ticket integrations, onboarding, or Chrome Web Store listing.
- No product demo presented as working software; the browser card is a labeled conceptual illustration.
- No multi-page marketing site, blog, referral system, SEO program, brand system, testimonials, logo strip, waitlist counter, or ship-date countdown.
- No pre-order or payment flow. The test exposes a planned starting price and measures replies, not transactions.
- No second CTA, scheduling link, “request demo,” free trial, or download button.

## 8. Evidence handoff

| Field | Value |
|---|---|
| Current decision | TBD after test |
| Evidence classes | assumption |
| Supported claims | TBD after test |
| Still unproven | Working one-click restore, willingness to pay, acquisition economics, security/privacy acceptance, Chrome Web Store approval, retention, and team adoption |
| Contradictions / exclusions | TBD after test |
| Source anchors | TBD after test |
| Next validation | Founder runs the preflight gate and 10-day test; pass only under the source-specific thresholds above, with warm and cold kept separate |
