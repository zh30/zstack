# zstack Architecture

> Open-source **Agent Skill** collection for **independent developers** — original skills, one git source of truth, installable into Claude Code, Codex, and Grok Build (and any host that speaks the Agent Skills / `SKILL.md` convention).

## 1. Problem & Goals

### Problem

Independent developers (solo founders, OPC builders, indie hackers) use AI coding agents daily, but:

1. High-leverage workflows live as one-off prompts — not versioned, not shareable.
2. Skills that *are* shared are often host-locked (Claude-only, Cursor-only) or giant general packs (e.g. gstack) that are not focused on indie product work.
3. Publishing a skill set that works on **Claude Code + Codex + Grok Build** still requires a deliberate layout and install story.

### Product positioning

| Dimension | zstack |
|-----------|--------|
| **Audience** | Independent developers / one-person companies |
| **Content** | **Original** skills we create and maintain — not a migration of personal `~/.*` skill dumps |
| **Distribution** | Public GitHub (MIT); others clone + `./scripts/setup.sh` |
| **Hosts** | Claude Code, Codex, Grok Build (first-class) |
| **vs gstack** | Complementary. gstack = general eng factory (`/qa`, `/ship`, `/browse`). zstack = indie-developer product & shipping workflows |

### Goals

1. **Original skill catalog** — every skill is designed for indie developers and authored in-repo.
2. **Multi-host compatibility** — Claude Code, Codex CLI, Grok Build from one `SKILL.md`.
3. **One-command install** — `./scripts/setup.sh` links skills into each host for the user.
4. **Author once** — portable Agent Skills shape; avoid per-host forks unless necessary.
5. **Open-source ready** — no secrets, no machine-local paths, clear LICENSE and docs for external users.
6. **OPC-scale maintainability** — boring structure one maintainer + AI can evolve.
7. **Clear boundary with gstack** — do not vendor or reimplement gstack.

### Non-goals

- Migrating or vendoring existing personal/third-party skill libraries into this repo.
- Replacing gstack, Claude plugins, or marketplace skill packs.
- Multi-tenant skill marketplace / SaaS.
- Runtime agent orchestration framework (that stays in the agents themselves).
- Guaranteeing 100% identical tool names across hosts (hosts differ; skills must stay portable in *intent*).

---

## 2. Design Principles

| Principle | Meaning |
|-----------|---------|
| **Portable core** | Body of `SKILL.md` is host-agnostic Markdown instructions + shell/scripts. |
| **Minimal frontmatter** | Only fields in the Agent Skills intersection by default (`name`, `description`). |
| **Symlink over copy** | Default install is symlink from repo → host skill dirs so `git pull` is live. |
| **Symlink-only v1** | Keep one live source of truth; copy mode is not implemented. |
| **Progressive complexity** | L0 pure MD → L1 + scripts/references → L2 host adapters (only if forced). |
| **Discoverability first** | `description` is the API surface for auto-invocation; treat it as a product. |
| **No secret in skills** | Skills never embed tokens; reference env vars / wrangler secrets. |

---

## 3. How Each Host Discovers Skills

Ground truth last verified on 2026-07-31; see
[docs/compatibility.md](./docs/compatibility.md) for sources and runtime evidence:

| Host | Global skill roots | Project / repo roots | Notes |
|------|--------------------|----------------------|-------|
| **Claude Code** | `~/.claude/skills/<name>/SKILL.md` | `.claude/skills/` | Official docs explicitly support symlinked skill directories. |
| **Codex** | `~/.agents/skills/<name>/SKILL.md` | `.agents/skills/` from CWD to repo root | Official docs explicitly support symlinked skill directories. Optional `agents/openai.yaml`. |
| **Grok Build** | `~/.grok/skills/`, plus compatibility discovery of `~/.agents/skills/` and `~/.claude/skills/` | `.grok/skills/`, `.agents/skills/`, `.claude/skills/` | Confirmed with `grok inspect --json` on Grok Build 0.2.118. |

