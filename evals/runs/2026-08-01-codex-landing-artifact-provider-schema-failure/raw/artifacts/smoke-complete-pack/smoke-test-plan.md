# 10-day landing smoke test: Restoreboard (working name)

| Item | Pre-registered specification |
|---|---|
| Test dates | August 3–12, 2026 (10 calendar days) |
| ICP | Hands-on support agents at US SaaS teams of roughly 5–100 employees who repeatedly switch among client-specific tickets, admin pages, docs, and dashboards |
| Problem | Rebuilding the same client context from history, bookmarks, and open tabs before useful support work can begin |
| Promise | Restore every client-specific tab workspace in one click |
| Offer | Early-access waitlist; planned pricing from $9/month; no charge and no promised ship date |
| Single landing CTA | **Join the early-access waitlist** |
| Stack | Cloudflare Pages + Pages Function, Buttondown double opt-in, Plausible |
| Paid cap | $150 total, Reddit Ads only; hard stop at $150 |
| Current evidence | Assumptions only. The page has not received traffic and the product is unbuilt. |

## 1. Smoke protocol

### Hypothesis

If a planned Chrome extension promises one-click restoration of client-specific tab workspaces to hands-on support agents at small US SaaS teams, then at least two **cold** source lanes will independently clear their pre-registered visitor-to-active-waitlist thresholds during August 3–12, with at least eight cold active subscribers total, three substantive cold replies describing recurring context-rebuild behavior, and two cold respondents expressing credible willingness to try the product at pricing from $9/month.

Warm outreach is a message-quality diagnostic only. It is recorded, exported, and decided separately; it can never rescue or inflate a cold result.

### Metric definitions

- **Qualified unique visitor:** a unique Plausible visitor from the US on an exact allow-listed UTM combination, excluding obvious bots, the founder, QA traffic, duplicate same-day visits, and traffic outside the intended support/SaaS context when identifiable. Pageviews with missing or changed UTMs remain `unattributed`.
- **CTA click:** Plausible `CTA Click`. This shows offer curiosity, not conversion.
- **Waitlist attempt:** Plausible `Waitlist Attempt`. Invalid, rejected, duplicate, or failed requests do not count as conversions.
- **Provider acceptance:** Buttondown returns success to the Cloudflare Pages Function. Plausible `Waitlist Accepted` is operational telemetry only; it is not the primary conversion.
- **Active waitlist conversion (primary):** an active Buttondown subscriber after double opt-in, carrying the exact source-lane tag. The dated Buttondown active-subscriber export is the numerator and source of truth.
- **Source CVR:** source-tagged active Buttondown subscribers ÷ qualified Plausible unique visitors for the same exact source lane and date window.
- **Substantive reply:** a human reply describing past/current client-context rebuilding, frequency, consequences, or a current workaround. Praise or “cool idea” alone is not substantive.
- **Credible paid intent:** an unsolicited or prompted reply explicitly saying the respondent would personally/team-wise try, buy, expense, or ask for approval at the disclosed starting price. A page view or signup is not paid intent.
- **Open rate:** a noisy deliverability diagnostic only; never a go/kill signal.

### Source-specific thresholds

These are pre-test assumptions, not external benchmarks. A lane below its minimum qualified sample is **inconclusive**, regardless of its apparent rate. Do not pool lanes to make a source pass.

| Lane | Traffic class | Minimum qualified uniques | Strong | Weak / reshape at minimum sample |
|---|---|---:|---|---|
| `warm_dm` | Warm | 20 | ≥4 active (≥20%) and ≥2 substantive replies | ≤1 active (≤5%) or zero substantive replies |
| `reddit_organic` | Cold community | 50 | ≥3 active (≥6%) and ≥1 substantive reply | 0 active or <2% |
| `support_driven` | Cold niche community | 30 | ≥3 active (≥10%) and ≥1 substantive reply | 0 active or <3% |
| `x_organic` | Cold/mixed social | 40 | ≥2 active (≥5%) and ≥1 substantive reply | 0 active or <2% |
| `reddit_ads` | Cold paid | 75 | ≥3 active (≥4%) and cost per active ≤$50 | ≤1 active or <1.5%; also fail paid acquisition if cost per active >$75 |

