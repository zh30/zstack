# Codex CLI behavioral run

## Outcome

**2/2 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| discovery-sparse-debrief | z-customer-discovery | pass |
| smoke-mixed-traffic | z-landing-smoke | pass |

## Criterion review

### `discovery-sparse-debrief`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/discovery-sparse-debrief.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The class cell contains only assumption; future interviews and experiments appear only in Next validation. |
| present | Flag compliments, future intent, pitching, and a leading question. | true | The audit explicitly identifies praise, probably-pay future intent, demo-led pitching, and a leading yes/no question. |
| present | Keep G1, G2, and G3 neutral or unsupported without past behavior. | true | The gate table marks G1, G2, and G3 Neutral and explains the missing past behavior, spend, and switch action. |
| absent | Green-light a build or invent missing workflow and spend details. | false | It rejects a large build and neither reconstructs a workflow nor invents expenditure. |

### `smoke-mixed-traffic`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/smoke-mixed-traffic.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The class cell contains only observed experiment for the supplied funnel counts; planned interviews and payment tests are not listed as current classes. |
| present | Refuse to pool warm and cold traffic without source-level conversions. | true | It says the pooled 6% cannot be treated as cold conversion and requires friend-versus-ad attribution. |
| present | Ask for or recommend source-specific counts and a bounded next test. | true | It asks for source-attributed confirmed signups and a bounded 200-qualified-cold-visit retest with thresholds. |
| absent | Treat the aggregate 6% as proof of demand or recommend a full build. | false | It calls the aggregate inadequate and explicitly rejects a full build. |

## Execution controls

Codex CLI 0.146.0 used `gpt-5.6-sol` with
medium reasoning, one ephemeral turn per case,
exact copied skill snapshots, generated prompts through stdin, isolated
initialized Git workspaces, a minimal per-case `CODEX_HOME`, a read-only sandbox,
approval policy `never`, ignored user config/rules, removed ambient desktop context,
and disabled web/browser/apps/computer access
and subagents.

## Runner incidents

No recognized runner incidents were recorded.

Private runner records corroborated host, requested and actual model, permissions,
isolation flags, workspaces, prompt bytes, response bytes, and incident counts, then
were excluded because they contain ephemeral session identifiers and local
paths. Results apply to the retained skill snapshots and execution controls.
