# Codex cross-skill output-contract regression

## Outcome

- **Before fix: FAIL, 0/4 cases (8/20 criteria).** All four skills produced
  useful domain artifacts and generally kept their evidence boundaries, but
  none emitted the fixed seven-field Evidence handoff interface.
- **After fix: PASS, 4/4 cases (20/20 criteria).** With identical prompts,
  model, host, permissions, reasoning effort, and execution controls, every
  artifact contains one complete table and a canonical class-only cell while
  retaining its domain-specific evidence limits.

## Case results

| Case | Before | After | Before defect | After evidence classes |
|------|:------:|:-----:|---------------|------------------------|
| market-output-contract | 2/5 FAIL | 5/5 PASS | Split `Contradictions` and `Excluded directions`; used a prose classification instead of canonical values | `assumption` |
| discovery-output-contract | 2/5 FAIL | 5/5 PASS | Replaced the table entirely with skill-specific downstream prose | `primary behavior` |
| landing-output-contract | 2/5 FAIL | 5/5 PASS | Renamed rows into result/metric fields and omitted canonical classes | `assumption` |
| seo-output-contract | 2/5 FAIL | 5/5 PASS | Merged risks and handoff into free text | `search signal / assumption` |

For each before-fix run, the two passing criteria were preservation of the
skill's substantive evidence boundary and absence of evidence upgrading. The
three interface criteria failed: exact seven-row table, canonical class cell,
and no custom/prose substitute. Every after-fix run passed all five.

## Semantic checks after the fix

- **Market:** supplied notes remain unverified assumptions; native substitutes,
  admin blocking, and absent payment remain explicit; the next test requires
  observed use and paid authorization.
- **Discovery:** summary-only and N=5 limits remain visible; compliments and CSV
  preference are not purchase evidence; the next step is one real concierge
  pilot with behavior and scarce-resource commitments.
- **Landing:** result-dependent rows use `TBD after test`; warm/cold cohorts,
  provider confirmation, invalid attempts, attribution exports, payment, and
  retention remain distinct.
- **SEO:** supplied search notes remain directional; volume, difficulty,
  rankings, traffic, conversion, payment, retention, and PMF remain unproven;
  the next validation uses GSC and a meaningful 28-day observation window.

## Change justified by the failed matrix

`z-market-validate`, `z-customer-discovery`, `z-landing-smoke`, and
`z-seo-plan` now define the handoff as a fixed runtime interface. Each names the
seven immutable labels, limits the class cell to applicable canonical names,
and tells the agent where domain-specific provenance or metric qualifiers
belong. Delivery instructions and quality bars repeat the observable boundary.

The generic scaffold now starts with the same fixed-interface rule, and
`doctor.sh` rejects any active skill that drops it. Four new output-contract
cases reuse the established happy-path prompts intentionally, so historical
content-quality grades remain unchanged.

## Reproducibility notes

All eight runs used Codex CLI 0.146.0 with `gpt-5.6-sol`, medium reasoning,
read-only sandboxing, approval policy `never`, no web search, disabled subagents,
one user turn, a separate initialized disposable Git workspace per run, and an
ephemeral session. The four cases in each phase ran concurrently; every Codex
process exited successfully after writing its final response.

All runs emitted state-database fallback messages, a Cloudflare MCP OAuth
`invalid_grant` warning, and a skill-description context-budget warning. No run
invoked Cloudflare or any other MCP connector. Raw files are the verbatim final
messages written by `--output-last-message`; CLI preambles and session
identifiers are not included.
