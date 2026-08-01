---
name: z-landing-smoke
description: >-
  Use before building when an independent developer needs a landing-page,
  waitlist, or pre-order demand smoke test. Produces concise copy, one CTA, a
  low-cost traffic plan, and explicit conversion, contact-intent, continue, and
  kill thresholds; includes 落地页 and 等待列表 requests.
---

# Landing Smoke Test

You help **independent developers** validate **real demand before writing a
large codebase**. The mechanism is deliberate and cheap:

1. Ship a **concise English landing page** (not a full product).  
2. Collect **email / waitlist / pre-order** intent.  
3. Drive **small, honest traffic** (PH, Reddit, X, niche communities, tiny ads).  
4. Read **conversion, open rates, replies, prepay** — not vanity visits.  

This is the indie answer to “does anyone actually care?”

## Core thesis (never dilute)

- **Talk is cheap; a form submit or card hold is not.**  
- **Traffic without a clear offer is noise.**  
- **Building features to “feel progress” before a smoke test is usually waste.**  
- One **sharp ICP + one promise + one CTA** beats a kitchen-sink homepage.

## When not to use

- Pure market research with no page intent → `z-market-validate`  
- Full product PRD only → `z-write-prd`  
- SEO content program → `z-seo-plan` (can feed keywords into this page)  
- Polished multi-page marketing site redesign (out of scope for smoke)  

## Output language

- **Landing page copy: English by default** (global smoke test surface).  
- **Experiment plan / notes:** same language as the user (Chinese user → Chinese
  plan OK; page still English unless they explicitly want CN page).  
- If user insists on Chinese page (e.g. CN-only ICP), switch page language and
  note distribution channel changes.

## Non-negotiables

1. **One primary CTA.** Waitlist **or** pre-order **or** “notify me” — not five.  
2. **Honest positioning.** No fake “10,000 customers” social proof.  
3. **Instrument the funnel.** Define events before launch.  
4. **Success and kill criteria in numbers** (even rough).  
5. **Lowest cost stack.** Prefer static/edge host + form provider the user can
   set up in hours, not a custom backend.  
6. **Distribution is part of the skill** — page without traffic plan is incomplete.  
7. **Do not build the product inside this skill** unless user explicitly asks for
   a single-file HTML deliverable only.
8. **Evidence does not upgrade on handoff.** A visit, CTA click, attempted
   submission, confirmed signup, reply, and payment are distinct signals; keep
   upstream assumptions and downstream conclusions labeled.
9. **The handoff is a fixed interface.** End the experiment document with
   exactly one two-column, seven-row Evidence handoff table headed
   `Field | Value` using these exact labels: `Current
   decision`, `Evidence classes`, `Supported claims`, `Still unproven`,
   `Contradictions / exclusions`, `Source anchors`, and `Next validation`.
   The class cell may contain only applicable names from `primary behavior`,
   `observed experiment`, `secondary public`, `search signal`, and `assumption`;
   put metric state and attribution limits in the other fields. Include a class
   only when supplied inputs or actual results in this output belong to it; a
   planned interview, traffic test, or payment ask does not make that class
   current. User-reported funnel counts are `observed experiment`, not `primary
   behavior`; use `primary behavior` only for supplied interview/reply stories.
   Treat the seven labels as literal protocol tokens. In the table's first
   column, write each label as plain text exactly as listed: do not wrap it in
   bold, italics, code, or links; do not add punctuation, translate it, or use a
   synonym. For example, write `| Current decision |`, never
   `| **Current decision** |`.
   Do not add a third evidence-class, metric, status, or detail column; evidence
   classes belong only in the `Evidence classes` value cell.

---

## Workflow

### Phase 0 — Intake (blockers only)

From user materials (idea / PRD / market-validate / SEO plan / repo), lock:

| Field | Why it matters |
|-------|----------------|
| **ICP (narrow)** | Who the headline speaks to |
| **Problem in their words** | Above-the-fold honesty |
| **Promise (outcome)** | What life looks like after |
| **CTA type** | waitlist / early access / pre-order / deposit |
| **Price signal (optional)** | Even “from $X/mo” or “founding $Y” tests willingness |
| **Geography** | Affects channels and page language |
| **Constraints** | No paid ads, no PH, domain ready, stack preference |
| **Timebox** | Default **7–14 days** smoke |

If CTA type missing, **recommend** based on confidence:

| Situation | CTA |
|-----------|-----|
| Idea unproven, free curiosity | Waitlist / email |
| Strong pain, tool-shaped | Early access waitlist + optional “why you need this” field |
| Clear paid category, some proof | Pre-order / founding price / Stripe Payment Link |
| High-touch B2B | “Book a 15-min call” or email + company field |

Ask ≤ 5 questions only if you cannot choose safely; else state assumptions.

### Phase 1 — Experiment design (before copy)

Write a short **Smoke Protocol**:

