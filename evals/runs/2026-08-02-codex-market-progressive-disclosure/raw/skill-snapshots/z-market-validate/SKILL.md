---
name: z-market-validate
description: >-
  Use when an independent developer needs public market research to decide
  whether an early product idea is worth deeper validation. Scans communities
  and competitors for demand, objections, alternatives, solo-founder fit, entry
  wedges, and a go, narrow, or stop recommendation.
---

# Market Validate

Turn a **raw / half-baked idea** into an evidence-backed validation report for an
**independent developer** (solo founder / OPC). Bias toward **honest negatives**
as much as positives. Prefer primary signals from real people complaining, paying,
or shipping — not generic “AI market size” fluff.

## When not to use

- Ready for real user interviews (Mom Test) → prefer `z-customer-discovery`
- Ready to test demand with a page + waitlist → prefer `z-landing-smoke`
- Idea is already shipping and needs growth experiments (different skill later)
- Pure technical design / architecture (use eng planning skills)
- Legal/compliance deep dive only

## Output language

Write the **final report in the same language the user used** for the idea
(Chinese → Chinese report; English → English). Keep source quotes in original
language with short translations when helpful.

## Non-negotiables

1. **No empty confidence.** Every major claim needs a source link or a clear “not found”.
2. **Seek disconfirming evidence.** Actively search for “scam”, “hate”, “cancelled”, “alternative”, “too expensive”, “doesn’t work”.
3. **Indie lens.** Score suitability for **one person** (scope, support burden, distribution, regulation, capital).
4. **Short-term return is hard.** Call out when “quick money” claims are weak; prefer 30/90-day *plausible* paths over fantasy ARR.
5. **Do not invent numbers.** If you cannot measure volume, say so and use qualitative bands.
6. **Tools are host-specific.** Use whatever the host provides: web search, X/Twitter search, page fetch/browse, Reddit search, etc. If a channel is unreachable, mark it `blocked` and continue.
7. **Evidence does not upgrade on handoff.** Preserve each claim's canonical
   class — `primary behavior`, `observed experiment`, `secondary public`,
   `search signal`, or `assumption` — when another skill consumes it.
8. **The handoff is a fixed interface.** End the primary report with exactly
   one two-column, seven-row Evidence handoff table headed `Field | Value`.
   Its first column must use these exact plain-text labels: `Current decision`,
   `Evidence classes`, `Supported claims`, `Still unproven`, `Contradictions /
   exclusions`, `Source anchors`, and `Next validation`. Do not format,
   translate, split, or rename them. The class cell may contain only applicable
   names from `primary behavior`, `observed experiment`, `secondary public`,
   `search signal`, and `assumption`. Planned work does not add a current class.
   Never leave the class cell empty. Use `assumption` when inputs are only
   missing, invalid, or unverified, and state that limit elsewhere.

---

## Workflow

### Phase 0 — Intake (≤ 5 questions if needed)

If the idea is too vague to search, ask only what blocks research. Prefer
inferring the rest and stating assumptions.

Minimum to proceed:

| Field | Example |
|-------|---------|
| **One-liner** | “AI that turns meeting notes into client invoices for freelancers” |
| **Who suffers** | Freelancers / agencies / Chinese SMBs / … |
| **Geography** | Global / US / CN / … |
| **Rough shape** | SaaS / template / content / marketplace / CLI / mobile |

Optional (ask only if missing and material): willingness-to-pay guess, skills the
founder already has, hard constraints (no marketplace, no hardware, offline only).

Record assumptions explicitly in the report.

### Phase 1 — Research frame (do this before searching)

Produce a short internal frame (can be in notes, not full user-facing yet):

1. **Problem statement** (user pain in their words, not product words)
2. **Search query pack** (8–20 queries) covering pain, demand, competitors,
   alternatives, pricing, failure/churn, and relevant language variants
3. **Success signals** (what would count as “real demand”)
4. **Kill signals** (what would make this a no-go for an indie)

Read `references/sources.md` for channel tactics and query recipes.
Read `references/report-template.md` before writing the final doc.

### Phase 2 — Multi-channel demand scan

