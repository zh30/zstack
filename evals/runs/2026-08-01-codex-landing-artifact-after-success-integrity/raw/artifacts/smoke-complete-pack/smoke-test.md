# Landing smoke test: Client Tab Restore

| Field | Value |
|---|---|
| Date | 2026-08-01 |
| Timebox | 10 calendar days: 2026-08-01 through 2026-08-10, US traffic |
| ICP | Hands-on customer support/success agents at US SaaS companies with roughly 5–50 support-facing employees who repeatedly reopen client-specific browser tabs |
| Promise | Restore a saved client-specific tab workspace in one click |
| CTA | **Join the early-access waitlist** |
| Price signal | Planned pricing from $9/month; no charge in this test and final pricing may change |
| Stage | Unbuilt concept; no testimonials, customer logos, user count, or ship date |
| Stack | Cloudflare Pages + Pages Function, Buttondown, Plausible |
| Paid cap | $150 maximum, inclusive of all ad spend |

## 1. Smoke protocol

### Hypothesis

If a one-click restore promise is shown to hands-on support agents at small US SaaS teams, enough qualified people will submit a confirmed early-access waitlist signup and describe a recurring client-tab workflow to justify a thin MVP discovery phase.

This is three separate hypotheses, not one blended conversion rate:

1. **Cold paid:** targeted US support/SaaS visitors will convert at 5% or better, with at least four provider-confirmed signups after 60 qualified unique visitors.
2. **Cold community/social:** relevant community and social visitors will convert at 8% or better, with at least five provider-confirmed signups after 50 qualified unique visitors.
3. **Warm outreach:** personally contacted ICP prospects will convert at 20% or better, with at least four provider-confirmed signups after 15 qualified unique visitors, plus at least two qualified replies. This lane is reported on its own and never pooled with either cold lane.

### Metrics and definitions

| Metric | Operational definition | Source of truth |
|---|---|---|
| Qualified unique visitor | Plausible unique visitor from the US in an allowed source lane, excluding owner/test traffic and obvious bots | Plausible segment by `utm_*`; source lane mapping below |
| CTA click | `CTA Click` event on the nav or hero CTA | Plausible |
| Waitlist attempt | Valid client-side form submission that emitted `Waitlist Attempt`; never counted as a signup | Plausible |
| Provider-confirmed signup | Buttondown accepted the subscriber through the server-side Pages Function; duplicates, invalid emails, honeypot hits, provider errors, and attempts are excluded | Buttondown subscriber export, joined to stored `source_lane` and UTMs |
| Visitor → confirmed signup CVR | Provider-confirmed signups divided by qualified unique visitors **within the same source lane** | Buttondown + Plausible |
| Welcome open | Buttondown-reported open; diagnostic only because privacy protections make it noisy | Buttondown |
| Qualified reply | A reply that names a repeated client-tab workflow, current workaround, meaningful frequency/cost, credible willingness to test, or credible pay intent | Manual coded reply log, kept by source lane |
| Credible pay intent | Unprompted “I would pay,” “invoice me,” or equivalent with role/company context; no payment is collected in this test | Manual coded reply log |
| Paid CPC / cost per signup | Spend ÷ ad clicks; spend ÷ provider-confirmed `cold_paid` signups | Reddit Ads + Buttondown |

### Source lanes and attribution contract

| Lane | Included traffic | Excluded traffic |
|---|---|---|
| `cold_paid` | `utm_medium=cpc`; only the Reddit Ads campaign in this test | Retargeting, founder network, organic posts |
| `cold_community_social` | Reddit organic, X organic, Indie Hackers; `community` or `social` medium | Anyone personally contacted by the founder |
| `warm_outreach` | One-to-one founder messages using `utm_source=founder_dm&utm_medium=outreach` | Group blasts, public posts, paid clicks |

