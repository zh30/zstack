# Landing smoke test: ClientSnap

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
| **Timebox** | 10 days (Day 0 setup → Day 10 decision) |
| **ICP** | Hands-on support / success agents at small US SaaS teams (roughly 5–50 people) who juggle multiple customer accounts in Chrome every day |
| **Promise** | One-click restore of client-specific tab workspaces |
| **CTA type** | Early-access waitlist — exact label: **Join the early-access waitlist** |
| **Price signal** | Planned from **$9/month** (not live billing; honest “planned price”) |
| **Page language** | English |
| **Geography** | US-first traffic and copy; English page only |
| **Stack** | Cloudflare Pages + Buttondown + Plausible |
| **Ad budget** | **$150 hard cap** (paid channel only) |
| **Ship date** | **None stated** — no firm ship month |
| **Social proof** | **None** — no testimonials, logos, or user counts |
| **Deployable page** | `landing/index.html` |

---

## 1. Hypothesis

If we offer **one-click restore of client-specific Chrome tab workspaces** to **hands-on support agents at small US SaaS teams** via **“Join the early-access waitlist”** (with a truthful planned price from **$9/month**), then within **10 days**:

1. **Cold + community + social traffic classes** (never pooled with warm) will each either clear their **source-specific visitor → confirmed-email CVR** bars below, **or** fail those bars with enough sample to justify rewrite / park.
2. **Warm outreach** will be judged **only** against the warm bar (separate sheet row — never averaged into cold rates).
3. At least **one qualitative paid-intent signal** appears among confirmed waitlist replies (use-case detail, “I’d pay,” or “invoice me”) **or** we treat email-only demand as soft and interview before building.

**What we are not testing:** extension UX polish, Chrome store conversion, multi-seat admin, or long-term retention.

---

## 2. Metrics & decision rules

### 2.1 Traffic classes (never pool warm with cold)

| Class ID | Definition | Typical sources | UTM pattern |
|----------|------------|-----------------|-------------|
| `warm` | Personal relationship or prior conversation; founder-initiated 1:1 | DMs, email to known CS people, warm intros | `utm_medium=warm` (`utm_source=dm` / `email` / `intro`) |
| `community` | Buyer-ish forums where people self-select into support/SaaS ops topics | Reddit, Indie Hackers, niche Slack/Discord (with permission) | `utm_medium=community` |
| `social` | Public organic social, not a 1:1 ask | X/Twitter posts & replies | `utm_medium=social` |
| `paid` | Paid cold acquisition only | Meta / Reddit / Google / X ads under $150 total | `utm_medium=cpc` |

**Hard rule:** Never compute a single “overall CVR” for go/kill. Report four class rates (or “insufficient N”). If a visit lacks classifiable UTM **and** no `traffic_class` on the confirmed subscriber, put it in `unattributed` and **exclude** it from source-specific decisions.

### 2.2 Metric definitions

| Metric | Definition | Source of truth |
|--------|------------|-----------------|
| **Qualified visitor** | Unique pageview on the smoke landing with a classifiable UTM **or** `traffic_class` landing param | Plausible (pageviews + UTM breakdown); optional `props.traffic_class` |
| **CTA click** | Click on any primary CTA control that scrolls/focuses the waitlist form | Plausible custom event `click_cta` |
| **Attempt** | Form submit click / native submit started | Plausible `attempt_waitlist` only (diagnostic) |
| **Confirmed conversion** | New subscriber accepted by Buttondown (valid email, not rejected) | **Buttondown subscriber record** with preserved `traffic_class` (tag or metadata) |
| **Visitor → email CVR** | Confirmed conversions ÷ qualified visitors **for the same class** | Class-matched Buttondown count ÷ Plausible class visits |
| **Welcome open** | Open on the single welcome email (diagnostic only) | Buttondown |
| **Intent reply** | Reply or form “biggest pain” answer that names a real multi-client tab workflow | Manual review |
| **Cost per confirmed email (paid only)** | Ad spend ÷ confirmed `paid` conversions | Ads dashboard + Buttondown `paid` tag |

**Conversion integrity:** Invalid, duplicate, bot, or merely attempted submissions are **not** conversions. Do **not** fire `submit_waitlist` from the browser submit handler as success. Client may fire `attempt_waitlist`; **count** only Buttondown-confirmed subscribers.

**Attribution integrity:** Each confirmed subscriber must store `traffic_class` (and raw UTMs when present) via Buttondown tag and/or metadata. Verify with one real valid test submit per class before Day 1 traffic. If attribution breaks, **stop claiming source-specific CVR** and fix capture first.

