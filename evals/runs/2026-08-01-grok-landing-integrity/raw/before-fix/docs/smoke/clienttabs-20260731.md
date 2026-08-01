# Landing smoke test: ClientTabs

**Working name:** ClientTabs  
**Tagline promise:** One-click restore of client-specific tab workspaces for hands-on support agents.

## Contents

1. Hypothesis  
2. Metrics and decision rules (source-specific; never pooled)  
3. Landing-page copy (English) + meta/OG + headline variants  
4. Form and tracking  
5. Implementation notes (Cloudflare Pages + Buttondown + Plausible)  
6. Traffic plan (10-day calendar, $150 ad cap)  
7. Explicit non-build scope  
8. Post-test decision  

| Field | Value |
|-------|--------|
| **Date** | 2026-07-31 |
| **Timebox** | 10 days (Day 0 setup → Day 10 decision) |
| **ICP** | Hands-on support / success agents at small US SaaS teams (≈5–50 person companies) who juggle many clients and rebuild browser context all day |
| **CTA type** | Early-access waitlist — single CTA label: **Join the early-access waitlist** |
| **Page language** | English |
| **Price signal** | Planned pricing **from $9/month** (truthful intent; product unbuilt; no firm ship date) |
| **Stack** | Cloudflare Pages (static) + Buttondown (email) + Plausible (analytics) |
| **Ad budget** | **$150 max** total paid for the full smoke |
| **Honesty rules** | No testimonials, no logos, no user counts, no firm ship date |

---

## 1. Hypothesis

If we offer **one-click restore of client-specific Chrome tab workspaces** to **hands-on support agents at small US SaaS teams** via an **early-access waitlist** with a **from $9/month** price signal, then within **10 days**:

| Traffic class | Primary metric | Success threshold (pre-registered) |
|---------------|----------------|-------------------------------------|
| **Warm outreach** (personal DMs / known operators) | Visitor → waitlist CVR | ≥ **12%** on ≥ 40 qualified visits **or** ≥ **8** emails with ≥ **3** thoughtful replies |
| **Cold organic** (Reddit, niche communities, Indie Hackers, X public) | Visitor → waitlist CVR | ≥ **3.5%** on ≥ 150 qualified visits **and** ≥ **6** emails |
| **Cold paid** (ads only) | Visitor → waitlist CVR **and** cost per email | ≥ **2%** CVR **and** ≤ **$8** cost per email on ≥ 80 paid landings |

**Secondary hypothesis:** At least **4** waitlist replies (across any source, tagged by source) will describe a real multi-client context-switch pain in their own words (not “cool idea”).

**Non-hypothesis:** Viral traffic or brand awareness. This test answers: *Will the right people leave email for this job-to-be-done before we build the extension?*

### Assumptions (explicit)

- Product is **unbuilt**; page discloses that honestly.  
- Chrome extension is the intended form factor (not a full multi-browser suite).  
- “Small US SaaS” = support/success people who live in Chrome + helpdesk (Intercom/Zendesk/etc.), not enterprise IT admins.  
- Founder has time to **reply within 24h** to every waitlist email and community comment during the window.

---

## 2. Metrics & decision rules

### 2.1 Funnel definitions

| Metric | Definition |
|--------|------------|
| **Landing view** | Plausible unique pageview on `/` (or landing path), filtered by UTM when analyzing sources |
| **CTA click** | Plausible custom event `click_cta` (hero + final CTA share one event name; optional `props.placement`) |
| **Waitlist submit** | Successful Buttondown subscription + Plausible `submit_waitlist` |
| **Visitor → email CVR** | Waitlist submits ÷ unique visitors **for that source class only** |
| **CTA → submit** | Waitlist submits ÷ CTA clicks (friction diagnostic) |
| **Welcome open** | Buttondown open rate on welcome email (diagnostic only; not a kill metric) |
| **Qualified reply** | Reply (to welcome or follow-up) that names a real workflow / pain / willingness |
| **“I’d pay” signal** | Explicit pay language, company size fit, or “invoice my team” without being prompted to hype |

### 2.2 Never pool warm + cold

Track **three separate scorecards** in a sheet:

