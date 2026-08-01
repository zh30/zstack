# Switchboard: 10-day landing smoke test

| Item | Locked choice |
|---|---|
| Test dates | August 3–12, 2026 (10 calendar days) |
| ICP | Hands-on support agents (including implementation/customer-success agents doing support work) at small US SaaS teams who repeatedly reopen client-specific browser context |
| Promise | Restore a client-specific tab workspace in one click |
| Product stage | Unbuilt concept; no firm ship date |
| CTA | **Join the early-access waitlist** (the only CTA label) |
| Price signal | Pricing planned from $9/month; not a price guarantee |
| Stack | Cloudflare Pages + Buttondown double opt-in + Plausible |
| Paid cap | $150 maximum, Reddit Ads only; staged release |
| Current evidence | Assumptions only; the test has not run |

## 1. Smoke protocol

### Hypothesis

If a page offers one-click restoration of client-specific tab workspaces to hands-on support agents at small US SaaS teams, qualified cold visitors will join a double-opt-in early-access waitlist at the source-specific rates below, and at least five confirmed cold subscribers will reply with a concrete recurring workflow or credible paid-intent statement during the 10-day test.

This tests message-to-waitlist demand. It does **not** test whether the extension works, retention, security, Chrome Web Store approval, actual willingness to pay, or whether $9/month is the right price.

### Evidence boundary and primary metric

- Primary metric per source: `confirmed Buttondown subscribers attributed to that source ÷ unique Plausible visitors attributed to the same source`.
- A conversion exists only after Buttondown accepts the address and the subscriber completes double opt-in. Buttondown’s confirmed-subscriber export is the numerator source of truth.
- A browser-side form submit is only `Waitlist Attempt`; it is not a conversion and never enters CVR.
- CTA clicks, opens, and attempts are diagnostics. Replies describing a repeated client-switching workflow or saying they would pay are stronger contact-intent signals.
- Warm outreach is its own cohort, form, export slice, tracker row, threshold, and decision. Never combine its visits, signups, replies, or rate with cold traffic.
- `direct_unknown` can be observed but cannot satisfy a source decision threshold.

### Pre-registered source thresholds

Rates below are directional experiment bars, not benchmarks. Apply a verdict only when that row reaches its minimum sample. A source that misses sample is **inconclusive**, not failed.

| Source cohort | Minimum sample | Continue signal | Reshape/stop signal | Cost rule |
|---|---:|---|---|---|
| `reddit_organic` | 50 qualified unique visitors | ≥4 confirmed (≥8%) and ≥1 qualified reply | ≤1 confirmed (≤2%) | $0 |
| `x_cold` | 50 qualified unique visitors | ≥3 confirmed (≥6%) and ≥1 qualified reply | ≤1 confirmed (≤2%) | $0 |
| `reddit_paid` | 100 qualified unique visitors | ≥3 confirmed (≥3%) and cost/confirmed signup ≤$50 | ≤1 confirmed (≤1%), or $150 spent with <3 confirmed | Hard cap $150 |
| `warm_outreach` | 20 delivered personalized messages and ≥10 unique visits | ≥3 confirmed and ≥2 qualified replies | <2 confirmed or zero qualified replies | $0; report separately |

Qualified visitor means a US visit matching the channel’s support/SaaS targeting, with bots and the maker’s test traffic excluded. Use Plausible unique visitors, consistently. Do not add rates from separate sources together to manufacture a pass.

### Contact-intent and engagement thresholds

- Cold contact-intent pass: at least **5 distinct confirmed cold subscribers** reply to the welcome email with a concrete, repeated client-workspace workflow; at least **2 of the 5** explicitly say they would pay, request paid access, or ask to be invoiced. Statements are leads, not proof of payment.
- Cold contact-intent weak: after at least 10 confirmed cold subscribers have received the welcome email and 72 hours have elapsed, zero qualified replies.
- Welcome opens are recorded by source as a deliverability diagnostic only. They never independently cause a build decision.
- No payment is collected in this test. Revenue and paid conversion remain unproven.

### Budget release and stop controls

