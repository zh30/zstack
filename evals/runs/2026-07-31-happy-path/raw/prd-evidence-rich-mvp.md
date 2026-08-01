# PRD: Ownership-Aware Client Onboarding Runbook

| Field | Value |
|---|---|
| **Status** | Review |
| **Owner** | Solo developer / product owner |
| **Last updated** | 2026-07-31 |
| **Version** | 0.1 |
| **Primary persona** | Project manager or operations lead at a small agency |
| **Platform** | Desktop-first responsive web app |
| **Delivery constraint** | Six-week, solo-developer MVP; Cloudflare-native deployment |
| **Related materials** | Five interview synthesis, Reshape decision, cold and warm smoke-test results supplied with this PRD |

## Revision history

| Version | Date | Summary |
|---|---|---|
| 0.1 | 2026-07-31 | Initial decision-ready MVP PRD from supplied discovery and smoke-test evidence |

## Decision summary

Build a narrow coordination tool for small-agency project managers who repeatedly reconstruct client onboarding across email, Notion, Drive, billing, and automation tools.

The MVP will provide one reusable onboarding workflow per workspace. A project manager turns that workflow into a live client run, assigns one named owner and a due date to every step, records completion or exceptions, links to records that remain in existing tools, sends simple manual email reminders, sees overdue and blocked work with an event history, and exports run data as CSV.

For the first pilot:

- One authenticated coordinator operates the workspace.
- Step owners are named assignees, not product users; they do not receive accounts or a portal.
- The product stores workflow and coordination metadata, but not uploaded files or the contents of linked records.
- Template edits affect future runs only.
- Reminders are coordinator-triggered emails, not scheduled automation.
- Billing is handled outside the app while testing the unvalidated continuation price of $29/month.
- The bookkeeping segment remains a separate opportunity and is not incorporated into this MVP.

These choices preserve the six-week solo-development constraint while testing the central hypothesis: explicit ownership plus reusable run structure reduces copying and prevents silent misses.

---

## 1. Evidence and source treatment

### 1.1 Evidence ledger

| ID | Source | Observation | Product interpretation | Confidence / limitation |
|---|---|---|---|---|
| E-001 | Five customer interviews and resulting Reshape decision | Interviews pointed toward agency project managers coordinating onboarding across email, Notion, Drive, billing, and automation tools. | Use small-agency project managers as the first wedge and coordination—not document storage—as the primary problem. | Moderate qualitative signal; interview notes and segment composition were not supplied. |
| E-002 | Strongest interview | The last three onboardings took about 45 minutes each in repeated copying; the team pays $29/month for Zapier, abandoned a Notion template because ownership was unclear, and requested a pilot with one real client. | Reuse, explicit step ownership, and a real-client pilot are P0. The reported 45-minute cost is a benchmark for that respondent, not a segment-wide average. | Strong problem evidence from one respondent; insufficient to establish prevalence or willingness to pay. |
| E-003 | Separate bookkeeping interview segment | Security-sensitive bookkeeping teams experience weekly failures and use paid VA labor. | Do not merge this segment into the agency wedge. Its compliance, security, and operating model require separate validation. | Meaningful pain, but outside the selected first market. |
| E-004 | Adoption constraints | No historical migration; link to existing records rather than store sensitive files; explicit owner per step; CSV export. | These are hard MVP boundaries and acceptance conditions. | Treated as supplied product constraints. |
| E-005 | Qualified cold smoke test | 300 visitors produced 27 waitlist signups, six substantive replies, and two volunteers for a real-client pilot. | There is directional cold interest and unusually valuable pilot intent, sufficient to justify a narrow MVP. | Calculated rates: 9.0% signup, 2.0% substantive reply, 0.67% pilot volunteer per visitor, and 7.4% volunteer per signup. No payment was requested. |
| E-006 | Separate warm-list smoke test | 40 warm visits produced 12 signups. | Warm interest may help recruit design partners but is not acquisition evidence comparable to cold traffic. | Calculated 30.0% conversion. Must be reported separately and never pooled with E-005. |
| E-007 | Price evidence | No payment was requested; $29/month is a proposed continuation price. | Treat $29 as a price test, not established willingness to pay. Do not build in-app billing before the test produces a paid commitment. | Willingness to pay is unknown. |

No verbatim customer quotations are used because none were supplied. All percentages above are calculations from the supplied counts. Product targets later in this document are forward-looking decisions, not research results.

### 1.2 Evidence-based confidence

- **Problem existence:** moderate.
- **Chosen agency wedge:** moderate.
- **Value of explicit ownership:** moderate, with a strong single-interview signal.
- **Demand for a real-client pilot:** strong enough to proceed, based on two volunteered pilots.
- **Repeat use and retention:** unknown.
- **Willingness to pay at $29/month:** unknown.
- **Need for native integrations or scheduled automation:** not yet demonstrated.

---

## 2. Overview

### 2.1 One-liner

A reusable web runbook for small-agency project managers to give every client-onboarding step a named owner and due date, track completion and exceptions, and link existing records without moving sensitive files.

### 2.2 Problem statement

**Current situation:** Agency project managers rebuild onboarding coordination for every new client across email threads, Notion pages, Drive folders, billing systems, and automation tools.

**Pain:** Repeated copying consumes setup time, ownership becomes ambiguous, and overdue or blocked steps can remain invisible until somebody manually checks several tools.

**Why now:** Two qualified cold visitors volunteered to use a solution for a real client, providing a concrete pilot path rather than only stated interest.

