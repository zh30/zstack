# PRD: Ownership-Aware Client Onboarding Runbook

| Field | Value |
|---|---|
| **Status** | Draft for review |
| **Owner** | Solo founder/developer |
| **Last updated** | 2026-08-01 |
| **Version** | 0.1 |
| **Primary persona** | Small-agency operator responsible for coordinating client onboarding |
| **Platform** | Desktop-first responsive web application |
| **Delivery constraint** | Six-week solo-developer MVP |
| **Related evidence** | User-provided discovery and smoke-test summary |

## Revision history

| Version | Date | Summary |
|---|---|---|
| 0.1 | 2026-08-01 | Initial build-ready MVP PRD |

---

## 1. Overview

### 1.1 One-liner

A lightweight web runbook for small agencies to turn a reusable client-onboarding workflow into one accountable live run, with explicit owners, due states, exceptions, reminders, external links, CSV handling, and durable missed-step history.

### 1.2 Problem statement

Small agencies often coordinate onboarding through spreadsheets, task tools, email, and memory. A checklist may describe what should happen, but it frequently fails to make three things visible:

- Who owns each step.
- What is due, late, complete, or blocked.
- What was missed, including after someone later completes the step.

The result is follow-up work for the agency operator, inconsistent onboarding, and preventable omissions. General-purpose project-management tools can represent tasks, but require configuration and do not necessarily preserve an onboarding-specific operational history.

Sensitive file storage and bookkeeping are adjacent jobs, not part of this product. The MVP should link to records held elsewhere rather than becoming another document repository or financial system.

### 1.3 Evidence treatment

Evidence must remain separated by source and audience temperature.

| Evidence | Classification | What it supports | What it does not support |
|---|---|---|---|
| Discovery supports explicit owners, reusable steps, external record links, and CSV | Primary behavior, based on the supplied discovery summary | These capabilities are credible candidates for the workflow wedge | Relative priority, exact UX, retention, or willingness to pay |
| Cold smoke: 27 signups from 300 visits | Observed experiment; 9% signup rate | Some cold-audience interest in the proposition | Product usage, retention, or payment demand |
| Two pilot volunteers | Observed experiment | At least two people expressed willingness to try a pilot | Completed onboarding runs, sustained use, or payment |
| Warm traffic: 12 signups from 40 visits | Observed experiment; 30% signup rate | Warm contacts responded positively | General-market conversion; it must not be pooled with cold traffic |
| No payment requested | Observed experiment limitation | Nothing about willingness to pay has been tested | Validation of the proposed $29/month price |
| $29/month | Assumption | A concrete price hypothesis for later testing | Revenue potential or product-market fit |

No blended “39 of 340” conversion rate will be used. Cold and warm cohorts have different acquisition conditions and must remain separate in all reporting.

### 1.4 Product goals

1. Let an agency operator define one reusable onboarding workflow.
2. Let the operator instantiate and manage one real client onboarding run.
3. Make ownership, due state, completion, and exceptions unambiguous.
4. Preserve evidence that a step was missed even if it is later resolved.
5. Keep external records accessible through links without storing sensitive files.
6. Learn whether two pilot agencies use the product on live onboarding work.

### 1.5 Business goals

1. Convert the two volunteers into instrumented live pilots.
2. Determine whether the runbook creates repeatable operational value.
3. Test willingness to pay separately from smoke-test signup behavior.
4. Decide at the end of the pilot whether to continue, narrow, reposition, or stop.

### 1.6 Non-goals

The six-week MVP will not include:

- Client or guest portals.
- File uploads, attachment storage, document previews, or document management.
- Bookkeeping, invoicing, payment collection, or financial reconciliation.
- Historical data migration or white-glove spreadsheet migration.
- Connectors or synchronization with CRM, project-management, storage, email, or accounting services.
- Automated email, SMS, Slack, or webhook reminders.
- AI-generated workflows, summaries, prioritization, or recommendations.
- Native mobile applications or mobile-specific workflows.
- Enterprise roles, granular RBAC, SSO, approval chains, or organizational hierarchies.
- Compliance certification or regulated-industry compliance scope.
- Multiple simultaneous workflow types or a general-purpose process builder.
- Public template marketplaces or cross-agency sharing.

### 1.7 Assumptions

- **Assumption:** The primary user is an agency owner, operations lead, or account lead who personally coordinates onboarding.
- **Assumption:** One agency account has one authenticated operator during the MVP.
- **Assumption:** Owners assigned to steps can be labels or contacts; they do not receive product accounts.
- **Assumption:** “CSV” means importing workflow steps and exporting run status/history. This must be confirmed with pilot users before finalizing the CSV contract.
- **Assumption:** A workflow may contain multiple reusable steps, but the MVP supports one workflow definition and one active live run per agency account.
- **Assumption:** Manual reminders mean the system prepares useful reminder text and records a reminder action; delivery happens outside the product.
- **Assumption:** Pilot agencies can use external systems for sensitive documents and add links to those records.