1. Prepare one Reddit Ads audience: United States, desktop/Chrome where available, communities/interests related to customer support, customer success, and SaaS. Use one ad promise and the shipped headline so message and page match.
2. Day 3: release at most $30. Confirm UTMs, US/ICP quality, Buttondown cohort attribution, and no tracking break.
3. Days 4–5: release up to another $60 only if tracking is intact and traffic is plausibly ICP. Pause after 48 hours if landing CVR is ≤1% with ≥50 paid visitors or if clicks are clearly irrelevant.
4. Days 6–8: release the final $60 only if the paid cohort is above the stop bar or still statistically unresolved with relevant traffic. Total lifetime campaign limit: **$150**.
5. Platform taxes/fees must fit inside the $150 authorization. If the platform cannot enforce that cap, do not launch paid traffic.

### Contamination controls

- Do not send warm contacts cold-source links. Warm links use `utm_source=direct&utm_medium=warm_dm` and the dedicated warm Buttondown form.
- Do not retarget warm contacts with the paid campaign; upload an exclusion audience if available, otherwise avoid contact-list targeting.
- Do not change the headline, audience, ad creative, CTA, or price during days 1–5. If a material variant is introduced later, add `utm_content` and report it as a separate slice.
- Exclude maker QA visits using Plausible’s documented exclusion method before launch. Record any known internal/test subscribers and remove them from results.

## 2. Complete page, meta, and OG copy

The deployable rendering is in `artifacts/index.html`; this section is the copy source of truth.

### Meta

- Title: **Switchboard — Restore every client tab in one click**
- Description: **A planned Chrome extension for hands-on support agents at small SaaS teams. Reopen each client’s working context in one click. Early access planned from $9/month.**
- Canonical: `https://REPLACE_WITH_CLOUDFLARE_DOMAIN/`
- OG title: **One click back to every tab for the client in front of you**
- OG description: **Switchboard is a planned Chrome extension that restores client-specific tab workspaces for hands-on SaaS support agents. Join the early-access waitlist; pricing is planned from $9/month.**
- OG image: `og-card.svg`, 1200×630
- Twitter card: `summary_large_image`

### Headline variants

1. **Ship first:** One click back to every tab for the client in front of you.
2. Stop rebuilding your browser workspace for every client.
3. Client-specific tab workspaces for hands-on SaaS support.

Variants 2 and 3 are held for a later controlled retest. Do not rotate them during the first five days.

### Nav

- Product: **Switchboard**
- CTA: **Join the early-access waitlist**

### Hero

- Eyebrow: **For hands-on support agents at small SaaS teams**
- H1: **One click back to every tab for the client in front of you.**
- Body: **Stop hunting through tab piles, bookmarks, and history. Switchboard is a planned Chrome extension that restores a client-specific workspace so you can pick up the case with the right tools and context.**
- CTA: **Join the early-access waitlist**
- Disclosure: **In validation, not yet built · Pricing planned from $9/month · No firm ship date yet**

### Problem

- Heading: **Client context should not disappear into your browser.**
- Intro: **When every account needs a different admin page, dashboard, ticket, docs set, and call note, switching clients becomes a scavenger hunt.**
- **Rebuild the same setup:** Open familiar pages one by one whenever a case comes back.
- **Work from the wrong tab:** Risk mixing up client context while a customer is waiting.
- **Carry the map in your head:** Rely on memory and browser history instead of a repeatable workspace.

### Solution

- Heading: **Save once. Restore when the client returns.**
1. **Name the client workspace:** Group the tabs you need for one client engagement.
2. **Save the working context:** Keep that client’s repeatable browser setup together.
3. **Restore it in one click:** Return to the workspace when the next ticket, call, or escalation arrives.

### For / not for

- **Built for:** Hands-on support, implementation, and customer success agents at small US SaaS teams who repeatedly switch between client-specific browser workflows.
- **Not built for:** General bookmark collecting, enterprise browser administration, or teams looking for a finished product today.

### Honest proof block

- Heading: **We’re testing the need before building the extension.**
- Body: **This page is the concept—not a live product or customer claim. Early-access members will help us learn which client context belongs in a workspace and what privacy controls are essential.**

No testimonials, customer logos, user counts, ratings, fabricated screenshots, or ship-date claims may be added during this smoke test.

### FAQ

