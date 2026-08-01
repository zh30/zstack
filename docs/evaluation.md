# Evaluating skill behavior and routing

zstack keeps two complementary regression manifests:

- `evals/cases.yaml` tests what an agent does **after** a skill is selected.
- `evals/routing.yaml` tests whether frontmatter descriptions select the right
  skill—or correctly select `none`—before any skill body is loaded.

`doctor.sh` validates both manifests and requires at least three behavioral
cases per active skill—including one `happy-path` and one `edge` or
`adversarial` case—plus two routing cases per active skill and at least two
routing no-match cases. It does **not** pretend that static validation proves
model behavior.

## Run a behavioral case

Use any isolated runner for repeatable no-web response cases:

```bash
# Start with one case while iterating; this makes a real model call.
ruby scripts/run-codex-behavioral-evals.rb --case market-tools-blocked
ruby scripts/run-claude-behavioral-evals.rb \
  --case market-tools-blocked \
  --model sonnet
ruby scripts/run-grok-behavioral-evals.rb \
  --case market-tools-blocked \
  --model grok-4.5

# Run the whole response or artifact partition without listing every case.
ruby scripts/run-codex-behavioral-evals.rb --execution response
ruby scripts/run-codex-behavioral-evals.rb --execution artifact

# Inspect exact snapshots and prompts without calling a model.
ruby scripts/run-claude-behavioral-evals.rb \
  --dry-run \
  --case-prefix market-
```

The runner copies only the selected skills into the run directory, hashes every
copied source file, then gives each case a separate initialized Git workspace
containing that exact snapshot. Codex and Claude receive the generated prompt
through stdin; Grok receives the exact same bytes through `--prompt-file` at a
private opaque path. Private workspaces, host homes, and Grok prompt filenames
use independent random 128-bit tokens rather than semantic case ids. Those
tokens never enter public prompts, responses, or artifacts; the runner rejects
a final response that exposes one, and the archiver independently verifies the
private path relationships before discarding invocation records.
Cases default to `execution: response`. A case that must create real
files declares `execution: artifact` and must be run separately from response
cases; the runner switches to an isolated writable sandbox (`workspace-write`
for Codex/Claude, `workspace` for Grok), permits
writes only under `artifacts/`, verifies that the copied skill did not change,
rejects any other workspace file, and hashes every retained deliverable.
Artifact responses must cite only workspace-relative `artifacts/...` paths; a
machine-local workspace path makes the run incomplete before review.

The Codex response adapter uses a read-only sandbox and approval policy `never`,
copies only its auth file into a disposable per-case `CODEX_HOME`, removes
ambient desktop task/permission/origin variables, ignores user config/rules,
disables anonymous Codex analytics with the documented per-run
`analytics.enabled=false` override, and disables web/browser/apps/computer
access and subagents. This prevents
installed plugins, MCP servers, and unrelated skill descriptions from entering
the evaluation context. The Claude adapter uses safe mode, a `Read`-only tool allowlist,
permission mode `dontAsk`, no session persistence, and disables Chrome and MCP;
host authentication/provider settings can still affect requested-model
resolution, so requested and actual model ids are recorded separately. The
runner classifies failed Claude API results into a small, non-secret category
(for example `model-unavailable`, `authentication`, or `rate-limit`) and shows
the HTTP status when present. It never prints the provider's raw error text;
inspect private `logs/*.json` only when the category is insufficient. A
`model-unavailable` result with no model usage is a provider/configuration
failure, not behavioral evidence, and must not be reviewed or archived. The
Grok adapter uses an isolated ephemeral `GROK_HOME`, fixed system-prompt
override, read-only sandbox, `Read`-only tool allowlist, permission mode
`dontAsk`, no memory/plan/subagents/web, and an explicit auth-file indirection.
Its system prompt requires one exact standalone final-response marker. The
runner retains only bytes after that marker; missing, repeated, or empty marked
output fails closed. Any host/tool narration before the marker remains in the
private JSON result, while its discarded byte count is carried into the
reviewed archive as a runner incident. The archiver independently re-extracts
the marked response and corroborates both the retained bytes and byte count.
For Grok API failures, the runner extracts a defensible HTTP status from the
private structured result when available and reports only a small category such
as `authentication`, `rate-limit`, or `provider-error`; the provider message is
never copied into the public response or console diagnosis.
Artifact cases use Grok's built-in `workspace` sandbox with `Read,Write,Edit`
and `bypassPermissions`; the disposable-workspace boundary and post-run audit
then reject writes outside `artifacts/` or changes to the copied skill.
Grok can still discover the standard Agent Skills hub outside its isolated
host home, so this limitation is retained in controls and archive summaries;
the fixed prompts require use of only the exact copied target snapshot. MCP
startup warnings may still appear privately, but MCP tools are excluded. Both
structured adapters record requested and actual model ids separately. The case
receives its registered `prompt`, but never `must` or `must_not`.