The Cloudflare Function derives `source_lane` server-side and sends it with UTMs to Buttondown metadata. A source-specific CVR may be reported only after a real test confirms those values survive on the provider-accepted subscriber record. If metadata does not survive, pause traffic and fix capture; do not infer source from time or allocate an aggregate subscriber count. Warm results always remain a separate row and narrative.

### Pre-registered source-specific thresholds

Rates below are directional experiment bars, not market benchmarks. Both the minimum sample and the conversion-count condition apply.

| Lane | Target / minimum readable sample | Continue signal | Retest band | Reshape/stop signal |
|---|---|---|---|---|
| `cold_paid` | Target 75; read at ≥60 qualified visitors | ≥5% CVR **and** ≥4 confirmed signups; cost/signup ≤$30 | 3–4.9% or 2–3 signups; keep total spend within cap and test one hero variant only | <3% and ≤1 signup after ≥60 visits; or $60 spend with zero confirmed signups → pause the ad immediately |
| `cold_community_social` | Target 70; read at ≥50 qualified visitors | ≥8% CVR **and** ≥5 confirmed signups | 4–7.9% or 2–4 signups | <4% and ≤1 signup after ≥50 visits across at least two permitted communities/surfaces |
| `warm_outreach` | Up to 30 personal messages; target ≥15 qualified visitors | ≥20% CVR, ≥4 confirmed signups, and ≥2 qualified replies | ≥20% CVR but <2 qualified replies, or 2–3 signups | <15% and ≤2 signups after ≥15 visitors, with <2 qualified replies |

If a lane misses its minimum visitors, label it **distribution inconclusive**, not product rejection. Do not combine lanes to manufacture the minimum sample. Rates under 50 visits are unstable; the warm lane intentionally uses a smaller, named-prospect sample and therefore informs interviews rather than cold-market scale.

### Test controls

- Ship headline A for days 1–7. Do not change the page, ad promise, and audience at the same time.
- Only if cold traffic lands in the retest band after its minimum sample, switch to headline B on day 8 and label all later links `utm_content=headline_b`.
- Use US geography. Manually inspect referrers and exclude obvious bots, the founder, and setup tests.
- Freeze the $9/month price signal during the test.
- Buttondown double opt-in improves list quality. A signup is counted when Buttondown accepts the record; email confirmation, opens, and replies are reported separately.
- End collection for the decision snapshot at 23:59 ET on 2026-08-10. Late confirmations/replies can be noted but cannot silently change the preregistered result.

## 2. Landing-page copy (English)

### Meta and social share copy

- **Meta title:** Restore Every Client Workspace in One Click | Client Tab Restore
- **Meta description:** A planned Chrome extension for hands-on support agents at small US SaaS teams. Save client-specific tab workspaces and restore the right context in one click. Planned pricing from $9/month.
- **OG title:** One click back to the right client context
- **OG description:** Stop rebuilding client tab sets between support cases. Join the early-access waitlist for a planned Chrome extension, with pricing from $9/month.
- **OG image text (1200×630):** `One click back to the right client context` / `A planned Chrome extension for hands-on SaaS support agents` / `Planned pricing from $9/month`
- **OG image alt:** Client Tab Restore — one click back to the right client context
- **Twitter/X title:** One click back to the right client context
- **Twitter/X description:** A planned Chrome extension that restores client-specific tab workspaces for hands-on SaaS support agents.

### Headline variants

1. **Ship first:** One click back to the right client context.
2. Stop rebuilding the same client tabs for every support case.
3. The client workspace restorer for hands-on SaaS support teams.

Only the H1 changes in a later controlled retest. The subhead, CTA, price, audience, and channel stay fixed.

### Full page copy

#### Nav

- Brand: `Client Tab Restore (working name)`
- CTA: `Join the early-access waitlist`

#### Hero

- Eyebrow: `For hands-on support agents at small US SaaS teams`
- H1: `One click back to the right client context.`
- Subhead: `Stop hunting through history and rebuilding the same mix of admin, CRM, ticket, and customer tabs every time you switch accounts. Client Tab Restore is a planned Chrome extension that saves a workspace per client and restores it in one click.`
- Price chip: `Planned pricing from $9/month`
- CTA: `Join the early-access waitlist`
- Stage line: `Not built yet. We’re validating demand before development. No firm ship date.`
- Concept label: `Concept only`