**Implication for zstack:** default installation needs only
**`~/.agents/skills`** + **`~/.claude/skills`**. The former covers current Codex
and Grok; the latter covers Claude and Grok. Keep `~/.codex/skills` as a legacy
opt-in and `~/.grok/skills` as an explicit dedicated-root opt-in.

```
                    ┌─────────────────────────┐
                    │   zstack git repo       │
                    │   skills/<name>/…       │
                    └───────────┬─────────────┘
                                │  setup / install
                        ┌───────┴────────┐
                        ▼                ▼
               ~/.agents/skills  ~/.claude/skills
                 (Codex + Grok)     (Claude + Grok)
```

Optional: `./scripts/setup.sh --hosts codex` installs the legacy Codex root;
`--hosts grok` installs the dedicated Grok root. A later default setup leaves
those unselected roots untouched.

---

## 4. Repository Layout

```
zstack/
├── README.md                 # What / why / quick start
├── ARCHITECTURE.md           # This document
├── AGENTS.md                 # Agent-facing rules when working *on* zstack
├── CONTRIBUTING.md           # Public contribution workflow and quality gates
├── LICENSE
├── catalog.yaml              # Skill registry (id, category, hosts, status)
├── evals/
│   ├── cases.yaml            # Post-selection behavioral regression manifest
│   └── routing.yaml          # Description-only routing regression manifest
├── skills/                   # ★ Source of truth
│   ├── _template/            # Scaffold for new skills
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── quality-bar.md
│   ├── z-market-validate/
│   │   └── SKILL.md
│   ├── z-customer-discovery/
│   │   ├── SKILL.md
│   │   └── references/
│   └── z-some-workflow/
│       ├── SKILL.md
│       ├── scripts/
│       └── references/
├── hosts/                    # Host profiles (declarative, small)
│   ├── agents.yaml
│   ├── claude.yaml
│   ├── codex.yaml
│   └── grok.yaml
├── scripts/
│   ├── setup.sh              # Primary installer (bash, zero deps)
│   ├── unlink.sh             # Clean uninstall of zstack links only
│   ├── doctor.sh             # Validate skills + link health
│   ├── test.sh               # Fast smoke mode + complete integration tests
│   ├── new-skill.sh          # Scaffold from _template
│   ├── check-evidence-docs.rb # Keep visible host counts aligned with evidence
│   ├── report-evidence-coverage.rb # Behavioral/routing evidence matrices
│   ├── run-behavioral-evals.rb # Shared snapshot-isolated runner core
│   ├── run-{codex,claude,grok}-behavioral-evals.rb # Host runner entries
│   ├── archive-behavioral-run.rb # Shared reviewed-archive core
│   ├── archive-{codex,claude,grok}-behavioral-run.rb # Host archive entries
│   ├── run-routing-evals.rb # Shared description-only routing core
│   ├── run-{codex,claude,grok}-routing-evals.rb # Host runner entries
│   ├── archive-routing-run.rb # Shared atomic routing archiver
│   ├── archive-{codex,claude,grok}-routing-run.rb # Host archive entries
│   └── lib/
│       ├── common.sh         # Shared installer/catalog shell parsing
│       └── eval_host_contracts.rb # Immutable eval inputs + runner parsing
├── docs/
│   ├── authoring.md          # How to write a portable skill
│   ├── compatibility.md      # Host discovery sources + runtime evidence
│   ├── evaluation.md         # Clean-session forward-test method
│   └── frontmatter.md        # Exact portable frontmatter contract
└── .github/
    └── workflows/
        └── validate.yml      # Frontmatter + structure CI
```

### Why this shape

- **`skills/` flat by name** — matches every host’s discovery model (`<root>/<name>/SKILL.md`). Nested categories would break discovery unless install rewrites paths.
- **`catalog.yaml`** — human + machine registry without inventing a DB: status (active/draft/deprecated), tags, which hosts to install to.
- **`hosts/*.yaml`** — install targets and frontmatter constraints in data, not hard-coded if-else forests.
- **Bash installer first** — works before Node/Bun is available; optional Node later if validation grows.

---

## 5. Skill Unit Model

### 5.1 Directory contract

Every skill is a directory under `skills/<name>/` with:

