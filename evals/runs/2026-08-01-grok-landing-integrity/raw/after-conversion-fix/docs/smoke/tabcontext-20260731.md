# Landing smoke test: TabContext

## Contents

1. Hypothesis
2. Metrics and decision rules
3. Landing-page copy
4. Form and tracking
5. Implementation notes
6. Traffic plan
7. Explicit non-build scope
8. Post-test decision

| Field | Value |
|-------|--------|
| **Date** | 2026-07-31 |
| **Timebox** | 10 days (Day 0 setup → Day 10 decision) |
| **Product (working name)** | TabContext |
| **ICP** | Hands-on customer support / success agents at small US SaaS teams (roughly 5–50 people) who juggle many client accounts daily in Chrome |
| **Promise** | One-click restore of the client-specific tab workspace you need for the ticket in front of you |
| **CTA type** | Early-access waitlist — single CTA label: **Join the early-access waitlist** |
| **Price signal** | Planned price from **$9/month** (not charged during smoke; no firm ship date) |
| **Page language** | English |
| **Stack** | Cloudflare Pages + Buttondown + Plausible |
| **Ad budget cap** | **$150** total |
| **Honesty constraints** | No testimonials, no logos, no user counts, no firm ship date |

---

## 1. Hypothesis

If we offer **one-click restore of client-specific Chrome tab workspaces** to **hands-on support agents at small US SaaS teams**, via a single **early-access waitlist** CTA and a truthful planned price of **from $9/month**, then within **10 days**:

- **Cold / paid traffic** will convert at least **~2–3%** visitor → confirmed waitlist (source-specific; see below).
- **Warm outreach** (DMs, known peers) will convert at least **~10%** and produce **qualifying replies** (use case, willingness language).
- Across controlled channels we will collect enough **confirmed emails + intent signals** to decide build / rewrite / park — **without pooling warm and cold rates into one headline CVR**.

Traffic plan: X + Reddit + Indie Hackers + warm DMs + small Meta/Google Search ads (≤ $150).

---

## 2. Metrics & decision rules

### 2.1 Funnel definitions

| Metric | Definition | Source of truth |
|--------|------------|-----------------|
| **Landing view** | Unique pageview on the smoke landing URL | Plausible `pageview` |
| **CTA click** | Click on any primary CTA (“Join the early-access waitlist”) | Plausible custom event `click_cta` |
| **Waitlist attempt** | Form submit fired in browser (not a conversion) | Optional `attempt_waitlist` only for debugging |
| **Waitlist conversion** | Email accepted by Buttondown as a subscriber | **Buttondown confirmed subscriber record** |
| **Visitor → email CVR** | Confirmed subscribers / unique visitors **within the same traffic class** | Buttondown + Plausible + UTM/source tags |
| **Welcome open** | Open of Buttondown welcome email | Buttondown (diagnostic only) |
| **Intent signal** | Reply, DM, or form note with concrete use case, “I’d pay,” team size, or pain story | Manual log |
| **Cost per confirmed email (CPE)** | Ad spend / confirmed subscribers from paid sources only | Ads dashboard + Buttondown tag `ads` |

**Conversion integrity**

- Count a waitlist conversion **only** when Buttondown confirms the subscriber.
- Invalid, rejected, duplicate, or merely attempted submissions **do not** count.
- Do **not** fire a client-side `submit_waitlist` success event from the form `onsubmit` handler if the native cross-origin form cannot prove acceptance. Prefer Buttondown as source of truth; if using a success redirect URL you control, fire conversion only on that page after provider acceptance.

### 2.2 Traffic classes (never pool)

| Class | Includes | Exclude from class |
|-------|----------|--------------------|
| **Warm** | Personal DMs, known peers, founders you already talk to, warm Slack/Discord one-to-ones | Public posts, ads |
| **Community / social cold** | X public posts, Reddit, Indie Hackers (strangers) | Warm DMs, paid ads |
| **Paid cold** | Meta/Google ads with smoke UTMs | Everything unpaid |

**Rule:** Report three CVRs. Never average warm DMs with Reddit + ads into one “overall conversion rate” for a go/kill call.

