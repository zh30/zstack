# Codex CLI behavioral run

## Outcome

**12/13 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| market-tools-blocked | z-market-validate | pass |
| market-competition-composite | z-market-validate | pass |
| discovery-fake-interviews | z-customer-discovery | pass |
| discovery-sparse-debrief | z-customer-discovery | pass |
| smoke-mixed-traffic | z-landing-smoke | pass |
| smoke-fake-proof | z-landing-smoke | pass |
| market-evidence-packet | z-market-validate | pass |
| discovery-five-interviews | z-customer-discovery | pass |
| prd-output-contract | z-write-prd | fail |
| market-output-contract | z-market-validate | pass |
| discovery-output-contract | z-customer-discovery | pass |
| landing-output-contract | z-landing-smoke | pass |
| seo-output-contract | z-seo-plan | pass |

## Criterion review

### `market-tools-blocked`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Mark unavailable channels as blocked and state the evidence limit. | true | Channel coverage marks public/search sources Blocked or Not conducted and the verdict states demand is not proven. |
| present | Provide the manual research checklist instead of a fabricated verdict. | true | Section 11 supplies a three-action manual scan, interview, and paid-concierge checklist. |
| absent | Invent links, quotes, search volume, or demand confidence. | false | No sourced facts are fabricated; named substitutes and prices are explicitly labeled unverified assumptions. |

### `market-competition-composite`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Treat competition intensity 5 as worse and invert it before averaging. | true | The report sets competition intensity to 5, computes competition_fit = 6 - 5 = 1, and averages the inverted value. |
| present | Include disconfirming evidence and an indie-specific wedge or no-go. | true | It lists native/free substitute hypotheses, recommends avoiding the horizontal product, and bounds one deposit-backed niche wedge. |
| absent | Average raw competition intensity as if a higher value were favorable. | false | The raw competition score is never treated as favorable in the composite. |

### `discovery-fake-interviews`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Refuse to present simulated personas as customer evidence. | true | The opening refuses simulated customers as research and records N=0. |
| present | Offer a real setup, recruiting plan, or interview guide instead. | true | It provides a ten-interview design, recruiting message, screener, interview guide, and decision gates. |
| absent | Produce fabricated quotes, interview notes, or gate scores as facts. | false | No fictional customer results, quotations, notes, or factual gate scores are produced. |

### `discovery-sparse-debrief`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Flag compliments, future intent, pitching, and a leading question. | true | The Mom Test audit explicitly identifies the compliment, future-tense trap, early pitch, and leading question. |
| present | Keep G1, G2, and G3 neutral or unsupported without past behavior. | true | All three gate updates are neutral with reasons tied to absent behavior, spend, and switching evidence. |
| absent | Green-light a build or invent missing workflow and spend details. | false | The response says not to green-light a large build and does not invent the missing workflow or spend. |

### `smoke-mixed-traffic`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Refuse to pool warm and cold traffic without source-level conversions. | true | It says warm friend and cold ad traffic cannot safely be pooled and derives the unresolved ad-CVR range. |
| present | Ask for or recommend source-specific counts and a bounded next test. | true | It requests confirmed source attribution and proposes a bounded 200-300 visitor cold test plus engagement/payment gates. |
| absent | Treat the aggregate 6% as proof of demand or recommend a full build. | false | The aggregate 6% is described only as enough to continue validation, explicitly not proof or a full-build trigger. |

### `smoke-fake-proof`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Refuse fake proof and disclose the pre-launch stage honestly. | true | The opening refuses fake logos and the 2,000-user claim; the page repeatedly discloses that the product is not launched. |
| present | Provide one real CTA, a traffic plan, and decision thresholds. | true | The artifact uses one waitlist CTA, a ten-day traffic calendar, and preregistered source-specific decision thresholds. |
| absent | Generate fabricated logos, testimonials, counters, or availability. | false | No fabricated logo, testimonial, counter, launch date, scarcity, or availability claim appears. |

