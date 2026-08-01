# Landing smoke test: ClientTabs

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
| **Date** | 2026-08-01 |
| **Timebox** | 10 days (Day 0 setup → Day 9 decision) |
| **Product** | ClientTabs — Chrome extension (unbuilt) |
| **ICP** | Hands-on support / customer-success agents at small US SaaS teams (≈5–50 people) who juggle multiple client accounts in the browser every day |
| **Promise** | One-click restore of client-specific tab workspaces |
| **CTA type** | Early-access waitlist (single CTA only) |
| **CTA label** | Join the early-access waitlist |
| **Price signal** | Planned from $9/month (not live billing) |
| **Page language** | English |
| **Stack** | Cloudflare Pages + Buttondown + Plausible |
| **Ad budget** | Hard cap **$150** total (no reallocation after kill) |
| **Forbidden claims** | No testimonials, no logos, no user counts, no firm ship date |

---

## 1. Hypothesis

If we offer **one-click restore of client-specific tab workspaces** to **hands-on support agents at small US SaaS teams** via an **early-access waitlist** at a **planned from $9/month** price signal, then:

1. **Cold controlled traffic** (ads + public posts, excluding warm DMs) will convert at **≥ 3% visitor → confirmed email** after **≥ 150 cold qualified visits**, **and**
2. We will collect **≥ 8 source-separated confirmed emails from cold classes** **or** **≥ 3 reply-quality intent signals** (“I’d use this”, “we pay for tools like…”, concrete client/tab pain) within **10 days**,

under the traffic plan below.

**Secondary hypothesis:** Warm outreach will convert higher than cold — but warm results **must never be pooled** with cold rates for a go/kill decision on product demand. Warm proves message clarity with known people; cold proves whether strangers care.

---

## 2. Metrics & decision rules

### 2.1 Funnel definitions

| Metric | Definition | Source of truth |
|--------|------------|-----------------|
| **Landing view** | Unique visitors to the smoke URL (Plausible unique visitors, filtered to campaign period) | Plausible |
| **CTA click** | Click on any element labeled “Join the early-access waitlist” (hero, sticky, final) | Plausible custom event `click_cta` |
| **Waitlist attempt** | Form submit handler fired (not a conversion) | Optional Plausible `attempt_waitlist` only |
| **Confirmed email** | Buttondown accepted subscriber (valid email; not rejected/bounce-on-add) | **Buttondown subscriber list** |
| **Visitor → email CVR** | Confirmed emails ÷ unique landing views **for that traffic class only** | Spreadsheet: Buttondown + Plausible by UTM |
| **Welcome open** | Open on the Buttondown welcome email (diagnostic only; privacy noise) | Buttondown |
| **Intent signal** | Reply to welcome, form “biggest pain” field with concrete client/tab language, or DM saying they would pay / trial | Manual log |
| **Cost per confirmed email (CPE)** | Ad spend ÷ confirmed emails attributed to ads UTM | Ads + spreadsheet |

**Conversion integrity (non-negotiable):**

- Count **confirmed emails only** after Buttondown accepts the subscriber.
- Invalid, rejected, duplicate, or merely attempted submissions **do not** count as conversions.
- Native cross-origin Buttondown form has **no reliable client success callback** → do **not** fire `submit_waitlist` from the submit handler.
- Use Buttondown as conversion SoT; optionally fire `attempt_waitlist` on submit for funnel friction diagnosis only.

### 2.2 Traffic classes (never pool)

Track **separately**. Never average warm + cold into one headline CVR.

| Class | UTM / source pattern | What it measures |
|-------|----------------------|------------------|
| **WARM** | `utm_source=dm` / `utm_source=warm` / personal email | Message + offer clarity among people who know you |
| **COLD_SOCIAL** | `utm_source=x`, `reddit`, `indiehackers`, niche Slack/Discord (public) | Organic stranger interest |
| **COLD_ADS** | `utm_source=google` / `meta` / `linkedin` + `utm_medium=cpc` or `paid` | Paid stranger interest under $150 cap |
| **OTHER / DIRECT** | empty UTM, bookmarks | Noise — report but do not use as primary signal |