**Paid stop gate:** pause after the first $60 or 40 qualified ad visitors, whichever comes first, if there are zero provider-accepted requests. Fix delivery/creative once; do not spend the remaining $90 until the landing and tag path pass QA again. The cumulative account/campaign spend must never exceed $150.

**Contact-intent bar:** cold evidence requires ≥3 substantive cold replies across independently tagged cold sources. **Price-intent bar:** ≥2 of those cold respondents must credibly accept testing at “from $9/month.” These are required in addition to page conversion for a build decision.

### Sample and integrity rules

1. Never add `warm_dm` visits or conversions to a cold numerator, denominator, CVR, reply count, or headline claim.
2. Only exact allow-listed source/medium/campaign/content combinations enter named lanes. Everything else is `unattributed` and excluded from lane thresholds.
3. Do not infer source from signup time or distribute an untagged Buttondown total across sources.
4. Freeze the shipped headline for days 1–5. If a reset is warranted, change only the headline on day 6, label it `v2`, and require a fresh comparable window; never blend v1/v2 rates.
5. A provider-accepted but not double-opted-in record is a funnel diagnostic, not an active waitlist conversion.
6. Do not declare a lane weak before its minimum sample. If distribution cannot reach the minimum, record distribution failure separately from offer failure.

## 2. Final English landing copy

The full implemented wording is in `landing/index.html`. This is the approved copy deck.

### Meta and Open Graph

- **Meta title:** Restore Client Tab Workspaces in One Click | Early Access
- **Meta description:** A planned Chrome extension for hands-on support agents at small US SaaS teams. Restore each client's working tabs in one click. Join the early-access waitlist.
- **OG title:** Restore every client tab workspace in one click
- **OG description:** A planned Chrome extension for hands-on support agents at small US SaaS teams. Planned pricing from $9/month.
- **OG card line:** Restore every client tab workspace in one click. Planned pricing from $9/month.
- **Canonical/OG URL:** `https://YOUR_DOMAIN.example/` until replaced
- **OG image:** `og-card.png`, 1200×630

### Headline variants

1. **Ship first:** Restore every client tab workspace in one click.
2. Stop rebuilding the same client tabs for every support case.
3. The client workspace switcher for hands-on SaaS support.

Variant 1 runs on days 1–5. Variant 2 is the only permitted retest headline and only if the day-5 review triggers a reset. Variant 3 is held for a later test, not rotated concurrently.

### Page copy

**Nav:** Restoreboard (working name) · “Join the early-access waitlist”

**Hero label:** Planned Chrome extension

**Hero headline:** Restore every client tab workspace in one click.

**Hero body:** For hands-on support agents at small US SaaS teams who lose time rebuilding the right mix of admin pages, tickets, docs, and dashboards for each client.

**Price line:** Planned pricing from $9/month. No charge today.

**Problem heading:** Client support should not start with a tab scavenger hunt.

- **Rebuild the same setup:** You search history, bookmarks, and old tickets to reconstruct a client’s working context.
- **Mix up client context:** Look-alike admin pages and dashboards make the wrong account an easy, stressful mistake.
- **Lose momentum between cases:** Each switch interrupts the investigation before the real support work even begins.

**Solution heading:** Save the context once. Bring it back when that client needs you.

1. **Save a client workspace:** Group the tabs you use for one client under a clear client name.
2. **Close the clutter:** Move on without keeping every client’s tabs open all day.
3. **Restore in one click:** Reopen that client’s saved working set when a ticket or escalation arrives.

**Built for:** Support agents who work across multiple client accounts; small US SaaS teams without a custom support console; workflows spread across tickets, admin pages, docs, and dashboards.

**Not designed for:** General bookmark organization; personal research/read-later lists; large enterprises needing centralized policy controls on day one.

