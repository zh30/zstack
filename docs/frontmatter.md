# Frontmatter compatibility

Portable intersection for Claude Code, Codex, and Grok Build:

| Field | Required | Notes |
|-------|----------|-------|
| `name` | Yes | Must match directory name; **must start with `z-`**, then kebab-case, ≤64 chars |
| `description` | Yes | Routing + auto-invoke; include triggers and `/name` |
| `license` | Recommended | Use `MIT` to match repo |
| `metadata` | Optional | `author`, `tags`, `source` for forks |
| `allowed-tools` | Optional | Host-enforced inconsistently; ok to omit |
| `disable-model-invocation` | Optional | Force slash-only when `true` |

## Avoid in zstack (host- or vendor-specific)

- `preamble-tier`, gstack-only generators fields  
- Hard dependency on Claude-only tool ids in **body** text  
- Oversized multi-paragraph `description` (Codex is pickier)

## Description checklist

- [ ] Says **what** the skill does  
- [ ] Says **when** to use it (verbs / keywords)  
- [ ] Mentions `/skill-name`  
- [ ] Fits comfortably under ~500–1024 characters  