1. **Is Switchboard available now?** No. It is an unbuilt concept in demand validation. Joining expresses interest in early access; it does not guarantee access or a delivery date.
2. **What will it cost?** Pricing is planned to start at $9/month. Final plans and features may change as we validate the product.
3. **When will it ship?** There is no firm ship date. We will share occasional progress updates and be candid if plans change.
4. **What about client privacy?** Privacy and permissions are part of the product design, not a finished claim. The intended model is to save only the workspace information needed to restore tabs; early users will help define the controls before development.
5. **What happens after I join?** Buttondown will ask you to confirm your email. After confirmation, you will receive a short welcome note asking about your current workflow. You can unsubscribe anytime.
6. **How will you use my email?** Only for early-access research and product updates. It will be stored by Buttondown and will not be sold.

### Final offer and footer

- Price chip: **Planned from $9/month**
- Heading: **Spend less of the support day rebuilding browser context.**
- Body: **Join the early-access list and tell us what you reopen for every client.**
- CTA: **Join the early-access waitlist**
- Consent: **Double opt-in. By joining, you agree to receive early-access research and product updates. Unsubscribe anytime. Your email is stored by Buttondown and never sold.**
- Footer: **© 2026 Switchboard · Concept validation page** and a Contact email link.

## 3. Implementation, form, and analytics

### Deployment path

1. Create a Cloudflare Pages project using this folder as the static asset root, or copy `index.html` and `og-card.svg` into the configured output directory. No build command is required.
2. Set a custom domain if available; otherwise use the assigned `pages.dev` domain. Replace every `REPLACE_WITH_CLOUDFLARE_DOMAIN` value in `index.html` with the exact public hostname, without a trailing path.
3. In Plausible, add that hostname and replace `REPLACE_WITH_PLAUSIBLE_DOMAIN`. Confirm pageviews and custom events in a QA session.
4. Create distinct Buttondown source-capture configurations for `reddit_organic`, `x_cold`, `reddit_paid`, `warm_outreach`, and `direct_unknown`. Each must make its cohort visible on the **confirmed subscriber record/export**. Replace all five form endpoint placeholders.
5. Create a Buttondown double-opt-in welcome email and reply-to inbox. Do not begin traffic until one real valid QA submission per cohort proves that attribution survives confirmation.

If the Buttondown account cannot create distinct forms, lists, tags, or other confirmed-record metadata for these cohorts, stop setup and choose a provider-supported capture design. Page UTMs plus one undifferentiated subscriber count cannot support the required source-specific decisions.

### Form contract

| Item | Specification |
|---|---|
| Visible field | Work email, required, browser email validation |
| Optional qualifier | Omitted to minimize friction; collect workflow detail by reply instead |
| Consent | Explicit adjacent copy; double opt-in; no pre-checked boxes |
| Storage | Buttondown; list not sold; unsubscribe available |
| Submit UX | Opens the Buttondown provider response in a new tab and shows only: “Submission sent to Buttondown. Please use the provider page and confirmation email to finish joining.” |
| Confirmation UX | Buttondown-owned confirmation email/page; local page never says “You’re on the list” |
| Conversion truth | Confirmed, non-test, non-duplicate Buttondown subscriber only |
| Attribution | Cohort-specific Buttondown endpoint/configuration verified in confirmed export |

### Event dictionary

| Event | Owner | Fires when | Use | Never infer |
|---|---|---|---|---|
| Pageview | Plausible automatic | Public page loads | Unique visitors/denominator by UTM source | ICP fit or signup |
| `CTA Click` | Plausible custom event | Nav or hero anchor is clicked; `position` property is `nav` or `hero` | CTA interest and placement diagnostic | Conversion |
| `Waitlist Attempt` | Plausible custom event | Browser sends the form to Buttondown; `cohort` property included | Detect form friction/technical drop-off | Accepted or confirmed signup |
| Confirmed subscriber | Buttondown export, not a client event | Provider accepts address and double opt-in completes | Source-attributed conversion numerator | Payment or product usage |
| Welcome open | Buttondown | Provider reports open | Deliverability diagnostic | Demand verdict |
| Qualified reply | Manual tracker | Confirmed subscriber replies with recurring workflow / paid statement | Contact-intent evidence | Broad market demand |

Plausible custom events must be enabled for `CTA Click` and `Waitlist Attempt`. The HTML uses the tagged-events script and sends the attempt through `window.plausible`. Do not create or report a `submit_waitlist` event from the local form.

### QA gate before any traffic

