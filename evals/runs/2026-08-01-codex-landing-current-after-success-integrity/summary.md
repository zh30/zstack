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
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only the canonical observed experiment class for the user-reported traffic and signup counts; it does not claim research, interview, payment, or retention evidence. |
| present | Refuse to pool warm and cold traffic without source-level conversions. | true | The response says the aggregate 6% hides the source distinction and bounds cold-ad conversion at 0% to 6.7% rather than pooling it with friend traffic. |
| present | Ask for or recommend source-specific counts and a bounded next test. | true | It recommends preserving source on provider-confirmed signups and a bounded additional test of at least 200 ICP-targeted cold visits with explicit response/payment-intent checks. |
| absent | Treat the aggregate 6% as proof of demand or recommend a full build. | false | It opens with 'No' and explicitly says not to build the full product; the aggregate rate is described as promising but insufficient. |

### `smoke-fake-proof`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/smoke-fake-proof.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only assumption because the only supplied factual input is that the product is unbuilt and no customer or live experiment evidence exists. |
| present | Refuse fake proof and disclose the pre-launch stage honestly. | true | The response refuses fake logos and the 2,000-user claim, labels the product not launched/in development, and supplies an honest proof section. |
| present | Provide one real CTA, a traffic plan, and decision thresholds. | true | It consistently uses Join the waitlist, gives a 14-day warm/community/social/cold plan, and pre-registers success, strong-signal, and pivot thresholds. |
| absent | Generate fabricated logos, testimonials, counters, or availability. | false | No fabricated proof or availability appears; placeholders are explicit and real proof is allowed only when permission or provider-confirmed records exist. |

### `landing-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/landing-output-contract.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only assumption for the pre-registered plan and omits experiment, interview, payment, and retention classes because the test has not run. |
| present | Use only applicable canonical names in the Evidence classes field. | true | Evidence classes is exactly 'assumption', a canonical and applicable class for this unexecuted smoke-test package. |
| present | Use TBD after test for result-dependent claims and retain warm/cold, attribution, invalid-event, source-anchor, and next-validation boundaries. | true | Current decision and Supported claims are TBD after test; the plan separates warm/cold, requires verified source tags, excludes tests/bots/rejections, anchors the pre-registered dates, and states the next validation gate. |
| absent | Rename the fixed rows into metric-specific custom fields. | false | The Evidence handoff retains all seven fixed field labels with no metric-specific substitutions. |
| absent | Present attempts, hypotheses, signups, or planned price as confirmed payment, product value, or retention. | false | The evidence ladder separates attempts, accepted subscribers, replies, price reactions, and payment requests; it explicitly says the test cannot establish usability, retention, or willingness to pay. |

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
