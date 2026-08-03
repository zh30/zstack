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

The runner copies only the selected skills into the run directory. It bounds
each source tree, captures every regular file through stable non-link binary
reads, writes those exact bytes exclusively, and then recaptures all selected
sources before finalizing the snapshot manifest. File, byte, inventory, or
content drift aborts the run rather than creating a mixed snapshot. It hashes
every copied source file, then gives each case a separate initialized Git
workspace containing that exact snapshot. Codex and Claude receive the
generation-time prompt bytes through an owner-private descriptor that is
unlinked before spawn; the structured invocation hash is computed from those
same in-memory bytes, never by reopening the retained prompt pathname. Grok
receives the exact same bytes through `--prompt-file /dev/fd/9`; fd 9 is mapped
to a separate anonymous descriptor in each child process, so the apparent file
path cannot be replaced and contains no case identity.
Before any host launch, the runner also stable-reads the retained public prompt
and requires it to equal the generation-time bytes; early pathname drift aborts
before model execution, while later drift is caught by output-tree monitoring.
Private workspaces and host homes use independent random 128-bit tokens rather
than semantic case ids. Those
tokens never enter public prompts, responses, or artifacts; the runner rejects
a final response that exposes one, and the archiver independently verifies the
private path relationships before discarding invocation records.
Cases default to `execution: response`. A case that must create real
files declares `execution: artifact` and must be run separately from response
cases; the runner switches to an isolated writable sandbox (`workspace-write`
for Codex/Claude, `workspace` for Grok), permits
writes only under `artifacts/`, verifies that the copied skill did not change,
rejects any other workspace file, and hashes every retained deliverable.
Each case copy is materialized directly from the runner's captured in-memory
bytes rather than re-reading a pathname-backed snapshot. The runner verifies
the exact file inventory and bytes immediately before launch and on every
runtime-tree poll, so a changed copy terminates the case and cannot be archived.
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
`dontAsk`, no memory/plan/subagents/web, and an auth copy inside that isolated
home. Both auth adapters accept only a current-user, owner-private, single-link
regular file of at most 1 MiB; they use a no-follow stable copy and remove a
partial destination on failure. A missing auth file remains a supported way to
exercise redacted authentication-failure handling.
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

Runner resource flags fail closed before creating an output directory:
one invocation may select at most 256 cases, `--jobs` is limited to 32,
`--timeout-seconds` to 86,400, and Grok
`--max-turns` to 100. Claude's per-case budget must be a positive finite
number. These ceilings bound local processes and accidental API exposure while
remaining above the complete registered case matrices.
Generated prompts are written exclusively with a 512-KiB per-case limit and a
16-MiB whole-run limit; `controls.json` records both ceilings and the exact
retained prompt-byte total for archive revalidation.
Before creating those files, runners independently require unique bounded
kebab-case case and skill ids, and resolve every catalog skill through the real
`skills/` tree without symlink traversal. This remains enforced even when a
runner is invoked directly without a preceding doctor check.
Before any model call, the host `--version` probe also runs in a supervised
process group with a 10-second timeout and 64-KiB combined stdout/stderr limit;
a stalled, noisy, background-spawning, or non-UTF-8 probe fails the run.
The runner resolves the host executable to one real absolute file before that
probe and verifies its device, inode, size, mode, and timestamps before and
after every case, preventing PATH or symlink drift from mixing versions in one
evidence run.
Each case workspace is initialized through a template-free `git init` with a
10-second timeout and 64-KiB output limit, so ambient Git templates cannot add
hooks or files and a broken Git executable cannot stall the runner.
Archive manifest generation and evidence validation use the same process-group
supervision, with a five-minute timeout and 2-MiB combined output limit. A
broken evidence tool therefore cannot hold the archive publication lock or
grow captured diagnostics without bound.
Coverage reporting uses the same five-minute inner bound, while documentation
checks give each nested report another 30 seconds to finish validation and
cleanup before terminating its process group.

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
Every report invocation first runs the full archive validator, so standalone
coverage gates never trust unhashed, linked, or structurally invalid run data.
The report then re-reads every `run.json`, review, result, control, prompt, and
skill-snapshot file through the same bounded stable-file contract. It rejects
linked path components and treats any file or tree that changes during the
current-source comparison as non-current, so the report does not rely on the
preflight validator alone.
Routing runners record disabled web search and subagents in their controls;
archivers verify those fields before copying them into public provenance.
Use `--require-current-complete-pass` for an any-host release gate, or repeat
`--require-current-complete-pass-host` for required Claude, Codex, or Grok
matrices. These gates bind each pass to the current skill-source bytes, so a
skill edit makes its older pass insufficient until a reviewed rerun is
published. Current gates also require the supported host's recorded isolation
contract, including disabled web search and subagents, an ephemeral session,
and its host-specific persistence or sandbox controls. Behavioral current
passes also recheck the published pass grade and every present/absent review
outcome against today's case criteria, plus the exact current prompt wrapper.
Routing current passes likewise reconstruct the current candidate rotation and
prompt wrapper, then require the retained selection, pass flag, format,
completion, and exit status to agree with today's expected route. The
non-current `--require-complete-pass` variants are useful only
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
uses an isolated host home, fixed system prompt, anonymous-descriptor
prompt-file transport, an empty
tool list, read-only sandbox, and disables web, memory, plan, subagents, managed
MCP, and marketplace auto-registration. Its workspace, host-home, and private
workspace and host-home paths use the same random opaque-token contract as
behavioral runs; the semantic routing case id is retained only in public runner
filenames, while the prompt path is the fixed child descriptor `/dev/fd/9`. Grok can
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
Routing applies the same resource ceilings; `--truncate-descriptions` accepts
80–4,096 Unicode characters.
Default and explicit output directories are owner-private. An existing
`--output` directory must be empty, owned by the current user, and deny all
group/other access because it retains private host logs and invocation records.
The runner holds an exclusive lease inside that directory until every child is
reaped and cleanup finishes, so concurrent runs cannot share an output path. A
hard-killed run leaves the lease in place and the non-empty directory must be
inspected or replaced instead of being silently reused.

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