---

## 2. Users and context

### 2.1 Primary persona

| Attribute | Detail |
|---|---|
| **Label** | Small-agency onboarding operator |
| **Who they are** | Owner, operations lead, or account lead at a small service agency |
| **Primary job** | Get a new client from signed agreement to operational readiness without missing handoffs |
| **Environment** | Desktop work across email, spreadsheets, project tools, cloud storage, and bookkeeping software |
| **Current workaround** | Reused spreadsheets, copied checklists, email follow-ups, and personal memory |
| **Trigger** | A new client signs and several internal or client-owned steps must happen in sequence |
| **Core pain** | The operator cannot quickly see who owes what, what is late, and what has already gone wrong |
| **Anti-persona** | Enterprise operations teams requiring SSO, formal compliance controls, complex permissions, or integrations |

### 2.2 Supporting participants

Internal teammates and client contacts may be named as step owners, but they are not authenticated users in the MVP. The primary operator updates the run on their behalf.

This distinction prevents “explicit ownership” from expanding into portals and multi-user role management.

### 2.3 Primary job-to-be-done

> When a new client engagement begins, help me reuse a proven onboarding sequence, assign every step to a clear owner, and catch or document missed work before it disrupts delivery.

### 2.4 Use context

- The operator configures the workflow before or during the start of a client engagement.
- The run is checked during regular operational follow-up.
- Reminder delivery and sensitive-record work happen in existing tools.
- Mobile viewing may work through responsive layout, but mobile optimization is not a release criterion.

---

## 3. Solution

### 3.1 Value proposition

For small-agency operators who coordinate client onboarding across scattered tools, the product is an ownership-aware runbook that turns a reusable sequence into a live, auditable execution view. Unlike a static spreadsheet, it makes due states and exceptions explicit and retains missed-step history. Unlike a general project-management suite, it stays narrowly focused on one onboarding workflow.

### 3.2 MVP outcome

The smallest successful outcome is:

> A pilot operator creates or imports one workflow, starts one real onboarding run, assigns every step, updates it through completion or exception, and can identify both current late work and previously missed work without consulting a separate tracking sheet.

### 3.3 Product principles

1. **Every actionable step has one explicit owner.**
2. **Current status and historical truth are separate.** Completing a late step must not erase that it was missed.
3. **Link, do not ingest.** External systems remain the source of truth for files, finance, and client records.
4. **Manual operation before automation.** Prove reminder value before adding delivery integrations.
5. **One complete workflow before breadth.** Do not generalize into a workflow platform during the pilot.
6. **Exceptions must be visible, not hidden as completion.**

### 3.4 Scope summary

| In scope: MVP/P0 | Out of scope |
|---|---|
| One reusable workflow | Multiple workflow types or marketplace |
| One active live run | Portfolio-scale run management |
| Ordered reusable steps | Conditional branching and dependencies |
| Owner label/contact per step | Accounts for assigned owners |
| Due dates and derived due states | Calendar synchronization |
| Completion and exception handling | Approval chains |
| Manual reminder preparation and logging | Automated message delivery |
| External record links | File storage |
| CSV import/export | Migration service or bidirectional sync |
| Missed-step event history | Compliance-grade audit product |

---

## 4. Journeys and states

### 4.1 Journey A — Create the reusable workflow

1. The operator opens the empty workflow screen.
2. They name the onboarding workflow.
3. They add steps manually or import them from a valid CSV.
4. For each step, they provide a title and default owner label; optional fields include instructions, relative due offset, and external link.
5. They reorder and edit steps.
6. The system validates that every step has a title and owner.
7. The operator marks the workflow ready.

**Success state:** A ready workflow with at least one ordered, valid step can start a run.

**Failure and recovery:** Invalid CSV rows or incomplete steps are identified by row or step. Valid data remains available for correction; a partially invalid import cannot silently create a run.

### 4.2 Journey B — Start the live client run

1. The operator chooses “Start onboarding.”
2. They enter a client/run name and start date.
3. The system copies the workflow steps into a run snapshot.
4. Relative due offsets become concrete due dates.
5. The operator reviews and may adjust owners, dates, instructions, or external links for this run.
6. They confirm and activate the run.

**Success state:** One active run displays all steps and their current due states.

**Failure and recovery:** If an active run already exists, the system explains the MVP limit and prevents another from being started. A completed run may remain read-only while a new run is started only if the product limit is interpreted as one active run rather than one lifetime run.

