# Discovery synthesis — client onboarding / cross-tool handoff

| Field | Value |
|-------|--------|
| **Date** | 2026-07-31 |
| **N completed** | 5 |
| **N target** | 5 (checkpoint; summaries only — not full debriefs) |
| **Cold / warm mix** | 4 cold / 1 warm |
| **ICP (working)** | Operators who move client data across tools during onboarding/ops (agency PMs, bookkeepers, consultants with assistants) |
| **Mode** | synthesize (summary-only inputs) |
| **Evidence basis** | Founder-supplied interview summaries treated as full evidence; no verbatim quotes available |

## 1. Method limits

- **Summary-only inputs:** No transcripts, timestamps, or verbatim quotes. Patterns are attributable to interview IDs only; phrase-level copy for landing pages is **not** grounded.
- **Pitch pollution:** One interview (founder, warm) is compliments-only after pitch — invalid as demand signal.
- **Sample bias:** Small N=5; roles span agency PM, consultant, founder, bookkeeper, marketer — not a single tight ICP. Cold majority is good; warm founder is noise for gates.
- **What we still don’t know:** Budget owners vs implementers; exact tools in the copy chain; frequency of “45 min” beyond agency PM; how “weekly failures” fail (import error vs human error vs permissions); security constraints for bookkeepers beyond “sensitive-file concerns”; whether pilot willingness is budgeted; migration path detail for consultant.
- **Saturation:** Not reached. Bleeding+paying cluster (agency PM, bookkeeper, partially consultant) is directionally consistent; marketer is adjacent; founder contradicts G1/G2.

## 2. Segments observed

| Segment | Who | N | Implication |
|---------|-----|---|-------------|
| **Bleeding + paying cost** | Agency PM (Zapier + repeated 45 min copy); Bookkeeper (paid VA + weekly failures); Consultant (pays assistant) | 3 | Core ICP candidates. Already externalize cost (tools and/or labor). Product must beat current stack + migration fear. |
| **Bleeding / active workflow, light cash** | Marketer (free automation; has switched tools; wants CSV) | 1 | Price-sensitive; may convert on export/interop, not premium automation. Weak G2 cash proof. |
| **Polite only** | Founder (no recent pain or spend; complimented pitch only) | 1 | Drop from ICP. Compliments are not demand. |

## 3. Pain patterns (G1)

| Pattern | Frequency | Evidence (note ids; no invented quotes) |
|---------|-----------|----------------------------------------|
| Manual cross-tool copy / re-entry during client work | 1 strong (agency PM); adjacent elsewhere | **01-agency-pm:** repeatedly spends **45 minutes** copying across tools. |
| Recurring operational failures | 1 strong | **04-bookkeeper:** **weekly failures**. |
| Labor as workaround for process gaps | 2 | **04-bookkeeper:** paid VA labor. **02-consultant:** pays an assistant. |
| Unclear ownership kills adoption of process assets | 1 | **01-agency-pm:** abandoned a template over **unclear ownership**. |
| No recent pain | 1 | **03-founder:** no recent pain or spend. |
| Free-tier automation sufficiency (milder pain) | 1 | **05-marketer:** uses free automation (workaround exists; severity lower than paid labor/Zapier). |

## 4. Status quo & spend (G2)

| Solution in market | Cost form | Gaps they hate / limits | Notes |
|--------------------|-----------|-------------------------|-------|
| Zapier (or similar paid automation) | Paid subscription | Still leaves **manual 45 min** copy for agency PM | **01** — pays *and* still burns time → incomplete fix |
| Paid VA / assistant labor | Ongoing human cost | Weekly failures still happen (bookkeeper); migration risk named (consultant) | **04**, **02** |
| Free automation | $0 software | Marketer already lives here; wants **CSV** | **05** — spend is time/tool-churn, not cash |
| Templates (process, not product) | Near-zero cash; adoption cost | Abandoned over **unclear ownership** | **01** — process products fail without ownership model |
| (None / status quo OK) | $0 | N/A | **03-founder** |

## 5. Switch barriers (G3)

| Barrier | How common | Implication for product |
|---------|------------|-------------------------|
| **Migration** of existing setup | Named by consultant | Onboarding path must be non-destructive; import/side-by-side; don’t require big-bang cutover |
| **Ownership clarity** (who owns template/process) | Agency PM abandoned template | Multi-seat / client workspace needs explicit ownership & handoff semantics |
| **Sensitive files / data handling** | Bookkeeper | Security, access control, retention story is table stakes for that segment — not a later add-on |
| **Interop preference (CSV)** | Marketer | Export/import and boring formats reduce lock-in fear; aids light users |
| **Prior tool switching** (positive signal) | Marketer has switched before | Switching is possible in this persona when value is clear |
| **Pilot as trust step** | Agency PM asked for a **real pilot** | Commercial motion = time-boxed pilot, not feature dump or “sign annual” |
| **No problem to switch from** | Founder | Anti-ICP |