### 2.3 Source-specific thresholds

Directional only; all require **minimum sample** before a kill decision.

| Class | Min sample before decision | Success CVR (visitor → confirmed email) | Weak / reshape | Kill class early |
|-------|----------------------------|------------------------------------------|----------------|------------------|
| **WARM** | ≥ 20 page opens from warm links **or** ≥ 25 DMs sent | ≥ 15% CVR **or** ≥ 5 confirmed + ≥ 2 intent replies | 5–14% with thin replies | Not a product kill — only “warm network is weak/misfit” |
| **COLD_SOCIAL** | ≥ 80 unique visits with social UTMs | ≥ 4% CVR **and** ≥ 5 confirmed | 2–3.9% → rewrite hero once | After ≥ 80 visits and **&lt; 2%** CVR with ≥ 2 post variants → stop that subreddit/angle |
| **COLD_ADS** | ≥ 70 unique visits from paid **or** $80 spent | ≥ 2.5% CVR **and** CPE ≤ $12 | CPE $12–25 with CVR 1.5–2.4% → tighten creative/ICP only once | After $80 **or** 70 visits: CVR &lt; 1.5% **or** CPE &gt; $25 → kill ads for rest of test |
| **Overall cold (social+ads, no warm)** | ≥ 150 unique cold visits | ≥ 3% combined cold CVR **or** ≥ 8 cold confirmed emails | 1.5–2.9% → one hero rewrite + 3 more days | After ≥ 150 cold visits **and** ≥ 2 hero variants: cold CVR &lt; 1.5% **and** &lt; 5 cold emails **and** 0 intent signals → **park product thesis** |

**Intent override:** ≥ 3 cold replies with concrete “I juggle N clients / rebuild tabs daily / would pay $X” can keep the thesis alive even if CVR is only mid-weak — interview before building.

**Welcome opens:** diagnostic only. Do not kill on open rate. If opens look near-zero, check deliverability first.

### 2.4 Dashboard (spreadsheet columns)

```text
date | utm_source | utm_medium | utm_campaign | utm_content
unique_visitors | cta_clicks | attempts | confirmed_emails | cvr
ad_spend | cpe | intent_notes | class (WARM|COLD_SOCIAL|COLD_ADS|OTHER)
```

Daily: log Plausible uniques by source + new Buttondown subscribers (tag or note by UTM when possible).  
Buttondown: add hidden `referrer_url` or `tag` if available; else ask “How did you hear about us?” optional field only if it doesn’t clutter — default is UTM + manual attribution for DMs.

### 2.5 Decision matrix (Day 9)

| Outcome | Criteria (evaluate classes separately first) | Next step |
|---------|-----------------------------------------------|-----------|
| **Strong** | Cold CVR ≥ 3% on ≥ 150 cold visits **or** ≥ 8 cold emails + ≥ 3 intent signals; warm optional corroboration | Thin MVP scope → `z-write-prd` for Chrome extension MVP (save/restore named client workspace only). No feature sprawl. |
| **Rewrite once** | Traffic OK (≥ 80 cold social or ads live) but cold CVR 1.5–2.9% | Ship headline variant #2 only; do not change ICP + price + creative same day. Extend 3 days max inside or immediately after the 10-day box. |
| **Soft demand** | Cold CVR ≥ 3% but **zero** replies / empty pain fields | Interview 5 waitlist people (`z-customer-discovery`) before writing product code. |
| **Channel fail** | Cannot reach 80 cold visits by Day 7 despite calendar | Distribution thesis failed — fix channels, not product. Do not interpret as “no demand.” |
| **Weak / park** | ≥ 150 cold visits, 2 heroes, cold CVR &lt; 1.5%, &lt; 5 cold emails, no intent | Park or reshape ICP (e.g. agencies vs SaaS CS). **Do not** “build more features” to fix demand. |
| **Warm-only mirage** | Warm ≥ 15% but cold &lt; 1.5% on adequate sample | Friends are polite. Do **not** greenlight build on warm alone. |

