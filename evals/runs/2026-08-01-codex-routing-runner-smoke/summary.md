# Codex routing run

## Outcome

**1/1 passed.**

| Case | Expected | Selected | Result |
|------|----------|----------|--------|
| zh-boundary-public-research | z-market-validate | z-market-validate | pass |

## Execution controls

Codex CLI 0.146.0 used `gpt-5.6-sol` with
low reasoning, one ephemeral turn per case,
generated prompts through stdin, isolated initialized Git workspaces, a
read-only sandbox, approval policy `never`, ignored user config/rules, and
disabled tools, apps, skill loading, browser/computer access, and subagents.
Candidate order followed the recorded deterministic rotation.

## Runner incidents

- 1/1 runner logs contained the state-database fallback.
- 1/1 runner logs contained the Cloudflare MCP OAuth invalid_grant.
- 1/1 runner logs contained the installed-skill context-budget warning.

Runner logs were cross-checked against the published host, model, approval,
sandbox, reasoning, workspace, prompt, and response fields and inspected
for incidents. They were excluded because they contain ephemeral session
identifiers and machine-local workspace paths.
Results apply to these cases, descriptions, controls, model, and host version.