### 2.3 Sample floors (do not kill early)

| Class | Min qualified visits before kill/pivot | Min confirmed conversions for “strong” read |
|-------|----------------------------------------|-----------------------------------------------|
| `warm` | 30 | 5+ |
| `community` | 80 | 6+ |
| `social` | 100 | 5+ |
| `paid` | 80 **or** full $150 spent (whichever first for kill eligibility) | 4+ |

If a class never hits the visit floor by Day 10, mark that class **inconclusive** (distribution failure), not product failure.

### 2.4 Source-specific thresholds

| Class | Success bar (proceed signal) | Weak / rewrite bar | Kill / park bar (after sample floor) |
|-------|------------------------------|--------------------|--------------------------------------|
| `warm` | CVR **≥ 12%** and ≥2 intent replies | CVR 5–11% or silent list | CVR **&lt; 5%** with ≥30 visits |
| `community` | CVR **≥ 5%** and ≥2 use-case-rich answers/replies | CVR 2–4.9% | CVR **&lt; 2%** with ≥80 visits |
| `social` | CVR **≥ 4%** | CVR 1.5–3.9% | CVR **&lt; 1.5%** with ≥100 visits |
| `paid` | CVR **≥ 2.5%** **and** cost per confirmed email **≤ $12** | CVR 1–2.4% or CPE $12–20 | CVR **&lt; 1%** after ≥80 visits **or** CPE **&gt; $20** after ≥$75 spent with &lt;4 emails |

Directional only — adapt if a class is pure tire-kickers (high CVR, zero intent → soft demand).

### 2.5 Aggregate decision matrix (class-aware)

| Outcome | Criteria | Next step |
|---------|----------|-----------|
| **Strong** | ≥2 non-warm classes clear success **or** one non-warm class clears success **and** warm clears success; plus ≥3 intent replies total | Thin MVP slice + optional `z-write-prd`; interview 5 waitlist people first week |
| **Mixed — rewrite offer** | Traffic floors met on ≥1 cold/community class; CVR in weak band; some replies | Ship hero variant B or C; keep same channels 5 more days **or** end of timebox retest window |
| **Mixed — soft demand** | CVR OK on warm and/or community but **zero** intent replies after one follow-up email | Run 5–8 Mom Test interviews (`z-customer-discovery`); do **not** build extension yet |
| **Paid only weak** | Organic OK, paid fails CPE/CVR | Drop paid; do not conclude product is dead |
| **Distribution fail** | &lt; sample floors on all classes despite honest calendar | Fix reach / ICP venues; do not “build features to attract” |
| **Weak / park** | Sample floors met on ≥2 classes including one non-warm; all under kill bars; no paid intent | Park or reshape ICP/promise; **do not** start Chrome extension engineering |

**Never:** average `warm` CVR with `paid`/`social`/`community` into one headline rate for a ship decision.

### 2.6 Secondary diagnostics (not go/kill alone)

| Signal | Use |
|--------|-----|
| Welcome open rate | Deliverability + subject check only |
| CTA click → attempt | Form friction / clarity |
| “Biggest pain today?” text | Copy language + ICP filter |
| Unsubscribes within 48h | Expectation mismatch |

---

## 3. Landing page copy (English)

### Meta

- **Title:** ClientSnap — One-click client tab workspaces for support agents  
- **Description:** Restore every client’s Chrome tabs in one click. Built for hands-on support agents at small US SaaS teams. Join the early-access waitlist. Planned from $9/month.  
- **OG title:** ClientSnap — One-click client context restore  
- **OG description:** Stop rebuilding the same client tabs between tickets. ClientSnap restores client-specific Chrome workspaces in one click. Early-access waitlist. Planned from $9/month.  
- **OG line (short share):** One-click restore of client-specific tab workspaces for support agents. Early access — planned from $9/month.

### Headline variants

1. **(Ship this)** Restore every client’s Chrome workspace in one click  
2. Stop rebuilding the same client tabs between every ticket  
3. Client-specific tab workspaces for hands-on support agents  

### Full page

#### Nav

- **Product name:** ClientSnap  
- **CTA button:** Join the early-access waitlist  

#### Hero