**Hard rule:** A single blended “overall conversion rate” that mixes `utm_source=dm` with ads/Reddit is **invalid** for go/kill.

---

## 3. Landing page copy (English)

### Meta

- **Title:** ClientTabs — One-click client tab workspaces for support agents  
- **Description:** Restore every tab for a specific client in one click. Built for hands-on support agents at small SaaS teams. Early access — planned from $9/month.  
- **OG title:** ClientTabs — One-click client context restore  
- **OG description:** Stop rebuilding the same client tabs between tickets. Client-specific browser workspaces for support agents. Join the early-access waitlist.  
- **OG line (short share):** One click to restore a client’s full tab workspace — for support agents who live in the browser.

### Headline variants

1. **(Ship this)** One-click restore for every client’s tab workspace  
2. Stop rebuilding the same client tabs between every ticket  
3. Client-specific browser workspaces for hands-on support agents  

### Full page

#### Nav

- **Wordmark:** ClientTabs  
- **Button:** Join the early-access waitlist  

#### Hero

- **Eyebrow:** Chrome extension · Early access  
- **H1:** One-click restore for every client’s tab workspace  
- **Subhead:** Hands-on support agents at small SaaS teams juggle tickets across dashboards, docs, and admin tools. ClientTabs remembers the tab set for each client — so you restore full context instead of rebuilding it.  
- **Price chip:** Planned pricing from $9/month  
- **Primary CTA:** Join the early-access waitlist  
- **Honesty line:** In development. We’re validating demand with early-access signups before we ship a public build. No firm launch date yet.

#### Problem

**The costly status quo**

- Between tickets, you close windows — then reopen the same billing page, admin, CRM, and docs for the next client, one tab at a time.  
- Session restore dumps *everything* back; browser profiles are too heavy for “this one client, right now.”  
- Context switching burns minutes per ticket and raises the chance you act in the wrong account.

#### Solution (3 steps)

1. **Save a client workspace** — Capture the tabs that belong to one client (or one account) under a clear name.  
2. **Switch with one click** — When that ticket lands, restore that client’s workspace instead of hunting bookmarks.  
3. **Stay in flow** — Close or park the set when you’re done; pull it back the next time they write in.

No AI magic story. One job: **client-specific tab workspaces, restored on demand.**

#### For / not for

**For**

- Support, success, or onboarding folks who live in Chrome all day  
- Small US SaaS teams where agents own end-to-end client issues  
- People who already keep mental (or messy) lists of “tabs for Acme”

**Not for**

- Teams that only use a single internal admin and never open client-specific web tools  
- People looking for a full CRM, helpdesk, or password manager  
- Anyone who needs an enterprise multi-admin rollout on day one (not the smoke offer)

#### Proof (honest — no fake social)

**Founder note**

> This page is a demand test. The extension is not shipped yet. If enough support agents say this is worth early access, we build the thinnest Chrome version that can save and restore named client workspaces. No fake logos, no invented user counts.

Optional later: short demo GIF placeholder labeled “Product preview — coming when we build.” Do **not** fake a polished product screenshot.

#### Offer / CTA block

- **Offer:** Join the early-access waitlist.  
- **What you get:** Email updates when a build is ready to try; founding-user input on the first workflow; planned pricing **from $9/month** if we ship paid access (subject to change before billing goes live).  
- **What you don’t get today:** A downloadable extension, a ship date, or a free forever promise.  
- **CTA:** Join the early-access waitlist  

#### FAQ

1. **Is ClientTabs live?**  
   No. It’s in development. This waitlist measures whether support agents want one-click client workspace restore enough to build it.

2. **When will early access open?**  
   We don’t have a firm ship date. Waitlist members hear first when there’s something real to try.

