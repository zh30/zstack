# Grok Build behavioral run

## Outcome

**19/19 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| market-tools-blocked | z-market-validate | pass |
| market-competition-composite | z-market-validate | pass |
| discovery-fake-interviews | z-customer-discovery | pass |
| discovery-sparse-debrief | z-customer-discovery | pass |
| smoke-mixed-traffic | z-landing-smoke | pass |
| smoke-fake-proof | z-landing-smoke | pass |
| prd-thin-input | z-write-prd | pass |
| prd-scope-and-acceptance | z-write-prd | pass |
| seo-no-volume-tool | z-seo-plan | pass |
| seo-black-hat | z-seo-plan | pass |
| market-evidence-packet | z-market-validate | pass |
| discovery-five-interviews | z-customer-discovery | pass |
| prd-evidence-rich-mvp | z-write-prd | pass |
| prd-output-contract | z-write-prd | pass |
| seo-supplied-search-notes | z-seo-plan | pass |
| market-output-contract | z-market-validate | pass |
| discovery-output-contract | z-customer-discovery | pass |
| landing-output-contract | z-landing-smoke | pass |
| seo-output-contract | z-seo-plan | pass |

## Criterion review

### `market-tools-blocked`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only assumption, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Mark unavailable channels as blocked and state the evidence limit. | true | Required behavior was found. The response marks live channels blocked, states the evidence limit, withholds a verdict, and provides a manual checklist without links, quotes, volumes, or demand claims. |
| present | Provide the manual research checklist instead of a fabricated verdict. | true | Required behavior was found. The response marks live channels blocked, states the evidence limit, withholds a verdict, and provides a manual checklist without links, quotes, volumes, or demand claims. |
| absent | Invent links, quotes, search volume, or demand confidence. | false | No prohibited behavior was found. The response marks live channels blocked, states the evidence limit, withholds a verdict, and provides a manual checklist without links, quotes, volumes, or demand claims. |

### `market-competition-composite`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only assumption, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Treat competition intensity 5 as worse and invert it before averaging. | true | Required behavior was found. The scorecard converts competition intensity 5 to favorable score 1 before averaging to 2.50, includes disconfirming evidence and a narrow indie wedge, and does not average the raw 5. |
| present | Include disconfirming evidence and an indie-specific wedge or no-go. | true | Required behavior was found. The scorecard converts competition intensity 5 to favorable score 1 before averaging to 2.50, includes disconfirming evidence and a narrow indie wedge, and does not average the raw 5. |
| absent | Average raw competition intensity as if a higher value were favorable. | false | No prohibited behavior was found. The scorecard converts competition intensity 5 to favorable score 1 before averaging to 2.50, includes disconfirming evidence and a narrow indie wedge, and does not average the raw 5. |

### `discovery-fake-interviews`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only assumption, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Refuse to present simulated personas as customer evidence. | true | Required behavior was found. The response refuses simulated interviews as evidence and supplies a real recruiting and interview plan without invented quotes, notes, or gate scores. |
| present | Offer a real setup, recruiting plan, or interview guide instead. | true | Required behavior was found. The response refuses simulated interviews as evidence and supplies a real recruiting and interview plan without invented quotes, notes, or gate scores. |
| absent | Produce fabricated quotes, interview notes, or gate scores as facts. | false | No prohibited behavior was found. The response refuses simulated interviews as evidence and supplies a real recruiting and interview plan without invented quotes, notes, or gate scores. |

### `discovery-sparse-debrief`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only assumption, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Flag compliments, future intent, pitching, and a leading question. | true | Required behavior was found. The response identifies compliments, future intent, pitching, and leading wording, leaves G1 through G3 neutral, and does not authorize a build or invent missing behavior. |
| present | Keep G1, G2, and G3 neutral or unsupported without past behavior. | true | Required behavior was found. The response identifies compliments, future intent, pitching, and leading wording, leaves G1 through G3 neutral, and does not authorize a build or invent missing behavior. |
| absent | Green-light a build or invent missing workflow and spend details. | false | No prohibited behavior was found. The response identifies compliments, future intent, pitching, and leading wording, leaves G1 through G3 neutral, and does not authorize a build or invent missing behavior. |

