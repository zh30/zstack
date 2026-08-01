# Host compatibility evidence

Last verified: **2026-08-01**. Host discovery is an external contract, so this
page records evidence rather than promising identical behavior forever.

## Current discovery matrix

| Host | Default zstack root | Evidence | Symlink support |
|------|---------------------|----------|-----------------|
| Claude Code | `~/.claude/skills` | [Official skills docs](https://code.claude.com/docs/en/skills) | Explicitly documented |
| Codex | `~/.agents/skills` | [Official skills docs](https://developers.openai.com/codex/skills) | Explicitly documented |
| Grok Build | `~/.agents/skills` plus Claude compatibility | `grok inspect --json`, Grok Build 0.2.117 | Verified with zstack directory symlinks |

`~/.codex/skills` is not in the current Codex discovery list. zstack retains it
as an explicit legacy profile only:

```bash
./scripts/setup.sh --hosts codex
```

Grok already discovers the default Agent Skills and Claude roots. Install its
dedicated root only when a local setup requires it:

```bash
./scripts/setup.sh --hosts grok
```

Explicit optional profiles remain untouched by later default setup runs.

## Verification layers

| Layer | What it proves | Latest evidence |
|-------|----------------|-----------------|
| Source validation | Portable frontmatter, links, catalog, eval coverage | `./scripts/doctor.sh --source-only` |
| Install integration | Safe symlink setup, optional-profile semantics, rollback, unlink | `./scripts/test.sh` |
| Runtime discovery | A real host lists all five installed zstack skills | Grok Build 0.2.117 `inspect` |
| Routing behavior | Descriptions select the intended skill, reject unrelated work, survive context pressure, and route Chinese requests | Codex [routing run](../evals/runs/2026-07-31-routing/summary.md), [routing-budget regression](../evals/runs/2026-08-01-codex-routing-budget/summary.md), and [Chinese routing regression](../evals/runs/2026-08-01-codex-routing-zh/summary.md); Grok [full 25-case matrix](../evals/runs/2026-08-01-grok-routing-full-matrix/summary.md) |
| Complete behavior | A selected skill produces a decision-ready artifact from current source | Codex [19-case response matrix](../evals/runs/2026-08-01-codex-behavior-current-full-response/summary.md), [closed-gate landing rerun](../evals/runs/2026-08-01-codex-landing-response-after-closed-analytics-gate/summary.md), and [verified landing artifact](../evals/runs/2026-08-01-codex-landing-artifact-after-closed-analytics-gate/summary.md) provide 20/20 current coverage; Grok's [19-case matrix](../evals/runs/2026-08-01-grok-behavior-current-full-response/summary.md) remains current for 16 non-landing cases, while the retained [unverified-success artifact failure](../evals/runs/2026-08-01-grok-behavior-current-smoke-artifact-unverified-success/summary.md) explains the four pending landing reruns |

The Grok runtime inspection found all five skills from
`~/.agents/skills/<name>/SKILL.md`. Clean, isolated, no-web Grok runs now cover
all five happy paths: market validation and SEO passed directly; discovery exposed
an artifact-budget failure and passed after the fix; PRD exposed missing P0-NFR
validation methods and passed after the fix; landing smoke exposed premature
conversion events, deferred deployable output, disconnected UTM/subscriber
attribution, and unverified success UI before passing. This is evidence of the
recorded host/model runs—not a guarantee of complete parity across future
versions. The landing archive records the model transition from
`grok-4.5-build` to `grok-4.5` after the former became unavailable.

A clean Codex CLI 0.146.0 / `gpt-5.6-sol` regression then exposed two PRD
output-contract failures: prose-only evidence handoff and an overlong core.
With the same prompt and controls, the final run passed the fixed seven-field
interface and reduced the PRD from 6,907 to 4,755 words while retaining every
P0 acceptance criterion.

A second Codex matrix applied the same output-contract test to market,
discovery, landing, and SEO. All four initially preserved domain reasoning but
failed the fixed Evidence handoff interface; identical post-fix runs passed
20/20 criteria with canonical evidence classes and unchanged evidence limits.

A third Codex matrix measured frontmatter budget rather than artifact quality.
The original descriptions, mechanically truncated 180-character prefixes, and
compacted descriptions each routed 15/15 positive, boundary, and no-match
requests correctly. The compact set front-loads use conditions and reduces the
five active descriptions from 2,001 to 1,355 characters (32.3%).

The compact descriptions then passed 10/10 Chinese routing requests: one
positive case per skill, three close validation boundaries, and two unrelated
engineering no-matches. This closes the previous all-English routing-manifest
gap without adding keyword lists back to frontmatter.

The repository's deterministic routing runner and atomic archiver were then
exercised end to end on a live Chinese boundary case. The retained
[runner smoke archive](../evals/runs/2026-08-01-codex-routing-runner-smoke/summary.md)
records stdin-only prompt transport, read-only/never-approval controls, the raw
prompt and response, sanitized runner metadata, and both integrity manifests;
private CLI logs corroborated the published controls and retained prompt/response
bytes, then were inspected for incidents but not archived.

The routing runner and archiver now share one three-host core. Deterministic
fake-host tests cover Claude and Grok tool exclusion, requested-versus-actual
model provenance, private-record exclusion, and API-error fail-closed behavior.
A real Grok `grok-4.5-build` matrix then passed all 25 current English, Chinese,
boundary, and no-match requests with exact two-line outputs. The first uniform
run produced 23 passes but had two provider executions end without final text;
raising the Grok routing turn ceiling from one to two and rerunning the entire
matrix produced 25/25 complete executions, all actually finishing in one turn.
The archived [full matrix](../evals/runs/2026-08-01-grok-routing-full-matrix/summary.md)
preserves prompt rotation, empty-tool controls, actual model, turns, stops, and
private startup incidents through corroborated metadata and exact hashes.

The post-selection Codex runner and reviewed archiver were exercised on the
`market-tools-blocked` resilience case. Its
[smoke archive](../evals/runs/2026-08-01-codex-behavioral-runner-smoke/summary.md)
retains the exact four-file skill snapshot, generated prompt, final response,
criterion-by-criterion review, execution controls, and both integrity
manifests. The live run passed and moved current complete-provenance behavioral
coverage from 9/20 to 10/20 cases.

Two subsequent reviewed matrices reran the remaining ten cases against exact
current skill snapshots. Matrix [A](../evals/runs/2026-08-01-codex-behavioral-resilience-matrix-a/summary.md)
covered competition scoring, fabricated interviews, mixed traffic, thin PRD
input, and missing keyword tools. Matrix [B](../evals/runs/2026-08-01-codex-behavioral-resilience-matrix-b/summary.md)
covered sparse debriefs, fake proof, all-P0 scope pressure, black-hat SEO, and
an evidence-rich market report. Both passed 5/5 after criterion-by-criterion
review, bringing every behavioral case at that source snapshot to a
complete-provenance pass (20/20). The release-facing command is now
`scripts/report-evidence-coverage.rb --require-current-complete-pass`, which
also rejects those passes after relevant source or case bytes change.

A host-specific gap audit then reran the four happy paths that still lacked
complete Codex provenance. Discovery, PRD, and SEO passed; landing correctly
failed because the response-only runner prohibited the file that its criterion
required. The failure is retained in the
[gap archive](../evals/runs/2026-08-01-codex-happy-gap-regression/summary.md).
Behavioral cases now declare response or artifact execution explicitly. The
artifact runner grants an isolated workspace-write sandbox, accepts files only
under `artifacts/`, verifies the skill snapshot remained byte-identical, rejects
private workspace paths in the final response, and hashes every deliverable.
The reviewed [landing artifact rerun](../evals/runs/2026-08-01-codex-landing-artifact-pass/summary.md)
retains eight deployable/test-plan files and passes all criteria. Codex now has
a complete-provenance pass for 20/20 current cases, not only any-host coverage.

The isolated behavioral protocol now also has a Claude Code adapter sharing the
same snapshot, anti-leak, review, and atomic-publication core. Integration tests
exercise safe mode, the `Read`-only tool allowlist, requested-versus-actual model
provenance, private JSON/invocation exclusion, invocation tamper rejection, and
the host's unusual `is_error=true` result shape. These deterministic adapter
tests are not Claude behavior evidence: until a real reviewed Claude archive is
published, the host-specific coverage report correctly remains 0/20 for Claude.
The latest local Claude probe reached the configured provider but received HTTP
404 before generation for every configured model family. The runner now reports
this safely as `model-unavailable` without echoing provider error text. This is
kept as an explicit external configuration gap rather than being mislabeled as
skill behavior evidence.

The same core now has a Grok adapter with an isolated ephemeral host home,
prompt-file transport, fixed system-prompt override, read-only/workspace
sandboxes, tool allowlists, and requested-versus-actual model records. The
adapter explicitly discloses that Grok may still discover the standard Agent
Skills hub, and it records MCP startup attempts as incidents while excluding
MCP tools. The first real reviewed
[isolated-runner regression](../evals/runs/2026-08-01-grok-market-blocked-runner/summary.md)
passed `market-tools-blocked` with complete provenance. The reviewed
[adversarial matrix](../evals/runs/2026-08-01-grok-adversarial-five-skill/summary.md),
[response-gap run](../evals/runs/2026-08-01-grok-response-gaps-before-composite-fix/summary.md),
[composite fix rerun](../evals/runs/2026-08-01-grok-market-composite-after-fix/summary.md),
and output-contract runs
[before](../evals/runs/2026-08-01-grok-output-contracts-before-label-fix/summary.md)
and [after](../evals/runs/2026-08-01-grok-output-contracts-after-label-fix/summary.md)
preserve both the failures that triggered fixes and their passing reruns. At
that recorded source snapshot, the earlier artifact and happy-path evidence
gave Grok a complete 20/20 host matrix. Later landing-integrity hardening changed
the source bytes for four cases, so that historical result no longer satisfies
their current-source gate. Deterministic fake-CLI response, artifact, error, and
tamper tests are not counted as model evidence.

The latest release gate no longer accepts a complete historical pass after the
underlying skill bytes change. A retained
[provider-schema failure](../evals/runs/2026-08-01-codex-landing-artifact-provider-schema-failure/summary.md)
showed that a plausible-looking Buttondown tag-ID mapping contradicted the
[official subscriber-create tag-name contract](https://docs.buttondown.com/api-subscribers-create)
checked on 2026-08-01. The source now requires dated official
endpoint/auth/status/payload semantics or launch-blocking `VERIFY_*`
placeholders. Codex's full response matrix, latest three landing response
reruns, and verified real-file artifact cover all 20 current cases. The latest
artifact's Function passed 18 deterministic adversarial scenarios covering
media type, malformed and non-object JSON, actual streamed-byte limits, hostile
stream errors, provider timeout/network/rejection/acceptance, attribution, and
diagnostic privacy. Separate browser tests proved that query and fragment data
are removed before analytics setup, only allow-listed attribution survives, and
unresolved Plausible values make no external request. Buttondown and Plausible
remain explicitly blocked until their current official contracts, real records,
and network behavior are verified.

Grok remains current for 16/20 behavior cases; all 25 routing cases remain
current. Its prior client-controlled success-parameter failure is retained, the
skill fix is present, and two attempted reruns were not archived because the
local CLI returned HTTP 401 before model generation. Every case carries an exact
seven-row Evidence handoff;
the archive validates its bytes mechanically and binds a separate semantic
review of evidence-class applicability. CI enforces the same current-source
rule for both behavior and all 25 routing cases, so the current Grok gap fails
closed rather than borrowing an older pass. Grok's structured adapter also uses
an exact final-response marker: pre-marker narration remains private and is
reported only as a discarded byte count. Missing/duplicate markers fail, the
archiver independently re-extracts the response, and API failures are reduced
to a safe category plus HTTP status without printing the provider message.

## Recheck after host upgrades

1. Run `./scripts/setup.sh` and `./scripts/doctor.sh`.
2. Inspect the host's skill list or runtime configuration.
3. Re-run at least one routing boundary and one complete behavior case in a
   fresh session.
4. Record the host version, model, prompt, raw output, grade, and limitations.

Discovery proves that a host can load the files. It does not replace behavioral
evaluation, and one passing model version does not guarantee every future host.