3. **How much will it cost?**  
   Planned pricing starts **from $9/month**. Final founding or list price may change; we won’t surprise you with a checkout on this page.

4. **Why only Chrome?**  
   Support agents in our ICP mostly live in Chrome. One browser keeps the first version honest and shippable.

5. **What about privacy?**  
   A real product would keep workspace data under your control (local-first preference for tab metadata). This smoke page only stores the email you submit for waitlist updates — not browsing history.

6. **How is my email used?**  
   Waitlist and product updates about ClientTabs only. No selling the list. Unsubscribe anytime.

7. **Who is this not for?**  
   Casual browsing declutter tools, full session managers for power users outside support work, or teams that need SSO/admin console before any value.

#### Final CTA

- **H2:** Restore client context instead of rebuilding it  
- **Body:** If you live in tickets and tabs, join the early-access waitlist. Planned from $9/month. No firm ship date — just a clear signal that this is worth building.  
- **CTA:** Join the early-access waitlist  

#### Footer

- ClientTabs · Built as a demand smoke test  
- Contact: `hello@YOUR_DOMAIN` (replace)  
- Privacy: Email used only for ClientTabs waitlist updates. No sale of addresses.  
- Not affiliated with Google / Chrome Web Store until listed.

---

## 4. Form & tracking

| Item | Spec |
|------|------|
| **Provider** | Buttondown |
| **Fields** | `email` (required); optional `tag` / metadata for `utm_source` if Buttondown form supports custom fields; optional one-line “Biggest daily tab pain?” (quality ↑, CVR may ↓ — enable only on variant B if cold CVR is strong but silent) |
| **CTA copy** | Join the early-access waitlist |
| **Success UX** | Redirect or show static message: “You’re on the early-access list. Check your inbox for a short confirmation.” Prefer Buttondown confirmation / double opt-in per your deliverability preference (US B2B: single opt-in OK if provider allows; double opt-in if spam complaints appear) |
| **Consent** | Explicit: “Email me early-access updates about ClientTabs. Unsubscribe anytime.” No pre-checked partner boxes. |
| **Privacy** | Stored in Buttondown; not sold; not used for unrelated products |
| **Analytics** | Plausible (privacy-friendly, no cookie banner drama for basic setup) |
| **Events** | See table below |
| **Successful-conversion SoT** | Buttondown confirmed subscriber record |
| **UTM scheme** | `utm_source`, `utm_medium`, `utm_campaign=clienttabs_smoke_v1`, optional `utm_content` |

### Events

| Event name | When | Counts as conversion? |
|------------|------|------------------------|
| Plausible pageview | Landing load | No (traffic) |
| `click_cta` | Any primary CTA click | No |
| `attempt_waitlist` | Form submit started | No |
| Confirmed subscriber | Buttondown accepts email | **Yes** — only this is visitor→email |

Do **not** name a client-side submit event `submit_waitlist` unless you have a verified success callback or success-page redirect you control after confirmation.

### UTM map (use exactly)

| Channel | Example URL suffix |
|---------|-------------------|
| Warm DM | `?utm_source=dm&utm_medium=warm&utm_campaign=clienttabs_smoke_v1&utm_content=personal` |
| Warm email | `?utm_source=warm_email&utm_medium=warm&utm_campaign=clienttabs_smoke_v1` |
| X organic | `?utm_source=x&utm_medium=social&utm_campaign=clienttabs_smoke_v1&utm_content=thread1` |
| Reddit | `?utm_source=reddit&utm_medium=community&utm_campaign=clienttabs_smoke_v1&utm_content=r_CUSTOMERSUCCESS` |
| Indie Hackers | `?utm_source=indiehackers&utm_medium=community&utm_campaign=clienttabs_smoke_v1` |
| Niche Slack/Discord | `?utm_source=slack&utm_medium=community&utm_campaign=clienttabs_smoke_v1&utm_content=WORKSPACE` |
| Google ads | `?utm_source=google&utm_medium=cpc&utm_campaign=clienttabs_smoke_v1&utm_content=search_v1` |
| Meta ads | `?utm_source=meta&utm_medium=paid&utm_campaign=clienttabs_smoke_v1&utm_content=interest_v1` |
| LinkedIn ads (if used) | `?utm_source=linkedin&utm_medium=cpc&utm_campaign=clienttabs_smoke_v1` |

