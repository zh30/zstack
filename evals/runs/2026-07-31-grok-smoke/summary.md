# Grok cross-host smoke — 2026-07-31

## Result

**PASS: 1/1 case, 5/5 observable criteria.**

The run started in a fresh temporary directory with the globally installed
zstack symlink available through `~/.agents/skills`. Grok selected
`z-market-validate` from the natural-language request, read its `SKILL.md` and
report template, and returned the raw artifact in
[`raw/market-evidence-packet.md`](./raw/market-evidence-packet.md).

## Runner

| Field | Value |
|-------|-------|
| Host | Grok Build CLI 0.2.117 |
| Model | `grok-4.5-build` |
| Context | Fresh temporary working directory |
| Permissions | Read-only tools; no writes, web search, or subagents |
| Turns | 3, `end_turn` |
| Prompt | Exact `evals/cases.yaml` happy-path prompt; no grading criteria exposed |

## Grade

| Criterion | Result | Evidence |
|-----------|--------|----------|
| Separate supplied unverified notes from unavailable channels and state confidence limit | PASS | “Research mode: notes-only,” channel coverage table, and method limit cap confidence at low–medium |
| Score all six dimensions, invert competition, and show the calculation | PASS | Six scores plus `competition_fit = 6 - 4 = 2` and `(3 + 2 + 2 + 4 + 4 + 2) / 6 = 2.83` |
| Give commercial, solo-fit, and 30–90 day verdicts, one wedge, and exactly three actions | PASS | Executive verdict, sections 6–9, one labeled primary wedge, and a numbered three-item 48-hour list |
| Do not invent links, quotes, verified prices, or willingness-to-pay evidence | PASS | URLs remain `n/a`; pricing is repeatedly labeled dated/unverified; direct WTP remains absent |
| Do not recommend team-sync or enterprise build before paid/security validation | PASS | Team workspace and org sync are explicitly excluded; the wedge is local-only |

## Limitations

- This is one complete behavior case, not a five-skill Grok suite.
- It proves behavior for this host/model/version and installed-skill state only.
- A one-turn pilot correctly routed to the skill but stopped before reading the
  body; increasing the turn cap was a runner correction, not a skill revision.
- Grok emitted unrelated global plugin warnings on stderr. They did not affect
  the response and are intentionally excluded from the skill artifact.
- Claude cross-model execution was not run because the local Claude CLI had no
  authentication credential available under the gstack safety check.

Use this run together with the five-skill Codex happy-path suite, not as a
replacement for it. The next cross-host step is to run the other four happy
paths in fresh Grok sessions and then repeat representative cases in Claude.
