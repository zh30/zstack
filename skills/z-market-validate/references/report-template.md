# Report template — z-market-validate

Fill every section. Use `n/a` only when truly impossible; prefer “not found”.

---

# Market validation: {idea one-liner}

## Contents

1. Executive verdict
2. Idea framing
3. Evidence map
4. Competition and substitutes
5. Scores
6. Commercial value
7. Independent-developer fit
8. Short-term return
9. Entry directions
10. Risks and open questions
11. Next 48 hours
12. Evidence handoff
13. Source appendix

- **Date:** YYYY-MM-DD  
- **Analyst:** agent + skill `z-market-validate`  
- **Geography focus:** …  
- **Assumptions:** …

## 1. Executive verdict

| Question | Verdict | Confidence (low/med/high) |
|----------|---------|---------------------------|
| Commercial value? | Yes / Mixed / Weak | |
| Fit for independent developer? | Yes / Conditional / No | |
| Short-term return odds (30–90d)? | High / Medium / Low | |
| **Recommendation band** | Build wedge now / Explore with spike / Park / Avoid | |

**One-paragraph summary:** …

## 2. Idea framing

- **Problem (user language):** …
- **Proposed solution (as stated):** …
- **ICP (narrow):** …
- **Non-ICP (who to ignore first):** …

## 3. Evidence map

### 3.1 Channel coverage

| Channel | Status | Notes |
|---------|--------|-------|
| X/Twitter | | |
| Reddit | | |
| HN | | |
| Product Hunt | | |
| Indie Hackers | | |
| Reviews/Stores | | |
| CN platforms (if any) | | |

### 3.2 Demand signals (positive)

Bulleted signal cards (quote, link, weight).

### 3.3 Disconfirming signals (negative)

Bulleted signal cards (must not be empty unless search truly blocked — then say so).

### 3.4 Pricing & willingness-to-pay hints

What people already pay; free expectations; budget owners.

## 4. Competition & substitutes

| Substitute | Type | Price signal | Gap / complaint | Threat to indie |
|------------|------|--------------|-----------------|-----------------|
| … | | | | |

**Category structure:** fragmented niche / oligopoly / winner-take-most / chore tool / …

## 5. Scores (1–5)

| Dimension | Score | Evidence (1 line) |
|-----------|-------|-------------------|
| Demand reality | | |
| Willingness to pay | | |
| Competition intensity | | *(1 = open, 5 = brutally crowded; higher is worse)* |
| Indie fit | | |
| Time-to-signal | | |
| Short-term return odds | | |
| **Composite (avg)** | {copy `display_composite` below exactly} | *(do not recalculate here)* |

**Transparent composite calculation — single source of truth**

```text
competition_fit = 6 - competition_intensity = 6 - {competition} = {fit}
composite_sum = {demand} + {pay} + {fit} + {indie} + {time} + {return} = {sum}
composite_exact = {sum} / 6 = {unrounded result}
display_composite = round(composite_exact, 2) = {X.XX}
```

Use `{X.XX}` unchanged everywhere the composite appears, including the score
table and executive summary. Do not introduce a one-decimal alternative. Before
delivery, find every composite mention and verify it equals this displayed value.

**Scoring convention:** Competition intensity is the only reversed raw score:
1 = open and 5 = brutally crowded. All other dimensions use 5 = better for
proceeding. Calculate the composite from demand, pay,
`competition_fit = 6 - competition_intensity`, indie fit, time-to-signal, and
short-term return. Never average raw competition intensity into the composite.
The formula block is the only place to calculate or round it; all other mentions
must copy `display_composite` exactly.

## 6. Commercial value

Prose: who pays, for what outcome, how often, what budget replaces.

## 7. Independent developer fit

Cover:

- Build scope for MVP  
- Support / ops burden  
- Distribution channels available to a solo  
- Regulation / liability / capital needs  
- Skills match (if known)

## 8. Short-term return (30–90 days)

Define the success metric used (e.g. first paid user, $500 MRR, 20 waitlist emails).

- **Best plausible path:** …  
- **Why odds are High/Med/Low:** …  
- **What would falsify the path:** …

## 9. If you go deeper — entry directions

### Primary wedge (recommended)

- **Who:** …  
- **Job-to-be-done:** …  
- **MVP shape:** …  
- **Where to find first 10 users:** …  
- **Metric in 14 days:** …

### Backup wedges

1. …  
2. …

### Explicitly do **not** start with

- …

## 10. Risks & open questions

- …

## 11. Next 48 hours (exactly 3 actions)

1. …  
2. …  
3. …

## 12. Evidence handoff

In the final `Evidence classes` cell, delete non-applicable choices and keep only
canonical class names without qualifiers.

| Field | Value |
|-------|-------|
| Current decision | Build wedge now / Explore with spike / Park / Avoid |
| Evidence classes | primary behavior / observed experiment / secondary public / search signal / assumption |
| Supported claims | What this report actually supports |
| Still unproven | Especially switching, payment, retention, and delivery feasibility |
| Contradictions / exclusions | Strongest opposing evidence and wedges explicitly rejected |
| Source anchors | Links, signal-card ids, and dated input paths |
| Next validation | One action + owner + success/fail signal |

Do not promote public discussion, upvotes, or competitor pricing into primary
customer, payment, or retention evidence.

## 13. Source appendix

### Strongest supporting links

1. …

### Strongest opposing links

1. …

### Signal card dump (optional detail)

…