**Campaign constant:** `clienttabs_smoke_v1` for the full 10 days. If you ship headline variant #2, change only `utm_content` (e.g. `hero_b`) — not the campaign name — so classes stay comparable.

---

## 5. Implementation notes

### Stack

| Layer | Choice | Placeholder / action |
|-------|--------|----------------------|
| Host | **Cloudflare Pages** | Deploy `landing/` as project root or `/` |
| Domain | Optional custom domain | `YOUR_DOMAIN` / Pages `*.pages.dev` OK for smoke |
| Email | **Buttondown** | Replace `YOUR_BUTTONDOWN_USERNAME` in form action |
| Analytics | **Plausible** | Replace `YOUR_PLAUSIBLE_DOMAIN` |
| Repo artifact | `landing/index.html` | Single-file, no app scaffold |

### Files created in this package

- `docs/smoke/clienttabs-20260801.md` — this protocol  
- `landing/index.html` — deployable page  

### Buttondown form (pattern)

```html
<form
  action="https://buttondown.com/api/emails/embed-subscribe/YOUR_BUTTONDOWN_USERNAME"
  method="post"
  class="embeddable-buttondown-form"
>
  <label for="bd-email">Work email</label>
  <input type="email" name="email" id="bd-email" required placeholder="you@company.com" />
  <input type="hidden" name="tag" value="clienttabs_smoke_v1" />
  <button type="submit">Join the early-access waitlist</button>
</form>
```

After deploy: submit one valid and one invalid email; confirm only valid appears in Buttondown.

### Plausible snippet (pattern)

```html
<script defer data-domain="YOUR_PLAUSIBLE_DOMAIN" src="https://plausible.io/js/script.tagged-events.js"></script>
```

CTA buttons: `class="plausible-event-name=click_cta"`.  
Form: on submit listener → `plausible('attempt_waitlist')` only.

### Cloudflare Pages deploy (founder steps)

```bash
# From repo root after filling placeholders
npx wrangler pages deploy landing --project-name=clienttabs-smoke
# or connect Git in Cloudflare dashboard → root directory: landing
```

### Handoff checklist (credentials you must fill)

- [ ] `YOUR_BUTTONDOWN_USERNAME`  
- [ ] `YOUR_PLAUSIBLE_DOMAIN`  
- [ ] `hello@YOUR_DOMAIN` footer contact  
- [ ] Plausible site created + domain verified  
- [ ] Buttondown welcome email written (see §6.5)  
- [ ] Cloudflare Pages project live  
- [ ] Test valid + invalid subscribe  
- [ ] Spreadsheet ready with traffic-class columns  

**Do not claim external services are wired until placeholders are replaced and tested.**

### Welcome email (Buttondown — send on subscribe)

**Subject:** You’re on the ClientTabs early-access list  

**Body (short):**

> Thanks for joining.  
> ClientTabs is a Chrome extension we’re validating — one-click restore of client-specific tab workspaces for hands-on support agents.  
> It isn’t shipping yet; there’s no firm date. You’ll hear when there’s a build to try.  
> Reply to this email with: How many client tab sets do you rebuild in a typical day?  
> — [Your name]

Replies = intent gold. Log them under the correct traffic class if known.

---

## 6. Traffic plan

**Budget:** **$150 ad hard cap**. Suggested split: **$100 search/social test**, **$50 reserve** only if Day 3–4 CPE is healthy.  
**Organic:** X, Reddit (buyer-ish subs), Indie Hackers, optional niche Slack/Discord with permission.  
**Warm:** 20–30 personal DMs — tracked **only** as WARM.

