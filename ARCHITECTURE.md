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
| **Copy only when needed** | Windows without Developer Mode, or hosts that rewrite content (rare for zstack). |
| **Progressive complexity** | L0 pure MD → L1 + scripts/references → L2 host adapters (only if forced). |
| **Discoverability first** | `description` is the API surface for auto-invocation; treat it as a product. |
| **No secret in skills** | Skills never embed tokens; reference env vars / wrangler secrets. |

---

## 3. How Each Host Discovers Skills

Ground truth from current tooling (2026):

| Host | Global skill roots | Project / repo roots | Notes |
|------|--------------------|----------------------|-------|
| **Claude Code** | `~/.claude/skills/<name>/SKILL.md` | `.claude/skills/` | Also used by many other tools for compat. |
| **Codex** | `~/.codex/skills/<name>/SKILL.md` | `.agents/skills/` | Strict frontmatter; invalid `SKILL.md` is skipped. Optional `agents/openai.yaml`. |
| **Grok Build** | `~/.grok/skills/`, plus **compat scan** of `~/.claude/skills/`, `~/.cursor/skills/` | `.grok/skills/`, `.agents/skills/`, `.claude/skills/`, `.cursor/skills/` | Dedupes by skill **name** (higher priority wins). Scans `.agents/skills` at each tier. |
| **Cross-tool hub** | `~/.agents/skills/` | `.agents/skills/` | De-facto standard path; Grok + many CLIs read it. Good default install target for OSS users. |

**Implication for zstack:** installing into **`~/.agents/skills`** + **`~/.claude/skills`** + **`~/.codex/skills`** (+ optional `~/.grok/skills`) covers the three primary agents with maximum overlap and least surprise.

```
                    ┌─────────────────────────┐
                    │   zstack git repo       │
                    │   skills/<name>/…       │
                    └───────────┬─────────────┘
                                │  setup / install
              ┌─────────────────┼─────────────────┐
              ▼                 ▼                 ▼
     ~/.agents/skills    ~/.claude/skills   ~/.codex/skills
     (hub + Grok)        (Claude Code)      (Codex)
              │                 │
              └────────┬────────┘
                       ▼
              Grok Build also scans
              ~/.claude + ~/.agents
```

Optional: also link `~/.grok/skills` for explicit Grok-only overrides; usually unnecessary if Claude/agents links exist.

---

## 4. Repository Layout

```
zstack/
├── README.md                 # What / why / quick start
├── ARCHITECTURE.md           # This document
├── AGENTS.md                 # Agent-facing rules when working *on* zstack
├── LICENSE
├── package.json              # Optional: scripts only (no runtime dep required)
├── catalog.yaml              # Skill registry (id, category, hosts, status)
├── skills/                   # ★ Source of truth
│   ├── _template/            # Scaffold for new skills
│   │   └── SKILL.md
│   ├── git-commit/
│   │   └── SKILL.md
│   ├── writing-daily-work-reports/
│   │   ├── SKILL.md
│   │   └── references/
│   └── some-tool-skill/
│       ├── SKILL.md
│       ├── scripts/
│       └── references/
├── packs/                    # Optional logical groups (meta only, no duplicate content)
│   └── opc-cloudflare.yaml   # lists skill ids in the pack
├── hosts/                    # Host profiles (declarative, small)
│   ├── agents.yaml
│   ├── claude.yaml
│   ├── codex.yaml
│   └── grok.yaml
├── scripts/
│   ├── setup.sh              # Primary installer (bash, zero deps)
│   ├── unlink.sh             # Clean uninstall of zstack links only
│   ├── doctor.sh             # Validate skills + link health
│   ├── new-skill.sh          # Scaffold from _template
│   └── lib/
│       └── common.sh
├── docs/
│   ├── authoring.md          # How to write a portable skill
│   ├── frontmatter.md        # Field compatibility matrix
│   └── migration.md          # Import from ~/.agents, ~/.claude, …
└── .github/
    └── workflows/
        └── validate.yml      # Frontmatter + structure CI
```

### Why this shape