**Known cost of the status quo:** One respondent reported roughly 45 minutes of repeated copying in each of their last three onboardings, pays $29/month for Zapier, and abandoned a Notion template because responsibility for steps remained unclear. This is a single-customer benchmark, not a market average.

### 2.3 Primary job-to-be-done

> When a new client is ready to onboard, help me instantiate our standard process, make one person accountable for every step, and surface anything late or blocked without recreating the same coordination across several tools.

### 2.4 Value proposition

For small-agency project managers who coordinate client onboarding across disconnected tools, the product is an ownership-aware runbook that makes a reusable process operational for each client. Unlike a static Notion template or a general automation tool, it requires a named owner and due date for each live step, tracks exceptions and history, and leaves source records in the tools the agency already uses.

### 2.5 Goals

#### Product goals

1. Let a project manager turn a saved workflow into a ready-to-run client onboarding in 15 minutes or less after the initial template is configured.
2. Prevent an active run from containing a step without one explicit owner and due date.
3. Make overdue, blocked, skipped, completed, and reopened work visible from one run view.
4. Preserve enough event history to determine when a step was assigned, changed, reminded, completed, or placed into an exception.
5. Let users keep sensitive files and operational records in existing systems while linking to them.
6. Provide a portable step-level CSV report without requiring migration or an integration.

#### Business goals

1. Put the product into use for at least one real client with the strongest design partner, then onboard the second volunteer if the first pilot is operationally stable.
2. Determine whether the reusable run saves meaningful setup time relative to the reported 45-minute baseline.
3. Observe reuse on a second onboarding when a pilot has an eligible new client.
4. Ask for an actual $29 continuation payment after real use, rather than relying on stated interest.
5. Learn whether manual reminders are sufficient before investing in scheduled automation.

### 2.6 Non-goals for MVP

The MVP will not include:

- A full client or assignee portal.
- Accounts or permissions for step owners.
- Native file upload, file storage, document ingestion, or content previews.
- Historical client or workflow migration.
- CSV import.
- Notion, Google Drive, billing, Zapier, or other native connectors.
- A connector marketplace.
- AI-generated or AI-recommended workflows.
- Multiple reusable workflow templates per workspace.
- Native mobile apps.
- Bookkeeping compliance workflows or bookkeeping-specific security claims.
- Enterprise roles, granular permissions, SSO, SCIM, or audit certification.
- Multi-coordinator real-time collaboration.
- Automated scheduled reminders.
- In-app subscription billing before willingness to pay is validated.
- Complex workflow branching, approvals, dependencies, or conditional logic.
- Custom reporting dashboards beyond the operational run view and CSV export.

---

## 3. Product principles and scope

### 3.1 Product principles

1. **Every live step has one accountable owner.** Collaborators may help, but MVP stores one person responsible for the outcome.
2. **Coordinate records; do not become the record store.** External files and system records remain in their current tools.
3. **Make exceptions explicit.** Blocked and skipped work requires a reason; silence must not appear as success.
4. **Snapshot live work.** Updating the reusable template never silently changes an in-progress client run.
5. **One strong workflow before workflow breadth.** The pilot supports one reusable process, not a template library.
6. **Manual control before automation.** The coordinator initiates reminders and state changes until pilot behavior proves which automation is valuable.

### 3.2 Scope summary

| In scope: MVP / P0 | Deferred until validated | Explicitly out of scope |
|---|---|---|
| One reusable workflow | Multiple workflow templates | Historical migration |
| One coordinator account | Scheduled reminders | Full client portal |
| Named owner per step | Basic teammate access | Native file storage |
| Relative due offsets and live due dates | In-app $29 billing | Connector marketplace |
| New client runs from a template snapshot | Cross-run reporting | AI workflows |
| Completion, blocked, skipped, and reopen tracking | Owner self-service through a narrowly scoped interaction, only if separately validated | Mobile apps |
| Manual email reminders |  | Bookkeeping compliance |
| External record links |  | Enterprise roles |
| Event history and missed-step view |  |  |
| CSV export |  |  |

---

## 4. Users and context

### 4.1 Primary persona

| Attribute | Detail |
|---|---|
| **Label** | Small-agency project manager / operations lead |
| **Who they are** | The person responsible for coordinating a newly signed client through setup across the agency team, the client, and outside systems. |
| **Working environment** | Desktop-heavy coordination across email, Notion, Drive, billing, and automation tools. |
| **Primary job** | Start a consistent onboarding run, assign accountability, and catch late or blocked work. |
| **Current workaround** | Duplicate templates, copy details between tools, manually chase owners, and inspect several systems for status. |
| **Trigger** | A client signs or reaches the handoff point where onboarding must begin. |
| **Success** | The PM can see who owns every step, what is due, what failed, and what remains, without storing source files in another system. |
| **Anti-persona** | Security-sensitive bookkeeping operations seeking compliance workflows; enterprises needing role administration; agencies seeking a customer portal or deep connector automation. |

**Assumption A-001:** One coordinator can operate the pilot workspace. Owners may be agency staff, client contacts, or other outside participants, but are references rather than signed-in users.

### 4.2 Use context

- Primary use is on desktop during focused operational work.
- The responsive UI must remain readable and usable on a phone browser for quick review, but mobile-specific optimization and apps are not MVP goals.
- A run starts only for a new onboarding; historical clients are not imported.
- The PM is expected to have permission to store client labels, assignee contact details, and external URLs.
- Linked services remain responsible for their own access control. A link may exist in the run even if the viewer lacks permission in the destination system.

