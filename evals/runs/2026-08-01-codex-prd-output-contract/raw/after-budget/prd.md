# PRD: Ownership-Aware Client-Onboarding Runbook

| Field | Value |
|---|---|
| **Status** | Draft |
| **Owner** | Founder / solo developer |
| **Last updated** | 2026-08-01 |
| **Version** | 0.1 |
| **Primary persona** | Operations lead or owner of a small client-services agency |
| **Platform** | Responsive web application |
| **Delivery window** | Six weeks |
| **Related evidence** | Cold smoke test: 27/300 signups and two pilot volunteers; warm traffic: 12/40 signups |

## 1. Overview

### 1.1 One-liner

A web-based client-onboarding runbook for small agencies that makes every step, owner, due state, exception, and missed handoff visible without becoming a client portal, file store, or bookkeeping system.

### 1.2 Problem statement

Small agencies often onboard clients through a mixture of spreadsheets, checklists, email, chat, and individual memory. The checklist may describe what should happen, but it does not reliably show:

- who owns each step;
- whether it is due, completed, blocked, skipped, or late;
- what exception prevented completion;
- which handoffs were missed;
- where the authoritative external record lives.

This leaves the agency operator repeatedly asking for status, manually reconstructing failures, and discovering missed steps late.

The status quo is flexible and familiar, so the MVP must beat it on accountability and recoverability—not breadth.

### 1.3 Primary job-to-be-done

> When a new client engagement begins, help me run our repeatable onboarding process with explicit ownership and due-state visibility so I can identify and recover missed handoffs before they affect the client.

### 1.4 Value proposition

For small-agency operators coordinating repeatable client onboarding, the product is an ownership-aware runbook that turns a reusable process into a traceable live run. Unlike a static spreadsheet or generic checklist, it preserves owner, due, completion, exception, reminder, and missed-step history while leaving documents and financial records in their existing systems.

### 1.5 MVP outcome

One pilot agency can define one reusable onboarding workflow, start one live client run, operate it through completion, and use its history to explain at least one completed, exceptional, or missed step without relying on a separate status spreadsheet.

### 1.6 Goals

**User outcomes**

1. Make responsibility and due state unambiguous for every onboarding step.
2. Let the operator record completion, exceptions, reminders, and missed steps with low administrative overhead.
3. Preserve a useful operational history while external records remain in their existing systems.
4. Reuse the same workflow for future onboarding runs rather than rebuilding a checklist.

**Business outcomes**

1. Determine whether two pilot volunteers will use the product on real onboarding work.
2. Observe whether ownership and missed-step history improve coordination enough to support repeat use.
3. Test willingness to pay separately; `$29/month` is a hypothesis, not a validated price.
4. Reach a clear continue, reshape, or stop decision at the end of six weeks.

### 1.7 Product principles

1. **Accountability before automation:** explicit owners and visible state are more important than automated reminders or integrations.
2. **History over mutable checkboxes:** meaningful changes remain explainable after the fact.
3. **Links, not custody:** reference external records without storing their contents.
4. **Operator-controlled:** one agency operator manages the run; step owners do not require accounts in the MVP.
5. **One complete path:** prove one workflow and one live run before adding scale or customization.

## 2. Evidence treatment

### 2.1 Observed evidence

| Cohort | Result | Treatment |
|---|---:|---|
| Cold smoke traffic | 27 signups from 300 visits: 9% | Evidence of cold-audience interest in the proposition, not usage, retention, or payment |
| Warm traffic | 12 signups from 40 visits: 30% | Directional evidence from an existing relationship or familiarity cohort; must not be pooled with cold traffic |
| Pilot intent | Two volunteers | Stronger than a signup because the volunteers accepted follow-up, but not proof of live-run completion or retention |
| Payment | No payment requested | No willingness-to-pay evidence; `$29/month` remains an assumption |

The 39 combined signups must not be reported as a single `39/340` conversion rate because warm and cold acquisition conditions differ materially.

### 2.2 Assumptions requiring validation

- **Assumption:** The primary operator is an owner, operations lead, or project manager at a roughly 2–20 person agency.
- **Assumption:** A step owner can initially be represented by a name and optional contact detail without having a product account.
- **Assumption:** CSV means export for review or backup. CSV import is migration and is excluded.
- **Assumption:** One reusable workflow and at most one active live run per workspace is sufficient for the pilot.
- **Assumption:** Manual reminders can be recorded as operational events; the system does not send email or chat messages.
- **Assumption:** A missed step is a step that becomes overdue before completion, exception, or skip—not merely a step manually marked “missed.”

