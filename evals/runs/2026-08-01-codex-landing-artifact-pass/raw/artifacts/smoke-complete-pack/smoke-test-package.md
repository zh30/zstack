# Client Restore — 10-day landing smoke test

| Field | Value |
|---|---|
| Date prepared | 2026-08-01 |
| Test window | 2026-08-03 through 2026-08-12 (10 calendar days) |
| ICP | Hands-on support agents and support leads at small US SaaS teams who repeatedly switch among client-specific browser tabs |
| Problem | Rebuilding the right browser context every time work switches to another client |
| Promise | Restore a saved client-specific tab workspace in one click |
| CTA | **Join the early-access waitlist** |
| Price signal | Truthful planned pricing from **$9/month**; not a locked offer |
| Stage | Concept only; extension is not built; no firm ship date |
| Stack | Static Cloudflare Pages + one Pages Function + Buttondown + Plausible |
| Paid cap | **$150 maximum**, including all paid variants; no automatic overage |

## 1. Smoke protocol

### Hypothesis

If small US SaaS support teams are offered a Chrome extension that restores each client’s saved tab workspace in one click, enough qualified people will join an early-access waitlist—and describe a real workflow or willingness to pay from $9/month—to justify a thin product discovery/MVP step.

The test is about demand for the outcome, not retention, extension permissions, technical feasibility, or the final price.

### Funnel and evidence boundaries

```text
Attributed unique landing visitor
  → CTA Click (interest)
    → Waitlist Attempt (attempt only)
      → Buttondown API accepts subscriber (primary conversion)
        → double opt-in / open (deliverability diagnostics)
          → substantive reply / explicit $9 intent (stronger demand)
```

- **Primary metric:** provider-accepted waitlist conversion rate = unique attributed visitors ÷ Buttondown-accepted, deduplicated subscriber records, calculated separately for every traffic source.
- **Conversion source of truth:** Buttondown subscriber export. `Waitlist Confirmed` in Plausible is a diagnostic cross-check, not the canonical count.
- **Qualified visitor:** a US visitor recorded by Plausible, carrying the expected source UTM, and not identified as internal/test traffic. Count Plausible unique visitors, not raw pageviews.
- **Qualified reply:** a reply that names a current client-switching workflow, cost, frequency, workaround, purchase role, or willingness to try/pay. “Cool idea” does not qualify.
- **Price-intent signal:** an unprompted or direct answer that the person/team would pay at least $9/month for the promised outcome. No payment is collected in this test.
- **Open rate:** diagnostic only; privacy protections make it noisy.
- Invalid email, rejected/duplicate request, bot attempt, and `Waitlist Attempt` are never conversions.

### Source isolation and pre-registered thresholds

Never pool warm outreach with cold traffic. Do not pool cold sources for a source verdict either. Aggregate cold totals may be shown as a summary only after each source row remains visible.

| Source | Traffic class | Minimum qualified visitors | Strong signal | Weak at minimum sample | Notes |
|---|---|---:|---|---|---|
| Personal, relevant DMs | `warm_outreach` | 20 | ≥5 accepted signups (≥25%) and ≥2 qualified replies | ≤1 signup (≤5%) or zero replies | Relationship bias; never used to rescue a cold result |
| Organic Reddit | `cold_community` | 40 | ≥3 accepted signups (≥7.5%) and ≥1 qualified reply | 0 signups and zero replies | One compliant buyer-community placement; do not cross-post spam |
| Permissioned support community | `cold_community` | 30 | ≥4 accepted signups (≥13.3%) and ≥2 qualified replies | 0 signups and zero replies | Higher-intent niche audience; must have moderator permission |
| X organic posts | `cold_social` | 40 | ≥3 accepted signups (≥7.5%) and ≥1 qualified reply | 0 signups and zero replies | Mixed social intent; engagement alone is not demand |
| Reddit paid campaign | `cold_paid` | 60 | ≥3 accepted signups (≥5%) and cost per accepted signup ≤$50 | 0 signups after 60 visitors, or cost per signup >$75 after ≥2 signups | $150 total ceiling; one ICP, two controlled hero/creative variants |