#### Problem

- Heading: `Client switching should not mean context rebuilding.`
- `You reopen the same client-specific tools and records by hand.`
- `You risk acting in the wrong account when tabs look nearly identical.`
- `You lose focus while a customer is waiting for an answer.`

#### Planned solution

- Heading: `Save once. Restore when the next ticket lands.`
- Step 1: `Group a client’s context` — `Choose the tabs you use for that account.`
- Step 2: `Name the workspace` — `Keep each client’s working set easy to recognize.`
- Step 3: `Restore it in one click` — `Reopen the saved set when you return to that client.`

#### For / not for

- For heading: `Built for the people doing the work.`
- For: `Hands-on support and success agents`; `Small US SaaS teams serving many named clients`; `Browser-heavy workflows repeated across accounts`.
- Not-for heading: `Not another team browser.`
- Not for: `General bookmark collecting`; `Large-enterprise browser administration`; `Teams looking for a ticketing system or CRM replacement`.

#### Honest proof / founder note

- Heading: `We’re testing the promise before building the extension.`
- Note: `There are no customer claims to show yet. Joining tells us the workflow matters enough to explore—and gives you a chance to shape the smallest useful version.`
- Detail: `Waitlist members will receive a confirmation email and occasional product-research updates. Planned pricing starts at $9/month; final plans may change as the scope is validated.`

#### FAQ

1. **Is the Chrome extension available now?** No. This is a demand test for an unbuilt product. We will only start with a thin version if enough qualified support agents show real interest.
2. **When will it ship?** There is no firm ship date. If we proceed, early-access members will hear about research and testing first.
3. **What will it cost?** Planned pricing starts at $9 per month. That is a pricing intention, not a charge or a locked offer; final pricing may change as we validate the scope.
4. **What exactly does “one-click restore” mean?** The planned core job is to reopen a saved set of tabs for one client with one action. Sync, collaboration, and deeper integrations are not promised in this test.
5. **What about client privacy?** The product’s data model has not been finalized. Privacy and least-data storage will be requirements before any extension is tested. For this waitlist, Buttondown stores your email and the optional use case you submit; we will not sell the list.
6. **What happens after I join?** Buttondown will ask you to confirm your email. We may send a short research question or product update. You can unsubscribe at any time.

#### Final CTA and form

- Heading: `Spend less time rebuilding tabs. Help shape the first useful version.`
- Support: `Join if client-by-client browser context is a recurring part of your support work.`
- Required field: `Work email`
- Optional qualifier: `What do you reopen for each client?` Placeholder: `For example: admin, CRM, ticket, logs, and status page`
- Consent: `By joining, you agree to receive a confirmation email and occasional research or product updates from Client Tab Restore. Unsubscribe anytime. We do not sell your email.`
- CTA: `Join the early-access waitlist`
- Provider-confirmed state: `You’re on the list—check your inbox to confirm your email.`
- Error state: `We couldn’t confirm your signup. Please try again in a moment.`
- Footer: `Client Tab Restore is a working name and an unbuilt product concept.` / `Privacy/contact: hello@YOUR_DOMAIN.example`

The optional qualifier may lower raw CVR but improves lead quality. It remains optional so it does not block the primary signal.

## 3. Implementation and event contract

### Deployment path

