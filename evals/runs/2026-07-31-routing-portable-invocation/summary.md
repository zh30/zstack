# Routing forward-test summary — portable invocation revision

## Why this run exists

The five frontmatter descriptions stopped embedding `/z-*` syntax after a
cross-host review found that explicit invocation prefixes differ. This run
checks that intent-based automatic routing still works with those revised
descriptions.

## Protocol

- Runner: three fresh, repository-blind agent contexts, with five cases each.
- Inputs: only the candidate descriptions and natural-language requests in
  [`prompts.md`](./prompts.md).
- Excluded: skill bodies, repository access, expected selections, and grading
  notes.
- Raw selections: [`raw/core-a.md`](./raw/core-a.md),
  [`raw/core-b.md`](./raw/core-b.md), and
  [`raw/boundaries.md`](./raw/boundaries.md).
- Grading source: [`../../routing.yaml`](../../routing.yaml), revealed only after
  all three contexts returned.

## Result

**15 / 15 passed.** The descriptions retained correct positive, neighboring,
boundary, and no-match routing after host-specific invocation syntax was
removed.

| Case | Expected | Selected | Result |
|---|---|---|---|
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
