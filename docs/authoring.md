# Authoring portable skills

zstack ships **original** skills for **independent developers**. Write for strangers on GitHub, not only for one machine.

## Audience checklist

Before merging a skill, confirm:

- [ ] A solo founder / OPC builder would invoke this more than once
- [ ] Steps work without the author’s private context
- [ ] No secrets, no `/Users/...` paths, no private repo assumptions unless documented as optional

## Authoring checklist

1. `./scripts/new-skill.sh <name> [category]`; this atomically creates the
   skill and a `draft` catalog entry.
2. Set `name` == directory name.
3. Keep frontmatter to exactly `name` + `description`; write a strong routing
   description (see [frontmatter.md](./frontmatter.md)). Put all trigger
   guidance there; do not repeat a `When to use` section in the body because
   the body loads only after the skill has triggered.
4. Keep the body portable across hosts:
   - “Run: `git status`” not “use the Bash tool to…”
   - “Read `path/to/file`” not “call mcp__…”
5. Put long material in `references/`; link every reference directly from
   `SKILL.md` with a clear instruction for when to read it. References over 100
   lines need a `## Contents` section in their first 30 lines so an agent can
   route to the relevant section without loading the whole file blindly.
6. Customize the generated, directly linked `references/quality-bar.md` and
   Evidence handoff for the workflow. Every active skill must keep both. Its
   primary output must contain exactly one two-column, seven-row
   `Field | Value` table and follow the
   [evidence handoff contract](./evidence-handoff.md) without upgrading upstream
   assumptions or weak signals.
7. Put deterministic logic in `scripts/` when useful.
8. Replace the scaffold placeholders and review the auto-created catalog
   category, tags, and summary. Tags must be unique kebab-case values and
   include `indie`.
9. Add at least three behavioral cases to `evals/cases.yaml` (including one
   `happy-path` and one `edge` or `adversarial`) and two clean-context routing
   cases to `evals/routing.yaml`, then change `draft` to `active`. Behavioral
   cases default to response-only; add `execution: artifact` only when an actual
   written deliverable is part of the grade.
10. Run `./scripts/test.sh`; if Bash changed, also run
   `shellcheck scripts/*.sh scripts/lib/*.sh`.
11. Run affected post-selection cases with
    `ruby scripts/run-codex-behavioral-evals.rb --case <id>` or the Claude/Grok
    counterpart; inspect and grade the raw response in `review.json`. The
    runner pre-fills only the mechanically checked handoff criterion and does
    not grade semantics. Promote reviewed release
    evidence with the matching host archiver.
    When a description changes, run the relevant clean routing cases with
    `ruby scripts/run-codex-routing-evals.rb --case <id>` and, when practical,
    the matching Claude/Grok entry point. For release-facing routing evidence,
    promote `RUN_DIR` with the matching `archive-<host>-routing-run.rb` instead
    of copying artifacts by hand.
12. Run `ruby scripts/report-evidence-coverage.rb`, then
    `./scripts/setup.sh`; smoke-test explicit invocation using that host's
    syntax (`/name` in Claude/Grok, `$name` in Codex) and a natural-language
    auto-routing prompt on at least one host.

## What not to put in a skill

- API keys, cookies, private URLs with tokens  
- Machine-specific absolute paths  
- Migrated dumps of unrelated personal skills  
- Full copies of gstack (or other packs’) workflows  

## Naming

**Required:** `z-` prefix + descriptive kebab-case.

| Good | Bad |
|------|-----|
| `z-launch-checklist` | `launch-checklist` (no prefix) |
| `z-pricing-page-review` | `qa`, `ship`, `browse` (gstack collisions) |
| `z-write-prd` | `write-prd` |

Pattern: `^z-[a-z0-9]([a-z0-9-]{0,60}[a-z0-9])?$`