| Path | Required | Purpose |
|------|----------|---------|
| `SKILL.md` | **Yes** | Frontmatter + instructions (the skill) |
| `scripts/` | No | Deterministic helpers (bash/python); invoked by path relative to skill root |
| `references/` | No | Long docs the agent should Read on demand (keep SKILL.md thin) |
| `assets/` | No | Static templates, examples |
| `agents/openai.yaml` | No | Codex-oriented metadata when needed |

**Naming:** `name` = directory name = portable skill id. Claude/Grok expose
`/name`; current Codex exposes `$name`.
**Required pattern:** `^z-[a-z0-9]([a-z0-9-]{0,60}[a-z0-9])?$` (must start with `z-`, ≤64 chars total).

Behavioral cases are centralized in root `evals/cases.yaml`; every active skill
must have at least three cases with non-empty prompt, `must`, and `must_not`
criteria, including one `happy-path` and one `edge` or `adversarial` case. Dated
clean-context responses and explicit grades live under `evals/runs/`; raw output
stays separate from the grading summary so a reviewer can audit regressions
without trusting the score alone. A shared deterministic validator checks the
exact two-column Evidence handoff against retained bytes; semantic criteria
remain reviewer-owned, and the archiver rejects disagreement between the two.

Routing cases are centralized in `evals/routing.yaml`; every active skill must
have at least two natural-language prompts, and the manifest must include at
least two unrelated `none` cases. Runners receive candidate descriptions and
the prompt only—never skill bodies or `expected_skill`—so the test measures the
actual discovery API rather than recall of an answer key.
### 5.2 Complexity tiers

| Tier | Contents | When to use |
|------|----------|-------------|
| **L0** | `SKILL.md` only | Most personal workflows, conventions, checklists |
| **L1** | + `scripts/` and/or `references/` | Need deterministic steps, long domain docs |
| **L2** | + host-specific extras such as `agents/openai.yaml` | Optional packaging while shared frontmatter stays minimal |
| **L3** | Content generation / multi-host rewrite | **Out of scope for v1** — that’s gstack’s job. If a skill needs L3, either (a) keep it host-agnostic, or (b) document it as Claude-primary |

### 5.3 Portable SKILL.md shape (canonical)

```markdown
---
name: z-example-skill
description: >-
  One-line what + when. Include natural trigger phrases, not host invocation syntax.
  Keep under ~500 chars when possible; Codex is pickier about invalid YAML.
---

# Example Skill

## Steps
1. …
2. …

## Guardrails
- Never …
```

**Body rules for multi-host portability:**

1. Prefer **shell commands** over host-specific tool names (`Bash` / “run this command” language).
2. Prefer **“read the file”** over “use the Read tool”.
3. Prefer **“edit the file”** over “use Edit / apply_patch / StrReplace”.
4. Reference bundled resources relative to the skill directory, such as
   `scripts/foo.sh`, and tell the agent to resolve that path from `SKILL.md`.
5. Do not hardcode host install roots or assume `ZSTACK_ROOT` is exported;
   `setup.sh` records the root for maintenance but does not change future host
   process environments.
6. Keep **description** specific: verbs + nouns + trigger contexts + failure-mode keywords.
7. Keep trigger guidance in **description**; do not repeat `When to use` after
   the skill has already loaded.

### 5.4 Frontmatter compatibility matrix

| Field | Claude | Codex | Grok | zstack policy |
|-------|--------|-------|------|----------------|
| `name` | ✓ | ✓ | ✓ | **Required** |
| `description` | ✓ | ✓ | ✓ | **Required**; primary routing signal |
| Any other key | varies | varies | varies | **Disallowed**; keep metadata in `catalog.yaml` |

**Rule:** zstack deliberately uses only `name` and `description`. Validate with
`scripts/doctor.sh --source-only` before install.

---

## 6. Install & Linking Model

### 6.1 Source of truth path

Default clone location (documented, not enforced):

```text
~/code/zstack          # or any path; setup records absolute path
```

Environment:

```bash
export ZSTACK_ROOT="$HOME/code/zstack"   # optional convenience for manual commands
```

