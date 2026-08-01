# Grok Build behavioral run

## Outcome

**2/2 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| discovery-output-contract | z-customer-discovery | pass |
| landing-output-contract | z-landing-smoke | pass |

## Criterion review

### `discovery-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include one Evidence handoff table with all seven exact contract field labels. | true | Section 8 contains one seven-row table whose first-column cells are the exact unstyled labels Current decision, Evidence classes, Supported claims, Still unproven, Contradictions / exclusions, Source anchors, and Next validation. |
| present | Use only applicable canonical names in the Evidence classes field. | true | The value is primary behavior only, a canonical class appropriate to the supplied interview summaries. |
| present | Preserve the summary-only and small-sample limits, polite-only counterevidence, source anchors, and one bounded next validation. | true | The response states N=5, summaries-only depth, and unknown warm identity; excludes the compliment-only founder from demand; anchors S01-S05; and gives one founder-owned two-week pilot with explicit success and fail conditions. |
| absent | Replace the fixed table with skill-specific downstream prose alone. | false | The fixed table remains the primary interface and the downstream artifact map only supplements it. |
| absent | Promote compliments, future intent, or the heterogeneous sample into payment, retention, or market-size proof. | false | The founder compliment is noise, the pilot ask is not called payment, the mixed-role N=5 sample is not market sizing, and product payment, pilot conversion, retention, and generalizability remain unproven. |

### `landing-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include one Evidence handoff table with all seven exact contract field labels. | true | Section 9 contains one seven-row table with every fixed label written as exact plain text in the first column. |
| present | Use only applicable canonical names in the Evidence classes field. | true | The value is assumption only, which is canonical and accurate before any traffic runs. |
| present | Use TBD after test for result-dependent claims and retain warm/cold, attribution, invalid-event, source-anchor, and next-validation boundaries. | true | Current decision and Supported claims are TBD after test; warm stays separate from non-warm; Buttondown-confirmed subscribers with retained tags are the conversion source; attempts are invalid as conversions; expected dated sources are named; and one Day-10 decision branch is bounded by Section 2 thresholds. |
| absent | Rename the fixed rows into metric-specific custom fields. | false | All fixed row names are retained exactly and no metric-specific field replaces them. |
| absent | Present attempts, hypotheses, signups, or planned price as confirmed payment, product value, or retention. | false | Attempted submits are explicitly not conversions, planned $9 pricing is not charged, result claims remain TBD, and payment, retention, and extension value are listed as unproven. |

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

- discovery-output-contract: Grok wrote 5495 private stderr bytes.
- discovery-output-contract: Grok attempted MCP startup despite the MCP tool exclusion.
- landing-output-contract: Grok wrote 5495 private stderr bytes.
- landing-output-contract: Grok attempted MCP startup despite the MCP tool exclusion.

Private runner records corroborated host, requested and actual model, permissions,
isolation flags, workspaces, prompt bytes, response bytes, and incident counts, then
were excluded because they contain ephemeral session identifiers and local
paths. Results apply to the retained skill snapshots and execution controls.