- **`skills/` flat by name** — matches every host’s discovery model (`<root>/<name>/SKILL.md`). Nested categories would break discovery unless install rewrites paths.
- **`catalog.yaml`** — human + machine registry without inventing a DB: status (active/draft/deprecated), tags, which hosts to install to.
- **`hosts/*.yaml`** — install targets and frontmatter constraints in data, not hard-coded if-else forests.
- **`packs/`** — optional “install these 8 skills for Cloudflare OPC work”; never copies skill bodies.
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
| `evals/` | No | Optional fixtures / check prompts for quality |

**Naming:** `name` = directory name = slash command stem.  
**Required pattern:** `^z-[a-z0-9]([a-z0-9-]{0,60}[a-z0-9])?$` (must start with `z-`, ≤64 chars total).
### 5.2 Complexity tiers

| Tier | Contents | When to use |
|------|----------|-------------|
| **L0** | `SKILL.md` only | Most personal workflows, conventions, checklists |
| **L1** | + `scripts/` and/or `references/` | Need deterministic steps, long domain docs |
| **L2** | + host-specific extras (`agents/openai.yaml`, rare frontmatter) | Codex packaging or host-only flags |
| **L3** | Content generation / multi-host rewrite | **Out of scope for v1** — that’s gstack’s job. If a skill needs L3, either (a) keep it host-agnostic, or (b) document it as Claude-primary |

### 5.3 Portable SKILL.md shape (canonical)

```markdown
---
name: example-skill
description: >-
  One-line what + when. Include trigger phrases and /example-skill.
  Keep under ~500 chars when possible; Codex is pickier about invalid YAML.
license: MIT
# Optional, widely ignored if unknown:
# allowed-tools: Bash, Read
# disable-model-invocation: false
# metadata:
#   author: henry
#   tags: git, opc
---

# Example Skill

## When to use
…

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
4. Reference scripts as: `bash "$(dirname …)/scripts/foo.sh"` or document install root as `$ZSTACK_ROOT/skills/<name>/scripts/…` after setup exports `ZSTACK_ROOT`.
5. Do not hardcode `~/.claude/skills/...` paths inside skill bodies — use `$ZSTACK_ROOT` or relative discovery.
6. Keep **description** specific: verbs + nouns + slash name + failure-mode keywords.

### 5.4 Frontmatter compatibility matrix

| Field | Claude | Codex | Grok | zstack policy |
|-------|--------|-------|------|----------------|
| `name` | ✓ | ✓ | ✓ | **Required** |
| `description` | ✓ | ✓ | ✓ | **Required**; primary routing signal |
| `license` | ✓ | ✓ | ✓ | Recommended (MIT to match repo) |
| `allowed-tools` | ✓ | often ignored | ✓ | Optional; host-specific enforcement |
| `disable-model-invocation` | ✓ | varies | ✓ | Optional |
| `when-to-use` | some | rare | ✓ | Prefer folding into `description` for portability |
| `triggers` / `preamble-tier` | gstack | — | — | **Avoid in zstack** (gstack-specific) |
| `metadata` | ✓ | ✓ | ✓ | Free-form; ok |
| `compatibility` | some | some | ✓ | Optional human note |

**Rule:** unknown keys should be harmless, but **Codex has rejected skills for invalid/oversized frontmatter**. Validate with `scripts/doctor.sh` before install.

---

## 6. Install & Linking Model

### 6.1 Source of truth path

Default clone location (documented, not enforced):

```text
~/code/zstack          # or any path; setup records absolute path
```

Environment:

```bash
export ZSTACK_ROOT="$HOME/code/zstack"   # optional; setup can write to ~/.zstack/config
```

### 6.2 Link strategy (v1)

For each skill marked `status: active` in `catalog.yaml`, and for each enabled host profile:

```text
ln -sfn "$ZSTACK_ROOT/skills/<name>"  "<host_skills_root>/<name>"
```

Examples:

| Host profile | Target |
|--------------|--------|
| `agents` | `~/.agents/skills/<name>` |
| `claude` | `~/.claude/skills/<name>` |
| `codex` | `~/.codex/skills/<name>` |
| `grok` | `~/.grok/skills/<name>` (optional) |

**Idempotent:** re-running `./setup` refreshes links; does not delete non-zstack skills.

**Safety:**

- Never overwrite a **non-symlink** directory that doesn’t point into `ZSTACK_ROOT` without `--force`.
- Only manage links whose targets resolve under `ZSTACK_ROOT/skills/`.
- `unlink.sh` removes only zstack-managed links (detect via target path).

### 6.3 Conflict with existing skills

Install never overwrites a non-symlink path without explicit user action. If name collides with another pack (e.g. gstack short name), **rename the zstack skill** — do not fight the user machine.

**User end state after install:**

```text
zstack/skills/foo  ←── ~/.agents/skills/foo
                   ←── ~/.claude/skills/foo
                   ←── ~/.codex/skills/foo