Setup records the latest repository root in `~/.zstack/root` and every managed
link as `repo-root|link-path` in `~/.zstack/links`. The latter lets uninstall
find project-local links and links from more than one clone.

These state leaves must be single-link regular text files without NUL bytes;
hardlinked aliases are rejected so the private state inode cannot be rewritten
through an external pathname. The root record must contain exactly one safe
absolute path. Before parsing either file, setup,
unlink, and doctor reject a root record larger than 4 KiB or a link manifest
larger than 1 MiB. The format, integrity, and size checks keep corrupted local
state from changing path meaning inside Bash or turning maintenance commands
into unbounded reads. Setup and unlink normalize the state directory to mode
`700`; generated root and link records use mode `600`, keeping absolute local
paths private to the current user. Doctor warns when those paths later become
group- or world-accessible. Repair or remove a reported invalid state file
before retrying.

State-file transitions are fail-closed. Under the shared mutation lock, setup
and unlink snapshot an existing manifest or root record, bind that snapshot to
the source inode and exact bytes, require both source and snapshot to remain
single-link regular files, and parse only the snapshot. A non-empty replacement
is published by rename and then rechecked against an exclusive expected snapshot
for the candidate inode, single-link state, and exact bytes before success is
reported. Destructive cleanup first binds the expected snapshot inode, moves the
identity-matched path into a private, atomically reserved quarantine, rechecks
both identities and single-link states, validates the expected bytes there, and
only then deletes it; a raced replacement or reference snapshot is restored or
preserved instead of being removed. The same quarantine primitive is used for
transaction-temp and PID-lock cleanup and does not depend on `mktemp`, so
allocator failure cannot strand an otherwise releasable lock.

This is state-integrity protection, not whole-command rollback: links that were
successfully created or removed can remain when a later state publication fails.
The command exits non-zero without claiming success, preserves conflicting or
raced content, and a safe retry reconciles the recorded state.

### 6.2 Link strategy (v1)

For each skill marked `status: active` in `catalog.yaml`, and for each enabled
host profile (or optional profile named explicitly by `--hosts`):

```text
ln -s "$ZSTACK_ROOT/skills/<name>"  "<host_skills_root>/<name>"
```

Examples:

| Host profile | Target |
|--------------|--------|
| `agents` | `~/.agents/skills/<name>` |
| `claude` | `~/.claude/skills/<name>` |
| `codex` | `~/.codex/skills/<name>` (legacy, explicit opt-in) |
| `grok` | `~/.grok/skills/<name>` (optional) |

**Idempotent:** re-running `./scripts/setup.sh` refreshes links; it does not
delete non-zstack skills. A skipped conflict or failed link makes the command
exit non-zero after reporting the complete summary.

**Scoped reconciliation:** each run treats selected host roots (plus the current
`--project` root) as desired-state scopes. It removes only links into this
repository whose skill became draft/deprecated or lost that host allowlist.
Unselected host roots, other clone records, non-links, and backups are retained.
If `--force` successfully takes over the exact same destination from another
clone, setup preserves the old symlink as a backup and transfers that path's
manifest ownership to the new clone.

**Safety:**

- Never overwrite a conflicting path by default. With `--force`, move it to a
  timestamped `.zstack-backup-*` sibling before creating the link. Restore the
  original automatically if link creation fails.
- Require an absolute, non-root-resolving `HOME`; host profiles must stay under
  `~/` without `.` or `..` traversal components.
- Refuse project-local installation when the current directory is `/`.
- Only manage links whose targets resolve under `ZSTACK_ROOT/skills/`.
- Record successful global and project-local links in `~/.zstack/links`.
- Refuse a symlinked `~/.zstack` state directory so locks and manifests cannot
  escape into an unrelated filesystem location.
- Serialize setup and unlink mutations with a recoverable PID lock under
  `~/.zstack/`; live operations block competitors and stale locks self-heal.
  Recovery and release refuse lock directories containing anything except the
  regular `pid` owner file, preserving unknown contents for manual inspection.
- `unlink.sh` removes a recorded or discovered link only when its target resolves
  under the current `ZSTACK_ROOT/skills/`; backups and non-links are preserved.