### 4.3 Journey C — Operate the run

1. The operator opens the active run.
2. They scan summary counts and ordered steps.
3. They filter or identify steps that are due, overdue, complete, or in exception.
4. They open a step to follow its external record link or review instructions.
5. They mark the step complete or record an exception with a reason.
6. The system records the change in history.
7. When all steps are resolved, the operator completes the run.

**Success state:** Every step is complete or explicitly excepted, and the run can be closed.

**Failure and recovery:** A missing exception reason prevents the exception from being saved. Closing a run with unresolved steps requires the operator to resolve them; there is no silent bulk completion.

### 4.4 Journey D — Follow up manually

1. The operator selects an incomplete step.
2. They choose “Prepare reminder.”
3. The product displays copyable reminder text containing the run, step, owner, and due context.
4. The operator copies the text and sends it through their existing communication tool.
5. They record that a reminder was sent, optionally adding a note.
6. The reminder action appears in the step history.

**Success state:** The operator can prove when follow-up occurred without the product sending a message.

**Failure and recovery:** If clipboard access fails, the reminder remains selectable for manual copying. A reminder log is not presented as proof of external delivery.

### 4.5 Journey E — Review missed work and export

1. The operator opens run history.
2. They see steps that crossed their due date while unresolved.
3. A late step that was subsequently completed remains in missed-step history.
4. They export the current run and relevant history to CSV.
5. The downloaded CSV distinguishes current state from historical missed status.

**Success state:** The operator can answer both “What is late now?” and “What was missed during this onboarding?”

### 4.6 State model

#### Workflow states

- **Draft:** Editable but cannot start a run if validation fails.
- **Ready:** Valid and available to instantiate.
- **In use:** A snapshot has been used for a run; later template edits do not rewrite that run.

#### Run states

- **Active:** Contains operational steps and accepts updates.
- **Completed:** All steps are resolved; retained for review and export.

#### Step resolution states

- **Not started:** No completion or exception recorded.
- **Complete:** Operator recorded completion.
- **Exception:** Operator recorded that the expected step will not complete normally, with a required reason.

#### Derived due states

- **No due date**
- **Upcoming**
- **Due today**
- **Overdue**
- **Resolved**

“Missed” is a durable historical event, not a resolution state. When an unresolved step passes its due boundary, the system records its first missed event. Later completion changes the current state to complete but does not delete that event.

---

## 5. Requirements

### 5.1 Functional requirements

| ID | Requirement | Priority | Acceptance criteria |
|---|---|---:|---|
| **FR-001** | The operator can create and edit one reusable workflow. | P0 | A workflow can be named, saved as draft, edited, and marked ready; it must contain at least one valid step before becoming ready. |
| **FR-002** | The operator can create, reorder, edit, and remove reusable workflow steps. | P0 | Each saved step has a stable order, title, and explicit owner; optional instructions, due offset, and link persist after reload; reordering is reflected in the next run. |
| **FR-003** | Each step has one explicit owner represented without requiring that owner to have an account. | P0 | A workflow cannot become ready while any step lacks a non-empty owner label; a run displays the owner beside each step; owner labels may be overridden within a run. |
| **FR-004** | The operator can start one live run from the reusable workflow. | P0 | Starting a run creates a snapshot of all ready workflow steps; the operator supplies a run/client name and start date; later template edits do not modify the live snapshot. |
| **FR-005** | The system limits MVP operation to one active run per agency account. | P0 | Attempting to start another active run is blocked with an explanatory message; completing the existing run removes the active-run conflict. |
| **FR-006** | The system calculates and displays due dates and due states. | P0 | A relative offset produces a concrete run-step due date; the UI distinguishes no due date, upcoming, due today, overdue, and resolved using text as well as color; state updates correctly across the configured account date boundary. |
| **FR-007** | The operator can mark a step complete. | P0 | Completion records timestamp and acting operator; the step becomes resolved; reopening the page preserves the result; any earlier missed event remains visible. |
| **FR-008** | The operator can record an exception instead of falsely completing a step. | P0 | An exception requires a non-empty reason and records timestamp and operator; excepted steps are visually distinct from completed steps and count as resolved for run closure. |
| **FR-009** | The operator can correct a completion or exception. | P0 | Reopening a resolved step requires a reason; the correction creates a new history event and does not delete the original resolution record. |
| **FR-010** | The system preserves missed-step history. | P0 | When a step remains unresolved after its due boundary, exactly one initial missed event is recorded; completing or excepting it later does not remove that event; history displays due date, missed time, and later resolution. |
| **FR-011** | The operator can prepare and log a manual reminder. | P0 | Reminder text includes run, step, owner, and due context; it is copyable without an integration; logging records timestamp and optional note; the UI states that delivery occurs outside the product. |
| **FR-012** | Workflow and run steps can link to external records. | P0 | A valid `https` link can be added, edited, opened in a new browser context, and removed; no linked content or file is copied into product storage. |
| **FR-013** | The operator can import workflow steps from CSV. | P0 | A documented template supports step order, title, owner, instructions, due offset, and external URL; import provides a preview; row-level validation identifies invalid data; no rows are committed until the operator confirms. |
| **FR-014** | The operator can export run data and history to CSV. | P0 | Export includes run identifier/name, step order/title, owner, due date, current resolution, completed/exception timestamps, exception reason, whether ever missed, first missed timestamp, reminder count, and external URL; UTF-8 output opens correctly in a standard spreadsheet application. |
| **FR-015** | The operator can view the run summary and step history. | P0 | The run shows totals for unresolved, overdue, complete, exception, and ever missed; each step has a chronological history of state changes and reminder logs. |
| **FR-016** | The operator can complete a run only after all steps are resolved. | P0 | Completion is blocked while any step is neither complete nor excepted; after confirmation, the run becomes completed and remains viewable/exportable. |
| **FR-017** | The product records the minimum analytics needed for pilot decisions. | P0 | Workflow ready, run started, step resolved, exception recorded, reminder logged, missed event, export, run completed, and pricing-response events can be counted by cohort without storing sensitive client content in analytics. |
| **FR-018** | The operator can duplicate or manage multiple workflows. | P2 | Explicitly deferred; no MVP acceptance criterion. |
| **FR-019** | Assigned owners can receive automated reminders. | P2 | Explicitly deferred until manual-reminder usage demonstrates demand. |
| **FR-020** | Multiple authenticated teammates can collaborate. | P2 | Explicitly deferred until pilot evidence shows operator-only updates are inadequate. |