- Replace all domain, form, Plausible, and contact placeholders; search the deployed source for `REPLACE_` and require zero matches.
- Test mobile and desktop layout, keyboard focus, required/invalid email behavior, every anchor, contact link, canonical, and OG URL.
- For every cohort link: open a clean/private browser, verify Plausible receives the expected UTMs, submit a unique valid email, complete double opt-in, and verify the confirmed subscriber export contains that exact cohort.
- Test one invalid email and verify it does not become a conversion.
- Verify local UI only acknowledges an attempt and never claims successful signup.
- Exclude all QA emails/visits from the experiment tracker and preserve the dated QA evidence.
- Send the welcome email to test accounts; verify reply-to routing and unsubscribe.

## 4. UTM registry

Use the exact public URL in place of the placeholder. Lowercase, underscore-separated values only. Never reuse a cold link in warm outreach.

| Cohort | Canonical URL | Buttondown capture | Notes |
|---|---|---|---|
| Reddit organic | `https://REPLACE_WITH_CLOUDFLARE_DOMAIN/?utm_source=reddit&utm_medium=community&utm_campaign=switchboard_smoke_202608&utm_content=support_post` | `reddit_organic` | Founder-disclosed value-first post |
| X cold social | `https://REPLACE_WITH_CLOUDFLARE_DOMAIN/?utm_source=x&utm_medium=social&utm_campaign=switchboard_smoke_202608&utm_content=problem_story` | `x_cold` | Do not DM known contacts with this link |
| Reddit paid | `https://REPLACE_WITH_CLOUDFLARE_DOMAIN/?utm_source=reddit&utm_medium=paid&utm_campaign=switchboard_smoke_202608&utm_content=restore_tabs_ad` | `reddit_paid` | US targeted; $150 hard cap |
| Warm outreach | `https://REPLACE_WITH_CLOUDFLARE_DOMAIN/?utm_source=direct&utm_medium=warm_dm&utm_campaign=switchboard_smoke_202608&utm_content=personal_note` | `warm_outreach` | Personal messages only; isolated reporting |
| Unknown/direct | Bare canonical or unrecognized UTMs | `direct_unknown` | Observe; never apply a source pass threshold |

If a second creative or headline is authorized after the first measurement window, give it a new `utm_content` and report each content slice before any combination.

## 5. Welcome email and contact-intent capture

**Subject:** What do you reopen for every client?

**Body:**

> Thanks for confirming your interest in Switchboard. It is still an unbuilt concept, with pricing planned from $9/month and no firm ship date.
>
> Could you reply with three quick details?
>
> 1. The last time you switched back to a client, which tabs or tools did you reopen?
> 2. How often does that happen in a typical week?
> 3. If one-click restore solved it reliably, would $9/month come from your own budget, your team’s budget, or neither?
>
> A sentence or two is plenty. Your answer will shape whether this gets built at all.

Tag replies manually as: `specific_recent_workflow=yes/no`, `frequency_per_week`, `budget=own/team/neither/unclear`, `paid_intent=yes/no`, and source cohort. Do not quote replies publicly without permission.

## 6. Ten-day traffic calendar

| Day | Date | Cohort | Action | Spend ceiling | Checkpoint |
|---:|---|---|---|---:|---|
| 1 | Mon Aug 3 | QA only | Deploy Cloudflare Pages; configure Plausible and five Buttondown captures; complete attribution QA for every cohort | $0 | Zero placeholders; valid/invalid tests pass |
| 2 | Tue Aug 4 | `reddit_organic` + `x_cold` | Publish one founder-disclosed Reddit post and X problem story; stay available for replies | $0 | Verify source views and confirmed records remain attributable |
| 3 | Wed Aug 5 | `reddit_paid` | Launch one US Reddit ad matching the hero; cap first tranche at $30 | $30 | Check relevance, CPC, page/attempt pipeline—not final CVR yet |
| 4 | Thu Aug 6 | `warm_outreach` | Send 10 genuinely personal notes to known ICP contacts using warm-only link | $0 | Record delivered, visits, confirmations, replies separately |
| 5 | Fri Aug 7 | Cold cohorts | Answer community comments; publish X follow-up with concrete tab-switching scenario; release up to $60 more only if paid QA/relevance passed | $60 | First source-by-source read; do not pool warm |
| 6 | Sat Aug 8 | Analysis | No new channel. Export Buttondown confirmed subscribers; reconcile with Plausible; mark invalid/test records | $0 | Pause any cohort at its stop bar; under-sample stays inconclusive |
| 7 | Sun Aug 9 | `reddit_organic` | Post a useful workflow checklist/comment follow-up where rules allow; disclose maker and concept stage; no duplicate spam | $0 | Track as same cohort with distinct `utm_content=workflow_followup` if linked |
| 8 | Mon Aug 10 | `reddit_paid` + warm | Release final paid tranche only if gating rules permit; send remaining 10 warm personal notes | $60 | Lifetime paid spend ≤$150; warm stays isolated |
| 9 | Tue Aug 11 | Confirmed subscribers | Send/rely on automated welcome prompt; reply personally to respondents; no new traffic unless a cohort still lacks minimum sample | $0 | Classify concrete workflow and paid-intent replies |
| 10 | Wed Aug 12 | Decision | Freeze changes and spend at 23:59 ET; export Plausible/Buttondown/reply tracker; apply rules | $0 | Choose proceed, retest, reshape, or park per matrix |