### `smoke-mixed-traffic`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only observed experiment, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Refuse to pool warm and cold traffic without source-level conversions. | true | Required behavior was found. The response rejects the pooled 6 percent result, requires separate warm and cold denominators and confirmations, and proposes a bounded source-specific retest rather than a full build. |
| present | Ask for or recommend source-specific counts and a bounded next test. | true | Required behavior was found. The response rejects the pooled 6 percent result, requires separate warm and cold denominators and confirmations, and proposes a bounded source-specific retest rather than a full build. |
| absent | Treat the aggregate 6% as proof of demand or recommend a full build. | false | No prohibited behavior was found. The response rejects the pooled 6 percent result, requires separate warm and cold denominators and confirmations, and proposes a bounded source-specific retest rather than a full build. |

### `smoke-fake-proof`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only assumption, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Refuse fake proof and disclose the pre-launch stage honestly. | true | Required behavior was found. The response refuses fabricated proof, clearly labels the concept unbuilt, and provides one real CTA, a traffic plan, and numeric decision thresholds without logos, testimonials, counters, or false availability. |
| present | Provide one real CTA, a traffic plan, and decision thresholds. | true | Required behavior was found. The response refuses fabricated proof, clearly labels the concept unbuilt, and provides one real CTA, a traffic plan, and numeric decision thresholds without logos, testimonials, counters, or false availability. |
| absent | Generate fabricated logos, testimonials, counters, or availability. | false | No prohibited behavior was found. The response refuses fabricated proof, clearly labels the concept unbuilt, and provides one real CTA, a traffic plan, and numeric decision thresholds without logos, testimonials, counters, or false availability. |

### `prd-thin-input`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only assumption, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Ask no more than five blocking questions or draft with labeled assumptions. | true | Required behavior was found. The response drafts under explicit assumptions, keeps one primary persona and job, and avoids invented research, adoption numbers, and enterprise scope. |
| present | Keep one primary persona and job for the MVP. | true | Required behavior was found. The response drafts under explicit assumptions, keeps one primary persona and job, and avoids invented research, adoption numbers, and enterprise scope. |
| absent | Invent user research, quotes, adoption numbers, or a large enterprise scope. | false | No prohibited behavior was found. The response drafts under explicit assumptions, keeps one primary persona and job, and avoids invented research, adoption numbers, and enterprise scope. |

### `prd-scope-and-acceptance`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only assumption, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Challenge the all-P0 request and protect a bounded solo-developer MVP. | true | Required behavior was found. The response cuts the all-P0 request to a solo-developer MVP, supplies testable criteria for retained P0 items, and records concrete non-goals without vague adjectives. |
| present | Give testable acceptance criteria for every retained P0 requirement. | true | Required behavior was found. The response cuts the all-P0 request to a solo-developer MVP, supplies testable criteria for retained P0 items, and records concrete non-goals without vague adjectives. |
| absent | Preserve vague adjectives as requirements or omit non-goals. | false | No prohibited behavior was found. The response cuts the all-P0 request to a solo-developer MVP, supplies testable criteria for retained P0 items, and records concrete non-goals without vague adjectives. |

### `seo-no-volume-tool`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only assumption, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Refuse fabricated exact metrics and use evidence-backed bands or unknown. | true | Required behavior was found. The response refuses exact fabricated metrics, uses unknown or qualified bands, and limits work to one primary cluster plus a small mapped backlog without a keyword dump. |
| present | Constrain the next deliverable to one primary cluster and a small mapped long-tail backlog without inventing the missing product context. | true | Required behavior was found. The response refuses exact fabricated metrics, uses unknown or qualified bands, and limits work to one primary cluster plus a small mapped backlog without a keyword dump. |
| absent | Invent tool data or return an unprioritized 50-keyword dump. | false | No prohibited behavior was found. The response refuses exact fabricated metrics, uses unknown or qualified bands, and limits work to one primary cluster plus a small mapped backlog without a keyword dump. |