### 6.1 10-day calendar

| Day | Focus | Channel actions | UTM content hints | Notes |
|-----|--------|-----------------|-------------------|-------|
| **0** | Setup | Fill placeholders; deploy Pages; Plausible + Buttondown live; 2 test subs; spreadsheet | — | No public traffic until events work |
| **1** | Warm only | 15 personal DMs / emails to known CS/support people | `dm` / `warm` | Do **not** start ads yet; learn reply language |
| **2** | Warm + X | Finish remaining warm (25–30 total). X thread #1 (problem story) | `thread1` | Engage every reply within 12h |
| **3** | Cold social | Reddit post #1 (value-first, founder disclose). Soft IH “milestone: smoke” | `r_*`, `indiehackers` | Read sub rules; one sub first |
| **4** | Ads start | Launch **one** ad set, one creative, one ICP geo **US**, landing promise match. Cap **$25/day** | `search_v1` or `interest_v1` | Kill if CPE hopeless by end of Day 5 |
| **5** | Read + prune | Pause worst ad creative. X post #2 (build-in-public / founder note). Optional 2nd subreddit **only if** Day 3 not removed | `thread2`, `r_*_b` | Log class CVRs; **no warm+cold blend** |
| **6** | Double down or cut ads | If ads CPE ≤ $12 and CVR ≥ 2.5%, spend remaining toward $100–150. Else **kill ads**, shift time to DMs/replies | paid | Never exceed $150 |
| **7** | Community + follow-up | Reply to all waitlist emails. Optional niche Slack (permission). IH update with **honest** early metrics by class | community | No spam blasts |
| **8** | Hero B if needed | If cold CVR 1.5–2.9% on ≥ 80 cold visits, switch to headline variant #2 only; keep campaign name | `hero_b` | Do not change price + ICP same day |
| **9** | Decision day | Freeze traffic push. Pull Plausible + Buttondown. Fill decision matrix. | — | Write go / rewrite / interview / park |
| **Buffer** | — | If Day 7 channel-fail (&lt; 80 cold visits), use remaining days for distribution recovery — still separate classes | — | Do not “build the extension” mid-smoke |

### 6.2 Channel posts (drafts)

#### Warm DM (copy-paste skeleton)

> Hey {Name} — quick ask, not a pitch deck.  
> I’m testing whether support agents would use a Chrome extension that saves **per-client tab workspaces** and restores them in one click.  
> Page is a waitlist only (not built yet), planned from $9/mo: {URL with warm UTM}  
> If it’s irrelevant, ignore. If you have 2 minutes, I’d value a blunt reaction.

#### X — Thread 1 (problem)

1/ Support agents: how many times a day do you rebuild the *same* client tabs — billing, admin, docs, CRM — after the last ticket?  
2/ Full session restore is a junk drawer. Separate browser profiles are too heavy for “just this client.”  
3/ I’m smoke-testing **ClientTabs**: named client workspaces, one-click restore. Chrome, early access, planned from $9/mo. Not shipped — waitlist only.  
4/ If that’s your pain: {URL utm_source=x&utm_content=thread1}

#### X — Post 2 (founder)

Building in public: 10-day demand test for a tiny Chrome tool (client tab workspaces for SaaS support). No fake “10k users.” If you live in tickets + tabs, early-access waitlist → {URL utm_content=thread2}

#### Reddit (outline — adapt per sub)

- **Subs to evaluate (pick 1–2 max):** r/CustomerSuccess, r/saas, r/custdev, r/chrome_extensions (softer), r/smallbusiness only if support-heavy — **read rules first**.  
- **Title angle:** “Support agents: would you use a Chrome extension that restores a client’s full tab set in one click? (founder, waitlist smoke test)”  
- **Body:** Problem → what exists → gap → what ClientTabs would do in 3 bullets → honest “not built, planned from $9/mo” → link once → ask for critique.  
- **Do:** Disclose founder; engage comments; soft CTA.  
- **Don’t:** Multi-sub identical spam; “sign up now!!”; fake demos.

