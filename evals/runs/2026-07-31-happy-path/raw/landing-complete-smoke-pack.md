# Landing smoke test: ContextDeck

“ContextDeck” is a working name. Confirm trademark and domain availability before publishing.

| Field | Plan |
|---|---|
| Date prepared | July 31, 2026 |
| Test window | 10 consecutive days after form and analytics QA |
| ICP | Hands-on support agents at small US SaaS teams handling complex, multi-tool tickets |
| Problem | Reconstructing the right customer context across admin dashboards, logs, billing, CRM, and other tabs |
| Promise | Restore the right client workspace in one click |
| Primary CTA | “Join the early-access waitlist.” |
| Price signal | “Planned from $9/month” |
| Stack | Cloudflare Pages, Buttondown, Plausible |
| Paid-media ceiling | $150 total, with staged release gates |
| Stage | Unbuilt product; demand-validation page only |

## 1. Smoke protocol

### Hypothesis

If hands-on SaaS support agents are offered a planned Chrome extension that restores a client-specific tab workspace in one click, at least 4% of qualified non-warm visitors will join the early-access waitlist.

A strong result requires:

- At least 200 qualified, non-warm unique visitors across at least two acquisition sources.
- At least 8 successful waitlist submissions.
- At least 60% of submitted addresses confirmed through double opt-in.
- At least 3 detailed workflow replies.
- At least 2 respondents saying $9/month sounds reasonable for this problem.

The price response is qualitative willingness evidence, not paid intent. Only an unsolicited pilot-payment or invoice request counts as paid intent.

### Measurement definitions

| Metric | Definition |
|---|---|
| Qualified visitor | A non-bot, non-internal unique visitor from a US-targeted support/SaaS channel. Channel targeting is a proxy; employment is not individually verified. |
| CTA click rate | `cta_click / unique visitors` |
| Waitlist CVR | `waitlist_success / unique visitors` |
| Confirmation rate | Confirmed Buttondown subscribers divided by successful submissions |
| Detailed reply | A reply naming concrete tools or tabs, ticket frequency or pain, and willingness to test or pay |
| Cost per waitlist signup | Paid spend divided by paid-source successful submissions |
| Warm traffic | Personal outreach to known or directly referred support professionals |
| Non-warm traffic | Ads, public social posts, Reddit, and community distribution |

Internal tests use `utm_source=internal` and are excluded. Warm outreach is reported separately and never added to cold or mixed-traffic conversion rates.

### Headline testing rule

Ship headline A first.

Only expose paid traffic to headline B if headline A receives at least 100 non-warm visitors and converts below 2%. Keep the audience, ad creative, price, CTA, and page body unchanged. Do not test headline C during this 10-day run.

### Overall result thresholds

| Result | Pre-registered condition |
|---|---|
| Strong | 200+ non-warm visitors, 4%+ CVR, 8+ submissions, 5+ confirmed subscribers, 3+ detailed replies, and 2+ positive $9/month responses |
| Promising | 200+ visitors and 2–3.9% CVR, or 4%+ CVR without substantive replies |
| Weak | 200+ visitors across at least two sources and two controlled headlines, below 2% CVR with no more than 3 signups and fewer than 2 detailed replies |
| Distribution failure | Fewer than 150 non-warm visitors despite completing the calendar and testing up to the $150 limit |
| Inconclusive | Any source or total result that does not reach its minimum sample |

A distribution failure is not evidence that the customer problem is dead.

## 2. Complete one-page copy

### Meta and social sharing

- **Meta title:** ContextDeck | Restore Client Tabs in One Click
- **Meta description:** A planned Chrome extension for support agents who reopen dashboards, logs, and customer records. Join the waitlist. Planned from $9/month.
- **OG title:** Reopen the right customer workspace in one click
- **OG description:** ContextDeck is a planned Chrome extension for SaaS support agents who rebuild client context across too many tabs.
- **OG image text:**  
  ContextDeck  
  Reopen the right customer workspace in one click  
  Early-access concept · Planned from $9/month
- **OG image alt:** Concept card for ContextDeck, a planned client-workspace Chrome extension
- **Social card:** 1200×630, text and simple tab-stack illustration only. Label it “Early-access concept”; do not use a fake product screenshot.
- **Robots during the smoke:** `noindex,follow` so accidental search traffic does not blur source attribution.

