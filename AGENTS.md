# AGENTS.md — zstack

Instructions for AI agents working **on this repository** (authoring skills for an open-source pack).

## Purpose

zstack is an **open-source multi-host Agent Skill collection for independent developers**. Skills must run on Claude Code, Codex, and Grok Build from a single `SKILL.md`.

**Create original skills only.** Do not migrate personal home-dir skills or vendor third-party packs into this repo. External tools may be **linked in docs** only.

## Hard rules

1. **Source of truth** is `skills/<name>/`. Never “fix” a skill only in an
   installed home-directory link such as `~/.agents`, `~/.claude`, or `~/.codex`.
2. **Portable wording** in skill bodies: prefer shell commands and “read/edit this file” over host-specific tool names.
3. **Minimal frontmatter**: always `name` + `description`. Directory name must equal `name`.
4. **`z-` prefix required** on every skill id (`z-market-validate`, not `market-validate`). Avoids collisions with gstack and other packs.
5. **No secrets** in skills or catalog. Skills must be safe to open-source.
6. **Audience**: independent / solo developers (OPC). Prefer workflows that compound for one-person product teams.
7. **Symlink install** via `scripts/setup.sh` for local use; public users clone this repo then run setup.
8. **Host roots**: keep `agents` + `claude` enabled by default. Current Codex uses
   `~/.agents/skills`; keep `hosts/codex` as an explicit legacy opt-in. Grok scans
   `~/.agents` + `~/.claude`, so keep `hosts/grok` as an explicit opt-in too.
9. **Do not reimplement gstack** binaries or multi-host codegen unless architecture is explicitly revised.

## After changing a skill

1. Add or update its behavioral cases in `evals/cases.yaml`; when its
   `description` changes, also update and re-run `evals/routing.yaml`.
2. Run `./scripts/test.sh` and `./scripts/doctor.sh`.
3. Ensure its `catalog.yaml` metadata is complete before setting it `active`.
4. Keep its linked quality bar and evidence-handoff output contract current.
5. Re-run `./scripts/setup.sh` if the skill is new.
6. Smoke-test slash invocation in at least one host.

## Adding a skill

```bash
./scripts/new-skill.sh z-my-skill-name product
# edit skills/z-my-skill-name/SKILL.md
# review the auto-created draft in catalog.yaml
# add three behavioral (including happy-path) + two routing cases, then activate
./scripts/test.sh
./scripts/setup.sh
```

See `docs/authoring.md` and `ARCHITECTURE.md`.