---

## 5. P0 user journeys

### Journey A — Configure the reusable workflow

1. The coordinator signs in to the workspace.
2. The product shows an empty workflow state and explains that one workflow can be reused for future clients.
3. The coordinator creates or edits the workspace’s single workflow.
4. For every step, the coordinator enters a title, optional instructions, an owner slot such as “Agency PM” or “Client finance contact,” and a due offset in calendar days from the run start date.
5. The coordinator reorders steps and saves the workflow.
6. The system validates that at least one step exists and that every step has an owner slot and valid due offset.

**Success state:** The workflow is ready to instantiate for a client.

**Failure / recovery:** Missing titles, owner slots, or invalid offsets are shown next to the affected steps; valid work remains in the form so the PM can correct and retry.

### Journey B — Start a real-client run

1. The coordinator chooses **Start client onboarding** from the saved workflow.
2. They enter a client label, start date, and optional run-level external links.
3. The product creates a preview using a snapshot of the current workflow.
4. The coordinator maps each workflow owner slot to one named owner and confirms or adjusts calculated due dates.
5. The product highlights any step without an owner or due date.
6. The coordinator activates the run once all required assignments are complete.

**Success state:** A live run appears in the active-run list with progress, next-due, overdue, and exception counts.

**Failure / recovery:** Activation is blocked until every step has exactly one owner and one due date. The user can save the run as a draft and return later.

### Journey C — Coordinate due work and send a reminder

1. The coordinator opens the active-run list and filters to due today, overdue, or blocked steps.
2. They open a step and inspect its owner, instructions, due date, and external links.
3. If the owner has an email address, the coordinator selects **Send reminder**.
4. The product previews a fixed, minimal email containing the client label, step title, due date, and coordinator reply-to address; external record URLs are omitted.
5. The coordinator confirms the send.
6. The result—accepted by provider or failed—is recorded in the step history.

**Success state:** The coordinator can see that a reminder attempt occurred and when.

**Failure / recovery:** Missing owner email disables the send action and explains how to add one. Provider failure leaves the step unchanged, records the failure, and offers retry.

### Journey D — Complete a step or record an exception

1. The coordinator opens a step.
2. They mark it **In progress**, **Complete**, **Blocked**, or **Skipped**.
3. Completing records the actor and time.
4. Blocking or skipping requires an exception reason; a blocked step may also include a next-action note.
5. If a completed or skipped step must be reopened, the coordinator provides a reason.
6. The run summary and event history update immediately.

**Success state:** The current state and its explanation are visible, and the prior state remains in history.

**Failure / recovery:** A blocked or skipped state cannot be saved without a reason. A failed update preserves the previous state and offers retry without duplicating the event.

### Journey E — Find missed steps and export a run

1. The coordinator opens the missed-step view, which lists unresolved steps whose due date has passed.
2. They filter by run, owner, or exception state.
3. They open a step to review assignment, due-date changes, reminders, completion, and exception events.
4. They select **Export CSV** for one run or the currently filtered result.
5. The product generates a UTF-8 CSV with one row per run step.
6. The coordinator opens the file in a spreadsheet or retains it as a handoff record.

**Success state:** The exported rows match the visible scope and contain current state plus the key timestamps and exception fields.

**Failure / recovery:** If no rows match, the UI explains that there is nothing to export and does not download a blank file.

---

## 6. Requirements

### 6.1 Functional requirements