### Headline variants

1. **Ship this:** Reopen every tab for the right customer in one click.
2. Stop rebuilding client context every time a ticket comes back.
3. A one-click client workspace for complex support tickets.

### Nav

**ContextDeck**

Button: **Join the early-access waitlist.**

### Hero

**EARLY-ACCESS CONCEPT FOR SAAS SUPPORT TEAMS**

# Reopen every tab for the right customer in one click.

ContextDeck is a planned Chrome extension for hands-on support agents. Save the dashboards, logs, billing pages, and customer records used for a client, then restore that workspace when the ticket comes back.

**Planned from $9/month**

Email field placeholder: **Work email**

Button: **Join the early-access waitlist.**

Microcopy:

Not available yet, and there is no firm ship date. Join to help shape the first useful version. Early-access updates only; unsubscribe anytime.

### Problem

## When the ticket returns, the context is gone.

Complex tickets rarely live in one tool. By the time a customer replies again, the useful tabs are buried, closed, or mixed with another account.

- Reopen the same admin, billing, logs, CRM, and status pages by hand.
- Search for the right account identifiers again before continuing the investigation.
- Double-check every tab because working in the wrong customer context is a real risk.

The repetitive work is not resolving the ticket. It is rebuilding the workspace around it.

### Planned solution

## One client. One workspace. One click back in.

**The planned workflow:**

1. **Group the tabs you already use.**  
   Select the pages involved in a complex customer issue.

2. **Give the workspace a client label.**  
   Keep the relevant dashboard, logs, billing, and record pages together.

3. **Restore it when the ticket returns.**  
   Reopen the saved tab set in Chrome instead of reconstructing it from memory.

No automation theater. Just the right working context when you need it again.

### Who it is for

## Built for the people doing the investigation

ContextDeck is for:

- Hands-on support agents at small SaaS companies.
- Technical or escalated tickets that span several internal and external tools.
- Agents who revisit the same customer issue over multiple sessions or days.
- Chrome-based workflows where tabs are the working surface.

It is not for:

- Teams looking for a complete help-desk or workforce-management suite.
- Organizations that need a production-ready, audited extension today.
- Simple tickets that stay entirely inside one support inbox.
- Teams requiring non-Chrome support in the first experiment.

### Honest proof section

## A concept preview, not a customer claim

**Concept preview**

> ACME Co · Complex billing issue  
> Admin · Billing · Logs · CRM · Status  
> **Restore 5 tabs**

Caption:

Illustration of the planned workflow. This is not a live product screenshot.

Founder note:

We are validating whether repeated client-context reconstruction is painful enough to justify a focused extension before building it. There are no customer logos, testimonials, usage numbers, or launch-date promises yet.

### Offer

## Help shape the first useful version

Early-access subscribers may receive:

- Short progress and validation updates.
- The first invitations to test the extension.
- Questions about permissions, privacy, and the tools that belong in a client workspace.
- A chance to influence what the smallest useful version should include.

**Planned pricing: from $9/month.** Final pricing and included features may change based on early-access feedback. Joining the waitlist does not create a purchase obligation or guarantee an invitation date.

Email field placeholder: **Work email**

Button: **Join the early-access waitlist.**

Microcopy:

Your email is used only for ContextDeck research and early-access updates. Buttondown stores the list. We do not sell it. Unsubscribe anytime.

### FAQ

#### Is ContextDeck available now?

No. This page is a demand test for a planned Chrome extension. There is no downloadable product or firm release date yet.

#### What would a workspace contain?

The current concept is a named set of tabs associated with one client or investigation. Exact handling of URLs, tab titles, identifiers, and workspace data will be decided with early testers.

#### What will it cost?

The current price hypothesis is **from $9/month**. That is a planning signal, not a final price or billing commitment.

#### What about customer-data privacy and Chrome permissions?

No customer data or browser access is requested when you join the waitlist. The product will be designed around minimum necessary Chrome permissions and local storage where practical. The final data flow, permissions, and privacy terms will be disclosed before anyone installs an early build.

