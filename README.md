# zstack

**Agent Skills for independent developers** — teach your AI coding agent how to *validate, interview, smoke-test, specify, and grow* a product, not only how to write code.

**Languages:** English (this file) · [中文说明](./README.zh-CN.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Skills](https://img.shields.io/badge/skills-5-brightgreen)](./skills/)
[![Hosts](https://img.shields.io/badge/hosts-Claude%20%7C%20Codex%20%7C%20Grok-black)](#works-with-your-agent)

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

1. You type something like `/z-market-validate` or describe an intent in plain language.  
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

| Skill | Command | In plain language | Deeper purpose |
|-------|---------|-------------------|----------------|
| [z-market-validate](./skills/z-market-validate/) | `/z-market-validate` | “Is this idea even worth a week?” | Multi-channel demand scan (X, Reddit, HN, PH, …), pro **and** con evidence, indie fit, 30–90 day return odds, entry wedge |
| [z-customer-discovery](./skills/z-customer-discovery/) | `/z-customer-discovery` | “Talk to 5–15 real people without fooling yourself” | Mom Test coaching: recruit, interview guide, debrief, synthesis on pain / existing spend / switch willingness |
| [z-landing-smoke](./skills/z-landing-smoke/) | `/z-landing-smoke` | “Cheapest way to see if anyone cares” | English landing + waitlist/pre-order, traffic plan, conversion & kill criteria before a large build |
| [z-write-prd](./skills/z-write-prd/) | `/z-write-prd` | “Turn notes into something you can build” | Indie-sized PRD: problem, scope, FR IDs, acceptance criteria, non-goals, milestones |
| [z-seo-plan](./skills/z-seo-plan/) | `/z-seo-plan` | “What should we actually try to rank for?” | Keyword research from PRD/URL/code, primary terms, page map, on-page & technical notes — no fake volume numbers |

Each skill ships with `references/` (templates, quality bars, playbooks). Read those when you want the full methodology; the agent is instructed to load them during a run.

---

## Quick start

### Requirements

- macOS or Linux (symlink-based install; Windows users: enable Developer Mode or re-run setup after pulls)
- [Git](https://git-scm.com/)
- At least one of: [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [OpenAI Codex CLI](https://github.com/openai/codex), [Grok Build](https://x.ai)
- `bash` (for install/doctor scripts)

### Install

```bash
git clone https://github.com/<your-org>/zstack.git ~/code/zstack
cd ~/code/zstack
./scripts/setup.sh
./scripts/doctor.sh
```

`setup.sh` symlinks each skill into:

| Host | Default skill root |
|------|--------------------|
| Agent Skills hub | `~/.agents/skills/` |
| Claude Code | `~/.claude/skills/` |
| Codex | `~/.codex/skills/` |
| Grok Build | Uses compat scan of agents/claude by default (`hosts/grok` off) |

Edit a skill under `skills/` and every host sees the change immediately (symlink).

### Use

In your agent session:

```text
/z-market-validate
I want to build a tool that turns meeting notes into client invoices for freelancers.
```

Or natural language:

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
     ┌───────┼────────┐
     ▼       ▼        ▼
 ~/.agents  ~/.claude ~/.codex
     │       │
     └───────┴──► Grok also scans these roots
```

**Design choices (first principles):**

| Choice | Why |
|--------|-----|
| Markdown playbooks, not a new runtime | Agents already execute; we constrain *judgment* |
| Symlink install | One edit, all hosts; no stale copies |
| `z-` prefix | Shared skill directories are crowded; namespaces prevent collisions |
| Original skills only | Quality and licensing stay coherent for open source |
| No Grok-only install by default | Grok already reads `~/.agents` / `~/.claude` |
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
├── catalog.yaml              # Skill registry
├── hosts/                    # Per-agent install profiles
├── scripts/
│   ├── setup.sh              # Install / refresh symlinks
│   ├── doctor.sh             # Validate skills + links
│   ├── new-skill.sh          # Scaffold z-* skill
│   └── unlink.sh             # Remove zstack-managed links only
├── skills/
│   ├── _template/
│   ├── z-market-validate/
│   ├── z-customer-discovery/
│   ├── z-landing-smoke/
│   ├── z-write-prd/
│   └── z-seo-plan/
└── docs/
    ├── authoring.md
    └── frontmatter.md
```

---

## Create or extend a skill

```bash
./scripts/new-skill.sh z-my-workflow
# edit skills/z-my-workflow/SKILL.md
# register in catalog.yaml
./scripts/doctor.sh
./scripts/setup.sh
```

Rules of thumb:

1. **Name** = directory = slash command; must match `z-[a-z0-9-]+`.  
2. **`description`** is the API for auto-invocation — put triggers in it.  
3. Write the body for **any** host: prefer “run this command / read this file” over host-specific tool brand names.  
4. Put long material in `references/`; keep `SKILL.md` executable.  
5. No secrets, no machine-local absolute paths.

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

Actively developed. Public remote URL may still be private until you publish — replace the clone URL in Quick start with your GitHub path when ready.

| Area | State |
|------|--------|
| Skill catalog (5) | Usable |
| Multi-host setup/doctor | Usable |
| Architecture docs | Usable |
| CI / CONTRIBUTING | Planned |

---

## License

[MIT](./LICENSE) — free to use, modify, and distribute with attribution.

---

## Maintainers

Built for one-person product companies that refuse to confuse **shipping code** with **shipping value**.

If this pack saves you from a dead-end build, star the repo and open an issue with what you learned — that feedback is how the skills get sharper.