## 3. Users and context

### 3.1 Primary persona

| Attribute | Detail |
|---|---|
| **Label** | Agency onboarding operator |
| **Who they are** | Owner, operations lead, or project manager responsible for coordinating new-client onboarding |
| **Environment** | Small agency using spreadsheets, email, chat, cloud documents, and possibly bookkeeping software |
| **Primary responsibility** | Ensure internal and client-dependent onboarding work happens in the right order |
| **Trigger** | A new client signs or is handed from sales into delivery |
| **Current workaround** | Duplicate a spreadsheet or checklist, assign names informally, and chase status through messages |
| **Core frustration** | The checklist shows intended work but does not preserve reliable accountability or exception history |
| **Anti-persona** | Enterprises requiring complex permissions, compliance workflows, integrations, or multi-department governance |

### 3.2 Represented participant

A step owner is a person named on a step but is not an authenticated product user in the MVP. The operator records changes and reminders on the owner’s behalf.

This is a product constraint, not an enterprise role model.

### 3.3 Use context

The primary experience is desktop web during operational work. Basic responsive usability is required, but no native mobile application or mobile-specific workflow is included.

## 4. Scope

| In scope: P0 | Out of scope |
|---|---|
| One reusable workflow | Client or owner portals |
| Ordered, reusable steps | File upload, document storage, previews, or attachments |
| One active live onboarding run | CSV import or historical migration |
| Explicit owner per run step | Email, Slack, CRM, accounting, storage, or calendar connectors |
| Due dates and derived due states | Automated reminders or notifications |
| Completion, exception, and skip handling | AI generation, recommendations, or summaries |
| Manual reminder logging | Bookkeeping, invoices, contracts, payment tracking, or financial reconciliation |
| External record links | Native mobile applications |
| CSV export | Enterprise roles, SSO, approval chains, or granular permissions |
| Missed-step and event history | Compliance certification, regulated-data workflows, or policy management |
| Basic workspace access | Multiple simultaneous workflows or active runs |

Sensitive documents and bookkeeping records remain in systems chosen by the agency. The MVP stores only operational metadata and user-supplied external URLs.

## 5. P0 user journeys and states

### Journey A — Create the reusable workflow

1. The operator creates the workspace’s single workflow.
2. The operator names the workflow and adds ordered steps.
3. Each step receives a title and optional guidance.
4. The operator reorders, edits, or removes steps before starting the run.
5. The operator saves the workflow for reuse.

**Success state:** The workflow has at least one valid step and can start a live run.

**Failure/recovery:** Invalid or incomplete steps are identified inline without discarding valid edits.

### Journey B — Start and operate a live run

1. The operator starts a run from the saved workflow.
2. The operator enters a client/run label and start date.
3. The system snapshots the workflow steps into the run.
4. The operator assigns an owner and due date to each run step.
5. The operator reviews the run by status and due state.
6. The operator completes steps or records exceptions as work progresses.

**Success state:** Every actionable step has a visible owner, status, and due state.

**Failure/recovery:** If an owner or due date is missing, the step remains visibly “Needs setup” and cannot be mistaken for ready work.

### Journey C — Chase and recover a missed handoff

1. The system identifies an open step whose due date has passed.
2. The step becomes overdue and receives a missed-step history event once.
3. The operator contacts the owner outside the product.
4. The operator logs when and how the reminder occurred, with an optional note.
5. The owner’s work is later completed, skipped, or placed in exception.
6. The history continues to show that the step was previously missed.

**Success state:** The operator can explain the missed handoff and its resolution from the run history.

**Failure/recovery:** Repeated page loads do not create duplicate missed-step events.

### Journey D — Reference and export the record

1. The operator adds an HTTPS link to the authoritative external record for a step.
2. The product labels the link without copying or previewing the external content.
3. The operator opens the record in a new browser context when needed.
4. The operator exports the live run as CSV.
5. The CSV contains current operational state and stable identifiers.

**Success state:** The operator can review or share structured run data without exporting sensitive file contents.

**Failure/recovery:** Invalid URLs are rejected clearly; export failure does not alter the run.

### 5.1 State model

A run step has one primary status:

- `needs_setup`: owner or due date is missing;
- `not_started`: configured but work has not begun;
- `in_progress`;
- `completed`;
- `exception`: blocked or deviating from the standard process, with a required reason;
- `skipped`: intentionally not required, with a required reason.

Due state is derived separately:

- `no_due_date`;
- `upcoming`;
- `due_today`;
- `overdue`;
- `resolved`.

A completed, exception, or skipped step is resolved. An overdue step retains its missed-step event even after resolution.

A run is:

- `draft`;
- `active`;
- `completed`;
- `archived`.

The run can become `completed` only when every step is resolved.

## 6. Functional requirements

| ID | Requirement | Priority | Acceptance criteria |
|---|---|---:|---|
| **FR-001** | The operator can create and edit one reusable workflow containing ordered steps. | P0 | A workflow requires a name and at least one titled step. Steps can be added, edited, removed, and reordered. Saving and reopening preserves order. The UI prevents creation of a second workflow. |
| **FR-002** | The operator can start one live run from the workflow. | P0 | Starting a run requires a client/run label and start date. The system snapshots the current ordered steps. Later workflow edits do not silently alter the existing run. A second active run cannot be started while one is active. |
| **FR-003** | Every run step supports an explicit owner and due date. | P0 | The operator can set and change an owner display name and due date. A step missing either is visibly `needs_setup`. Owner and due-date changes create timestamped history events containing previous and new values. |
| **FR-004** | The system presents current status and derived due state. | P0 | Each step displays its primary status plus due state. Open steps become `due_today` on their due date and `overdue` after it, using the workspace timezone. Resolved steps display `resolved`. |
| **FR-005** | The operator can update progress and complete a step. | P0 | A configured step can move between `not_started` and `in_progress`, then to `completed`. Completion records timestamp and acting operator. Reopening requires confirmation and records a history event. |
| **FR-006** | The operator can record exceptions and intentional skips. | P0 | Moving a step to `exception` or `skipped` requires a non-empty reason. The reason, timestamp, and acting operator appear in history. The operator can later resolve an exception as completed without losing the exception event. |
| **FR-007** | The system preserves missed-step history. | P0 | The first time an unresolved step passes its due date, exactly one `became_overdue` event is recorded. Completing, skipping, changing the due date, or reopening the step does not erase it. Current state and historical miss are distinguishable. |
| **FR-008** | The operator can record manual reminders. | P0 | A reminder entry requires a step, date/time, and channel chosen from email, chat, phone, meeting, or other; note is optional. Logging a reminder does not send a message. Each reminder appears in step and run history. |
| **FR-009** | Steps can reference external records by URL. | P0 | The operator can add, edit, open, and remove a labeled `https://` URL. The system does not fetch, copy, index, or preview the destination. URLs or labels resembling secrets trigger cautionary copy but are not logged beyond the saved field. |
| **FR-010** | The operator can export the run as CSV. | P0 | Export includes run ID/label, step ID/order/title, owner, due date/state, current status, completion time, exception/skip reason, external link, last reminder time, and whether the step was ever overdue. It excludes external file contents and credentials. Export does not mutate data. |
| **FR-011** | The operator can inspect chronological history. | P0 | Run-level history can be filtered to a step and shows creation, owner/due changes, state transitions, exceptions, skips, reminders, external-link changes, and overdue events in stable chronological order. Historical events cannot be edited through normal UI. |
| **FR-012** | The operator can complete and archive the live run. | P0 | Completion is available only when all steps are resolved. Completion records a timestamp. The completed run remains readable and exportable; archiving removes it from the default operational view without deleting history. |
| **FR-013** | The product exposes upgrade interest without charging. | P1 | After meaningful pilot use, the operator may indicate whether they would pay `$29/month` and why. No card, checkout, or claim of validated pricing is present in the six-week P0. |
| **FR-014** | The operator can duplicate a completed run from the workflow. | P1 | When no run is active, a new run can be started from the current workflow while the previous completed run remains readable. This may be deferred if it threatens P0 pilot completion. |

## 7. Non-functional and data-boundary requirements

