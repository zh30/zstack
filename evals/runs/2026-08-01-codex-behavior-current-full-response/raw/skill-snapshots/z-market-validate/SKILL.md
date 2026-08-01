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
7. **Evidence does not upgrade on handoff.** Preserve whether a claim is a
   secondary public signal, observed behavior, experiment result, search signal,
   or assumption when another skill consumes it.
8. **The handoff is a fixed interface.** End the primary report with exactly
   one two-column, seven-row Evidence handoff table headed `Field | Value`
   using these exact labels: `Current
   decision`, `Evidence classes`, `Supported claims`, `Still unproven`,
   `Contradictions / exclusions`, `Source anchors`, and `Next validation`.
   The class cell may contain only applicable names from `primary behavior`,
   `observed experiment`, `secondary public`, `search signal`, and `assumption`;
   put provenance and confidence qualifiers in the other fields. Include a
   class only when supplied inputs or actual results in this report belong to
   it; a planned next research action does not make that class current.
   Never leave the class cell empty. If the report has only missing, invalid,
   or unverified inputs, use `assumption` and state the limitation elsewhere.

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
2. **Search query pack** (8–20 queries), including:
   - problem phrases (“I hate…”, “looking for…”, “alternative to…”)
   - competitor / category names
   - “vs”, “pricing”, “worth it”, “shutdown”, “refund”
   - language variants (EN + local language if geography is CN or bilingual)
3. **Success signals** (what would count as “real demand”)
4. **Kill signals** (what would make this a no-go for an indie)

Read `references/sources.md` for channel tactics and query recipes.
Read `references/report-template.md` before writing the final doc.

### Phase 2 — Multi-channel demand scan

Scan **at least 4 channels** when tools allow. Mark each channel status:
`searched` | `partial` | `blocked` | `skipped (reason)`.

**Default global stack (priority order):**

| Priority | Channel | What to extract |
|----------|---------|-----------------|
| 1 | **X / Twitter** | Recent complaints, wishlists, builder threads, pricing talk |
| 2 | **Reddit** | Subreddit pain posts, “how do you…”, competitor hate/love |
| 3 | **Hacker News** | Show HN, Ask HN, “who is hiring” is less useful; pain/launch comments |
| 4 | **Product Hunt** | Similar launches, upvotes as weak signal, comment objections |
| 5 | **Indie Hackers** | Revenue posts, failed builds, “I built X” retrospectives |
| 6 | **App Store / Play / G2 / Capterra** (if category fits) | 1★ themes, feature requests |
| 7 | **SEO / public keyword pages** | Only if accessible; treat volumes as rough |

**If user / idea is China-primary or bilingual, also scan when reachable:**

| Channel | Notes |
|---------|--------|
| 即刻 / 微博 / 小红书 / 知乎 / 抖音评论 | Demand + trend language; watch for ad spam |
| V2EX / 少数派 / 即刻产品圈 | Indie / tech-adjacent CN signal |

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

Score each dimension **1–5** with one-line evidence. Midpoint (3) means mixed
or weak evidence — not “good”.

| Dimension | 1 | 5 | Direction |
|-----------|---|---|-----------|
| **Demand reality** | Almost no organic pain | Frequent, specific, recurring pain | higher = better |
| **Willingness to pay** | Free-only / toy | Clear paid substitutes or budget talk | higher = better |
| **Competition intensity** | Open field / weak substitutes | Brutal giants + free tools everywhere | **higher = worse** |
| **Indie fit** | Needs team, heavy support, capital, heavy compliance | Solo can ship + distribute MVP | higher = better |
| **Time-to-signal** | >6 months to know | Can learn in days–weeks | higher = better |
| **Short-term return odds** | Near-zero in 90 days | Plausible first paid outcomes in 30–90 days | higher = better |

When averaging a **composite**, invert competition first: `competition_fit = 6 - competition_intensity`, then average the six “higher = better” values (demand, pay, competition_fit, indie, time-to-signal, short-term).

Calculate that composite **once** from the six displayed inputs. Round it once to
two decimal places and treat that result as the report's single display value.
Copy the exact same value into the score table, executive summary, and any later
prose; never recompute or reround it from memory. Before delivery, search every
composite mention and reconcile it with the visible formula. Any mismatch is an
invalid report, even when the formula itself is correct.

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

Use the structure in `references/report-template.md`. Apply
`references/quality-bar.md` before delivery.

Do not rename, split, or replace the template's seven Evidence handoff rows with
equivalent prose or custom fields.

Delivery options:

1. **Default:** paste the full report in chat.
2. If the user is in a product repo and wants a file: write
   `docs/z-market-validate-<slug>-<YYYYMMDD>.md` (or path they specify).

End with:

- **Top 5 evidence links**
- **Top 5 disconfirming links**
- **Next 48-hour actions** (3 concrete tasks, not “keep researching forever”)
- **Evidence handoff** with supported claims, unproven claims, source anchors,
  and the next validation

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