## 6. Gate scores

Scoring anchors: 1 = contradicts/absent · 2 = isolated/weak · 3 = mixed/unstable segment · 4 = repeated behavioral support · 5 = strong repeated cost/action, few contradictions. Confidence reflects sample diversity, note quality, bias — **not** the score number alone.

| Gate | Score (1–5) | Confidence | Summary |
|------|-------------|------------|---------|
| **G1 Pain** | **4** | **medium** | Independent cold interviews show concrete recurring cost: 45 min copy (01), weekly failures (04), labor workarounds (02, 04). Founder (03) contradicts but is polite-only. Summaries lack incident timelines → confidence not high. |
| **G2 Spend** | **4** | **medium** | Real money/labor already in play: Zapier (01), paid VA (04), paid assistant (02). Marketer is free-tier only; founder spends nothing. Pattern holds in bleeding segment, not whole sample. |
| **G3 Switch** | **3** | **medium-low** | Positive: pilot ask (01), prior tool switch (05), template abandonment shows dissatisfaction (01). Negative/hard: migration barrier (02), sensitive-file concerns (04), ownership friction (01). Credible only if wedge designs around barriers — not blanket “they’ll switch.” |

## 7. Decision (summary)

**Verdict: Advance** — narrow wedge + pilot/smoke, not a broad platform build.

**Why:** Among 4 cold interviews, 3 show past-behavior pain and/or spend (G1/G2). G3 is mixed: willingness appears as pilot request and prior switching, but migration, ownership, and sensitive data are first-class product constraints. The warm founder is discarded as demand evidence. N=5 summaries support a **smoke test / real pilot** with the bleeding+paying segment, not a large multi-persona MVP.

**Wedge for smoke/PRD:** Cross-tool **client onboarding / data handoff** for **agency PMs and bookkeepers** (and similar ops roles) who already pay Zapier and/or VA labor — deliver a **time-boxed pilot** that reduces manual copy and weekly breakage, with **CSV/export**, **explicit ownership**, and **sensitive-file handling** called out.

**Reshape note (not full Reshape verdict):** If the product was framed as “generic AI onboarding for all founders,” reshape messaging/ICP to the bleeding+paying ops segment; do not park the problem domain.

**Park would reopen if:** Next 5 cold interviews in this ICP show no spend and no recent incidents, or pilot asks evaporate when calendar/money is requested.

## 8. Downstream handoff

| Artifact | Use in |
|----------|--------|
| Pain language (paraphrase only — no invented quotes): manual multi-tool copy, weekly failures, paying VA/Zapier still broken, ownership of templates unclear | `z-landing-smoke` problem copy; avoid founder-friendly “great for startups” tone |
| Offer: **real pilot** (agency PM signal); CSV in/out (marketer); security for sensitive files (bookkeeper) | Smoke CTA + FAQ |
| Non-goals / killed for now: build for compliment-only founders; big-bang migration; template libraries without ownership model | `z-write-prd` non-goals |
| Open questions: budget owner; tool chain list; quantify time beyond one PM; bookkeeper failure mode; pilot success metric | Next interview guide (cold agency PM / bookkeeper only) |
| Next skill | **`z-landing-smoke`** with pilot waitlist/CTA aimed at agency ops + bookkeepers; optional parallel **`z-write-prd`** thin scope locked to wedge |

## 9. Note index

| ID | Slug | Warm/Cold | Gates lean |
|----|------|-----------|------------|
| 01 | agency-pm | cold | G1 support · G2 support (Zapier + time) · G3 support (pilot; ownership barrier) |
| 02 | consultant | cold | G1 support (assistant as workaround) · G2 support · G3 constrain (migration) |
| 03 | founder | warm | G1 contradict · G2 contradict · G3 n/a (polite only) |
| 04 | bookkeeper | cold | G1 support (weekly failures) · G2 support (VA) · G3 constrain (sensitive files) |
| 05 | marketer | cold | G1 mild · G2 weak (free) · G3 mixed (switched before; wants CSV) |

---

*Synthesized only from founder-provided summaries. No quotes invented. Statistical humility: N=5 pattern detection, not market size.*