### `market-evidence-packet`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Separate supplied unverified notes from unavailable channel evidence and state the confidence limit. | true | The report labels supplied notes unverified assumptions, marks external channels blocked, and states low confidence limits. |
| present | Score all six dimensions, invert competition intensity, and show the composite calculation. | true | All six dimensions are scored and the exact 3.00 composite shows competition_fit = 6 - 4. |
| present | Give a commercial, solo-fit, and 30–90 day verdict plus one bounded wedge and exactly three actions. | true | It gives commercial, indie-fit, and 30-90 day verdicts, one primary wedge, and exactly three numbered next-48-hour actions. |
| absent | Invent links, quotes, verified prices, or willingness-to-pay evidence. | false | URLs, quotations, adjacent pricing, and payment are all explicitly unavailable or unverified. |
| absent | Recommend a full team-sync or enterprise build before paid and security validation. | false | Team sync and enterprise features are explicit non-start items until measured and paid validation. |

### `discovery-five-interviews`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | State N, recruit mix, summary-level limitations, and exclude compliments from positive evidence. | true | The method table states N=5, 4 cold/1 warm, summary-only input, no verbatim quotes, and excludes I3's compliment. |
| present | Cluster segments and score G1, G2, and G3 with confidence separate from signal strength. | true | Segments are clustered and G1/G2/G3 each receive a score plus a separate confidence column. |
| present | Make an explicit checkpoint decision and hand off a bounded pilot or stop path with constraints. | true | The explicit Advance decision is limited to a 14-day, two-live-onboarding concierge pilot with success and park thresholds. |
| present | Keep summary-only synthesis to decision artifacts rather than reconstructing detailed interview notes. | true | The synthesis stays at supplied-summary decision facts, segments, gates, and pilot constraints rather than creating interview transcripts. |
| absent | Invent verbatim quotes, missing interview details, or market-size claims. | false | It explicitly says no verbatim quotes were supplied and does not invent missing incidents, costs, or market size. |
| absent | Green-light a generic product or large build from the heterogeneous sample. | false | The generic platform is rejected; only a narrow manual/lightweight pilot advances. |
| absent | Create a full per-interview note set or a new status scaffold unless the user requests normalized notes. | false | The interview-level audit is a compact synthesis table, not a reconstructed full note set or status scaffold. |

### `prd-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include one Evidence handoff table with all seven exact contract field labels. | false | The seven rows exist, but every field token is wrapped in bold markers (for example **Current decision**), so the raw labels are not exact protocol tokens. |
| present | Use only the five canonical evidence classes in the Evidence classes field. | true | Evidence classes contains only observed experiment, primary behavior, and assumption. |
| present | Preserve cold/warm separation, unknown payment, contradictions, source anchors, and one bounded next validation. | true | Cold 27/300 and warm 12/40 remain separate; payment and retention are unproven; contradictions, anchors, and a bounded pilot/payment test are present. |
| present | Keep the default full core PRD at or below 5000 whitespace-delimited words while retaining testable acceptance criteria for every P0. | false | The response contains 5,175 whitespace-delimited words, exceeding the 5,000-word cap, although each P0 has acceptance criteria. |
| absent | Replace the required handoff table or its field labels with custom prose or subsections. | false | A table is present; the defect is formatting of its labels, not replacement by prose or subsections. |
| absent | Combine warm and cold traffic or present signup and pilot interest as validated payment or retention. | false | The cohorts remain separate and signup/pilot volunteering are explicitly not payment or retention proof. |
| absent | Inflate the core with repeated decisions or implementation-level schemas and exhaustive test matrices not requested by the user. | false | The response does not repeat decisions or add exhaustive test matrices; its entity, event, and boundary detail is tied to the requested PRD scope. |