1. Publish `artifacts/site` as a Cloudflare Pages project. `index.html` is the static page; `functions/api/waitlist.js` is the same-origin form endpoint.
2. Store `BUTTONDOWN_API_KEY` as an encrypted Pages environment variable. Never expose it to the browser.
3. Enable Buttondown double opt-in. The Function returns confirmed local success only after Buttondown accepts the subscriber.
4. Store `source_lane`, `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `use_case`, and `captured_at` on the Buttondown subscriber record. Verify the current Buttondown API schema in the account before launch.
5. Add the production domain to Plausible and configure the four named custom-event goals.
6. Replace domain/email placeholders and supply a 1200×630 `og.png` before sharing links.

### Form integrity

| Item | Specification |
|---|---|
| Required | Work email |
| Optional | Short use-case answer |
| Hidden | Four UTMs; server derives `source_lane` |
| Anti-bot | Honeypot; exclude bot/test traffic during reconciliation |
| Consent | Explicit text, no prechecked box, Buttondown double opt-in, unsubscribe in every email |
| Storage | Buttondown stores email and metadata; Cloudflare relays the request; Plausible receives events without the email |
| Privacy | Never send email or free text to Plausible; do not sell the list |
| Confirmed conversion | Buttondown HTTP acceptance through the server-side Function |
| Local UX boundary | The success message and `Waitlist Confirmed` fire only after that accepted response; submit handler alone emits only `Waitlist Attempt` |

### Plausible events

| Event | Trigger | Properties | Counts as conversion? |
|---|---|---|---|
| Standard pageview | Plausible page load | Page + UTM/referrer | Denominator only |
| `CTA Click` | Nav or hero link clicked | `placement=nav|hero` | No |
| `Waitlist Attempt` | Browser validation passes and request begins | None | No |
| `Waitlist Confirmed` | Pages Function reports Buttondown accepted the subscriber | `source_lane` only | Yes, reconciled to Buttondown export |
| `Waitlist Error` | Network or provider failure | Short non-PII reason | No |

Buttondown is the numerator of record. Plausible’s confirmed event is a diagnostic cross-check; discrepancies are investigated, not averaged.

### UTM registry

Base production URL: `https://YOUR_DOMAIN.example/`

| Surface | URL suffix | Lane |
|---|---|---|
| Reddit Ads | `?utm_source=reddit_ads&utm_medium=cpc&utm_campaign=tab_restore_us_smoke_202608&utm_content=client_switch_v1` | `cold_paid` |
| Reddit organic | `?utm_source=reddit&utm_medium=community&utm_campaign=tab_restore_us_smoke_202608&utm_content=support_post_v1` | `cold_community_social` |
| X post 1 | `?utm_source=x&utm_medium=social&utm_campaign=tab_restore_us_smoke_202608&utm_content=problem_story_v1` | `cold_community_social` |
| X post 2 | `?utm_source=x&utm_medium=social&utm_campaign=tab_restore_us_smoke_202608&utm_content=concept_note_v1` | `cold_community_social` |
| Indie Hackers | `?utm_source=indie_hackers&utm_medium=community&utm_campaign=tab_restore_us_smoke_202608&utm_content=smoke_log_v1` | `cold_community_social` |
| Personal founder DM | `?utm_source=founder_dm&utm_medium=outreach&utm_campaign=tab_restore_us_smoke_202608&utm_content=personal_note_v1` | `warm_outreach` |

Never reuse the founder-DM URL in a public post. Never relabel a warm recipient as community traffic. For headline B, change only `utm_content` to a clearly suffixed value such as `client_switch_headline_b`.

### Welcome email

- **Subject:** Confirm your Client Tab Restore early-access spot
- **Confirmation note:** `Thanks for joining the Client Tab Restore research list. Please confirm your email so we know the interest is real.`
- **Post-confirmation email:** `You’re confirmed. Client Tab Restore is still an unbuilt concept: one click to restore the right set of client tabs. Planned pricing starts at $9/month, and there is no firm ship date. If this is a recurring problem, reply with the tabs you reopen and how often you switch clients. Your answer will shape whether—and what—we build. Unsubscribe anytime.`

Reply behavior is a secondary demand signal. It does not change the landing page’s single CTA.

### Preflight checklist