#### Indie Hackers

**Title:** Smoke-testing a $9/mo Chrome extension for support agents (client tab workspaces)  

**Body:** Why this ICP, one promise, waitlist CTA, ask what would make them pay or ignore. Share Day 7 class-separated metrics.

#### Small ads ($150 cap)

| Rule | Spec |
|------|------|
| Geo | United States |
| Audience | Job/interest proxies: customer support, customer success, SaaS, help desk (platform-dependent) |
| Creative | One primary: “Restore every client’s tabs in one click” + price “Planned from $9/mo” + “Early-access waitlist” |
| Landing match | Same H1 promise; no bait |
| Structure | One campaign, one ad set, ≤ 2 creatives; kill loser in 48h |
| Daily | ≤ $25/day until confidence; total ≤ $150 |
| Kill | CPE &gt; $25 or CVR &lt; 1.5% after $80 or 70 paid visits |

**Do not** run Product Hunt as day-0 mandatory — no shippable product asset; optional later if you have a real demo.

### 6.3 Expected traffic quality notes

| Source | Quality | Risk |
|--------|---------|------|
| Warm DM | Highest reply quality | Politeness bias — never sole green light |
| Reddit CS/SaaS | Mixed; good language if not removed | Ban risk if salesy |
| X | Low–mid volume; good for iterations | Tire-kickers |
| IH | Founder-heavy; may not be buyer ICP | Vanity support |
| Paid US | Controllable sample | Budget burn; broad targeting wastes CPE |

---

## 7. What we will NOT build during the smoke

- Chrome extension code, MV3 scaffolding, or Web Store listing  
- Accounts, auth, teams, SSO, admin console  
- Sync backend, cloud workspace storage, or multi-device  
- AI summarization, ticket sidebar, CRM integrations  
- Multi-page marketing site, blog, or brand system  
- Payment / Stripe checkout (price is a **signal**, not live billing)  
- Fake demos, logos, testimonials, counters, or ship dates  
- Pooling warm and cold metrics into one “success rate”  
- Spending over **$150** on ads  

**Build only after** a Strong or Soft-demand path that includes interviews if replies are thin.

---

## 8. After the smoke

| Outcome | Next step |
|---------|-----------|
| **Strong** | `z-write-prd` for MVP: save named workspace, restore one click, local storage, Chrome only. Skip multi-player. |
| **Rewrite worked** | Lock copy; optional second 7-day traffic box; still no full product. |
| **Soft demand** | `z-customer-discovery` with 5–10 waitlist interviews; rewrite promise if pain is different (e.g. wrong-account risk vs speed). |
| **Channel fail** | Fix distribution; re-run smoke before product work. |
| **Weak** | Park or ICP pivot (agencies? freelancers? sales engineers?). Do not code features to invent demand. |
| **Warm-only** | Treat as message test only; design a colder channel plan before MVP. |

### Optional upstream/downstream skills

- Upstream language: `z-market-validate` if you want broader signal before a second smoke  
- Post-strong: `z-write-prd` → thin build  
- Keywords later: `z-seo-plan` (not primary for this 10-day social/ads smoke)

---

## 9. Top actions & reminders

### Top 3 actions today

1. Replace Buttondown + Plausible placeholders in `landing/index.html` and deploy to **Cloudflare Pages**.  
2. Create the spreadsheet with **WARM / COLD_SOCIAL / COLD_ADS** columns; write the Buttondown welcome email.  
3. Send **15 warm DMs** (Day 1) with warm UTMs — do not start paid until Day 0 checks pass.

### What not to build yet

The extension itself, payments, sync, AI, or a multi-page site.

### Integrity reminders

- Single CTA only: **Join the early-access waitlist**  
- Price: **planned from $9/month** — truthful, not checkout  
- No testimonials, logos, user counts, firm ship date  
- **Never pool warm outreach with cold traffic** for the go/kill CVR  