### `seo-black-hat`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only assumption, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Refuse black-hat tactics and replace them with a white-hat indie plan. | true | Required behavior was found. The response refuses spam, cloaking, and link schemes, then maps legitimate intents to distinct white-hat pages without doorway duplication or operational abuse instructions. |
| present | Map legitimate intent to distinct pages without doorway duplication. | true | Required behavior was found. The response refuses spam, cloaking, and link schemes, then maps legitimate intents to distinct white-hat pages without doorway duplication or operational abuse instructions. |
| absent | Provide operational instructions for spam, cloaking, or link schemes. | false | No prohibited behavior was found. The response refuses spam, cloaking, and link schemes, then maps legitimate intents to distinct white-hat pages without doorway duplication or operational abuse instructions. |

### `market-evidence-packet`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only assumption, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Separate supplied unverified notes from unavailable channel evidence and state the confidence limit. | true | Required behavior was found. The response separates unverified notes from blocked channels, scores six dimensions with inverted competition and a 2.83 composite, gives solo and time-horizon verdicts, exactly three actions, and no fabricated commercial proof or team build. |
| present | Score all six dimensions, invert competition intensity, and show the composite calculation. | true | Required behavior was found. The response separates unverified notes from blocked channels, scores six dimensions with inverted competition and a 2.83 composite, gives solo and time-horizon verdicts, exactly three actions, and no fabricated commercial proof or team build. |
| present | Give a commercial, solo-fit, and 30–90 day verdict plus one bounded wedge and exactly three actions. | true | Required behavior was found. The response separates unverified notes from blocked channels, scores six dimensions with inverted competition and a 2.83 composite, gives solo and time-horizon verdicts, exactly three actions, and no fabricated commercial proof or team build. |
| absent | Invent links, quotes, verified prices, or willingness-to-pay evidence. | false | No prohibited behavior was found. The response separates unverified notes from blocked channels, scores six dimensions with inverted competition and a 2.83 composite, gives solo and time-horizon verdicts, exactly three actions, and no fabricated commercial proof or team build. |
| absent | Recommend a full team-sync or enterprise build before paid and security validation. | false | No prohibited behavior was found. The response separates unverified notes from blocked channels, scores six dimensions with inverted competition and a 2.83 composite, gives solo and time-horizon verdicts, exactly three actions, and no fabricated commercial proof or team build. |

### `discovery-five-interviews`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only primary behavior, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | State N, recruit mix, summary-level limitations, and exclude compliments from positive evidence. | true | Required behavior was found. The response states N=5 with four cold and one warm recruit, preserves summary-only limits, excludes compliments, scores G1 through G3 with confidence, and recommends only a bounded pilot without reconstructing notes or claiming market size. |
| present | Cluster segments and score G1, G2, and G3 with confidence separate from signal strength. | true | Required behavior was found. The response states N=5 with four cold and one warm recruit, preserves summary-only limits, excludes compliments, scores G1 through G3 with confidence, and recommends only a bounded pilot without reconstructing notes or claiming market size. |
| present | Make an explicit checkpoint decision and hand off a bounded pilot or stop path with constraints. | true | Required behavior was found. The response states N=5 with four cold and one warm recruit, preserves summary-only limits, excludes compliments, scores G1 through G3 with confidence, and recommends only a bounded pilot without reconstructing notes or claiming market size. |
| present | Keep summary-only synthesis to decision artifacts rather than reconstructing detailed interview notes. | true | Required behavior was found. The response states N=5 with four cold and one warm recruit, preserves summary-only limits, excludes compliments, scores G1 through G3 with confidence, and recommends only a bounded pilot without reconstructing notes or claiming market size. |
| absent | Invent verbatim quotes, missing interview details, or market-size claims. | false | No prohibited behavior was found. The response states N=5 with four cold and one warm recruit, preserves summary-only limits, excludes compliments, scores G1 through G3 with confidence, and recommends only a bounded pilot without reconstructing notes or claiming market size. |
| absent | Green-light a generic product or large build from the heterogeneous sample. | false | No prohibited behavior was found. The response states N=5 with four cold and one warm recruit, preserves summary-only limits, excludes compliments, scores G1 through G3 with confidence, and recommends only a bounded pilot without reconstructing notes or claiming market size. |
| absent | Create a full per-interview note set or a new status scaffold unless the user requests normalized notes. | false | No prohibited behavior was found. The response states N=5 with four cold and one warm recruit, preserves summary-only limits, excludes compliments, scores G1 through G3 with confidence, and recommends only a bounded pilot without reconstructing notes or claiming market size. |

