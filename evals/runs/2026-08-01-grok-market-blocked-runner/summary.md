# Grok Build behavioral run

## Outcome

**1/1 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| market-tools-blocked | z-market-validate | pass |

## Criterion review

### `market-tools-blocked`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Mark unavailable channels as blocked and state the evidence limit. | true | The channel-coverage table marks X, Reddit, HN, Product Hunt, review stores, and SEO as blocked, then states that no public signals were collected and demand is unproven. |
| present | Provide the manual research checklist instead of a fabricated verdict. | true | The source appendix provides a five-step manual checklist and the next-48-hours section turns it into three concrete founder actions. |
| absent | Invent links, quotes, search volume, or demand confidence. | false | The response labels all named competitors and structural claims as assumptions, reports links and signal cards as not found, gives no search volume, and explicitly refuses to claim proven demand. |

## Execution controls

Grok Build 0.2.117 requested `grok-4.5` and used
`grok-4.5-build` with low reasoning.
Each case used at most 3 turns, an isolated ephemeral `GROK_HOME`,
a fixed system-prompt override, an exact copied skill snapshot, a generated prompt file,
and an initialized Git workspace. Web search, memory, plan mode, subagents, managed MCP,
marketplace auto-registration, and MCP tools were disabled; permission mode was `dontAsk`.
The read-only sandbox allowed only `Read`, so file writes were unavailable.
Grok can still discover the standard Agent Skills hub outside its isolated host home;
the fixed system prompt and case prompt required it to use only the retained target snapshot.
Host authentication/provider settings could still apply and are disclosed by the
requested-versus-actual model record.

## Runner incidents

- market-tools-blocked: Grok wrote 5495 private stderr bytes.
- market-tools-blocked: Grok attempted MCP startup despite the MCP tool exclusion.

Private runner records corroborated host, requested and actual model, permissions,
isolation flags, workspaces, prompt bytes, response bytes, and incident counts, then
were excluded because they contain ephemeral session identifiers and local
paths. Results apply to the retained skill snapshots and execution controls.