| ID | Requirement | Priority | Acceptance criteria / validation |
|---|---|---:|---|
| **NFR-001** | Sensitive-file storage is prohibited. | P0 | No upload, attachment, blob-storage, file-preview, or file-content ingestion endpoint exists. A repository and route review confirms this before pilot launch. |
| **NFR-002** | Bookkeeping data remains outside the product. | P0 | No invoice, payment, bank, tax, accounting-ledger, contract-value, or financial reconciliation fields exist in the P0 model or UI. External bookkeeping records may only be referenced by URL. |
| **NFR-003** | Agency data is isolated by workspace. | P0 | Automated tests attempt cross-workspace reads and writes for workflows, runs, steps, and history and receive no data. All server-side record access is scoped to the authenticated workspace. |
| **NFR-004** | History is append-only through product behavior. | P0 | State-changing integration tests verify that a new event is added and earlier events remain unchanged. No normal application route permits event update or deletion. |
| **NFR-005** | Core operator flows are keyboard-accessible and clearly labeled. | P0 | Workflow editing, run setup, state changes, reminder logging, link entry, and CSV export can be completed with keyboard navigation; automated accessibility checks report no critical violations on P0 pages. |
| **NFR-006** | Common operational views remain responsive for MVP-scale data. | P0 | With 100 steps and 1,000 history events, workflow, run, and history views reach usable state within two seconds at the 75th percentile in a production-like test. |
| **NFR-007** | Dates are interpreted consistently. | P0 | Workspace timezone is stored explicitly and displayed on due-date and history views. Boundary tests cover due today, post-midnight overdue transition, and daylight-saving changes where applicable. |

## 8. UX and content notes

### 8.1 Information architecture

- Sign in / workspace setup
- Workflow editor
- Start-run setup
- Live run overview
- Step detail and event history
- Run history
- Export action
- Minimal pilot feedback prompt

### 8.2 Critical empty, error, and permission states

- **No workflow:** Explain that the first task is to encode the agency’s repeatable onboarding steps.
- **Workflow has no steps:** Disable starting a run and identify the missing requirement.
- **Needs setup:** Surface missing owner or due date directly on the step.
- **No active run:** Offer “Start onboarding run” only when a valid workflow exists.
- **Overdue:** Show both present status and the fact that the step crossed its deadline.
- **Invalid external link:** Retain entered label, identify URL requirements, and avoid silent loss.
- **Export failure:** Offer retry; do not mark the run or any step as changed.
- **Attempted second workflow/run:** Explain the pilot limitation rather than implying a technical error.
- **Unauthorized workspace access:** Return no resource details and provide a safe navigation path.

### 8.3 Copy-critical moments

- **Workflow empty state:** “Turn the onboarding process you already use into repeatable, owned steps.”
- **External link helper:** “Link to the authoritative record. Do not paste passwords, access tokens, or sensitive file contents.”
- **Reminder action:** “Log reminder”—never “Send reminder.”
- **Overdue history:** “This step passed its due date while unresolved.”
- **Pricing prompt:** “Would this be worth `$29/month` to your agency?” Responses are research, not payment validation.

## 9. Data concepts and boundaries

### 9.1 Core entities

| Entity | Purpose | Conceptual fields |
|---|---|---|
| **Workspace** | Isolates one agency | ID, name, timezone, created time |
| **Operator** | Authenticated pilot user | ID, workspace ID, display name, authentication reference |
| **Workflow** | Reusable onboarding definition | ID, workspace ID, name, version/update time |
| **WorkflowStep** | Ordered reusable step | ID, workflow ID, order, title, guidance |
| **Run** | Client-specific execution snapshot | ID, workspace ID, workflow reference/version, client/run label, start date, state, completion time |
| **RunStep** | Operational copy of a workflow step | ID, run ID, order/title snapshot, owner, due date, status, resolution data |
| **ExternalLink** | Pointer to authoritative external record | ID, run-step ID, label, HTTPS URL |
| **ReminderEvent** | Record of an off-product reminder | ID, step ID, channel, note, occurred time, operator |
| **HistoryEvent** | Append-only operational audit trail | ID, run/step ID, event type, safe change summary, occurred time, operator |

### 9.2 Stored versus excluded data

**Stored**

- Agency/workspace identifiers
- Operator identity required for access
- Workflow and run metadata
- Owner names and optional operational contact labels
- Due dates, states, exception/skip reasons
- Reminder notes
- External URLs
- Append-only history

**Explicitly excluded**

- Uploaded files or copied document contents
- Passwords, API keys, tokens, or authentication material for linked services
- Bookkeeping ledgers, invoices, bank details, payment records, or tax records
- Client portal credentials
- Regulated-data or compliance-specific classifications

