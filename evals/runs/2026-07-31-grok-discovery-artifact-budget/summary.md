# Grok discovery artifact-budget regression

## Outcome

- **Before fix: FAIL.** The response met the original content criteria but created 8 files (29,474 bytes): a new status scaffold, five reconstructed per-interview notes, synthesis, and decision. Reconstructing full notes from thin summaries added false precision and file noise.
- **After fix: PASS (7/7 criteria).** The same model and prompt created exactly the two decision artifacts requested by the revised skill: synthesis and decision (14,216 bytes). No README or per-interview notes were created.

## After-fix grading

| Criterion | Grade | Evidence |
|---|---:|---|
| State N, mix, summary limits; exclude compliments | PASS | `synthesis.md` header and §1 state N=5, 4 cold/1 warm, summary-only limits; §2 classifies the founder as polite-only and drops it from demand. |
| Cluster segments; score G1/G2/G3 with separate confidence | PASS | `synthesis.md` §§2–6 segment the sample and report 4/medium, 4/medium, 3/medium-low. |
| Explicit decision and bounded handoff | PASS | Both artifacts choose Advance only for a narrow, pilot-first wedge; `decision.md` lists pilot/smoke scope, non-goals, and Park reopen criteria. |
| Keep summary synthesis to decision artifacts | PASS | Artifact manifest contains only `synthesis.md` and `decision.md`. |
| No invented quotes/details/market size | PASS | `synthesis.md` repeatedly labels paraphrases, identifies unknowns, and states no verbatim quotes; no market-size claim appears. |
| No generic or large-build green light | PASS | Verdict explicitly rejects a broad platform and generic founder product. |
| No reconstructed notes or new status scaffold | PASS | After-fix manifest: 2 files, neither a README nor notes. |

## Change justified by the failed run

`z-customer-discovery` now has an explicit artifact budget for summary-only `synthesize` mode: default to `synthesis.md` and `decision.md`, update a pre-existing status file only when present, and do not reconstruct per-interview notes unless requested. The behavioral manifest now grades this boundary.

## Reproducibility notes

Both runs used Grok Build 0.2.117 with `grok-4.5-build`, no web search, no subagents, at most three turns, and an initialized disposable Git workspace. The retest requested low reasoning effort, but this model reported that reasoning effort is unsupported; no effective effort is claimed. Account, request, and session identifiers are intentionally omitted.

Archive integrity note: the retained before-fix `synthesis` file proved that its
manifest SHA-256 had been truncated during archiving. The manifest was repaired
from the retained bytes on 2026-08-01; `scripts/validate-evidence.rb` now checks
retained artifact sizes and hashes. Six unretained noisy artifacts remain
explicitly inventory-only and cannot be cryptographically reverified.