Rates below 50 visits are unstable. If a source misses its minimum, mark it **inconclusive / distribution miss**, not product failure.

### Secondary targets

| Metric | Target by day 10 | Interpretation |
|---|---:|---|
| Cold provider-accepted signups | ≥10 across at least two separately successful cold sources | Breadth beyond one channel |
| Qualified replies from cold signups | ≥3 | Evidence of lived pain |
| Explicit willingness to pay from $9/month | ≥2 cold respondents | Price-interest evidence, not purchase proof |
| Buttondown accepted → double opt-in | Record, no universal threshold | Diagnose deliverability and list quality |
| Unsubscribes / spam complaints | Record all | Any complaint triggers copy and consent review |

### Operational stop rules

- Hard-stop all ads at **$150 total spend**, even if the platform suggests more.
- Pause a paid creative after at least 20 landing visitors and zero accepted signups; do not reallocate above the total cap without recording the change.
- Pause if CPC exceeds $4 after 15 clicks, inspect audience/message fit, and spend no more until corrected.
- Pause any channel immediately if a moderator objects, a post breaks rules, or traffic appears bot-heavy.
- Freeze hero wording during a measurement slice. Use `variant=a` and `variant=b` links; never edit audience, creative, and page promise simultaneously.
- Do not count founder tests. Use `utm_source=internal_test&utm_medium=qa` and exclude them in Plausible and Buttondown exports.

## 2. Landing-page copy

The deployable page is `site/index.html`. This section is the copy source of truth.

### Meta and social copy

- **Meta title:** Client Restore — One-click context restore for SaaS support teams
- **Meta description:** Restore the right tabs for each client in one click. Client Restore is a planned Chrome extension for hands-on support agents at small US SaaS teams.
- **OG title:** One click. Every client tab, right where you left it.
- **OG description:** A planned Chrome extension that restores client-specific tab workspaces for hands-on support agents at small US SaaS teams. Planned pricing from $9/month.
- **OG image alt:** Client Restore: one-click context restore for SaaS support teams
- **X description:** Restore client-specific tab workspaces without rebuilding context. Planned pricing from $9/month.

### Headline variants

1. **Ship first (A):** One click. Every client tab, right where you left it.
2. **Problem-first (B):** Stop rebuilding your browser for every client.
3. **Category wedge (C, hold back):** The client workspace switcher for hands-on SaaS support.

The page accepts `?variant=a`, `?variant=b`, or `?variant=c`, preserves the variant on every confirmed subscriber record, and defaults to A. Test A versus B only during this 10-day run; C is reserved for a later retest.

### Full page copy

**Nav**

- Product: Client Restore
- CTA: **Join the early-access waitlist**

**Hero**

- Eyebrow: For hands-on support agents at small US SaaS teams
- Headline A: One click. Every client tab, right where you left it.
- Subhead A: Client Restore is a planned Chrome extension that saves a tab workspace for each client, then restores the whole context when the next ticket lands.
- Price: Planned pricing from $9/month
- CTA: **Join the early-access waitlist**
- Honesty: Not built yet. Join to help shape the first useful version. No firm ship date.

**Problem**

- Rebuild the client setup — You hunt through history, bookmarks, and half-labeled tabs before you can touch the issue.
- Mix up client context — Similar dashboards and account pages make the wrong tab an easy, costly mistake.
- Lose momentum all day — Every client switch breaks focus and turns routine support work into browser cleanup.

**Planned solution**

1. Name the client workspace — Group the tabs you use for one client, from their admin page to tickets and logs.
2. Save the working context — Keep the workspace ready without leaving every client tab open all day.
3. Restore it in one click — Open the client’s saved tab set when work arrives and get back into the issue faster.

**For / not for**

- For support agents switching among client accounts, customer success/implementation teammates who live in Chrome, and small US SaaS teams needing a lightweight personal workflow.
- Not a help desk, CRM, shared knowledge base, fit for browsers that prohibit extensions, or useful for people who rarely revisit client-specific tabs.

**Proof / stage disclosure**

