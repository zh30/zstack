# Codex routing-budget regression

## Outcome

- **Baseline: 15/15 pass.** The original five descriptions routed every
  positive, boundary, and no-match case correctly.
- **180-character prefix stress: 15/15 pass.** Mechanically removing every
  description tail did not change a selection.
- **Compacted descriptions: 15/15 pass.** The committed candidates retained
  every baseline selection after moving use conditions to the front.
- Total active-skill description size fell from **2,001 to 1,355 characters**
  (**-646, -32.3%**).

The runner emitted Codex's installed-skill context-budget warning in all 45
runs. That warning alone does not prove these five candidate descriptions were
truncated because the routing candidates were supplied directly in the prompt.
It does establish real host-level budget pressure; the prefix phase tests the
relevant failure mode directly.

## Description budget

| Skill | Baseline chars | Compact chars | Change |
|-------|---------------:|--------------:|-------:|
| z-customer-discovery | 396 | 263 | -133 |
| z-landing-smoke | 435 | 274 | -161 |
| z-market-validate | 442 | 276 | -166 |
| z-seo-plan | 347 | 264 | -83 |
| z-write-prd | 381 | 278 | -103 |
| **Total** | **2,001** | **1,355** | **-646** |

The compact descriptions front-load the user intent, retain boundary-defining
inputs and outputs, and remove channel lists or repeated trigger prose that the
prefix stress showed was unnecessary for this suite.

## Case results

| Case | Expected | Baseline | Prefix 180 | Compact |
|------|----------|----------|------------|---------|
| market-vague | z-market-validate | pass | pass | pass |
| market-public | z-market-validate | pass | pass | pass |
| discovery-plan | z-customer-discovery | pass | pass | pass |
| discovery-debrief | z-customer-discovery | pass | pass | pass |
| landing-waitlist | z-landing-smoke | pass | pass | pass |
| landing-metrics | z-landing-smoke | pass | pass | pass |
| prd-notes | z-write-prd | pass | pass | pass |
| prd-rewrite | z-write-prd | pass | pass | pass |
| seo-live-url | z-seo-plan | pass | pass | pass |
| seo-prd-map | z-seo-plan | pass | pass | pass |
| none-code-fix | none | pass | pass | pass |
| none-architecture | none | pass | pass | pass |
| boundary-real-interviews | z-customer-discovery | pass | pass | pass |
| boundary-public-research | z-market-validate | pass | pass | pass |
| boundary-waitlist-demand | z-landing-smoke | pass | pass | pass |

## Protocol and provenance

Each phase used 15 independent `codex exec` processes. Every process received
only the five phase-specific candidate descriptions, one natural request from
`evals/routing.yaml`, and a two-line response contract. Candidate order rotated
by case. Expected selections, skill bodies, repository files, tools, installed
skill loading, web search, apps, and subagents were unavailable to the routing
decision.

All runs used Codex CLI 0.146.0 with `gpt-5.6-sol`, low reasoning, an ephemeral
session, a separate initialized disposable Git workspace, read-only sandboxing,
approval policy `never`, and one user turn. Every process exited 0. The exact
phase candidates and verbatim final selections are under `raw/`; CLI logs were
excluded because they contain ephemeral session identifiers and machine-local
paths.

All runs also emitted state-database fallback messages and a Cloudflare MCP
OAuth `invalid_grant` warning. No run invoked that connector or any MCP tool.
These results demonstrate preserved routing for this suite, model, and host;
they do not guarantee routing across every model family or future description
set.