| ID | Requirement | Priority | Acceptance criteria |
|---|---|---:|---|
| **FR-001** | The coordinator can authenticate and access only their workspace. | P0 | **Given** an approved pilot coordinator, **when** they complete sign-in, **then** they reach their workspace. **Given** a signed-out or different-workspace request, **when** a protected run, link, export, or history endpoint is requested, **then** the request is denied without exposing whether the record exists. Step owners do not receive accounts or product access. |
| **FR-002** | The coordinator can maintain named owners for assignment. | P0 | An owner requires a display name and category: agency, client, or external. Email is optional except when sending a reminder. An owner referenced by a run cannot be hard-deleted; it can be archived while remaining visible on historical runs. The product prevents an active run step from having zero or more than one owner. |
| **FR-003** | Each workspace can configure exactly one reusable workflow. | P0 | The workflow supports at least one ordered step. Every step requires a title, owner slot, and integer calendar-day offset from the run start; instructions are optional. Steps can be added, edited, removed, and reordered before save. Invalid steps are identified inline. Saving template changes does not alter any existing run. |
| **FR-004** | The coordinator can instantiate a client run from the workflow. | P0 | A new run requires a client label, start date, and workspace timezone. The system copies the current workflow version into run steps and calculates due dates from offsets. The coordinator can map owner slots and adjust due dates in a preview. The run cannot become active until every step has one owner and due date. Saving as draft is allowed. |
| **FR-005** | The product shows operational run and due state. | P0 | The active-run list shows client label, progress, next due date, overdue count, and exception count. A run can be filtered by owner, client label, current status, and due state. Due state is derived in the workspace timezone as **Upcoming**, **Due today**, **Overdue**, or **Resolved**. A step remains overdue until Complete or Skipped, even if it is Blocked. |
| **FR-006** | The coordinator can update step execution state. | P0 | Supported states are **Not started**, **In progress**, **Blocked**, **Complete**, and **Skipped**. Marking Complete stores `completed_at` and actor. Reopening a Complete or Skipped step requires a reason. A successful update changes the summary and creates exactly one history event; a failed or retried request must not create duplicate events. |
| **FR-007** | Exceptions are explicit and recoverable. | P0 | Changing a step to Blocked or Skipped requires a non-empty reason. A Blocked step may store a next-action note. Resolving a Blocked step retains its original exception event. Blocked, skipped, and reopened steps appear in run history and CSV export with their reason and timestamps. |
| **FR-008** | Runs and steps can contain links to external records without storing their contents. | P0 | The coordinator can add, label, edit, and remove HTTPS links at run or step level. Invalid or non-HTTPS URLs produce a clear validation message. Links open in a new browser tab. The system does not upload, fetch, index, preview, or copy destination content. Raw external URLs are excluded from analytics, application logs, and reminder emails. |
| **FR-009** | The coordinator can send a simple reminder to a step owner. | P0 | A reminder can be initiated only for an unresolved step whose owner has an email address. Before sending, the coordinator sees the recipient and fixed message content. The email includes the client label, step title, due date, and coordinator reply-to, but no external URLs or file contents. Provider acceptance or failure is displayed and logged with a timestamp. Retry is available after failure. No scheduled or recurring reminders are included. |
| **FR-010** | The product maintains enough history to investigate missed steps. | P0 | Run history records creation, activation, owner change, due-date change, status transition, exception reason, reopen reason, reminder result, and run close/reopen. Each event shows event type, time, and actor. Events cannot be edited or deleted in the MVP UI. A missed-step view shows every unresolved step past its due date and links to its history. |
| **FR-011** | The coordinator can export run data as CSV. | P0 | Export works for an individual run and the current filtered result. It produces one UTF-8 row per run step with at least: client label, workflow version, step order, step title, owner name, owner category, owner email, status, due state, due date, completion time, exception type/reason, last reminder result/time, external link labels/URLs, run start, and run close time. Values are correctly quoted, and spreadsheet-formula prefixes are neutralized. An empty result does not produce a file. |
| **FR-012** | The coordinator can close and reopen an onboarding run. | P0 | A run can close only when all steps are Complete or Skipped; open or Blocked steps identify why close is unavailable. Closing records time and actor. Reopening requires a reason and restores the run to the active list while preserving its original close event. |
| **FR-101** | A workspace can maintain multiple workflow templates. | P1 | Consider only after pilots demonstrate multiple recurring onboarding types. |
| **FR-102** | The product sends scheduled due and overdue reminders. | P1 | Consider only after observing whether manual reminders are frequent and valuable; recipient consent and suppression rules must be defined first. |
| **FR-103** | More than one agency teammate can operate a workspace. | P1 | Add only if the single-coordinator assumption prevents a pilot from completing a live run. Keep roles limited to member and workspace owner rather than enterprise permissions. |
| **FR-104** | The product manages recurring $29/month billing. | P1 | Build only after at least one user accepts a real continuation charge. The first price test may use an external hosted payment link or manual invoice. |

### 6.2 Non-functional requirements

| ID | Requirement | Priority | Verification |
|---|---|---:|---|
| **NFR-001** | Protect workspace and linked-record metadata. | P0 | All production traffic uses TLS; every data request is workspace-scoped server-side; no external URL appears in analytics, logs, or reminder content; protected pages are non-indexable; no file-upload path exists. Authorization tests cover cross-workspace record, export, and history access. |
| **NFR-002** | Preserve state and history atomically. | P0 | Status changes, exception details, and their history event commit together or not at all. Retry tests verify that duplicate requests do not produce duplicate state transitions or reminder events. A platform-supported backup/restore procedure is documented and smoke-tested before the first live pilot. |
| **NFR-003** | Deliver a desktop-first responsive, accessible interface. | P0 | All P0 journeys are usable at 1280px desktop width and 375px mobile-browser width without lost controls or horizontal page scrolling. Forms have programmatic labels, validation is announced, primary actions are keyboard reachable, focus is visible, and text/control contrast meets WCAG 2.1 AA. |
| **NFR-004** | Keep routine coordination responsive at pilot scale. | P0 | With a seeded workspace of 100 runs and 100 steps per run, the active-run and run-detail pages reach usable content within 2.5 seconds at p75 on a typical broadband connection, and ordinary state changes acknowledge within 1 second at p75 excluding email-provider latency. |
| **NFR-005** | Make operational failures diagnosable without exposing customer records. | P0 | Authentication, mutation, export, and reminder failures have traceable request IDs. Logs include internal record IDs and error categories, not client-provided URLs or reminder bodies. The solo operator can inspect failed reminders and application errors from one operational dashboard or log query. |
| **NFR-006** | Deploy on a Cloudflare-native application boundary. | P0 | The web application and server execution run on Cloudflare; structured application state uses a Cloudflare-native datastore. Any external email or authentication provider is isolated behind a small service boundary so it can be replaced without changing the workflow model. |

### 6.3 State definitions

| Concept | Values | Rule |
|---|---|---|
| **Execution state** | Not started, In progress, Blocked, Complete, Skipped | Coordinator-set; Blocked and Skipped require reasons. |
| **Due state** | Upcoming, Due today, Overdue, Resolved | System-derived from due date, execution state, and workspace timezone. |
| **Run state** | Draft, Active, Closed | Draft may be incomplete; Active must pass ownership and due-date validation; Closed requires all steps Complete or Skipped. |
| **Missed step** | Any unresolved step after its due date | Includes Not started, In progress, and Blocked. |

### 6.4 Product analytics events

No client-provided external URL, instructions, exception reason, or reminder body may be included in analytics.

