# Codex CLI behavioral run

## Outcome

**1/1 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| smoke-complete-pack | z-landing-smoke | pass |

## Criterion review

### `smoke-complete-pack`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Keep one CTA and disclose that the product, proof, price, and ship date are unvalidated. | true | The page uses Join the early-access waitlist for all three CTA placements and repeatedly labels the extension unbuilt, proof absent, $9 pricing planned, and ship date unknown. |
| present | Provide numeric timeboxed success and kill rules with warm and cold traffic reported separately. | true | The dated 10-day protocol defines minimum samples, numeric strong/weak/park rules, a $150 cap, and separate warm, cold-community, cold-social, and cold-paid rows and conclusions. |
| present | Include full English copy, UTMs, a materialized minimal deployable page whose form counts only provider-confirmed success, preserves source attribution on each confirmed subscriber, and never presents an unverified attempt as confirmed success, plus at least three concrete channels, non-build scope, and a decision matrix. | true | Eight retained files include full copy, page/meta/OG, a deployable Pages site, TypeScript Function, UTMs, ledger, three-plus channels, non-build list, and decision matrix. The Function returns 201 only after Buttondown success and stores every UTM, variant, and traffic class on the subscriber; the browser emits Waitlist Confirmed and success UI only after that 201. |
| absent | Fabricate proof, promise availability, build the product, or pool warm and cold conversion. | false | The copy explicitly rejects logos, testimonials, user counts, availability, and ship-date claims; the non-build list excludes extension/product code, and warm traffic cannot satisfy any cold decision rule. |

## Retained deliverables

- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/README.md`](./raw/artifacts/smoke-complete-pack/README.md)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/functions/api/waitlist.ts`](./raw/artifacts/smoke-complete-pack/functions/api/waitlist.ts)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/measurement-template.csv`](./raw/artifacts/smoke-complete-pack/measurement-template.csv)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/site/_headers`](./raw/artifacts/smoke-complete-pack/site/_headers)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/site/index.html`](./raw/artifacts/smoke-complete-pack/site/index.html)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/site/og-card.svg`](./raw/artifacts/smoke-complete-pack/site/og-card.svg)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/smoke-test-package.md`](./raw/artifacts/smoke-complete-pack/smoke-test-package.md)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/wrangler.toml`](./raw/artifacts/smoke-complete-pack/wrangler.toml)

## Execution controls

Codex CLI 0.146.0 used `gpt-5.6-sol` with
medium reasoning, one ephemeral turn per case,
exact copied skill snapshots, generated prompts through stdin, isolated
initialized Git workspaces, a workspace-write sandbox, approval policy
`never`, and disabled web/browser/apps/computer access and subagents.
Post-run auditing rejected writes outside `artifacts/` and any change to
the copied skill; retained deliverables are covered by exact hashes.

## Runner incidents

- 1/1 runner logs contained the state-database fallback.
- 1/1 runner logs contained the Cloudflare MCP OAuth invalid_grant.
- 1/1 runner logs contained the installed-skill context-budget warning.

Private runner records corroborated host, requested and actual model, permissions,
isolation flags, workspaces, prompt bytes, response bytes, and incident counts, then
were excluded because they contain ephemeral session identifiers and local
paths. Results apply to the retained skill snapshots and execution controls.