The product should minimize personal data in reminder notes and exception reasons. Compliance guarantees are not part of the MVP.

### 9.3 Integrations

No third-party connector is P0. Authentication and basic hosting infrastructure are product foundations, not agency workflow integrations. CSV is generated directly by the product; it is not a spreadsheet connector.

## 10. Metrics, decision rules, and kill triggers

Targets below are founder-set validation thresholds, not conclusions from existing evidence.

| Metric | Definition | Six-week signal |
|---|---|---|
| **Pilot activation** | Volunteer creates a valid workflow and starts a real live run | Both volunteers activate |
| **Operational adoption** | Active run has at least 80% of steps assigned an owner and due date | At least one pilot achieves this within two working days |
| **Run completion** | Real live run reaches completed state with all steps resolved | At least one of two pilots completes a run |
| **Accountability use** | Pilot records or encounters at least one reminder, exception, skip, or overdue event and later consults history | Observed in at least one real run |
| **Return use** | Operator returns on three distinct days during the run | At least one pilot |
| **Pricing evidence** | Explicit `$29/month` response after meaningful use | Record separately as yes/no/conditional; do not count signup intent as payment |

### Kill or pivot triggers

At the end of week six:

- **Stop or radically reshape** if neither volunteer starts a real run after assisted onboarding and one follow-up.
- **Stop building product breadth** if both pilots operate the run mainly outside the product because updating owners or state is too burdensome.
- **Reframe the wedge** if pilots use the checklist but neither consults reminder, exception, overdue, or history features; ownership-aware recovery may not be the differentiator.
- **Do not implement billing** if no activated pilot expresses credible willingness to pay after use. A polite “sounds reasonable” is insufficient; seek a concrete commitment such as agreeing to a paid continuation date.
- **Continue toward a paid beta** if at least one real run completes, the operator returns on three days, accountability history is used, and at least one pilot makes a concrete paid-continuation commitment.
- **Investigate before deciding** if operational value is clear but `$29/month` is rejected; this distinguishes pricing failure from product failure.

Cold and warm acquisition metrics remain separate in every report. Further cold testing should compare like-for-like traffic and creative.

## 11. Risks, edge cases, and founder decisions

| Risk or edge case | Impact | Mitigation |
|---|---|---|
| Owners cannot update their own steps | Operator becomes a bottleneck | Accept for the pilot; measure update burden before considering owner access |
| Manual reminders are mistaken for automated delivery | Loss of trust | Use “log” language everywhere and show no delivery status |
| Changing the workflow corrupts a live run | History becomes unreliable | Snapshot workflow steps when a run starts |
| Due date changes hide a missed deadline | Accountability is weakened | Preserve the first overdue event permanently |
| Sensitive information is pasted into notes or links | Privacy exposure | Warning copy, minimal fields, no previews/fetching, and founder onboarding guidance |
| One-workflow/run constraint blocks normal pilot use | Pilot cannot finish evaluation | Recruit agencies willing to test one onboarding at a time; treat demand for concurrency as evidence for P1 |
| CSV grows into migration support | Six-week scope expands | Export only; explicitly reject import files |
| High-touch pilot support masks poor usability | False activation signal | Record assistance required and distinguish assisted from independent completion |
| `$29/month` anchors feedback prematurely | Distorts discovery | Ask only after meaningful use and capture objections verbatim without presenting price as final |

**Open founder decisions**

1. Whether owner contact information is needed at all, or whether display name alone is sufficient.
2. Whether a step in `exception` counts as resolved immediately or remains open until explicitly resolved. This PRD recommends that `exception` is resolved for run completion but remains prominent in history.
3. Whether a pilot may retain multiple completed runs during the MVP. This PRD recommends yes, while allowing only one active run.
4. What qualifies as a concrete payment commitment if checkout is intentionally excluded.

## 12. Six-week solo-developer milestones