1. `warm` — `utm_medium=dm` or `utm_source` in `{linkedin_dm, email_dm, twitter_dm, friend}`  
2. `cold_organic` — Reddit, IH, X public, Discord/Slack (permissioned), founder posts  
3. `cold_paid` — `utm_medium=cpc` only  

**Forbidden:** one blended “overall CVR” as the success headline. You may show a total email count for ops, but **all go/no-go rules use class-specific rates and minimum samples**.

### 2.3 Source-specific thresholds

| Class | Min sample before decision | Success | Weak / rewrite | Kill / park (this wedge) |
|-------|----------------------------|---------|----------------|---------------------------|
| **Warm** | ≥ 40 visits **or** 20 personal asks completed | CVR ≥ 12% **or** ≥ 8 emails + ≥ 3 qualified replies | CVR 6–12% with polite but shallow replies | &lt; 6% CVR after 40+ visits **and** &lt; 2 qualified replies after follow-up |
| **Cold organic** | ≥ 150 visits **and** ≥ 2 channels tried | CVR ≥ 3.5% **and** ≥ 6 emails | CVR 1.5–3.5% with some pain language in comments | CVR &lt; 1.5% after 200+ visits across 2 hero variants **or** &lt; 3 emails after full organic push |
| **Cold paid** | ≥ 80 paid landings **or** $150 spent | CVR ≥ 2% **and** CPE ≤ $8 | CVR 1–2% **or** CPE $8–15 | CPE &gt; $15 with CVR &lt; 1% after $80 spent → **stop ads**; do not raise budget |

**Ad hard stop:** never exceed **$150** total. Kill losing creative/audience after **48h** or **$40** spent (whichever first) if CTR or on-page CVR is hopeless.

### 2.4 Email engagement (diagnostic)

| Signal | How to read |
|--------|-------------|
| Welcome open rate | Compare to *your* Buttondown baseline; low opens → deliverability/subject first |
| Reply rate | ≥ 10% of waitlist replying with use-case language = strong soft demand |
| Zero replies after 2 touches | Interview 5 signups before building; demand may be curiosity-only |

### 2.5 Decision matrix (Day 10)

| Outcome | Criteria (class-aware) | Next step |
|---------|------------------------|-----------|
| **Strong** | Warm success **and** (cold organic success **or** cold paid success); ≥ 4 qualified pain replies total | Thin MVP Chrome extension (one job: save/restore named client workspace). Optional `z-write-prd`. Start 5–8 customer interviews from waitlist. |
| **Mixed — offer problem** | Warm OK, cold CVR weak | Rewrite hero/problem language from reply phrases; retest cold only 5–7 days; **do not** start full product build |
| **Mixed — distribution problem** | Strong replies from tiny traffic, cannot hit sample sizes | Keep page; change channels (buyer communities, partner newsletters); delay build |
| **Soft demand** | OK CVR, **zero** qualified replies after follow-up | 8 Mom-Test interviews (`z-customer-discovery`); no feature build |
| **Weak** | Cold organic kill **and** warm weak/kill; paid not worth continuing | Park or reshape ICP (e.g. agencies vs SaaS support); **do not** “add AI features” to save it |
| **Paid intent spike** | Any credible “we’d pay / invoice us” from ICP | Prioritize paid slice design; confirm price with 3 conversations before coding everything |

---

## 3. Landing page copy (English)

### Meta

- **Title:** ClientTabs — One-click client tab workspaces for support agents  
- **Description:** Restore every client’s tabs in one click. Built for hands-on support agents at small SaaS teams. Join the early-access waitlist. Planned pricing from $9/month.  
- **OG title:** One-click client context for support agents  
- **OG description:** Stop rebuilding the same tabs for every ticket. ClientTabs is a Chrome extension (in development) that restores client-specific workspaces in one click. Join the early-access waitlist — planned pricing from $9/month.  
- **OG line (short share):** One click to restore a client’s full tab workspace. For support agents who live in Chrome.  
- **Twitter/X card:** summary_large_image (image: simple text graphic — product name + promise; no fake UI chrome that implies a shipped product)

### Headline variants

1. **(Ship this)** One click to restore every client’s tab workspace  
2. Stop rebuilding the same 12 tabs for every support ticket  
3. Client-specific Chrome workspaces for hands-on SaaS support agents  

### Full page

#### Nav

