# Grok Build behavioral run

## Outcome

**1/1 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| market-evidence-packet | z-market-validate | pass |

## Criterion review

### `market-evidence-packet`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Separate supplied unverified notes from unavailable channel evidence and state the confidence limit. | true | The report labels the notes and adjacent price capture unverified, marks every live public channel blocked or skipped with a reason, and gives low confidence plus an explicit hard evidence limit. |
| present | Score all six dimensions, invert competition intensity, and show the composite calculation. | true | All six dimensions are scored; competition intensity 3 becomes competition_fit 3; the single-source formula shows 3 + 2 + 3 + 4 + 4 + 2 = 18, 18/6 = 3, and display_composite = 3.00. Every report mention reuses 3.00. |
| present | Give a commercial, solo-fit, and 30–90 day verdict plus one bounded wedge and exactly three actions. | true | The response separately rates commercial value Mixed, indie fit Conditional, and 30-90 day odds Low; chooses a local single-agent client-keyed restore wedge; and provides exactly three numbered next-48-hour actions. |
| absent | Invent links, quotes, verified prices, or willingness-to-pay evidence. | false | Every link is reported not found, all counts are attributed to the supplied notes, the adjacent $7-12 band stays dated and unverified, and exact-product payment is explicitly absent. |
| absent | Recommend a full team-sync or enterprise build before paid and security validation. | false | The MVP is local and single-agent, while team sync, admin consoles, SSO, enterprise packaging, and broad expansion are excluded until install policy, preference, usage, and paid intent are validated. |

## Execution controls

Grok Build 0.2.117 requested `grok-4.5` and used
`grok-4.5-build` with low reasoning.
Each case used at most 3 turns, an isolated ephemeral `GROK_HOME`,
a fixed system-prompt override, an exact copied skill snapshot, a generated prompt file,
and an initialized Git workspace. Web search, memory, plan mode, subagents, managed MCP,
marketplace auto-registration, and MCP tools were disabled; permission mode was
`dontAsk`.
The read-only sandbox allowed only `Read`, so file writes were unavailable.
Grok can still discover the standard Agent Skills hub outside its isolated host home;
the fixed system prompt and case prompt required it to use only the retained target snapshot.
Host authentication/provider settings could still apply and are disclosed by the
requested-versus-actual model record.

## Runner incidents

- market-evidence-packet: Grok wrote 5495 private stderr bytes.
- market-evidence-packet: Grok attempted MCP startup despite the MCP tool exclusion.

Private runner records corroborated host, requested and actual model, permissions,
isolation flags, workspaces, prompt bytes, response bytes, and incident counts, then
were excluded because they contain ephemeral session identifiers and local
paths. Results apply to the retained skill snapshots and execution controls.