### 5.2 Non-functional requirements

| ID | Requirement | Priority | Acceptance criteria / validation |
|---|---|---:|---|
| **NFR-001** | The product must enforce tenant isolation. | P0 | Automated authorization tests verify that changing workflow, run, step, history, or export identifiers cannot expose or mutate another agency account’s data. |
| **NFR-002** | Sensitive file storage must remain outside the product. | P0 | No upload control, multipart upload route, object-storage binding, attachment entity, or binary-content persistence exists in the production MVP. |
| **NFR-003** | Bookkeeping data must remain outside the product. | P0 | No fields or endpoints collect invoice lines, bank details, payment credentials, balances, or accounting transactions; external bookkeeping URLs may be stored as ordinary links. |
| **NFR-004** | Links and CSV inputs must be handled safely. | P0 | Only permitted URL schemes open as links; CSV cells render as text in the application; exported cells beginning with formula-control characters are escaped; malformed files fail with a user-readable error. |
| **NFR-005** | Operational history must be durable and append-oriented. | P0 | State-transition tests confirm that completing, excepting, reopening, or editing a step adds an event rather than overwriting prior history; missed events survive later resolution. |
| **NFR-006** | Core run management must be keyboard-usable and understandable without color. | P0 | A keyboard-only test can create/edit a workflow, start a run, resolve a step, log a reminder, and export CSV; labels expose status text and focus is visible. |
| **NFR-007** | The main run view must remain responsive at MVP scale. | P0 | With 100 steps and 500 history events, the run view becomes usable within 2 seconds at the 75th percentile on the chosen production preview test profile, excluding network cold-start anomalies documented during testing. |
| **NFR-008** | Dates must have one documented interpretation. | P0 | The account uses one selected or stored time zone; automated boundary tests cover due today → overdue transitions and prevent duplicate missed events. |
| **NFR-009** | Pilot data must be recoverable through export. | P0 | Before pilot launch, a seeded account can export a CSV containing every current step and the history fields specified in FR-014, and the export is manually checked against the UI. |
| **NFR-010** | MVP scope must not imply compliance certification. | P0 | Signup/onboarding copy and settings contain no claims of HIPAA, SOC 2, GDPR certification, or other formal compliance; sensitive-file guidance directs users to their existing approved system. |

### 5.3 Analytics events

| Event | Trigger | Essential properties |
|---|---|---|
| `account_created` | Operator creates an account | Acquisition cohort: cold, warm, pilot, unknown |
| `workflow_ready` | Workflow first passes validation | Step count, entry method: manual/CSV |
| `run_started` | Live run becomes active | Step count, pilot identifier |
| `step_resolved` | Step completed or excepted | Resolution type, was overdue, was ever missed |
| `reminder_logged` | Manual reminder recorded | Step due state |
| `step_missed` | First unresolved due-boundary crossing | Due date, owner type label category if defined |
| `run_exported` | CSV export succeeds | Run state |
| `run_completed` | All steps resolved and run closed | Duration, completed count, exception count, missed count |
| `pricing_asked` | Founder conducts structured pricing test | Cohort, proposed price |
| `pricing_response` | Prospect answers pricing test | Accept/reject/conditional; no fabricated revenue event |

