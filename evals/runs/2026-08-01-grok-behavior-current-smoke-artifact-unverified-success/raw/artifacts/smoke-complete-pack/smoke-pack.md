# Landing smoke test: ClientTabs

## Contents

1. Hypothesis
2. Metrics and decision rules
3. Landing-page copy
4. Form and tracking
5. Implementation notes
6. Traffic plan
7. Explicit non-build scope
8. Evidence handoff

| Field | Value |
|-------|--------|
| **Date** | 2026-08-01 |
| **Timebox** | 10 days (2026-08-01 → 2026-08-10) |
| **ICP** | Hands-on support agents and support leads at small US SaaS teams (≈5–50 employees) who juggle multiple client contexts in Chrome |
| **CTA type** | Early-access waitlist |
| **Primary CTA label** | Join the early-access waitlist |
| **Page language** | English |
| **Stack** | Cloudflare Pages (static) + Buttondown (waitlist) + Plausible (analytics) |
| **Price signal** | Planned from $9/month (honest intent; not a live charge) |
| **Ad cap** | $150 total paid media |
| **Product stage** | Unbuilt Chrome extension — demand smoke only |

## 1. Hypothesis

If we offer **one-click restore of client-specific tab workspaces** to **hands-on support agents at small US SaaS teams** via an **early-access waitlist** with a **planned price from $9/month**, then within **10 days**:

- **Cold paid (ads)** visitor → confirmed-email CVR will be **≥ 2.5%** after **≥ 80** ad-attributed qualified visits, **or** cost per confirmed email **≤ $6**.
- **Cold community / social** (Reddit, X, Indie Hackers) visitor → confirmed-email CVR will be **≥ 4%** after **≥ 100** combined cold organic visits (report per source; do not pool with warm).
- **Warm outreach** (personal DMs / known contacts) visitor → confirmed-email CVR will be **≥ 12%** after **≥ 25** warm visits, **or** **≥ 5** confirmed signups with **≥ 2** substantive replies describing client-tab pain.

**Never pool warm outreach with cold traffic** for headline CVR, success bars, or kill decisions. Each source class keeps its own numerator (provider-confirmed subscribers with matching traffic class) and denominator (qualified unique pageviews with matching UTM / traffic class).

## 2. Metrics & decision rules

### Metric definitions

| Metric | Definition | Source of truth |
|--------|------------|-----------------|
| Unique visitors (by source) | Unique pageviews on landing, segmented by `utm_source` / derived traffic class | Plausible |
| CTA clicks | Clicks on primary CTA (`click_cta`) | Plausible custom event |
| Attempted submits | Form submit handler fired (`attempt_waitlist`) — **not** a conversion | Plausible custom event |
| Confirmed emails / waitlist | Buttondown **accepted** subscriber (or verified success redirect) with traffic class metadata | Buttondown export |
| Visitor → email CVR (by source) | Confirmed emails ÷ unique visitors **for the same source class only** | Plausible + Buttondown join on traffic class |
| Welcome open rate | Opens on welcome / “you’re in” email (diagnostic only) | Buttondown |
| Intent signals | Replies, “I’d pay”, detailed pain answers in optional field | Inbox + form notes |
| Revenue | $0 expected (no charge in this test) | N/A |
| Cost per confirmed email (ads) | Ad spend ÷ ad-attributed confirmed emails | Ad platform + Buttondown |

### Event integrity

| Event name | When it fires | Counts as conversion? |
|------------|---------------|------------------------|
| `view_landing` | Landing page load | No |
| `click_cta` | Primary CTA click (nav, hero, final) | No |
| `attempt_waitlist` | User submits form (client-side) | No |
| `submit_waitlist` | **Only** after Buttondown-confirmed accept or controlled success redirect (`?status=subscribed`) | **Yes** |

Invalid, rejected, duplicate, or merely attempted submissions are **not** conversions. Do not show “You’re on the list” from the submit handler alone.

### Source classes (keep separate forever)

| Class | `utm_source` examples | `utm_medium` | Quality note |
|-------|----------------------|--------------|--------------|
| **Warm outreach** | `dm`, `warm_email`, `friend` | `referral` | Highest intent; separate dashboard row |
| **Cold social** | `twitter`, `x` | `social` | Cold; own CVR |
| **Cold community** | `reddit`, `indiehackers` | `community` | Cold; own CVR per sub-source preferred |
| **Cold paid** | `google`, `reddit_ads`, `x_ads` | `cpc` | Cold; own CVR + CPE |
| **Direct / unknown** | (none) | (none) | Report separately; do not assign to warm or cold |