**Honest proof/founder note:** This is a demand test, not a finished extension. I’m validating whether client-specific context restore is painful and valuable enough to build. There are no customer claims yet and no firm ship date. Early-access members will receive brief product updates and may be invited to shape the first version.

**FAQ:**

- **Is the Chrome extension available now?** No. This page is testing demand before the product is built. Joining expresses interest; it does not guarantee access by a particular date.
- **What will it cost?** Planned pricing starts from $9/month. That price may change as the product is defined, and joining the waitlist does not create a purchase or lock in a price.
- **What would the extension store?** The intended product would need tab titles and URLs to restore a workspace. The storage and permission design is not final. Privacy and least-privilege access will be evaluated before any release.
- **What happens after I join?** Buttondown will ask you to confirm your email. After confirmation, you may receive short product updates or a request for feedback. You can unsubscribe anytime.
- **Who is this not for?** It is not a general bookmark manager, a team knowledge base, or an enterprise browser-administration suite.
- **Will you sell my email?** No. Your email is stored by Buttondown and used only for this early-access list and related product research. It will not be sold.

**Final block heading:** Spend less time rebuilding client context.

**Final block body:** Join the list if one-click client workspace restore would make hands-on support easier.

**Form:** Work email · “Join the early-access waitlist”

**Form disclosure:** Double opt-in. No charge today. Unsubscribe anytime. Email stored by Buttondown; analytics by Plausible.

**Accepted state:** Request accepted — check your inbox to confirm your email.

**Error state:** We couldn’t send that request. Please try again in a moment.

## 3. Implementation and measurement

### Architecture

`landing/index.html` is a mobile-first static page. Its same-origin form posts to `landing/functions/api/waitlist.js`. The Pages Function validates email, allow-lists the full UTM tuple, maps it to a Buttondown tag ID held in an environment variable, calls Buttondown server-side, and returns only a bounded status. The API token never reaches the browser.

Use this Cloudflare Pages variable shape, replacing every placeholder with the immutable Buttondown tag ID:

```json
{
  "warm_dm": "TAG_ID_WARM_DM",
  "reddit_organic": "TAG_ID_REDDIT_ORGANIC",
  "support_driven": "TAG_ID_SUPPORT_DRIVEN",
  "x_organic": "TAG_ID_X_ORGANIC",
  "reddit_ads": "TAG_ID_REDDIT_ADS",
  "unattributed": "TAG_ID_UNATTRIBUTED"
}
```

- Secret: `BUTTONDOWN_API_KEY`
- Variable: `BUTTONDOWN_TAG_MAP_JSON`
- Buttondown: double opt-in on; confirmation and unsubscribe enabled.
- Email field: required. No name or free-text field on the page to minimize friction.
- Provider logs: never store emails, request bodies, free text, tokens, authorization headers, or raw provider bodies. Only bounded error category, HTTP status, and non-PII request ID may be used for diagnosis.
- Rate/bot protection: start with Cloudflare’s managed protections. If abuse appears, add Turnstile only after documenting the added friction; exclude pre/post-change rates from a single comparison.

The Buttondown API endpoint and payload in the Function must be checked against the current Buttondown account/API documentation before launch. Web access was unavailable while this package was authored, so the external contract could not be live-verified.

### Event dictionary

| Signal | Trigger | System | Decision use |
|---|---|---|---|
| Pageview | Plausible loads on landing view | Plausible automatic pageview with UTM | Source denominator after US/bot/QA filtering |
| `CTA Click` | A nav/hero CTA scroll link is clicked | Plausible custom event with derived lane | Curiosity diagnostic only |
| `Waitlist Attempt` | A locally valid form is submitted | Plausible custom event with lane | Form-friction diagnostic only |
| `Waitlist Accepted` | Cloudflare Function receives a successful Buttondown response | Plausible custom event with lane | Integration diagnostic; not primary conversion |
| `Waitlist Error` | Request fails/rejects | Plausible custom event with allow-listed error category | Operational QA only |
| Active subscriber | Double opt-in completed and tagged record appears | Buttondown dated export | **Primary conversion numerator** |
| Substantive reply | Human response is manually coded against definition | Buttondown/manual ledger | Contact intent |
| Credible paid intent | Reply passes the pre-registered definition | Manual ledger | Price intent |