The runner records execution completion, not a semantic grade. Its
`results.json` intentionally leaves `grade` as `null`. It does mechanically
validate the shared two-column Evidence handoff contract against retained
response and Markdown artifact bytes, recording the result and pre-filling
only that criterion in `review.json`. Review the retained output against every
remaining criterion: set a public reviewer label, case grade, each semantic
`observed` boolean, and concise evidence. Keep `logs/` private because host
results and invocation records contain ephemeral session identifiers and
machine-local paths.

Every host process runs in its own process group. Response cases have a
600-second wall-clock limit by default; artifact cases get 1200 seconds because
bounded incremental file writes and transport retries take longer. Override the
limit with `--timeout-seconds N` when a deliberately large artifact needs more
time. A timeout terminates the whole process group, sets `timedOut: true`, and
leaves the run incomplete and ineligible for archive.

After reviewing the run, promote it atomically:

```bash
ruby scripts/archive-codex-behavioral-run.rb \
  --run-dir "$RUN_DIR" \
  --archive 2026-08-01-codex-behavioral-example \
  --phase after-fix

ruby scripts/archive-claude-behavioral-run.rb \
  --run-dir "$RUN_DIR" \
  --archive 2026-08-01-claude-behavioral-example \
  --phase after-fix

ruby scripts/archive-grok-behavioral-run.rb \
  --run-dir "$RUN_DIR" \
  --archive 2026-08-01-grok-behavioral-example \
  --phase after-fix
```

The archiver rejects incomplete or contradictory reviews, a handoff judgment
that disagrees with its own recomputation, prompt/response drift, changed
runner controls, incomplete snapshot hashes, and source changes since
execution. It corroborates controls and bytes against private host results and
invocation records,
copies exact prompts, responses, and skill snapshots but not logs, creates both
manifest layers, publishes by atomic rename, and rolls back a new archive when
post-publish evidence validation fails.
For artifact cases it additionally revalidates the runner artifact manifest,
copies the exact deliverable bytes under `raw/artifacts/<case>/`, and includes
them in both the raw and whole-archive manifests.

For a case that genuinely needs web access or another capability intentionally
excluded by all isolated runners:

1. Start a clean agent task with no prior zstack discussion.
2. Install or directly reference the skill under test.
3. Give the agent only the case `prompt`; do not reveal `must` or `must_not`.
4. If the skill may write files, run it in a disposable, initialized workspace
   and allow writes only there. This avoids trust prompts and protects the
   repository while preserving realistic artifact behavior.
5. Save the raw response or produced artifacts. Record an artifact manifest
   when output size or file count is itself part of the grade. Use either
   `sha256 bytes path` or the legacy `bytes sha256 path` column order; paths are
   relative to the manifest's `raw/` directory.
6. Grade every `must` and `must_not` item, citing the response.

A case passes only when every `must` is present and every `must_not` is absent.
For a material skill revision, prefer independent runs in two supported hosts or
model families. Treat disagreement as a reason to sharpen the skill or case,
not as permission to average away a failure.

### Audit behavioral evidence coverage

```bash
ruby scripts/report-evidence-coverage.rb
ruby scripts/report-evidence-coverage.rb --json
ruby scripts/report-evidence-coverage.rb --require-current-complete-pass-host codex
ruby scripts/report-evidence-coverage.rb \
  --suite routing \
  --require-current-complete-pass-host codex \
  --require-current-complete-pass-host grok
```

The report distinguishes any archived pass from a pass whose archive has
complete execution provenance, both overall and for each supported host family.
Use `--require-current-complete-pass` for an any-host release gate, or repeat
`--require-current-complete-pass-host` for required Claude, Codex, or Grok
matrices. These gates bind each pass to the current skill-source bytes, so a
skill edit makes its older pass insufficient until a reviewed rerun is
published. The non-current `--require-complete-pass` variants are useful only
for historical audits. Historical partial evidence remains valid but does not
satisfy any complete-provenance gate.
Use `--suite routing` to apply the same any-host and host-specific gates to the
current description-routing manifest; the default suite remains `behavioral`.