### Source-specific thresholds (pre-registered)

| Source class | Min sample before decide | Success bar | Kill / pivot bar (after min sample) |
|--------------|--------------------------|-------------|-------------------------------------|
| Warm outreach | ≥ 25 unique visits **and** ≥ 5 days of outreach | CVR ≥ 12% **or** ≥ 5 confirmed + ≥ 2 pain-rich replies | CVR &lt; 6% **and** 0 substantive replies → rewrite ask / ICP, do not blame cold channels |
| Cold social (X) | ≥ 40 unique visits | CVR ≥ 4% | CVR &lt; 1.5% after 2 post angles → stop X spend of time; keep as low-effort only |
| Cold community (Reddit / IH) | ≥ 60 unique visits combined, prefer per-sub ≥ 30 | CVR ≥ 4% **or** ≥ 3 qualified “I’d use this” replies | CVR &lt; 1.5% **and** hostile/no-fit feedback → reshape ICP language |
| Cold paid (ads) | ≥ 80 unique visits **or** $80 spent (first gate at 48–72h) | CVR ≥ 2.5% **or** CPE ≤ $6 | CVR &lt; 1% **or** CPE &gt; $12 after $80+ → kill that creative/audience; total ad cap **$150** |
| Aggregate (informational only) | — | Do **not** use pooled warm+cold CVR for go/kill | — |

### Overall decision matrix (after day 10 or earlier if a class hits kill)

| Result | Criteria (examples) | Next step |
|--------|---------------------|-----------|
| **Strong** | ≥ 2 cold classes meet success **or** warm success + ≥ 1 cold class success; plus ≥ 3 intent replies | Proceed to thin MVP / `z-write-prd` for Chrome extension MVP only |
| **Mixed — rewrite offer** | Traffic OK by class, cold CVR weak, little objection clarity | Rewrite hero/promise; retest **same** cold channels 5 days; do not build product |
| **Mixed — soft demand** | CVR OK by class, **zero** engagement after welcome + 1 follow-up | Interview waitlist (Mom Test) before writing extension code |
| **Paid intent signal** | Any unprompted “invoice me” / “take my card” / clear $9 fit | Prioritize paid slice design; still do not build full product |
| **Weak / park** | After min samples, cold CVR below kill **and** warm below kill | Park or reshape ICP; do **not** “add features” to the unbuilt extension |
| **Distribution fail** | Cannot reach min visits on any cold class despite honest push | Fix distribution thesis; product thesis remains untested |

### Dashboard (spreadsheet columns)

Date | Source class | utm_source | Unique visitors | CTA clicks | Attempts | Confirmed emails | CVR | CPE (ads) | Replies | Notes

**Rule:** never average warm CVR into cold CVR for a single “overall conversion rate” decision.

## 3. Landing page copy (English)

### Meta

- **Title:** ClientTabs — One-click client tab workspaces for support agents
- **Description:** Restore every client’s tabs, docs, and tools in one click. Early access for hands-on support agents at small US SaaS teams. Planned from $9/month. Join the waitlist.
- **OG title:** ClientTabs — restore client context in one click
- **OG blurb:** A Chrome extension for support agents who lose minutes every ticket reopening the same client tabs. One-click workspace restore. Early-access waitlist. Planned from $9/month. Not shipping yet — validating demand first.
- **OG image note:** Simple text card: product name + “One-click client tab restore” + “Early access · from $9/mo” (no fake UI screenshots of a live product).

### Headline variants

1. **(Ship this)** One-click client tab workspaces for support agents  
2. Stop rebuilding the same client tabs on every ticket  
3. Client context back in one click — built for SaaS support desks  

### Full page

#### Nav

- **Product name:** ClientTabs  
- **CTA button:** Join the early-access waitlist  

#### Hero

