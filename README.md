# zstack

**Agent Skills for independent developers** — teach your AI coding agent how to *validate, interview, smoke-test, specify, and grow* a product, not only how to write code.

**Languages:** English (this file) · [中文说明](./README.zh-CN.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Validate](https://github.com/zh30/zstack/actions/workflows/validate.yml/badge.svg)](https://github.com/zh30/zstack/actions/workflows/validate.yml)
[![Skills](https://img.shields.io/badge/skills-5-brightgreen)](./skills/)
[![Hosts](https://img.shields.io/badge/hosts-Claude%20%7C%20Codex%20%7C%20Grok-black)](./ARCHITECTURE.md#3-how-each-host-discovers-skills)

---

## The problem (first principles)

Independent developers now have something previous generations did not: **AI agents that can write large amounts of software quickly**.

That creates a new failure mode.

| Easy (with AI) | Still hard (and still decides outcomes) |
|----------------|----------------------------------------|
| Scaffold an app | Know *whether* anyone needs it |
| Ship features | Talk to real users without fooling yourself |
| Polish UI | Test demand before months of build |
| Refactor forever | Write a buildable product definition |
| Generate blog posts | Earn attention with honest search strategy |

**First principle:** code is leverage on a *decision*. If the decision is wrong, more code multiplies waste.

Most agent tools optimize the left column. **zstack optimizes the right column** — the product-judgment loop that solo founders cannot afford to skip.

---

## What is an “Agent Skill”?

You do not need to be an AI engineer to use this.

Think of a **skill** as a **playbook your agent loads on demand**:

1. You select `z-market-validate` with your host's syntax (`/` in Claude/Grok,
   `$` in Codex), or describe the intent in plain language.
2. The agent opens a `SKILL.md` file — a structured set of steps, checklists, and quality bars.
3. It follows that playbook with its normal tools (search, edit files, run commands).
4. You get a **repeatable workflow**, not a one-off chat that evaporates next week.

**For practitioners:** skills follow the common Agent Skills convention (`name` + `description` frontmatter + markdown body). One source file installs into Claude Code, Codex, and Grok-compatible skill roots via symlink. See [ARCHITECTURE.md](./ARCHITECTURE.md) for host discovery paths, frontmatter policy, and install model.

---

## What zstack is

zstack is an **open-source collection of original skills** aimed at **one-person companies and indie builders**.

It is:

- A **product workflow pack** (validate → discover → smoke-test → specify → SEO)
- **Portable** across major AI coding agents
- **Installable** with one script
- **Versioned in git** so your playbooks improve over time

It is **not**:

- A replacement for general engineering packs such as [gstack](https://github.com/garrytan/gstack) (`/qa`, `/ship`, `/browse`, …) — use those for engineering factory work; use zstack for **product truth**
- A dump of vendored third-party skills
- A hosted SaaS or a separate agent product you must run as a service

---

## Who it is for

| You will feel at home if… | You may want something else if… |
|---------------------------|----------------------------------|
| You build alone or nearly alone | You need a full enterprise product-ops suite |
| You use Claude Code, Codex, or Grok Build | You only want model prompts with no install story |
| You have been burned by “AI-built apps nobody wants” | You only need code review / browser QA (try gstack) |
| You want process that compounds across projects | You want a black-box “AI CEO” with no inspectable steps |

---

## The product journey

zstack skills are designed to chain. You can enter at any step; the default path is:

```text
  Idea (half-baked is fine)
       │
       ▼
  z-market-validate      ← public signals: is anyone complaining / paying?
       │
       ▼
  z-customer-discovery   ← real humans, Mom Test: past behavior, not compliments
       │
       ▼
  z-landing-smoke        ← cheapest behavior test: page + waitlist / pre-order
       │
       ▼
  z-write-prd            ← only then: a buildable product definition
       │
       ▼
  build (your stack + your engineering skills)
       │
       ▼
  z-seo-plan             ← when there is something worth finding in search
```

**Why this order?**

1. **Public signal** is cheap and kills obvious non-problems.  
2. **Interviews** produce truth you cannot scrape — and catch self-deception.  
3. **Smoke tests** ask for *behavior* (email, money), not opinions.  
4. **PRDs** without the above often document fiction with high confidence.  
5. **SEO** on a wrong product is paid advertising for a dead end.

---

## Skills

Every skill id starts with **`z-`** so it does not collide with other packs on the same machine.

| Skill | Skill id | In plain language | Deeper purpose |
|-------|---------|-------------------|----------------|
| [z-market-validate](./skills/z-market-validate/) | `z-market-validate` | “Is this idea even worth a week?” | Multi-channel demand scan (X, Reddit, HN, PH, …), pro **and** con evidence, indie fit, 30–90 day return odds, entry wedge |
| [z-customer-discovery](./skills/z-customer-discovery/) | `z-customer-discovery` | “Talk to 5–15 real people without fooling yourself” | Mom Test coaching: recruit, interview guide, debrief, synthesis on pain / existing spend / switch willingness |
| [z-landing-smoke](./skills/z-landing-smoke/) | `z-landing-smoke` | “Cheapest way to see if anyone cares” | English landing + waitlist/pre-order, traffic plan, conversion & kill criteria before a large build |
| [z-write-prd](./skills/z-write-prd/) | `z-write-prd` | “Turn notes into something you can build” | Indie-sized PRD: problem, scope, FR IDs, acceptance criteria, non-goals, milestones |
| [z-seo-plan](./skills/z-seo-plan/) | `z-seo-plan` | “What should we actually try to rank for?” | Keyword research from PRD/URL/code, primary terms, page map, on-page & technical notes — no fake volume numbers |

Each skill ships with `references/` (templates, quality bars, playbooks). Read those when you want the full methodology; the agent is instructed to load them during a run.

---

## Quick start

### Requirements

- macOS or Linux. On Windows, use WSL; native Windows is not currently tested.
- [Git](https://git-scm.com/)
- At least one of: [Claude Code](https://code.claude.com/docs/en/skills), [OpenAI Codex](https://developers.openai.com/codex/skills), [Grok Build](https://x.ai)
- `bash` (for install/doctor scripts)
- Ruby 2.6+ for contributor tests, strict YAML/evidence validation, and routing
  evaluation tooling; basic install/unlink remains Bash-only

### Install

```bash
git clone https://github.com/zh30/zstack.git ~/code/zstack
cd ~/code/zstack
./scripts/setup.sh
./scripts/doctor.sh
```

`doctor.sh` reports every problem it finds by default. Use `--source-only` to
skip installed-link checks, or `--fail-fast` to stop at the first error during
focused iteration.

`setup.sh` symlinks each active catalog skill into the current required discovery
roots. Optional compatibility profiles are available through `--hosts`:

| Profile | Root | Default | Why |
|---------|------|---------|-----|
| Agent Skills hub | `~/.agents/skills/` | Yes | Current Codex user root; also discovered by Grok |
| Claude Code | `~/.claude/skills/` | Yes | Claude Code user root; also compatible with Grok |
| Legacy Codex | `~/.codex/skills/` | No | Older compatibility root: `./scripts/setup.sh --hosts codex` |
| Explicit Grok | `~/.grok/skills/` | No | Optional dedicated root: `./scripts/setup.sh --hosts grok` |

An explicit `--hosts` selection enables an optional profile. Later default runs
leave that unselected root untouched.

Edit a skill under `skills/` and every host sees the change immediately (symlink).
Conflicts are skipped and make setup exit non-zero; pass `--force` to preserve
the old path as a timestamped backup. If link creation then fails, setup restores
the original path. Managed global and `--project` links are recorded for cleanup:

```bash
./scripts/unlink.sh
```

Unlinking never removes conflict backups or non-symlink content.
Re-running setup reconciles only the selected host roots: links for skills that
became draft/deprecated or lost that host are removed, while unselected hosts
and other zstack clones are left untouched.

### Use

Explicit invocation differs by host:

```text
Claude / Grok: /z-market-validate
Codex:         $z-market-validate
```

Natural language is portable across hosts:

```text
Run customer discovery setup for ICP: independent design consultants.
Pain: weekly client reporting. Target 10 interviews.
```

---

## How it works (for the curious)

```text
┌──────────────────────────┐
│  This git repo           │
│  skills/z-*/SKILL.md     │  ← source of truth
└────────────┬─────────────┘
             │  ./scripts/setup.sh  (symlink)
         ┌───────┴────────┐
         ▼                ▼
 ~/.agents/skills  ~/.claude/skills
   Codex + Grok       Claude + Grok

 Optional explicit compatibility roots: ~/.codex/skills, ~/.grok/skills
```

**Design choices (first principles):**

| Choice | Why |
|--------|-----|
| Markdown playbooks, not a new runtime | Agents already execute; we constrain *judgment* |
| Symlink install | One edit, all hosts; no stale copies |
| `z-` prefix | Shared skill directories are crowded; namespaces prevent collisions |
| Original skills only | Quality and licensing stay coherent for open source |
| Current roots by default | Codex uses `~/.agents`; Claude uses `~/.claude`; Grok discovers both |
| Legacy roots are opt-in | Avoid unsupported duplicate installs while retaining older Codex and explicit Grok compatibility |
| Evidence over vibes | Skills force disconfirming search, Mom Test rules, kill criteria |

Deeper internals: **[ARCHITECTURE.md](./ARCHITECTURE.md)** · authoring: **[docs/authoring.md](./docs/authoring.md)** · agent rules for contributors: **[AGENTS.md](./AGENTS.md)**.

---

## Repository layout

```text
zstack/
├── README.md                 # You are here (English)
├── README.zh-CN.md           # Chinese
├── ARCHITECTURE.md           # Multi-host design
├── AGENTS.md                 # Rules when AI edits this repo
├── CONTRIBUTING.md           # Contribution workflow and quality gates
├── catalog.yaml              # Skill registry
├── hosts/                    # Per-agent install profiles
├── evals/
│   ├── cases.yaml            # Behavioral regression prompts and criteria
│   ├── routing.yaml          # Description-only skill-selection cases
│   └── runs/                 # Dated clean-context responses and grades
├── scripts/
│   ├── setup.sh              # Install / refresh symlinks
│   ├── doctor.sh             # Validate skills + links
│   ├── test.sh               # Installer + validator integration tests
│   ├── new-skill.sh          # Scaffold z-* skill
│   ├── unlink.sh             # Remove zstack-managed links only
│   ├── report-evidence-coverage.rb # Behavioral/routing provenance matrices
│   ├── run-behavioral-evals.rb # Shared isolated behavioral-runner core
│   ├── run-{codex,claude,grok}-behavioral-evals.rb # Host entry points
│   ├── archive-behavioral-run.rb # Shared reviewed-archive core
│   ├── archive-{codex,claude,grok}-behavioral-run.rb # Host entry points
│   ├── run-routing-evals.rb # Shared isolated description-routing core
│   ├── run-{codex,claude,grok}-routing-evals.rb # Host entry points
│   ├── archive-routing-run.rb # Shared atomic routing-archive core
│   ├── archive-{codex,claude,grok}-routing-run.rb # Host entry points
│   ├── generate-evidence-manifests.rb # Rebuild / check whole eval archives
│   ├── validate-yaml.rb      # Optional strict YAML + duplicate-key validation
│   ├── validate-evidence.rb  # Eval archive JSON / byte / SHA-256 validation
│   └── lib/                  # Shared shell parsing + immutable eval host inputs
├── skills/
│   ├── _template/
│   ├── z-market-validate/
│   ├── z-customer-discovery/
│   ├── z-landing-smoke/
│   ├── z-write-prd/
│   └── z-seo-plan/
└── docs/
    ├── authoring.md
    ├── compatibility.md
    ├── evidence-handoff.md
    ├── evaluation.md
    └── frontmatter.md
```

---

## Create or extend a skill

```bash
./scripts/new-skill.sh z-my-workflow product
# edit SKILL.md and customize the generated references/quality-bar.md
# review the auto-created draft in catalog.yaml
# add three behavioral (including happy-path) + two routing cases, then activate
./scripts/test.sh
./scripts/setup.sh
```

Rules of thumb:

1. **Name** = directory = portable skill id; must match `z-[a-z0-9-]+`.
2. **`description`** is the API for auto-invocation — put triggers in it.
3. Write the body for **any** host: prefer “run this command / read this file” over host-specific tool brand names.
4. Put long material in `references/`; keep `SKILL.md` executable.
5. No secrets, no machine-local absolute paths.
6. New scaffolds include the Evidence handoff and quality-bar baseline, but
   intentionally fail validation until skill and catalog placeholders are
   replaced; draft skills do not require behavioral or routing eval cases yet.

Pull requests are welcome; see [CONTRIBUTING.md](./CONTRIBUTING.md) for the
original-content policy, required checks, and smoke-test evidence.
Behavioral and routing test methodology lives in
[docs/evaluation.md](./docs/evaluation.md).
Archived runs preserve the model response separately from its grade; the
[host compatibility evidence](./docs/compatibility.md) links the current run
matrix. A passing archive is evidence for that runner and date, not a guarantee
across every model or host. The latest Codex routing evidence includes a
[context-budget regression](./evals/runs/2026-08-01-codex-routing-budget/summary.md)
and a [Chinese routing regression](./evals/runs/2026-08-01-codex-routing-zh/summary.md),
both with raw selections preserved.
The same routing protocol now has a reviewed
[Grok 25-case matrix](./evals/runs/2026-08-01-grok-routing-full-matrix/summary.md)
covering all English, Chinese, boundary, and no-match requests with complete
provenance.
The complete-output [happy-path run](./evals/runs/2026-07-31-happy-path/summary.md)
passed all five skills with raw artifacts preserved.
The reviewed Codex resilience matrices [A](./evals/runs/2026-08-01-codex-behavioral-resilience-matrix-a/summary.md)
and [B](./evals/runs/2026-08-01-codex-behavioral-resilience-matrix-b/summary.md)
bring complete-provenance behavioral coverage to 20/20 current cases.
The subsequent [host-gap audit](./evals/runs/2026-08-01-codex-happy-gap-regression/summary.md)
preserved three passes and one real artifact failure; the isolated
[artifact rerun](./evals/runs/2026-08-01-codex-landing-artifact-pass/summary.md)
retains the deployable page and closes Codex-specific complete coverage at
20/20.
The same snapshot, anti-leak, review, and atomic-archive protocol now has a
Claude Code adapter that records requested versus actual model ids and rejects
API errors even when the host wraps them in a nominal success result.
The current local Claude provider rejects its configured models before
generation; the runner reports this as a redacted `model-unavailable` failure,
so Claude behavior coverage remains honestly at 0/20.
The Grok adapter adds an isolated host home, prompt-file transport, an exact
final-response boundary, tool/sandbox controls, redacted API-error categories,
and the same private-provenance checks. Its reviewed
[19-case response matrix](./evals/runs/2026-08-01-grok-behavior-current-full-response/summary.md)
remains current for the 16 non-landing cases. The retained
[landing artifact failure](./evals/runs/2026-08-01-grok-behavior-current-smoke-artifact-unverified-success/summary.md)
triggered stricter provider-confirmed-success rules; all four landing cases now
need a fresh Grok rerun. The local Grok CLI currently reports unauthenticated,
so current-source Grok behavior coverage is honestly 16/20. Deterministic
adapter fixtures do not count as model evidence. A retained
[provider-schema failure](./evals/runs/2026-08-01-codex-landing-artifact-provider-schema-failure/summary.md)
then exposed a guessed Buttondown tag-ID contract. The skill now requires dated
official provider semantics or an explicit launch-blocking `VERIFY_*` mapping.
Codex combines its
[19-case response matrix](./evals/runs/2026-08-01-codex-behavior-current-full-response/summary.md)
with the reviewed [three-case landing rerun](./evals/runs/2026-08-01-codex-landing-response-after-closed-analytics-gate/summary.md)
and [real landing artifact](./evals/runs/2026-08-01-codex-landing-artifact-after-closed-analytics-gate/summary.md)
for 20/20 current-source coverage. The artifact keeps unknown attribution out
of decision lanes, strips the query and fragment before analytics setup, makes
no analytics or Buttondown request while explicit contract placeholders remain,
and exposes no raw provider or exception data. Its Function passed 18 local
adversarial intake/provider scenarios, including actual streamed-byte limits
without trusting `Content-Length`; deterministic browser checks also proved the
closed analytics gate and bounded attribution. CI requires current skill bytes
for both behavior and routing; the open Grok gap therefore fails closed until a
reviewed authenticated rerun is published.
Cross-host discovery evidence and all five Grok happy-path runs are
recorded in [host compatibility](./docs/compatibility.md), including retained
failures that led to discovery, landing-integrity, and PRD fixes.

---

## FAQ

**Do I need all three agents?**  
No. Install works for whichever roots exist on your machine.

**Will this write my product for me?**  
Skills produce *decisions and artifacts* (reports, interview guides, landing copy, PRDs, SEO plans). You still own judgment, outreach, and shipping.

**Why force English landing pages in `z-landing-smoke`?**  
Default smoke surface is global English; the skill allows CN pages when your ICP is China-primary. Experiment *notes* follow your language.

**Is this affiliated with gstack?**  
No. Complementary tooling. Avoid reusing gstack short names (`qa`, `ship`, …).

**Can I vendor other people’s skills here?**  
Project policy: **original skills only**. Link out in docs if useful.

---

## Status

Actively developed at `github.com/zh30/zstack`.

| Area | State |
|------|--------|
| Skill catalog (5) | Usable |
| Multi-host setup/doctor | Usable |
| Architecture docs | Usable |
| CI validation | Configured; currently fails closed on the documented Grok 16/20 behavior-evidence gap |
| Contributor guide | Usable |

---

## License

[MIT](./LICENSE) — free to use, modify, and distribute with attribution.

---

## Maintainers

Built for one-person product companies that refuse to confuse **shipping code** with **shipping value**.

If this pack saves you from a dead-end build, star the repo and open an issue with what you learned — that feedback is how the skills get sharper.