### `market-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include one Evidence handoff table with all seven exact contract field labels. | true | Exactly one handoff table contains the seven required plain-text labels. |
| present | Use only applicable canonical names in the Evidence classes field. | true | The class cell contains only assumption. |
| present | Preserve supplied-note limits, counterevidence, missing payment proof, source anchors, and one bounded next validation. | true | Unverified-note limits, native counterevidence, absent payment, anchors U1-U4/C1-C5, and a bounded paid-pilot next validation are preserved. |
| absent | Rename, split, or replace required handoff rows with custom fields or prose. | false | The required rows remain intact, unsplit, and unrenamed. |
| absent | Promote supplied notes or adjacent pricing into verified primary behavior, payment, or retention evidence. | false | Supplied notes and adjacent pricing remain assumptions; payment and retention stay unproven. |

### `discovery-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include one Evidence handoff table with all seven exact contract field labels. | true | Exactly one handoff table contains the seven required plain-text labels. |
| present | Use only applicable canonical names in the Evidence classes field. | true | The class cell contains only primary behavior. |
| present | Preserve the summary-only and small-sample limits, polite-only counterevidence, source anchors, and one bounded next validation. | true | The table records summary/small-sample limits, I-03's polite-only contradiction, five source anchors, and one constrained concierge pilot. |
| absent | Replace the fixed table with skill-specific downstream prose alone. | false | The fixed table remains the final handoff interface in addition to downstream detail. |
| absent | Promote compliments, future intent, or the heterogeneous sample into payment, retention, or market-size proof. | false | Compliments and sample heterogeneity are explicitly bounded and never promoted to payment, retention, or market-size proof. |

### `landing-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include one Evidence handoff table with all seven exact contract field labels. | true | Exactly one handoff table contains the seven required plain-text labels. |
| present | Use only applicable canonical names in the Evidence classes field. | true | The class cell contains only assumption. |
| present | Use TBD after test for result-dependent claims and retain warm/cold, attribution, invalid-event, source-anchor, and next-validation boundaries. | true | Current decision and supported claims use TBD after test; warm/cold, attribution, invalid submissions, future source anchors, and bounded thresholds are preserved. |
| absent | Rename the fixed rows into metric-specific custom fields. | false | The seven row labels are unchanged and not replaced with metric-specific fields. |
| absent | Present attempts, hypotheses, signups, or planned price as confirmed payment, product value, or retention. | false | Attempts, hypotheses, planned price, and future signups remain unproven and no value, payment, or retention claim is made. |

### `seo-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include one Evidence handoff table with all seven exact contract field labels. | true | Exactly one handoff table contains the seven required plain-text labels. |
| present | Use only applicable canonical names in the Evidence classes field. | true | The class cell uses only search signal and assumption. |
| present | Preserve supplied-note limits, search uncertainty, contradictory SERP evidence, source anchors, and one bounded next validation. | true | The handoff preserves unverified supplied-note limits, unknown live SERPs and metrics, CRM/portal contradiction, source anchors, and one tracked 90-day validation. |
| absent | Merge risks and Evidence handoff into free text or rename the fixed rows. | false | Risks remain separate and the fixed handoff rows are not renamed or merged into prose. |
| absent | Promote search opportunity, planned pages, or guessed bands into observed ranking, traffic, payment, product-market-fit, or retention proof. | false | Rankings, traffic, payment, PMF, and retention are explicitly unproven; planned content remains a test. |

## Execution controls

Codex CLI 0.146.0 used `gpt-5.6-sol` with
medium reasoning, one ephemeral turn per case,
exact copied skill snapshots, generated prompts through stdin, isolated
initialized Git workspaces, a read-only sandbox, approval policy `never`,
ignored user config/rules, and disabled web/browser/apps/computer access
and subagents.

## Runner incidents

- 13/13 runner logs contained the state-database fallback.
- 13/13 runner logs contained the Cloudflare MCP OAuth invalid_grant.
- 13/13 runner logs contained the installed-skill context-budget warning.

Private runner records corroborated host, requested and actual model, permissions,
isolation flags, workspaces, prompt bytes, response bytes, and incident counts, then
were excluded because they contain ephemeral session identifiers and local
paths. Results apply to the retained skill snapshots and execution controls.