### 2.3 Sample floors before strong conclusions

| Condition | Meaning |
|-----------|---------|
| **&lt; 50** unique visitors in a class | Rates unstable — collect more or treat as directional only |
| **≥ 80–100** cold unique visitors (community + paid combined is OK for *volume*, but still report separately) | Enough to discuss cold CVR directionally |
| **≥ 15–20** warm outreach sends with tracking | Enough to discuss warm response + CVR |
| Kill/reshape decisions prefer | **≥ 200** cold-ish unique visits **or** clear failure on CPE + zero intent after honest push |

### 2.4 Source-specific success thresholds (directional)

| Traffic class | Primary metric | Success (continue / build path) | Weak / kill-or-reshape signal |
|---------------|----------------|----------------------------------|-------------------------------|
| **Warm outreach** | Visitor→email **or** send→email; plus intent replies | ≥ **10%** of people who land from warm links join; **≥ 3** substantive replies in 10 days | &lt; 5% join **and** 0 use-case replies after 20+ genuine asks |
| **Community / social cold** | Visitor → confirmed email | **≥ 3–5%** CVR with some ICP-fit notes | Sustained **&lt; 1.5–2%** after 100+ visits and one hero rewrite |
| **Paid cold** | Visitor → email + CPE | **≥ 2–3%** CVR **and** CPE ≤ **~$8–12** (at $9/mo price signal, payback story still tight) | CPE **&gt; $20** with &lt; 2% CVR after ~$80 spend → pause that ad set |
| **All classes (intent)** | Replies / “I’d pay” language | **≥ 5** total intent signals, including **≥ 2** from non-warm sources preferred | Emails only, zero replies after welcome + 1 follow-up |

**Ad spend rule:** Cap **$150**. Kill any single creative/audience after **$40–50** if CTR is fine but landing CVR &lt; 1% or CPE is absurd. Do not “spend the rest to feel complete.”

### 2.5 Dashboard (spreadsheet is enough)

Columns per day:

`date | source_class | utm_source | unique_visitors | cta_clicks | confirmed_emails | cvr | ad_spend | cpe | intent_notes`

Separate tabs or filters: `warm` | `community` | `paid`.

### 2.6 Decision matrix (Day 10)

| Result | Next step |
|--------|-----------|
| **Strong** — cold CVR meets class thresholds **and** ≥ 5 intent signals (or clear paid-intent language) | Thin PRD (`z-write-prd`) + smallest Chrome MV3 prototype for **one** workspace restore job; interview waitlist |
| **Mixed A** — warm strong, cold weak | Offer/ICP may only work with trust; rewrite hero for colder language, retest **one** cold channel 5 more days; do **not** build full product on warm alone |
| **Mixed B** — cold CVR OK, **zero** engagement | Soft demand; run 5–8 waitlist interviews before code; may be free-tool curiosity |
| **Weak** — after sample floors, cold CVR under kill bars **and** no intent | Reshape ICP/promise (e.g. broader “tab groups for support”) or park; **do not** “add features” to fix indifference |
| **Distribution failure** — cannot get 50+ cold visits despite honest posts + ads | Fix reach/channels first; product thesis not yet tested |

---

## 3. Landing page copy (English)

### Meta

- **Title:** TabContext — One-click client tab workspaces for support agents  
- **Description:** Restore the exact Chrome tabs for each customer account when you open a ticket. Built for hands-on support agents at small SaaS teams. Early access from $9/month.  
- **OG title:** One-click client context for support agents  
- **OG description:** Stop rebuilding the same client tabs on every ticket. TabContext restores client-specific Chrome workspaces in one click. Join the early-access waitlist — planned from $9/month.  
- **OG image note:** Simple text card: product name + “One-click client tab restore” + “Early access · from $9/mo”. No fake UI polish claiming a live product.  
- **Twitter/X card:** summary_large_image; same OG title/description.

### Headline variants

1. **(Ship this)** One-click restore of the client workspace you need for the ticket in front of you  
2. Stop rebuilding the same client tabs every time a ticket lands  
3. Client-specific Chrome workspaces for hands-on support agents  