- **Left:** ClientTabs  
- **Right:** button → **Join the early-access waitlist** (anchor `#waitlist`)

#### Hero

**Eyebrow:** Chrome extension · In development  

**H1:** One click to restore every client’s tab workspace  

**Subhead:** For hands-on support agents at small US SaaS teams who juggle dozens of clients a day. Save a named workspace per client—docs, admin, billing, status page—and restore the whole set when the next ticket hits.  

**Price chip:** Planned pricing from **$9/month**  

**Primary CTA:** **Join the early-access waitlist**  

**Honesty line:** We’re validating demand with an early-access list before we ship. No firm launch date yet—you’ll get product updates by email, unsubscribe anytime.

**Optional micro-line under CTA:** Takes ~20 seconds. Work email preferred.

#### Problem / status quo

**H2:** Context-switching is eating your queue time  

Every new ticket is a scavenger hunt: reopen the customer’s admin, their status page, last invoice, internal runbook, and three “where did I put that?” tabs. Multiply by a full day of hands-on support.

- You rebuild the **same browser setup** for the same accounts, all week.  
- Wrong-tab mistakes and half-loaded context make you look slower than you are.  
- Bookmarks and “pin these tabs” are blunt tools—they don’t switch with the **client** in front of you.

#### Solution (3 steps)

**H2:** How ClientTabs is meant to work  

1. **Save a client workspace** — Name it after the account; capture the tab set you actually use for them.  
2. **Open from the next ticket** — When that client appears in your queue, restore their workspace in one click.  
3. **Stay in flow** — Jump clients without rebuilding Chrome by hand between conversations.

No feature laundry list. One job: **client-shaped context, restored fast.**

#### Who it’s for / not for

**H2:** Who this is for  

- Hands-on **support, success, or onboarding** folks at small SaaS companies  
- People who live in **Chrome** and rotate through many customer contexts daily  
- Teams that can’t afford slow “where’s that admin again?” moments on every ticket  

**Not for (please don’t join just to collect tools):**  

- People who want a full enterprise “digital adoption” platform  
- One-site power users who never switch accounts  
- Teams that need multi-browser / locked-down managed-browser programs first (out of scope for v1 thinking)

#### Proof (honest)

**H2:** Where we are  

ClientTabs is **not shipped yet**. There are no customer logos, no user counts, and no testimonials on this page—on purpose.  

This early-access list is how we decide whether to build the first real version for agents like you. If you join, expect a short welcome email and occasional product notes—not spam.

**Founder note (optional short block):**  
I’m building this for support people who lose minutes—and confidence—every time the browser doesn’t match the ticket. If that pain is real for you, I want to hear how you work today.

#### Offer / CTA block

**H2:** Early access  

**Join the early-access waitlist** to:

- Be first in line when a usable build is ready for founding users  
- Help shape the workflow (save / restore / naming) around real support days  
- Lock in **founding pricing awareness**: planned public pricing **from $9/month** (final details shared before any charge)

**Form label:** Work email  
**Optional field:** Biggest daily friction when switching clients? (1–2 sentences)  
**CTA button:** **Join the early-access waitlist**  

#### FAQ

**Is ClientTabs available today?**  
No. It’s in development. This page is a demand smoke test with an early-access waitlist.

**When will it ship?**  
We don’t have a firm ship date. Waitlist members get updates as milestones land. We won’t invent a calendar to look more ready than we are.

**How much will it cost?**  
Planned pricing is **from $9/month**. If that changes, early-access members hear first—before any payment is taken.

**Why a Chrome extension?**  
Support agents already live in the browser. The job is restoring tab context where the work happens—not another dashboard to ignore.

**Will you sell or share my email?**  
No. Email is stored with our email provider (Buttondown) to send waitlist and product updates. Unsubscribe anytime. See the privacy note in the footer.

**What happens after I join?**  
You’ll get a short welcome message. We may ask one or two questions about your workflow. No obligation to buy.

**Is this for agencies or only SaaS product support?**  
The first wedge is **in-house support/success at small SaaS**. Agencies with many clients may fit later; tell us your context in the optional form field.

#### Final CTA

**H2:** Restore client context without rebuilding Chrome  

**Sub:** Early access for hands-on support agents. Planned pricing from $9/month.  

**CTA:** **Join the early-access waitlist**  

#### Footer

