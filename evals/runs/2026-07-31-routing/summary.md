# Routing forward-test summary — 2026-07-31

## Protocol

- Runner: 15 independent clean-context Codex subagent sessions.
- Each session received only the five current frontmatter descriptions, one
  natural-language request, and an instruction to select one skill or `none`.
- Sessions were forbidden from reading repository files or eval manifests.
- Expected selections and grading criteria were not shown until after every
  response had been collected.
- Prompts and expected selections are recorded in
  [`../../routing.yaml`](../../routing.yaml); exact responses are preserved in
  [`raw/responses.md`](./raw/responses.md).

## Result

**15 / 15 passed.** No description change was needed.

| Case | Expected | Selected | Result |
|------|----------|----------|--------|
| market-vague | z-market-validate | z-market-validate | pass |
| market-public | z-market-validate | z-market-validate | pass |
| discovery-plan | z-customer-discovery | z-customer-discovery | pass |
| discovery-debrief | z-customer-discovery | z-customer-discovery | pass |
| landing-waitlist | z-landing-smoke | z-landing-smoke | pass |
| landing-metrics | z-landing-smoke | z-landing-smoke | pass |
| prd-notes | z-write-prd | z-write-prd | pass |
| prd-rewrite | z-write-prd | z-write-prd | pass |
| seo-live-url | z-seo-plan | z-seo-plan | pass |
| seo-prd-map | z-seo-plan | z-seo-plan | pass |
| none-code-fix | none | none | pass |
| none-architecture | none | none | pass |
| boundary-real-interviews | z-customer-discovery | z-customer-discovery | pass |
| boundary-public-research | z-market-validate | z-market-validate | pass |
| boundary-waitlist-demand | z-landing-smoke | z-landing-smoke | pass |

This is evidence for these descriptions and this runner on this date, not a
guarantee across every host or model family.
