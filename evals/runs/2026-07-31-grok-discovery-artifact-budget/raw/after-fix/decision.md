# Discovery decision — client onboarding / cross-tool handoff

| Field | Value |
|-------|--------|
| **Date** | 2026-07-31 |
| **N** | 5 (4 cold / 1 warm) |
| **Evidence quality** | Summary-only (no full debriefs / no verbatims) |
| **Related** | [synthesis.md](./synthesis.md) |

## Verdict

# **Advance**

Proceed to a **behavior test (smoke) and/or thin pilot**, not a broad product build.

## Gate snapshot

| Gate | Score | Confidence |
|------|-------|------------|
| G1 Pain | 4 / 5 | medium |
| G2 Spend | 4 / 5 | medium |
| G3 Switch | 3 / 5 | medium-low |

## Why Advance (not Reshape / Park)

1. **G1 supported in the cold, bleeding cluster:** Agency PM (repeated 45 min cross-tool copy), bookkeeper (weekly failures), consultant (assistant labor as status quo). Not vibes — named recurring cost.
2. **G2 supported with real status-quo spend:** Zapier (agency PM), paid VA (bookkeeper), paid assistant (consultant). People already pay for incomplete solutions.
3. **G3 is the limiter, not a killer:** Migration (consultant), unclear ownership of templates (agency PM), sensitive files (bookkeeper). Counter-signals: pilot request (agency PM), prior tool switch + CSV preference (marketer).
4. **Warm founder is polite-only** — no recent pain/spend, pitch compliment only. Treat as anti-evidence for “build for founders,” not as gate support.
5. **Park would be wrong:** Three independent cold interviews show spend or labor against a live workflow problem. **Full Reshape** would fit only if the hypothesized ICP was “any founder”; reshape is a **messaging/ICP cut**, already baked into this Advance wedge.

## What Advance means in practice

| Do | Don’t |
|----|--------|
| Smoke / waitlist / pilot offer aimed at **agency PMs & bookkeepers** (ops roles already paying Zapier or VA) | Green-light multi-month platform for all five personas |
| Design pilot success around **time saved on copy** and **failure reduction** | Sell annual deals before a real pilot (agency PM asked for pilot) |
| Ship **CSV / boring interop**, **ownership model**, **sensitive-file story** early | Big-bang migration as required path |
| Recruit next interviews **cold**, same bleeding segment | Count founder compliments as validation |

## If Advance — wedge for smoke / thin MVP

**One-liner (internal):** Help agency and bookkeeping operators stop re-copying client data across tools — without blowing up migration, ownership, or file sensitivity.

**Must include in scope:**

- Reduce manual multi-tool copy (anchored on 45 min pattern)
- Reliability against weekly failure modes (bookkeeper)
- Explicit ownership for shared process/templates
- Export/import (CSV) and non-destructive onboarding (migration barrier)
- Security posture for sensitive client files

**Must stay non-goals (for now):**

- Founder-general “AI onboarding assistant”
- Template marketplace without ownership rules
- Forced full migration from assistant/VA workflows on day one

## Reshape clause (conditional)

If smoke conversion is only from free-tier marketers/founders and **zero** agency PM / bookkeeper pilot interest when asked for calendar commitment, **Reshape** ICP or Park after that behavior test — do not expand feature scope to chase compliments.

## Park — reopen criteria (not chosen now)

Reopen Park only if a second cold batch (recommended +5 in bleeding segment) fails to show recent incidents **and** cash/labor spend, or pilots are refused when concrete time/money is requested.

## Downstream handoff (concrete)

| Step | Owner action | Skill / artifact |
|------|----------------|------------------|
| 1 | Landing + CTA: “Request a pilot” / waitlist for **agency ops & bookkeepers** who already use Zapier or VAs for client handoff | **`z-landing-smoke`** |
| 2 | Copy inputs: use **paraphrased patterns only** (manual copy across tools; weekly breakage; still paying Zapier/VA; ownership unclear; CSV; pilot). **Do not invent quotes** until real verbatims exist | smoke page |
| 3 | PRD scope locked to wedge + non-goals above; success metric = pilot completion + reported time/failure change | **`z-write-prd`** (after or parallel to smoke) |
| 4 | Next interviews: screen for last-30-day copy/failure incident + current spend; deprioritize founders with no ops pain | discovery round 2 |
| 5 | Desk signal only if wedge renames | `z-market-validate` (optional, secondary) |

## Explicit reject list (from this sample)

| Signal | Disposition |
|--------|-------------|
| Pitch compliments (03-founder) | Not demand |
| Free automation alone (05) without cash pain | Secondary segment; price/export sensitive |
| Migration fear (02) | Design constraint, not “no market” |
| Sensitive files (04) | Design constraint for bookkeeper path |

---

**Decision line for the record:** Advance a **pilot-first smoke** for **bleeding + paying ops** (agency PM / bookkeeper-class); treat G3 barriers as product requirements; discard polite founder evidence.