### 6.3 Conflict with existing skills

Install never overwrites a non-symlink path without explicit user action. If name collides with another pack (e.g. gstack short name), **rename the zstack skill** — do not fight the user machine.

**User end state after install:**

```text
zstack/skills/z-foo  ←── ~/.agents/skills/z-foo
                     ←── ~/.claude/skills/z-foo

Optional:            ←── ~/.codex/skills/z-foo
                     ←── ~/.grok/skills/z-foo
```

### 6.4 Project-local install (optional)

```bash
./scripts/setup.sh --project   # links into <repo>/.agents/skills
```

Use when a skill is product-specific and should travel with an app repo. Personal daily tools stay global.
The absolute project link paths are retained in the install manifest so
`./scripts/unlink.sh` can remove them even when run elsewhere.

### 6.5 Relationship to gstack

| Concern | Owner |
|---------|-------|
| `/qa`, `/ship`, `/browse`, multi-host generators | **gstack** |
| Personal OPC skills, Chinese workflows, niche tools | **zstack** |
| Install dir collision (`~/.claude/skills/z-foo`) | The `z-` prefix separates this pack from gstack short names |

**Name policy:** the `z-` namespace avoids gstack short names (`qa`, `ship`,
`review`, `browse`, …). Prefer descriptive names such as
`z-cf-d1-migrate`, `z-opc-daily-report`, or `z-stripe-webhook-smoke`.

---

## 7. Catalog

### 7.1 `catalog.yaml` (example)

```yaml
version: 1
skills:
  - id: z-writing-daily-work-reports
    path: skills/z-writing-daily-work-reports
    status: active          # active | draft | deprecated
    category: reporting
    hosts: [agents, claude, codex, grok]
    tags: [chinese, work]

  - id: z-experimental-foo
    path: skills/z-experimental-foo
    status: draft
    hosts: [claude]         # only install to Claude while drafting
```

## 8. Host Profiles

Declarative files under `hosts/`:

```yaml
# hosts/claude.yaml
name: claude
display_name: Claude Code
skills_root: ~/.claude/skills
link_mode: symlink          # symlink | copy
frontmatter:
  required: [name, description]
  # no description max enforced by zstack doctor for claude
```

```yaml
# hosts/codex.yaml
name: codex
display_name: Legacy Codex compatibility root
skills_root: ~/.codex/skills
link_mode: symlink
enabled: false
frontmatter:
  required: [name, description]
  description_max_chars: 1024   # conservative cross-host limit
```

```yaml
# hosts/agents.yaml
name: agents
display_name: Agent Skills hub
skills_root: ~/.agents/skills
link_mode: symlink
```

```yaml
# hosts/grok.yaml
name: grok
display_name: Grok Build
skills_root: ~/.grok/skills
link_mode: symlink
enabled: false              # default off — Grok already reads ~/.claude + ~/.agents
```

**v1 decision:** no content rewriting. If a skill fails Codex validation, fix the source skill to be portable. Revisit generators only if a real skill cannot be expressed portably.

---

## 9. Authoring Workflow

```
1. ./scripts/new-skill.sh z-my-skill product
2. Edit skills/z-my-skill/SKILL.md (description, workflow, and handoff)
3. Customize the generated references/quality-bar.md; add more references or
   scripts only if needed
4. Review the auto-created draft metadata in catalog.yaml
5. Add at least three behavioral cases to evals/cases.yaml (including one
   happy-path) and two routing cases to evals/routing.yaml; mark only cases that
   require real files with `execution: artifact`
6. ./scripts/test.sh && ./scripts/doctor.sh --source-only
7. Change status to active and run ./scripts/setup.sh
8. Run affected post-selection cases with
   `ruby scripts/run-codex-behavioral-evals.rb --case <id>` or the Claude
   counterpart, and relevant routing
   cases with `ruby scripts/run-codex-routing-evals.rb --case <id>` or the
   matching Claude/Grok entry point, then
   smoke-test an explicit invocation and a natural-language auto-routing prompt
   in one host
9. git commit
```