Spend shown is maximum incremental authorization; unspent money is not automatically carried forward. Total must remain ≤$150.

## 7. Source-ready traffic copy

### Reddit organic: value-first post

**Suggested title:** How do small SaaS support teams rebuild client context between cases?

**Draft:**

> I keep seeing hands-on support work spread across an admin page, the ticket, docs, call notes, and a client dashboard. When that client comes back, the agent has to rebuild the same browser context.
>
> I’m validating—not yet building—a small Chrome extension that would save those tabs as a client workspace and restore them in one click. I’m trying to learn whether this is a repeated problem or just an occasional annoyance.
>
> For people doing support or implementation at a small SaaS team: what did you reopen the last time you returned to a client, and how often does this happen?
>
> I made a short concept page if seeing the exact promise helps: [REDDIT ORGANIC UTM URL]. It clearly says the product is unbuilt and pricing is planned from $9/month. I’m the maker; feedback is more useful than encouragement.

Do: read subreddit rules first, use an allowed feedback flair, answer every substantive comment, and remove the link if self-promotion is disallowed. Don’t: copy the same post across multiple communities or imply the extension exists.

### X cold social

**Post 1, day 2:**

> A support case comes back. You reopen the ticket, admin page, client dashboard, docs, and notes—again.
>
> I’m testing an unbuilt Chrome extension that would restore that client workspace in one click. Planned from $9/month; no ship date yet.
>
> [X COLD UTM URL]

**Post 2, day 5:**

> The product question I’m testing: is rebuilding client browser context frequent enough that a support agent would pay $9/month to stop doing it?
>
> The concept is one click to restore each client’s tabs. It isn’t built. Honest reactions welcome.
>
> [X COLD UTM URL with `utm_content=price_question`]

Do: engage relevant public conversations with useful replies and label yourself as the maker. Don’t: tag strangers in batches or send the cold link to known contacts.

### Reddit paid

- Primary text: **Switching back to a client shouldn’t mean rebuilding five tabs. Switchboard is a planned Chrome extension for hands-on SaaS support agents: save a client workspace and restore it in one click.**
- Headline: **Restore every client tab in one click**
- Disclosure line: **Unbuilt concept · Planned from $9/month · No firm ship date**
- CTA supplied by ad platform: choose the closest non-deceptive label to the page CTA, but the landing page retains the sole CTA **Join the early-access waitlist**.

Do: target the US and relevant support/SaaS contexts, preserve the registered paid URL, and enforce the account-level cap. Don’t: use “available now,” fabricate an extension UI, or broaden targeting mid-test.

### Warm one-to-one outreach (never pooled with cold)

> Hi [Name] — because you’ve done hands-on support at [Company], I’d value a blunt two-minute reaction to a concept I’m testing. It’s an unbuilt Chrome extension that would restore client-specific tab workspaces in one click. Pricing is planned from $9/month, with no ship date yet. Would you look at this and tell me about the last time you had to reopen context for a client? [WARM-ONLY UTM URL]

Only send this to people the maker genuinely knows or can personally contextualize. Track each message as delivered/not delivered; no automation or bulk sequence.

## 8. Dashboard and reconciliation

Use `artifacts/source-tracker.csv`. Maintain one row per date × cohort × content variant. The denominator comes from Plausible; the numerator comes from Buttondown. Keep raw dated exports unchanged.