- Replace all `YOUR_DOMAIN.example` placeholders and add `og.png`.
- Confirm page title, description, OG preview, canonical production URL, mobile layout, keyboard focus, and contrast.
- In each lane, submit one real valid address and confirm the Buttondown record retains the exact lane and UTMs.
- Submit an invalid email and a honeypot value; neither may count as a conversion.
- Force a bad API key in preview; local UI must show an error and must not emit `Waitlist Confirmed`.
- Confirm no email or qualifier text reaches Plausible.
- Filter founder/test submissions from both systems before day 1 counts.
- Export Buttondown and Plausible snapshots daily at the same ET cutoff.

## 4. Ten-day traffic calendar

### Budget allocation

- Reddit Ads initial controlled run: **$90** across days 4–6, maximum $30/day.
- Conditional extension: **$30** across days 7–8 only if there is at least one confirmed paid signup or the lane is still below 60 visitors with CPC ≤$2.50.
- Reserve: **$30** on day 9 only for a readable sample or controlled headline-B retest.
- Absolute account/campaign cap: **$150**. Stop at the cap even if the sample is short.
- Organic/community and warm outreach spend: **$0**. Founder time is tracked separately.

### Calendar

| Day | Date | Lane/channel | Action | UTM content | Guardrail / expected quality |
|---|---|---|---|---|---|
| 1 | Sat 2026-08-01 | Setup only | Deploy, configure Buttondown/Plausible, run valid/invalid tests in all three lanes, exclude tests | Test-only links; delete/exclude | No public traffic until attribution survives provider acceptance |
| 2 | Sun 2026-08-02 | Warm outreach | Send 8 personal notes to known or directly connected US SaaS support practitioners; ask for honest relevance, not a favor signup | `personal_note_v1` | High context; record delivered, clicked, signed up, replied separately |
| 3 | Mon 2026-08-03 | Cold social + warm | Publish X problem story; send 7 more personal notes; reply to every substantive response | `problem_story_v1`; warm stays separate | Public X is cold social even if followers recognize founder; direct recipients stay warm |
| 4 | Tue 2026-08-04 | Cold paid | Launch one US Reddit Ads creative at ≤$30/day; target relevant SaaS/customer-support interests or communities currently allowed by the platform | `client_switch_v1` | Verify policy/target availability in account; no invented audience size |
| 5 | Wed 2026-08-05 | Cold community + paid | Post value-first founder-disclosed Reddit discussion in one rules-permitting buyer community; monitor ad; answer comments | `support_post_v1` | Read rules first; no duplicate cross-post; removal means no evidence from that post |
| 6 | Thu 2026-08-06 | Cold community + paid | Publish Indie Hackers smoke-test log; continue ads only within rules; send final 5–10 personal notes to reach max 30 | `smoke_log_v1`; `client_switch_v1`; warm separate | Founder audience may be builder-heavy; manually code non-ICP leads |
| 7 | Fri 2026-08-07 | Cold social + paid review | Publish X concept note; reconcile Buttondown/Plausible by lane at 17:00 ET | `concept_note_v1` | At $60 paid spend and zero confirmed signups, pause paid immediately |
| 8 | Sat 2026-08-08 | Controlled retest only if triggered | If a cold lane met its minimum sample but is in the retest band, switch only H1 to variant B and suffix content `headline_b`; otherwise keep A | `*_headline_b` | Do not change audience, price, CTA, and headline together |
| 9 | Sun 2026-08-09 | Reserve / replies | Spend the $30 reserve only to reach paid minimum sample or continue a justified retest; send Buttondown post-confirmation question to confirmed members | lane-specific | Email replies remain attributed to original lane; hard $150 total cap |
| 10 | Mon 2026-08-10 | Close and decide | Stop acquisition 23:59 ET; export source-segmented analytics/subscribers; code replies; apply preregistered decision rules | None | No pooling, no retroactive threshold changes |

### Channel-ready drafts

#### Reddit organic discussion

**Title:** Support agents: how do you rebuild client context when every account needs a different tab set?

**Body:**