- ClientTabs · Built for support agents who live in Chrome  
- Contact: `hello@YOURDOMAIN.com` (replace)  
- Privacy: We use your email only for ClientTabs waitlist and product updates. No selling lists.  
- Analytics: Privacy-friendly analytics (Plausible).  
- © 2026 ClientTabs  

---

### Microcopy bank

| Element | Copy |
|---------|------|
| Success state title | You’re on the early-access list |
| Success state body | Check your inbox for a short welcome note. If you told us your biggest friction, we’ll read it—replies help us build the right first version. |
| Error state | Something went wrong submitting. Try again, or email hello@YOURDOMAIN.com. |
| Email field placeholder | you@company.com |
| Optional field placeholder | e.g. “I reopen the same 8 tabs every time Acme writes in” |
| Button loading | Joining… |

---

## 4. Form & tracking

| Item | Spec |
|------|------|
| **Provider** | Buttondown (embedded form or POST to Buttondown API / form endpoint) |
| **Fields** | `email` (required); `tag` or notes: optional `friction` (biggest daily friction); hidden: `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `utm_term` (from query string at load) |
| **CTA label (only)** | Join the early-access waitlist |
| **Consent** | Single opt-in OK for this US-leaning smoke if Buttondown + your deliverability setup allow; include clear purpose line under the form. Use double opt-in if you already prefer it for list quality—state it on the success screen (“Confirm the email we just sent”). |
| **Success message** | See microcopy bank above |
| **Welcome email** | Send immediately via Buttondown automation (draft in §5.4) |

### Events (Plausible custom events)

| Event name | When | Props (optional) |
|------------|------|------------------|
| `pageview` | Default Plausible | UTM as standard referrer/UTM |
| `click_cta` | Any primary CTA click | `placement`: `nav` \| `hero` \| `offer` \| `final` |
| `submit_waitlist` | Successful form submit only | `has_friction_answer`: true/false |
| `submit_waitlist_error` | Failed submit | `reason` if known |

**Goal in Plausible:** `submit_waitlist` as primary conversion goal.

### UTM scheme

Base: `https://YOURDOMAIN.com/` (or Pages preview URL during test)

```text
utm_campaign=clienttabs_smoke_v1
utm_source  = channel identifier
utm_medium  = dm | social | community | cpc | email
utm_content = optional post/creative id
utm_term    = optional audience or keyword (ads)
```

| Channel | Example URL query |
|---------|-------------------|
| Warm LinkedIn DM | `?utm_source=linkedin_dm&utm_medium=dm&utm_campaign=clienttabs_smoke_v1&utm_content=batch1` |
| Warm email | `?utm_source=email_dm&utm_medium=dm&utm_campaign=clienttabs_smoke_v1` |
| X public post | `?utm_source=twitter&utm_medium=social&utm_campaign=clienttabs_smoke_v1&utm_content=thread1` |
| Reddit r/saas | `?utm_source=reddit&utm_medium=community&utm_campaign=clienttabs_smoke_v1&utm_content=r_saas` |
| Indie Hackers | `?utm_source=indiehackers&utm_medium=community&utm_campaign=clienttabs_smoke_v1` |
| Support-focused Slack/Discord (if allowed) | `?utm_source=slack&utm_medium=community&utm_campaign=clienttabs_smoke_v1&utm_content=WORKSPACE` |
| Google/Meta/Reddit ads | `?utm_source=google\|meta\|reddit_ads&utm_medium=cpc&utm_campaign=clienttabs_smoke_v1&utm_content=CREATIVE&utm_term=AUDIENCE` |

**Spreadsheet columns (required):** date, source_class (`warm` / `cold_organic` / `cold_paid`), utm_source, visits, cta_clicks, emails, CVR, spend, CPE, notes/replies.

---

## 5. Implementation notes

### 5.1 Stack

| Layer | Choice | Notes |
|-------|--------|------|
| Host | **Cloudflare Pages** | Static `landing/` or repo root `index.html`; custom domain optional for smoke |
| Email | **Buttondown** | Waitlist + welcome sequence; tag subscribers `smoke_v1` + source tag if available |
| Analytics | **Plausible** | Enable custom events; respect privacy copy in footer |
| Form | Buttondown native form embed **or** minimal HTML form POSTing to Buttondown | Prefer no custom backend |
| Ads | One platform you can run same day (Reddit Ads or Meta or Google) | **$150 cap** |