- **Eyebrow:** Chrome extension · Early access · Planned from $9/month  
- **H1:** One-click client tab workspaces for support agents  
- **Subhead:** Hands-on support at small US SaaS teams juggles a different browser mess for every client. ClientTabs is being designed to save and restore that full tab workspace in one click — so you get context back without the scavenger hunt.  
- **Price chip:** Planned pricing from $9/month  
- **Primary CTA:** Join the early-access waitlist  
- **Honesty line:** Unbuilt product. We’re validating demand with real support agents before we write the extension. No ship date promised.  

#### Problem / status quo

**Every client is a different pile of tabs.**

- You reopen the same CRM record, status page, runbook, Loom, and Slack thread — ticket after ticket.  
- Context switches between clients cost minutes and raise “wrong account” risk.  
- Bookmarks and “pin these tabs” notes don’t travel with the ticket or the shift handoff.  

#### Solution (3 steps)

1. **Save a client workspace** — Capture the tab set that belongs to one customer or account.  
2. **Label it for the desk** — Name it by client so anyone on the team can find it.  
3. **Restore in one click** — Open that full context when the next ticket for that client lands.  

No feature laundry list. One job: **client-specific tab context, restored fast.**

#### Who it’s for / not for

**For**

- Hands-on support agents and player-coach leads at small US SaaS teams  
- People who live in Chrome across many accounts daily  
- Teams that already feel the cost of “rebuild the tabs” every shift  

**Not for**

- Casual personal bookmarking or student research setups  
- Enterprises needing SSO rollout, SCIM, and a 6-month security review before a smoke test  
- Anyone looking for a full helpdesk, CRM, or session-replay product  

#### Proof (honest)

- No testimonials, logos, or user counts — none exist yet.  
- **Founder note:** “I’m testing whether support agents care enough about one-click client tab restore to join an early-access list at a planned $9/month price before any Chrome code ships.”  
- Optional placeholder: short demo storyboard / GIF later — not required for this smoke.  

#### Offer / CTA block

- **Offer:** Early-access waitlist for founding support users  
- **What you get:** Product progress notes, a chance to shape the first useful version, and founding-price consideration when paid plans open (planned from $9/month)  
- **What you don’t get:** A live extension today, a guaranteed launch date, or fake scarcity  
- **CTA:** Join the early-access waitlist  
- **Optional one-field qualifier:** “Biggest client-context pain this week?” (quality over volume; may lower CVR)  

#### FAQ

1. **Is ClientTabs live?**  
   No. This page is a demand smoke test for an unbuilt Chrome extension.

2. **When will it ship?**  
   No firm ship date. If waitlist interest is real, we’ll define a thin MVP next — not before.

3. **What does “from $9/month” mean?**  
   Planned pricing signal for a simple individual/seat plan. Not a charge today. Final packaging may change based on what founding users need.

4. **How will my email be used?**  
   Waitlist updates and occasional product questions only. Stored in Buttondown. Not sold.

5. **Who is this not for?**  
   Not a general “tab manager for everyone.” If you don’t handle multiple client contexts as a support agent, this list isn’t for you.

6. **What happens after I join?**  
   Confirmation depends on the email provider accepting your address. You’ll get a short welcome note when accepted. Unsubscribe anytime.

#### Final CTA + footer

- **Headline:** Want client context back in one click?  
- **CTA:** Join the early-access waitlist  
- **Footer:** ClientTabs · Built by an independent developer · Contact: `hello@YOUR_DOMAIN` · Privacy: email used only for waitlist updates; no selling lists · Cloudflare Pages host  

## 4. Form & tracking

| Item | Spec |
|------|------|
| Fields | `email` (required); optional `tag` / notes: “Biggest client-context pain this week?”; hidden `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `traffic_class` |
| Provider | Buttondown embed/API subscribe form |
| Success message | On controlled redirect `?status=subscribed`: “You’re on the early-access list — check your inbox.” On unverified cross-origin attempt only: “Submission sent — check your inbox if the provider accepts it.” |
| Events | `view_landing`, `click_cta`, `attempt_waitlist`; fire `submit_waitlist` **only** on verified success redirect or server-confirmed path |
| Successful-conversion source of truth | Buttondown confirmed subscriber record (primary); optional success redirect as UX only |
| Confirmed-conversion attribution | Persist UTM + `traffic_class` into Buttondown metadata / tags (`warm`, `cold_social`, `cold_community`, `cold_paid`, `unknown`). Verify with one real valid submission per class before buying ads. |
| Consent | Single opt-in OK for this US-leaning B2B smoke if Buttondown + privacy line present; switch to double opt-in if deliverability suffers |
| Analytics | Plausible: pageviews + custom events above; no cookie banner theater if Plausible is cookieless as configured |
| UTM scheme | See below |

### UTM scheme

Base: `https://YOUR_DOMAIN/` (Cloudflare Pages URL until custom domain)

