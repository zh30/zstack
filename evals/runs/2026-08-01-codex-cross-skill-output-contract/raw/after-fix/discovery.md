Mode: synthesize

## Discovery synthesis — client onboarding

| Field | Value |
|---|---|
| Date | 2026-08-01 |
| N completed | 5 |
| Cold / warm mix | 4 cold / 1 warm; role-level attribution was not supplied |
| Sample | Agency PM, consultant, founder, bookkeeper, marketer |
| Working ICP | People responsible for recurring client-onboarding workflows across multiple tools |
| Evidence limit | Summary-level primary evidence; no transcripts or verbatim quotes |

### Evidence audit

| Source anchor | G1 Pain | G2 Spend | G3 Switch | Audit notes |
|---|---|---|---|---|
| S1 Agency PM | Support — repeated 45-minute copying workflow | Support — time plus Zapier spend | Support, with caveat — abandoned a template and requested a pilot | Strongest prospect. Pilot request is promising but remains future intent until resources are committed. |
| S2 Consultant | Neutral — assistant use suggests workload, but no incident or frequency was supplied | Support — pays an assistant | Contradict/barrier — migration was explicitly named | Existing spend is real; willingness and feasibility to switch are not. |
| S3 Founder | Contradict — no recent pain | Contradict — no spend | Neutral — compliment only | Exclude the compliment from demand evidence. This interview may contain pitch leakage. |
| S4 Bookkeeper | Support — failures happen weekly | Support — paid VA labor | Contradict/barrier — sensitive-file concerns | Strong pain and spend, but adoption may require a security-heavy product unsuitable for the first wedge. |
| S5 Marketer | Neutral — no concrete failure or cost was supplied | Neutral — uses free automation | Support — has switched tools before; CSV request is weak supporting detail | Past switching matters. “Wants CSV” is a preference, not proof of adoption. |

The summaries do not reveal the questions asked, so leading-question and future-tense violations cannot be fully audited. Two responses appear exposed to solution discussion: the founder’s pitch compliment and possibly the PM’s pilot request. Neither is upgraded beyond its behavioral weight.

## Segments observed

| Segment | Who | N | Implication |
|---|---|---:|---|
| Bleeding and paying a cost | Agency PM, bookkeeper | 2 | Best evidence of demand, but they have different trust and compliance needs. |
| Paying workaround; pain detail incomplete | Consultant | 1 | Follow up on the last onboarding, assistant hours, and consequences before including this segment. |
| Bleeding, not paying | None established | 0 | Free automation alone does not prove pain. |
| Workflow-active; pain unproven | Marketer | 1 | Useful switching evidence, but not yet evidence for the pain proposition. |
| Polite only | Founder | 1 | Anti-ICP unless later behavior contradicts this interview. |

## Cross-interview patterns

### G1 — Pain

- The agency PM has a concrete recurring 45-minute manual workflow.
- The bookkeeper experiences weekly failures.
- The remaining three interviews do not establish recent, frequent pain.
- The supported problem is therefore narrower than “client onboarding”: recurring, multi-tool operational handoffs with measurable manual labor or failures.

### G2 — Existing spend

- Agency PM: Zapier plus staff time.
- Consultant: paid assistant.
- Bookkeeper: paid VA labor.
- Three of five already absorb monetary or labor costs, although the consultant’s underlying pain needs clarification.
- The marketer’s free setup and founder’s lack of spend are material counterexamples.

### G3 — Switching

Positive evidence:

- Agency PM abandoned an attempted template and requested a pilot.
- Marketer has switched tools before.

Barriers:

- Unclear ownership caused one prior solution to fail.
- Migration blocks the consultant.
- Sensitive files block or complicate the bookkeeper.
- CSV portability matters to the marketer, but the request alone is not commitment.

The emerging requirement is not merely automation. A viable wedge must make ownership explicit and reduce migration risk; targeting sensitive financial files initially would add substantial trust friction.

## Gate scores

| Gate | Score | Confidence | Rationale |
|---|---:|---|---|
| G1 Pain | 3/5 | Medium | Two strong behavioral cases, one incomplete case, and two interviews without demonstrated pain. A plausible segment exists, but the pattern is not stable across the broad sample. |
| G2 Spend | 4/5 | Medium | Three independent respondents already pay through software or labor. Exact amounts and budget ownership are missing. |
| G3 Switch | 3/5 | Medium-low | One past switch and one requested pilot are encouraging, but migration, ownership, and sensitive-data barriers are prominent. No completed switch, payment, or data commitment exists yet. |

Confidence is capped because N=5 is small, the sample spans materially different roles, warm/cold attribution by respondent is unknown, and only summaries—not transcripts—were provided.

## Decision

**Verdict: Reshape**

Do not build a general client-onboarding product yet. The evidence supports reshaping toward:

> Agency PMs who repeatedly copy onboarding information across tools, already pay for automation, and need one clearly owned workflow with low-risk CSV-based adoption.

The bookkeeper should not define the initial product: the pain and spend are real, but sensitive-file handling creates a distinct security and trust burden. Keep that segment for later validation. The founder is an exclusion; the marketer and consultant require stronger pain evidence.

### Concrete next move

Run the requested agency PM pilot before a broad landing-page test.

Pilot scope:

- One real onboarding workflow.
- One source and one destination integration, or CSV import/export if that lowers migration friction.
- Named owner for every handoff and exception.
- No sensitive financial-file ingestion.
- Manual operations behind the scenes are acceptable.
- Measure baseline and pilot completion time, failures, and human interventions.

Decision threshold:

- **Advance:** The PM schedules kickoff, provides a real sanitized dataset or system access, identifies the workflow owner, runs at least three onboardings, and commits money or another meaningful scarce resource if the pilot materially reduces the 45-minute workflow.
- **Fail/reshape again:** The PM will not provide data, access, owner time, or a scheduled workflow; usage repeatedly requires sensitive-file handling; or three runs fail to produce measurable savings.
- **After pilot success:** Hand the demonstrated workflow and measured result to `z-landing-smoke`, then scope only the validated path with `z-write-prd`.

No verbatim copy bank can be produced from these summaries. Downstream messaging must use attributed paraphrases or collect exact language in the pilot follow-up.

## Evidence handoff

| Field | Value |
|---|---|
| Current decision | Reshape |
| Evidence classes | primary behavior |
| Supported claims | A narrow operational segment experiences recurring manual onboarding work; three respondents already bear software or labor costs; ownership, migration, portability, and sensitive-file handling affect adoption. |
| Still unproven | Segment prevalence, exact willingness to pay, budget ownership, successful migration, sustained use, retention, integration requirements, and whether the requested pilot will convert into committed behavior. |
| Contradictions / exclusions | Founder had no recent pain or spend; marketer’s pain was not established; consultant named migration as a barrier; bookkeeper raised sensitive-file concerns; compliments, the CSV preference, and an uncommitted pilot request are not purchase evidence. |
| Source anchors | User-supplied summaries: S1 agency PM, S2 consultant, S3 founder, S4 bookkeeper, S5 marketer. No transcripts or verbatim quotes were supplied. |
| Next validation | Founder runs one agency-PM concierge pilot. Success requires scheduled kickoff, real workflow access or sanitized data, a named owner, at least three completed onboardings, measurable improvement over the 45-minute baseline, and a money or scarce-resource commitment; absence of those behaviors fails the hypothesis. |

The workspace is read-only, so I could not persist this as `docs/discovery/synthesis.md` and `decision.md`.