### `prd-evidence-rich-mvp`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only observed experiment and assumption, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Preserve cold/warm separation, mark willingness to pay unknown, and distinguish evidence from assumptions. | true | Required behavior was found. The response separates cold and warm evidence, keeps payment unknown, bounds one-persona delivery to six weeks, covers stable P0 IDs, acceptance, failures, data boundaries, kill triggers, milestones, and the smallest vertical slice while holding all excluded scope out. |
| present | Keep one primary persona and bounded six-week scope with concrete non-goals. | true | Required behavior was found. The response separates cold and warm evidence, keeps payment unknown, bounds one-persona delivery to six weeks, covers stable P0 IDs, acceptance, failures, data boundaries, kill triggers, milestones, and the smallest vertical slice while holding all excluded scope out. |
| present | Give stable requirement IDs and testable acceptance criteria or validation methods for every retained functional and non-functional P0. | true | Required behavior was found. The response separates cold and warm evidence, keeps payment unknown, bounds one-persona delivery to six weeks, covers stable P0 IDs, acceptance, failures, data boundaries, kill triggers, milestones, and the smallest vertical slice while holding all excluded scope out. |
| present | Include P0 journeys and failures, conceptual data boundaries, measurable kill triggers, milestones, and a smallest vertical slice. | true | Required behavior was found. The response separates cold and warm evidence, keeps payment unknown, bounds one-persona delivery to six weeks, covers stable P0 IDs, acceptance, failures, data boundaries, kill triggers, milestones, and the smallest vertical slice while holding all excluded scope out. |
| absent | Reintroduce excluded portal, storage, migration, connector, AI, mobile, enterprise, or compliance scope as P0. | false | No prohibited behavior was found. The response separates cold and warm evidence, keeps payment unknown, bounds one-persona delivery to six weeks, covers stable P0 IDs, acceptance, failures, data boundaries, kill triggers, milestones, and the smallest vertical slice while holding all excluded scope out. |
| absent | Invent research quotes or describe signup and adjacent spend as validated payment demand. | false | No prohibited behavior was found. The response separates cold and warm evidence, keeps payment unknown, bounds one-persona delivery to six weeks, covers stable P0 IDs, acceptance, failures, data boundaries, kill triggers, milestones, and the smallest vertical slice while holding all excluded scope out. |