- **Eyebrow:** For hands-on support agents at small US SaaS teams  
- **H1:** Restore every client’s Chrome workspace in one click  
- **Subhead:** ClientSnap is a Chrome extension that saves and restores **client-specific tab workspaces** so you stop hunting portals, tickets, and docs when you switch accounts.  
- **Price chip:** Planned price from **$9/month**  
- **Stage line:** In development — validating demand with an early-access waitlist. No ship date promised.  
- **Primary CTA:** Join the early-access waitlist  
- **Microcopy under CTA:** Work email preferred. Unsubscribe anytime.  

#### Problem / status quo

**Switching clients should not cost a full context rebuild.**

1. **Tab archaeology** — You close a ticket, open the next account, and spend minutes re-finding admin, billing, status, and runbooks.  
2. **Fragile memory** — Pinned tabs and “Temporary” windows mix clients; one wrong tab and you act in the wrong account.  
3. **No shared ritual that sticks** — Bookmarks folders and notes help once, then rot under real ticket load.  

#### Solution (3 steps)

1. **Snap a workspace per client** — Capture the tabs you actually use for that account (not your whole browser).  
2. **Label it like your queue** — Name workspaces by customer or account ID the way your team already talks.  
3. **One-click restore** — Jump back into that client’s tab set when the next ticket lands.  

#### Who it’s for / not for

**For**

- Support, success, or onboarding folks who live in Chrome across **many customer accounts** daily  
- Small US SaaS teams where agents are hands-on (you still open the product, not only a helpdesk macro)  
- People who already invent workarounds (named windows, bookmark piles, “don’t close these”)  

**Not for**

- One-product ICPs with a single internal admin and no multi-tenant context switching  
- Teams that only need a helpdesk — not browser context  
- Enterprise browser-management RFPs, SOC2 theater, or “AI that answers tickets for you”  
- Anyone needing a guaranteed launch date this month  

#### Proof (honest)

- No testimonials, logos, or user counts yet — that would be fiction.  
- **Founder note:** “I’m testing whether support agents care enough about **one-click client context restore** to join an early-access list before I build the full extension. If you live this pain, I want the waitlist and a sentence about your workflow.”  
- Optional visual: simple wireframe/GIF placeholder of “Client A → Client B restore” (schematic only; not a fake product screenshot).  

#### Offer / CTA block

- **Offer:** Early access when a thin version is ready; product notes to the list; influence on the first workspace model.  
- **Price:** Planned from **$9/month** for individuals (billing not open yet; this is a willingness signal, not a charge).  
- **CTA:** Join the early-access waitlist  
- **Optional qualifier (one field):** Biggest pain today when switching clients? (short text)  

#### FAQ

1. **Is ClientSnap live?**  
   No. This page is a demand smoke test. The extension is not shipped.

2. **When will it ship?**  
   No firm date. Waitlist members hear first when there is something real to try.

3. **What does “from $9/month” mean?**  
   Planned individual pricing starts at $9/month. Final packaging may change; you will not be charged by joining the waitlist.

4. **What data does a tab workspace extension need?**  
   Design goal: local workspace metadata (URLs you choose to save), not reading your ticket bodies for ads. Full privacy policy ships with the product; email on this form is only for waitlist updates.

5. **Will you sell my email?**  
   No. Stored in Buttondown for ClientSnap updates. Unsubscribe anytime.

6. **Is this for whole teams?**  
   Smoke test targets individual agents first. Team plans only if demand is real.

7. **Why a waitlist instead of a download?**  
   Building a Chrome extension before proving agents want **one-click client restore** is how solo builders waste months.

#### Final CTA

- **H2:** Get early access to one-click client context restore  
- **Body:** If multi-client tab chaos is part of your shift, join the list. Planned from $9/month — no charge today.  
- **CTA:** Join the early-access waitlist  

#### Footer

- ClientSnap — early-access smoke test  
- Contact: `hello@YOUR_DOMAIN` (placeholder)  
- Privacy: Email used only for ClientSnap waitlist updates. No sale of the list.  
- Built by an independent developer validating demand before writing the full extension.

---

## 4. Form & tracking

| Item | Spec |
|------|------|
| **Provider** | Buttondown |
| **Fields** | `email` (required); `biggest_pain` (optional text → Buttondown metadata); hidden `traffic_class`, `utm_source`, `utm_medium`, `utm_campaign`, `utm_content` |
| **CTA copy** | Join the early-access waitlist |
| **Success message** | You’re on the ClientSnap early-access list. Check your inbox for a short confirmation. |
| **Consent** | Single opt-in acceptable for this US smoke if Buttondown + deliverability stay clean; enable double opt-in if spam risk rises. Disclose: updates about ClientSnap only. |
| **Successful-conversion source of truth** | Buttondown **confirmed subscriber** record (not browser submit) |
| **Confirmed-conversion attribution** | Buttondown **tag** = `traffic_class` value (`warm` \| `community` \| `social` \| `paid` \| `unattributed`) **and** metadata keys for raw UTMs + `biggest_pain`. Verify each class with a real test submit before traffic. |
| **Fallback if metadata fails** | Separate Buttondown tags via four form endpoints or tag query params — do **not** invent source from signup time |
| **Analytics** | Plausible (privacy-friendly, simple) |
| **Events** | See below |
| **UTM scheme** | `utm_source`, `utm_medium`, `utm_campaign=smoke_v1`, optional `utm_content` |