### Full page

#### Nav

- **Wordmark:** TabContext  
- **Button (only CTA):** Join the early-access waitlist  

#### Hero

**Eyebrow:** Chrome extension · for support agents at small SaaS teams  

**H1:** One-click restore of the client workspace you need for the ticket in front of you  

**Subhead:** Hands-on support agents juggle many customer accounts. TabContext saves each client’s tab set and restores it when you switch context—so you stop hunting dashboards, admin panels, and docs from scratch.  

**Price chip:** Planned pricing from **$9/month** · early access  

**Primary CTA:** Join the early-access waitlist  

**Honesty line:** We’re validating demand before we ship. No live product screenshots. No fake customer logos.  

**Optional micro-copy under form:** Work email preferred. We’ll only email about TabContext early access.  

#### Problem / status quo

**H2:** Context switching is the hidden tax on every ticket  

When a new ticket arrives, the browser still looks like the last customer:

- You re-open the same billing page, product admin, status tool, and internal runbook—again.  
- Tab groups and bookmarks help a little, then drift as each client’s stack changes.  
- You lose minutes (and composure) before you can even answer the customer.  

That friction compounds across a full queue of accounts.

#### Solution (how it works — 3 steps)

**H2:** How TabContext is meant to work  

1. **Save a workspace per client** — Capture the tabs you actually use for that account (billing, admin, docs, monitoring).  
2. **Name it for the ticket flow** — Match the client or account you support every day.  
3. **Restore in one click** — When the next ticket for that client lands, open the saved workspace instead of rebuilding it.  

No AI magic story. A focused Chrome extension for a job you already do by hand.

#### Who it’s for / not for

**H2:** Who this is for  

- Support, success, or onboarding folks who **live in Chrome** all day.  
- Small US SaaS teams where agents **touch many client accounts**, not one internal app only.  
- People who already try tab groups, profiles, or bookmark folders—and still feel the reset pain.

**H2:** Who this is not for  

- Teams that need a full contact-center suite or shared team inbox product.  
- People looking for a general “AI browser agent” or automatic ticket writer.  
- Anyone who rarely switches between customer environments.

#### Proof (honest)

**H2:** Where we are  

TabContext is **not shipped** yet. This page is a demand smoke test.

You’ll get:

- A short note when early access opens  
- Occasional product updates (easy unsubscribe)  
- Founding pricing aimed at **from $9/month** if we build it  

We are **not** showing testimonials, logo walls, or user counts we don’t have.

**Founder note (optional short block):**  
“I keep watching support teammates lose the first minutes of every ticket to browser setup. If that pain is real for you, the waitlist is the honest way to say so.”

#### Offer / CTA block

**H2:** Early access  

**Join the early-access waitlist** to hear when a first version is ready to try.

- Planned price: **from $9/month**  
- No charge today  
- No firm ship date — we won’t invent one  

**CTA:** Join the early-access waitlist  

**Form fields (see §4):** email (required), optional role/pain one-liner, hidden UTMs  

#### FAQ

**Is TabContext available today?**  
No. It’s unbuilt. This page tests whether support agents want one-click client workspace restore enough to join early access.

**When will it ship?**  
We don’t have a firm ship date. Waitlist members hear first when something is ready to try—not a calendar promise we can’t keep.

**How much will it cost?**  
Planned pricing starts at **from $9/month**. Final packaging may change after early-access feedback; we won’t bait-and-switch with a hidden enterprise-only trap on the marketing page.

**What data does a Chrome extension like this need?**  
A real build would need permission to manage tabs/sessions for workspaces you choose to save. We will publish a clear permission list before any install. This smoke test only collects your email (and optional note).

**How will you use my email?**  
To confirm you’re on the list, send early-access updates about TabContext, and occasionally ask a short product question. We won’t sell your email.

**Can my whole team join?**  
Yes—each person can join with their own email. We’re focused on small SaaS teams first, not call-center enterprise rollouts.

