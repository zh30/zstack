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
| **Timebox** | 10 days (Day 0 setup → Day 9 close → Day 10 decision) |
| **ICP** | Hands-on support / CS agents at small US SaaS teams (≈5–50 people) who juggle multiple client accounts in Chrome every day |
| **Promise** | One-click restore of client-specific tab workspaces |
| **CTA type** | Early-access waitlist — exact label: **Join the early-access waitlist** |
| **Price signal** | Planned pricing from **$9/month** (honest “planned,” not live billing) |
| **Page language** | English |
| **Geography** | United States (ads + primary outreach); English-speaking agents OK elsewhere |
| **Stage** | **Unbuilt** Chrome extension — demand test only |
| **Stack** | Cloudflare Pages + Buttondown + Plausible |
| **Ad budget cap** | **$150** total across the window |
| **Forbidden claims** | No testimonials, no logos, no user counts, no firm ship date |

---

## 1. Hypothesis

If we offer **one-click restore of client-specific tab workspaces** to **hands-on support agents at small US SaaS teams** via a single CTA **“Join the early-access waitlist”** with a truthful planned price **from $9/month**, then within **10 days**:

| Traffic class | Primary metric | Pre-registered success bar | Minimum sample before kill |
|---------------|----------------|----------------------------|----------------------------|
| **Warm outreach** (`warm`) | Confirmed waitlist / unique landing visitors from warm links | **≥ 12%** visitor→email CVR **and** ≥ 3 qualified replies (use case or “I’d pay”) | ≥ **40** warm visitors **or** ≥ **8** confirmed warm emails |
| **Cold social / community** (`social`) | Confirmed waitlist / unique landing visitors from X, Reddit, IH, niche Slack | **≥ 4%** visitor→email CVR **and** ≥ 1 thoughtful reply | ≥ **120** social visitors across ≥ 2 channels |
| **Cold paid ads** (`ads`) | Confirmed waitlist / unique ad landing visitors; cost per confirmed email | **≥ 1.5%** CVR **and** cost per confirmed email **≤ $25** | ≥ **80** ad visitors **or** full **$150** spent with clean tracking |

**Core claim under test:** agents who live in multi-client Chrome sessions care enough about **context restore** to leave a work email before the product exists.

**Not under test:** extension architecture, Chrome Web Store ranking, or full CS platform fit.

### Critical integrity rule

**Never pool warm outreach with cold traffic** for a headline CVR, success call, or kill call. Report three funnels. An aggregate “all traffic” rate may appear only as a footnote and **must not** drive the decision.

---

## 2. Metrics & decision rules

### 2.1 Funnel definitions

```text
Channel impression / click
  → Landing view (Plausible pageview + UTM / traffic_class)
    → CTA click (Plausible custom event: cta_click)
      → Waitlist attempt (form submit fired; not a conversion)
        → Confirmed subscriber (Buttondown accepts email)  ← ONLY conversion
          → Welcome open (diagnostic only)
            → Reply / “I’d pay” / use-case note  ← qualitative gold
```

| Metric | Definition | Source of truth |
|--------|------------|-----------------|
| Unique visitors (by class) | Unique pageviews on landing, segmented by `utm_source` → mapped traffic class | Plausible (filter by UTM) |
| CTA clicks | Clicks on any primary CTA button/link that focuses the form | Plausible goal `cta_click` |
| Waitlist attempts | Browser form submit events | Optional Plausible `waitlist_attempt` only; **not** CVR |
| **Confirmed emails** | New subscribers accepted by Buttondown for this smoke | **Buttondown** (tag + metadata) |
| Visitor → email CVR (by class) | Confirmed emails(class) / unique visitors(class) | Buttondown numerators + Plausible denominators, **same class** |
| Cost per confirmed email (ads) | Ad spend / confirmed `ads`-tagged emails | Ad platform + Buttondown |
| Welcome open rate | Opens on Day-0 welcome | Buttondown (diagnostic only; not a demand verdict) |
| Intent signals | Replies to welcome, DM answers, “I’d pay”, calendar asks | Manual log |
| Revenue | $0 expected (no pre-order in this smoke) | — |