Analytics must not capture client names, instructions, exception text, external URLs, or other potentially sensitive record content.

---

## 6. UX and content notes

### 6.1 Information architecture

- **Sign in / account setup**
- **Workflow**
  - Empty state
  - Workflow editor
  - CSV import preview
- **Active run**
  - Run summary
  - Ordered step list
  - Step detail and history
  - Manual reminder dialog
- **Completed run**
  - Read-only summary
  - History
  - CSV export
- **Minimal settings**
  - Time zone
  - Account/export controls

### 6.2 Run-view hierarchy

The primary run view should answer, in order:

1. What requires attention now?
2. Who owns it?
3. When was or is it due?
4. What should happen next?
5. Has this step previously been missed?
6. Where is the source record?

### 6.3 Critical empty states

- **No workflow:** Explain that the operator will define one reusable onboarding sequence. Offer “Add first step” and “Import CSV.”
- **Workflow draft invalid:** List incomplete steps and the missing fields.
- **No active run:** Offer to start onboarding from the ready workflow.
- **No missed steps:** State that no step has crossed its due date unresolved; do not imply the run is complete.
- **No external link:** Allow normal operation; links are optional.
- **No history beyond creation:** Show the creation event rather than an empty panel.

### 6.4 Critical errors and recovery

- CSV invalid: retain preview and point to affected rows.
- Duplicate or missing CSV order: offer normalized ordering in preview, requiring confirmation.
- Invalid external URL: do not save it; explain accepted format.
- Clipboard unavailable: select reminder text for manual copy.
- Concurrent or stale update: reload current step state and ask the operator to reapply the change.
- History generation failure: do not report the state change as successful unless both current state and event are durably recorded.
- Export failure: preserve run state and allow retry.

### 6.5 Copy-critical moments

- **Empty-state proposition:** “Turn your client-onboarding checklist into an owned, trackable run.”
- **External records:** “Link to the source record. Files stay in your existing storage system.”
- **Exception action:** “Record why this step will not complete as planned.”
- **Manual reminder:** “Copy this reminder and send it in your usual communication tool.”
- **Missed history:** “Ever missed records that this step passed its due date unresolved, even if it was completed later.”
- **Pricing:** Do not present `$29/month` as validated or “the normal price.” If tested, identify it as a proposed pilot price.

---

## 7. Data boundaries and integrations

### 7.1 Core entities

| Entity | Purpose | Conceptual fields |
|---|---|---|
| **AgencyAccount** | Tenant and operator boundary | ID, operator ID, time zone, created time |
| **Workflow** | Single reusable onboarding definition | ID, account ID, name, state, version, timestamps |
| **WorkflowStep** | Reusable ordered instruction | ID, workflow ID, order, title, default owner, instructions, due offset, external URL |
| **Run** | One client-onboarding execution | ID, account ID, workflow version, display name, start date, state, timestamps |
| **RunStep** | Snapshot of a workflow step for a run | ID, run ID, order, title, owner, instructions, due date, external URL, current resolution |
| **StepEvent** | Append-oriented operational history | ID, run-step ID, event type, event time, actor, reason/note where applicable |
| **ImportSession** | Temporary CSV validation and preview | ID, account ID, parsed rows, errors, expiry |
| **ExperimentCohort** | Keeps evidence segments separate | Account/signup ID, cold/warm/pilot/unknown, source note |

Client/run display names and free-text instructions may still contain business-sensitive information. The product should minimize collection and avoid sending these fields to analytics or logs.

### 7.2 Stored in the product

- Workflow and run metadata.
- Step titles and instructions.
- Owner labels and optional contact-oriented text if confirmed necessary.
- Due dates and current resolution.
- Exception reasons and manual-reminder notes.
- External HTTPS URLs.
- Append-oriented history.
- Acquisition cohort and non-sensitive usage events.

### 7.3 Explicitly not stored

- Uploaded files or binary attachments.
- File contents fetched from external links.
- Financial ledgers, invoices, bank details, card data, or bookkeeping records.
- Email or message bodies sent through third-party systems.
- Credentials for external storage, CRM, accounting, or communication systems.
- Compliance documents or regulated-data classifications.

### 7.4 Integration boundary

