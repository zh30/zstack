# Frontmatter compatibility

zstack uses the smallest reliable intersection across Claude Code, Codex, and
Grok Build. Every `SKILL.md` frontmatter contains **exactly two keys**:

| Field | Required | Rule |
|-------|----------|------|
| `name` | Yes | Match the directory; start with `z-`; kebab-case; ≤64 characters |
| `description` | Yes | Explain what and when; omit host-specific invocation syntax; 80–1024 characters |

Example:

```yaml
---
name: z-example-workflow
description: >-
  Do a specific job for independent developers. Use when the user asks for
  the relevant outcome, artifact, or concrete trigger phrase.
---
```

Repository-wide licensing lives in `LICENSE`; catalog metadata lives in
`catalog.yaml`. Do not duplicate either in skill frontmatter. Avoid
host-specific fields such as `allowed-tools`, `disable-model-invocation`,
`metadata`, `preamble-tier`, or vendor-specific trigger keys.

## Description checklist

- [ ] Says **what** the skill does
- [ ] Says **when** to use it with concrete verbs and keywords
- [ ] Omits `/z-*` and `$z-*`; hosts expose different explicit prefixes
- [ ] Fits under 1024 characters; prefer roughly 500 or fewer
- [ ] Does not depend on host-specific tool names