#### When will early access begin?

There is no firm ship date. Subscribers will receive an update when there is something concrete to test.

#### What happens after I join?

You will receive a confirmation email, followed by occasional product-research or early-access updates. You may also be invited to describe your current workflow. You can unsubscribe at any time.

### Final CTA

## Spend less time reconstructing the customer. Spend more time resolving the ticket.

A focused Chrome extension for restoring the right client workspace is still a concept. If this problem is familiar, help decide whether it should be built.

**Planned from $9/month**

Email field placeholder: **Work email**

Button: **Join the early-access waitlist.**

### Footer

**ContextDeck is an independent product experiment.**

Privacy: We use your email only for product research and early-access updates, store it with Buttondown, and never sell it.

Contact: **[replace with a real monitored founder email]**

No firm launch date. No purchase is being taken.

## 3. Confirmation and welcome copy

Use double opt-in to reduce fake and mistyped submissions. The primary conversion metric remains a successful form submission; confirmation rate is a separate quality metric.

### Submission success state

**Almost there—check your inbox.**

Confirm your email to join the early-access list. After that, tell us which tabs you reopen most during a complex ticket.

### Confirmation subject

**Confirm your ContextDeck early-access signup**

### Welcome email

**Subject:** You’re on the ContextDeck early-access list

Thanks for confirming.

ContextDeck is still a concept: a Chrome extension that would restore the tabs used for a particular customer or investigation. There is no firm ship date yet.

One question would help:

**Which three to five tools or tabs do you usually reopen when a complex customer ticket comes back?**

If you have a view on pricing, add whether **$9/month feels easy to justify, depends on the workflow, or would not be worth it**.

Just reply to this email. A concrete answer is far more useful than a survey score.

—The ContextDeck founder

## 4. Implementation plan

### Minimal build path

- Host a single responsive page on Cloudflare Pages.
- Use one small same-origin Pages Function at `/api/waitlist` to keep the Buttondown API key server-side.
- Store `BUTTONDOWN_API_KEY` as a Cloudflare secret, never in browser JavaScript or the repository.
- Use Buttondown as the email system of record.
- Configure double opt-in, a confirmation email, and the welcome email above.
- Use Plausible for page views, UTM attribution, and custom funnel events.
- Do not install an ad-platform tracking pixel during this test. UTMs plus Plausible are sufficient and reduce privacy and implementation overhead.
- Show the full privacy statement in the footer; do not request a name, company, ticket data, or browser permissions.

### Form specification

| Item | Specification |
|---|---|
| Visible field | Email, required |
| Optional fields | None on the page; collect workflow detail by reply |
| Hidden fields | Honeypot, UTM fields, `lp_variant`, CTA placement |
| Validation | Trim, lowercase, reasonable length limit, basic email validation |
| Duplicate handling | Return the same success state as a new address; do not reveal whether an address already exists |
| Consent | Double opt-in; unsubscribe link in every email |
| Storage | Buttondown only |
| Analytics privacy | Never send the email address or form contents to Plausible |
| Error state | “We couldn’t add you just now. Please try again, or email [founder email].” |

Initially use a honeypot and server-side rate limiting. Add Turnstile only if spam appears; adding it in advance introduces unnecessary conversion friction.

### Submission flow

1. Preserve UTM parameters and `lp_variant` while the visitor remains on the page.
2. Record `waitlist_submit` without PII.
3. POST the email and hidden attribution values to the same-origin Pages Function.
4. Validate the request and reject honeypot submissions.
5. Subscribe the address through Buttondown.
6. On a provider success or duplicate response, return a generic success result.
7. Fire `waitlist_success` with source, variant, and CTA placement properties.
8. On failure, fire `waitlist_error` with an error category, never an email or raw provider response.
9. Reconcile successful submissions against confirmed Buttondown subscribers after the test.

### Plausible event plan

