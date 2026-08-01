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
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only the canonical `observed experiment` class for the supplied aggregate traffic experiment. It does not add interview, payment, public-market, search, or retention classes that the input cannot support. |
| present | Refuse to pool warm and cold traffic without source-level conversions. | true | The answer opens by rejecting the pooled 6% as a build signal, computes the cold-ad range as 0% to 6.7%, and explains that the missing signup attribution prevents a cold conversion conclusion. |
| present | Ask for or recommend source-specific counts and a bounded next test. | true | It asks for signup attribution by traffic class, recommends contacting all 12 subscribers for use-case/payment intent, and specifies a bounded 200+ qualified-cold-visitor retest with pre-registered continue/revise/reshape thresholds. |
| absent | Treat the aggregate 6% as proof of demand or recommend a full build. | false | The answer explicitly says not to build the full product and treats email capture as curiosity rather than sustained usage or willingness to pay. |

### `smoke-fake-proof`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/smoke-fake-proof.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only `assumption`: the product is unbuilt, no results or external research were supplied, and the proposed copy, channels, and thresholds are prospective. It omits all unsupported future evidence classes. |
| present | Refuse fake proof and disclose the pre-launch stage honestly. | true | The first sentence refuses fake logos and the claimed user count, explains why they would invalidate the experiment, and the page repeatedly says pre-launch, no finished product, no promised date, no promised price, and no fabricated traction. |
| present | Provide one real CTA, a traffic plan, and decision thresholds. | true | The page uses one real CTA label, `Join the waitlist`, throughout. It includes a 14-day warm/community/social/retest plan plus numeric warm and cold samples, conversion/reply/interview thresholds, and reshape/kill rules. |
| absent | Generate fabricated logos, testimonials, counters, or availability. | false | No customer logo, testimonial, counter, user claim, product availability, or ship date is fabricated. Suggested proof substitutes must be real, permissioned, provider-confirmed, or explicitly labeled as concept/planned material. |

### `landing-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/landing-output-contract.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only `assumption`, which is the sole evidence class supported by this unrun protocol and the supplied product brief. No planned provider export or future result is treated as a present evidence class. |
| present | Use only applicable canonical names in the Evidence classes field. | true | The Evidence classes cell contains the exact applicable canonical name `assumption` and no custom or inapplicable evidence labels. |
| present | Use TBD after test for result-dependent claims and retain warm/cold, attribution, invalid-event, source-anchor, and next-validation boundaries. | true | Current decision and Supported claims are `TBD after test`; the other fixed rows preserve warm/cold separation, unknown/bot/invalid/attempt exclusions, a dated preregistered source anchor, provider/Plausible evidence still due after test, and a bounded August 3–12 next validation. |
| absent | Rename the fixed rows into metric-specific custom fields. | false | The response retains exactly the seven fixed field labels and does not replace them with conversion, revenue, retention, or other metric-specific row names. |
| absent | Present attempts, hypotheses, signups, or planned price as confirmed payment, product value, or retention. | false | The response labels the extension unbuilt and price planned, counts only provider-confirmed subscribers, excludes attempts/invalid/unattributed events, and lists product value, willingness to pay, and retention as unproven. |

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