`new-skill.sh` applies the same snapshot contract to both scaffold templates and
the catalog transaction. It publishes the generated directory and catalog by
rename, verifies the published catalog against an exclusive expected snapshot,
and rolls back only while that publication proof remains intact. If the catalog
or its expected snapshot changes, it preserves the published catalog and skill
instead of using ambiguous rollback evidence. Every file snapshot is allocated
and identity-tracked before bytes are copied into it; a same-byte replacement
inode is therefore rejected and preserved rather than mistaken for transaction
state during cleanup. Generated scaffold files likewise start as identity-bound
random files and reach their fixed package names through exclusive hard links;
an existing destination is never overwritten, and cleanup registration follows
the original inode to its published name.

### Quality bar for merge

- [ ] Valid YAML frontmatter with `name` + `description`
- [ ] Directory name matches `name`
- [ ] Description includes natural triggers and no host-specific invocation prefix
- [ ] No secrets, no absolute personal paths that break on another machine
- [ ] Body uses portable wording (command/file oriented)
- [ ] No scaffold or catalog placeholders remain
- [ ] Catalog category and tags are kebab-case; tags are unique and include `indie`
- [ ] Catalog summary is non-empty and meaningful
- [ ] Active skill links `references/quality-bar.md`
- [ ] Primary output preserves exactly one two-column, seven-row evidence handoff
- [ ] At least three behavioral cases include happy-path and resilience coverage
- [ ] At least two clean-context routing cases exercise the description
- [ ] `test.sh` and `doctor.sh` clean

---

## 10. Validation (doctor)

`scripts/doctor.sh` checks:

1. **Structure** — every `skills/*/SKILL.md` exists; name regex; name == dirname;
   references over 100 lines expose a Contents section near the top.
2. **YAML + frontmatter** — use the shared strict Ruby parser when available to
   reject syntax errors, aliases, duplicate keys, multiple documents, and
   complex mapping keys; stable bounded reads also reject linked files or path
   components and bind the opened descriptor to the pre-open inode before any
   content is read, copied, or hashed. Runners, archivers, evidence tools, and `doctor` share this
   contract instead of assuming `doctor` already ran. Doctor also batch-parses
   the exact workflow, catalog, host, behavioral, and routing snapshots consumed
   by its later checks, so strict syntax and semantic validation cannot silently
   refer to different source versions. Before and after all multi-stage skill
   checks, it also captures the bounded skill tree twice and compares canonical
   paths, file digests, inode metadata, modes, ownership, and link counts. At
   the pre-content boundary, the first pass also writes the exact bounded bytes
   into an owner-private tree; package, handoff, catalog, skill, and portability
   checks read only that snapshot, so a later live-path replacement cannot be
   opened before the final drift check rejects the run. It
   repeats that comparison after an installed skill-link audit. A concurrent
   skill-package change therefore invalidates the run, either skipping link
   checks or explicitly invalidating link results instead of accepting a
   mixed-source result. Always enforce
   required frontmatter fields and a non-empty description with Bash/AWK.
3. **Catalog** — require paths, status, hosts, kebab-case category, unique
   kebab-case tags including `indie`, and a meaningful summary.
4. **Host profiles** — require matching names, display names, safe HOME-contained
   roots, symlink mode, positive limits, and frontmatter fields.
5. **Skill content scans** — reject machine-local skill paths and host-specific
   tool ids, and validate the Evidence handoff contract, without following
   rejected skill-tree symlinks. Later Bash/AWK/grep content reads use the
   owner-private Ruby snapshot whose source state must equal the earlier
   baseline. Without Ruby, a conservative
   Bash preflight runs at both boundaries, requires current-user real
   directories and single-link regular files, rejects symlinks and special
   entries, and enforces the same 100,000-entry, 10,000-file, 2 MiB per-file,
   and 512 MiB collection bounds.
6. **Links** — under the shared setup/unlink mutation lock, each installed link
   must resolve under `$ZSTACK_ROOT/skills`. Before multi-stage parsing, doctor
   captures single-link, byte-exact snapshots of the catalog, host profiles,
   behavioral and routing manifests, and installed root/link state. It
   revalidates every live source before using the derived views and skips the
   link audit rather than report a mixed snapshot while inputs drift or another
   maintenance command is active.