| System | MVP | Boundary |
|---|---:|---|
| External record/file system | Link only | Store URL; do not fetch, index, preview, or copy content |
| Spreadsheet software | Yes, via files | User-controlled CSV import and export only |
| Email/chat | No integration | Prepare copyable reminder text; user sends externally |
| Bookkeeping platform | No integration | Optional ordinary external link only |
| CRM/project tools | No | No OAuth, API connector, sync, or webhook |
| Payment provider | No for initial MVP | Add only after explicit pricing-test decision |

### 7.5 Permissions

- One authenticated operator per agency account.
- Named step owners are operational labels, not security principals.
- All workflow, run, history, and export access is scoped to the authenticated account.
- No client-facing or teammate-facing access in the MVP.

---

## 8. Metrics, decision rules, and kill triggers

### 8.1 Baseline evidence

- Cold signup conversion: **27/300 = 9%**.
- Warm signup conversion: **12/40 = 30%**, reported separately.
- Pilot volunteers: **2**.
- Payment evidence: **none**.
- `$29/month`: **unvalidated hypothesis**.

### 8.2 MVP metrics

Because only two pilots are currently available, pilot metrics should be reported as counts and per-pilot outcomes, not misleading aggregate percentages.

| Metric | Definition | Six-week/pilot signal |
|---|---|---|
| **Pilot start** | Volunteer attends setup and imports/creates a workflow | 2 of 2 attempted; reasons recorded for any no-show |
| **Activation** | Workflow becomes ready and a live client run is started | At least 2 live runs total, preferably one per pilot |
| **Core adoption** | Pilot records at least five genuine step updates across two or more sessions | Both pilots, or one strong pilot plus a documented failure reason for the other |
| **Ownership coverage** | Active run steps with an explicit owner | 100%, enforced by product validation |
| **Operational value** | Pilot identifies a due, overdue, exception, reminder, or previously missed item they would otherwise track elsewhere | At least one concrete instance per activated pilot |
| **Run progression** | Run completed, or remains actively maintained for a real engagement | At least one completed run or two actively maintained runs at pilot decision date |
| **Return behavior** | Operator returns on at least two distinct days after activation | At least one pilot; target both |
| **CSV utility** | CSV import or export used on real pilot data | At least one real use; collect purpose and friction |
| **Pricing signal** | Structured response after experiencing the product | Ask each activated pilot separately; record accept, reject, or conditions |
| **Cold demand** | Cold landing conversion | Continue reporting 27/300 baseline and future cold cohorts separately |
| **Warm demand** | Warm landing conversion | Continue reporting separately; never combine with cold conversion |

### 8.3 Continue criteria

Continue into a post-MVP iteration if:

- At least one pilot completes or actively maintains a genuine onboarding run.
- The product reveals or helps resolve at least one real ownership, due-state, exception, reminder, or missed-step issue.
- At least one pilot returns after initial setup without founder prompting for every session.
- Pilot feedback points to improvements within the existing wedge rather than requiring portals, files, connectors, or a general project-management product.

Two successful pilots would be stronger evidence, but the sample is too small to treat the result as market validation.

### 8.4 Pivot or narrow triggers

Narrow or revise the wedge if:

- Pilots value reusable checklists but do not use owner or missed-history features.
- CSV is primarily requested for migration rather than repeatable operation.
- Assigned owners must update their own steps for the runbook to be useful, implying that the operator-only model is inadequate.
- Most work happens in an existing project-management tool and external links create more duplication than clarity.
- The useful unit is a smaller checklist segment rather than an entire onboarding run.

### 8.5 Kill triggers

Stop or materially rethink the product after the pilot if any of these occur:

1. Neither volunteer starts a real run within two weeks of having a usable pilot build, despite one structured setup attempt each.
2. Both pilots revert to their prior system before making five genuine step updates, and the reason is lack of core value rather than a fixable defect.
3. No pilot can identify a real decision, omission, or follow-up improved by explicit ownership, due states, exceptions, or missed history.
4. Both pilots say the product is unusable without an excluded category such as a client portal, file storage, or deep connector.
5. Structured post-use pricing conversations produce no willingness to pay at any plausible solo-business price and no credible high-frequency usage.
6. The founder must perform recurring data cleanup or concierge operation that cannot be reduced within the current MVP boundary.

The `$29/month` hypothesis should not be killed merely because a free smoke test did not collect payment. It must be tested explicitly after product use.

---

## 9. Edge cases and risks