```

### 6.4 Project-local install (optional)

```bash
./setup --project   # links into <repo>/.agents/skills for team sharing
```

Use when a skill is product-specific and should travel with an app repo. Personal daily tools stay global.

### 6.5 Relationship to gstack

| Concern | Owner |
|---------|-------|
| `/qa`, `/ship`, `/browse`, multi-host generators | **gstack** |
| Personal OPC skills, Chinese workflows, niche tools | **zstack** |
| Install dir collision (`~/.claude/skills/foo`) | Names must not clash with gstack short names if both installed without prefix |

**Name policy:** avoid squatting gstack short names (`qa`, `ship`, `review`, `browse`, …). Prefer descriptive personal names (`cf-d1-migrate`, `opc-daily-report`, `stripe-webhook-smoke`).

---

## 7. Catalog & Packs

### 7.1 `catalog.yaml` (example)

```yaml
version: 1
skills:
  - id: writing-daily-work-reports
    path: skills/writing-daily-work-reports
    status: active          # active | draft | deprecated
    category: reporting
    hosts: [agents, claude, codex, grok]
    tags: [chinese, work]

  - id: experimental-foo
    path: skills/experimental-foo
    status: draft
    hosts: [claude]         # only install to Claude while drafting
```

### 7.2 Packs

```yaml
# packs/opc-cloudflare.yaml
name: opc-cloudflare
description: Skills for Cloudflare-native OPC web apps
skills:
  - cf-d1-migrate
  - wrangler-preview-checklist
  - stripe-webhook-smoke
```

Install: `./setup --pack opc-cloudflare`.

---

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
display_name: OpenAI Codex CLI
skills_root: ~/.codex/skills
link_mode: symlink
frontmatter:
  required: [name, description]
  description_max_chars: 1024   # soft limit; doctor warns
  strip_unknown: false          # v1: do not rewrite files
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
1. ./scripts/new-skill.sh my-skill
2. Edit skills/my-skill/SKILL.md (description + steps)
3. Add scripts/references only if needed
4. ./scripts/doctor.sh my-skill
5. Register in catalog.yaml (status: draft → active)
6. ./setup --hosts claude,codex,agents
7. Smoke: invoke /my-skill in each agent
8. git commit
```

### Quality bar for merge

- [ ] Valid YAML frontmatter with `name` + `description`
- [ ] Directory name matches `name`
- [ ] Description includes triggers / slash command
- [ ] No secrets, no absolute personal paths that break on another machine
- [ ] Body uses portable wording (command/file oriented)
- [ ] `doctor.sh` clean
- [ ] Catalog entry present

---

## 10. Validation (doctor)

`scripts/doctor.sh` checks:

1. **Structure** — every `skills/*/SKILL.md` exists; name regex; name == dirname.
2. **Frontmatter** — parse YAML; required fields; description non-empty.
3. **Portability lint** — warn on hardcoded `~/.claude/skills/gstack` or host-only tool jargon when avoidable.
4. **Links** — for each host, if link exists, target must resolve under `$ZSTACK_ROOT/skills`.
5. **Collisions** — detect non-zstack dirs occupying the same skill name.
6. **Catalog sync** — warn if directory missing from catalog or catalog points to missing path.