### 4.1 Events

| Event name | When | Counts as conversion? |
|------------|------|------------------------|
| `pageview` | Plausible default | No |
| `click_cta` | Primary CTA clicked | No |
| `attempt_waitlist` | Form submit initiated | **No** |
| *(no client `submit_waitlist` success)* | — | Use Buttondown as success |
| Manual / export `confirmed_waitlist` | Daily export or Buttondown admin count by tag | **Yes** |

Optional later: Buttondown webhook → tiny Worker to emit server-side analytics; **not required** for 10-day smoke.

### 4.2 UTM catalog (complete)

Base: `https://YOUR_DOMAIN/` (Cloudflare Pages URL or custom domain)

| Channel action | Example URL |
|----------------|-------------|
| Warm DM | `?utm_source=dm&utm_medium=warm&utm_campaign=smoke_v1&utm_content=personal` |
| Warm email | `?utm_source=email&utm_medium=warm&utm_campaign=smoke_v1&utm_content=known_cs` |
| X post 1 (pain) | `?utm_source=twitter&utm_medium=social&utm_campaign=smoke_v1&utm_content=pain_story` |
| X post 2 (build) | `?utm_source=twitter&utm_medium=social&utm_campaign=smoke_v1&utm_content=build_public` |
| X post 3 (offer) | `?utm_source=twitter&utm_medium=social&utm_campaign=smoke_v1&utm_content=offer` |
| Reddit (support/SaaS) | `?utm_source=reddit&utm_medium=community&utm_campaign=smoke_v1&utm_content=r_TARGETSUB` |
| Indie Hackers | `?utm_source=indiehackers&utm_medium=community&utm_campaign=smoke_v1&utm_content=milestone` |
| Niche Slack/Discord | `?utm_source=slack&utm_medium=community&utm_campaign=smoke_v1&utm_content=WORKSPACE` |
| Paid — creative A | `?utm_source=PLATFORM&utm_medium=cpc&utm_campaign=smoke_v1&utm_content=creative_a` |
| Paid — creative B | `?utm_source=PLATFORM&utm_medium=cpc&utm_campaign=smoke_v1&utm_content=creative_b` |

**Mapping medium → traffic_class (in page JS):**

| `utm_medium` | `traffic_class` |
|--------------|-----------------|
| `warm` | `warm` |
| `community` | `community` |
| `social` | `social` |
| `cpc` | `paid` |
| missing / other | `unattributed` |

### 4.3 Tracking spreadsheet columns (minimum)

`date | traffic_class | visitors | cta_clicks | attempts | confirmed_emails | cvr | ad_spend | cpe | intent_replies | notes`

Separate **rows or sheets per traffic_class**. No pooled CVR cell for decisions.

---

## 5. Implementation notes

### 5.1 Stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Host | **Cloudflare Pages** | Deploy `landing/` as static project |
| Page | `landing/index.html` (single file) | No app framework |
| Email | **Buttondown** | Embed/form POST + tags/metadata |
| Analytics | **Plausible** | Custom events; no cookie banner theater if config is cookieless |

### 5.2 Placeholders to replace before real traffic

| Placeholder | Where | You provide |
|-------------|-------|-------------|
| `YOUR_BUTTONDOWN_USERNAME` | Form `action` | Buttondown username |
| `YOUR_PLAUSIBLE_DOMAIN` | Plausible script + `data-domain` | e.g. `clientsnap.pages.dev` or custom |
| `YOUR_DOMAIN` | Canonical, OG, URLs, footer email | Pages or custom domain |
| `hello@YOUR_DOMAIN` | Footer contact | Real inbox |

**Do not claim** Buttondown/Plausible/custom domain are live until credentials and DNS are yours and verified.

### 5.3 Deploy steps (founder)

