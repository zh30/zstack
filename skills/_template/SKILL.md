---
name: z-skill-name
description: >-
  TODO: Describe the recurring independent-developer outcome in one or two sentences.
  State when the user asks for the relevant jobs, trigger phrases, or artifacts.
  Keep invocation syntax out of this description; hosts use different prefixes.
---

# Z Skill Name

## Workflow

1. …
2. …

## Output contract

Produce a concrete artifact that records inputs, assumptions, decisions, and the
next bounded action. Use `TBD until validated` for result fields before evidence
exists.

The handoff is a fixed interface. Emit exactly one two-column, seven-row table
headed `Field | Value`. Keep all seven field labels as exact plain-text tokens
and put only applicable canonical class names in `Evidence classes`.
Include a class only when supplied inputs or actual results belong to it; a
planned future validation does not make that class current.
Never leave the class cell empty; use `assumption` when the artifact rests only
on missing, invalid, or unverified inputs and explain that limit elsewhere.

## Evidence handoff

| Field | Value |
|-------|-------|
| Current decision | … |
| Evidence classes | primary behavior / observed experiment / secondary public / search signal / assumption |
| Supported claims | … |
| Still unproven | … |
| Contradictions / exclusions | … |
| Source anchors | … |
| Next validation | … |

## Quality gate

Before delivery, read and apply the
[quality bar](references/quality-bar.md).

## Guardrails

- Evidence does not upgrade on handoff. Preserve its original class and say
  what remains unproven.
- Never commit secrets.
- Prefer editing files via normal agent file tools / shell; keep steps host-agnostic.