The archive name must be a new `YYYY-MM-DD-kebab-slug` directory beginning with
a real ISO calendar date, and the phase must be kebab-case. The archiver
re-parses every final response, checks grades
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

Publish a run only when it has a durable evidence role: it establishes missing
current-source or host coverage, preserves a failure that caused a rule or fix,
validates a new runner/host contract, or records a release-facing complete
matrix. Keep exploratory runs and redundant passing reruns in an ignored local
directory. Archives are immutable audit evidence, not a general model-call log.

Each runner also limits combined per-case host-produced output to 2 MiB. For
Codex this is the CLI log plus the host-written final-response file; for
structured Claude/Grok adapters it is the raw JSON result plus stderr. The
runner-extracted Claude/Grok response is separately bounded to 2 MiB but is not
counted twice as host output. The supervisor applies an operating-system
per-file size limit and terminates the process group when the monitored total
crosses the bound; `controls.json` and failed results retain the limit and
observed byte count.
Artifact cases additionally retain at most 400 files, 2,000 total tree entries,
2 MiB per file, and 8 MiB total under `artifacts/`. Stable binary reads, a
second inventory/content pass, and exclusive destination writes reject changed
or oversized trees before treating them as durable runner evidence. The
artifact manifest is generated from those captured in-memory bytes, while each
retained file is re-read stably and required to match before final publication.
Retained
paths must also be canonical relative UTF-8 without leading/trailing whitespace
or control characters so JSON, line manifests, and every supported host encode
the same artifact identity. The 400-file and 8-MiB retained-artifact budgets
also apply cumulatively across every case in one invocation, preventing
individually valid cases from producing a run that exceeds its declared
publication envelope.
Every real-host case applies a 250-ms baseline-tree poll to its allowed
top-level layout, template-free `.git` tree, copied skill package when present,
and isolated Codex/Grok home. This prevents a damaged or hostile local CLI from
ignoring its declared sandbox and using a private subtree to grow disk state
without bound. A violation terminates the process group and is recorded as
`workspaceLimitError`; archivers reject that result and preserve the exact
limits in public execution provenance. Runners prepare the complete batch
layout first, start the monitor, and dynamically register each PID immediately
after `spawn` returns; no earlier process waits for later case setup before it
is supervised. The monitor checks every concurrent PID independently rather
than waiting for join order, and the parent performs one atomic final check
when each PID exits. The same batch check binds the
shared temporary-root layout and every isolated-home container, so a process
cannot evade its case budget by writing a sibling directory. Grok's inherited
prompt descriptor is anonymous and unlinked; its exact bytes are bound before
spawn and the parent closes its copy immediately afterward. The output
reservation separately pins both the output-directory and lease-file identities;
replacements are detected during every batch and before
and after final evidence writes. Each batch also captures the output-tree
inventory before spawning a host. Only that batch's declared log, invocation,
and response paths may appear or grow; prior evidence remains identity- and
timestamp-bound, while the whole tree stays below 4,096 files, 8,192 entries,
and 640 MiB. Runner-created logs, invocations, controls, manifests, results,
and review scaffolds use owner-private exclusive creation, so a pre-existing
file or symbolic link fails the run instead of being followed or truncated.
A workspace/output-tree violation stops scheduling later batches and leaves a
partial, non-archivable diagnostic run; Grok prompt copies use the same stable
read and exclusive-create boundary before their captured hash is recorded.
Every runtime workspace, artifact, host-home, and runner-output file must also
be owned by the current user and have exactly one hard link, preventing an
allowed path from aliasing an inode outside the monitored tree.
Repository inputs and retained runner sources use the same owner and
single-hard-link rule. Their parent-directory identities and file stat state
are checked across each bounded read or snapshot. Immediately after open, the
path's pre-open identity must match the opened descriptor before the first byte
is read, copied, or hashed; the identity is checked again after the operation.
Thus a manifest, auth file, retained source, control file, prompt, response, or
log cannot enter evidence through an external hardlink, a replacement between
`lstat` and `open`, or a concurrently replaced trusted directory.
The standalone Evidence handoff validator and current-evidence documentation
checker use this same 2 MiB stable-input contract for path-backed Markdown;
missing documents still fail normally, while symlinks, hardlinks, special
files, oversized inputs, and replacement races are rejected before their bytes
can influence a result.
Published evidence archives extend this rule to every directory and regular
file. Manifest generation binds archive and `evals/runs` directory identities
through its two preflight passes and atomic replacement; validation records
ownership and link counts in the whole-tree state that it rechecks at exit.
Coverage reporting captures the complete evidence collection before invoking
the validator, requires the same content-bound tree immediately afterward,
reads only the captured `run.json` set, verifies every consumed file against
that snapshot, and rechecks the bounded tree before emitting a report. The
collection is capped at 100,000 entries across all archives.
Artifact execution is additionally single-process so the whole-run budget can
be enforced while the model is still running. The same poll checks artifact
file, tree-entry, per-file, file-count, and cumulative-byte limits before the
final content audit.