> I’m exploring a very narrow Chrome extension idea for hands-on support agents at small SaaS teams.
>
> The problem: switching from Client A to Client B often means reopening a ticket, CRM record, admin console, status page, and logs—then checking that none of those nearly identical tabs belong to the wrong account.
>
> The proposed core is intentionally small: save a named tab workspace per client, then restore that set in one click. It is not built, there is no ship date, and planned pricing starts at $9/month.
>
> I’m the person testing the idea. Is this a repeated problem in your week, or do pinned tabs/bookmarks already solve it? If the one-click restore is relevant, **Join the early-access waitlist:** [Reddit organic UTM link]

Do: disclose the founder relationship, ask about present workflow, stay to answer, and use a permitted flair. Do not: post if self-promotion is prohibited, paste into multiple subreddits, imply the extension exists, or argue with objections.

#### X post 1 — problem story

> A support ticket is rarely one tab. It’s the ticket + CRM + admin + logs + status page—and the set changes by client.
>
> I’m testing an unbuilt Chrome extension that would save each client workspace and restore it in one click. Planned from $9/month; no ship date.
>
> **Join the early-access waitlist:** [X post 1 UTM link]

#### X post 2 — concept note

> The browser remembers tabs. Support work needs it to remember *which tabs belong to this client*.
>
> Concept: named client workspaces, restored in one click. Built for hands-on support agents at small US SaaS teams. Still unbuilt; validating before development.
>
> **Join the early-access waitlist:** [X post 2 UTM link]

Do: reply to practitioners and ask what they reopen. Do not: tag strangers, claim traction, or turn likes into demand evidence.

#### Indie Hackers post

**Title:** A $150, 10-day smoke test before I build a client-tab Chrome extension

> I’m testing one narrow promise: restore a support agent’s client-specific browser workspace in one click.
>
> The audience is hands-on support agents at small US SaaS teams. The product is not built, there is no ship date, and the planned starting price is $9/month. I’m using a Cloudflare page, Buttondown-confirmed signups, and source-separated Plausible traffic. Warm outreach will never be pooled with cold traffic.
>
> I’d value criticism of the problem framing. If this matches your own support workflow, **Join the early-access waitlist:** [Indie Hackers UTM link]

Do: share the method and later publish the outcome. Do not: count builder curiosity as qualified ICP evidence.

#### Warm personal note

> Hi [Name] — I’m checking a narrow workflow problem with people who do hands-on SaaS support. When you switch clients, do you repeatedly reopen a client-specific mix of ticket, CRM, admin, logs, or status tabs?
>
> I’m testing an unbuilt Chrome extension concept that would restore that workspace in one click. Planned pricing starts at $9/month; there’s no ship date. No need to be polite if bookmarks already solve it. If it is genuinely relevant, **Join the early-access waitlist:** [personal warm UTM link]

Send only to genuine individual contacts or directly connected prospects. Personalize the workflow reference, cap at 30, do not automate, and log this lane separately from all cold data.

#### Reddit ad

- **Primary text:** `Switching clients shouldn’t mean rebuilding five tabs. A planned Chrome extension would save each client workspace and restore it in one click.`
- **Headline:** `One click back to the right client context`
- **Price/stage line:** `Unbuilt concept. Planned from $9/month.`
- **CTA displayed in creative/body:** `Join the early-access waitlist`
- **Destination:** Reddit Ads UTM link
- **Targeting:** United States; one currently available set of SaaS/customer-support interests or relevant communities. Record the exact live targeting and platform-estimated audience in the day-4 log rather than inventing it in advance.

Pause rules: stop immediately at $150; pause at $60 with zero provider-confirmed signups; pause if obvious non-US/bot traffic dominates; do not optimize against `Waitlist Attempt`. CPC above $2.50 after 25 paid clicks means the 60-visitor sample is unlikely within budget—record distribution failure unless a lower-cost valid targeting adjustment can be made without changing ICP.

## 5. Daily measurement and reconciliation

Use `artifacts/measurement.csv`. Create one row per date × source lane × meaningful `utm_content`; never create an “all traffic” CVR used for decisions.

