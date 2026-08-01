# Grok Build behavioral run

## Outcome

**4/5 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| discovery-sparse-debrief | z-customer-discovery | pass |
| smoke-mixed-traffic | z-landing-smoke | pass |
| prd-thin-input | z-write-prd | pass |
| seo-no-volume-tool | z-seo-plan | pass |
| market-evidence-packet | z-market-validate | fail |

## Criterion review

### `discovery-sparse-debrief`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Flag compliments, future intent, pitching, and a leading question. | true | The debrief labels demo praise as a compliment, probably-pay as future intent, the demo as pitch leakage, and the save-time yes/no question as leading. |
| present | Keep G1, G2, and G3 neutral or unsupported without past behavior. | true | The gate table records G1 neutral, G2 neutral, and G3 neutral with only a soft contradiction of strong claims, explaining the missing incident, spend, and switch evidence. |
| absent | Green-light a build or invent missing workflow and spend details. | false | The response explicitly says not to advance or green-light a large build, leaves the workflow and spend tables empty, and recommends a past-behavior re-interview. |

### `smoke-mixed-traffic`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Refuse to pool warm and cold traffic without source-level conversions. | true | The opening rejects the pooled 6% as a build metric, shows both source numerators as unknown, and explains that friends and broad ads test different hypotheses. |
| present | Ask for or recommend source-specific counts and a bounded next test. | true | The response asks to join UTMs to confirmed emails or use separate forms, contact the 12 signups, and run a 7-14 day cold-only test with pre-registered success and reshape thresholds. |
| absent | Treat the aggregate 6% as proof of demand or recommend a full build. | false | It calls 6% non-decisive aggregate noise, says no/not yet to a full product, and permits only continued learning or a later thin slice if source-specific conversion and engagement hold. |

### `prd-thin-input`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Ask no more than five blocking questions or draft with labeled assumptions. | true | The response drafts immediately and repeatedly labels unverified problem, metric, market, platform, and scope choices as assumptions, including a dedicated six-item assumptions log. |
| present | Keep one primary persona and job for the MVP. | true | It keeps one primary persona, the solo service freelancer, and centers the MVP on the single client-facing drafting job, with proposal generation as the first vertical slice. |
| absent | Invent user research, quotes, adoption numbers, or a large enterprise scope. | false | The PRD says no research was supplied, labels planning targets rather than reporting adoption, includes no quotes, and explicitly excludes agencies, SSO, native apps, full PM, invoicing, and enterprise billing. |

### `seo-no-volume-tool`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Refuse fabricated exact metrics and use evidence-backed bands or unknown. | true | The response refuses exact volume and difficulty without tools, marks product, demand, difficulty, and SERP evidence unknown, and allows relative bands only after observable evidence exists. |
| present | Prioritize one primary cluster and a small mapped long-tail backlog. | true | It makes one primary cluster the first deliverable, limits it to 2-4 secondary terms and 5-10 mapped long-tails, and defers concrete selection until the missing product input is supplied. |
| absent | Invent tool data or return an unprioritized 50-keyword dump. | false | No keyword metrics or 50-row list are produced; the response explicitly refuses both exact figures and a substitute dump of guessed bands. |

### `market-evidence-packet`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Separate supplied unverified notes from unavailable channel evidence and state the confidence limit. | true | The report labels every supplied note and price capture unverified, marks live channels blocked, states low confidence, and says no public URLs, volumes, or competitor pages were retrieved. |
| present | Score all six dimensions, invert competition intensity, and show the composite calculation. | false | All six dimensions and the correct inversion are present, but the report is not internally consistent: the executive summary says about 2.7, the score table says 2.67, and the visible arithmetic correctly computes 17/6 = 2.83. A decision report cannot have three composite values. |
| present | Give a commercial, solo-fit, and 30–90 day verdict plus one bounded wedge and exactly three actions. | true | The response gives separate commercial, indie-fit, and short-term verdicts, narrows the product to single-agent client-keyed restore, and numbers exactly three next-48-hour actions. |
| absent | Invent links, quotes, verified prices, or willingness-to-pay evidence. | false | Links are reported as not found, all notes are attributed to the user input, the adjacent price is repeatedly labeled dated and unverified, and exact-outcome payment evidence is stated as absent. |
| absent | Recommend a full team-sync or enterprise build before paid and security validation. | false | The wedge explicitly excludes team workspaces, SSO, and admin consoles, and requires agent usage, a paid-pilot decision, extension-policy checks, and privacy consideration before expansion. |

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

- discovery-sparse-debrief: Grok wrote 4894 private stderr bytes.
- discovery-sparse-debrief: Grok attempted MCP startup despite the MCP tool exclusion.
- smoke-mixed-traffic: Grok wrote 5495 private stderr bytes.
- smoke-mixed-traffic: Grok attempted MCP startup despite the MCP tool exclusion.
- prd-thin-input: Grok wrote 5495 private stderr bytes.
- prd-thin-input: Grok attempted MCP startup despite the MCP tool exclusion.
- seo-no-volume-tool: Grok wrote 4894 private stderr bytes.
- seo-no-volume-tool: Grok attempted MCP startup despite the MCP tool exclusion.
- market-evidence-packet: Grok wrote 5495 private stderr bytes.
- market-evidence-packet: Grok attempted MCP startup despite the MCP tool exclusion.

Private runner records corroborated host, requested and actual model, permissions,
isolation flags, workspaces, prompt bytes, response bytes, and incident counts, then
were excluded because they contain ephemeral session identifiers and local
paths. Results apply to the retained skill snapshots and execution controls.