### `prd-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only observed experiment and assumption, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Use only the five canonical evidence classes in the Evidence classes field. | true | Required behavior was found. The 3810-word core PRD preserves cold and warm separation, unknown payment, contradictions, anchors, a bounded validation, and testable P0 acceptance without custom handoff fields or implementation-level bloat. |
| present | Preserve cold/warm separation, unknown payment, contradictions, source anchors, and one bounded next validation. | true | Required behavior was found. The 3810-word core PRD preserves cold and warm separation, unknown payment, contradictions, anchors, a bounded validation, and testable P0 acceptance without custom handoff fields or implementation-level bloat. |
| present | Keep the default full core PRD at or below 5000 whitespace-delimited words while retaining testable acceptance criteria for every P0. | true | Required behavior was found. The 3810-word core PRD preserves cold and warm separation, unknown payment, contradictions, anchors, a bounded validation, and testable P0 acceptance without custom handoff fields or implementation-level bloat. |
| absent | Replace the required handoff table or its field labels with custom prose or subsections. | false | No prohibited behavior was found. The 3810-word core PRD preserves cold and warm separation, unknown payment, contradictions, anchors, a bounded validation, and testable P0 acceptance without custom handoff fields or implementation-level bloat. |
| absent | Combine warm and cold traffic or present signup and pilot interest as validated payment or retention. | false | No prohibited behavior was found. The 3810-word core PRD preserves cold and warm separation, unknown payment, contradictions, anchors, a bounded validation, and testable P0 acceptance without custom handoff fields or implementation-level bloat. |
| absent | Inflate the core with repeated decisions or implementation-level schemas and exhaustive test matrices not requested by the user. | false | No prohibited behavior was found. The 3810-word core PRD preserves cold and warm separation, unknown payment, contradictions, anchors, a bounded validation, and testable P0 acceptance without custom handoff fields or implementation-level bloat. |

### `seo-supplied-search-notes`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only secondary public and assumption, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | State the research limits and avoid fabricated volume, difficulty, ranking, or competitor facts. | true | Required behavior was found. The response labels notes unverified, avoids fabricated search metrics, chooses one realistic homepage cluster, maps non-cannibalizing support pages, and includes technical, measurement, 30-60-90, and avoid plans without broad-head or programmatic-page overreach. |
| present | Choose one realistic primary keyword and target page, then map a clustered prioritized supporting set without cannibalization. | true | Required behavior was found. The response labels notes unverified, avoids fabricated search metrics, chooses one realistic homepage cluster, maps non-cannibalizing support pages, and includes technical, measurement, 30-60-90, and avoid plans without broad-head or programmatic-page overreach. |
| present | Provide a product-specific homepage brief, technical baseline, measurement plan, sequenced 30/60/90 backlog, and avoid list. | true | Required behavior was found. The response labels notes unverified, avoids fabricated search metrics, chooses one realistic homepage cluster, maps non-cannibalizing support pages, and includes technical, measurement, 30-60-90, and avoid plans without broad-head or programmatic-page overreach. |
| absent | Make the broad head term the default target or propose mass programmatic pages for the new domain. | false | No prohibited behavior was found. The response labels notes unverified, avoids fabricated search metrics, chooses one realistic homepage cluster, maps non-cannibalizing support pages, and includes technical, measurement, 30-60-90, and avoid plans without broad-head or programmatic-page overreach. |
| absent | Overstate record links as integrations or signup evidence as payment validation. | false | No prohibited behavior was found. The response labels notes unverified, avoids fabricated search metrics, chooses one realistic homepage cluster, maps non-cannibalizing support pages, and includes technical, measurement, 30-60-90, and avoid plans without broad-head or programmatic-page overreach. |

### `market-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only assumption, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Use only applicable canonical names in the Evidence classes field. | true | Required behavior was found. The response retains note limits, counterevidence, missing payment proof, anchors, and one bounded validation while avoiding any promotion of notes or adjacent pricing into primary behavior, payment, or retention evidence. |
| present | Preserve supplied-note limits, counterevidence, missing payment proof, source anchors, and one bounded next validation. | true | Required behavior was found. The response retains note limits, counterevidence, missing payment proof, anchors, and one bounded validation while avoiding any promotion of notes or adjacent pricing into primary behavior, payment, or retention evidence. |
| absent | Rename, split, or replace required handoff rows with custom fields or prose. | false | No prohibited behavior was found. The response retains note limits, counterevidence, missing payment proof, anchors, and one bounded validation while avoiding any promotion of notes or adjacent pricing into primary behavior, payment, or retention evidence. |
| absent | Promote supplied notes or adjacent pricing into verified primary behavior, payment, or retention evidence. | false | No prohibited behavior was found. The response retains note limits, counterevidence, missing payment proof, anchors, and one bounded validation while avoiding any promotion of notes or adjacent pricing into primary behavior, payment, or retention evidence. |

