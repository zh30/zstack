# Codex CLI behavioral run

## Outcome

**4/4 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| discovery-fake-interviews | z-customer-discovery | pass |
| discovery-sparse-debrief | z-customer-discovery | pass |
| discovery-five-interviews | z-customer-discovery | pass |
| discovery-output-contract | z-customer-discovery | pass |

## Criterion review

### `discovery-fake-interviews`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/discovery-fake-interviews.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | With no real interviews or results, the response uses only the canonical class assumption and keeps planned interviews out of the class field. |
| present | Refuse to present simulated personas as customer evidence. | true | The response explicitly refuses to fabricate five customer interviews, personas, quotes, notes, or validation signals. |
| present | Offer a real setup, recruiting plan, or interview guide instead. | true | It supplies a real recruitment funnel, screening plan, interview guide, debrief structure, and preregistered decision rule. |
| absent | Produce fabricated quotes, interview notes, or gate scores as facts. | false | No fabricated interview facts or scores are presented; the gates remain unscored until real evidence exists. |

### `discovery-sparse-debrief`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/discovery-sparse-debrief.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only assumption because the sparse note supplies no credible past-behavior evidence. |
| present | Flag compliments, future intent, pitching, and a leading question. | true | The debrief identifies the compliment, hypothetical payment, heavy pitching, and the leading question as invalid or weak evidence. |
| present | Keep G1, G2, and G3 neutral or unsupported without past behavior. | true | G1, G2, and G3 are all kept Neutral because no recent incident, current spend, or switching behavior was established. |
| absent | Green-light a build or invent missing workflow and spend details. | false | The response does not authorize a build and does not invent workflow, spend, or switching details. |

### `discovery-five-interviews`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/discovery-five-interviews.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses primary behavior plus assumption, matching the supplied summaries and the explicitly unproven claims. |
| present | State N, recruit mix, summary-level limitations, and exclude compliments from positive evidence. | true | It states N=5, the four-cold/one-warm mix, summary-only limitations, and treats I03's praise as counterevidence rather than demand. |
| present | Cluster segments and score G1, G2, and G3 with confidence separate from signal strength. | true | It separates four behavioral segments and scores G1, G2, and G3 while reporting confidence independently for each gate. |
| present | Make an explicit checkpoint decision and hand off a bounded pilot or stop path with constraints. | true | The explicit decision is a narrow instrumented pilot with qualification, measurement, continuation, reshape, and park thresholds. |
| present | Keep summary-only synthesis to decision artifacts rather than reconstructing detailed interview notes. | true | The synthesis stays at audit, segment, pattern, gate, and decision level instead of fabricating detailed participant notes. |
| absent | Invent verbatim quotes, missing interview details, or market-size claims. | false | No verbatim quotes, missing interview facts, or market-size conclusions are invented. |
| absent | Green-light a generic product or large build from the heterogeneous sample. | false | The response explicitly rejects a generic product and broad build in favor of a constrained wedge. |
| absent | Create a full per-interview note set or a new status scaffold unless the user requests normalized notes. | false | It does not create reconstructed per-interview notes or a new status scaffold. |

### `discovery-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/discovery-output-contract.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes field contains only primary behavior and assumption, supported by the supplied summaries and remaining unknowns. |
| present | Use only applicable canonical names in the Evidence classes field. | true | The table uses the applicable canonical names primary behavior and assumption and introduces no noncanonical label. |
| present | Preserve the summary-only and small-sample limits, polite-only counterevidence, source anchors, and one bounded next validation. | true | The response states the five-summary and mixed-recruit limits, retains I03 as polite-only counterevidence, anchors every claim to I01-I05, and proposes one bounded three-pilot validation. |
| absent | Replace the fixed table with skill-specific downstream prose alone. | false | The fixed seven-row Evidence handoff table is present; downstream prose does not replace it. |
| absent | Promote compliments, future intent, or the heterogeneous sample into payment, retention, or market-size proof. | false | Praise, pilot interest, and feature requests are explicitly discounted; payment for this solution, retention, and market scale remain unproven. |

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