### 2.2 Conversion integrity (non-negotiable)

1. A **conversion** is a **provider-confirmed** Buttondown subscriber for this campaign.
2. Invalid, duplicate-rejected, bot, or merely attempted submissions **do not count**.
3. Client-side JS **must not** emit `submit_waitlist` / success conversion on form submit.
4. Visible UI after native cross-origin submit: **neutral acknowledgement only**  
   (“Submission sent — check your inbox if you’re added.”).  
   Never “You’re on the list” without verified callback/redirect.
5. Optional client event name: `waitlist_attempt`. Confirmed conversion is counted only from Buttondown.

### 2.3 Attribution integrity (non-negotiable)

Source-specific thresholds require the **same class on numerator and denominator**.

| Piece | Spec |
|-------|------|
| Landing | Read `utm_source`, `utm_medium`, `utm_campaign`, `utm_content` on load; map to `traffic_class` ∈ {`warm`, `social`, `ads`, `direct`} |
| Hidden fields | Persist UTMs + `traffic_class` into the form before submit |
| Buttondown tags | Exactly one smoke tag: `smoke-warm` \| `smoke-social` \| `smoke-ads` \| `smoke-direct` |
| Buttondown metadata | `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `traffic_class`, `smoke_id=clienttabs_20260801` |
| Preflight | Before Day 1 traffic: submit **one valid** and **one invalid** email per major class path; confirm tag + metadata appear on the accepted subscriber; confirm invalid does not count |

If a channel cannot preserve class on the confirmed subscriber, **do not** report source-specific CVR for that channel. Fix capture first. Never allocate an undifferentiated email total across channels by timing.

### 2.4 Traffic class map

| `traffic_class` | `utm_source` examples | Pool with? |
|-----------------|----------------------|------------|
| `warm` | `dm`, `email_personal`, `slack_dm`, `friend` | **Only other warm** |
| `social` | `twitter`, `reddit`, `indiehackers`, `slack_community`, `linkedin` | Other social/community only |
| `ads` | `google`, `reddit_ads`, `meta`, `x_ads` | Other paid only |
| `direct` | empty / typed URL / unknown | Report separately; **exclude from warm and cold success bars** unless volume is material |

### 2.5 Pre-registered decision matrix (Day 10)

Evaluate **each class that hit minimum sample**. Classes below sample → “insufficient data,” not “fail.”

| Outcome | Conditions (examples) | Next step |
|---------|----------------------|-----------|
| **Strong** | `social` ≥ 4% with ≥ 5 confirmed **or** `ads` ≥ 1.5% with CPE ≤ $25 **and** ≥ 2 intent replies overall; warm not required but if run should not be &lt; 8% with large sample | Thin PRD (`z-write-prd`) + smallest Chrome MVP that only saves/restores named client tab sets |
| **Mixed — offer soft** | Traffic OK, CVR below bar on cold, warm healthy | Rewrite hero/problem (one variant); retest **same cold channels** 5 days; do not build product |
| **Mixed — soft demand** | CVR hits bar, **zero** replies after one follow-up email | 5–8 waitlist interviews (`z-customer-discovery`) before any code |
| **Paid wedge** | Any credible “invoice us / I’d pay now” from ICP email domain | Prioritize paid founding conversation; still no full feature build |
| **Weak / kill reshape** | After minima: `social` &lt; 2% **and** `ads` &lt; 1% (or CPE &gt; $40 with 80+ visits) **and** no intent replies | Park or reshape ICP/promise — **do not** “add features to the landing” beyond copy tests |
| **Distribution failure** | &lt; 50 total qualified cold visits despite honest push | Fix distribution thesis; product thesis untested |

**Warm vs cold:** Strong warm + dead cold = network courtesy, not market pull. Treat as **mixed** at best. Strong cold + weak warm = still interesting; warm may have been poorly targeted.

### 2.6 Simple dashboard (spreadsheet columns)

`date | traffic_class | source | visitors | cta_clicks | confirmed_emails | cvr | ad_spend | cpe | replies | notes`

---

## 3. Landing page copy (English)

### Meta

- **Title:** ClientTabs — One-click client tab workspaces for support agents  
- **Description:** Restore every client’s Chrome tabs in one click. Built for hands-on support agents at small SaaS teams. Join the early-access waitlist. Planned pricing from $9/month.  
- **OG title:** ClientTabs — Restore client tab workspaces in one click  
- **OG description:** Support agents juggle clients all day. ClientTabs is a Chrome extension (in development) that restores each client’s tab workspace in one click. Join the early-access waitlist. From $9/month planned.  
- **OG image alt:** ClientTabs — one-click client context restore for support agents  

### Headline variants

1. **(Ship this)** One-click restore for every client’s tab workspace  
2. Stop rebuilding the same client tabs between every ticket  
3. Client-specific Chrome workspaces for hands-on support agents  

### Full page

#### Nav

- **Wordmark:** ClientTabs  
- **CTA (button):** Join the early-access waitlist  

#### Hero

- **Eyebrow:** Chrome extension for support agents · In development  
- **H1:** One-click restore for every client’s tab workspace  
- **Subhead:** Hands-on support agents at small SaaS teams jump between accounts all day. ClientTabs saves a named set of tabs per client—and restores that full context in one click when the next ticket hits.  
- **Price chip:** Planned pricing from $9/month  
- **Primary CTA:** Join the early-access waitlist  
- **Honesty line:** Unbuilt on purpose—we’re validating demand with real agents before shipping the extension. No fake demos, no invented user counts.  
- **Form (inline or jump target `#waitlist`):**  
  - Work email (required)  
  - Optional: “Biggest tab-switching pain today?” (short text)  
  - Optional: Company size band (solo / 2–10 / 11–50 / 51+)  
  - Consent: “Email me early-access updates. Unsubscribe anytime. We never sell your address.”  