| Event | Trigger | Properties |
|---|---|---|
| Automatic pageview | Page loads | Standard UTM/referrer attribution |
| `cta_click` | Any nav, hero, offer, or final CTA is clicked | `placement`, `lp_variant` |
| `waitlist_submit` | Valid form submission starts | `placement`, `lp_variant`, source fields |
| `waitlist_success` | Buttondown accepts the request | `placement`, `lp_variant`, source fields |
| `waitlist_error` | Subscription fails | `placement`, `lp_variant`, `error_category` |
| `confirmation` | Reconciled from Buttondown after the test | Spreadsheet metric, not required as a browser event |
| `welcome_open` | Reported by Buttondown | Diagnostic only |
| `workflow_reply` | Manually classified reply | Spreadsheet metric |
| `price_positive` | Reply says $9/month is reasonable | Spreadsheet metric |

Do not make a product decision from email opens alone. Mail privacy features make them noisy.

### QA before Day 1

- Confirm the page at 375px, 768px, and desktop widths.
- Submit a real test email and verify Buttondown receipt.
- Verify double opt-in and welcome-email delivery.
- Verify duplicate submission behavior.
- Verify the success and failure states.
- Confirm every CTA uses the same wording and destination.
- Confirm each UTM source appears correctly in Plausible.
- Confirm no email address appears in Plausible events, page URLs, or logs.
- Confirm internal traffic is excluded.
- Replace the contact-email placeholder.
- Label every visual as a concept, not a screenshot.

## 5. UTM scheme

Use one campaign name for the entire experiment:

`contextdeck_smoke_us_202608`

| Parameter | Values |
|---|---|
| `utm_source` | `reddit_ads`, `reddit`, `linkedin`, `x`, `support_community`, `warm_dm`, `internal` |
| `utm_medium` | `cpc`, `community`, `social`, `outreach`, `qa` |
| `utm_campaign` | `contextdeck_smoke_us_202608` |
| `utm_content` | Post or creative identifier such as `reopened_ticket_v1` |
| `utm_term` | Optional paid-targeting label such as `support_agents` |
| `lp_variant` | `a`, or `b` only after the headline gate |

Examples:

```text
https://YOUR_DOMAIN/?utm_source=reddit_ads&utm_medium=cpc&utm_campaign=contextdeck_smoke_us_202608&utm_content=reopened_ticket_v1&utm_term=support_agents&lp_variant=a
```

```text
https://YOUR_DOMAIN/?utm_source=reddit&utm_medium=community&utm_campaign=contextdeck_smoke_us_202608&utm_content=context_rebuild_post&lp_variant=a
```

```text
https://YOUR_DOMAIN/?utm_source=linkedin&utm_medium=social&utm_campaign=contextdeck_smoke_us_202608&utm_content=founder_problem_story&lp_variant=a
```

```text
https://YOUR_DOMAIN/?utm_source=warm_dm&utm_medium=outreach&utm_campaign=contextdeck_smoke_us_202608&utm_content=personal_batch_01&lp_variant=a
```

Filter out `utm_medium=outreach`, `utm_source=warm_dm`, `utm_source=internal`, and bots from the primary conversion calculation.

## 6. Focused 10-day traffic calendar

Product Hunt is intentionally omitted: there is no working artifact yet, and its launch spike would add weakly comparable traffic.

### Paid-media allocation

Use one paid channel only: a US-targeted Reddit campaign aimed at relevant customer-support/customer-success communities or interests, provided the account can target them narrowly.

- Days 2–4: $20/day, $60 first-stage cap.
- Days 5–7: up to another $60 only if the first gate passes.
- Day 8: reserve the final $30 for the surviving landing variant.
- Hard maximum: $150.
- If the campaign fails a gate, stop spending and leave the remainder unspent. Do not switch to a new ad platform mid-test.

| Day | Channel | Action |
|---|---|---|
| Preflight | Internal | Complete form, email, mobile, UTM, and analytics QA. Exclude all visits. |
| 1 | LinkedIn + X | Publish the founder problem story. Send 10 personal warm messages, tracked separately. |
| 2 | Reddit organic + ads | Post one value-first discussion where rules permit. Launch the paid campaign at $20/day. |
| 3 | Niche support community | Ask an admin for permission, then share the research request. Send the remaining 10 warm messages. |
| 4 | Measurement | Reply to every substantive comment. At $60 or 48 hours, apply the first paid-channel gate. |
| 5 | LinkedIn | Publish the concept-workflow post with the same page, headline, price, and CTA. Continue ads only if qualified. |
| 6 | Email + community | Send the one-question research email to confirmed subscribers. Share once in a second permitted niche community; do not duplicate-spam. |
| 7 | X | Post the privacy/permissions question and link to the same offer. Check the 100-visitor headline gate. |
| 8 | Paid reserve | If the campaign still meets thresholds, apply the final $30 to the control or gated B variant. Otherwise spend nothing. |
| 9 | Follow-up | Answer replies, classify workflow and pricing responses, and interview willing respondents. No new audience or page changes. |
| 10 | Close | Stop spend, export Plausible and Buttondown data, remove internal traffic, separate sources, and apply the decision rules. |