Read and apply `references/sources.md`. When tools allow, scan **at least 4
relevant channels**, including one buyer habitat rather than only founder
communities. Choose among X/Twitter, Reddit, Hacker News, Product Hunt, Indie
Hackers, app/review sites, and public search pages; for China-primary or
bilingual ideas, add reachable sources such as 即刻、微博、小红书、知乎、V2EX、
少数派, or buyer-relevant comments. Mark every chosen channel `searched`,
`partial`, `blocked`, or `skipped (reason)`; never imply access you did not have.

For each useful hit, capture a **signal card**:

```text
- channel:
- url:
- date: (if known)
- quote/summary: (short)
- polarity: demand | praise | objection | churn | competitor | pricing | noise
- weight: high | med | low   # high = recent + specific + emotional/paying intent
- indie_relevance: high | med | low
```

Aim for **12–30 signal cards**, not 200 dumps. Prefer quality and diversity
(different channels and polarities).

### Phase 3 — Competition & substitutes

Identify 3–8 alternatives people already use (including “do nothing”, Excel,
agencies, manual process). For each:

- Who it’s for
- Pricing (if public)
- Gaps people complain about
- Why an indie might still win a **wedge** (or why not)

### Phase 4 — Scoring (explicit, humble)

Use the exact six-dimension score table and formula in
`references/report-template.md`. Score each dimension **1–5** with one-line
evidence; midpoint 3 means mixed or weak evidence. Competition intensity is the
only reversed raw input: calculate `competition_fit = 6 -
competition_intensity`, then average demand, pay, competition fit, indie fit,
time-to-signal, and short-term return. Calculate and round once to two decimals,
then copy that exact display value everywhere. Any mismatch is an invalid report.

Also pick a **recommendation band**:

| Band | Meaning |
|------|---------|
| **Build wedge now** | Enough pain + indie-shaped + learning path |
| **Explore with spike** | Unclear; 1–2 week research/build spike only |
| **Park / reshape** | Weak demand, bad indie fit, or only vanity market |
| **Avoid (as stated)** | Kill criteria hit; only proceed if idea changes |

Never let a high “market size story” override empty primary signals.

### Phase 5 — Indie short-term return judgment

Answer explicitly (no hedging without saying why):

1. **Commercial value?** Yes / Mixed / Weak — in one paragraph with evidence.
2. **Fit for independent developer?** Yes / Conditional / No — scope, support, channels, skills.
3. **Short-term return (30–90 days) odds?** High / Medium / Low — what “return” means (first $100, first 10 users, consulting lead, etc.).
4. **If going deeper, best entry direction** — pick **one primary wedge** + 1–2 backups; say what to ship first and what to measure.

Prefer wedges that are:

- Narrow ICP
- Manual-first or uglier MVP OK
- Distribution via communities already scanned
- Avoid winner-take-all platforms on day one

### Phase 6 — Deliver the report

Read and follow `references/report-template.md`, then apply
`references/quality-bar.md` before delivery; both are binding.

Do not rename, split, or replace the template's seven Evidence handoff rows with
equivalent prose or custom fields.

Delivery options:

1. **Default:** paste the full report in chat.
2. If the user is in a product repo and wants a file: write
   `docs/z-market-validate-<slug>-<YYYYMMDD>.md` (or path they specify).

Finish with the strongest supporting and opposing links available, exactly three
bounded next-48-hour actions, and the fixed Evidence handoff.

---

## Method notes (anti-BS)

- Upvotes ≠ revenue. PH medals ≠ retention.
- Loud Twitter ≠ paying customers.
- “I’d use this” comments are cheap; “I pay for X and hate Y” is gold.
- Founder echo chambers overstate novelty; search the buyer’s habitat, not only builder habitats.
- If everything looks positive, you under-sampled objections — go back to Phase 2.
- If everything looks negative, separate “bad idea” from “bad positioning / wrong ICP”.

## Guardrails

- Do not claim survey statistical significance from a few posts.
- Do not recommend illegal, spammy, or ToS-abusive growth tactics.
- Do not scrape behind logins if the host cannot; mark `blocked`.
- Do not shame the user’s idea; be direct and constructive.
- If tools fail entirely, say so and give a **manual research checklist** from `references/sources.md` instead of fabricating a report.