#### Problem

**You don’t lose tickets. You lose context.**

- You close five tabs after Client A, open Client B, then rebuild A’s admin, billing, and status pages from memory.  
- Shared “start here” bookmarks ignore *this* client’s quirks—and still take a dozen clicks.  
- Switching costs compound across a shift: slower first responses, more “let me pull that up again,” more end-of-day fatigue.

#### Solution (3 steps)

1. **Name a client workspace** — e.g. “Acme — production” with the tabs you actually use.  
2. **Save the set once** — ClientTabs remembers that layout for next time.  
3. **Restore in one click** — when Acme writes in, open their workspace instead of hunting URLs.

No AI magic pitch. No “second brain.” Just client-specific tab context, restored fast.

#### Who it’s for / not for

**For**

- Hands-on support, CS, or success agents who live in Chrome across many customer accounts  
- Small US SaaS teams (roughly 5–50) where agents own full ticket context  
- People who already maintain informal tab rituals, bookmark folders, or “don’t close these” windows  

**Not for**

- Enterprise IT programs shopping a full digital-employee platform  
- Teams that only need a generic session manager with no client naming  
- Anyone expecting a live Chrome Web Store install today—this page is a demand test  

#### Proof (honest)

- **No testimonials, logos, or user counts**—we don’t have them yet, and we won’t invent them.  
- **Founder note:** “I’m testing whether support agents want one-click client workspaces badly enough to join an early-access list before code ships. If you do, your email and one sentence of pain are the most useful signal.”  
- **Demo:** Optional static wireframe or short GIF *only if real*; otherwise a simple labeled mock of “Client → Restore” UI—not a fake product screenshot.

#### Offer / CTA block

- **Offer:** Early access when the first usable extension build is ready for founding users.  
- **Price:** Planned from **$9/month** (subject to change; you’ll hear before any charge).  
- **What you get now:** A short confirmation path via email, occasional build updates, and a chance to shape the first version.  
- **What you don’t get:** A firm ship date, a free forever plan promise, or spam.  
- **CTA:** Join the early-access waitlist  

#### FAQ

1. **Is ClientTabs live?**  
   No. It is an unbuilt Chrome extension. This page tests whether the problem is real enough to build.

2. **When will founding users get access?**  
   When a thin first build can save and restore named client tab sets. We will not publish a firm ship date on this page.