1. **Hypothesis** — “If we offer X to Y, Z% will leave email / prepay.”  
2. **Primary metric** — e.g. visitor → email rate; or visitor → paid hold.  
3. **Secondary metrics** — email open (if welcome sequence), reply rate, refund
   requests, “how did you hear”.  
4. **Sample plan** — target **N qualified visitors** and **M conversions** per
   meaningful traffic class before deciding (see `references/metrics-guide.md`).
   Do not pool warm DMs with cold ads into one headline rate.
5. **Success bar** — pre-register a source-specific threshold based on traffic
   intent and CTA friction. Treat reference ranges as directional, not universal.
6. **Kill / pivot bar** — require a minimum sample and conversion count. For
   example, after 200+ qualified visits across two controlled copy variants,
   sustained &lt;1–2% email CVR is evidence to reshape the offer—not proof that
   the entire problem is dead.
7. **Timebox** — start/end dates; no infinite “soft launch”.  

Indie default: **optimize for learning speed**, not brand perfection.

### Phase 2 — Landing page information architecture

Keep to **one scrollable page** (mobile-first). Required sections:

| Section | Purpose |
|---------|---------|
| **Nav (minimal)** | Product name + CTA button only |
| **Hero** | ICP + problem + outcome + primary CTA + optional price chip |
| **Problem / status quo** | Make pain concrete (3 bullets max) |
| **Solution** | How it works in 3 steps (no feature dump) |
| **Who it’s for / not for** | Sharpen ICP; reduce junk signups |
| **Proof (honest)** | Demo GIF placeholder, founder note, waitlist count if real |
| **Offer** | Waitlist perks / founding price / ship window |
| **FAQ** | 4–6 objections (price, privacy, timeline, “is it built?”) |
| **Final CTA** | Repeat primary action |
| **Footer** | Contact, privacy one-liner, “Built by …” |

Optional: comparison table vs status quo (Excel / agency / competitor category).

**Visual bar:** clean, fast, readable. No stock-photo carousel, no 12 fonts.
If generating HTML, use simple system font stack + strong contrast.

### Phase 3 — Write English copy

Rules:

- **Specific &gt; clever.** Name the user and the job.  
- **Outcome in the first screen.**  
- **One metaphor max.**  
- **CTA verb = next step** (“Join the waitlist”, “Get early access”, “Pre-order — $29”).  
- Optional **one-field qualifier** on form (“Biggest pain today?”) — increases
  quality, may lower CVR; state the tradeoff.  
- **Honesty about stage:** “In development — shipping to founding users [month]”
  if true. Fake “live product” screenshots are banned.

Produce:

1. **Final page copy** (section by section)  
2. **Meta title + meta description** (English)  
3. **OG blurb** for social shares  
4. **3 headline variants** (A/B later; ship one first)  

Use `references/copy-patterns.md` for structures.

### Phase 4 — Implementation pack (lowest cost)

Deliver a **build path** tailored to user constraints. Prefer in order:

| Tier | Stack | When |
|------|--------|------|
| **A** | Single `index.html` + Formspree/Basin/Getform/Google Form embed | Fastest learning |
| **B** | Carrd / Framer / Typedream + native email | Non-dev preferred |
| **C** | Static on Cloudflare Pages / Vercel + Resend/Buttondown/Mailchimp | Dev already in repo |
| **D** | Stripe Payment Link / Lemon Squeezy for pre-order | Testing pay intent |

Always specify:

- Form fields (email required; name optional; UTM or “source” hidden field)  
- Success state copy that matches what the integration can prove. Use
  “You’re on the list — check inbox” only after a verified provider callback or
  controlled success redirect. For a fire-and-forget cross-origin form, use a
  neutral attempt acknowledgement such as “Submission sent — check your inbox
  if the provider accepts it.”
- Consent flow: choose single vs double opt-in from jurisdiction, provider
  policy, deliverability, and list-quality needs—not speed alone
- Privacy: where email is stored; no selling list  
- Analytics: Plausible/Umami/GA4/page view + conversion event (pick one simple)  
- UTM scheme: `utm_source`, `utm_medium`, `utm_campaign` per channel  

Make the conversion event match the metric definition. Count a waitlist
conversion only after the form provider confirms acceptance; invalid, rejected,
or merely attempted submissions are not conversions. With a native cross-origin
form that exposes no reliable success callback, use the provider's confirmed
subscriber record as the source of truth and do not fire a client-side success
event from the submit handler. Do not show confirmed-success UI from that
handler either; the visible state must not claim more than the integration can
prove. See `references/metrics-guide.md`.

If decisions use source-specific CVR, confirmed conversions must remain
attributable to the same source classes as pageviews. Preserve UTMs or a derived
traffic class in provider-supported subscriber metadata, or use distinct
provider-native forms/tags per source class. Test that attribution survives a
real valid submission before traffic. If the provider cannot preserve it, do
not claim source-specific conversion rates; change the capture design first.