Archivers do not parse or publish directly from a mutable `--run-dir`. They
first capture each referenced regular file into a private, stable snapshot,
reject symbolic-link path components and files above 2 MiB, and verify file
identity, size, and timestamps across the copy. A promotion captures at most
1,000 source files and 64 MiB total. The same bounded read retains an immutable
in-memory copy as the authority for every later parse, digest, byte count,
privacy check, Evidence handoff check, and exclusive archive write. The private
snapshot pathname remains only a compatibility handle; replacing it after
capture cannot change validation or publication. Binary bytes remain
`ASCII-8BIT`; JSON, manifests, prompts, responses, and logs must pass an
explicit UTF-8 view before text processing, avoiding locale-dependent implicit
file encodings. Later edits to either the compatibility pathname or the runner
directory therefore cannot change the evidence being promoted.
The archiver also keeps a relative-path-to-bytes map for every public `raw/`
file. It derives the raw artifact manifest from that map instead of rescanning
pathnames, then requires the complete directory/file inventory, byte counts,
and SHA-256 digests to match immediately after candidate validation and again
after publication. Replacing a raw file and rewriting both manifest layers into
a new self-consistent archive therefore still fails because the bytes no longer
match the runner capture.
After the whole-archive manifest is created, the archiver captures one bounded,
content-bound snapshot of the complete hidden candidate. Candidate validation
must leave every directory and file in that tree unchanged; after atomic rename,
the same inode-backed child tree must appear at the public name. This extends
the raw-byte guarantee to generated summaries, metadata, controls, reviews, and
both manifest layers, even when an attempted replacement updates its manifest
entry to remain internally self-consistent.
Generated top-level files use a transaction-root-bound writer: paths are
canonical single-component names, writes are exclusive and no-follow, each file
is capped at 2 MiB, and both the root inode and created file inode are checked
before and after `fsync`. A raced existing file or symlink is preserved and
causes the promotion to fail instead of being overwritten or followed outside
the hidden archive.
Temporary evaluation directories are removed through an identity-bound
quarantine: cleanup first moves the expected dev/inode under a random
owner-private sibling, rechecks it there, and only then traverses it. If the
caller-visible pathname was replaced during that move, cleanup restores and
preserves the replacement instead of recursively deleting it.

