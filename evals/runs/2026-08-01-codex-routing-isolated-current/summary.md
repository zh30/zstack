# Codex CLI routing run

## Outcome

**25/25 passed.**

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

## Execution controls

Codex CLI 0.146.0 used `gpt-5.6-sol` with
low reasoning, one ephemeral turn per case,
generated prompts through stdin, isolated initialized Git workspaces, a
minimal per-case `CODEX_HOME`, read-only sandbox, approval policy `never`,
ignored user config/rules, removed ambient desktop context, and
disabled tools, apps, skill loading, browser/computer access, and subagents.
Candidate order followed the recorded deterministic rotation.

## Runner incidents

No recognized runner incidents were recorded.

Private runner records were cross-checked against the published host, model,
approval, sandbox, reasoning, workspace, prompt, response, and stop fields
and inspected for incidents. They were excluded because they contain
ephemeral session identifiers and machine-local workspace paths.
Results apply to these cases, descriptions, controls, model, and host version.
