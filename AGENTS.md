# AGENTS.md — zstack

Instructions for AI agents working **on this repository** (authoring skills for an open-source pack).

## Purpose

zstack is an **open-source multi-host Agent Skill collection for independent developers**. Skills must run on Claude Code, Codex, and Grok Build from a single `SKILL.md`.

**Create original skills only.** Do not migrate personal home-dir skills or vendor third-party packs into this repo. External tools may be **linked in docs** only.

## Hard rules

1. **Source of truth** is `skills/<name>/`. Never “fix” a skill only under `~/.claude` or `~/.codex`.
2. **Portable wording** in skill bodies: prefer shell commands and “read/edit this file” over host-specific tool names.
3. **Minimal frontmatter**: always `name` + `description`. Directory name must equal `name`.
4. **`z-` prefix required** on every skill id (`z-market-validate`, not `market-validate`). Avoids collisions with gstack and other packs.
5. **No secrets** in skills or catalog. Skills must be safe to open-source.
6. **Audience**: independent / solo developers (OPC). Prefer workflows that compound for one-person product teams.
7. **Symlink install** via `scripts/setup.sh` for local use; public users clone this repo then run setup.
8. **Grok**: do not enable `hosts/grok` by default — Grok scans `~/.agents` + `~/.claude`.
9. **Do not reimplement gstack** binaries or multi-host codegen unless architecture is explicitly revised.

## After changing a skill

1. Run `./scripts/doctor.sh` (when available).
2. Ensure `catalog.yaml` lists the skill.
3. Re-run `./scripts/setup.sh` if the skill is new.
4. Smoke-test slash invocation in at least one host.

## Adding a skill

```bash
./scripts/new-skill.sh z-my-skill-name
# edit skills/z-my-skill-name/SKILL.md
# add catalog.yaml entry
./scripts/setup.sh
```

See `docs/authoring.md` and `ARCHITECTURE.md`.