### Channel drafts

#### Reddit organic

**Title:** Support agents: how do you recover customer context when a complex ticket reopens?

**Body:**

I’m researching a repetitive support workflow: a customer replies a day later, but the admin page, logs, billing record, CRM entry, and status checks used for the investigation are gone or mixed into other tabs.

I’m considering a small Chrome extension that would save those tabs as a client workspace and restore them together later.

For people doing hands-on SaaS support:

1. How often do you rebuild this context?
2. Which tools or tabs are usually involved?
3. Would saving URLs as a named workspace be useful, or is the real problem somewhere else?

Maker disclosure: I have not built the extension. I’m testing whether the workflow deserves a product first.

If external links are permitted, I put the concept and pricing hypothesis here: **[UTM link]**. If links are not permitted, omit it and engage in the discussion only.

Do not post identical text across multiple subreddits or argue with moderators.

#### LinkedIn founder story

A complex customer ticket rarely lives in one tab.

An agent checks the admin dashboard, billing, logs, CRM, status history, and sometimes a few internal tools. The customer replies tomorrow, and much of that working context has to be reconstructed.

I’m testing a narrow product idea: a Chrome extension that saves those tabs as a client workspace and restores them in one click.

It is not built. There is no ship date. The current pricing hypothesis is from $9/month.

If you do hands-on support at a small SaaS company, I’d value the signal: **[UTM link]**

#### X post

A reopened support ticket often means reopening the customer’s admin, billing, logs, CRM, and status tabs from scratch.

I’m testing a Chrome extension concept that restores that client workspace in one click.

Not built. No ship date. Planned from $9/month.

**[UTM link]**

#### Niche-community permission message

Hi—may I share a short, disclosed product-research post with the group? I’m validating a Chrome-extension concept for support agents who rebuild customer context across several tabs. It is not built, and I would ask for workflow feedback with one optional waitlist link. I will not repost or DM members.

#### Niche-community post

When a complex ticket returns after a day or two, how do you recover the dashboard, logs, billing, CRM, and other pages you used for that customer?

I’m validating a small Chrome-extension concept that would save and restore those tabs as one client workspace. It is not built, and there is no launch date.

The current price hypothesis is from $9/month. I’m looking for honest “useful” or “wrong problem” feedback from hands-on agents: **[UTM link]**

#### Warm outreach

Hi [name]—I’m testing a narrow idea for support agents who reopen several customer-specific tabs when a complex ticket comes back.

It is a planned Chrome extension, not a product yet. Would you spend two minutes looking at the page and tell me whether the problem is real in your workflow?

**[warm UTM link]**

No pressure to join the list. A blunt reply is more useful.

#### Paid ad

**Headline:** Ticket reopened? Restore the customer’s tabs in one click.

**Body:** A planned Chrome extension for support agents who rebuild context across admin, logs, billing, and CRM. Join the early-access waitlist. Planned from $9/month.

Use headline A on the landing page and one US support-agent audience. Do not change audience, ad promise, and page copy simultaneously.

## 7. Source-specific thresholds

These are directional pre-registration rules, not universal benchmarks.