We are testing the need before building the extension. This page is a concept, not a live product. There are no customer claims, usage numbers, or promised launch date. Early-access members may be invited to a short research conversation and will hear when there is a concrete product update.

**FAQ**

1. **Is it available now?** No. It is a planned Chrome extension, and this waitlist tests whether the problem is worth solving. There is no firm ship date.
2. **What would it cost?** Planned pricing starts at $9/month. This is a genuine pricing hypothesis, not a locked offer; scope and final pricing may change.
3. **What does one-click restore mean?** The planned core action is to reopen a saved set of client-specific tabs from the extension in one click. Permissions, behavior, and limits still require testing.
4. **What about client privacy?** The intended product should minimize data collection and explain every Chrome permission. The storage model is not finalized. Buttondown stores waitlist email/answers; Plausible measures aggregate page activity.
5. **What happens after I join?** Buttondown sends the configured confirmation or welcome email. We may ask about the workflow and send occasional updates; unsubscribe anytime.
6. **Is it for team workspace sharing?** Not in this test. The first question is whether individual agents value fast, client-specific context restore.

**Final offer**

- Heading: Spend less time rebuilding client context.
- Body: Tell us where the browser slows you down. Planned pricing starts at $9/month; joining is free and does not reserve or charge anything.
- CTA: **Join the early-access waitlist**
- Privacy: Email and optional answer are stored in Buttondown, never sold. Plausible records aggregate funnel events and campaign attribution.

## 3. Implementation and event contract

### Files and responsibilities

| File | Responsibility |
|---|---|
| `site/index.html` | Mobile-first one-page copy, A/B headline rendering, form validation, Plausible events |
| `functions/api/waitlist.ts` | Same-origin validation and server-side Buttondown submission; keeps API key secret |
| `wrangler.toml` | Cloudflare Pages build output and non-secret variables |
| `site/og-card.svg` | 1200×630 social concept card; convert to PNG if a target platform rejects SVG |
| `measurement-template.csv` | Daily source/variant measurement ledger |
| `README.md` | Setup, deploy, QA, and external-service checklist |

### Form contract

| Field | Required | Storage | Purpose |
|---|---|---|---|
| Work email | Yes | Buttondown | Waitlist identity and follow-up |
| Biggest pain | No, 500 chars | Buttondown subscriber metadata | Qualitative intent and interview prioritization |
| Consent checkbox | Yes, unchecked by default | Submission metadata (`consent_source`) | Explicit product-research email consent |
| Honeypot | Hidden | Not stored | Reject simple bots |
| UTMs, variant, traffic class | Captured automatically | Buttondown subscriber metadata | Source-specific numerator and experiment slice |

Use Buttondown double opt-in for list quality and deliverability. A provider-accepted record is the primary landing conversion; opt-in completion is a separate downstream metric. Emails are stored in Buttondown, must not be sold, and should be deleted on a valid privacy request.

### Event definitions

| Plausible event | Fires when | Counts as conversion? | Required properties |
|---|---|---|---|
| `Landing View` | Page JavaScript initializes | No | source, medium, campaign, content, variant, traffic_class |
| `CTA Click` | Any CTA scroll link is clicked | No | same |
| `Waitlist Attempt` | Valid browser form begins the API request | No | same |
| `Waitlist Confirmed` | The Pages Function returns 201 only after Buttondown returns success | Diagnostic yes; Buttondown export remains canonical | same |
| `Waitlist Error` | Network/provider/API validation failure | No | same + generic reason |

Plausible's automatic pageview can coexist with `Landing View`; use the custom event for property-rich funnel slices and the automatic pageview for standard traffic reporting. Never substitute attempts for accepted subscribers.

### Confirmation truthfulness

- Before the API response: “Sending your request…”
- After Buttondown acceptance: “You’re on the early-access list. Check your inbox for Buttondown’s next step.”
- On failure: “We couldn’t confirm your signup. Please try again…”
- The page never shows confirmed success after a timeout or unverified submit.

### Buttondown attribution requirement

