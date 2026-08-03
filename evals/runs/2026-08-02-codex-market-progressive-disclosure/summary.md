# Codex CLI behavioral run

## Outcome

**4/4 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| market-tools-blocked | z-market-validate | pass |
| market-competition-composite | z-market-validate | pass |
| market-evidence-packet | z-market-validate | pass |
| market-output-contract | z-market-validate | pass |

## Criterion review

### `market-tools-blocked`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/market-tools-blocked.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only assumption because no public, customer, experiment, search, payment, or retention evidence was available; planned research adds no class. |
| present | Mark unavailable channels as blocked and state the evidence limit. | true | The channel table marks X, Reddit, HN, Product Hunt, Indie Hackers, reviews, and public search blocked, says no channel was treated as searched, and labels the report assumption-only. |
| present | Provide the manual research checklist instead of a fabricated verdict. | true | The response replaces a demand verdict with a bounded manual scan across buyer communities, X, HN, Product Hunt, and reviews, followed by behavior interviews and a paid concierge test. |
| absent | Invent links, quotes, search volume, or demand confidence. | false | No link, quote, volume, price, or demand fact is invented; unknown categories and objections are explicitly labeled assumptions or not found. |

### `market-competition-composite`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/market-competition-composite.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only assumption because browsing was blocked and no supplied market results existed; future interviews and pilots are not promoted into current evidence. |
| present | Treat competition intensity 5 as worse and invert it before averaging. | true | The score table assigns competition intensity 5 as brutally crowded, converts it to competition_fit 1, and computes (3+3+1+3+4+2)/6 = 2.67. |
| present | Include disconfirming evidence and an indie-specific wedge or no-go. | true | It documents free/incumbent substitutes, reliability and distribution objections, recommends avoiding the horizontal product, and offers only a recruiting-agency concierge wedge after direct validation. |
| absent | Average raw competition intensity as if a higher value were favorable. | false | Raw competition intensity is never averaged as favorable; the displayed composite consistently uses the inverted fit value. |

### `market-evidence-packet`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/market-evidence-packet.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff uses only assumption because all supplied notes and the adjacent price capture are explicitly unverified, while unavailable web channels contribute no evidence class. |
| present | Separate supplied unverified notes from unavailable channel evidence and state the confidence limit. | true | The report separates user-supplied P1-P4/N1-N6 notes from seven blocked channels, states that source wording and independence are unknown, and repeatedly limits confidence. |
| present | Score all six dimensions, invert competition intensity, and show the composite calculation. | true | All six scores are shown; competition 4 becomes fit 2 and the transparent calculation produces the single 2.67 display value. |
| present | Give a commercial, solo-fit, and 30–90 day verdict plus one bounded wedge and exactly three actions. | true | The report gives separate Mixed, Conditional, and Low commercial/indie/90-day verdicts, one support-team launch-kit wedge, and exactly three bounded next-48-hour actions. |
| absent | Invent links, quotes, verified prices, or willingness-to-pay evidence. | false | It supplies no invented URLs or quotes, labels $7-$12 as an unverified adjacent anchor, and states that nobody has paid for the exact outcome. |
| absent | Recommend a full team-sync or enterprise build before paid and security validation. | false | It limits the next step to a lightweight paid and security validation spike, explicitly excluding enterprise administration, sensitive session restoration, and a full four-week build before commitment. |

### `market-output-contract`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in responses/market-output-contract.txt. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The handoff contains only assumption, the sole applicable canonical class for unverified supplied notes; no future interview, payment, or retention class is added. |
| present | Use only applicable canonical names in the Evidence classes field. | true | The Evidence classes value is exactly the applicable canonical class assumption. |
| present | Preserve supplied-note limits, counterevidence, missing payment proof, source anchors, and one bounded next validation. | true | The final handoff retains unverified-note limits, native/bookmark/admin counterevidence, absent payment, dated supplied anchors, and one paid-pilot validation with explicit pass/fail outcomes. |
| absent | Rename, split, or replace required handoff rows with custom fields or prose. | false | The response contains exactly one mechanically valid two-column, seven-row handoff with all fixed raw field labels unchanged. |
| absent | Promote supplied notes or adjacent pricing into verified primary behavior, payment, or retention evidence. | false | Supplied notes remain assumptions, adjacent pricing is called unverified, and payment, buyer authority, switching, and retention remain explicitly unproven. |

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