| Item | Impact | Mitigation |
|---|---|---|
| Owner is a client contact who cannot access the product | Status may depend on operator updates | Treat owner as an accountability label; validate whether operator-mediated updates are sufficient |
| Step has no meaningful due date | Artificial deadlines reduce trust | Permit “no due date” while still requiring an owner |
| Due date changes after it was missed | History could be rewritten | Preserve original missed event and record the date change separately |
| Step is reopened after completion | Current and historical truth diverge | Add reopening event with required reason; retain completion event |
| Exception becomes normal completion later | Reporting can become confusing | Record both transitions chronologically and display current resolution separately |
| Workflow changes during a run | Live steps might unexpectedly change | Snapshot workflow version at run creation |
| External link expires or access is denied | Product cannot guarantee record availability | Show stored link and allow edit; do not claim link health or fetch content |
| CSV contains formulas or malformed encoding | Security or data corruption risk | Escape exports, validate imports, document UTF-8 template |
| CSV requirement actually means ongoing spreadsheet sync | Scope pressure | Validate in week one; retain file-based boundary for MVP |
| Manual reminders become high-volume work | Weak fit without automation | Measure reminder frequency before considering integrations |
| One active run is too restrictive | Pilot workflow blocked | Treat as an explicit pilot constraint and record demand before expanding |
| Pilot users expect migration help | Founder support burden | Provide one CSV template and short guide; no bespoke migration |
| Exception/free-text fields collect sensitive information | Privacy and support risk | Add concise guidance, minimize logging, and avoid analytics capture |
| Small pilot sample gives false confidence | Premature scaling | Use case evidence and counts, not broad market claims |

### Support-burden controls

- Provide one canonical CSV template with examples.
- Do not accept arbitrary legacy spreadsheet formats as a product requirement.
- Limit founder-led setup to one structured session per pilot.
- Record repeated support questions and convert only recurring core-flow issues into product changes.
- Do not manually operate reminders or update runs on behalf of pilots.

### Open product questions

1. Does CSV primarily mean workflow-step import, run export, or both?
2. Is one active run enough for the first pilots, or do agencies routinely onboard clients concurrently?
3. Are owner labels sufficient, or must owners have contact details for useful reminder text?
4. Should due offsets use calendar days or business days?  
   **MVP recommendation:** calendar days unless both pilots require business-day logic.
5. What exact moment counts as “missed”: immediately after the due date or after a configurable end-of-day boundary?  
   **MVP recommendation:** after the due date ends in the account time zone.
6. Can completed runs remain accessible while a new active run begins?  
   **MVP recommendation:** yes; the limit should be one active run, not one lifetime run.
7. What information may appear in CSV exports without creating unacceptable sensitivity?
8. After hands-on use, will either pilot pay `$29/month`, and under what conditions?

---

## 10. Six-week delivery plan

| Week | Milestone | Outcome | Exit criteria |
|---|---|---|---|
| **Week 1** | M0: Product contract and risk spike | Lock states, CSV contract, tenant model, missed-event semantics, and pilot schedule | Pilot questions answered where possible; one-active-run rule confirmed; test fixtures cover date boundary and CSV hazards |
| **Week 2** | M1: First vertical slice | One operator can create a minimal workflow, start a run, and complete one step with durable history | Deployed preview demonstrates workflow → run snapshot → completion event → reload; tenant authorization test passes |
| **Week 3** | M2: Operational state | Owners, due states, exceptions, reopening, and missed-step history work end to end | State-transition and time-boundary tests pass; overdue and ever-missed are distinguishable |
| **Week 4** | M3: Workflow portability and follow-up | CSV import/export, external links, and manual reminders are usable | Pilot CSV imports in preview; export matches UI; unsafe CSV/link tests pass; reminder logs persist |
| **Week 5** | M4: Pilot-ready product | Empty/error states, analytics, accessibility baseline, and data boundaries are verified | Production-like preview passes P0 journey tests; no upload surface exists; pilot onboarding guide is ready |
| **Week 6** | M5: Live pilot and decision capture | Two volunteers are onboarded, real usage is observed, and pricing is tested after use | Each pilot has one setup attempt; real-run outcomes and friction are logged; `$29/month` responses captured separately from signup evidence |

### 10.1 First vertical slice

Build this before CSV, reminders, dashboards, or visual polish:

> An authenticated operator creates a workflow containing one step with an owner and due offset, starts a named run, sees the concrete due state, marks the step complete, reloads the page, and sees both the current resolution and its immutable history event.

The slice includes:

- One tenant/account boundary.
- Minimal workflow and step creation.
- Workflow validation.
- Run snapshot creation.
- Due-date calculation.
- Step completion.
- Append-oriented history.
- A single authorization test and state-persistence test.
- A deployable preview.

This slice validates the hardest product invariant early: a reusable definition becomes a live, independently historical run.

### 10.2 Build-versus-buy guidance