```text
# Warm (never mix into cold reports)
?utm_source=dm&utm_medium=referral&utm_campaign=smoke_v1&utm_content=personal
?utm_source=warm_email&utm_medium=referral&utm_campaign=smoke_v1&utm_content=known_contact

# Cold social
?utm_source=twitter&utm_medium=social&utm_campaign=smoke_v1&utm_content=thread_pain
?utm_source=twitter&utm_medium=social&utm_campaign=smoke_v1&utm_content=bip_update

# Cold community
?utm_source=reddit&utm_medium=community&utm_campaign=smoke_v1&utm_content=r_saas
?utm_source=reddit&utm_medium=community&utm_campaign=smoke_v1&utm_content=r_customercare
?utm_source=indiehackers&utm_medium=community&utm_campaign=smoke_v1&utm_content=milestone

# Cold paid ($150 cap)
?utm_source=reddit_ads&utm_medium=cpc&utm_campaign=smoke_v1&utm_content=care_agents
?utm_source=x_ads&utm_medium=cpc&utm_campaign=smoke_v1&utm_content=support_icp
?utm_source=google&utm_medium=cpc&utm_campaign=smoke_v1&utm_content=exact_intent
```

**traffic_class mapping (hidden field + Buttondown tag):**

| traffic_class | When |
|---------------|------|
| `warm` | utm_medium=referral and source dm/warm_email/friend |
| `cold_social` | utm_medium=social |
| `cold_community` | utm_medium=community |
| `cold_paid` | utm_medium=cpc |
| `unknown` | no UTM |

## 5. Implementation notes

| Item | Spec |
|------|------|
| Host | Cloudflare Pages |
| Domain | Placeholder `YOUR_DOMAIN` (Pages `*.pages.dev` OK for smoke) |
| Email | Buttondown — placeholder `BUTTONDOWN_USERNAME` |
| Analytics | Plausible — placeholder `PLAUSIBLE_DOMAIN` |
| Deployable file | `artifacts/landing/index.html` (materialized) |
| Pre-order processor | None (waitlist only; no Stripe this test) |

### Build path (Tier C)

1. Create Buttondown account + publication; note embed username.  
2. Create Plausible site for the Pages hostname.  
3. Replace placeholders in `artifacts/landing/index.html`: `BUTTONDOWN_USERNAME`, `PLAUSIBLE_DOMAIN`, `YOUR_DOMAIN`, `hello@YOUR_DOMAIN`.  
4. Deploy folder `artifacts/landing/` to Cloudflare Pages (production branch).  
5. Send **one valid** and **one invalid** test submission; confirm only valid lands in Buttondown with UTM metadata.  
6. Confirm success redirect `?status=subscribed` shows confirmed copy and fires `submit_waitlist` once.  
7. Open Plausible; verify `view_landing`, `click_cta`, `attempt_waitlist`.  
8. Only then start traffic calendar and ads.

### Placeholders still requiring user credentials

- `BUTTONDOWN_USERNAME`  
- `PLAUSIBLE_DOMAIN`  
- `YOUR_DOMAIN` / Cloudflare Pages project  
- `hello@YOUR_DOMAIN` contact address  
- Ad account(s) for up to $150 spend  

**Do not claim external services are wired until placeholders are replaced and a real valid submission is verified.**

### Form behavior (truthful UX)

- Native POST to Buttondown embed subscribe URL with `redirect` back to the landing URL + `?status=subscribed`.  
- Client submit handler: fire `attempt_waitlist` only; do **not** claim success.  
- If `status=subscribed` present on load: show confirmed success state + fire `submit_waitlist` once (session-guarded).  
- Conversion reporting for decisions: Buttondown export tagged by `traffic_class`, not Plausible attempt counts.

## 6. Traffic plan

**Timebox:** 10 days · **Paid cap:** $150 · **Channels (4):** Warm DMs, X/Twitter, Reddit (+ optional IH), small ads  

### Day-by-day calendar

