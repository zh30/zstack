# Grok Build routing run

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

Grok Build 0.2.117 requested `grok-4.5` and used
`grok-4.5-build` with low reasoning.
Each case used at most 2 turn, an isolated ephemeral
`GROK_HOME`, a fixed system prompt, a generated prompt file, and an initialized
Git workspace. The built-in tool list was empty; web search, memory, plan mode,
subagents, managed MCP, marketplace auto-registration, and MCP tools were disabled.
Grok can still discover the standard Agent Skills hub outside its isolated host
home, so both prompts explicitly prohibited skill loading and file inspection.
Candidate order followed the recorded deterministic rotation.

## Runner incidents

- market-vague: Grok wrote 4580 private stderr bytes.
- market-vague: Grok attempted MCP startup despite the MCP tool exclusion.
- market-public: Grok wrote 4580 private stderr bytes.
- market-public: Grok attempted MCP startup despite the MCP tool exclusion.
- discovery-plan: Grok wrote 4293 private stderr bytes.
- discovery-plan: Grok attempted MCP startup despite the MCP tool exclusion.
- discovery-debrief: Grok wrote 4580 private stderr bytes.
- discovery-debrief: Grok attempted MCP startup despite the MCP tool exclusion.
- landing-waitlist: Grok wrote 4324 private stderr bytes.
- landing-waitlist: Grok attempted MCP startup despite the MCP tool exclusion.
- landing-metrics: Grok wrote 4293 private stderr bytes.
- landing-metrics: Grok attempted MCP startup despite the MCP tool exclusion.
- prd-notes: Grok wrote 4580 private stderr bytes.
- prd-notes: Grok attempted MCP startup despite the MCP tool exclusion.
- prd-rewrite: Grok wrote 4293 private stderr bytes.
- prd-rewrite: Grok attempted MCP startup despite the MCP tool exclusion.
- seo-live-url: Grok wrote 4293 private stderr bytes.
- seo-live-url: Grok attempted MCP startup despite the MCP tool exclusion.
- seo-prd-map: Grok wrote 4293 private stderr bytes.
- seo-prd-map: Grok attempted MCP startup despite the MCP tool exclusion.
- none-code-fix: Grok wrote 4293 private stderr bytes.
- none-code-fix: Grok attempted MCP startup despite the MCP tool exclusion.
- none-architecture: Grok wrote 4324 private stderr bytes.
- none-architecture: Grok attempted MCP startup despite the MCP tool exclusion.
- boundary-real-interviews: Grok wrote 4293 private stderr bytes.
- boundary-real-interviews: Grok attempted MCP startup despite the MCP tool exclusion.
- boundary-public-research: Grok wrote 4324 private stderr bytes.
- boundary-public-research: Grok attempted MCP startup despite the MCP tool exclusion.
- boundary-waitlist-demand: Grok wrote 4293 private stderr bytes.
- boundary-waitlist-demand: Grok attempted MCP startup despite the MCP tool exclusion.
- zh-market-public: Grok wrote 4293 private stderr bytes.
- zh-market-public: Grok attempted MCP startup despite the MCP tool exclusion.
- zh-discovery-plan: Grok wrote 4611 private stderr bytes.
- zh-discovery-plan: Grok attempted MCP startup despite the MCP tool exclusion.
- zh-landing-waitlist: Grok wrote 4293 private stderr bytes.
- zh-landing-waitlist: Grok attempted MCP startup despite the MCP tool exclusion.
- zh-prd-notes: Grok wrote 4293 private stderr bytes.
- zh-prd-notes: Grok attempted MCP startup despite the MCP tool exclusion.
- zh-seo-live-url: Grok wrote 4580 private stderr bytes.
- zh-seo-live-url: Grok attempted MCP startup despite the MCP tool exclusion.
- zh-none-code-fix: Grok wrote 4293 private stderr bytes.
- zh-none-code-fix: Grok attempted MCP startup despite the MCP tool exclusion.
- zh-none-architecture: Grok wrote 4293 private stderr bytes.
- zh-none-architecture: Grok attempted MCP startup despite the MCP tool exclusion.
- zh-boundary-real-interviews: Grok wrote 4293 private stderr bytes.
- zh-boundary-real-interviews: Grok attempted MCP startup despite the MCP tool exclusion.
- zh-boundary-public-research: Grok wrote 4580 private stderr bytes.
- zh-boundary-public-research: Grok attempted MCP startup despite the MCP tool exclusion.
- zh-boundary-waitlist-demand: Grok wrote 4293 private stderr bytes.
- zh-boundary-waitlist-demand: Grok attempted MCP startup despite the MCP tool exclusion.

Runner logs were cross-checked against the published host, model, approval,
sandbox, reasoning, workspace, prompt, and response fields and inspected
for incidents. They were excluded because they contain ephemeral session
identifiers and machine-local workspace paths.
Results apply to these cases, descriptions, controls, model, and host version.
