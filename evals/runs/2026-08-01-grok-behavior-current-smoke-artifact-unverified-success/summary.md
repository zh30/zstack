# Grok Build behavioral run

## Outcome

**0/1 passed after explicit criterion review.**

| Case | Skill | Grade |
|------|-------|-------|
| smoke-complete-pack | z-landing-smoke | fail |

## Criterion review

### `smoke-complete-pack`

| Expectation | Criterion | Observed | Evidence |
|-------------|-----------|----------|----------|
| present | Include exactly one two-column, seven-row Evidence handoff table using the exact plain-text field labels and only canonical evidence class names. | true | Mechanical check found one valid Evidence handoff table in artifacts/smoke-complete-pack/smoke-pack.md. |
| present | Include only evidence classes supported by supplied inputs or actual results; omit unused canonical classes and planned future evidence. | true | The Evidence handoff lists only assumption, matching a pre-test plan with no observed traffic, signup, payment, or retention result; planned exports remain future anchors. |
| present | Keep one CTA and disclose that the product, proof, price, and ship date are unvalidated. | true | Every CTA placement uses Join the early-access waitlist, and the page explicitly says the product is unbuilt, has no proof, offers only planned pricing from $9/month, and has no ship date. |
| present | Provide numeric timeboxed success and kill rules with warm and cold traffic reported separately. | true | The ten-day protocol supplies numeric minimum samples, source-specific success and kill bars, a $150 cap, and separate warm, cold-social, cold-community, and cold-paid rows with an explicit no-pooling rule. |
| present | Include full English copy, UTMs, a materialized minimal deployable page whose form counts only provider-confirmed success, preserves source attribution on each confirmed subscriber, and never presents an unverified attempt as confirmed success, plus at least three concrete channels, non-build scope, and a decision matrix. | false | Most package elements are present, but the HTML treats the client-controlled query parameter ?status=subscribed as confirmation: it hides the form, displays You are on the early-access list, and fires submit_waitlist. That URL can be opened without any provider confirmation. The single Buttondown form also assumes unverified metadata field support instead of materializing provider-confirmed source attribution. |
| absent | Fabricate proof, promise availability, build the product, or pool warm and cold conversion. | false | No fabricated testimonial, logo, user count, availability promise, product implementation, or pooled warm/cold conversion was found; the failure is specifically the unverified success and attribution mechanism. |

## Retained deliverables

- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/landing/index.html`](./raw/artifacts/smoke-complete-pack/landing/index.html)
- `smoke-complete-pack`: [`artifacts/smoke-complete-pack/smoke-pack.md`](./raw/artifacts/smoke-complete-pack/smoke-pack.md)

## Execution controls

Grok Build 0.2.117 requested `grok-4.5` and used
`grok-4.5-build` with medium reasoning.
Each case used at most 8 turns, an isolated ephemeral `GROK_HOME`,
a fixed system-prompt override, an exact copied skill snapshot, a generated prompt file,
and an initialized Git workspace. Web search, memory, plan mode, subagents, managed MCP,
marketplace auto-registration, and MCP tools were disabled; permission mode was
`bypassPermissions`.
The workspace sandbox allowed only `Read`, `Write`, and `Edit`; post-run auditing
rejected writes outside `artifacts/` and any change to the copied skill.
Grok can still discover the standard Agent Skills hub outside its isolated host home;
the fixed system prompt and case prompt required it to use only the retained target snapshot.
Host authentication/provider settings could still apply and are disclosed by the
requested-versus-actual model record.

## Runner incidents

- smoke-complete-pack: Grok wrote 5495 private stderr bytes.
- smoke-complete-pack: Grok attempted MCP startup despite the MCP tool exclusion.

Private runner records corroborated host, requested and actual model, permissions,
isolation flags, workspaces, prompt bytes, response bytes, and incident counts, then
were excluded because they contain ephemeral session identifiers and local
paths. Results apply to the retained skill snapshots and execution controls.