| Week | Outcome | Exit criteria |
|---|---|---|
| **Week 1 — Model and interaction spike** | Validate the state model and thin architecture with pilot examples | Workflow/run snapshot, due-state rules, append-only events, and no-file boundary are represented in executable tests or a working spike |
| **Week 2 — First vertical slice** | One owned step can travel through the complete product path | Operator creates a one-step workflow, starts a run, assigns owner/due date, completes the step, and sees the event in history using persisted data |
| **Week 3 — Full P0 run operation** | Multi-step workflow and run states work end to end | Reordering, setup gaps, progress, completion, exception, skip, run completion, and reopening behavior pass acceptance tests |
| **Week 4 — Accountability and boundaries** | Misses and off-product coordination become traceable | Overdue event generation is idempotent; reminder logging, external links, CSV export, workspace isolation, and prohibited-storage checks pass |
| **Week 5 — Pilot hardening** | Two volunteers can attempt real onboarding | Accessibility pass, performance validation, recovery states, analytics, guided onboarding, and production-like smoke test are complete |
| **Week 6 — Live pilot and decision** | Obtain behavioral and pricing evidence | Pilot activity is observed, assistance is logged, metrics are reviewed separately from smoke signups, and continue/reshape/stop decision is recorded |

### First vertical slice

Build this before dashboards, polished workflow editing, or CSV:

1. Authenticate one operator into one workspace.
2. Create and persist one workflow containing one step.
3. Start one run by snapshotting that step.
4. Assign an owner and due date.
5. Mark the step completed.
6. Display the append-only sequence: run created → owner assigned → due date assigned → completed.
7. Reload the application and verify current state and history remain intact.
8. Verify a different workspace cannot access the run.

This slice tests the product’s central promise: a reusable instruction becomes owned work with trustworthy history.

### Build-versus-buy guidance

Use managed authentication, hosting, database, and basic telemetry appropriate to the existing project stack. Build the workflow/run state model and history because they contain the product’s differentiation. Do not build messaging, file handling, spreadsheet parsing, or billing infrastructure during the pilot.

### Support burden controls

- Offer one structured onboarding session per pilot.
- Record every point at which the founder must intervene.
- Avoid bespoke workflow configuration performed only by the founder.
- Route feedback through one channel and tag it as bug, usability problem, missing P0 behavior, or later request.

## 13. Launch and feedback

**Beta audience:** The two existing pilot volunteers first. Additional participants should come from cold acquisition where possible and remain labeled by source.

**Pilot cadence:**

1. Before use: capture the existing onboarding checklist and current coordination method.
2. During setup: observe without redesigning the workflow for the participant.
3. During the run: review events and assistance required, not just self-reported satisfaction.
4. After completion or abandonment: ask what moved back to spreadsheets/chat and why.
5. Only after meaningful use: ask for a concrete `$29/month` continuation decision.

No production deployment, billing activation, or broader launch is implied by this PRD.

## 14. Evidence handoff

| Field | Value |
|---|---|
| **Current decision** | Build a six-week, pilot-only MVP bounded to one reusable workflow and one active live run; decide continue, reshape, or stop from observed real-run behavior before expanding scope. |
| **Evidence classes** | observed experiment; primary behavior; assumption |
| **Supported claims** | Cold messaging generated 27 signups from 300 visits; warm traffic generated 12 from 40; two people volunteered for pilots; the proposition warrants a bounded pilot. |
| **Still unproven** | Real workflow activation, sustained use, run completion, whether ownership/history improves outcomes, independent usability, retention, willingness to pay, and whether `$29/month` is viable. Detailed P0 behaviors are build requirements, not validated demand. |
| **Contradictions / exclusions** | Warm and cold results cannot be pooled; no payment was requested; signup and volunteer intent are not retention or revenue. Excluded: portals, file storage, migration/import, connectors, AI, mobile, enterprise roles, bookkeeping, and compliance scope. |
| **Source anchors** | User-provided cold smoke result `27/300`; warm result `12/40`; two pilot volunteers; stated P0 list; stated exclusions; FR-001–FR-012; NFR-001–NFR-007. |
| **Next validation** | Founder runs the first real onboarding with both volunteers by week six. Accept the wedge if at least one completes a run, returns on three distinct days, uses accountability history, and makes a concrete paid-continuation commitment; otherwise apply the kill/pivot rules above. |

---

Postscript outside the PRD:

Three decisions to confirm:

1. “One live run” means one active run at a time, while completed runs remain readable.
2. CSV is export-only; import is excluded as migration.
3. Step owners are represented people, not authenticated users.

The best first implementation slices are the workflow/run snapshot, owned-step completion with append-only history, then overdue/reminder recovery.

No additional broad market validation is required before the bounded pilot. Pricing should go back through targeted validation after pilots have experienced meaningful product use.