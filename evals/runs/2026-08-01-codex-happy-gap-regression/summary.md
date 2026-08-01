# Codex CLI behavioral run

## Outcome

**3/4 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| discovery-five-interviews | z-customer-discovery | pass |
| smoke-complete-pack | z-landing-smoke | fail |
| prd-evidence-rich-mvp | z-write-prd | pass |
| seo-supplied-search-notes | z-seo-plan | pass |

## Criterion review

### `discovery-five-interviews`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | State N, recruit mix, summary-level limitations, and exclude compliments from positive evidence. | true | The header records N=5, a 4-cold/1-warm mix, unidentified warm membership, summary-only limits, and treats the founder compliment as contradictory rather than positive evidence. |
| present | Cluster segments and score G1, G2, and G3 with confidence separate from signal strength. | true | Separate segment, G1, G2, G3, and gate-score tables distinguish score from Medium or Medium-low confidence. |
| present | Make an explicit checkpoint decision and hand off a bounded pilot or stop path with constraints. | true | The verdict is Advance narrowly to a three-account, 14-day concierge pilot with explicit pass, reshape, and park conditions. |
| present | Keep summary-only synthesis to decision artifacts rather than reconstructing detailed interview notes. | true | I01-I05 are declared traceability labels, and the response limits itself to evidence, segment, gate, decision, pilot, and handoff artifacts. |
| absent | Invent verbatim quotes, missing interview details, or market-size claims. | false | It explicitly states that no verbatim quotes are available, identifies missing facts, and says the sample cannot estimate prevalence or market size. |
| absent | Green-light a generic product or large build from the heterogeneous sample. | false | It rejects a broad product build and narrows the wedge to agency operations/PMs and a concierge pilot. |
| absent | Create a full per-interview note set or a new status scaffold unless the user requests normalized notes. | false | The compact evidence table is not a reconstructed note set, and no new status scaffold is created. |

### `smoke-complete-pack`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Keep one CTA and disclose that the product, proof, price, and ship date are unvalidated. | true | Every CTA uses Join the early-access waitlist, while hero, proof, FAQ, and footer disclose the unbuilt product, absent proof, planned price, and absent ship date. |
| present | Provide numeric timeboxed success and kill rules with warm and cold traffic reported separately. | true | The August 3-12 plan defines source-specific minimums, strong/weak thresholds, paid stop rules, and prohibits warm/cold pooling. |
| present | Include full English copy, UTMs, a materialized minimal deployable page whose form counts only provider-confirmed success, preserves source attribution on each confirmed subscriber, and never presents an unverified attempt as confirmed success, plus at least three concrete channels, non-build scope, and a decision matrix. | false | Copy, UTMs, attribution rules, channels, non-build scope, and decision matrix are present, but the response only lists and describes suggested files; it contains no deployable HTML/JS/Pages Function artifact. |
| absent | Fabricate proof, promise availability, build the product, or pool warm and cold conversion. | false | It refuses testimonials, logos, counters, availability and ship-date claims, excludes product code, and keeps every warm/cold calculation separate. |

### `prd-evidence-rich-mvp`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Preserve cold/warm separation, mark willingness to pay unknown, and distinguish evidence from assumptions. | true | The evidence table preserves cold 27/300 and warm 12/40 separately, labels payment unknown, and distinguishes observed smoke/pilot facts from assumptions. |
| present | Keep one primary persona and bounded six-week scope with concrete non-goals. | true | It selects one small-agency onboarding coordinator, a six-week solo pilot MVP, one workflow/run, and a concrete non-goal list. |
| present | Give stable requirement IDs and testable acceptance criteria or validation methods for every retained functional and non-functional P0. | true | FR-001 through FR-015 and NFR-001 through NFR-008 each include testable acceptance or validation language. |
| present | Include P0 journeys and failures, conceptual data boundaries, measurable kill triggers, milestones, and a smallest vertical slice. | true | Four journeys include recovery paths; later sections define states, entities, prohibited data, kill/reshape triggers, weekly milestones, and the persisted first vertical slice. |
| absent | Reintroduce excluded portal, storage, migration, connector, AI, mobile, enterprise, or compliance scope as P0. | false | Portals, storage, import/migration, connectors, AI, mobile, enterprise roles, and compliance are explicit non-goals rather than P0 requirements. |
| absent | Invent research quotes or describe signup and adjacent spend as validated payment demand. | false | No quotes are invented; signup, volunteering, payment, and the $29 price hypothesis remain explicitly distinct. |

### `seo-supplied-search-notes`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | State the research limits and avoid fabricated volume, difficulty, ranking, or competitor facts. | true | The opening evidence limit and keyword tables mark volume, difficulty, rankings, SERPs, and all query notes as unknown or unverified. |
| present | Choose one realistic primary keyword and target page, then map a clustered prioritized supporting set without cannibalization. | true | Agency client onboarding workflow is assigned to the homepage, with a small P0-P2 support map and explicit cannibalization rules. |
| present | Provide a product-specific homepage brief, technical baseline, measurement plan, sequenced 30/60/90 backlog, and avoid list. | true | Dedicated sections provide the ownership-specific homepage brief, technical checklist, weekly measurement rules, 30/60/90 workload, and avoid table. |
| absent | Make the broad head term the default target or propose mass programmatic pages for the new domain. | false | Broad agency software, CRM, portal, and generic onboarding software terms are deferred, and programmatic city/industry pages are explicitly avoided. |
| absent | Overstate record links as integrations or signup evidence as payment validation. | false | External URLs are not framed as integrations, and the handoff leaves payment demand, activation, and retention unproven. |

## Execution controls

Codex CLI 0.146.0 used `gpt-5.6-sol` with
medium reasoning, one ephemeral turn per case,
exact copied skill snapshots, generated prompts through stdin, isolated
initialized Git workspaces, a read-only sandbox, approval policy `never`,
ignored user config/rules, and disabled web/browser/apps/computer access
and subagents.

## Runner incidents

- 4/4 runner logs contained the state-database fallback.
- 4/4 runner logs contained the Cloudflare MCP OAuth invalid_grant.
- 4/4 runner logs contained the installed-skill context-budget warning.

Private runner records corroborated host, requested and actual model, permissions,
isolation flags, workspaces, prompt bytes, response bytes, and incident counts, then
were excluded because they contain ephemeral session identifiers and local
paths. Results apply to the retained skill snapshots and execution controls.