| Day | Window | Channel | Action | UTM | Budget | Notes |
|-----|--------|---------|--------|-----|--------|-------|
| 1 | AM | Setup | Deploy Pages; wire Buttondown + Plausible; test valid/invalid submit + attribution | — | $0 | Block traffic until attribution works |
| 1 | PM | Warm | 8 personal DMs to known support agents / leads | `utm_source=dm&utm_medium=referral&utm_campaign=smoke_v1&utm_content=personal` | $0 | Track as **warm only** |
| 2 | AM | X | Pain-story thread (no hard sell in first tweets) + link in final tweet | `utm_source=twitter&utm_medium=social&utm_campaign=smoke_v1&utm_content=thread_pain` | $0 | Cold social |
| 2 | PM | Warm | 7 more DMs | same warm UTM | $0 | Cap ~20–25 total warm over test |
| 3 | AM | Reddit | Value-first post in buyer-ish sub (e.g. SaaS / customer success / support) — read rules; disclose maker | `utm_source=reddit&utm_medium=community&utm_campaign=smoke_v1&utm_content=r_saas` | $0 | Soft CTA; engage every comment |
| 3 | PM | X | Build-in-public: “smoke testing unbuilt extension” + link | `utm_source=twitter&utm_medium=social&utm_campaign=smoke_v1&utm_content=bip_update` | $0 | Cold social |
| 4 | All | Ads start | One ICP, one geo (US), one creative, one landing promise | `utm_source=reddit_ads` or `x_ads` / `utm_medium=cpc` / `utm_campaign=smoke_v1` | **$40** | Kill creative if CPE hopeless at 48h |
| 5 | AM | Reddit | Second sub **only if** Day 3 not removed; different angle, not copy-paste spam | `utm_content=r_customercare` | $0 | Cold community |
| 5 | PM | Ads | Continue winner only; pause loser | cpc UTMs | **$30** | Stay inside $150 |
| 6 | AM | Indie Hackers | Milestone: demand smoke for support Chrome wedge | `utm_source=indiehackers&utm_medium=community&utm_campaign=smoke_v1&utm_content=milestone` | $0 | Share honest stage |
| 6 | PM | Warm | Final 5–8 DMs to ideal ICP not yet pinged | warm UTM | $0 | Still separate reporting |
| 7 | All | Ads | Scale only if CPE ≤ $6 and CVR ≥ 2.5%; else iterate one variable | cpc | **$40** | |
| 8 | AM | X | Reply-heavy day: engage support builders; soft link when relevant | twitter UTM | $0 | Quality &gt; broadcast |
| 8 | PM | Ads | Final paid push or full stop | cpc | **≤ $40** remainder | Total paid ≤ **$150** |
| 9 | All | Follow-up | Welcome sequence check; 1 short reply ask to waitlist (“what tabs do you reopen every ticket?”) | — | $0 | Intent signals |
| 10 | All | Decision | Export Buttondown by traffic_class; fill dashboard; apply source-specific rules | — | $0 | Write Evidence handoff outcomes |

**Total planned ads:** $40 + $30 + $40 + ≤$40 = **≤ $150**.

### Channel posts (drafts)

#### Warm DM (template)

> Hey {Name} — you work hands-on support at a small SaaS team, right? I’m smoke-testing an idea **before** building: a Chrome extension that restores a client’s full tab workspace in one click. Honest page, waitlist only, planned from $9/mo, no ship date. If you have 2 minutes, does this match a real pain? {LINK with warm UTM}

Do: personalize. Don’t: mass BCC or claim fake urgency.

#### X / Twitter — thread outline

1. Support agents don’t lose time to “slow tools” — they lose it reopening the **same client tabs**.  
2. CRM + status page + runbook + billing + Loom… every ticket, every client.  
3. I’m **not** shipping a polished product. I’m testing whether one-click **client workspace restore** is worth an early-access list at **from $9/month**.  
4. If that’s your job, join the early-access waitlist (unbuilt, no fake logos): {cold social UTM link}  
5. What tabs do you reopen on every account?

Do: engage replies same day. Don’t: bot-follow or engagement pods.

#### Reddit — post outline