CI runs the same checks without link verification (no home dirs on CI), or with a dry-run mode.

---

## 11. Runtime Behavior (what agents do)

zstack does **not** run a daemon. Runtime is entirely host-driven:

1. User (or model) invokes skill by slash command or auto-routing on `description`.
2. Host injects `SKILL.md` body into context.
3. Agent follows steps; may execute scripts from the skill directory (resolved via symlink → real path).

Optional helper for scripts that need the real repo root:

```bash
# skills/foo/scripts/_root.sh
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
| **B. Copy install** | Works everywhere | Stale after pull; needs re-setup | Fallback only |
| **C. Full host codegen (gstack-style)** | Perfect per-host frontmatter | Heavy for an indie skill pack | Reject for v1 |
| **D. Only `~/.agents/skills` as hub** | One install target | Claude/Codex may not all scan it equally | Use agents **plus** explicit claude/codex links |
| **E. Nested categories as install paths** | Nice taxonomy | Breaks `<root>/<name>/SKILL.md` discovery | Taxonomy in catalog only |
| **F. Migrate existing personal skills first** | Fast content fill | Wrong product (not OSS-ready original pack) | **Rejected** |

---

## 14. Key Decisions

1. **Product = open-source indie-developer skill pack**, not a private skill dump.
2. **Canonical format = Agent Skills `SKILL.md`** with minimal frontmatter (`name`, `description`, optional `license` / `metadata`).
3. **Source of truth = this git repo’s `skills/`**; home directories are install targets only.
4. **Install = symlink** into `~/.agents/skills`, `~/.claude/skills`, `~/.codex/skills`; **Grok via compat scan** (`hosts/grok` disabled).
5. **No content rewriting in v1** — portability via authoring rules + doctor.
6. **Original skills only** — no migration of personal/third-party packs; external tools may be linked in docs only.
7. **`z-` prefix on all skill ids** for multi-pack coexistence.
8. **Catalog + packs** for discovery and partial install.
9. **Bash-first setup/doctor** so OSS users need no JS toolchain to install.
10. **Progressive skill tiers L0–L2**; L3 generators deferred.

---

## 15. Decided (product locks)

| # | Question | Decision |
|---|----------|----------|
| 1 | Grok install | **`hosts/grok.enabled: false`** — rely on Grok’s compat scan of `~/.agents` + `~/.claude` |
| 2 | Skill naming | **Mandatory `z-` prefix** (e.g. `z-market-validate`) for OSS collision safety |
| 3 | Third-party skills | **Docs external links only** — never vendor marketplace packs into this repo |
| 4 | Content source | **Pure original skills only** — no migration of personal or others’ skill dumps |

### Still open (non-blocking)

1. Package manager: stay bash-only vs add Node/TS doctor later  
2. GitHub distribution: install docs only vs skill registries later  

---

## 16. PR Plan (implementation slices)

### PR1 — Scaffold ✅
- Architecture, README, AGENTS, template, hosts, setup/doctor/new-skill

### PR2 — First original skills ✅
- `z-market-validate`, `z-write-prd`
- Catalog + multi-host install + `z-` naming lock

### PR3 — OSS polish
- Public install docs (clone → setup → verify on three hosts)
- CONTRIBUTING.md for external skill PRs
- CI: `doctor.sh` on push

### PR4 — Packs (optional)
- Logical packs once enough skills exist (e.g. `shipping`, `growth`, `cloudflare-opc`)

---

## 17. Success Metrics

- Stranger on GitHub: clone + `./scripts/setup.sh` → skills usable in Claude / Codex / Grok.
- Each skill is **original**, documented, and safe to open-source.
- `doctor.sh` catches broken frontmatter before Codex skips the skill.
- Zero accidental overwrites of unrelated host skills.
- Authoring a new L0 skill takes &lt; 10 minutes including catalog + install.

---

*Last updated: 2026-07-29 — locked: Grok compat scan, z- prefix, docs-only third-party links, original skills only.*