7. **Collisions** — detect non-zstack paths occupying the same skill name.
8. **Behavioral manifest** — require unique, typed cases with non-empty prompts
   and criteria; every active skill needs three total, including happy-path and
   resilience coverage.
9. **Routing manifest** — require natural prompts without expected-skill
   leakage, valid active targets, two cases per active skill, two no-match
   cases across the suite, and Chinese positive/no-match coverage when
   descriptions advertise Chinese triggers.
10. **Commit-candidate lint** — capture one NUL-safe inventory of existing
   tracked/unignored paths (excluding intentional worktree deletions),
   bind its inode and every regular-file or symlink state before the Markdown
   and secret scans, then independently re-enumerate and recapture the final
   candidate set. Content, identity, and set-membership drift are rejected.
   Secret matching scans
   that same exact candidate set for common AI-provider credentials (including
   Hugging Face tokens and long `XAI_API_KEY` assignments), current and
   compatibility Cloudflare/Wrangler authentication assignments, Stripe,
   GitHub, npm, Google, Slack, AWS, and private-key signatures without reading
   ignored local state.
   A detection is reported as one aggregate error with at most five validated
   repository-relative paths (then one ellipsis); matched content and secret
   values are never echoed.
   When Git metadata is unavailable (for example, a source archive), the Bash
   fallback conservatively excludes zstack transaction state, `.gstack`,
   `node_modules`, root `logs/`, OS metadata, `*.log`/PID files, and private
   `.env`/`.dev.vars` variants and Wrangler state while retaining
   `.env.example` and `.dev.vars.example` as public source. Before content
   scans, that fallback also enforces the same candidate count, inventory,
   per-file, and total-byte limits as the Ruby state capture. It enumerates
   every non-directory entry, then accepts only current-user regular files or
   symlinks and requires regular files to have one hard link, preventing write
   aliases outside the repository.

CI runs Bash syntax, strict YAML, and the integration suite on Linux and macOS;
both jobs parse every Ruby script, while Linux also runs ShellCheck and
Actionlint. Marked current-evidence blocks in README and the compatibility page
are checked against the coverage reporter's JSON, so source-byte changes cannot
leave visible host counts stale. Ruby 2.6+ is required for contributor tests, evidence tooling, and
live routing evaluation. It remains an optional doctor enhancement for basic
install users: the portable Bash/AWK validation contract still runs when Ruby is
absent. The suite copies only tracked or unignored source into temporary
fixtures and uses temporary HOME directories, so it verifies link behavior
without reading ignored local state or touching the runner's real skill roots.

---

## 11. Runtime Behavior (what agents do)

zstack does **not** run a daemon. Runtime is entirely host-driven:

1. User explicitly invokes the skill with host syntax (`/name` or `$name`), or
   the model auto-routes from `description`.
2. Host injects `SKILL.md` body into context.
3. Agent follows steps; may execute scripts from the skill directory (resolved via symlink → real path).

Optional helper for scripts that need the real repo root:

```bash
# skills/z-foo/scripts/_root.sh
ZSTACK_SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
ZSTACK_ROOT="$(cd "$ZSTACK_SKILL_DIR/../.." && pwd -P)"
```

Because install is symlink-based, `pwd -P` resolves into the git repo.

---

## 12. Content strategy (original skills only)

| Do | Don’t |
|----|--------|
| Design skills for **indie / solo product work** | Copy personal `~/.agents` skill dumps into the repo |
| Write skills from scratch for open source | Vendor large third-party packs without a deliberate fork |
| Keep examples generic (`$HOME`, env vars) | Ship machine-local paths or private URLs |
| Document audience + triggers in `description` | Squatting gstack / other packs’ short names |

Roadmap is **skill-by-skill creation**, not import pipelines.

---

