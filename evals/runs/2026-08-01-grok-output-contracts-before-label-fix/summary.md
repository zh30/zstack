# Grok Build behavioral run

## Outcome

**3/5 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| prd-output-contract | z-write-prd | pass |
| market-output-contract | z-market-validate | pass |
| discovery-output-contract | z-customer-discovery | fail |
| landing-output-contract | z-landing-smoke | fail |
| seo-output-contract | z-seo-plan | pass |

## Criterion review

### `prd-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include one Evidence handoff table with all seven exact contract field labels. | true | Section 11 contains one handoff table whose first column is exactly Current decision, Evidence classes, Supported claims, Still unproven, Contradictions / exclusions, Source anchors, and Next validation. |
| present | Use only the five canonical evidence classes in the Evidence classes field. | true | The field contains only observed experiment, primary behavior, and assumption. |
| present | Preserve cold/warm separation, unknown payment, contradictions, source anchors, and one bounded next validation. | true | Cold 27/300 plus two pilots and warm 12/40 remain separate, payment and $29 remain unproven, excluded scope is explicit, anchors identify the brief and PRD sections, and one owner/action/accept/kill pilot validation is bounded. |
| present | Keep the default full core PRD at or below 5000 whitespace-delimited words while retaining testable acceptance criteria for every P0. | true | The entire response is 3,755 whitespace-delimited words, and every retained functional and non-functional P0 row has an observable acceptance criterion or validation method. |
| absent | Replace the required handoff table or its field labels with custom prose or subsections. | false | The fixed seven-row table is present and the short sentence after it supplements rather than replaces the contract. |
| absent | Combine warm and cold traffic or present signup and pilot interest as validated payment or retention. | false | The cohorts remain separate throughout; revenue is explicitly not an MVP success metric, no payment was requested, and retention is listed as unproven. |
| absent | Inflate the core with repeated decisions or implementation-level schemas and exhaustive test matrices not requested by the user. | false | The PRD stays within the word cap, uses one conceptual entity table and concise acceptance rows, and contains no implementation schema or exhaustive test matrix. |

### `market-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include one Evidence handoff table with all seven exact contract field labels. | true | Section 12 contains one seven-row table with each required label exactly and without Markdown decoration in the first column. |
| present | Use only applicable canonical names in the Evidence classes field. | true | Evidence classes contains only secondary public and assumption, matching the unverified supplied notes and adjacent capture. |
| present | Preserve supplied-note limits, counterevidence, missing payment proof, source anchors, and one bounded next validation. | true | The table identifies the notes as the only unverified source, retains Chrome groups, bookmarks, admin blocks, and no-payment evidence, and gives one founder-owned 48-hour validation with success and fail gates. |
| absent | Rename, split, or replace required handoff rows with custom fields or prose. | false | No required row is renamed, split, or replaced. |
| absent | Promote supplied notes or adjacent pricing into verified primary behavior, payment, or retention evidence. | false | The notes and $7-12 band stay unverified, exact-product payment is absent, and actual switching, payment, and retention remain unproven. |

### `discovery-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include one Evidence handoff table with all seven exact contract field labels. | false | The table has seven semantic rows, but every first-column label is wrapped in Markdown bold markers, for example **Current decision** and **Evidence classes**, so the cell text is not the exact fixed contract label. |
| present | Use only applicable canonical names in the Evidence classes field. | true | The value contains only primary behavior, an applicable canonical class for the supplied interview summaries. |
| present | Preserve the summary-only and small-sample limits, polite-only counterevidence, source anchors, and one bounded next validation. | true | The response states N=5 and summaries-only limits, excludes the warm founder compliment, anchors S01-S05, and provides one owner/action/success/fail pilot validation. |
| absent | Replace the fixed table with skill-specific downstream prose alone. | false | A seven-row table is present; the downstream artifact map is additional rather than a prose-only replacement. |
| absent | Promote compliments, future intent, or the heterogeneous sample into payment, retention, or market-size proof. | false | The compliment-only warm founder is excluded, the pilot ask is not called payment, and price, retention, and scale beyond N=5 remain unproven. |

### `landing-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include one Evidence handoff table with all seven exact contract field labels. | false | The table contains seven semantic rows, but each fixed first-column label is Markdown-bolded, so **Current decision** and the other decorated cells are not exact contract labels. |
| present | Use only applicable canonical names in the Evidence classes field. | true | The value contains only assumption, which is canonical and appropriate before the smoke test runs. |
| present | Use TBD after test for result-dependent claims and retain warm/cold, attribution, invalid-event, source-anchor, and next-validation boundaries. | true | The table uses TBD after test for the decision, supported claims, and contradictions; keeps source classes separate; distinguishes attempts from provider-confirmed subscribers; anchors Plausible, Buttondown, spend, and outreach; and gives a bounded Day-10 branch. |
| absent | Rename the fixed rows into metric-specific custom fields. | false | The semantic row names are not replaced by metric-specific custom names; the failure is Markdown decoration around otherwise correct labels. |
| absent | Present attempts, hypotheses, signups, or planned price as confirmed payment, product value, or retention. | false | The planned $9 price, thresholds, and all traffic results remain hypotheses or TBD; submit attempts are explicitly invalid as confirmed conversion and payment/value/retention stay unproven. |

### `seo-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include one Evidence handoff table with all seven exact contract field labels. | true | Section 12 contains one table with all seven unformatted fixed labels exactly. |
| present | Use only applicable canonical names in the Evidence classes field. | true | The field contains only search signal and assumption. |
| present | Preserve supplied-note limits, search uncertainty, contradictory SERP evidence, source anchors, and one bounded next validation. | true | The table keeps volumes, rankings, traffic, and live SERPs unproven; preserves the CRM/portal-dominated contradiction; anchors the user brief and blocked channels; and gives one founder-owned SERP plus GSC validation with a decision signal. |
| absent | Merge risks and Evidence handoff into free text or rename the fixed rows. | false | Risks remain Section 11 and the fixed handoff remains a separate exact-label table. |
| absent | Promote search opportunity, planned pages, or guessed bands into observed ranking, traffic, payment, product-market-fit, or retention proof. | false | All bands are unverified, pages are planned, and rankings, traffic, signups, payment, PMF, and retention are explicitly listed as unproven. |

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

- prd-output-contract: Grok wrote 5495 private stderr bytes.
- prd-output-contract: Grok attempted MCP startup despite the MCP tool exclusion.
- market-output-contract: Grok wrote 5495 private stderr bytes.
- market-output-contract: Grok attempted MCP startup despite the MCP tool exclusion.
- discovery-output-contract: Grok wrote 5676 private stderr bytes.
- discovery-output-contract: Grok attempted MCP startup despite the MCP tool exclusion.
- landing-output-contract: Grok wrote 5495 private stderr bytes.
- landing-output-contract: Grok attempted MCP startup despite the MCP tool exclusion.
- seo-output-contract: Grok wrote 5495 private stderr bytes.
- seo-output-contract: Grok attempted MCP startup despite the MCP tool exclusion.

Private runner records corroborated host, requested and actual model, permissions,
isolation flags, workspaces, prompt bytes, response bytes, and incident counts, then
were excluded because they contain ephemeral session identifiers and local
paths. Results apply to the retained skill snapshots and execution controls.