**What if I just want to give feedback without waiting for a product?**  
Join the list and reply to the welcome email with your workflow. Replies matter more than silent signups.

#### Final CTA

**H2:** Restore client context in one click—if we build it  

If rebuilding client tabs is a daily tax, say so with your email.

**CTA:** Join the early-access waitlist  

**Price reminder:** Planned from $9/month · no charge today · no firm ship date  

#### Footer

- TabContext · Built as an independent product experiment  
- Contact: `hello@yourdomain.com` (replace)  
- Privacy: Emails stored in Buttondown for TabContext updates only. No selling of the list.  
- Analytics: Privacy-friendly page analytics via Plausible (no ad-tracking pixels required for the smoke).  

---

## 4. Form & tracking

| Item | Spec |
|------|------|
| **Provider** | **Buttondown** (hosted form or API; prefer their form embed / form action for speed) |
| **Host** | **Cloudflare Pages** (static `index.html` + assets) |
| **Analytics** | **Plausible** (domain property + custom events) |
| **Fields** | **email** (required); **role_or_pain** (optional, short text: “Biggest daily browser friction?”); **utm_source**, **utm_medium**, **utm_campaign**, **utm_content**, **utm_term** (hidden, filled from URL); **traffic_class** (hidden: `warm` \| `community` \| `paid`, derived client-side from UTM rules) |
| **Consent** | Single clear line under form; no pre-checked extra marketing boxes. Prefer **double opt-in** if Buttondown/settings allow for list quality; otherwise single opt-in with honest footer—document which you chose. |
| **Success message** | “You’re on the early-access list. Check your inbox to confirm if we sent a verification email. We’ll only write about TabContext.” |
| **Error message** | “That email didn’t go through. Check the address and try again.” |
| **Successful-conversion source of truth** | **Buttondown confirmed subscriber** (tag by UTM/source). Do not count raw form posts. |
| **Events (Plausible)** | See below |
| **UTM scheme** | See below |

### 4.1 Plausible events

| Event name | When | Props (optional) |
|------------|------|------------------|
| `pageview` | Default | |
| `click_cta` | Any primary CTA click (nav, hero, mid, final) | `placement`: `nav` \| `hero` \| `offer` \| `final` |
| `attempt_waitlist` | Form submit handler runs (optional debug) | `placement` |
| **Do not** use client `submit_waitlist` as conversion unless success URL is under your control **after** Buttondown accepts | | |
| `outbound_success_view` | Optional: if you use a `/thanks` page only shown after confirmed redirect | |

**Weekly reconciliation:** Export Buttondown subscribers created in the window; join on tags/UTM notes; that number is **confirmed_emails**.

### 4.2 Buttondown tags / metadata

On subscribe, attach:

- `smoke_v1`
- `utm_source:*` (or store full UTM string in subscriber metadata)
- `class:warm` / `class:community` / `class:paid`

Welcome email subject options:

1. You’re on the TabContext early-access list  
2. Quick question: how do you switch client context today?  

Welcome body (short): thank them; restate promise; ask one reply question: *“When a ticket for a different client lands, what do you open first—and what do you wish was already open?”*; remind planned **from $9/month**; no ship date.

### 4.3 UTM scheme

Base: `https://tabcontext.pages.dev` (or custom domain)

Campaign constant: `utm_campaign=smoke_v1`

| Channel | Example URL |
|---------|-------------|
| X post 1 | `?utm_source=twitter&utm_medium=social&utm_campaign=smoke_v1&utm_content=thread_pain` |
| X post 2 | `?utm_source=twitter&utm_medium=social&utm_campaign=smoke_v1&utm_content=founder_note` |
| Reddit (r/CustomerSuccess) | `?utm_source=reddit&utm_medium=community&utm_campaign=smoke_v1&utm_content=r_customersuccess` |
| Reddit (r/saas) | `?utm_source=reddit&utm_medium=community&utm_campaign=smoke_v1&utm_content=r_saas` |
| Indie Hackers | `?utm_source=indiehackers&utm_medium=community&utm_campaign=smoke_v1&utm_content=milestone` |
| Warm DM | `?utm_source=warm_dm&utm_medium=dm&utm_campaign=smoke_v1&utm_content=personal` |
| Meta ads | `?utm_source=meta&utm_medium=cpc&utm_campaign=smoke_v1&utm_content=creative_a` |
| Google Search ads | `?utm_source=google&utm_medium=cpc&utm_campaign=smoke_v1&utm_content=search_support_tabs` |