The function sends `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `utm_term`, `variant`, and `traffic_class` as subscriber metadata. Before buying traffic, confirm in a real Buttondown subscriber record that every field survives. If the current Buttondown plan/API does not store metadata:

1. Do **not** calculate source CVR.
2. Replace the design with provider-supported source tags or distinct lists/forms per source.
3. Re-run one valid submission per source and export the records before launch.

Do not infer source from timestamps or allocate an unattributed subscriber total across sources.

## 4. UTM matrix

Replace `https://YOUR_DOMAIN/` after deployment. Lowercase values only; never reuse `warm_dm` for cold contacts.

| Source | Exact URL | Class |
|---|---|---|
| Warm DM, hero A | `https://YOUR_DOMAIN/?utm_source=warm_dm&utm_medium=outreach&utm_campaign=client_restore_smoke_202608&utm_content=personal_a&variant=a` | warm_outreach |
| Organic Reddit, hero A | `https://YOUR_DOMAIN/?utm_source=reddit_organic&utm_medium=community&utm_campaign=client_restore_smoke_202608&utm_content=post_a&variant=a` | cold_community |
| Support community, hero A | `https://YOUR_DOMAIN/?utm_source=support_community&utm_medium=community&utm_campaign=client_restore_smoke_202608&utm_content=permission_post_a&variant=a` | cold_community |
| X post 1, hero A | `https://YOUR_DOMAIN/?utm_source=x&utm_medium=social&utm_campaign=client_restore_smoke_202608&utm_content=problem_post_a&variant=a` | cold_social |
| X post 2, hero B | `https://YOUR_DOMAIN/?utm_source=x&utm_medium=social&utm_campaign=client_restore_smoke_202608&utm_content=workflow_post_b&variant=b` | cold_social |
| Reddit ad A | `https://YOUR_DOMAIN/?utm_source=reddit_ads&utm_medium=cpc&utm_campaign=client_restore_smoke_202608&utm_content=client_tabs_a&variant=a` | cold_paid |
| Reddit ad B | `https://YOUR_DOMAIN/?utm_source=reddit_ads&utm_medium=cpc&utm_campaign=client_restore_smoke_202608&utm_content=rebuild_context_b&variant=b` | cold_paid |
| Internal QA | `https://YOUR_DOMAIN/?utm_source=internal_test&utm_medium=qa&utm_campaign=client_restore_smoke_202608&utm_content=valid_test&variant=a` | direct_unknown; exclude |

Reddit organic and the permissioned support community are separate sources even though both use `cold_community` as a class. Apply their thresholds separately; never decide from a pooled community subtotal. The same placement-level reporting applies to each X post and ad creative.

## 5. Ten-day traffic calendar

| Day / date | Channel | Action | Spend cap | Measurement gate |
|---|---|---|---:|---|
| 1 · Aug 3 | QA + warm | Complete valid/invalid/duplicate submissions; verify Buttondown metadata and Plausible events. Then send 5 personalized DMs. | $0 | No public traffic until attribution passes |
| 2 · Aug 4 | Organic Reddit | Read current rules, contribute context, post one founder-disclosed problem/feedback post where allowed. Reply to everyone. | $0 | Record removal/mod feedback; do not repost elsewhere same day |
| 3 · Aug 5 | X + warm | Publish problem-story post A; send 5 more personalized DMs. | $0 | Keep hero A fixed |
| 4 · Aug 6 | Support community | Ask moderator permission; share one research-first post if approved. Send welcome question to accepted subscribers. | $0 | Separate support-community and Reddit records |
| 5 · Aug 7 | Paid Reddit | Start one narrow US audience, two ads split A/B, daily platform cap $30. | $30 | Check clicks, visitor match, metadata—not statistical winner |
| 6 · Aug 8 | Paid + X | Continue paid A/B if neither stop rule triggered. Publish workflow post B on X. Send 5 warm DMs. | $30 | No copy/audience changes beyond registered variant |
| 7 · Aug 9 | Paid | Continue, answer comments/replies, tag qualified replies. No new channel. | $30 | Pause a creative at 20 visits/0 signups |
| 8 · Aug 10 | Paid + community follow-up | Final permitted community follow-up with early learning, not a repeated pitch. Continue viable ads. | $30 | Check each source against minimum sample |
| 9 · Aug 11 | Paid + warm | Last paid day, capped at remaining budget; send final 5 warm DMs. Ask accepted subscribers one $9 question. | $30 max | Campaign lifetime spend must be ≤$150 |
| 10 · Aug 12 | No acquisition after noon | Export Plausible and Buttondown, dedupe, exclude QA/bots, reconcile events, score each source, apply rules. | $0 | Freeze data with timestamp and preserve exports |