- **Title angle:** “Support agents: how do you restore a client’s full browser context between tickets?”  
- **Body:** Describe the pain in their words; mention you’re the maker testing a one-click restore idea; disclose early-access waitlist; no fake traction.  
- **Link:** one UTM’d URL.  
- Do: follow sub rules / flair. Don’t: multi-sub identical spam in one hour.

#### Indie Hackers — outline

- Milestone: 10-day landing smoke for ClientTabs.  
- ICP + promise + $9/mo signal + stack (Pages / Buttondown / Plausible).  
- Ask for critique on offer clarity, not vanity upvotes.

#### Ads — creative brief ($150 cap)

- **Audience:** US; interests/jobs around customer support, SaaS, help desk (platform-dependent).  
- **Primary text:** “Reopen the same client tabs every ticket? Early access to a Chrome extension for one-click client workspace restore. Planned from $9/month. Waitlist — product not built yet.”  
- **CTA alignment:** must match page promise (one-click restore + waitlist).  
- **Kill rule:** after ~$40–80, if CVR &lt; 1% or CPE &gt; $12, kill creative or audience; do not “spend the rest to learn nothing.”

### Expected traffic quality notes

| Channel | Quality | Risk |
|---------|---------|------|
| Warm DM | Highest ICP fit | Small N; bias toward politeness signups |
| X | Mixed builders + agents | Tire-kickers if framed as “cool Chrome toy” |
| Reddit | Can be excellent if sub matches buyers | Removal / hostility if salesy |
| Ads | Controllable US cold traffic | Broad targeting wastes the $150 |

## 7. What we will NOT build during the smoke

- The Chrome extension (background scripts, tab APIs, sync, auth)  
- Team admin, SSO, billing, or multi-seat product  
- Fake demo video claiming a live product  
- Multi-page marketing site, blog, or SEO program  
- Custom backend beyond Buttondown + static host  
- A/B infrastructure beyond shipping **one** headline first (variants reserved)  
- Waitlist “social proof” counters or partner logos  

**What not to do with data:** never report a single blended CVR that mixes warm DMs with cold ads/social as the go/kill number.

## 8. Outcome → next step (planning matrix)

| Outcome | Next step |
|---------|-----------|
| Strong | Thin MVP PRD (`z-write-prd`) for restore/save workspace only |
| Mixed — weak CVR | Rewrite hero; retest cold channels; no code |
| Mixed — silent list | 5–8 waitlist interviews before build |
| Weak | Park or reshape ICP; stop extension fantasies |
| Distribution fail | Fix channels; do not interpret as product death |

---

## Evidence handoff

| Field | Value |
|-------|-------|
| Current decision | TBD after test |
| Evidence classes | assumption |
| Supported claims | TBD after test |
| Still unproven | Real demand for one-click client tab restore; willingness to pay $9/month; cold vs warm conversion at pre-registered thresholds; retention; whether a Chrome MVP can deliver the promise; any payment or reply behavior (no results yet) |
| Contradictions / exclusions | TBD after test — pre-register: do not pool warm outreach with cold traffic; do not count attempt_waitlist as conversion; no testimonials/logos/user counts/ship date used as evidence |
| Source anchors | Plan: artifacts/smoke-pack.md (2026-08-01); deployable page artifacts/landing/index.html; post-test: Plausible source breakdown, Buttondown export by traffic_class, ad spend log ≤ $150, day-10 dashboard |
| Next validation | Owner: founder — Day 1 replace placeholders, verify one valid submission per traffic_class tag, then run 10-day calendar; success/fail = source-specific thresholds in §2 (not pooled CVR) |

---

## Postscript (operator checklist)

### Top 3 actions today

1. Replace `BUTTONDOWN_USERNAME`, `PLAUSIBLE_DOMAIN`, and domain/contact placeholders; deploy `artifacts/landing/` to Cloudflare Pages.  
2. Verify attribution: valid submit → Buttondown row with `traffic_class`; success redirect fires `submit_waitlist` only once.  
3. Send first 8 warm DMs **and** schedule Day 2–3 cold posts — track warm and cold in separate spreadsheet rows from minute one.

### What not to build yet

Any Chrome extension code, auth, sync, or billing. This smoke only answers: **do the right people join and talk?**

### Other skills

- Loop `z-market-validate` only if cold channels show confused category language.  
- Loop `z-customer-discovery` if CVR is OK but replies are thin.  
- Loop `z-write-prd` only after Strong or clear paid-intent signal.