Do not create or emit a client-side `submit_waitlist`/confirmed-conversion event. The browser cannot prove double opt-in. The local accepted state truthfully asks the person to check their inbox.

### Dashboard formulas

- Source CVR = `buttondown_active_double_opt_in / qualified_unique_visitors`
- CTA rate = `cta_clicks / qualified_unique_visitors`
- Attempt-to-accept = `buttondown_accepted / waitlist_attempts`
- Activation rate = `buttondown_active_double_opt_in / buttondown_accepted`
- Paid cost per active = `reddit_ads spend / reddit_ads active subscribers`
- Reply rate = `substantive replies / active subscribers` (reported by source)

Record raw counts daily in `measurement-template.csv`; compute rates only in a separate summary so zeros and exclusions remain visible. Never create an “all traffic” CVR containing warm and cold.

### Preflight acceptance tests

1. Replace domain/email placeholders and install the exact Plausible account snippet.
2. Submit a valid unique address from every UTM URL; complete double opt-in; verify the matching Buttondown tag on each active record.
3. Test missing UTMs and a one-character-mutated campaign. Both must become `unattributed`, never warm/cold.
4. Test invalid email, Buttondown rejection, duplicate address, and temporary provider failure. None may create an active conversion or a false “you’re on the list” state.
5. Reconcile a one-day QA export: Plausible accepted diagnostics versus Buttondown accepted/active records. Delete/label all QA records before day 1.
6. Confirm no PII or provider response body appears in Cloudflare logs.

## 4. Exact UTM links

Replace only the domain; do not edit any UTM value after launch.

- Warm DM: `https://YOUR_DOMAIN.example/?utm_source=dm&utm_medium=outreach&utm_campaign=restore_smoke_202608&utm_content=support_agent`
- Reddit organic: `https://YOUR_DOMAIN.example/?utm_source=reddit&utm_medium=community&utm_campaign=restore_smoke_202608&utm_content=r_customersuccess`
- Support Driven: `https://YOUR_DOMAIN.example/?utm_source=support_driven&utm_medium=community&utm_campaign=restore_smoke_202608&utm_content=member_post`
- X organic: `https://YOUR_DOMAIN.example/?utm_source=x&utm_medium=social&utm_campaign=restore_smoke_202608&utm_content=founder_post`
- Reddit Ads: `https://YOUR_DOMAIN.example/?utm_source=reddit_ads&utm_medium=cpc&utm_campaign=restore_smoke_202608&utm_content=support_context_v1`

Shorteners are not permitted because they obscure QA. Never reuse the warm link in a public post.

## 5. Traffic calendar: August 3–12, 2026

| Day | Channel/action | Spend cap | Checkpoint |
|---|---|---:|---|
| 1 — Mon Aug 3 | Publish on Cloudflare Pages; complete preflight; send 8 individually written warm DMs | $0 | QA rows removed; `warm_dm` only |
| 2 — Tue Aug 4 | Send 7 more warm DMs; publish X problem post; reply to every relevant response | $0 | Record warm and X separately |
| 3 — Wed Aug 5 | Send final 5 warm DMs; post value-first Reddit discussion only if rules allow | $0 | 20 warm asks complete; no cross-sub spam |
| 4 — Thu Aug 6 | Ask Support Driven moderator/admin permission; post only if approved; X follow-up | $0 | Permission URL/note logged |
| 5 — Fri Aug 7 | Launch one Reddit Ads creative/US audience; no headline edits | $30 | Check clicks, qualified visits, errors |
| 6 — Sat Aug 8 | Continue ads only if delivery is relevant; first fixed review; allow at most one headline reset | $30 | Apply $60/40-visitor zero-acceptance stop gate |
| 7 — Sun Aug 9 | Reply to community comments; no new community blast; ads only if gate passed | $30 | Export active subscribers by tag |
| 8 — Mon Aug 10 | X founder update; one respectful Reddit follow-up comment where invited; email confirmed subscribers the one-question note | $30 | Code replies without upgrading praise |
| 9 — Tue Aug 11 | Final paid tranche only if paid gate passed; personally follow up with responders who described the pain | $30 | Hard cumulative spend cap $150 |
| 10 — Wed Aug 12 | Stop all traffic at 23:59 America/New_York; export Plausible/Buttondown; dedupe, classify, and apply rules | $0 | Write per-source verdicts; warm appendix separate |

