STATUS: **DONE_WITH_CONCERNS** — the complete copy-ready smoke package is below, but the read-only sandbox rejected file creation before any changes were made. Buttondown’s current endpoint/metadata contract must also be verified because the required gstack browser is not installed.

# ClientTabs 10-day smoke test

| Field | Value |
|---|---|
| Date | 2026-08-03 to 2026-08-12 |
| Product | ClientTabs |
| ICP | Hands-on support/customer-success agents at small US SaaS teams who repeatedly reopen client-specific browser tabs |
| Promise | Restore a client’s working tabs in one click |
| CTA | **Join the early-access waitlist** |
| Price signal | Planned pricing from **$9/month** |
| Stack | Cloudflare Pages + Pages Functions, Buttondown, Plausible |
| Paid cap | **$150 maximum**, including all retries |
| Stage | Unbuilt concept; no ship date |

## 1. Smoke protocol

### Hypothesis

If hands-on support agents at small US SaaS companies see a Chrome extension that restores each client’s working tabs in one click, qualified cold visitors will confirm an early-access signup at the source-specific rates below, and some will describe a recurring workflow problem or credible willingness to pay from $9/month.

### Metrics

Primary metric:

> Buttondown-confirmed subscribers ÷ Plausible unique visitors for the same source, campaign, and date range.

A conversion requires a confirmed Buttondown subscriber record. These do **not** count:

- CTA clicks
- Form attempts
- Buttondown API errors
- Duplicate addresses
- Pending double-opt-in subscribers
- Invalid or rejected addresses

Secondary metrics:

- CTA clicks per unique visitor
- Buttondown-accepted requests
- Confirmation rate
- Welcome-email opens, diagnostic only
- Replies describing tools, frequency, or pain
- Credible “I would pay $9/month” responses
- Paid-traffic CPC and cost per confirmed subscriber

### Source-specific thresholds

Every row is evaluated separately. Warm traffic is never included in cold, organic, paid, or headline conversion rates.

| Source | Minimum sample | Pass threshold | Weak threshold |
|---|---:|---:|---:|
| Warm outreach | 15 qualified visitors | ≥3 confirmed, 20%, plus ≥2 substantive replies | <2 confirmed after 15 |
| Support communities | 25 | ≥3 confirmed, 12%, plus ≥1 substantive reply | 0–1 confirmed after 25 |
| Reddit organic | 40 | ≥3 confirmed, 7.5%, plus ≥1 substantive reply | <2 confirmed after 40 |
| X organic | 30 | ≥2 confirmed, 6.7% | 0 confirmed after 30 |
| Reddit Ads | 50 | ≥2 confirmed, 4%, and ≤$75 per confirmed subscriber | 0 confirmed after 50 or <2% CVR |

Rates under 50 visits remain unstable. Failure to obtain the minimum sample indicates a distribution problem, not proof that the product problem is absent.

### Overall build gate

Proceed to a thin MVP only when all are true:

- At least two independent sources pass.
- At least one passing source is cold.
- At least four cold-source confirmed subscribers exist.
- At least three substantive replies describe recurring client-context reconstruction.
- At least two respondents credibly accept the planned price of $9/month or more.

Warm results may support the decision but cannot satisfy the cold-source requirement.

## 2. Complete landing-page copy

### Meta and OG

- **Title:** ClientTabs: Restore Client Tabs in One Click
- **Meta description:** A planned Chrome extension for hands-on SaaS support teams. Save each client’s working tabs and restore the full context in one click. From $9/month.
- **OG title:** One click back into every client workspace
- **OG description:** ClientTabs is a planned Chrome extension that restores the tabs hands-on support agents need for each client. Join the early-access waitlist.
- **OG image copy:**  
  **One click back into every client workspace**  
  Planned Chrome extension for hands-on SaaS support teams
- **OG image alt:** Concept illustration of a support agent restoring a saved client workspace
- **Canonical URL:** `https://YOUR_DOMAIN.example/`

Do not include an OG image until a real, clearly labeled concept graphic exists.

### Headline variants

1. **Ship first:** One click back into every client workspace.
2. Restore every client’s support tabs without rebuilding the context.
3. Stop hunting for the same client tabs twice.

Change only the headline during a variant test.

### Nav

**ClientTabs**

Button:

> Join the early-access waitlist

### Hero

Eyebrow:

> For hands-on SaaS support teams

Headline:

> One click back into every client workspace.

Body:

> ClientTabs is a planned Chrome extension that saves the tabs you use for each client, then restores the whole working context when their next ticket lands.

Button:

> Join the early-access waitlist

Stage and price:

> Not built yet. We’re validating demand before development. Planned pricing starts at $9/month.

### Problem

Heading:

> Your client context is scattered across browser history.

Intro:

> Every reopened ticket starts with the same small scavenger hunt.

Cards:

**Rebuild the setup**

> Hunt for the client’s admin page, CRM record, billing account, docs, and prior thread.

**Mix up accounts**

> Work across look-alike tabs and risk acting in the wrong client’s context.

**Lose the thread**

> Close a ticket today, then reconstruct the same working set when it reopens next week.

### Planned solution

Heading:

> Save once. Restore when the client returns.

Disclosure:

> The extension is not available yet. This is the focused workflow we plan to test with early users.

Steps:

1. **Name the client**  
   Collect the tabs already open for a client into one named workspace.

2. **Keep the context**  
   Update that client’s working set as tools, accounts, and cases change.

3. **Restore in one click**  
   Open the saved tabs together when the next support request arrives.

### For and not for

Heading:

> Built for support work that lives in the browser.

**This is for you if…**

- You personally troubleshoot accounts for multiple clients.
- Your team is a small US SaaS company using several browser-based support tools.
- You repeat the same tab setup whenever a client returns.

**It is not designed for…**

- General personal bookmark organization.
- Large contact centers needing workforce management or ticket routing.
- Teams that cannot use Chrome extensions under company policy.

### Honest proof section

Founder note:

> This page is the test, not proof that the product exists. I’m looking for support agents who repeatedly rebuild client-specific browser context. Their waitlist responses will decide whether ClientTabs gets built and what the first version includes.

Caption:

> Founder note · no testimonials or customer claims

Do not add logos, counters, testimonials, ratings, screenshots presented as functional software, or “trusted by” language.

### Offer and form

Heading:

> Spend less time reopening context.

Body:

> Join to hear if early access opens and to share which client tabs you rebuild most often. Planned pricing starts at $9/month if the product is built. Joining is free and does not reserve or lock a price.

Placeholder:

> Work email

Button:

> Join the early-access waitlist

Privacy:

> Your email will be stored in Buttondown and used only for ClientTabs research and product updates. It will not be sold. Confirm by email to join; unsubscribe anytime.

Verified API-acceptance state:

> Request accepted by our email provider. Check your inbox and confirm to complete your signup.

Error state:

> We couldn’t send your request. Check your email and try again.

Do not show “You’re on the list” before double-opt-in confirmation.

### FAQ

**Can I install ClientTabs now?**

> No. ClientTabs is an unbuilt product concept. This waitlist is testing whether the problem is important enough to build for.

**When will it ship?**

> There is no firm ship date. If demand supports development, waitlist members will hear about research sessions and early access first.

**What will it cost?**

> Planned pricing starts at $9/month if the extension is built. Final plans and features may change as we learn from support teams. Joining the waitlist is free.

**Will it read my client data?**

> The privacy model is not finalized because the extension has not been built. The intended first version stores the workspace information needed to reopen chosen tabs, not page contents. Permissions, storage, and security details must be validated before release.

**What happens after I join?**

> Buttondown will send a confirmation email. After you confirm, you may receive a short question about your workflow and occasional development updates. No access date is promised.

**Why focus on small US SaaS teams?**

> They often combine hands-on support with several browser tools while having little time to configure heavyweight service software. This test intentionally stays narrow.

### Final CTA

Heading:

> Would one-click context restore improve your support shift?

Button:

> Join the early-access waitlist

### Footer

> ClientTabs is an independently developed product concept.

> Questions: YOUR_EMAIL@example.com · Email stored by Buttondown; privacy-friendly analytics by Plausible.

## 3. Implementation package

### Minimal file structure

```text
index.html
functions/
  api/
    waitlist.ts
```

No React app, database, authentication, extension code, or package scaffold is needed.

### Form contract

Visible field:

- `email`, required

Hidden/derived metadata:

- `utm_source`
- `utm_medium`
- `utm_campaign`
- `utm_content`
- `traffic_class`
- `landing_variant=a_context_restore`

Include an invisible honeypot field, but do not treat it as product qualification.

The Pages Function should:

1. Accept same-origin `POST /api/waitlist`.
2. Validate and normalize the email.
3. Allowlist metadata fields and lengths.
4. Reject honeypot submissions.
5. Call Buttondown using `BUTTONDOWN_API_KEY`.
6. Return success only after Buttondown returns a verified successful response.
7. Never log the email address.
8. Return neutral errors without exposing provider details.

Cloudflare secrets/configuration:

```text
BUTTONDOWN_API_KEY
BUTTONDOWN_SUBSCRIBERS_URL
```

`BUTTONDOWN_SUBSCRIBERS_URL` must be copied from current Buttondown account documentation before deployment; it should not be guessed or committed.

### Buttondown setup

- Enable double opt-in.
- Confirmation subject: **Confirm your ClientTabs waitlist spot**
- Welcome subject: **Which client tabs do you rebuild?**
- Welcome copy:

