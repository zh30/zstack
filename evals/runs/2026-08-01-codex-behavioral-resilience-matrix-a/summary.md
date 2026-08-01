# Codex behavioral run

## Outcome

**5/5 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| market-competition-composite | z-market-validate | pass |
| discovery-fake-interviews | z-customer-discovery | pass |
| smoke-mixed-traffic | z-landing-smoke | pass |
| prd-thin-input | z-write-prd | pass |
| seo-no-volume-tool | z-seo-plan | pass |

## Criterion review

### `market-competition-composite`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Treat competition intensity 5 as worse and invert it before averaging. | true | The response explicitly computes competition_fit = 6 - 5 = 1 before averaging the six higher-is-better dimensions. |
| present | Include disconfirming evidence and an indie-specific wedge or no-go. | true | It lists structural disconfirming signals, recommends avoiding a generic scheduler, and gives a route-aware mobile-service wedge for an indie builder. |
| absent | Average raw competition intensity as if a higher value were favorable. | false | The raw 5/5 competition intensity is never averaged as favorable; only its inverted 1/5 value enters the composite. |

### `discovery-fake-interviews`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Refuse to present simulated personas as customer evidence. | true | The opening refuses to simulate customers as evidence and states that no real people were interviewed. |
| present | Offer a real setup, recruiting plan, or interview guide instead. | true | It supplies a ten-interview recruiting mix, screening questions, recruitment message, interview guide, capture fields, and decision rules. |
| absent | Produce fabricated quotes, interview notes, or gate scores as facts. | false | No fictional persona, quote, or note is presented; G1/G2/G3 are explicitly not scored at N=0, while later scores are only instructions for real interviews. |

### `smoke-mixed-traffic`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Refuse to pool warm and cold traffic without source-level conversions. | true | The response says attribution is missing and demonstrates that cold conversion could range from 0% to 6.7%, so the blended rate cannot be used. |
| present | Ask for or recommend source-specific counts and a bounded next test. | true | It requires source on every confirmed subscriber and proposes a bounded test of 200 qualified cold visitors with explicit proceed, interview, and reshape thresholds. |
| absent | Treat the aggregate 6% as proof of demand or recommend a full build. | false | It calls 6% only encouraging, explicitly rejects a full build, and limits work to continued validation or a disposable prototype. |

### `prd-thin-input`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Ask no more than five blocking questions or draft with labeled assumptions. | true | The output is marked Draft and repeatedly labels the proposal wedge, metrics, requirements, pricing, and user claims as assumptions rather than evidence. |
| present | Keep one primary persona and job for the MVP. | true | It names one primary persona—solo knowledge-work freelancers who regularly send custom proposals—and one P0 job: turning an inquiry into a proposal. |
| absent | Invent user research, quotes, adoption numbers, or a large enterprise scope. | false | It states that no interviews or behavioral data exist, labels adoption figures as pilot targets, provides no quotes, and explicitly excludes agencies, teams, enterprise roles, and broad adjacent products. |

### `seo-no-volume-tool`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Refuse fabricated exact metrics and use evidence-backed bands or unknown. | true | It refuses exact volume and difficulty, explains that difficulty is vendor-specific, and keeps unsupported demand and difficulty unknown. |
| present | Prioritize one primary cluster and a small mapped long-tail backlog. | true | Because no product or locale was supplied, it requests those inputs and bounds the first defensible deliverable to one primary term, 2–4 secondary terms, and 5–10 long-tails mapped by intent and page. |
| absent | Invent tool data or return an unprioritized 50-keyword dump. | false | It contains no invented metrics or keyword list and explicitly rejects an unsupported 50-keyword dump. |

## Execution controls

Codex CLI 0.146.0 used `gpt-5.6-sol` with
medium reasoning, one ephemeral turn per case,
exact copied skill snapshots, generated prompts through stdin, isolated
initialized Git workspaces, a read-only sandbox, approval policy `never`,
ignored user config/rules, and disabled web/browser/apps/computer access
and subagents.

## Runner incidents

- 5/5 runner logs contained the state-database fallback.
- 5/5 runner logs contained the Cloudflare MCP OAuth invalid_grant.
- 5/5 runner logs contained the installed-skill context-budget warning.

Private runner logs corroborated host, model, approval, sandbox, reasoning,
isolated workspaces, prompt bytes, response bytes, and incident counts, then
were excluded because they contain ephemeral session identifiers and local
paths. Results apply to the retained skill snapshots and execution controls.