### 5.2 Files to create

```text
landing/
  index.html          # single-page smoke landing
  og.png              # optional 1200×630 text graphic
  _headers            # optional security/cache headers for Pages
docs/smoke/
  clienttabs-20260731.md   # this pack
  metrics-sheet.csv        # optional empty template
```

Repo also includes a deployable `landing/index.html` stub aligned to this copy.

### 5.3 Cloudflare Pages setup (checklist)

1. Create Pages project → deploy `landing` directory (or connect git).  
2. Set custom domain **or** use `*.pages.dev` for the 10-day test.  
3. Add Plausible snippet domain allowlist for that host.  
4. Smoke-check: load page, click CTA, submit test email, verify Plausible events (use Plausible debug or network tab).  
5. Remove test subscriber from Buttondown or tag `test`.

### 5.4 Buttondown welcome email (draft)

**Subject:** You’re on ClientTabs early access  

**Body:**

```text
Thanks for joining the ClientTabs early-access list.

Quick reminder of the promise: one-click restore of client-specific tab
workspaces for hands-on support agents—so you stop rebuilding the same
tabs for every ticket.

Planned pricing: from $9/month. No firm ship date yet; you’ll hear when
there’s something real to try.

Reply to this email with one line if you want:
What’s the most annoying part of switching clients in Chrome today?

— [Founder name]
ClientTabs
```

**Day 4 follow-up (only non-openers or non-repliers, one send):**

**Subject:** One question about your support browser setup  

Keep to 3–4 sentences; same reply ask. Do not pitch features.

### 5.5 Plausible snippet pattern

```html
<script defer data-domain="YOURDOMAIN.com" src="https://plausible.io/js/script.tagged-events.js"></script>
<script>
  window.plausible = window.plausible || function() { (window.plausible.q = window.plausible.q || []).push(arguments) }
</script>
```

CTA buttons: `class="plausible-event-name=click_cta plausible-event-placement=hero"` (or JS `plausible('click_cta', { props: { placement: 'hero' } })`).

On successful subscribe: `plausible('submit_waitlist', { props: { has_friction_answer: 'true' } })`.

### 5.6 Privacy one-liner (page + footer)

Email stored in Buttondown for ClientTabs waitlist/product updates only. Analytics via Plausible (privacy-friendly, no ad-profile resale story). No fake counters.

### 5.7 Pre-order processor

None. Waitlist only—no Stripe for this smoke.

---

## 6. Traffic plan (10 days, $150 ad cap)

### Principles

1. **Warm first, then cold organic, then paid**—so you learn messaging before spending.  
2. **Never blend** warm and cold when reading CVR.  
3. **Max 1 major variable change at a time** (e.g. headline swap on Day 6 only if cold CVR weak).  
4. **No Product Hunt** required (unbuilt extension; PH optional later when demoable).  
5. **Disclose founder** on Reddit/IH; follow sub rules.  

### 6.1 Day-by-day calendar

| Day | Focus | Actions | UTM / source_class | Budget |
|-----|--------|---------|-------------------|--------|
| **0** | Setup | Deploy Pages; Buttondown form live; Plausible goals; test submit; spreadsheet ready; finalize domain in all links | — | $0 |
| **1** | Warm only | 15 personal DMs/emails to ideal ICP (support leads/agents you can name). Genuine ask: “Does this pain exist for you? 20-sec waitlist if yes.” | `utm_medium=dm` → **warm** | $0 |
| **2** | Warm + X | 10 more DMs. Public X post #1: problem story (no hype). Pin link. | dm + `twitter` social → split classes | $0 |
| **3** | Cold organic | Reddit post #1 in **one** buyer-adjacent sub (see drafts). Engage every comment same day. | `reddit` community → **cold_organic** | $0 |
| **4** | Organic + email | Indie Hackers milestone: “smoke-testing a Chrome workspace idea for support agents.” Buttondown follow-up #1 to non-repliers. | `indiehackers` → cold_organic | $0 |
| **5** | Organic amplify | X thread #2 (3 steps of intended product). Optional: 1 niche Slack/Discord **with permission**. 5 more warm DMs if list remains. | social/community/dm tagged correctly | $0 |
| **6** | Midpoint read | Scorecard freeze noon: warm vs cold_organic only. If cold CVR &lt; 1.5% with ≥ 80 visits → ship **headline variant 2**, keep channels. **Do not** change ads and headline same day. | — | $0 |
| **7** | Paid start | Launch **one** ad set: US, English, job/interest proxies for SaaS support/CS; one creative = hero promise; landing match. Cap **$30/day**. | `cpc` → **cold_paid** | ≤ $30 |
| **8** | Paid optimize | Kill creative if CTR or CVR hopeless. Shift remaining budget to winner only. Reddit post #2 **only if** different sub and value-first (not duplicate spam). | cpc + optional community | ≤ $40 |
| **9** | Fill gaps | Reply-heavy day: every waitlist unanswered thread; 5 final warm asks. Ads continue only if CPE on track. | all classes separate | ≤ $40 |
| **10** | Decision | Stop ads. Export Plausible + Buttondown. Fill decision matrix. Write 1-page outcome note. | — | ≤ $40 leftover only if still learning; else $0 |