Do not compensate for low traffic by blasting unrelated subreddits or groups. A missed minimum is an inconclusive/distribution result.

## 6. Channel copy and conduct

### Warm DM — 20 known, ICP-matching people only

> Hey [Name] — I’m testing an idea for support agents who repeatedly rebuild a client’s ticket/admin/docs tabs when switching accounts. The promise is one-click restore of a saved client workspace. It isn’t built yet, and planned pricing starts from $9/month. Would you take two minutes to react to the page? [WARM UTM LINK]

Do personalize the observed reason they might fit. Do not ask them to share publicly, imply a favor is a purchase signal, or reuse their reaction as a testimonial without explicit permission. Record this lane only as warm.

### X post 1 — problem story

> Support agents often start a client case by hunting through history, bookmarks, tickets, admin pages, docs, and dashboards just to rebuild context. I’m testing a planned Chrome extension that restores each client’s tab workspace in one click. Not built yet; planned from $9/month. [X UTM LINK]

### X post 2 — transparent test update

> I’m deliberately testing this before building: one user, one job, one promise. For hands-on support agents at small SaaS teams: would one-click restore of client-specific tab workspaces remove real friction, or is the current workaround good enough? Details: [X UTM LINK]

Do engage concrete objections. Do not present impressions as demand or use a fake screenshot.

### Reddit discussion draft

Suggested community: `r/CustomerSuccess` only after confirming current rules, relevance, and self-promotion policy.

**Title:** How do hands-on support teams restore client context without keeping 100 tabs open?

> I’m researching a workflow I’ve seen around hands-on SaaS support: one client case needs a ticket, customer admin, account dashboard, and runbook; switching clients means rebuilding that set or leaving everything open.
>
> I’m the maker testing a narrow idea before building it: save those tabs as a client workspace and restore them in one click. It would be a Chrome extension, with planned pricing from $9/month. No product or ship date exists yet.
>
> What do you do today, and how often does the rebuild actually hurt? If the rules allow a research link, the early-access page is here: [REDDIT UTM LINK]

Do disclose the maker relationship and answer every substantive comment. Do not repost identical copy to multiple subreddits, direct-message commenters without permission, or post if links/research solicitations are disallowed.

### Support Driven community draft

Send to a moderator first: “I’m running a 10-day, pre-build demand test for a client-tab workspace restorer for hands-on SaaS support. May I post one transparent research/waitlist message? I’ll disclose I’m the maker and won’t DM members.”

If approved:

> Maker/research disclosure: I’m testing, before building, whether client-specific browser context is a real support pain. The idea is a Chrome extension that restores a saved set of ticket/admin/docs/dashboard tabs for one client in one click. It’s not available and has no firm ship date; planned pricing starts from $9/month. I’d value examples of how your team handles this today. The early-access page is here if the problem is familiar: [SUPPORT DRIVEN UTM LINK]

Do retain the permission note. Do not post without approval or harvest member details.

### Reddit Ad

- **Headline:** Reopen every client support workspace in one click
- **Body:** A planned Chrome extension for hands-on support agents at small US SaaS teams. Save each client’s working tabs and restore them together. Planned from $9/month; no charge today.
- **Button/link:** Use the platform’s closest allowed signup label, but the destination page’s sole CTA remains “Join the early-access waitlist.”
- **Audience:** US only; communities/interests related to customer success, SaaS support, help desk, and technical support; exclude broad productivity targeting.
- **Creative:** Use the provided OG card; one creative only during this test.