| Source | Minimum useful sample | Success/continue | Kill or pivot |
|---|---:|---|---|
| Reddit ads | 75 visitors | 4%+ CVR, at least 4 signups, and cost per signup at or below $30 | Stop if $60 buys fewer than 30 visitors; or 50 visitors produce zero signups; or 75+ visitors remain below 2% CVR |
| Organic Reddit | 40 visitors | 7.5%+ CVR and at least 3 signups, plus substantive comments | Pivot the angle if 80+ visitors across two permitted posts remain below 2.5% with no useful replies |
| LinkedIn | 50 visitors | 6%+ CVR and at least 3 signups | Pivot after 100+ visitors across two posts remain below 2% |
| X | 50 visitors | 6%+ CVR and at least 3 signups | Pivot after 100+ visitors across three posts remain below 2% |
| Niche support communities | 30 visitors | 10%+ CVR, at least 3 signups, and 2 workflow replies | Stop community promotion if 60+ visitors across two permitted shares remain below 5% or moderators object |
| Warm outreach | 20 personal messages and 15 visits | 20%+ visitor CVR, 3+ signups, and 3+ workflow replies | Weak warm signal if CVR is below 10% or fewer than 2 contacts confirm the problem |
| Overall non-warm | 200 visitors across 2+ sources | 4%+ CVR, 8+ signups, 3+ detailed replies, 2+ positive price responses | Reshape or park after controlled A/B exposure remains below 2% with no more than 3 signups |

If a source does not reach its minimum, label it inconclusive. Do not pool low-sample sources merely to make one channel appear successful.

## 8. Dashboard

Track one row per source, content item, landing variant, and date:

- Spend
- Impressions and ad clicks, where available
- Unique landing visitors
- CTA clicks
- Submission attempts
- Successful submissions
- Confirmed subscribers
- Detailed workflow replies
- Positive, conditional, and negative $9/month responses
- Waitlist CVR
- Confirmation rate
- Reply rate
- Cost per visitor
- Cost per successful signup
- Notes about moderation, traffic quality, or technical failures

Keep a separate warm-outreach sheet or view.

## 9. Decision rules

| Outcome | Decision |
|---|---|
| Strong non-warm conversion and engaged replies | Proceed to five customer interviews, then scope a thin Chrome-extension MVP around save, label, and restore only |
| Strong CVR but few confirmations | Inspect deliverability, duplicate/fake emails, and acquisition quality before interpreting demand |
| Strong CVR but no workflow replies | Treat as curiosity, not validated demand; interview subscribers before building |
| CTA clicks above 12% but form completion weak | Fix form trust, privacy language, errors, or email friction without changing the promise |
| CTA clicks below 8% across qualified traffic | Rewrite the promise or sharpen the ICP before changing implementation |
| Warm traffic strong, cold traffic weak | Do not average them. Treat it as relationship-biased evidence and retest the positioning with non-warm traffic |
| Organic strong, ads expensive | Preserve the organic wedge; do not assume scalable paid acquisition |
| One source strong, others weak | Interview that source’s signups and narrow the ICP or channel around them |
| 2–3.9% overall CVR | Retest one revised hero based on actual replies; do not add features |
| Below 2% after the full controlled sample | Park the concept or reshape the ICP/problem; do not build the extension to “improve” the smoke result |
| Fewer than 150 non-warm visitors | Diagnose distribution and run a new acquisition test; make no product-demand verdict |
| Unsolicited request to pay or run a paid pilot | Follow up immediately and test a paid MVP slice, but do not treat one request as proof of scale |

## 10. Explicit non-build scope

During this smoke test, do not build:

- The Chrome extension.
- Authentication or user accounts.
- Cloud sync.
- Team sharing or administration.
- Help-desk, CRM, logging, or billing integrations.
- Customer-data extraction.
- AI summaries or automatic tab classification.
- Payments or pricing tiers.
- A product dashboard.
- Fake demos, screenshots, testimonials, logos, or waitlist counters.
- A Product Hunt launch.
- Any backend beyond the minimal waitlist proxy.

## Top three actions today

1. Publish the single page with headline A, the truthful stage disclosure, and the planned $9/month signal.
2. Connect Buttondown and Plausible, then verify submission, confirmation, UTM attribution, and PII exclusion end to end.
3. Prepare the 20-person warm list, obtain permission from two support communities, and stage the $60 first-gate Reddit campaign.

Do not write a PRD or build the extension yet. If the result is weak or respondents use different problem language, run focused customer discovery before repeating the smoke; SEO planning is premature for this 10-day validation.