1. Create Buttondown newsletter; note username; create tags `warm`, `community`, `social`, `paid`, `unattributed` (or allow freeform tags).  
2. Confirm form accepts metadata (test API/docs for your Buttondown plan): e.g. `tag`, metadata fields for UTMs and `biggest_pain`.  
3. Add site in Plausible; enable custom events `click_cta`, `attempt_waitlist`.  
4. Replace placeholders in `landing/index.html`.  
5. `npx wrangler pages deploy landing --project-name=clientsnap` (or drag-drop in Pages UI).  
6. **Attribution drill:** open each class UTM once, submit a real email you control, confirm tag/metadata on subscriber.  
7. Send one welcome email template (subject below).  
8. Only then start Day 1 traffic.

### 5.4 Welcome email (Buttondown)

- **Subject:** You’re on the ClientSnap early-access list  
- **Body (short):** Thanks for joining. ClientSnap is an unbuilt Chrome extension for **one-click restore of client-specific tab workspaces** for support agents at small SaaS teams. Planned from $9/month — you haven’t been charged. Reply with how you switch clients today (tabs, windows, bookmarks?). — [Your name]

### 5.5 Files in this package

| Path | Role |
|------|------|
| `docs/smoke/clientsnap-20260801.md` | Full protocol (this file) |
| `landing/index.html` | Deployable smoke page |

### 5.6 Privacy one-liner (page + form)

Email is stored in Buttondown for ClientSnap waitlist updates only. Not sold. Unsubscribe anytime.

---

## 6. Traffic plan (10 days, $150 ad cap)

**Principles:** Disclose founder status where norms require it. One UTM’d link. Engage replies same day. Kill paid creatives that only burn budget. **Log warm separately forever.**

### 6.1 Day-by-day calendar

| Day | Focus | Actions | UTM / class | Spend |
|-----|-------|---------|-------------|-------|
| **0** | Setup | Replace placeholders; deploy Pages; Plausible + Buttondown live; 4-class attribution tests; spreadsheet ready; welcome email drafted | — | $0 |
| **1** | Warm only | 15 personal DMs/emails to ideal agents (ex-colleagues, CS friends, warm LinkedIn). Ask for honest “would you waitlist?” not virality | `utm_medium=warm` | $0 |
| **2** | Warm + X | 10 more warm touches. **X post 1** pain story (no feature dump). Engage every reply | warm + `social` / `pain_story` | $0 |
| **3** | Community | Reddit value-first post in **one** rules-checked sub (support/SaaS/customer success). Soft CTA, founder disclosure | `community` / sub name | $0 |
| **4** | Social + IH | **X post 2** build-in-public (smoke test honesty). Indie Hackers milestone post | `social` + `community` | $0 |
| **5** | Paid start | Launch **one** platform, **one** ICP geo (US), **one** creative matching H1. Cap **$15/day**. Pause if CPC absurd in 24h | `cpc` / `creative_a` | ≤ $15 |
| **6** | Paid + engage | Creative A continues **or** swap to **creative_b** if zero holds after ~$30. Continue reply farming on X/Reddit | `cpc` / `creative_b` if swap | ≤ $15–20 |
| **7** | Community #2 | Second community surface only if Day 3 wasn’t removed (different sub **or** niche Slack with permission). No identical spam | `community` | ≤ $15 paid if still learning |
| **8** | Social offer | **X post 3** direct offer + price chip honesty. Pin thread during test | `social` / `offer` | ≤ $15 |
| **9** | Fill gaps | Only channels that produced **qualified** visitors. No new platform. Warm follow-up to non-responders (still `warm`) | existing | ≤ $15; **stop paid if CPE already &gt; $20** |
| **10** | Decision | Freeze new spend. Export Buttondown by tag. Fill class table. Apply §2 decision matrix. Write 1-page outcome note | — | $0; **total paid ≤ $150** |

**Paid rules:** Total **≤ $150**. Prefer one platform. Kill a creative after ~$40 with no confirmed `paid` emails. Never retarget waitlist signups with “fake social proof.”

### 6.2 Channel post drafts

#### Warm DM (skeleton)

> Hey [Name] — you work multi-account support more than I do. I’m smoke-testing **ClientSnap**: a Chrome extension that restores **client-specific tab workspaces in one click**. Not built yet; planned from $9/mo. Would you glance at this and join the early-access waitlist only if the pain is real? [warm UTM link] One line on how you switch clients today would help either way.

#### X — Post 1 (pain)