If the user asks to **create, build, implement, or deliver a complete package**
in a writable workspace, materialize the smallest deployable landing artifact
(for example `landing/index.html`) in addition to the experiment document. Do
not leave that artifact as an offered “next step.” A copy/spec-only response is
appropriate only when the user asks for a plan, copy, or recommendations.

Missing provider IDs or domains are not a reason to defer the file: use obvious
non-secret placeholders, list them in the handoff, and never claim the external
service is wired until it is. Create **minimal files only** — **no product app
scaffolding**.

### Phase 5 — Traffic plan (required deliverable)

Design a **7–14 day** distribution plan. Quality &gt; spray.

**Channel playbook** (pick 3–5 max for the timebox):

| Channel | How to smoke-test honestly |
|---------|----------------------------|
| **X / Twitter** | 3–5 posts: problem story, founder build-in-public, soft CTA; engage replies |
| **Reddit** | Value-first post in **buyer** subreddit; disclose founder; follow rules or get banned |
| **Product Hunt** | Only if asset is showable; treat as spike day + follow-up; not day-0 mandatory |
| **Indie Hackers / forums** | Milestone post + ask for critique |
| **Niche Slack/Discord** | Ask permission; no blast spam |
| **Small ads** | $20–100 total test: one ICP, one creative, one landing; kill losers in 48h |
| **Warm network** | 20 personal DMs to ideal users with genuine ask |

For each chosen channel provide:

- Post outline / angle  
- Link with UTM  
- Expected traffic quality notes  
- Do / don’t (especially Reddit/PH etiquette)  

See `references/distribution-playbook.md`.

### Phase 6 — Measurement & decision rules

Define a **simple dashboard** (spreadsheet is fine):

| Metric | Definition |
|--------|------------|
| Unique visitors | |
| CTA clicks | |
| Emails / waitlist | |
| Visitor → email CVR | |
| Welcome email open rate | if sent |
| Replies / “I’d pay” messages | qualitative gold |
| Pre-orders / $ | if applicable |
| Traffic by source | UTM |

**Decision matrix** (tune numbers to context; always state yours):

| Result | Next step |
|--------|-----------|
| Strong CVR + engaged replies | Proceed to thin MVP / `z-write-prd` tighten |
| Traffic OK, CVR weak | Rewrite offer/hero; retest same channels |
| CVR OK, no engagement | Soft demand; interview waitlist before building |
| Paid intent appears | Prioritize paid MVP slice |
| Nothing after honest push | Park or reshape ICP — do not “build more features” |

### Phase 7 — Deliver package

Use `references/smoke-pack-template.md`. Pass `references/quality-bar.md`.

Do not rename the seven Evidence handoff rows into metric-specific fields. Put
warm/cold results, invalid events, and provider exports inside the fixed rows.
Do not decorate the fixed first-column labels with Markdown; decoration changes
the machine-readable interface even when rendered text looks similar.

**Deliverables (all of them):**

1. Smoke protocol (hypothesis, metrics, kill criteria, timebox)  
2. English landing copy + meta/OG + headline variants  
3. Implementation pack (stack + form + events + UTMs)  
4. Single-file HTML when useful or requested; **required** for create/build/
   implement/complete-package requests in a writable workspace
5. Traffic calendar (day-by-day or channel checklist)  
6. Decision rules  
7. Evidence handoff; before results exist, mark result-dependent fields
   `TBD after test` instead of filling them from the hypothesis

**Delivery location:**

- Chat by default  
- In repo: `docs/smoke/<slug>-<YYYYMMDD>.md` and optionally `landing/` or path user names  

Postscript in chat:

- Top 3 actions today  
- What **not** to build yet  
- Whether to loop `z-market-validate` / `z-seo-plan`  

---

## Collaboration with other zstack skills

| Skill | Role |
|-------|------|
| `z-market-validate` | Upstream demand language; disconfirming signals → FAQ & “not for” |
| `z-customer-discovery` | User phrases + real pain stories for copy; interviews explain smoke results |
| `z-write-prd` | Optional: only after smoke shows care — or thin PRD before smoke if needed |
| `z-seo-plan` | Optional keywords for hero/H1; smoke traffic is mostly **social/community**, not SEO |

**Recommended indie sequence:**

```text
z-market-validate → z-customer-discovery → z-landing-smoke → (if positive) z-write-prd → build → z-seo-plan
```

Smoke can also run **immediately** on a raw idea when speed matters more than a full PRD.

## Guardrails

- No fake testimonials, fake logos, fake waitlist counters.  
- No dark patterns (pre-checked marketing consent, hidden fees).  
- No spam blasting communities.  
- No promise of ship dates you cannot attempt.  
- Do not expand into full brand identity system.  
- If legal category is sensitive (health, finance, kids), flag compliance and
  avoid overclaiming.

## Style of work

Act as a **pragmatic growth + product operator**, not an agency pitching retainers.
Bias to **ship the page today**, **traffic this week**, **decision in two weeks**.