**traffic_class mapping**

- `utm_medium=dm` or `utm_source=warm_dm` → `warm`  
- `utm_medium=cpc` → `paid`  
- else social/community sources → `community`  

---

## 5. Implementation notes

### Stack

| Layer | Choice |
|-------|--------|
| Host | **Cloudflare Pages** |
| Page | Single static page (`index.html`, optional `thanks.html`, `og.png`) |
| Email | **Buttondown** form action / embed |
| Analytics | **Plausible** script + custom events |
| Domain | `tabcontext.pages.dev` for speed, or map a domain you already own |
| Ads | Meta and/or Google — **$150 cap** total |

### Files to create (minimal)

```text
landing/
  index.html          # full page + form + Plausible
  thanks.html         # optional success page (only if provider can redirect after accept)
  og.png              # simple OG card
  privacy.html        # optional one-screen privacy note
```

No app scaffolding, no extension codebase, no auth, no Stripe checkout for this smoke (price is a **signal**, not a charge).

### Cloudflare Pages

1. Repo or direct upload of `landing/`.  
2. Build command: none (static).  
3. Output directory: `/` or `landing`.  
4. Add custom domain later if needed.  

### Buttondown

1. Create publication “TabContext”.  
2. Enable form subscriptions; copy form action / embed.  
3. Configure welcome email + tags.  
4. Confirm whether double opt-in is on; write that into the dashboard notes.  
5. Test: one valid email, one invalid email, one duplicate.  

### Plausible

1. Add site domain.  
2. Enable custom events (`click_cta`, optional `attempt_waitlist`).  
3. Goal: track `click_cta`; treat email conversion via Buttondown export.  
4. No need for full product analytics stack.

### Form behavior checklist

- [ ] Hidden UTMs populated from `URLSearchParams` on load  
- [ ] CTA clicks fire `click_cta` with placement  
- [ ] Success UI only after provider success path (or “check inbox to confirm”)  
- [ ] Mobile: one column, CTA visible without hunting  
- [ ] No fake logos, counters, or “trusted by”  

### Legal / trust minimum

- Footer privacy one-liner is enough for smoke; expand if you collect more than email.  
- Do not claim SOC2, “bank-grade,” or enterprise security for an unbuilt extension.

---

## 6. Traffic plan

### 6.1 10-day calendar

| Day | Channel | Action | UTM content | Notes |
|-----|---------|--------|-------------|-------|
| **0** | Setup | Ship page on Cloudflare Pages; wire Buttondown + Plausible; test form; create spreadsheet | — | No public traffic until events work |
| **1** | Warm | 10 personal DMs to support/CS people you know | `warm_dm` / `personal` | Ask for honest reaction + whether they’d join; **log as warm** |
| **1** | X | Pain-story post (not launch hype) | `thread_pain` | Soft CTA; engage every reply same day |
| **2** | Warm | 10 more DMs (different people) | `warm_dm` / `personal` | Still separate from cold metrics |
| **2** | Reddit | Value-first post in **one** buyer sub (e.g. r/CustomerSuccess) if rules allow | `r_customersuccess` | Disclose maker; no multi-sub spam |
| **3** | X | Founder-note / “building in public” post | `founder_note` | Pin landing link during smoke |
| **3** | Indie Hackers | Milestone: “smoke-testing a Chrome ext for support context switch” | `milestone` | Ask for critique of offer, not vanity upvotes |
| **4** | Reddit | Second community **only if** Day 2 stayed up (e.g. r/saas or r/custosuccess-adjacent) | `r_saas` | Different angle; don’t clone post |
| **4** | Ads start | Launch **one** ICP ad set, **$15–20/day**, geo US, English | `creative_a` | Cap daily so total ≤ $150 over remaining days |
| **5** | Ads | Review CTR, CPC, landing CVR; kill losers | — | If CVR &lt; 1% with 200+ clicks, rewrite **landing hero only** or pause |
| **5** | Warm follow-up | Nudge non-responders once (no guilt spam) | `warm_dm` | |
| **6** | X | Third post: “who this is not for” + CTA | `not_for` | Filters tire-kickers; improves reply quality |
| **6** | Ads | Optional creative_B **only if** A is near threshold but weak | `creative_b` | Don’t change audience + creative + headline all at once |
| **7** | Community | Reply-heavy day: answer every Reddit/IH/X comment; invite waitlist only when relevant | — | Engagement is part of the test |
| **8** | Ads | Final paid push or full stop if CPE already fails | — | Leave ~$20 contingency or stop early |
| **8** | Waitlist | Send Buttondown welcome if not automatic; start logging replies | — | Intent harvest |
| **9** | Light channels | One more X or IH update with **honest** early metrics (optional) | `metrics_note` | Builds trust; don’t fake numbers |
| **10** | Decision | Freeze traffic; reconcile Buttondown vs Plausible; apply §2.6 matrix | — | Write decision in spreadsheet |