| Event | Trigger | Allowed properties |
|---|---|---|
| `workflow_saved` | Reusable workflow saves successfully | Workspace ID, step count, first-save boolean |
| `run_draft_created` | Client run draft is created | Workspace ID, run ID, step count |
| `run_activated` | Run passes validation and becomes active | Run ID, setup duration, step count, owner count |
| `step_state_changed` | Execution state changes | Run ID, step ID, from/to state, overdue boolean |
| `exception_recorded` | Blocked or Skipped is saved | Run ID, step ID, exception type; exclude reason text |
| `reminder_attempted` | Coordinator confirms reminder | Run ID, step ID, result category |
| `run_closed` | Run closes | Run ID, duration, completed/skipped counts |
| `csv_exported` | Non-empty CSV is produced | Scope type, row count |
| `price_offer_recorded` | Founder records post-pilot offer outcome | Pilot ID, offered price, accepted/declined/pending |

---

## 7. UX and content notes

### 7.1 Information architecture

- **Sign in**
- **Today / Active runs**
  - Due today
  - Overdue
  - Blocked
  - All active runs
- **Workflow**
  - Single reusable workflow editor
- **Start onboarding**
  - Client details
  - Owner mapping
  - Due-date preview
  - Activation validation
- **Run detail**
  - Summary
  - Ordered steps
  - Links
  - History
  - Export
- **Owners**
  - Active and archived owner references
- **Closed runs**
- **Minimal settings**
  - Workspace name
  - Timezone
  - Coordinator name and reply-to email

### 7.2 Critical empty, error, and permission states

| State | Required behavior |
|---|---|
| **No workflow** | Explain the reusable-workflow value and show one CTA: **Create your workflow**. |
| **Workflow has no valid steps** | Preserve entered data, identify invalid steps inline, and prevent use for a run. |
| **No client runs** | Explain that historical migration is not required and invite the user to start with the next real client. |
| **Draft has missing owners or due dates** | Show a count and direct links to each incomplete step; keep activation disabled. |
| **No overdue or blocked work** | State that nothing currently needs attention; do not imply all onboarding is complete. |
| **Owner has no email** | Keep assignment valid but disable reminders with an **Add email** action. |
| **Reminder provider fails** | Keep the step unchanged, show a non-technical error and retry action, and record the failed attempt. |
| **External link is invalid** | Explain that only HTTPS links are accepted; do not attempt to fetch the URL. |
| **External destination denies access** | The product cannot detect or repair destination permissions; users remain in the run after the new tab opens. |
| **No export rows** | Explain why there is nothing to export and do not download a blank CSV. |
| **Session expires during an edit** | Preserve unsaved form content locally where practical, require sign-in, and let the user retry. |
| **Unauthorized or wrong-workspace URL** | Return a generic not-found or access-denied state without revealing record existence. |
| **Network/update conflict** | Preserve the current form, show that the save did not succeed, and prevent duplicate history events on retry. |
| **Template changed after a run began** | Existing runs show their snapshot version and remain unchanged. |
| **Archived owner remains on a run** | Show the archived label but retain attribution; require a current owner if an active step is reassigned. |

### 7.3 Critical copy

- **Workflow empty state:** “Build the checklist once. Reuse it for each new client.”
- **Run activation blocker:** “Assign one owner and one due date to every step before this onboarding starts.”
- **No runs:** “Start with your next client—there’s no history to migrate.”
- **External links helper:** “Keep files in the tools you already use. This runbook stores the link, not the file.”
- **Exception prompt:** “What prevented this step from completing?”
- **Reminder confirmation:** “Send this step reminder to {owner email}? Linked records will not be included.”

---

## 8. Conceptual data and integration boundaries

### 8.1 Core entities

| Entity | Purpose | Key conceptual fields |
|---|---|---|
| **Workspace** | Tenant boundary for one pilot agency | ID, name, timezone, coordinator reply-to, created time |
| **Coordinator** | Authenticated primary user | ID, workspace ID, name, email, auth identity |
| **Owner** | Person accountable for a step; not necessarily a user | ID, workspace ID, name, category, email, active/archived |
| **Workflow** | Workspace’s one reusable process | ID, workspace ID, name, version, updated time |
| **Workflow step** | Reusable step definition | ID, workflow version, order, title, instructions, owner-slot label, due offset |
| **Run** | One client onboarding instance | ID, workspace ID, client label, workflow version, start date, state, activated/closed times |
| **Run step** | Snapshot of a workflow step for a client | ID, run ID, order, title, instructions, owner ID, due date, execution state, completion fields |
| **Exception** | Structured blocked/skipped/reopen context | Run-step ID, type, reason, next-action note, created/resolved times |
| **External link** | Pointer to a record outside the product | Parent type/ID, label, HTTPS URL |
| **History event** | Append-only operational event | Entity IDs, event type, actor, timestamp, non-sensitive structured metadata |
| **Reminder attempt** | Record of a coordinator-triggered email | Run-step ID, recipient reference, requested time, provider result, failure category |

### 8.2 Ownership and versioning rules

- A live step always resolves to one owner record.
- Owner-slot labels belong to the template; named people are mapped when the run is created.
- A run stores a snapshot of step text, order, owner mapping, and calculated due dates.
- A workflow save creates a new version for future runs rather than mutating existing runs.
- History is operational, not represented as a certified compliance audit log.

### 8.3 Integration boundaries