> Thanks for confirming. ClientTabs is still only a product concept.  
>   
> Reply with three quick details if this problem is familiar:  
> 1. Which browser tools do you reopen for a client?  
> 2. How often do you rebuild that setup?  
> 3. Would solving it be worth at least $9/month to you?  
>   
> A reply helps decide whether this gets built. There is no promised access date.

Before traffic, submit one valid and one invalid address and confirm that Buttondown preserves every UTM and `traffic_class` value on the subscriber record. If it cannot, use distinct Buttondown forms/tags per source. Do not calculate source-specific CVR until this works.

### Plausible events

| Event | Trigger | Evidence level |
|---|---|---|
| Pageview | Plausible automatic pageview | Visit |
| `CTA Click` | CTA anchor clicked | Interest |
| `Waitlist Attempt` | Valid browser form sent | Attempt only |
| `Waitlist Accepted` | Pages Function receives Buttondown 2xx | Provider acceptance, not confirmed subscription |
| Confirmed subscriber | Buttondown confirmed export | Primary conversion source of truth |
| Reply | Buttondown/manual review | Qualitative intent |

Event properties:

- `location`: `nav`, `hero`, or `final`
- `traffic_class`
- `landing_variant`

Never emit a client-side `Waitlist Confirmed` event from the submit handler.

### Deployment

```bash
pnpm dlx wrangler pages dev .
pnpm dlx wrangler pages deploy . --project-name clienttabs-smoke
```

Before deployment:

- Replace `YOUR_DOMAIN.example`.
- Replace `YOUR_EMAIL@example.com`.
- Configure the Plausible domain.
- Add Cloudflare secrets.
- Verify Buttondown’s endpoint and metadata format.
- Test mobile, keyboard navigation, valid submission, invalid submission, provider failure, and duplicate submission.

## 4. UTMs

Campaign:

```text
clienttabs_smoke_202608
```

| Source | URL |
|---|---|
| Warm outreach | `https://YOUR_DOMAIN.example/?utm_source=warm_outreach&utm_medium=personal&utm_campaign=clienttabs_smoke_202608&utm_content=founder_dm` |
| Reddit organic | `https://YOUR_DOMAIN.example/?utm_source=reddit&utm_medium=community&utm_campaign=clienttabs_smoke_202608&utm_content=post_NAME` |
| X | `https://YOUR_DOMAIN.example/?utm_source=x&utm_medium=social&utm_campaign=clienttabs_smoke_202608&utm_content=post_NAME` |
| Support community | `https://YOUR_DOMAIN.example/?utm_source=support_community&utm_medium=community&utm_campaign=clienttabs_smoke_202608&utm_content=community_NAME` |
| Reddit Ads | `https://YOUR_DOMAIN.example/?utm_source=reddit_ads&utm_medium=cpc&utm_campaign=clienttabs_smoke_202608&utm_content=context_restore_a` |

Do not share the warm URL publicly. Do not relabel warm referrals as direct or organic.

## 5. Ten-day traffic calendar

| Day | Date | Action | Maximum spend |
|---|---|---|---:|
| 1 | Aug 3 | Deploy, test Buttondown attribution, configure Plausible goals, record baseline | $0 |
| 2 | Aug 4 | Send five personalized warm messages; publish X problem post | $0 |
| 3 | Aug 5 | Ask permission in two support/customer-success communities; launch one Reddit ad creative | $25 |
| 4 | Aug 6 | Publish one value-first Reddit post after checking rules; reply to every response | $25 |
| 5 | Aug 7 | Review first $50. Continue ads only if ≥15 qualified visits and either ≥2 accepted requests or ≥1 confirmed subscriber | Up to $25 |
| 6 | Aug 8 | Send five more warm messages; publish X workflow post; no copy changes | Up to $25 |
| 7 | Aug 9 | Community follow-up with a transparent concept graphic or workflow question | Up to $25 |
| 8 | Aug 10 | Final five to ten warm messages; publish X price-signal post | Up to $25 |
| 9 | Aug 11 | Stop ads. Export Plausible and Buttondown data; send one welcome follow-up to confirmed subscribers | $0 |
| 10 | Aug 12 | Reconcile confirmed records, classify replies, apply source-specific rules, decide | $0 |

Hard rules:

- Total ad spend cannot exceed $150.
- Do not move organic or warm conversions into the paid cohort.
- Stop after the first $50 if the day-five gate fails.
- Unspent money stays unspent; it is not a target.
- Do not change headline, audience, and ad creative simultaneously.

## 6. Channel drafts

### Warm outreach

> Hi [Name] — I’m testing a narrow idea for people who personally support multiple SaaS clients. It would save each client’s working tabs and reopen the full set in one click.  
>   
> This is only a concept, not a product pitch. Would you take two minutes to tell me whether the problem is real for you?  
>   
> [warm UTM URL]

Send only to relevant people you already know or can contact legitimately. Track replies separately from page conversions.