Do cap campaign lifetime spend at $150 and check geography/placement. Do not retarget warm contacts, upload contact lists, or optimize against the client event as if it were a confirmed active subscriber.

## 7. Buttondown messages

Buttondown owns the confirmation email. Keep its confirmation action limited to confirming the subscription.

**Confirmation subject:** Confirm your Restoreboard early-access request

**Confirmation body:**

> You asked to join the early-access waitlist for Restoreboard (working name), a planned Chrome extension for restoring client-specific tab workspaces. Confirm your email using Buttondown’s confirmation button below. If you did not request this, you can ignore this email.

**Welcome subject:** Quick question about your client-tab workflow

**Welcome body:**

> Thanks for confirming your interest in Restoreboard (working name). This is a pre-build demand test for a Chrome extension that would restore a client-specific set of tabs in one click. There is no firm ship date, and planned pricing starts from $9/month.
>
> If you reply, what happened the last time you had to rebuild a client’s support context—what did you open, and how often does that happen?
>
> I read every reply. You can unsubscribe using the link below.

On day 8, send the same note only to active subscribers who have not already replied. Do not count opens as demand and do not send a second price survey within the 10 days.

## 8. Decision rules

Apply these after the day-10 cutoff and provider exports. Do not move a threshold after seeing results.

| Observed result | Decision |
|---|---|
| At least two cold lanes independently strong, ≥8 cold active subscribers, ≥3 substantive cold replies, and ≥2 credible cold price-intent replies | **Proceed** to a thin MVP PRD focused only on save/name/restore; conduct 5 interviews with responders before implementation |
| Exactly one cold lane strong, or conversion clears but reply/price intent does not | **Retest** that one source/ICP message for another fixed window; interview active subscribers; do not build the extension yet |
| Cold qualified traffic reaches lane minimums but CTA rate is <5% in two cold lanes | **Rewrite** the hero/problem framing; retest the same audiences with one variable changed |
| CTA interest is healthy but active double opt-in is weak | **Diagnose** form trust, confirmation delivery, and price/stage clarity before judging demand |
| Paid lane fails its minimum/CPA rule but an organic cold lane is strong | **Stop ads**; preserve the organic wedge and test it without treating paid failure as product failure |
| Two or more cold lanes reach minimum and are weak, with zero substantive cold replies | **Reshape or park** the offer/ICP; do not build more features |
| No cold lane reaches minimum despite executing the calendar | **Inconclusive distribution failure**; improve access to the ICP or run customer discovery, not a product build |
| Warm is strong while cold is weak/inconclusive | **No-go from smoke**; treat warm results only as copy/interview leads and never as evidence of cold demand |
| Any single “invoice me”/purchase request | Interview that person and test a paid commitment separately; one request is a lead, not proof of scale |

### What not to build during the test

- No Chrome extension, tab storage/sync engine, authentication, team accounts, billing, admin console, or onboarding flow.
- No multi-page marketing site, blog, referral loop, brand system, demo presented as real, or fake proof.
- No privacy/security claims beyond the disclosed intended direction.
- No feature expansion from comments until the source-specific decision is made.

## 9. Evidence handoff

| Field | Value |
|-------|-------|
| Current decision | TBD after test |
| Evidence classes | assumption |
| Supported claims | TBD after test |
| Still unproven | Demand, cold acquisition, contact intent, willingness to pay, usability, permission acceptability, retention, and product value are all unproven. |
| Contradictions / exclusions | No live results exist. Warm outreach must never be pooled with cold traffic; provider-accepted but inactive records, invalid/duplicate/failed attempts, QA traffic, bots, non-US traffic, and `unattributed` records are excluded from source thresholds. |
| Source anchors | Pre-registration dated 2026-08-01 in this document; after the test, attach dated Plausible source views, Buttondown active-subscriber/tag export, `measurement-template.csv`, reply coding notes, and Reddit Ads spend export. |
| Next validation | Founder runs the August 3–12 test; proceed only if at least two cold lanes independently pass and the cold conversion, reply, and price-intent bars above are all met. |