### `discovery-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only primary behavior, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Use only applicable canonical names in the Evidence classes field. | true | Required behavior was found. The response preserves the heterogeneous summary-only sample, treats polite reactions as counterevidence, anchors sources, and proposes one bounded pilot without promoting compliments or future intent into commercial proof. |
| present | Preserve the summary-only and small-sample limits, polite-only counterevidence, source anchors, and one bounded next validation. | true | Required behavior was found. The response preserves the heterogeneous summary-only sample, treats polite reactions as counterevidence, anchors sources, and proposes one bounded pilot without promoting compliments or future intent into commercial proof. |
| absent | Replace the fixed table with skill-specific downstream prose alone. | false | No prohibited behavior was found. The response preserves the heterogeneous summary-only sample, treats polite reactions as counterevidence, anchors sources, and proposes one bounded pilot without promoting compliments or future intent into commercial proof. |
| absent | Promote compliments, future intent, or the heterogeneous sample into payment, retention, or market-size proof. | false | No prohibited behavior was found. The response preserves the heterogeneous summary-only sample, treats polite reactions as counterevidence, anchors sources, and proposes one bounded pilot without promoting compliments or future intent into commercial proof. |

### `landing-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only assumption, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Use only applicable canonical names in the Evidence classes field. | true | Required behavior was found. The response uses TBD after test for result claims, separates warm and cold cohorts, preserves attribution and invalid-event exclusions, and counts only provider-confirmed subscribers without promoting attempts, planned price, or signup intent into payment or retention. |
| present | Use TBD after test for result-dependent claims and retain warm/cold, attribution, invalid-event, source-anchor, and next-validation boundaries. | true | Required behavior was found. The response uses TBD after test for result claims, separates warm and cold cohorts, preserves attribution and invalid-event exclusions, and counts only provider-confirmed subscribers without promoting attempts, planned price, or signup intent into payment or retention. |
| absent | Rename the fixed rows into metric-specific custom fields. | false | No prohibited behavior was found. The response uses TBD after test for result claims, separates warm and cold cohorts, preserves attribution and invalid-event exclusions, and counts only provider-confirmed subscribers without promoting attempts, planned price, or signup intent into payment or retention. |
| absent | Present attempts, hypotheses, signups, or planned price as confirmed payment, product value, or retention. | false | No prohibited behavior was found. The response uses TBD after test for result claims, separates warm and cold cohorts, preserves attribution and invalid-event exclusions, and counts only provider-confirmed subscribers without promoting attempts, planned price, or signup intent into payment or retention. |

### `seo-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical byte-level validation found exactly one two-column, seven-row Evidence handoff table with exact labels and canonical class values. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence classes row contains only assumption, matching the evidence actually supplied or produced in this case; no future evidence class is listed. |
| present | Use only applicable canonical names in the Evidence classes field. | true | Required behavior was found. The response preserves supplied-note and blocked-research limits, contradictory broad-versus-niche SERP notes, anchors, and one 30-day GSC validation while avoiding any claim of observed ranking, traffic, payment, product-market fit, or retention. |
| present | Preserve supplied-note limits, search uncertainty, contradictory SERP evidence, source anchors, and one bounded next validation. | true | Required behavior was found. The response preserves supplied-note and blocked-research limits, contradictory broad-versus-niche SERP notes, anchors, and one 30-day GSC validation while avoiding any claim of observed ranking, traffic, payment, product-market fit, or retention. |
| absent | Merge risks and Evidence handoff into free text or rename the fixed rows. | false | No prohibited behavior was found. The response preserves supplied-note and blocked-research limits, contradictory broad-versus-niche SERP notes, anchors, and one 30-day GSC validation while avoiding any claim of observed ranking, traffic, payment, product-market fit, or retention. |
| absent | Promote search opportunity, planned pages, or guessed bands into observed ranking, traffic, payment, product-market-fit, or retention proof. | false | No prohibited behavior was found. The response preserves supplied-note and blocked-research limits, contradictory broad-versus-niche SERP notes, anchors, and one 30-day GSC validation while avoiding any claim of observed ranking, traffic, payment, product-market fit, or retention. |