3. **How is my email used?**  
   Early-access updates and occasional questions about your workflow. Stored in Buttondown. Never sold. Unsubscribe anytime.

4. **What’s the price?**  
   Planned pricing starts from **$9/month**. Final founding terms may differ slightly; we won’t charge without a clear offer.

5. **Who is this not for?**  
   Teams that need broad browser session tools without per-client workspaces, or buyers who only want a finished store listing today.

6. **What happens after I join?**  
   You’ll get a welcome message. If volume allows, we may ask one follow-up about your tab workflow. No obligation.

#### Final CTA

- **H2:** Restore client context without rebuilding tabs  
- **Body:** If you support multiple SaaS customers in Chrome every day, join the list. One CTA. Honest stage. Planned from $9/month.  
- **CTA:** Join the early-access waitlist  

#### Footer

- Built as a demand test for ClientTabs  
- Contact: `hello@YOURDOMAIN` (placeholder)  
- Privacy: We use your email only for early-access updates. No selling lists.  
- Analytics: Privacy-friendly Plausible (no ad-profile tracking).  
- © 2026 ClientTabs  

---

## 4. Form & tracking

| Item | Spec |
|------|------|
| **Provider** | Buttondown |
| **Host** | Cloudflare Pages (static `landing/`) |
| **Analytics** | Plausible (one site) |
| **Fields** | `email` (required); `pain` (optional text → Buttondown notes/metadata); `company_size` (optional); hidden: `utm_*`, `traffic_class`, `smoke_id` |
| **Consent** | Explicit unchecked-by-default is ideal; minimum: clear sentence next to submit (no dark patterns) |
| **Opt-in** | Single opt-in acceptable for US smoke speed; enable Buttondown confirmation if deliverability suffers |
| **Success UI** | Neutral: “Submission sent — check your inbox if the address is accepted.” |
| **Conversion SoT** | Buttondown confirmed subscriber with smoke tag |
| **Attribution SoT** | Tag `smoke-{traffic_class}` + metadata UTMs on that subscriber |
| **Events (Plausible)** | See below |
| **UTM scheme** | See §4.2 |

### 4.1 Events

| Event name | When it fires | Counts as conversion? |
|------------|---------------|------------------------|
| Plausible pageview | Landing load | No |
| `cta_click` | Primary CTA click (nav, hero, final) | No |
| `waitlist_attempt` | Form `submit` handler runs after basic HTML5 validation | **No** |
| Confirmed waitlist | Buttondown accepts subscriber | **Yes** (manual/export count by tag) |

Do **not** configure a Plausible goal named like “Waitlist success” fired from the submit handler.

### 4.2 UTM scheme

Base: `https://YOURDOMAIN/` (or Pages URL)

```text
# Warm — never mix reporting with cold
?utm_source=dm&utm_medium=warm&utm_campaign=clienttabs_smoke_v1&utm_content=personal
?utm_source=email_personal&utm_medium=warm&utm_campaign=clienttabs_smoke_v1&utm_content=founder_note

# Social / community cold
?utm_source=twitter&utm_medium=social&utm_campaign=clienttabs_smoke_v1&utm_content=thread1
?utm_source=twitter&utm_medium=social&utm_campaign=clienttabs_smoke_v1&utm_content=thread2
?utm_source=reddit&utm_medium=community&utm_campaign=clienttabs_smoke_v1&utm_content=r_customersuccess
?utm_source=reddit&utm_medium=community&utm_campaign=clienttabs_smoke_v1&utm_content=r_saas
?utm_source=indiehackers&utm_medium=community&utm_campaign=clienttabs_smoke_v1&utm_content=milestone
?utm_source=slack_community&utm_medium=community&utm_campaign=clienttabs_smoke_v1&utm_content=cs_slack

# Paid cold ($150 cap)
?utm_source=reddit_ads&utm_medium=cpc&utm_campaign=clienttabs_smoke_v1&utm_content=us_support_agents
?utm_source=google&utm_medium=cpc&utm_campaign=clienttabs_smoke_v1&utm_content=search_v1
?utm_source=meta&utm_medium=cpc&utm_campaign=clienttabs_smoke_v1&utm_content=interest_cs
```