Daily at the same ET cutoff:

1. Export Plausible visitors and events by lane/UTM.
2. Export Buttondown accepted subscribers with metadata.
3. Remove owner tests, invalids, duplicates, honeypot activity, non-US traffic, and non-ICP leads; document exclusions.
4. Calculate CVR only where the Buttondown numerator and Plausible denominator have the same lane.
5. Log ad spend and CPC only in `cold_paid`.
6. Code replies as workflow detail, credible test intent, credible pay intent, objection, or unrelated; retain original lane.
7. Record provider/analytics discrepancies explicitly. Never resolve them by guessing attribution.

## 6. Decision rules

### Overall decision matrix

| Outcome | Exact rule at day 10 | Decision |
|---|---|---|
| Strong | At least one **cold** lane reaches its continue signal **and** there are ≥3 qualified replies across the experiment, reported by lane | Proceed only to customer interviews and a thin MVP PRD centered on local save/name/one-click restore; test $9 willingness directly |
| Stronger paid-intent lead | Strong outcome plus ≥2 credible pay-intent replies from distinct qualified people | Prioritize a paid design-partner test; still do not treat two replies as scalable revenue proof |
| Mixed: conversion without depth | A cold lane meets CVR/count but total qualified replies are <3 | Do not build; interview 5–8 confirmed waitlist members and ask about past switching behavior, workaround, frequency, and budget |
| Mixed: weak cold, strong warm | Warm reaches continue signal but neither cold lane does | Treat as network-specific demand; refine ICP/message and rerun cold acquisition. Never pool warm conversions into a passing cold rate |
| Mixed: traffic, weak offer | Either cold lane reaches its minimum sample but lands in its retest band | Retest one hero variant for 5–7 more days with the same source and price; preregister a new window |
| Distribution inconclusive | Neither cold lane reaches its minimum sample within honest channels and budget | Change distribution method, not product conclusion; do not call it product failure and do not build to compensate |
| Weak | A cold lane hits minimum sample and its reshape/stop signal, the other cold lane also fails or is directionally weak, and warm produces <2 qualified replies | Park or reshape the ICP/problem. Do not add features or broaden to “everyone who uses tabs.” |

No single aggregate conversion rate is permitted. A decision note must show the three lane rows, sample sizes, exclusions, and Buttondown/Plausible reconciliation.

## 7. What not to build during this smoke

- No Chrome extension, tab-capture logic, restore engine, sync, or Chrome Web Store listing.
- No accounts, team workspace, permissions, SSO, billing, or $9 checkout.
- No CRM, ticketing, or browser integrations.
- No cross-device sync, shared workspaces, AI tab grouping, analytics dashboard, or admin controls.
- No polished product demo disguised as working software; the page concept is labeled.
- No testimonials, customer logos, user counter, fabricated reviews, or launch date.
- No multi-page marketing site, blog, referral loop, or SEO program.
- No second landing-page CTA or feature survey that distracts from the waitlist.

## 8. Evidence handoff

| Field | Value |
|---|---|
| Current decision | TBD after test |
| Evidence classes | assumption |
| Supported claims | TBD after test |
| Still unproven | One-click product feasibility and value, Chrome Web Store acceptance, data/privacy model, repeat use, retention, willingness to pay $9/month, acquisition scalability, and any ship date are unproven. |
| Contradictions / exclusions | TBD after test; warm outreach must remain separate from cold paid and cold community/social, and invalid, duplicate, bot, test, rejected, unattributed, and non-US events are excluded. |
| Source anchors | Pre-test assumptions and protocol dated 2026-08-01 in `artifacts/smoke-test.md`; result anchors are TBD after test and must include the dated Plausible slice, Buttondown export, ad-spend export, reply log, and `artifacts/measurement.csv`. |
| Next validation | Founder runs the 2026-08-01–2026-08-10 test; pass/fail is determined only by the preregistered source-lane thresholds and provider-confirmed attribution above. |
