# Authoring portable skills

zstack ships **original** skills for **independent developers**. Write for strangers on GitHub, not only for one machine.

## Audience checklist

Before merging a skill, confirm:

- [ ] A solo founder / OPC builder would invoke this more than once
- [ ] Steps work without the author’s private context
- [ ] No secrets, no `/Users/...` paths, no private repo assumptions unless documented as optional

## Authoring checklist

1. `./scripts/new-skill.sh <name>`
2. Set `name` == directory name.
3. Write a strong `description` (see [frontmatter.md](./frontmatter.md)).
4. Keep the body portable across hosts:
   - “Run: `git status`” not “use the Bash tool to…”
   - “Read `path/to/file`” not “call mcp__…”
5. Put long material in `references/`; keep `SKILL.md` executable.
6. Put deterministic logic in `scripts/` when useful.
7. Register in `catalog.yaml` (`draft` → `active`).
8. `./scripts/doctor.sh` + `./scripts/setup.sh`; smoke-test slash invoke on at least one host.

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