**Mapping rule (implement in page JS):**

- `utm_medium=warm` → `traffic_class=warm`  
- `utm_medium=cpc` → `traffic_class=ads`  
- `utm_medium=social` or `community` → `traffic_class=social`  
- else → `traffic_class=direct`

### 4.3 Welcome email (Buttondown)

**Subject:** ClientTabs early access — you’re in the loop  

**Body (short):**

> Thanks for joining the ClientTabs early-access list.  
>  
> We’re building a Chrome extension that restores client-specific tab workspaces in one click—for support agents who jump between SaaS customers all day.  
>  
> The product isn’t shipping yet. Planned pricing starts from $9/month; we’ll email before anything is charged.  
>  
> Reply with one line if you want: what’s the most annoying part of rebuilding client context today?  
>  
> — [Founder name]

---

## 5. Implementation notes

### 5.1 Stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Host | **Cloudflare Pages** | Deploy `landing/` as static site |
| Form / email | **Buttondown** | Embed subscribe endpoint + tags/metadata |
| Analytics | **Plausible** | Goals: `cta_click`, optional `waitlist_attempt` |
| Domain | Founder-owned | Point DNS per Cloudflare Pages docs |
| Repo artifact | `landing/index.html` | Single-file, no product app |

### 5.2 Files

| Path | Role |
|------|------|
| `landing/index.html` | Full smoke landing (copy + form + UTM JS + Plausible hooks) |
| `docs/smoke/clienttabs-20260801.md` | This protocol |

### 5.3 Placeholders (replace before traffic)

| Placeholder | Where |
|-------------|--------|
| `YOUR_BUTTONDOWN_USERNAME` | Form `action` URL |
| `YOUR_PLAUSIBLE_DOMAIN` | Plausible `data-domain` |
| `YOURDOMAIN` / contact email | Footer, meta canonical |
| Founder name | Welcome email |

Missing IDs are **not** a reason to delay the HTML file; they **are** a reason not to claim the services are live until wired and preflighted.

### 5.4 Buttondown form contract (native POST)

```html
<form
  action="https://buttondown.com/api/emails/embed-subscribe/YOUR_BUTTONDOWN_USERNAME"
  method="post"
  class="waitlist-form"
>
  <input type="email" name="email" required autocomplete="email" />
  <!-- Optional free-text: send as metadata if account supports it; else append via tag workflow -->
  <input type="hidden" name="tag" id="bd-tag" value="smoke-direct" />
  <input type="hidden" name="metadata__utm_source" id="m-utm-source" value="" />
  <input type="hidden" name="metadata__utm_medium" id="m-utm-medium" value="" />
  <input type="hidden" name="metadata__utm_campaign" id="m-utm-campaign" value="" />
  <input type="hidden" name="metadata__utm_content" id="m-utm-content" value="" />
  <input type="hidden" name="metadata__traffic_class" id="m-traffic-class" value="direct" />
  <input type="hidden" name="metadata__smoke_id" value="clienttabs_20260801" />
  <button type="submit">Join the early-access waitlist</button>
</form>
```

If metadata field names differ in your Buttondown plan, use **distinct embed forms or tags per traffic class** so confirmed subscribers remain class-attributable. **Verify with a real valid submission before Day 1.**

### 5.5 Deploy checklist (Day 0)

1. Create Buttondown newsletter + tags `smoke-warm`, `smoke-social`, `smoke-ads`, `smoke-direct`.  
2. Create Plausible site; add goals `cta_click`, `waitlist_attempt`.  
3. Replace placeholders in `landing/index.html`.  
4. `wrangler pages deploy landing` (or Git-connected Pages project).  
5. Preflight: valid + invalid email; check tag/metadata; confirm neutral UI (not false success).  
6. Open spreadsheet dashboard.  
7. Only then start Day 1 traffic.

### 5.6 Ad budget controls

- **Hard cap: $150** across all paid channels combined.  
- Prefer **one** platform first (Reddit Ads *or* Google Search *or* Meta)—do not split $50×3 on Day 1.  
- Kill a paid variant after **48h** if CPC is fine but **0** confirmed emails after ≥40 landing visits, or CPE trajectory &gt; $40.  
- Reallocate remaining budget only to the creative/audience that produced confirmed `smoke-ads` emails.