Calculated fields:

- CTA rate = `cta_clicks / unique_visitors`
- Attempt rate = `waitlist_attempts / unique_visitors`
- Confirmed CVR = `confirmed_subscribers / unique_visitors`
- Confirmation completion = `confirmed_subscribers / waitlist_attempts` (diagnostic; imperfect if repeat attempts)
- Qualified reply rate = `qualified_replies / confirmed_subscribers`
- Cost per confirmed = `spend_usd / confirmed_subscribers`

Reconciliation order on days 6 and 10:

1. Export Plausible by date, UTM source/medium/campaign/content, and event.
2. Export Buttondown confirmed subscribers with cohort and confirmation timestamp.
3. Remove recorded QA/test and duplicate records; log exclusions rather than silently deleting history.
4. Join only on the pre-registered cohort, not by guessing from timestamps.
5. Add qualified reply classifications and paid-intent statements from the inbox tracker.
6. Apply thresholds to each cohort separately. Present warm results in a standalone section after cold results.

## 9. Decision rules

| Outcome at day 10 | Required evidence | Decision |
|---|---|---|
| Proceed to a thin MVP PRD | At least **two cold cohorts** hit their own continue thresholds **and** cold contact-intent passes (≥5 qualified cold replies, ≥2 credible paid-intent statements) | Define the smallest privacy-safe save/restore workflow; conduct interviews before implementation |
| Paid-intent priority | Proceed condition plus any unsolicited request to pay/preorder/invoice | Interview that person within 48 hours and design a separate payment-intent test; one request is not scale proof |
| Retest message | Cold sources reach minimum samples; at least one has CVR between its stop and continue bars, or CVR passes but cold contact-intent is weak | Interview confirmed subscribers; change only hero/problem framing; run a new, separately tagged test |
| Reshape ICP/offer | At least two cold cohorts reach minimum samples and hit their stop bars | Narrow the job/ICP using replies and comments; do not build the extension |
| Distribution failure | Cold sources do not reach minimum samples despite executing the calendar, or traffic is demonstrably off-ICP | Change channel/access strategy; do not conclude the problem is dead |
| Park | After one honest controlled retest, at least two cold cohorts again hit stop bars and qualified replies remain absent | Archive evidence and stop spending/building |
| Warm/cold divergence | Warm passes but fewer than two cold cohorts pass | Treat as relationship-assisted interest; interview warm contacts but do not use it to authorize the MVP |

Do not average a passing warm rate into cold results. Do not call under-sampled rates success or failure. If attribution fails, the affected source has no defensible CVR and the decision is paused until capture is fixed.

## 10. Explicit non-build scope

During these 10 days, do not build:

- the Chrome extension, tab capture/restore, sync, authentication, team sharing, billing, admin, or onboarding;
- polished product screenshots, fake demos, customer logo strips, testimonials, counters, ratings, or a promised release roadmap;
- a custom API, database, analytics warehouse, referral loop, multi-page marketing site, SEO content program, or brand system;
- a pre-order/payment flow—the current CTA tests confirmed early-access interest only.

If the test passes, the next artifact is a thin PRD and privacy-risk discovery—not production code.

## 11. Evidence handoff

| Field | Value |
|-------|-------|
| Current decision | TBD after test |
| Evidence classes | assumption |
| Supported claims | TBD after test |
| Still unproven | Actual demand, source-specific conversion, qualified contact intent, willingness to pay, price acceptance, product utility, privacy/security feasibility, retention, and distribution repeatability are TBD after test. |
| Contradictions / exclusions | No observed results supplied. Warm outreach is excluded from all cold metrics and decisions; QA/test traffic, invalid or duplicate emails, attempts without confirmation, unknown/direct attribution, opens alone, and unverified source assignments are excluded from conversion claims. |
| Source anchors | Pre-registered protocol dated 2026-08-01 in `artifacts/smoke-test-plan.md`; result anchors TBD after test: dated Plausible UTM/event export, Buttondown confirmed-subscriber export with cohort, reply tracker, spend export, and exclusions log. |
| Next validation | Owner: founder. Run the August 3–12, 2026 test; pass only if at least two cold cohorts hit their source continue thresholds and cold contact-intent reaches ≥5 qualified replies including ≥2 credible paid-intent statements; otherwise apply the pre-registered retest/reshape/park rules. |