| System / boundary | MVP use | Explicit limit |
|---|---|---|
| **Cloudflare application runtime** | Serve the web UI and server logic | No production deployment outside the agreed Cloudflare-native boundary. |
| **Cloudflare-native datastore** | Store workspace, workflow, run, ownership, link, and history metadata | No native file contents or linked-record contents. |
| **Authentication** | Coordinator sign-in and session management | One coordinator per pilot workspace; no enterprise identity features. |
| **Transactional email provider** | Send coordinator-confirmed reminders | No campaigns, sequences, scheduled reminders, or inbound email processing. |
| **Notion, Drive, billing, Zapier, other tools** | Store labeled HTTPS links only | No OAuth, API calls, metadata fetching, permission synchronization, or connectors. |
| **CSV** | Generate portable current-state reports | Export only; no import or migration. |
| **Analytics / logs** | Measure funnel and diagnose failures | Never include raw URLs, instructions, exception text, contact email, or reminder body. |

### 8.4 Data handling boundary

The MVP may store:

- Agency/workspace name.
- Coordinator identity.
- Client label chosen by the coordinator.
- Owner name, category, and optional email.
- Workflow and step text.
- Due dates, states, exceptions, timestamps, and reminder result metadata.
- HTTPS links to external records.

The MVP must not store:

- Uploaded documents or attachments.
- Contents retrieved from external links.
- Billing credentials or copied billing records.
- Historical client imports.
- Bookkeeping source documents.
- Secrets embedded in analytics or logs.

---

## 9. Edge cases and risks

### 9.1 Edge cases

| Item | Required handling |
|---|---|
| Negative due offset for pre-kickoff work | Permit integer negative offsets and show the calculated date in preview. |
| Due date is already past at activation | Warn clearly but permit activation if the PM confirms; the step becomes Overdue immediately. |
| Owner is changed after reminders or work began | Preserve the old owner in history and show the new current owner. |
| Template step is removed | Existing run snapshots retain the step. |
| Completed step is reopened | Require a reason; clear current completion state while preserving the prior completion event and time. |
| Blocked step passes due date | Show both Blocked execution state and Overdue due state. |
| Client onboarding is cancelled | Coordinator may mark remaining steps Skipped with a shared cancellation reason, then close the run. No silent bulk completion. |
| External record permissions expire | The app retains the link but makes no claim that it remains accessible. |
| Duplicate reminder submission | Use an idempotency key so one confirmation creates at most one provider request/event. |
| CSV spreadsheet injection | Prefix or otherwise neutralize cells beginning with `=`, `+`, `-`, or `@` while preserving the visible value. |
| Multiple browser tabs edit the same step | Detect stale version on save and ask the coordinator to refresh or consciously overwrite; never silently lose a newer update. |
| Timezone boundary around midnight | Calculate due state in the configured workspace timezone and display that timezone near dates. |

### 9.2 Product and delivery risks

| Risk | Impact | Mitigation / decision |
|---|---|---|
| The strongest evidence comes from one interview | Product may overfit one agency | Pilot with that customer first, then verify the same job with the second volunteer before expanding scope. |
| Agency workflows vary significantly | One reusable template may feel too rigid | Permit editable ordered steps, owner slots, and calendar-day offsets; defer branching and multiple templates. |
| Users expect native integrations because their work spans many tools | “Links only” may disappoint | Set expectation in onboarding and measure whether links plus coordination are sufficient before building connectors. |
| A single coordinator may become a status bottleneck | Run state may become stale | Measure update latency and requests for assignee self-service; do not pre-build a portal. |
| External URLs can themselves be sensitive | A leaked account could expose destinations | Strong workspace authorization, no URL logging/emailing, no metadata fetch, and documented deletion/restore procedures. |
| Reminder email may be unwanted or undeliverable | Trust and support burden | Coordinator confirms each send; no scheduled messages; record provider result; require an owner email. |
| Workflow setup becomes consulting work | Solo-founder support burden grows | Time-box one guided setup for each pilot, use the resulting workflow as product input, and decline migration/custom integration requests. |
| $29 may be too low, too high, or irrelevant | Revenue model remains unproven | Ask for a real payment after use; do not infer WTP from Zapier spend or waitlist conversion. |
| Warm and cold demand data are accidentally pooled | Acquisition signal becomes misleading | Maintain separate funnel labels and reports for qualified cold and warm traffic. |
| Bookkeeping pain draws the roadmap toward compliance | Six-week MVP becomes unshippable and wedge becomes incoherent | Keep bookkeeping out of product copy, data model promises, requirements, and pilot recruitment. |
| Event history is mistaken for certified auditing | Creates compliance expectations | Describe it as operational history only; make no audit or compliance certification claims. |

---

## 10. Milestones and indie delivery plan

| Milestone | Timing | Outcome | Exit criteria |
|---|---|---|---|
| **M0 — Pilot and data-boundary lock** | Week 1 | Confirm the first design partner’s actual workflow, owner slots, step volume, reminder sender identity, and permitted client metadata. Spike authentication, datastore, and outbound email boundaries. | First pilot approves the forward-looking workflow; no migration is required; data boundary and first reminder test are accepted. |
| **M1 — Smallest vertical slice** | Week 2 | A signed-in coordinator can use a seeded workflow to create one client run, assign owners and due dates, change one step to Complete or Blocked, and see the event in history. | End-to-end path persists correctly in production-like Cloudflare infrastructure; cross-workspace authorization tests pass. |
| **M2 — Operational runbook** | Weeks 3–4 | Complete workflow editor, snapshot/version behavior, draft/active/closed runs, due-state views, exception handling, external links, and missed-step filtering. | All FR-002 through FR-008, FR-010, and FR-012 acceptance criteria pass with seeded data. |
| **M3 — Reminder, export, and hardening** | Week 5 | Add manual reminder delivery, CSV export, analytics, responsive/accessibility pass, backup/restore check, and safe logging. | FR-009, FR-011, and all P0 NFR checks pass; no sensitive URLs appear in logs, analytics, or test emails. |
| **M4 — Guided real-client pilot** | Week 6 | Onboard the strongest design partner and activate the next eligible real-client run. Admit the second volunteer after P0 blockers are resolved. | A real run is active, baseline and setup time are recorded, support issues are triaged, and no unresolved data-loss/security blocker exists. |

