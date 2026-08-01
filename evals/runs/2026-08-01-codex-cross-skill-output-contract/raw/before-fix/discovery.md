Mode: synthesize

**Verdict: Advance — but only to a narrow, assisted pilot, not a broad MVP.**

The workspace is read-only, so I could not save `docs/discovery/synthesis.md` and `decision.md`. Their complete contents follow.

# Discovery synthesis

## Method limits

- Five interviews meet the minimum synthesis threshold, with a healthy 4 cold / 1 warm mix.
- The summaries do not identify which interview was warm, so that bias cannot be isolated.
- Roles are heterogeneous; this supports pattern detection, not market sizing or a universal client-onboarding product.
- No transcripts, dates, exact costs, or verbatim quotes were supplied. Nothing below should be presented as customer quotation.
- Questions are unavailable, so leading-question and pitch-leakage audits cannot be completed.
- A pilot request remains intent until the prospect commits time, data, access, or money.

## Evidence audit

| ID | Interview | G1 Pain | G2 Spend | G3 Switch | Audit |
|---|---|---|---|---|---|
| S1 | Agency PM | Support | Support | Support | Repeated 45-minute copying, Zapier spend, abandoned template, and pilot request. Strongest evidence, though cadence and pilot commitment remain unspecified. |
| S2 | Consultant | Neutral | Support | Neutral | Paying an assistant is behavioral spend. No recent incident or frequency supplied. Migration is a documented barrier, not proof of switching. |
| S3 | Founder | Contradict | Contradict | Contradict | No recent pain, workaround, or spend. Compliment is excluded as demand evidence. |
| S4 | Bookkeeper | Support | Support | Neutral | Weekly failures and paid VA labor strongly support pain and spend. Sensitive files make switching feasibility uncertain. |
| S5 | Marketer | Neutral | Contradict | Support | Uses free automation, with no concrete failure supplied. Past tool switching is behavioral evidence; wanting CSV is a requirement, not commitment. |

## Segments

| Segment | Who | N | Implication |
|---|---|---:|---|
| Bleeding and paying | Agency PM, bookkeeper | 2 | Core opportunity: recurring operational work with measurable labor/tool costs. |
| Paying workaround, pain insufficiently documented | Consultant | 1 | Relevant adjacent prospect; obtain a recent onboarding story before including in the ICP. |
| Switch-capable, not paying | Marketer | 1 | Useful for portability research, but weak monetization evidence. |
| Polite only | Founder | 1 | Anti-ICP for now; exclude compliments from demand calculations. |

## Patterns

### G1 — Pain

- Two strong recurring examples: repeated 45-minute copying and weekly failures.
- Paid assistant labor suggests another operational burden, but the summary lacks a concrete incident.
- The marketer and founder do not establish recent pain.

The supported pain is therefore **recurring cross-tool operational work**, not “client onboarding” broadly.

### G2 — Existing spend

Three participants already absorb costs through:

- Zapier plus manual PM time.
- A paid assistant.
- Paid VA labor.

This is meaningful behavioral evidence. It does not establish a software price point because amounts, budgets, and purchasing authority are unknown.

### G3 — Switching

Positive signals:

- One prior tool switch.
- One abandoned alternative.
- One request for a real pilot.

Material barriers:

- Migration effort.
- Unclear workflow ownership.
- CSV portability.
- Sensitive-file handling.

These barriers imply that a self-serve “connect everything” product is premature. Adoption probably requires assisted setup, clear ownership, reversible import/export, and carefully bounded data handling.

## Gate scores

| Gate | Score | Confidence | Reason |
|---|---:|---|---|
| G1 Pain | **3/5** | Medium | Two strong recurring cases, one indirect case, and two weak/negative cases across a heterogeneous sample. |
| G2 Spend | **4/5** | Medium | Three independent participants already pay with software or labor. Exact costs and budget ownership remain unknown. |
| G3 Switch | **3/5** | Low | Past switching, an abandoned alternative, and a pilot request are promising, but no completed migration, committed pilot, or payment exists yet. |

# Decision

## Advance

Advance to a **concierge design-partner pilot for agency PMs who repeatedly transfer new-client information across tools**.

Do not yet:

- Build a generalized onboarding platform.
- Promise bookkeeping-grade sensitive-file handling.
- Claim that assistants or VAs can be replaced.
- Assume CSV preference proves purchase intent.
- Treat the founder’s compliment as evidence.
- Invest in deep integrations before observing one live workflow.

## Immediate validation

**Owner:** Founder  
**Next action:** Convert the agency PM’s request into one live, assisted pilot within seven days.

Require the PM to:

1. Schedule a kickoff.
2. Show the current workflow and affected tools.
3. Assign the person responsible for each handoff.
4. Run one real client onboarding through the pilot.
5. Agree in advance to discuss payment after the first completed run.

**Advance signal:**

- Access to a real workflow is provided.
- At least one onboarding completes successfully.
- Manual work falls from 45 minutes to 20 minutes or less.
- The PM repeats it for a second client or makes a concrete payment commitment.

**Failure signal:**

- The PM will not schedule, provide a real case, or assign ownership.
- Migration/setup costs more effort than the workflow saves.
- They revert after one run.
- No repeat use or financial commitment follows.

# Downstream handoff

## For `z-landing-smoke`

- **ICP:** Agency PMs handling recurring client onboarding across multiple tools who already pay for automation or manual operations.
- **Trigger:** A new client requires the same information to be copied into several systems.
- **Offer:** Assisted pilot that maps ownership, moves the onboarding data, and preserves a CSV exit path.
- **CTA:** “Bring one real onboarding workflow.”
- **Primary proof to test:** Whether cold agency PMs surrender time and workflow access—not whether they join a waitlist.
- **Excluded segment:** Founders without recent onboarding pain or current spend.

Possible evidence-derived copy, explicitly **not customer quotations**:

- Reduce repetitive cross-tool client setup.
- Keep ownership clear at every handoff.
- Start with assisted migration.
- Preserve a CSV export path.
- Pilot it on one real client before changing the whole workflow.

No “top five customer phrases” can be supplied because the source contained no verbatim language.

## For a later `z-write-prd`

Scope only:

- One narrowly defined onboarding workflow.
- Assisted configuration.
- Explicit field and step ownership.
- CSV import/export and rollback.
- Time-saved instrumentation.
- Minimal access to sensitive files.

Keep as non-goals:

- Universal integrations.
- Autonomous migration.
- Bookkeeping or compliance claims.
- Replacing assistants or VAs.
- Support for every role represented in this sample.

The central unresolved question is G3: **will the strongest prospect actually move a live workflow, repeat it, and commit money?** That real pilot should come before meaningful product construction.