**Ad math guardrail:** $150 total → e.g. $30+$40+$40+$40 or stop earlier. Prefer **stopping early** over forced spend.

### 6.2 Channel do / don’t

| Channel | Do | Don’t |
|---------|----|-------|
| Warm DM | Personal, short, ask for truth (“is this real?”) | Mass identical blasts; pooling into cold CVR |
| X | Pain story, build-in-public, reply to CS/support folks | Engagement-pod spam; fake “launching today” |
| Reddit | One sub at a time; founder disclosure; feedback framing | Cross-post identical text to 5 subs in an hour |
| IH | Honest smoke-test framing; share learnings later | Fake traction metrics |
| Ads | One ICP, one message, US geo, $150 cap | Broad “everyone who uses Chrome”; retargeting rabbit holes |
| Slack/Discord | Ask mods; contribute first | Drive-by invite links |

### 6.3 Post drafts

#### Warm DM (LinkedIn / email)

```text
Subject (email): Quick question about client context in Chrome

Hey {Name} — you work hands-on support at a small SaaS team, so I wanted a
reality check (not a pitch deck).

I'm testing whether agents would use a Chrome extension that restores a
saved tab workspace per client in one click—so you don't rebuild admin +
docs + status tabs on every ticket. Planned price from $9/mo if it exists.
Nothing shipped yet.

If that pain is real for you, would you glance at this and join the
early-access waitlist (or reply "not a problem for us")?

{link with utm_medium=dm}
```

#### X / Twitter — Post 1 (Day 2)

```text
Support agents at small SaaS teams: how many tabs do you rebuild every
time a different customer writes in?

I'm smoke-testing ClientTabs — a Chrome extension (not built yet) for
one-click restore of client-specific workspaces.

Early-access waitlist, planned pricing from $9/mo. No fake logos, no
fake ship date.

{link utm_source=twitter&utm_medium=social&utm_campaign=clienttabs_smoke_v1&utm_content=post1}
```

#### X — Thread 2 (Day 5)

```text
1/ The job isn't "more bookmarks."
It's: this ticket is Acme → I need Acme's world in Chrome now.

2/ Intended flow:
Save workspace by client name → restore in one click on the next ticket.

3/ Building only if support agents actually want it.
Waitlist (from $9/mo planned): {link ...&utm_content=thread2}
```

#### Reddit (Day 3) — outline

- **Sub candidates (pick one after reading rules):** r/SaaS, r/CustomerSuccess, r/zendesk, r/intercom, r/supportal (verify activity/rules). Prefer **feedback** framing.  
- **Title:** `[Feedback] Would you use a Chrome extension that restores a full tab set per customer?`  
- **Body structure:**  
  1. Who you are (founder)  
  2. Problem in operator language  
  3. Proposed one-click restore  
  4. Stage honesty: unbuilt, waitlist, from $9/mo planned  
  5. Soft link once  
  6. Ask: How do you handle client context today?  
- **Don’t:** “Check out my startup” energy; multi-sub dump.

#### Indie Hackers (Day 4)