---

## 6. Traffic plan (10 days)

### 6.1 Calendar

| Day | Window | Channel | Action | UTM / class | Notes |
|-----|--------|---------|--------|-------------|-------|
| **0** | Setup | — | Deploy page, wire Buttondown + Plausible, preflight attribution | — | **No public traffic** until preflight passes |
| **1** | Warm | Personal DMs / email | 10–15 short notes to known CS/support agents or small-SaaS operators | `utm_medium=warm` · `smoke-warm` | **Log separately.** Ask for honest “would you use this?” not favors only |
| **2** | Warm + Social | Finish warm → 15–25 total; first X post | Pain story + soft CTA | `twitter` / `social` | Pin link during smoke |
| **3** | Social | X thread #2; Reddit research | Value-first; read sub rules | prepare `reddit` links | Do not blast identical posts |
| **4** | Social | Reddit post #1 | e.g. r/CustomerSuccess or r/saas — feedback framing, disclose maker | `reddit` + sub in `utm_content` | Engage every comment same day |
| **5** | Social + Ads start | Indie Hackers milestone; **start ads with ≤ $40** | IH: “smoke testing unbuilt extension” | `indiehackers`; ads `cpc` | Ads geo: US; age/roles toward support/CS if available |
| **6** | Ads + Social | Optimize/kill ads; Reddit post #2 **only if** post #1 not removed | Second angle: time cost of tab rebuild | class preserved | Cap daily ad spend so total ≤ $150 |
| **7** | Ads + Warm follow-up | Continue winner ads; 5 warm follow-ups (non-responders) | warm vs ads **separate sheets** | No new headline on ads and organic same day |
| **8** | Social | X recap / builder note; optional niche Slack **with permission** | `slack_community` | No spam blasts |
| **9** | Close | Stop new spend by EOD; final organic reply pass | — | Leave page up; stop pushing |
| **10** | Decision | Compute **per-class** CVR + CPE + replies | — | Apply §2.5; never pool warm+cold |

### 6.2 Channel posts (drafts)

#### Warm DM (template)

> Hey {Name} — quick ask, not a pitch deck. I’m testing an unbuilt Chrome extension for support agents who rebuild the same client tabs all day. Idea: save a tab workspace per client, restore in one click. Planned ~$9/mo if it ships.  
>  
> Would you glance at this and tell me if the problem is real for you?  
> {link with warm UTM}  
> Totally fine if it’s a “no.”

#### X — Post 1 (problem)

> Support agents don’t just switch tickets. They rebuild browsers.  
>  
> Client A: admin + billing + status.  
> Client B: different stack.  
> Client A again: start from zero.  
>  
> I’m testing ClientTabs — one-click restore of client-specific tab workspaces. Unbuilt. Early-access waitlist. Planned from $9/mo.  
>  
> If that’s your day, I want the signal:  
> {twitter UTM link}

#### X — Thread 2 (founder honesty)

> Day N of a 10-day demand test. No product yet on purpose.  
>  
> Promise: one-click context restore per client.  
> CTA: Join the early-access waitlist.  
> Price signal: from $9/month planned.  
>  
> Agents only, please — tire-kickers dilute the test.  
> {link}

#### Reddit (feedback framing)

**Title:** [Feedback] Would you use a Chrome extension that restores a full tab set per client (support agents)?  

**Body:**

> I work adjacent to small SaaS support teams. The pattern I keep seeing: agents rebuild the same client tabs between tickets—admin, billing, status pages—dozens of times a day. Bookmarks help a little; they don’t restore a *named client workspace* in one click.  
>  
> I’m validating an unbuilt extension (“ClientTabs”) before writing it: save tabs per client → restore in one click. Planned pricing from $9/month. Honest early-access waitlist only—no fake users, no ship date.  
>  
> Questions for agents:  
> 1) How do you handle client context in Chrome today?  
> 2) Is “one-click restore per client” worth $9/mo if it worked, or is this a nothing-burger?  
>  
> Landing (maker, demand test): {reddit UTM link}  
>  
> Happy to take critical feedback.