### Channel drafts

#### Warm outreach — 20 relevant contacts only

> Hey [Name] — I’m testing a small idea for support teams that repeatedly jump between client accounts. The concept is a Chrome extension that restores each client’s working tabs in one click. It isn’t built yet. Would you spend two minutes telling me whether this matches a real part of your day? [warm UTM] No pressure to join; blunt feedback is more useful.

Do personalize why the person fits. Do not automate, scrape addresses, or count friendly replies as signups.

#### Organic Reddit / buyer community

**Title:** Support agents: how do you rebuild browser context when switching clients?

> I’m researching a repetitive part of hands-on SaaS support: moving from Client A to Client B and finding the right admin, ticket, logs, CRM, and docs tabs again. I’m the maker of a not-yet-built concept that would save those tabs per client and restore them in one click. I made a one-page description and would value criticism, especially around privacy and whether this is frequent enough to pay for. Planned price starts at $9/month; there is no ship date. [community UTM]

Check the current community rules and use an allowed feedback/research flair. Do not post identical copy across multiple subreddits or disguise the founder relationship. Candidate communities must be verified manually because no live web check was available while preparing this package.

#### X post A — problem story

> A support ticket rarely starts with the ticket. First comes the client admin, CRM, logs, billing, docs—and the hunt for where you left off. I’m testing a not-yet-built Chrome extension that would restore that client workspace in one click. Planned from $9/mo. Honest criticism welcome: [X A UTM]

#### X post B — workflow question

> For hands-on SaaS support: when you switch clients, do you reopen the same 4–8 tabs again? I’m testing a focused Chrome extension concept: save each client’s tabs once, restore them in one click. No launch date; planned from $9/mo. [X B UTM]

#### Permissioned support community

> Founder research, posted with moderator approval: I’m testing whether client-specific tab restore is a real support workflow problem before building anything. The one-page concept promises one-click restore, says clearly that it is unbuilt, and asks for an early-access email. If you handle multiple SaaS clients, I’d value a blunt read: [support-community UTM]

Do ask permission and answer discussion. Do not DM community members without invitation.

#### Paid Reddit creative A

- Headline: Restore every client tab in one click
- Body: A planned Chrome extension for hands-on support agents at small US SaaS teams. Join the early-access waitlist. Planned from $9/month.
- Destination: Reddit ad A UTM

#### Paid Reddit creative B

- Headline: Stop rebuilding your browser for every client
- Body: Save each client’s working tabs once, then restore the context when support work arrives. Concept stage. Planned from $9/month.
- Destination: Reddit ad B UTM

Ad targeting: United States, desktop, one tightly relevant support/SaaS interest or community cluster. Exclude broad Chrome-extension audiences if they dilute the ICP. Keep targeting identical across A/B. Platform availability and current ad-policy compatibility require manual verification.

### Subscriber follow-up

Buttondown welcome subject: **Quick question about your client-tab workflow**

> Thanks for joining Client Restore early access. This is still a concept, so your answer matters more than a generic signup. What happened the last time you had to switch from one client’s work to another? And if one-click restore solved that reliably, would $9/month feel reasonable for you or your team? Reply in a sentence or two. — [Founder name]

Do not interpret email open as demand. Code replies by source, current behavior, frequency, workaround, role, and explicit price answer.

## 6. Dashboard and reconciliation

Use `measurement-template.csv` as the ledger. Keep the Buttondown export and Plausible export unedited; calculate in a separate sheet.

Daily checks:

1. Spend and hard cap.
2. Qualified unique visitors by exact source/content/variant.
3. CTA clicks and attempts as diagnostics.
4. Buttondown-accepted, deduplicated subscribers by the same attribution fields.
5. Confirmed conversions divided by matching-source qualified visitors.
6. Qualified replies and explicit $9 intent, coded by original source.
7. Errors, invalid submissions, duplicates, complaints, and attribution gaps.

Reconciliation rule: if Plausible `Waitlist Confirmed` differs from Buttondown accepted records, use Buttondown for conversion counts and investigate the discrepancy. If Buttondown attribution is missing, source-level CVR is invalid and the decision pauses.

## 7. Decision rules

### Source-level rules

- **Strong source:** meets its minimum visitors and its exact strong conversion/reply threshold.
- **Borderline source:** meets minimum visitors and lands between weak and strong, or meets rate but not reply/CPA requirement. Interview and retest the same source with one changed variable.
- **Weak source:** meets minimum visitors and matches its weak threshold. Stop that placement; do not generalize beyond it.
- **Inconclusive source:** misses minimum sample, attribution, or provider QA. This is a distribution/measurement failure, not a product verdict.

### Product decision matrix

| Result at day 10 | Decision | Next action |
|---|---|---|
| At least 2 cold sources are strong, ≥10 accepted cold signups, ≥3 qualified cold replies, and ≥2 explicit $9-positive replies | **Proceed to thin discovery/MVP definition** | Interview 5 highest-signal cold respondents; specify only save/name/restore and permission model |
| One cold source strong, or ≥10 cold signups but reply/price evidence misses | **Retest** | Run 5 interviews, sharpen the pain/ICP, then repeat one source with one changed headline or qualifier |
| Cold CVR strong but zero qualified replies after follow-up | **Soft demand** | Do not build; interview and test a paid commitment/deposit separately |
| Traffic meets minimums but all cold sources are weak | **Reshape** | Change ICP or job-to-be-done, not feature list; rerun a fresh smoke |
| After a second controlled offer test: ≥200 qualified cold visitors across at least 2 sources, <2% accepted CVR, fewer than 4 accepted signups, and zero qualified replies | **Park** | Archive evidence and revisit only with new customer evidence |
| Minimum samples not reached or attribution fails | **Inconclusive** | Fix distribution or measurement; do not claim product rejection or approval |

Warm outreach may inform interviews but cannot satisfy any cold-source requirement above.

## 8. Explicit non-build scope

Do not build during the smoke:

- Chrome extension, manifest, workspace storage, tab APIs, login, sync, team sharing, admin, billing, or Stripe
- Product UI mockups that could be mistaken for a working product
- Help desk/CRM integrations, AI tab grouping, analytics dashboard, mobile app, or cross-browser version
- Brand system, multi-page marketing site, blog, SEO program, referral system, or testimonials program
- A promised release date or claims about permissions/privacy architecture before technical discovery

Only the landing, provider connection, analytics, outreach, and evidence ledger are in scope.

## 9. Evidence handoff

| Field | Value |
|---|---|
| Current decision | TBD after test |
| Evidence classes | assumption |
| Supported claims | TBD after test |
| Still unproven | Whether qualified cold visitors convert; reply and $9 price intent; payment; Chrome API feasibility; permission acceptance; product value; retention; final scope and pricing |
| Contradictions / exclusions | No testimonials, logos, user counts, product usage, payment evidence, or firm ship date. Warm outreach is excluded from cold rates. Attempts, invalid/duplicate/rejected submissions, internal QA, and unattributed subscribers are excluded from conversion evidence. |
| Source anchors | Before launch: `smoke-test-package.md`, `site/index.html`, `measurement-template.csv`. After test: TBD after test—attach dated Plausible export/view, Buttondown subscriber export with metadata, ad spend export, reply coding, and data-freeze timestamp. |
| Next validation | Founder runs the 2026-08-03 preflight; pass only when one valid signup is provider-accepted with complete attribution, one invalid signup is rejected, duplicate behavior is documented, and Plausible attempt/confirmed events match their definitions. |
