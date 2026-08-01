# Discovery synthesis — client onboarding

| Field | Value |
|-------|--------|
| **Date** | 2026-07-31 |
| **N completed** | 5 |
| **N target** | 5 (checkpoint); recommend +2–3 cold ops if advancing |
| **Cold / warm mix** | 4 cold / 1 warm |
| **ICP (working)** | Operators who run client onboarding across tools and already pay people or automation (agency PMs, bookkeepers; consultants with assistants) |
| **Anti-ICP (from sample)** | Warm contacts with no recent pain who only praise a pitch; generalist founders without onboarding ops load |

**Evidence basis:** Five founder-supplied interview *summaries* treated as full evidence. No verbatim quotes were provided; patterns below cite **note IDs and behavioral facts only**. Nothing was invented.

---

## 0. Evidence audit

| Check | Result |
|-------|--------|
| Fabricated interviews? | No — five real summary-level debriefs |
| Verbatim gold quotes? | **None** — all notes mark quotes absent |
| Past behavior vs intent? | Strongest in 01, 04; weaker in 02, 05; **absent** in 03 |
| Pitch contamination? | 03 only complimented the pitch (classic Mom Test fail); weight near zero |
| Sample bias | 4/5 cold is good; roles span agency / consulting / founder / bookkeeping / marketing — useful diversity, thin depth per person |
| Note quality | Summary-grade: times and costs partly specified (45 min, weekly) but $ amounts, tool names, and dates mostly missing |
| Instant-fail risks | Avoid green-lighting a *large* build from compliments or from N=5 alone without smoke/pilot |

**Usable primary evidence set:** treat **01 Agency PM** and **04 Bookkeeper** as core; **02 Consultant** and **05 Marketer** as secondary (spend barrier / switch muscle); **03 Founder** as control for polite-warm noise.

---

## 1. Method limits

**What we still don’t know**

- Dollar amounts (Zapier tier, assistant/VA monthly cost)
- Exact tool stacks and which fields are re-keyed
- Who the budget owner is outside the agency PM’s pilot ask
- Whether “weekly failures” for bookkeepers are data errors, missed steps, client delays, or tool breaks
- What “migration” means for the consultant (historical data, live clients, SOPs)
- Security bar for sensitive files (SOC2, local-only, client-by-client consent)

**Sample biases**

- Summaries, not full transcripts → risk of founder framing
- One warm interview that is pure compliment → would pollute averages if weighted equally
- No pure “enterprise IT buyer” or “solo freelancer with no help” extremes
- N=5 is pattern detection, not market sizing

---

## 2. Segments observed

| Segment | Who | N | Implication |
|---------|-----|---|-------------|
| **Bleeding + paying cost** | 01 Agency PM (time + Zapier); 04 Bookkeeper (weekly failures + VA); 02 Consultant (assistant pay) | 3 | Primary ICP. Build and sell here first. |
| **Bleeding / tooling friction, low cash spend** | 05 Marketer (free automation; past switches; wants CSV) | 1 | Secondary: design for export/interop; do not price on this segment alone |
| **Polite only** | 03 Founder (no recent pain, no spend, pitch compliment) | 1 | Discard for demand. Do not use in gate averages as support. |

---

## 3. Pain patterns (G1)

| Pattern | Frequency in sample | Evidence (note ids + facts — no invented quotes) |
|---------|---------------------|--------------------------------------------------|
| Multi-tool manual copy / re-key during onboarding | Strong (1 of 5 with timed cost; others compatible) | **01**: repeatedly ~45 min copying across tools |
| Recurring operational failures | Strong in finance-ops | **04**: weekly failures |
| Process ownership gaps kill “template” fixes | Present | **01**: abandoned template over unclear ownership |
| Capacity absorbed by people workarounds | Present | **02** assistant; **04** VA — pain expressed as labor, not always as a named incident |
| Light / unstated pain | Present | **05** free automation only; **03** no recent pain |

---

## 4. Status quo & spend (G2)

| Solution in market | Cost form | Gaps they hate / leftover work | Notes |
|--------------------|-----------|--------------------------------|-------|
| Zapier | Paid automation | Still ~45 min manual copy (**01**) | Automation paid ≠ problem solved |
| Paid assistant | Human labor | Migration fear if changing stack (**02**) | Spend is real; switching cost is social/process |
| Paid VA | Human labor | Weekly failures persist (**04**) | Labor patches broken process |
| Free automation | $0 software | Will switch tools; wants CSV (**05**) | Low willingness-to-pay signal in cash terms |
| Templates / process docs | Time sunk | Abandoned when ownership unclear (**01**) | Process products fail without RACI-like clarity |
| Nothing / no stack pain | $0 | n/a | **03** — not a buyer now |

---

## 5. Switch barriers (G3)