```text
Title: Smoke-testing a $9/mo Chrome extension for SaaS support agents

Body: Sharing a 10-day demand test before writing the extension.
Promise: one-click client tab workspace restore.
Stack for the test: Cloudflare Pages + Buttondown + Plausible.
I'll post conversion by traffic class (warm vs cold) at the end—not a
blended vanity rate.

Link: {ih UTM}
Critique welcome: ICP too narrow? Price signal wrong?
```

### 6.4 Ad creative (paid days 7–9)

**Primary text:**  
Stop rebuilding the same tabs for every support ticket. ClientTabs restores a client’s Chrome workspace in one click. Early access — planned pricing from $9/month.

**Headline:** One-click client tab workspaces  
**CTA button (ad platform):** Learn more → landing CTA remains **Join the early-access waitlist**  
**Geo:** United States  
**Audience sketch:** Small business / SaaS interests + job titles Customer Support, Customer Success, Support Specialist (platform-dependent)  
**Kill rule:** After $40 or 48h, if landing CVR &lt; 1% or CPE projected &gt; $15 → pause, rewrite ad to match variant-2 headline, or stop paid entirely.

---

## 7. What we will NOT build during the smoke

- The Chrome extension itself (background scripts, sync, workspace storage)  
- Accounts, teams, SSO, admin dashboards  
- Multi-browser support  
- AI “auto-detect client from ticket”  
- Mobile apps  
- Complex design system / brand book  
- Fake demo videos that imply a shipped product  
- Testimonial collection UI, logo walls, live user counters  
- Custom backend beyond Pages + Buttondown + Plausible  
- Raising ad spend above **$150** to “make the graph look better”

---

## 8. After the smoke

| Outcome | Next step |
|---------|-----------|
| **Strong** | `z-write-prd` for thin MVP (save/list/restore workspace only). Schedule 5 interviews from waitlist. Build vertical slice in Chrome. |
| **Mixed (copy)** | Rewrite hero with *their* phrases; 7-day cold retest; still no full build |
| **Mixed (channels)** | Keep offer; try partner newsletters / CS communities; delay engineering |
| **Soft demand** | `z-customer-discovery` on waitlist; reassess wedge |
| **Weak** | Park ClientTabs wedge or change ICP; document learning; do not feature-sprint |
| **Upstream research** | If language feels wrong on Day 3 already, run `z-market-validate` in parallel—but **do not** stop the clock without a reason |

### Definition of done for *this package*

Founder can:

1. Publish the English page on Cloudflare Pages within a day  
2. Capture email via Buttondown with UTMs and Plausible events  
3. Execute the 10-day calendar within a **$150** ad cap  
4. Decide Day 10 using **source-specific** thresholds—**never** a pooled warm+cold CVR  

---

## Appendix A — Metrics sheet template (columns)

```text
date, source_class, utm_source, utm_medium, utm_content, visits, cta_clicks, emails, cvr_pct, spend_usd, cpe_usd, qualified_replies, notes
```

Example rows:

```text
2026-08-01, warm, linkedin_dm, dm, batch1, 12, 8, 3, 25.0, 0, , 1, "two replied with ticket workflow"
2026-08-03, cold_organic, reddit, community, r_saas, 90, 20, 3, 3.33, 0, , 1, "mod approved, good comments"
2026-08-07, cold_paid, meta, cpc, creative_a, 45, 6, 1, 2.22, 28, 28, 0, "pause if CPE stays high"
```

## Appendix B — Headline A/B rule

- **Days 1–5:** Headline variant 1 only.  
- **Day 6+:** Switch to variant 2 **only if** cold_organic CVR &lt; 1.5% with ≥ 80 cold visits.  
- Never run two heroes on two ad creatives simultaneously without tagging `utm_content` and reading them separately.

## Appendix C — Quality bar self-check

- [x] Clear ICP + single promise (one-click client workspace restore)  
- [x] One primary CTA: **Join the early-access waitlist**  
- [x] Hypothesis + numeric success/kill + 10-day timebox  
- [x] Full English copy + meta/OG + 3 headlines  
- [x] Form/events/UTM specified (Buttondown + Plausible)  
- [x] Traffic plan ≥ 3 channels + calendar + $150 cap  
- [x] Source-specific thresholds; warm never pooled with cold  
- [x] No testimonials, logos, user counts, firm ship date  
- [x] Explicit non-build list + decision matrix  