Archive publication is serialized across routing and behavioral archivers with
an owner-private operating-system file lock keyed to the repository's real
`evals/runs` path. The lock covers baseline validation, archive construction,
the final target-existence check, rename, post-publish validation, and rollback.
Concurrent archive commands therefore fail before creating a target, and a
crashed publisher releases the lock through the kernel.
Direct archive-manifest generation and checking acquire the same lock. An
archiver's bounded generator subprocess uses the lock already held by its
parent, so manifest maintenance cannot race a promotion or another generator.
The pathname, opened file descriptor, owner metadata, and device/inode identity
are rebound before every publication boundary. A generator subprocess retains
its own read lease on the parent's exact lock inode and rechecks that the
parent's exclusive flock still conflicts. Replacing the temporary lock pathname
therefore aborts and rolls back identity-matched outputs instead of creating a
second publication lane.

Before rename, the archiver asks the evidence validator to check the hidden
candidate directory alongside all existing archives while applying its intended
final archive name. The candidate must pass the same schema, provenance,
manifest, mapping, path, and byte checks as a published archive. Post-rename
validation remains as a repository-wide defense, but a process killed in that
final window can leave only an archive that already passed complete validation.

The publication lock does not freeze evaluation definitions or skill sources,
so archivers bind those separately. A routing promotion retains the exact
`evals/routing.yaml` bytes it graded; a behavioral promotion retains the exact
`evals/cases.yaml` bytes plus bounded SHA-256 state for every file in each
selected current skill tree. Stable non-link reads and a second inventory pass
capture that state. Direct archiver use enforces the same 100-file, 5-MiB
per-skill package bounds as the runner, stops a skill-tree walk after 1,000
entries, and retains the existing 1,000-file / 64-MiB whole-promotion budget.
The archiver rechecks the state after candidate validation before rename and
again after post-publish validation. Any concurrent drift aborts the candidate
or rolls back only the archive that transaction just published.

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
When recorded, exit status must be a non-negative integer, elapsed time and
cost must be finite non-negative numbers, and every numeric value nested in a
token-usage object must also be finite and non-negative; historical unknowns
may remain JSON `null`.
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

The manifest generator enumerates hidden top-level entries, rejects
non-canonical or impossible-date archive names, and computes every requested
manifest before writing any of them; one invalid target therefore cannot cause
an earlier target to be partially updated. It also rejects oversized inputs
before hashing and refuses to replace a symbolic-link or special-file manifest
target. The validator independently checks schema, provenance, suite/case references,
run-to-artifact mapping, complete archive and raw-file coverage, byte counts,
and SHA-256 hashes. Parsed JSON inputs require unique object keys and finite
numbers. YAML
manifests use one document with scalar, unique mapping keys; aliases remain
disabled. Parsed control files are captured as stable UTF-8 while retained
artifacts are hashed as arbitrary binary bytes. The validator records the initial type,
identity, mode, size, and timestamps of every archive entry and rechecks the
whole tree before success, binding all checks to one unchanged snapshot. A
published archive is bounded to 500 regular files, 2,000 total tree entries,
2 MiB per file, and 10 MiB total; one validation or default manifest pass
accepts at most 1,000 top-level archive entries. Split a larger durable run or retain large outputs
as explicit inventory-only entries instead of committing unbounded model logs
or binary artifacts. Archive only regular files; symbolic links are rejected
so evidence cannot resolve outside its directory. Manifest paths must be
canonical relative paths without `.` / `..` aliases, leading or trailing
whitespace, or control characters. Reviewer labels, criterion evidence, and
generated summaries must cite portable archive-relative evidence rather than
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