| Barrier | How common | Implication for product |
|---------|------------|-------------------------|
| Unclear ownership of onboarding process/artifacts | 01 | Product must make owner, steps, and handoff explicit — not another orphan template |
| Migration cost (data/process move) | 02 | Pilot must import or coexist; no big-bang cutover |
| Sensitive files / trust | 04 | Privacy-first design; optional local/export paths; clear data boundaries before pilot |
| Format / integration needs (CSV) | 05 | First-class CSV import/export reduces switch cost for automation-native users |
| No pain → no switch | 03 | Warm praise ≠ pipeline |

**Positive switch signals**

- **01** asked for a **real pilot** (strongest G3 action in sample)
- **01** already abandoned a weak alternative (search/fail cycle)
- **05** has **switched tools before** (switching muscle)

---

## 6. Gate scores

Scoring anchors (from skill rubric): 1 = contradicts/absent … 5 = repeated strong behavior with concrete cost and few material contradictions. Confidence is separate (sample quality, diversity, saturation).

| Gate | Score (1–5) | Confidence | Summary |
|------|-------------|------------|---------|
| **G1 Pain** | **4** | **medium** | Repeated behavioral pain in independent cold interviews: timed multi-tool copy (**01**), weekly failures (**04**), labor workarounds (**02**, **04**). **03** contradicts; **05** thin. Not a 5 — missing rich incident timelines and one strong counterexample in-sample. |
| **G2 Spend** | **4** | **medium** | Real money/time already spent on bad or incomplete solutions: Zapier (**01**), assistant (**02**), VA (**04**). **05** free-only; **03** no spend. Cash amounts unstated → confidence not high. |
| **G3 Switch** | **3** | **medium** | Mixed: pilot ask + prior abandoned template (**01**) and prior tool switches + CSV need (**05**) support feasibility; migration (**02**) and sensitive files (**04**) are material blockers; **03** no switch signal. Plausible segment, not yet stable switch proof across majority. |

**Confidence notes (all gates):** medium because N=5, summary-only notes, no verbatims, and one warm contaminated interview. Cold majority and role diversity prevent “low.” Saturation not reached (new roles still add new barriers).

---

## 7. Decision (summary)

**Verdict: Advance** — with a **narrow wedge**, not a broad platform build.

Full rationale, wedge, and kill list: `decision.md`.

---

## 8. Downstream handoff

| Artifact | Use in |
|----------|--------|
| User language (paraphrase from facts, not fake quotes) | `z-landing-smoke` — e.g. “45 minutes copying between tools,” “still paying Zapier,” “weekly handoff failures,” “who owns the template?” |
| Non-goals | `z-write-prd` — no founder vanity onboarding; no pitch-led warm demo as validation; no big-bang migration-required MVP |
| Open questions | Next 2–3 cold interviews: $ spend, security bar, ownership model |
| Pilot design | Scoped pilot for **01**-like agency PM; coexistence + CSV; clear ownership fields |
| Desk signal if wedge shifts | `z-market-validate` only if pilot ICP changes after security/migration findings |

### Concrete handoff pack

**A. For `z-landing-smoke` (recommended next, parallel to pilot)**

- **Audience:** Agency PMs / ops leads and bookkeeping ops who onboard clients across tools.
- **Problem lines (evidence-backed, non-quote):**
  - Spend ~45 minutes copying client data across tools — repeatedly.
  - Already pay Zapier (or a VA/assistant) and still clean up handoffs by hand.
  - Templates die when nobody owns the next step.
  - Weekly onboarding failures burn paid VA time.
- **CTA:** Waitlist or “request a 2-week pilot” (mirror **01** ask), not “sign up for the vision.”
- **Success metric:** Pilot requests / qualified emails from cold agency-ops or bookkeeping traffic — ignore warm founder praise.

**B. For thin pilot / `z-write-prd` scope**

| In scope | Out of scope (for now) |
|----------|-------------------------|
| Multi-step client onboarding checklist with **named owner per step** | Full “replace your agency OS” suite |
| Coexist with Zapier; reduce the 45-min copy loop for one path | Forced full migration day-one |
| CSV import/export | Deep native integrations before pilot learning |
| Explicit sensitive-file handling story (what never leaves client systems) | Generic AI on all client documents without consent model |
| Success = cut timed re-key + fewer weekly failure classes in pilot | Vanity dashboards, social proof from warm compliments |

**C. Open questions for next interviews**

1. Last onboarding: tools touched, minutes re-keying, who waited on whom?
2. Monthly $ on Zapier / VA / assistant attributable to onboarding?
3. What file classes cannot be uploaded anywhere?
4. What would make migration a non-issue for a 2-week pilot?
5. Who signs a paid pilot?

---

## 9. Note index

| ID | Slug | Source | Gates lean |
|----|------|--------|------------|
| 01 | agency-pm | cold | G1 support / G2 support / G3 support |
| 02 | consultant | cold | G1 weak-neutral / G2 support / G3 barrier (migration) |
| 03 | founder | warm | G1 contradict / G2 contradict / G3 contradict |
| 04 | bookkeeper | cold | G1 support / G2 support / G3 caution (sensitive files) |
| 05 | marketer | cold | G1 weak / G2 weak / G3 support (prior switches + CSV) |