### 10.1 Smallest vertical build slice

Build only this end-to-end spine first:

1. Sign in one pilot coordinator.
2. Load one seeded workflow with three configurable steps.
3. Create a run with a client label and start date.
4. Assign a named owner and calculated due date to each step.
5. Activate the run.
6. Mark one step Complete and another Blocked with a reason.
7. Show both transitions in an append-only run history.

This slice deliberately excludes reminders, CSV, polished filtering, multiple templates, and billing. It validates the hardest product invariant—template snapshot to owned live work—before adding surface area.

### 10.2 Build-versus-buy boundaries

- Use a proven authentication approach rather than designing password security.
- Use a transactional email provider for reminder delivery.
- Generate CSV directly from application data; do not add a reporting service.
- Use Cloudflare-native runtime, storage, scheduling-compatible primitives, and observability where appropriate.
- Do not buy or build connector infrastructure during the pilot.

### 10.3 Expected support burden

The largest support risks are workflow customization, owner mapping, destination-link permissions, and requests to import old data. Each pilot receives one time-boxed workflow setup session. Requests for migration, connectors, custom compliance behavior, or bespoke branching are logged as evidence but not implemented during the six-week MVP.

---

## 11. Launch, metrics, and feedback

### 11.1 Beta audience and sequence

1. Start with the strongest interview participant on one real client.
2. Add the second volunteered cold-traffic pilot once the first run demonstrates stable P0 behavior.
3. Recruit additional agency PMs from qualified cold leads only if needed to reach the price-test sample.
4. Track warm-list participants separately in all reporting.

### 11.2 Baseline capture

Before the first live run, record for each pilot:

- How long their last comparable onboarding setup took.
- Which tools required repeated copying.
- How they assigned responsibility.
- How they found late or blocked steps.
- Whether a second onboarding is expected within the evaluation window.

The only existing numeric baseline is approximately 45 minutes for the strongest respondent’s last three onboardings.

### 11.3 Launch metrics

Targets are directional because the initial sample is very small.

| Metric | Definition | Target / decision signal | Window |
|---|---|---|---|
| **Real-client activation** | A volunteered pilot activates a run containing real client coordination data and all required owners/dates | First design partner activates one run; aim for both volunteered pilots when each has an eligible client | By end of week 6 or within 7 days of an eligible onboarding |
| **Time to ready** | Time from selecting **Start onboarding** to activating a run from the configured template | Median ≤15 minutes; investigate any run >30 minutes | First three real runs |
| **Ownership completeness** | Active steps with exactly one owner and due date | 100%, enforced as a product invariant | Every activation |
| **Silent-miss rate** | Overdue steps with no completion or explicit exception update by 24 hours after due date | <10% of due steps | First 30 pilot days |
| **Exception visibility** | Blocked/skipped work with a recorded reason | 100%, enforced by validation | Every pilot run |
| **Workflow reuse** | An eligible pilot starts a second real run from the same workflow | At least one eligible pilot reuses it without founder reconstruction | Within 30 days of its next client |
| **Reminder utility** | Sent reminders that the PM reports replaced manually drafting/copying a message | Positive on at least 3 reminder events across pilots; otherwise reassess the feature | First 30 pilot days |
| **CSV portability** | Pilot can produce and open the requested run export with expected rows | Successful for both active pilots when tested | Before pilot review |
| **Continuation willingness** | Pilot accepts and completes a real $29 continuation payment after using a live run | At least one of the first two pilots; expand to five completed-use price asks before concluding price failure | End of each pilot |
| **Operational integrity** | P0 data-loss or cross-workspace exposure incidents | Zero; any incident pauses the pilot | Continuous |
| **Cold funnel continuity** | Qualified cold waitlist and pilot-volunteer rates | Continue reporting against the current 9.0% signup and 0.67% visitor-to-volunteer baselines; do not pool warm traffic | Each comparable cold cohort |

### 11.4 Kill and pivot triggers