## 13. Alternatives Considered

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| **A. Symlink install (chosen)** | Live updates for contributors; simple for OSS clone | Windows symlink quirks | **v1 default** |
| **B. Copy install** | Works without symlinks | Stale after pull; needs lifecycle support | Not implemented in v1 |
| **C. Full host codegen (gstack-style)** | Perfect per-host frontmatter | Heavy for an indie skill pack | Reject for v1 |
| **D. Only `~/.agents/skills` as hub** | One install target for Codex + Grok | Claude uses its own root | Use agents **plus** the Claude root |
| **E. Nested categories as install paths** | Nice taxonomy | Breaks `<root>/<name>/SKILL.md` discovery | Taxonomy in catalog only |
| **F. Migrate existing personal skills first** | Fast content fill | Wrong product (not OSS-ready original pack) | **Rejected** |

---

## 14. Key Decisions

1. **Product = open-source indie-developer skill pack**, not a private skill dump.
2. **Canonical format = Agent Skills `SKILL.md`** with exactly `name` and `description` in frontmatter.
3. **Source of truth = this git repo’s `skills/`**; home directories are install targets only.
4. **Default install = symlink** into `~/.agents/skills` and
   `~/.claude/skills`; legacy Codex and dedicated Grok roots are explicit opt-ins.
5. **No content rewriting in v1** — portability via authoring rules + doctor.
6. **Original skills only** — no migration of personal/third-party packs; external tools may be linked in docs only.
7. **`z-` prefix on all skill ids** for multi-pack coexistence.
8. **Catalog** controls discovery, lifecycle status, metadata, and per-host install.
9. **Bash-first setup/doctor** so OSS users need no JS toolchain to install.
10. **Progressive skill tiers L0–L2**; L3 generators deferred.

---

## 15. Decided (product locks)

| # | Question | Decision |
|---|----------|----------|
| 1 | Grok install | **`hosts/grok.enabled: false`** — rely on Grok’s compat scan of `~/.agents` + `~/.claude` |
| 2 | Codex install | **Current root is `~/.agents/skills`**; keep `hosts/codex` disabled as a legacy opt-in |
| 3 | Skill naming | **Mandatory `z-` prefix** (e.g. `z-market-validate`) for OSS collision safety |
| 4 | Third-party skills | **Docs external links only** — never vendor marketplace packs into this repo |
| 5 | Content source | **Pure original skills only** — no migration of personal or others’ skill dumps |

### Still open (non-blocking)

1. Package manager: stay bash-only vs add Node/TS doctor later  
2. GitHub distribution: install docs only vs skill registries later  

---

## 16. Current State and Next Milestones

### Shipped

- Five original product-judgment skills
- Catalog-driven, per-host symlink installation
- Source, link, portability, catalog, and host-profile validation
- Integration tests, ShellCheck, and CI
- Four behavioral regression cases per active skill (happy-path, edge, and adversarial)
- English and Chinese description-only routing cases, including boundaries and no-matches
- Archived Grok runtime discovery and a historical complete no-web behavior
  matrix for all five skills; current-source gaps fail closed in CI
- Shared isolated Codex/Claude/Grok behavioral and routing runners with
  per-process-group wall-clock limits, plus reviewed atomic archivers
- Response/artifact behavioral execution modes with audited deliverable capture
  and byte-bound mechanical Evidence handoff validation
- English and Chinese install docs plus a contribution guide

### Next, only with evidence

- Restore current Grok behavior coverage once authentication is available, and
  add clean Claude behavior archives once a configured provider/model pair is
  available; re-run host/model matrices after upgrades
- Additional original workflows where the current product journey has a proven gap
- Logical packs only after the catalog is large enough that selective install
  solves a real problem

---

## 17. Success Metrics

- Stranger on GitHub: clone + `./scripts/setup.sh` → skills usable in Claude / Codex / Grok.
- Each skill is **original**, documented, and safe to open-source.
- `doctor.sh` catches broken frontmatter before a host loses reliable routing.
- Zero accidental overwrites of unrelated host skills.
- Authoring a new L0 skill takes &lt; 10 minutes including catalog + install.

---

*Locked decisions: minimal frontmatter, current default host roots, explicit
legacy profiles, z- prefix, docs-only third-party links, and original skills
only.*
