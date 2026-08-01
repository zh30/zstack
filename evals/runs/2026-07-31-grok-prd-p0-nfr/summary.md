# Grok PRD P0-NFR regression

## Outcome

- **Before fix: FAIL (5/6 criteria).** The PRD was otherwise decision-ready, but its four P0 non-functional requirements used a Notes-only table. Several rows were descriptive or vague and had no independent acceptance criterion, so the requirement that every retained P0 be testable was not proven.
- **After fix: PASS (6/6 criteria).** The same model and prompt produced one canonical PRD. Every functional P0 has acceptance criteria, and all five retained P0 NFRs have explicit validation methods or observable negative checks.

## After-fix grading

| Criterion | Grade | Evidence |
|---|---:|---|
| Keep cold/warm separate; WTP unknown; evidence vs assumptions | PASS | §1.6 reports cold 27/300 and warm 12/40 separately, forbids blending, and labels $29 as a hypothesis because no payment was requested. The assumptions log is explicit. |
| One persona, six-week scope, concrete non-goals | PASS | Header and §2 select one agency ops/account-manager persona; §1.4 excludes portals, storage, bookkeeping, migration, connectors, AI, mobile, enterprise roles, and compliance; §9 is a six-week plan. |
| Stable IDs and testable criteria for every functional and non-functional P0 | PASS | FR-001–FR-014 P0 rows have concrete acceptance criteria. NFR-001/002/003/004/006 P0 rows specify viewport checks, absence checks, cohort-reporting rules, and a two-account 403/404 isolation test. |
| Journeys/failures, data boundaries, kill triggers, milestones, vertical slice | PASS | §§4, 7, 8, 9, and 10 cover all requested surfaces; §9.1 defines the smallest end-to-end slice with explicit omissions. |
| Do not reintroduce excluded scope as P0 | PASS | Excluded areas appear only as non-goals, negative data boundaries, or rejected ideas. No excluded capability is a P0 feature. |
| No invented quotes or payment validation | PASS | No research quote is invented; signups are treated as directional and $29/WTP as unvalidated. |

## Change justified by the failed run

`z-write-prd` now states that every retained P0—functional or non-functional—requires a concrete acceptance criterion or validation method. The PRD template replaces the Notes-only NFR column with `Acceptance criteria / validation method`, the quality bar names both requirement classes, and the behavioral criterion now makes this boundary observable.

## Reproducibility notes

Both runs used Grok Build 0.2.117 with `grok-4.5-build`, no web search, no subagents, at most three turns, and an initialized disposable Git workspace. The before-fix run experienced one transient model retry and still completed normally. Account, request, and session identifiers are intentionally omitted.