## Run a routing case

1. Start a clean agent task with no prior zstack or case discussion.
2. Give it only the current frontmatter descriptions of all candidate active
   skills and the case `prompt`; do not expose skill bodies, repository files,
   `expected_skill`, or grading notes.
3. Require exactly one selection from the candidates, or `none` when none fits.
4. Save the raw selection and concise reason before grading it against
   `expected_skill`.

Routing prompts must express natural user intent and must not name a `z-*` skill
or use a host-specific explicit invocation. Include positive cases, close
boundaries between neighboring skills, and unrelated no-match requests. A
routing case passes only when the selected id exactly matches `expected_skill`.

### Run an isolated routing matrix reproducibly

Use the repository runner instead of rebuilding isolation prompts by hand:

```bash
# Real model calls; filters are recommended while iterating.
ruby scripts/run-codex-routing-evals.rb --case-prefix zh-
ruby scripts/run-claude-routing-evals.rb --case boundary-public-research
ruby scripts/run-grok-routing-evals.rb --case boundary-public-research

# Inspect a mechanical truncation prompt without calling Codex.
ruby scripts/run-codex-routing-evals.rb \
  --dry-run \
  --case boundary-public-research \
  --truncate-descriptions 180
```

The shared runner reads active descriptions and registered requests from source,
rotates candidate order deterministically, and starts one ephemeral host process
per case in a separate initialized Git workspace. It never places
`expected_skill` in the model prompt. Codex receives only generated stdin, uses
a read-only sandbox, uses a disposable auth-only `CODEX_HOME`, removes ambient
desktop context, ignores user config/rules, disables anonymous analytics with
`analytics.enabled=false`, and disables skill loading, apps, browser/computer
access, and subagents. Claude uses safe mode, an empty
built-in tool list, `dontAsk`, no Chrome/MCP, and no session persistence. Grok
uses an isolated host home, fixed system prompt, prompt-file transport, an empty
tool list, read-only sandbox, and disables web, memory, plan, subagents, managed
MCP, and marketplace auto-registration. Its workspace, host-home, and private
prompt paths use the same random opaque-token contract as behavioral runs; the
semantic routing case id is retained only in public runner filenames. Grok can
still discover the standard
Agent Skills hub outside its isolated home, so both routing prompts prohibit
skill loading and file inspection. Its final-response marker uses the same
fail-closed extraction and independent archive corroboration as behavioral
runs, so setup narration cannot corrupt the public two-line routing response.
`--case`, `--case-prefix`, `--jobs`,
`--model`, `--reasoning`, `--timeout-seconds`, `--wrapper`,
`--truncate-descriptions`, and `--output` control every host; host-specific
budget/turn/auth options are shown by `--help`. The same per-process-group
600-second default prevents one stalled routing call from blocking a matrix.

The printed `RUN_DIR` contains exact candidate descriptions, per-case prompts,
verbatim final responses, machine-readable controls and grades, plus private
host records. Review failures before changing a description. **Do not copy
`logs/` into a public evidence archive**: logs, invocation records, and
structured host results contain ephemeral identifiers and machine-local paths.
Use the matching archiver to publish only exact candidates, prompts, responses,
and sanitized metadata. A full matrix makes real model calls, so prefer the
smallest relevant selector during iteration and run the complete set only for
release-facing evidence.

After reviewing the runner directory, promote it without hand-copying files:

```bash
ruby scripts/archive-codex-routing-run.rb \
  --run-dir "$RUN_DIR" \
  --archive 2026-08-01-codex-routing-example \
  --phase after-fix

ruby scripts/archive-grok-routing-run.rb \
  --run-dir "$RUN_DIR" \
  --archive 2026-08-01-grok-routing-example \
  --phase after-fix
```

The archive name must be a new `YYYY-MM-DD-kebab-slug` directory and the phase
must be kebab-case. The archiver re-parses every final response, checks grades
against the current routing manifest, rejects prompt/response drift and private
runner identifiers, retains exact prompts and responses, and uses private host
records to corroborate requested/actual model, permissions, isolation,
workspace, prompt bytes, response bytes, turns/stops, and incident counts. It
never copies those private records. It creates both manifest layers and validates
the complete schema-v2 evidence set, building in a hidden sibling directory and
publishing by atomic rename. An existing target is never overwritten, and a
failed post-publish validation removes only the newly created archive.

## Archive a run

