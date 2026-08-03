# Codex CLI behavioral run

## Outcome

**4/4 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| prd-thin-input | z-write-prd | pass |
| prd-scope-and-acceptance | z-write-prd | pass |
| prd-evidence-rich-mvp | z-write-prd | pass |
| prd-output-contract | z-write-prd | pass |

## Criterion review

### `prd-thin-input`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/prd-thin-input.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only assumption because the prompt supplies no research or results; it omits all planned interview, payment, product-use, and retention evidence. |
| present | Ask no more than five blocking questions or draft with labeled assumptions. | true | The PRD proceeds from an explicit evidence-limit notice and seven labeled assumptions, then asks only three non-blocking decisions in the postscript. |
| present | Keep one primary persona and job for the MVP. | true | It defines one independent project-based knowledge freelancer and one inquiry-to-reviewed-proposal job for the MVP. |
| absent | Invent user research, quotes, adoption numbers, or a large enterprise scope. | false | No interviews, quotes, adoption facts, or enterprise scope are invented; numeric metrics are explicitly validation thresholds and enterprise capabilities are non-goals. |

### `prd-scope-and-acceptance`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/prd-scope-and-acceptance.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only assumption for the user-supplied feature list and does not treat proposed interviews, pilots, payment gates, or requirements as current evidence. |
| present | Challenge the all-P0 request and protect a bounded solo-developer MVP. | true | The PRD explicitly rejects making the combined scheduling, payment, team, CRM, analytics, and native-app suite all P0, retaining only the individual booking loop for one developer. |
| present | Give testable acceptance criteria for every retained P0 requirement. | true | Every retained P0 row in FR-001 through FR-008 and NFR-001 through NFR-006 has an observable acceptance criterion or validation procedure. |
| absent | Preserve vague adjectives as requirements or omit non-goals. | false | Seamless and delightful are rejected as release criteria, while nine concrete v1 non-goals and objective behaviors define the scope. |

### `prd-evidence-rich-mvp`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/prd-evidence-rich-mvp.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only primary behavior, observed experiment, and assumption for the supplied discovery summary, measured smoke traffic, and unverified product decisions; no future class is added. |
| present | Preserve cold/warm separation, mark willingness to pay unknown, and distinguish evidence from assumptions. | true | The PRD reports cold 27/300 and warm 12/40 as separate cohorts, labels signups and volunteers as interest rather than use or payment, and keeps $29/month unvalidated. |
| present | Keep one primary persona and bounded six-week scope with concrete non-goals. | true | It has one small-agency onboarding operator persona, a six-week plan, one workflow and one active run, plus eleven concrete non-goals. |
| present | Give stable requirement IDs and testable acceptance criteria or validation methods for every retained functional and non-functional P0. | true | FR-001 through FR-014 and every retained P0 NFR-001 through NFR-006 use stable IDs and concrete acceptance checks; NFR-007 is explicitly P1. |
| present | Include P0 journeys and failures, conceptual data boundaries, measurable kill triggers, milestones, and a smallest vertical slice. | true | The PRD includes three end-to-end P0 journeys with recovery states, a conceptual data boundary, measurable continue/narrow/stop triggers, weekly milestones, and an eight-step smallest vertical slice. |
| absent | Reintroduce excluded portal, storage, migration, connector, AI, mobile, enterprise, or compliance scope as P0. | false | Portals, file storage, migration/import, connectors, AI, mobile, enterprise roles, compliance, and bookkeeping remain explicit non-goals and are absent from P0. |
| absent | Invent research quotes or describe signup and adjacent spend as validated payment demand. | false | No research quote is invented, and the response repeatedly states that signup, volunteering, adjacent systems, and a hypothetical price do not prove payment or retention. |

### `prd-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/prd-output-contract.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff includes only observed experiment and assumption, both canonical and supported by measured smoke traffic or unverified product choices; it adds no planned future class. |
| present | Use only the five canonical evidence classes in the Evidence classes field. | true | The Evidence classes cell contains exactly the applicable canonical names observed experiment and assumption. |
| present | Preserve cold/warm separation, unknown payment, contradictions, source anchors, and one bounded next validation. | true | The response preserves cold 27/300 and warm 12/40 separately, states that $29 and payment remain unproven, records exclusions and supplied anchors, and defines one week-5 pilot validation with continue/stop conditions. |
| present | Keep the default full core PRD at or below 5000 whitespace-delimited words while retaining testable acceptance criteria for every P0. | true | The core is 3,745 whitespace-delimited words. All retained P0 requirements FR-001 through FR-012 and NFR-001 through NFR-006 have testable acceptance or validation text. |
| absent | Replace the required handoff table or its field labels with custom prose or subsections. | false | The response ends with exactly one mechanically valid two-column, seven-row Evidence handoff using every fixed raw field label. |
| absent | Combine warm and cold traffic or present signup and pilot interest as validated payment or retention. | false | Warm and cold traffic are never combined, and the PRD explicitly denies that signups, volunteers, or the hypothetical $29 price establish payment or retention. |
| absent | Inflate the core with repeated decisions or implementation-level schemas and exhaustive test matrices not requested by the user. | false | At 3,745 words, the core stays below both draft and hard budgets; its conceptual entities and acceptance checks are requested implementation boundaries rather than exhaustive schemas or test matrices. |

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