- Buy or use managed authentication rather than building credential recovery.
- Use managed application storage suitable for the chosen deployment platform.
- Use a small CSV parser with explicit validation rather than implementing CSV parsing manually.
- Use product analytics only if sensitive free text and links can be excluded reliably; otherwise store minimal first-party counters.
- Do not adopt workflow engines, messaging platforms, object storage, or integration frameworks for this MVP.

### 10.3 Scope fallback order

If six-week capacity is threatened, simplify in this order without cutting the ownership-to-history core:

1. Use fixed reminder copy rather than customizable templates.
2. Export a single denormalized CSV rather than multiple reports.
3. Limit import to one documented CSV template.
4. Use simple move-up/move-down ordering rather than complex drag-and-drop.
5. Reduce dashboard filtering to clear summary counts and ordered status sections.

Do not cut explicit owners, due states, exceptions, or durable missed history; those are the wedge being tested.

---

## 11. Launch and feedback

### 11.1 Beta audience

- The two supplied pilot volunteers.
- Additional warm contacts may observe or join later, but their results remain labeled as warm.
- New cold traffic remains a separate acquisition cohort.

### 11.2 Pilot sequence

1. Conduct one short pre-use workflow walkthrough.
2. Ask the pilot to bring a real onboarding checklist or CSV.
3. Have the pilot create/import the workflow themselves.
4. Start a real run; avoid founder-entered demo data as activation evidence.
5. Observe the first update and capture friction.
6. Review usage after several days without updating the run for them.
7. Conduct a structured value and pricing conversation after meaningful use.

### 11.3 Feedback questions

- What did you check before opening the product?
- Which step required follow-up, and how did you handle it?
- Did naming an owner change any action?
- Was “exception” meaningfully different from “complete”?
- Did missed-step history reveal anything your previous system lost?
- What did you still track elsewhere, and why?
- Which CSV direction mattered?
- What would make you stop using this?
- After using it, would you pay `$29/month`? Why or why not?
- If not `$29`, is the objection price, frequency, missing value, or product trust?

### 11.4 Pricing treatment

Payment is not a launch dependency for the first instrumented pilot use because payment demand was never tested. However, pricing cannot remain indefinitely hypothetical.

At the end of meaningful pilot use:

- Present `$29/month` as a specific proposed price.
- Ask for a concrete decision, not a general opinion.
- Prefer a paid continuation or payment commitment over another email signup.
- Record conditional answers verbatim in research notes, without converting them into revenue.
- Keep payment evidence separate from activation and retention evidence.

---

## 12. Evidence handoff

| Field | Value |
|---|---|
| **Current decision** | Build a six-week, solo-developer MVP for one ownership-aware client-onboarding workflow and one active live run, then test it with the two pilot volunteers. Do not expand into files, portals, connectors, bookkeeping, or automation before core-use evidence. |
| **Evidence classes** | primary behavior; observed experiment; assumption |
| **Supported claims** | Supplied discovery supports explicit owners, reusable steps, external record links, and CSV as candidate needs. Cold smoke generated 27 signups from 300 visits. Warm traffic generated 12 signups from 40 visits and is a separate cohort. Two people volunteered for pilots. |
| **Still unproven** | Real workflow activation, repeated use, completed runs, retention, reduction in missed work, sufficiency of operator-only updates, exact CSV direction, willingness to pay, and viability of `$29/month`. |
| **Contradictions / exclusions** | Warm and cold traffic must not be pooled. Signup is not payment or retention evidence. No payment was requested. Sensitive file storage and bookkeeping are separate products/jobs. MVP excludes portals, files, migration, connectors, AI, mobile, enterprise roles, and compliance scope. |
| **Source anchors** | User-provided discovery summary; cold smoke result: 27/300; warm result: 12/40; two stated pilot volunteers; explicit statement that no payment was requested; supplied P0 and exclusion lists. No external sources or invented interviews were used. |
| **Next validation** | Onboard both volunteers onto real runs; observe owner/due/exception/missed-history behavior; determine the required CSV direction; measure return use and run progression; then ask each activated pilot for a concrete paid continuation decision at the proposed `$29/month`, recording cold, warm, pilot-use, and payment evidence separately. |

---

## Decisions to confirm

1. Confirm that “one live run” means **one active run at a time**, while completed runs remain accessible.
2. Confirm that P0 CSV includes both **workflow-step import and run/history export**.
3. Confirm that step owners are **labels managed by the operator**, not authenticated collaborators.

## Best next implementation slices

1. Workflow → live snapshot → step completion → durable event history.
2. Owner, due-state, exception, reopening, and first-missed-event logic.
3. CSV, links, manual reminders, exports, and pilot instrumentation.

Nothing needs to return to broad market validation before building this bounded pilot. The priority is now primary product-use evidence and an explicit post-use pricing test; broader cold validation should resume only after the core workflow demonstrates value.