### X post 1

> Hands-on SaaS support often begins with a scavenger hunt: admin page, CRM record, billing account, docs, and the old thread.  
>   
> I’m testing an unbuilt Chrome extension that would restore those client-specific tabs in one click. Planned from $9/month.  
>   
> Join the early-access waitlist: [X UTM URL]

### X post 2

> Question for people supporting multiple SaaS customers: when an old ticket reopens, how many tabs do you rebuild before you can actually help?  
>   
> I’m testing a focused solution, not claiming it exists yet.  
>   
> Join the early-access waitlist: [X UTM URL]

### Reddit organic

Suggested communities must be checked for current self-promotion rules before posting.

Title:

> How do hands-on support teams preserve browser context between client tickets?

Body:

> I support the idea of treating each client’s browser context as a reusable workspace: admin account, CRM, billing, logs, docs, and the prior thread.  
>   
> I’m testing whether this is painful enough to justify a small Chrome extension that restores those tabs together. It is not built, there is no ship date, and planned pricing would start at $9/month.  
>   
> I’d especially value hearing how people handle this today and which tools must be reopened. I made a one-page description here: [Reddit UTM URL]  
>   
> Disclosure: I’m the person considering building it.

Do not cross-post identical text to multiple subreddits.

### Support community

> May I share a one-page product concept for feedback? It is aimed at support agents who repeatedly reopen client-specific admin, CRM, billing, and documentation tabs. The proposed workflow restores that context in one click. It is not built, and I’m trying to learn whether it deserves to be.

Post the link only after permission.

### Reddit ad

Headline:

> Reopen every client’s support tabs in one click

Body:

> A planned Chrome extension for hands-on SaaS support teams. Save client-specific workspaces and restore them when the next ticket lands. Planned from $9/month.

Destination instruction:

> Join the early-access waitlist: [paid UTM URL]

Target the US and communities/interests close to SaaS support or customer success. Use one audience and one creative for the initial $50.

## 7. Dashboard

One spreadsheet row per date and source:

```text
date
traffic_class
utm_content
unique_visitors
cta_clicks
waitlist_attempts
buttondown_accepted
buttondown_confirmed
confirmation_rate
confirmed_cvr
welcome_opens
substantive_replies
price_positive_replies
ad_spend
cpc
cost_per_confirmed
notes
```

Reconcile Buttondown and Plausible using source metadata and matching dates. Do not infer source from signup time.

## 8. Decision rules

| Result | Decision |
|---|---|
| Two sources pass, including one cold source, with recurring-pain and price replies | Write a thin PRD and build only workspace save/restore |
| One source passes, or cold CVR passes without substantive replies | Run 5–8 customer-discovery interviews before building |
| CTA click rate is healthy but confirmation is weak | Inspect form trust, deliverability, and confirmation copy; retest without changing the ICP |
| CTA click rate is <5% on a source that reached its sample | Test headline variant 2 with the same source and offer |
| Warm passes but every cold source fails | Treat as relationship bias; reshape the promise or ICP |
| Two cold sources reach minimum samples and remain below weak thresholds, with no substantive replies | Park or reshape; do not build more features |
| Samples are not reached | Record distribution failure; do not call it product rejection |
| A credible user asks to pay | Interview that person and test a paid MVP slice; one request is not proof of scale |

## 9. What not to build

- Chrome extension
- Workspace synchronization
- Team accounts
- Authentication
- Billing
- Stripe integration
- AI tab classification
- CRM/help-desk integrations
- Admin dashboard
- Product analytics pipeline
- Full brand system
- SEO content program

## 10. Evidence handoff

| Field | Value |
|---|---|
| Current decision | TBD after test |
| Evidence classes | assumption |
| Supported claims | TBD after test |
| Still unproven | Demand from cold traffic, willingness to pay, product usability, extension permissions, privacy model, retention, and viable paid acquisition |
| Contradictions / exclusions | Warm outreach must remain separate; attempts, API acceptance, pending confirmations, duplicates, bots, and unattributed subscribers are excluded from confirmed CVR |
| Source anchors | TBD after test: dated Plausible source export, Buttondown confirmed-subscriber export with metadata, ad-platform spend export, and categorized reply log |
| Next validation | Founder runs the 2026-08-03 to 2026-08-12 test and applies the pre-registered per-source thresholds without pooling warm and cold traffic |

Top three actions today:

1. Make the workspace writable and materialize `index.html` plus `functions/api/waitlist.ts`.
2. Create Buttondown and Plausible properties, then verify one attributed double-opt-in signup.
3. Replace the domain/email placeholders and deploy the Cloudflare Pages preview.

Do not build the extension yet. A separate `z-market-validate` loop is optional if cold distribution proves difficult; `z-seo-plan` should wait because this test depends on targeted outreach and community traffic, not search.