**Do:** Disclose maker; follow sub rules; engage.  
**Don’t:** Multi-sub identical spam; fake “a friend built this”; buy upvotes.

#### Indie Hackers

**Title:** Smoke test: unbuilt Chrome extension for support agents’ client tab workspaces  

Share hypothesis, $150 ad cap, 10-day clock, and that warm vs cold will not be pooled. Ask for channel critique, not vanity praise.

#### Ads (single ICP)

- **Audience:** US; interests/jobs around customer support, customer success, SaaS; exclude pure consumer.  
- **Primary text:** “Rebuild client tabs between every ticket? ClientTabs (in development) restores each client’s workspace in one click. Early-access waitlist. Planned from $9/mo.”  
- **CTA button:** Learn more → landing with `utm_medium=cpc`  
- **Matching:** Ad promise = hero promise (one-click client restore).  
- **Budget:** Start ≤ $20–40; scale only if confirmed `smoke-ads` emails appear; hard stop at $150.

### 6.3 Channels intentionally limited

| Included | Excluded this window |
|----------|----------------------|
| Warm DM, X, Reddit, IH, one paid platform | Product Hunt (no showable product moment), broad TikTok, SEO content program, affiliate, fake traffic |

---

## 7. What we will NOT build during the smoke

- The Chrome extension (background scripts, sync, Web Store listing)  
- Auth, teams, SSO, admin dashboards  
- AI summarization, ticket tooling, helpdesk integrations  
- Multi-page marketing site, blog, brand system  
- Payment / Stripe checkout (price is a **signal**, not a charge)  
- Fake demo video, fake testimonials, logo walls, waitlist counters  
- Custom backend beyond Buttondown + Pages + Plausible  

**Allowed:** copy tweaks (one headline variant max if cold CVR is weak after Day 5 minima), tracking fixes, welcome-email edits.

---

## 8. After the smoke

| Outcome | Next step |
|---------|-----------|
| **Strong** | `z-write-prd` for a **thin** MVP: named client workspaces + save/restore only; optional 5 user interviews from waitlist |
| **Mixed — weak offer** | New hero (variant 2 or 3); keep ICP; 5-day cold retest; still no extension |
| **Mixed — silent list** | `z-customer-discovery` on waitlist; build only if pain is frequent and budgeted |
| **Weak** | Reshape ICP (e.g. onboarding specialists vs support) or park; do not “just build it anyway” |
| **Distribution failure** | Fix access to agents (communities, partnerships); re-run smoke before product code |

### Top 3 actions today

1. Replace Buttondown + Plausible + domain placeholders in `landing/index.html` and deploy to **Cloudflare Pages**.  
2. Preflight **valid/invalid** subscribe paths; confirm `smoke-*` tags + UTM metadata on confirmed subscribers.  
3. Send the first **10 warm DMs** with warm UTMs only—and open the **three-class** spreadsheet.

### What not to build yet

Any extension code, store assets, or multi-feature roadmap. The smoke answers “do agents care?” not “can we ship v1 architecture?”

### Related skills later

- Strong signal → `z-write-prd`  
- Need sharper language from real agents → `z-customer-discovery`  
- Broader market doubt → `z-market-validate`  
- SEO only after a real product URL exists → `z-seo-plan`

---

## Quality bar (self-check)

- [x] Clear ICP + single promise (one-click client tab workspace restore)  
- [x] One primary CTA: **Join the early-access waitlist**  
- [x] Hypothesis + numeric success/kill + 10-day timebox  
- [x] Full English copy + meta/OG + 3 headlines  
- [x] Form/events/UTMs; conversion = Buttondown confirmed only  
- [x] Neutral success UI for cross-origin form  
- [x] Source-specific CVR with subscriber attribution (tags + metadata)  
- [x] **Never pool warm with cold**  
- [x] Traffic calendar ≥ 3 channels + $150 ad cap  
- [x] Explicit non-build list  
- [x] No testimonials, logos, user counts, firm ship date  
- [x] Deployable `landing/index.html` materialized  
