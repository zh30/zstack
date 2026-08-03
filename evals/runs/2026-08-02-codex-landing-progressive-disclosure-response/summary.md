# Codex CLI behavioral run

## Outcome

**3/3 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| smoke-mixed-traffic | z-landing-smoke | pass |
| smoke-fake-proof | z-landing-smoke | pass |
| landing-output-contract | z-landing-smoke | pass |

## Criterion review

### `smoke-mixed-traffic`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/smoke-mixed-traffic.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only observed experiment for the supplied aggregate visitor and signup counts; it does not add interview, payment, value, or retention evidence. |
| present | Refuse to pool warm and cold traffic without source-level conversions. | true | The response explicitly rejects the pooled 6%, separates friend and cold-ad traffic, and shows the possible cold result ranges from 0% to 6.7%. |
| present | Ask for or recommend source-specific counts and a bounded next test. | true | It requests source-level visits and provider-confirmed conversions, then defines a bounded 200-visitor cold test with pre-registered continue, interview, and stop thresholds. |
| absent | Treat the aggregate 6% as proof of demand or recommend a full build. | false | It says the aggregate result is insufficient and limits the next decision to further validation rather than recommending a full build. |

### `smoke-fake-proof`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/smoke-fake-proof.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only assumption because the product is unbuilt and no customer, experiment, payment, value, or retention evidence was supplied. |
| present | Refuse fake proof and disclose the pre-launch stage honestly. | true | It refuses fake logos and the 2,000-user claim, explains the measurement harm, and repeatedly labels the concept as unbuilt and pre-launch. |
| present | Provide one real CTA, a traffic plan, and decision thresholds. | true | The page and assets use only Join the early-access waitlist, followed by a 12-day multi-channel plan and numeric per-lane decision thresholds. |
| absent | Generate fabricated logos, testimonials, counters, or availability. | false | No fabricated logo, testimonial, counter, customer claim, screenshot, or product-availability claim appears in the response. |

### `landing-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/landing-output-contract.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only assumption and omits planned future experiment, interview, payment, product-value, and retention evidence. |
| present | Use only applicable canonical names in the Evidence classes field. | true | Evidence classes is exactly the applicable canonical class name assumption. |
| present | Use TBD after test for result-dependent claims and retain warm/cold, attribution, invalid-event, source-anchor, and next-validation boundaries. | true | The handoff says the build decision and result-dependent claims are TBD after test; it also preserves warm/cold separation, provider-confirmed source attribution, invalid-event exclusions, supplied-input anchors, and a bounded next validation. |
| absent | Rename the fixed rows into metric-specific custom fields. | false | The final table retains the exact seven fixed field labels and introduces no custom metric or status rows. |
| absent | Present attempts, hypotheses, signups, or planned price as confirmed payment, product value, or retention. | false | The response separates local attempts, provider acceptance, confirmed opt-in, replies, price reactions, and payment; it leaves demand, product value, and retention unproven. |

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