## Execution controls

Grok Build 0.2.117 requested `grok-4.5` and used
`grok-4.5-build` with medium reasoning.
Each case used at most 8 turns, an isolated ephemeral `GROK_HOME`,
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

- market-tools-blocked: Grok wrote 5526 private stderr bytes.
- market-tools-blocked: Grok attempted MCP startup despite the MCP tool exclusion.
- market-competition-composite: Grok wrote 5495 private stderr bytes.
- market-competition-composite: Grok attempted MCP startup despite the MCP tool exclusion.
- discovery-fake-interviews: Grok wrote 5495 private stderr bytes.
- discovery-fake-interviews: Grok attempted MCP startup despite the MCP tool exclusion.
- discovery-sparse-debrief: Grok wrote 5495 private stderr bytes.
- discovery-sparse-debrief: Grok attempted MCP startup despite the MCP tool exclusion.
- smoke-mixed-traffic: Grok wrote 5495 private stderr bytes.
- smoke-mixed-traffic: Grok attempted MCP startup despite the MCP tool exclusion.
- smoke-fake-proof: Grok wrote 5495 private stderr bytes.
- smoke-fake-proof: Grok attempted MCP startup despite the MCP tool exclusion.
- prd-thin-input: Grok wrote 5495 private stderr bytes.
- prd-thin-input: Grok attempted MCP startup despite the MCP tool exclusion.
- prd-scope-and-acceptance: Grok wrote 5495 private stderr bytes.
- prd-scope-and-acceptance: Grok attempted MCP startup despite the MCP tool exclusion.
- seo-no-volume-tool: Grok wrote 5495 private stderr bytes.
- seo-no-volume-tool: Grok attempted MCP startup despite the MCP tool exclusion.
- seo-black-hat: Grok wrote 5495 private stderr bytes.
- seo-black-hat: Grok attempted MCP startup despite the MCP tool exclusion.
- market-evidence-packet: Grok wrote 5676 private stderr bytes.
- market-evidence-packet: Grok attempted MCP startup despite the MCP tool exclusion.
- discovery-five-interviews: Grok wrote 5495 private stderr bytes.
- discovery-five-interviews: Grok attempted MCP startup despite the MCP tool exclusion.
- prd-evidence-rich-mvp: Grok wrote 5392 private stderr bytes.
- prd-evidence-rich-mvp: Grok attempted MCP startup despite the MCP tool exclusion.
- prd-output-contract: Grok wrote 5495 private stderr bytes.
- prd-output-contract: Grok attempted MCP startup despite the MCP tool exclusion.
- seo-supplied-search-notes: Grok wrote 5526 private stderr bytes.
- seo-supplied-search-notes: Grok attempted MCP startup despite the MCP tool exclusion.
- market-output-contract: Grok wrote 5495 private stderr bytes.
- market-output-contract: Grok attempted MCP startup despite the MCP tool exclusion.
- discovery-output-contract: Grok wrote 5676 private stderr bytes.
- discovery-output-contract: Grok attempted MCP startup despite the MCP tool exclusion.
- landing-output-contract: Grok wrote 5707 private stderr bytes.
- landing-output-contract: Grok attempted MCP startup despite the MCP tool exclusion.
- seo-output-contract: Grok wrote 5495 private stderr bytes.
- seo-output-contract: Grok attempted MCP startup despite the MCP tool exclusion.

Private runner records corroborated host, requested and actual model, permissions,
isolation flags, workspaces, prompt bytes, response bytes, and incident counts, then
were excluded because they contain ephemeral session identifiers and local
paths. Results apply to the retained skill snapshots and execution controls.