| Trigger | Action |
|---|---|
| **No live use:** Neither volunteer activates a real-client run after each has an eligible onboarding and receives one guided setup session. | Stop feature expansion. Interview for whether the barrier is trust, timing, workflow fit, or insufficient value; reconsider the agency PM wedge before recruiting broadly. |
| **Setup remains heavy:** Median template-to-active time exceeds 30 minutes across three real runs, or both initial pilots say copying effort is unchanged or worse. | Simplify owner mapping and run creation. If copying remains inherent to the job, pivot the product mechanism rather than adding features. |
| **No reuse:** Among pilots with a second eligible onboarding within 30 days, none reuses the workflow. | Treat the reusable-runbook retention hypothesis as failed; investigate whether onboarding is too bespoke or the pain is episodic. |
| **State remains stale:** More than 25% of due steps across the first three completed runs are updated only after they are more than 24 hours overdue, and pilots attribute this to owners lacking access. | Reassess the single-coordinator model; test a narrowly scoped owner interaction before considering any full portal. |
| **Price rejection:** After five qualified agency PMs have completed at least one real run, zero accepts a real $29 continuation charge or equivalent paid commitment. | Reject the current price/package hypothesis. Test packaging and economic buyer before building billing or premium features; do not describe WTP as validated. |
| **Security or data integrity failure:** Any cross-workspace exposure or unrecoverable P0 data loss occurs. | Pause the pilot immediately, fix and verify the issue, then obtain pilot approval before resuming. |
| **Integration demand dominates:** Both initial pilots refuse continued use specifically because links cannot replace native connectors. | Reassess whether one narrow integration creates the core outcome. Do not build a marketplace. |
| **Agency wedge underperforms:** Product-use triggers fail after the guided pilot cycle. | Do not automatically merge in bookkeeping. Return that segment to separate discovery and compliance scoping before considering a pivot. |

### 11.5 Feedback cadence

- Conduct a 15-minute review after the first run is activated.
- Conduct another review when the run closes or after 14 days, whichever comes first.
- Review event history alongside the PM rather than relying only on recall.
- Ask explicitly what work still occurred in email, Notion, Drive, billing, or Zapier and why.
- Present the $29 continuation offer only after real use and record accepted, declined, or pending without reinterpreting polite interest as payment intent.

---

## 12. Assumptions and open questions

### 12.1 Assumptions log

| ID | Assumption | Impact if wrong |
|---|---|---|
| **A-001** | One authenticated coordinator can operate each pilot workspace. | May require basic teammate or owner interaction earlier than planned. |
| **A-002** | One reusable workflow is sufficient to test repeat value. | If agencies need multiple distinct onboarding types immediately, the product may underrepresent value. |
| **A-003** | Calendar-day offsets are adequate for MVP; business-day calendars are not required. | Due dates may require manual adjustment and reduce perceived time savings. |
| **A-004** | Named owners without product accounts still create useful accountability. | Status may remain stale if the PM cannot obtain updates efficiently. |
| **A-005** | Coordinator-triggered reminders are enough to test reminder value before scheduled automation. | Pilots may continue to forget follow-ups despite a clear due-state view. |
| **A-006** | Pilots are permitted to store client labels, assignee contact details, and external record URLs in the product. | A stricter policy could block live use or require further minimization. |
| **A-007** | The first pilot’s actual workflow can be expressed as an ordered checklist with dates and exceptions, without branches or dependencies. | Conditional work could force a narrower workflow choice or a product-mechanism change. |
| **A-008** | $29/month is a credible continuation test price, not a validated price. | The product may need different packaging, buyer, or economics. |
| **A-009** | The first pilots will have a new client during the evaluation window. | Lack of natural onboarding opportunities may delay activation and reuse conclusions. |

### 12.2 Open product questions

1. What exact steps, owner slots, and offsets make up the first pilot workflow?
2. What is the typical and maximum number of steps and owners in a real agency onboarding?
3. May reminders be sent from a product address with the PM as reply-to, or must they originate from the agency’s domain?
4. What consent or internal policy does each pilot require before an owner email is used?
5. How long should closed-run metadata and event history be retained, and what deletion controls do pilots expect?
6. Is client name acceptable as the run label, or should the UI recommend a non-sensitive identifier?
7. Does the first pilot have a second onboarding expected soon enough to observe reuse?
8. Which outcome would make the PM pay $29: time saved, fewer misses, client experience, or replacing another tool?
9. Are calendar-day deadlines acceptable, or do pilots require business days before they will use a live run?
10. Does manual reminder usage justify scheduled reminders, or is visibility alone sufficient?

---

## 13. Rejected ideas for this MVP

| Idea | Reason for rejection |
|---|---|
| Import prior Notion pages or spreadsheets | Conflicts with the no-migration adoption constraint and adds mapping/support burden. |
| Store client files directly | Violates the external-record boundary and increases security scope. |
| Connect Notion, Drive, billing, and Zapier | No evidence yet identifies one connector as necessary; a marketplace is incompatible with six weeks. |
| Give every owner an account | Creates invitations, permissions, support, and portal expectations before owner participation is validated. |
| Generate workflows with AI | Does not address the strongest demonstrated failure—unclear ownership—and introduces unnecessary variability. |
| Add bookkeeping workflows | Combines a security-sensitive segment with a different agency wedge before either is validated. |
| Build Stripe subscription management | Willingness to pay is still unknown; use a manual invoice or hosted payment link for the continuation test. |
| Automate recurring reminders | Start with coordinator-triggered messages to learn desired recipients, frequency, content, and consent. |
| Build native mobile apps | Primary work is desktop coordination; responsive web is sufficient for the MVP test. |

---

## Decisions to confirm before implementation

1. Confirm that the MVP has one signed-in coordinator while owners are non-user assignee records.
2. Confirm that “simple reminders” means coordinator-triggered email, with scheduled reminders deferred.
3. Confirm that the pilot is limited to one reusable workflow and forward-looking client runs, with no import path.

## Best next implementation slices

1. Authentication, workspace boundary, and the one-workflow-to-live-run vertical slice.
2. Execution state, exception validation, due-state calculation, and append-only history.
3. External links, manual reminders, CSV export, and pilot instrumentation.

No further broad market validation is required before the first real-client pilot. Pricing should return to validation immediately after live use, and the bookkeeping segment requires separate discovery before any product work.