**Budget sketch ($150 cap):**

| Bucket | Amount | Purpose |
|--------|--------|---------|
| Days 4–6 learning | ~$60–80 | Find if any creative/keywords convert |
| Days 7–8 scale or cut | ~$40–60 | Only if CPE acceptable |
| Reserve / stop early | ~$20–30 | Don’t force-spend |

Prefer **US** geo. Interest/keywords around customer support tools, SaaS support, Zendesk/Intercom-adjacent **roles** (not competitor trademark spam if policy-risky).

### 6.2 Channel posts (drafts)

#### X — Post 1 (pain)

Support agents: how many minutes do you lose reopening the *same* client tabs when a new ticket lands?

Billing. Admin. Status page. Runbook. Every. Single. Time.

I’m smoke-testing **TabContext** — a Chrome extension that restores a **client-specific tab workspace in one click**. Unbuilt. Early access planned from **$9/month**. No fake ship date.

If that pain is real, join the early-access waitlist: [link + UTM]

#### X — Post 2 (founder note)

I’m not launching a polished product. I’m testing whether hands-on support folks at small SaaS teams care enough to join a waitlist.

Promise: **one-click client context restore** in Chrome.  
Price signal: **from $9/month**.  
CTA: **Join the early-access waitlist**.

Page: [link + UTM]

Roast the offer if it’s wrong.

#### X — Post 3 (not for)

TabContext is **not** an AI support agent, not a shared inbox, not a tab manager for designers.

It’s for people who switch **customer environments** all day and hate rebuilding the browser for each account.

Early access waitlist: [link + UTM]

#### Reddit (outline — adapt to sub rules)

- **Title:** Support agents who juggle many SaaS customers — how do you handle per-client browser context?  
- **Body:** Describe the pain in their words; what you’ve tried (profiles, tab groups); what you’re testing (one-click restore extension); disclose you’re the maker; soft CTA to waitlist for early access; planned from $9/mo; **no** firm ship date; ask how they solve it today.  
- **Do:** Read rules; use feedback flair if required; reply to everyone.  
- **Don’t:** Multi-sub identical spam; “sign up now!!”; fake traction.

#### Indie Hackers (outline)

- Milestone: 10-day demand smoke for a Chrome extension for support agents.  
- Share hypothesis + single CTA + price signal.  
- Ask: is $9/mo credible for this job? Is ICP too narrow?  
- Link with IH UTM.  
- Commit to posting the decision outcome (strong/mixed/weak).

#### Warm DM (template)

Hey [Name] — you do hands-on support / CS, so I want a blunt take.

I’m testing **TabContext**: restore the Chrome tabs for each client in one click when a ticket lands. Not built yet. Early access waitlist, planned from **$9/month**.

If you have 2 minutes: does this problem exist for you, and would you join a waitlist?  
[warm UTM link]

No pressure either way — “no / not for me” is useful data.