> Support agents at small SaaS teams: how long does it take you to rebuild a customer’s tabs when the next ticket is a different account?  
> Portals, billing, status, runbooks — every switch.  
> I’m testing a one-click **client workspace restore** (Chrome). Early-access waitlist, planned from $9/mo — no fake “shipped” claims.  
> [social pain_story UTM]

#### X — Post 2 (build-in-public)

> Day n of a demand smoke test: landing page + waitlist only. No extension code until agents prove they care.  
> Offer: one-click restore of client-specific tab workspaces. CTA: Join the early-access waitlist. Price signal: from $9/mo.  
> If you do hands-on support, roast the page: [social build_public UTM]

#### X — Post 3 (offer)

> If you keep a fragile pile of client tabs open “just in case,” ClientSnap is the early-access waitlist for one-click context restore.  
> In development. Planned from $9/month. No testimonials to invent.  
> [social offer UTM]

#### Reddit (outline — adapt to sub rules)

- **Title angle:** “Support agents: do you rebuild browser context per customer, or is that just me?”  
- **Body:** Describe tab archaeology without dumping a pitch paragraph first. Ask how others cope. Short founder note at end: building a Chrome waitlist for one-click client workspace restore; link once; planned $9/mo; not live.  
- **Do:** Read rules, use feedback flair if required, reply to every comment.  
- **Don’t:** Multi-sub identical copy in one hour; fake “user” stories; claim shipping dates.

#### Indie Hackers (outline)

- Milestone: 10-day smoke for ClientSnap.  
- ICP + promise + CTA + $9 planned price.  
- Ask for critique on ICP narrowness, not “please upvote.”  
- Commit to posting results (even failure).

#### Paid creative (text)

- **Primary text:** Support agents: restore each client’s Chrome tabs in one click. Early access waitlist. Planned from $9/month.  
- **Headline:** One-click client tab workspaces  
- **Match:** Same promise as H1; US interest targeting small business / customer support roles if available.  
- **Exclude:** Competitor brand spam; broad “everyone who uses Chrome.”

### 6.3 Do / don’t summary

| Do | Don’t |
|----|-------|
| Disclose you’re the maker | Fake logos, counts, testimonials |
| One link, full UTMs | Pool warm DMs into cold CVR |
| Log by `traffic_class` | Fire conversion on submit attempt |
| Cap ads at $150 | Spray 10 subreddits day one |
| Interview intent-rich signups | Start building full extension mid-test |

---

## 7. What we will NOT build during the smoke

- Chrome extension code, Manifest V3 scaffolding, or Web Store listing  
- Accounts, teams, SSO, admin seats, or billing (Stripe)  
- Sync backend, cloud workspace storage, or AI “summarize this client”  
- Multi-page marketing site, blog, or SEO program  
- Fake demo video that implies a shipped product  
- Community spam tools or purchased traffic  
- Custom analytics warehouse — Plausible + spreadsheet is enough  

---

## 8. After the smoke

| Outcome | Next step |
|---------|-----------|
| **Strong** | 5 short interviews with waitlist; then thin MVP (local save/restore one workspace type) + `z-write-prd` if scope unclear |
| **Mixed — rewrite** | Ship headline variant 2 or 3; optional FAQ/price clarity; 5-day retest on best channel only |
| **Mixed — soft demand** | `z-customer-discovery` on multi-client tab pain; pause engineering |
| **Weak** | Park ClientSnap or change ICP (e.g. agencies / fractional CS) — do **not** add features to “make the page convert” |
| **Distribution fail** | New venue research; keep same page; do not blame the promise yet |

### Explicit non-pooling reminder

Warm outreach is for **message learning and upper-bound willingness**. Cold, community, social, and paid answer **“will strangers care?”** Mixing them into one CVR hides failure or exaggerates success.

---

## 9. Founder actions today (top 3)

1. Replace Buttondown / Plausible / domain placeholders in `landing/index.html` and deploy to **Cloudflare Pages**.  
2. Run four attribution test signups (`warm`, `community`, `social`, `paid` UTMs) and confirm Buttondown tags.  
3. Send **15 warm DMs** (Day 1) while drafting the Reddit-rules check for Day 3.

## 10. What not to build yet

Any Chrome extension code. This package is **page + waitlist + traffic + decision rules** only.

## 11. Optional skill loops

- If language of pain is weak → `z-customer-discovery`  
- If you need broader demand evidence before a second smoke → `z-market-validate`  
- If strong → `z-write-prd` for a thin local MVP only  

---

*Smoke pack generated for ClientSnap — 2026-08-01 — 10-day protocol, $150 ad cap, Cloudflare Pages + Buttondown + Plausible.*