For a release-facing run, store immutable raw responses in
`evals/runs/<YYYY-MM-DD>[-<kind-or-runner>]/raw/` and the grades in the same
directory's `summary.md`. Keep failed first attempts when they led to a skill
change; they explain why the regression rule exists. Do not overwrite a same-day
run from a different host or model—append a short runner slug to the directory
name instead.

Every archive must include a machine-readable `run.json` using schema version 2.
Record `schemaVersion`, `archiveDate`, the `behavioral` or `routing` suite, a host
object, provenance status, a non-empty `runs` array, and `runnerIncidents`. Each
run has a unique kebab-case `id`, its own registered `case`, phase, execution
controls, grade, and the exact retained paths it uses under `raw/`. This
per-run mapping supports multi-case archives and shared routing-response files
without inferring ownership from filenames.

Set provenance to `complete` only when the host version and every run's model,
workspace, permissions, web/subagent flags, turn limit or count, and stop status
were recorded. For historical evidence with gaps, use `partial`, list the gaps,
and store unknown values as JSON `null`; never reconstruct them from memory.
`executionDefaults` may hold values shared by every run. Token usage, cost,
reasoning effort, failures, host revision, and runner notes remain optional.
Omit account, session, and request identifiers; they do not help reproduce
behavior.

Every archive also needs at least one raw `artifact-manifest*.txt`. These raw
manifests preserve runner paths, sizes, hashes, and intentional inventory-only
entries. After the prompts, summary, metadata, and raw evidence are final, build
the whole-archive manifest:

```bash
ruby scripts/generate-evidence-manifests.rb evals/runs/<archive>
ruby scripts/generate-evidence-manifests.rb --check
ruby scripts/validate-evidence.rb
```

Do not hand-edit `archive-manifest.txt`. The generator deterministically hashes
every regular archive file except that manifest itself, so control-document and
raw-manifest drift is detected as well as raw-byte drift. Git history anchors
the resulting digest; the manifest is an integrity check, not a substitute for
a signed release.

The validator checks schema, provenance, suite/case references,
run-to-artifact mapping, complete archive and raw-file coverage, byte counts,
and SHA-256 hashes. Archive only regular files; symbolic links are rejected so
evidence cannot resolve outside its directory. Manifest paths must be canonical
relative paths without `.` / `..` aliases, leading or trailing whitespace, or
control characters. Reviewer labels, criterion evidence, and generated
summaries must cite portable archive-relative evidence rather than
machine-local paths; the archiver and validator reject common local home and
temporary-directory roots. If a failure raw manifest
inventories files whose bytes were intentionally not retained, add an
`Unarchived entries are inventory-only:` line followed by the exact
comma-separated manifest paths. Those allowlisted entries remain historical
inventory, not cryptographically reverifiable evidence; other missing or
unmapped files still fail validation.

Never place secrets, private customer data, or unpublished product material in
the archive. Use a local ignored directory instead when a real-world artifact
cannot be published safely.

## Add or revise behavioral cases

Behavioral cases use response mode unless they explicitly require a written
deliverable:

```yaml
- id: smoke-complete-pack
  skill: z-landing-smoke
  kind: happy-path
  execution: artifact
  prompt: Create a complete smoke-test package...
```

Use `artifact` only when file existence or deployability is part of the grade.
Keep ordinary reports and plans in the default response mode. Run the two modes
in separate invocations so their permission evidence remains unambiguous.

- Give each case a stable kebab-case `id` and a registered `skill`.
- Set `kind` to `happy-path`, `edge`, or `adversarial`; every active skill needs
  a successful full-output case as well as resilience coverage.
- Test a decision boundary or failure mode, not superficial wording.
- Keep prompts realistic and free of the intended answer.
- Write observable grading criteria; avoid "high quality" or "good reasoning".
- Never include private customer data, secrets, or the expected response itself.

## Add or revise routing cases

- Give each case a stable kebab-case `id`, a realistic `prompt`, and an
  `expected_skill` that is either an active catalog id or `none`.
- Add at least two positive cases per active skill and at least two unrelated
  no-match cases across the manifest.
- Test ambiguous neighboring intents as explicit boundary cases.
- When descriptions advertise non-English triggers, include at least one
  positive request for every such skill. Add neighboring boundary cases where
  skills overlap, and keep at least one unrelated no-match request in that
  language across the suite.
- Never put a skill id, host-specific explicit invocation, or expected selection
  in the prompt.
- Re-run changed descriptions in clean contexts; static manifest validation is
  only a guardrail, not a routing result.

Run `./scripts/test.sh` after changing either manifest.