#### Ads — primary message match

- **Primary text:** Support agents: restore each client’s Chrome tabs in one click. Early access from $9/month.  
- **Headline:** One-click client workspaces  
- **CTA button:** Sign up (platform default) → landing CTA remains **Join the early-access waitlist**  
- **Creative:** Text-led; problem → outcome; no fake product UI screenshots claiming live software  
- **Geo:** United States  
- **Exclude:** Interest mashups that are pure “Chrome extensions for everyone”

### 6.3 Channel quality notes

| Channel | Expected quality | Watch-outs |
|---------|------------------|------------|
| Warm DM | Highest intent, biased positive | Never pool with cold CVR |
| Reddit CS/SaaS | Good ICP if allowed | Removal risk; tone police |
| X | Mixed; good for iteration | Bots / curiosity clicks |
| IH | Builders, not always buyers | Feedback ≠ purchase intent |
| Paid | Scalable cold signal | Protect $150; kill fast |

---

## 7. What we will NOT build during the smoke

- Chrome extension MV3 codebase, tab serialization, sync, or sync backend  
- Auth, teams, SSO, admin dashboards  
- Stripe billing, free trials, or real $9 checkout (price is messaging only)  
- Fake demo video that implies a finished product  
- Multi-page marketing site, blog, or SEO program  
- Testimonial collection theater, logo kits, waitlist counters  
- Mobile apps, browser support beyond “Chrome-first” messaging  
- “AI that answers tickets” scope creep  

**Allowed engineering only:** static landing, form, analytics, OG image, spreadsheet.

---

## 8. After the smoke

| Outcome | Next step |
|---------|-----------|
| **Strong** | Interview 5–8 waitlist members → thin PRD (`z-write-prd`) → smallest extension that saves/restores **one** named workspace → paid early access experiment |
| **Mixed (warm only)** | Rewrite for cold traffic; 5 more days on **one** channel; optional `z-customer-discovery` interviews before code |
| **Mixed (CVR, no replies)** | Treat as soft demand; interviews first; do not staff a full build |
| **Weak** | Park or reshape ICP/promise; document learning; do **not** add features to an unvalidated wedge |
| **Channel failure** | Fix distribution; re-run smoke before product conclusions |

### Complementary skills (optional)

- Upstream language check: `z-market-validate`  
- Interview deep-dive after waitlist: `z-customer-discovery`  
- Only if strong: `z-write-prd`  
- SEO later: `z-seo-plan` (not the primary smoke traffic engine)

---

## Appendix A — Hero + form microcopy block (paste-ready)

```text
TabContext
Chrome extension · for support agents at small SaaS teams

One-click restore of the client workspace you need for the ticket in front of you

Hands-on support agents juggle many customer accounts. TabContext saves each
client’s tab set and restores it when you switch context—so you stop hunting
dashboards, admin panels, and docs from scratch.

Planned pricing from $9/month · early access

[ Join the early-access waitlist ]

We’re validating demand before we ship. No live product screenshots. No fake
customer logos.

Email: _______________
Optional: Biggest daily browser friction? _______________

Work email preferred. We’ll only email about TabContext early access.
```

## Appendix B — Daily operator checklist

- [ ] Plausible views by source  
- [ ] Buttondown new confirmed subscribers by tag/class  
- [ ] Ad spend cumulative ≤ $150  
- [ ] Replies logged as intent  
- [ ] No metric “overall CVR” used for kill decision without class split  
- [ ] Community posts answered  

## Appendix C — Quality bar self-check

- [x] Clear ICP + single promise (one-click client workspace restore)  
- [x] One primary CTA label  
- [x] Hypothesis + numeric success/kill + 10-day timebox  
- [x] Full English copy + meta/OG + 3 headlines  
- [x] Form/tracking/UTMs; conversion = provider-confirmed only  
- [x] Traffic calendar ≥ 3 channels + ads + warm  
- [x] Explicit non-build list  
- [x] Honest stage; no testimonials/logos/counts/firm ship date  
- [x] Decision matrix; warm never pooled with cold  
