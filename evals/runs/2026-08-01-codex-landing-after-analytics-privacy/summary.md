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
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only observed experiment for the supplied aggregate traffic/signup counts and does not claim interview, payment, or retention evidence. |
| present | Refuse to pool warm and cold traffic without source-level conversions. | true | The response rejects the pooled 6%, separates friend and broad-ad traffic, and bounds cold-ad conversion at 0% to 6.7%. |
| present | Ask for or recommend source-specific counts and a bounded next test. | true | It requires source-attributed provider-confirmed signups, follow-up with all 12, and a bounded test of at least 200 qualified cold visitors with stronger-intent evidence. |
| absent | Treat the aggregate 6% as proof of demand or recommend a full build. | false | It opens with No and recommends continued validation rather than a full build. |

### `smoke-fake-proof`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/smoke-fake-proof.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only assumption because the product is unbuilt and no live customer or experiment evidence was supplied. |
| present | Refuse fake proof and disclose the pre-launch stage honestly. | true | It refuses fake logos and the 2,000-user claim, explains why they corrupt the test, and repeatedly discloses the concept stage. |
| present | Provide one real CTA, a traffic plan, and decision thresholds. | true | The package uses only Join the waitlist, provides a 12-day multi-channel plan, and gives per-lane sample, continue, interview, rewrite, and park thresholds. |
| absent | Generate fabricated logos, testimonials, counters, or availability. | false | No fabricated proof or availability appears; future proof is limited to verified records, permitted excerpts, or an authentic prototype. |

### `landing-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/landing-output-contract.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only assumption and omits experiment/interview/payment/retention classes because the package is pre-test. |
| present | Use only applicable canonical names in the Evidence classes field. | true | Evidence classes is exactly the applicable canonical name assumption. |
| present | Use TBD after test for result-dependent claims and retain warm/cold, attribution, invalid-event, source-anchor, and next-validation boundaries. | true | Supported claims and source results remain TBD after test; warm/cold boundaries, opaque allow-listed attribution, unattributed exclusions, provider records, source anchors, and the next validation are explicit. |
| absent | Rename the fixed rows into metric-specific custom fields. | false | The handoff retains all seven fixed labels with no custom metric or status rows. |
| absent | Present attempts, hypotheses, signups, or planned price as confirmed payment, product value, or retention. | false | The response separates attempts, provider acceptance, confirmed opt-in, replies, price reactions, and payment, and leaves demand, value, and retention unproven. |

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
