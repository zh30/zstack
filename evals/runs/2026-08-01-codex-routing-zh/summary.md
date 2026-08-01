# Codex Chinese routing regression

## Outcome

**10/10 passed.** Current compact descriptions correctly routed five Chinese
positive requests, three close validation boundaries, and two unrelated Chinese
engineering requests. No description change was needed.

| Case | Expected | Selected | Result |
|------|----------|----------|--------|
| zh-market-public | z-market-validate | z-market-validate | pass |
| zh-discovery-plan | z-customer-discovery | z-customer-discovery | pass |
| zh-landing-waitlist | z-landing-smoke | z-landing-smoke | pass |
| zh-prd-notes | z-write-prd | z-write-prd | pass |
| zh-seo-live-url | z-seo-plan | z-seo-plan | pass |
| zh-none-code-fix | none | none | pass |
| zh-none-architecture | none | none | pass |
| zh-boundary-real-interviews | z-customer-discovery | z-customer-discovery | pass |
| zh-boundary-public-research | z-market-validate | z-market-validate | pass |
| zh-boundary-waitlist-demand | z-landing-smoke | z-landing-smoke | pass |

The boundary results are the main signal: requests for real interviews selected
customer discovery, public evidence without customer access selected market
validation, and a waitlist plus real traffic and thresholds selected landing
smoke. The two code and architecture requests correctly selected `none`.

## Protocol and provenance

Ten independent `codex exec` processes read their final request text directly
from `evals/routing.yaml`. Each received only the five current frontmatter
descriptions, one request, and a two-line selection contract. Candidate order
rotated by case. Expected answers, skill bodies, repository files, tools,
installed skill loading, web search, apps, and subagents were unavailable to the
routing decision.

All runs used Codex CLI 0.146.0 with `gpt-5.6-sol`, low reasoning, an ephemeral
session, a separate initialized disposable Git workspace, read-only sandboxing,
approval policy `never`, and one user turn. Every process exited 0. Exact shared
candidates and verbatim final responses are under `raw/`; CLI logs were excluded
because they contain ephemeral session identifiers and machine-local paths.

Every run emitted state-database fallback messages, a Cloudflare MCP OAuth
`invalid_grant` warning, and the installed-skill context-budget warning. No run
invoked an MCP connector or other tool. This is evidence for these requests,
descriptions, model, and host version—not a universal multilingual guarantee.
