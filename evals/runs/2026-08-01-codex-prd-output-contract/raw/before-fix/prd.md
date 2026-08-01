# PRD: Ownership-Aware Client Onboarding Runbook

| Field | Value |
|---|---|
| Status | Draft for review |
| Owner | Founder / solo developer |
| Last updated | 2026-08-01 |
| Version | 0.1 |
| Primary persona | Operations lead or agency owner at a small service agency |
| Platform | Desktop-first responsive web application |
| Delivery constraint | Six-week solo-developer MVP |
| Related evidence | User-provided smoke-test and discovery summary |

## Revision history

| Version | Date | Summary |
|---|---|---|
| 0.1 | 2026-08-01 | Initial six-week MVP PRD |

## 1. Overview

### 1.1 One-liner

A lightweight web runbook for small agencies to assign ownership, due dates, external records, and exceptions across repeatable client-onboarding steps without becoming a client portal, file store, or bookkeeping system.

### 1.2 Problem statement

Small agencies often coordinate client onboarding through spreadsheets, documents, chat, and external systems. These tools can list tasks, but they make it difficult to answer:

- Who owns each step?
- What is due or overdue?
- Which step was missed?
- Was a step completed, blocked, or deliberately excepted?
- Where is the external source record?
- Can the same process be reused for the next client?

The cost is follow-up work, uncertain accountability, and onboarding steps being discovered late rather than managed explicitly.

Discovery supports the need for explicit owners, reusable steps, external record links, and CSV. It also establishes an important boundary: sensitive file storage and bookkeeping should remain in separate systems.

### 1.3 Product choices

| Decision | MVP choice |
|---|---|
| Primary user | Small-agency owner or operations lead responsible for client onboarding |
| Primary job | Run a repeatable onboarding process without losing ownership or missed-step history |
| Core object | A reusable workflow instantiated as a client-specific run |
| Collaboration model | One authenticated agency operator; owners are assignable records, not product users |
| MVP capacity | One workflow definition and one active run at a time per workspace |
| Reminder model | Manual preparation and logging; no automatic delivery |
| External records | URL references only; the product does not fetch or store linked content |
| Commercial model | Pilot access; $29/month remains an unvalidated hypothesis |

**Assumption:** One active run is enough to validate the ownership and missed-step value proposition. Supporting concurrent client onboarding is deferred until pilot behavior demonstrates the need.

**Assumption:** A desktop-first web application matches the primary planning and operations context.

### 1.4 Goals

#### User outcomes

1. Turn a repeatable onboarding checklist into an owned, due-aware workflow.
2. See the current state of every step in one place.
3. Complete steps or record explicit exceptions without erasing what was missed.
4. reuse the workflow for a later client run.
5. Reference records kept in existing file, CRM, contract, and bookkeeping systems.

#### Business outcomes

1. Get both pilot volunteers to attempt the core workflow.
2. Determine whether ownership and missed-step history are materially better than the users’ current spreadsheet or document.
3. Observe whether at least one pilot reuses the workflow for a second onboarding.
4. Test willingness to pay separately from product usage.
5. Decide within six weeks whether to continue, reshape the wedge, or stop.

### 1.5 Non-goals

The MVP will not include:

- Client or contractor portals
- File upload, storage, previews, or document management
- Bookkeeping, invoices, financial ledgers, or accounting records
- Historical-data migration services
- CRM, email, accounting, storage, calendar, or automation connectors
- AI-generated workflows, summaries, recommendations, or reminders
- Native mobile applications
- Enterprise roles, approval hierarchies, SSO, or granular access control
- Compliance certifications or regulated-industry compliance claims
- Automatic reminder delivery
- Multiple workflows or concurrent live runs
- Workflow branching, conditional automation, or dependency graphs
- Payments or subscription enforcement during the initial pilot

### 1.6 Success metrics

These are proposed MVP decision thresholds, not previously validated benchmarks.

| Metric | Definition | Six-week signal |
|---|---|---|
| Pilot activation | Volunteer creates a workflow and starts a live run | 2 of 2 volunteers within seven days of access |
| Operational adoption | Activated pilot records at least five meaningful step-state changes across at least two sessions | At least 1 of 2 pilots |
| Core run completion | Live run reaches a terminal state with every step completed or accepted as an exception | At least one completed run |
| Workflow reuse | A completed workflow is instantiated for a subsequent client | At least one pilot attempts a second run within 30 days |
| Missed-step utility | Pilot views or uses the retained history of an overdue step | At least one observed occurrence plus useful qualitative feedback |
| Paid intent | Qualified user agrees to pay or makes a concrete paid commitment after using the product | Measured separately; no existing evidence |
| Reliability | P0 journeys finish without founder database repair | 100% of pilot runs |

Page views and total signups are acquisition context, not proof of product value or retention.

## 2. Users and context

### 2.1 Primary persona

| Attribute | Detail |
|---|---|
| Label | Small-agency operations lead |
| Who they are | Owner, account lead, or operations generalist at a small service agency |
| Context | Coordinates repeatable onboarding across agency staff, clients, and external systems |
| Primary job | Know who owes what, what is late, and whether onboarding is genuinely complete |
| Current alternatives | Spreadsheet, document checklist, project-management board, email, chat, memory |
| Trigger | A client onboarding stalls, responsibility is disputed, or a missed step is found late |
| Desired outcome | A defensible operational record without adopting a heavyweight system |
| Anti-persona | Enterprise procurement teams, regulated workflow administrators, or teams requiring client portals and complex permissions |

### 2.2 Step owners

A step owner is a person named as responsible for a step. In the MVP:

- Owners do not need product accounts.
- Owners may be internal agency staff, the client, or another external party.
- Assigning an owner does not grant access.
- The authenticated operator remains responsible for updating states and sending reminders.

This preserves explicit ownership without introducing multi-user permissions or portals.

### 2.3 Use context

The operator primarily uses the application on desktop during onboarding setup, status review, and follow-up. Mobile-responsive viewing is acceptable, but mobile-specific workflows are out of scope.

## 3. Solution

### 3.1 Value proposition

For small-agency operators who coordinate client onboarding across spreadsheets and external systems, this product is an ownership-aware runbook that makes responsibility, deadlines, completion, exceptions, and missed steps explicit. Unlike a generic checklist, it retains operational history; unlike an all-in-one agency platform, it leaves files and bookkeeping in their appropriate systems.

### 3.2 Product principles

1. **Every actionable step has one explicit owner.**
2. **A missed step remains visible after the immediate problem is resolved.**
3. **Exceptions are recorded, not disguised as completion.**
4. **External systems remain the source of truth for files and financial records.**
5. **Manual control precedes automation.**
6. **One reliable workflow before broader workflow management.**

### 3.3 Scope summary

| In scope: MVP/P0 | Out of scope |
|---|---|
| One reusable workflow | Workflow library |
| One active client run | Concurrent runs |
| Ordered reusable steps | Branching and dependencies |
| Owner and due date per step | User invitations and role management |
| Pending, completed, and exception states | Custom state builders and approvals |
| Upcoming, due-today, and overdue views | Calendar integration |
| Manual reminder preparation and history | Automated reminder delivery |
| External record URLs | Uploaded or mirrored records |
| CSV import and export | Managed migration |
| Append-only missed-step history | General-purpose audit/compliance product |

## 4. P0 user journeys and states

### Journey A — Create the reusable workflow

1. The operator creates the workspace’s workflow.
2. The operator names the workflow.
3. The operator adds or imports ordered steps.
4. Each step receives a title, default owner, optional due-offset, and optional external-record link.
5. The operator reorders or edits steps.
6. The operator saves the workflow and sees that it is ready to start.

**Success state:** The workflow has at least one valid step and can produce a run.

**Failure and recovery:** Invalid CSV rows or URLs are identified by row or field without discarding valid unsaved input.

### Journey B — Start a client onboarding run

1. The operator selects the workflow.
2. The operator enters a client label and start date.
3. The system copies the workflow steps into a run snapshot.
4. Due dates are calculated from step offsets where configured.
5. The operator reviews owners and dates.
6. The operator starts the run.

**Success state:** The run is live and its steps are independent of later workflow edits.

**Failure and recovery:** If a live run already exists, the system explains that it must be completed or archived before another can start.

### Journey C — Operate the live run

1. The operator opens the live run.
2. Steps are shown in workflow order with owner, due state, execution state, and external link.
3. The operator marks a step completed or records an exception.
4. If follow-up is needed, the operator prepares a manual reminder and records that it was sent.
5. The system updates the run summary and retains state-change history.
6. When all steps are terminal, the operator completes the run.

**Success state:** Every step is either completed or has an accepted exception.

**Failure and recovery:** Failed saves retain the user’s input and expose a retry action. Duplicate submissions do not create duplicate events.

### Journey D — Review a missed step

1. An unresolved step passes its due date.
2. The system changes its derived due state to overdue.
3. The system records the first overdue transition as a history event.
4. The operator later completes the step or records an exception.
5. The current run no longer treats it as unresolved.
6. The history still shows that the step was previously missed and how it was resolved.

**Success state:** Resolution does not erase the overdue event.

### Journey E — Reuse the workflow

1. The operator completes or archives the current run.
2. The reusable workflow remains available.
3. The operator starts a new run with a new client label and start date.
4. New run steps are copied from the current workflow definition.
5. The previous run remains read-only and available for history review.

**Success state:** Reuse requires no manual reconstruction of the checklist.

### State model

#### Workflow state

- `draft`: Editable but not ready to instantiate.
- `ready`: Valid and available to start.
- `archived`: Retained but cannot start a new run.

#### Run state

- `draft`: Created but not started.
- `live`: Actively tracked.
- `completed`: All steps terminal; read-only.
- `archived`: Manually closed; read-only, with closure reason.

#### Step execution state

- `pending`: Still requires action.
- `completed`: Finished with completion timestamp.
- `exception`: Not completed normally; requires reason and disposition.

An exception disposition is either:

- `open`: Still blocks run completion.
- `accepted`: Explicitly accepted and considered terminal.

#### Derived due state

For non-terminal steps:

- `no_due_date`
- `upcoming`
- `due_today`
- `overdue`

Completed and accepted-exception steps retain their due date and history but do not appear in the unresolved overdue count.

## 5. Requirements

### 5.1 Functional requirements

| ID | Requirement | Priority | Acceptance criteria |
|---|---|---|---|
| FR-001 | The operator can access a private workspace. | P0 | An unauthenticated visitor cannot read or change workflow or run data; an authenticated operator can access only their workspace. |
| FR-002 | The workspace supports one reusable workflow. | P0 | The operator can create, name, edit, reorder, and archive one workflow; the system prevents creation of a second active workflow and explains the limit. |
| FR-003 | The workflow contains ordered reusable steps. | P0 | Each step has a title, position, owner, optional due offset, and optional external link; a blank title or owner cannot be saved. |
| FR-004 | Owners are managed as explicit records. | P0 | The operator can create and select an owner with a display name and optional contact detail; assigning an owner never creates an account or grants access. |
| FR-005 | The operator can start one live run from the workflow. | P0 | Starting a run copies the current step definitions, records client label and start date, and blocks a second simultaneous live run. |
| FR-006 | A run is a snapshot of its workflow. | P0 | Editing the reusable workflow after a run starts does not silently change that run’s step titles, owners, positions, offsets, or links. |
| FR-007 | Each run step exposes its owner and due state. | P0 | The live-run view displays owner, execution state, due date, and derived due state for every step; due state changes correctly across the workspace date boundary. |
| FR-008 | The operator can adjust a run step’s owner and due date. | P0 | Changes affect only the live run, save their timestamp in history, and do not modify the workflow default. |
| FR-009 | The operator can complete a step. | P0 | Completing a pending or open-exception step records actor and timestamp, removes it from unresolved counts, and appends a history event. |
| FR-010 | The operator can record and resolve an exception. | P0 | An exception requires a non-empty reason; it can remain open, return to pending, or be accepted; each transition is retained in history. |
| FR-011 | The system records missed-step history. | P0 | The first time a non-terminal step becomes overdue, exactly one overdue event is recorded; completing, rescheduling, or excepting the step does not delete that event. |
| FR-012 | The operator can prepare and log a manual reminder. | P0 | For a pending step, the system presents owner, client, step, and due date in editable reminder text; the operator can copy or open a `mailto:` action and explicitly record the reminder timestamp. No message is sent automatically. |
| FR-013 | Steps can reference external records. | P0 | A step accepts a valid `http` or `https` URL and optional label; opening it uses a new browser context; the application does not fetch, preview, cache, or authenticate to the target. |
| FR-014 | The operator can import workflow steps from CSV. | P0 | A documented template supports title, owner, due offset, link label, and URL; validation reports row-specific errors; no workflow is partially overwritten without confirmation. |
| FR-015 | The operator can export data to CSV. | P0 | The workflow and each run can be exported with step order, owner, dates, current state, exception details, external links, and missed-step indicator; exported rows exclude credentials and file contents. |
| FR-016 | The operator can complete or archive a run. | P0 | Normal completion is allowed only when all steps are completed or accepted exceptions; archive requires a reason; both actions preserve a read-only history. |
| FR-017 | The operator can review run history. | P0 | The run exposes chronological events for creation, owner/due changes, overdue transitions, reminders, completions, exceptions, and closure. |
| FR-018 | The operator can reuse the workflow after closing a run. | P0 | Once no run is live, the operator can create another run from the same workflow while the previous run remains accessible and unchanged. |
| FR-019 | The product records essential pilot events. | P0 | Workflow creation, run start, step-state change, overdue-history view, reminder log, CSV import/export, run closure, and second-run start are recorded with workspace and timestamp. |

### 5.2 Non-functional requirements

| ID | Requirement | Priority | Acceptance criteria or validation |
|---|---|---|---|
| NFR-001 | Sensitive files remain outside the product. | P0 | No upload endpoint, file input, blob-storage binding, attachment field, URL-content fetcher, or file-preview service exists in the MVP. |
| NFR-002 | Bookkeeping remains outside the product. | P0 | No amount, invoice, payment, account code, ledger, balance, or transaction field exists; bookkeeping systems may only be referenced by URL. |
| NFR-003 | Workspace data is private in transit and at rest through the selected managed platform. | P0 | Production uses HTTPS; unauthenticated and cross-workspace access tests fail; secrets are not stored in source control or client bundles. |
| NFR-004 | State mutations are resistant to accidental duplication. | P0 | Retrying completion, exception, reminder-log, and run-start requests does not create duplicate terminal transitions or overdue events. |
| NFR-005 | P0 screens are keyboard operable. | P0 | Workflow creation, run start, step completion, exception recording, reminder logging, and CSV export can be completed without a pointing device; controls have programmatic labels. |
| NFR-006 | Core views remain usable at pilot scale. | P0 | With a 100-step workflow and 1,000 history events, the run page becomes interactive within three seconds on a typical broadband desktop connection in production preview testing. |
| NFR-007 | Data-boundary copy is explicit. | P0 | Link and CSV interfaces state that sensitive files, secrets, and bookkeeping data should remain in the source system; test review confirms the warning appears before first use. |
| NFR-008 | Pilot failures are diagnosable without logging sensitive content. | P0 | Errors include workspace, operation, timestamp, and opaque record IDs; logs omit reminder bodies, owner contact details, URLs, CSV contents, and exception text. |

### 5.3 Analytics events

| Event | Trigger | Properties |
|---|---|---|
| `workflow_created` | First valid workflow saved | Step count, creation method |
| `workflow_csv_imported` | Valid CSV committed | Valid rows, rejected rows |
| `run_started` | Draft becomes live | Step count, client identifier token |
| `step_state_changed` | Execution state changes | From, to, due state |
| `step_became_overdue` | First overdue transition | Step identifier, days overdue |
| `missed_history_viewed` | Operator opens missed-step history | Run identifier |
| `manual_reminder_logged` | Operator confirms reminder | Due state, channel action |
| `run_closed` | Run completed or archived | Closure type, step totals |
| `workflow_reused` | A second run starts | Days since prior run closed |
| `csv_exported` | Export finishes | Workflow or run export |

Analytics should use opaque identifiers and categorical properties rather than client names, owner contacts, URLs, or free text.

## 6. UX and content notes

### 6.1 Information architecture

- Sign in
- Workflow
  - Workflow editor
  - CSV import
  - Workflow export
- Current run
  - Run summary
  - Ordered step list
  - Step detail/history
  - Manual reminder dialog
- Previous runs
  - Read-only run detail
  - Run CSV export
- Settings
  - Workspace date/time zone
  - Owners
  - Data-boundary guidance

### 6.2 Critical empty and error states

- **No workflow:** Explain that the first action is to define or import the repeatable onboarding steps.
- **Workflow invalid:** Identify missing titles, owners, or malformed links by step.
- **No live run:** Offer “Start client onboarding” once the workflow is ready.
- **Second live run attempted:** Explain the MVP limit and offer links to the current run or closure action.
- **No due date:** Show “No due date,” never imply that the step is on schedule.
- **Invalid CSV:** Preserve the selected file locally where possible and report row-level errors before committing.
- **Failed mutation:** Retain user-entered exception or reminder text and provide retry.
- **External link:** Warn against placing secrets or sensitive data in the product.
- **All steps terminal:** Present a clear “Complete run” action and summary.

### 6.3 Key copy

- **Onboarding value proposition:** “Know who owns every onboarding step—and keep a record when one is missed.”
- **Workflow empty state:** “Create the steps you repeat for every client. Files and financial records stay in the systems you already use.”
- **Reminder action:** “Prepare reminder”
- **Reminder confirmation:** “Record as sent”
- **Exception action:** “Record exception”
- **Overdue history label:** “Previously overdue”
- **External-link guidance:** “Paste a link to the source record. Do not upload or copy sensitive content here.”
- **Pricing:** Do not present “$29/month” as established pricing during the product pilot.

## 7. Data and integrations

### 7.1 Core entities

| Entity | Purpose | Conceptual fields |
|---|---|---|
| Workspace | Agency’s private boundary | ID, owner account, name, time zone |
| OperatorAccount | Authenticated user | ID, workspace ID, authentication-provider reference |
| Owner | Responsible person metadata | ID, display name, optional email, optional organization/type |
| Workflow | Reusable process | ID, name, state, version timestamps |
| WorkflowStep | Reusable step definition | ID, workflow ID, position, title, owner ID, due offset, link label, external URL |
| Run | Client-specific execution | ID, workflow snapshot/version, client label, start date, state, closure reason/timestamps |
| RunStep | Snapshot and current state | ID, run ID, copied definition fields, execution state, exception disposition, due date |
| ReminderLog | Manual follow-up record | ID, run-step ID, timestamp, operator ID, channel action |
| HistoryEvent | Append-only operational history | ID, entity ID, event type, timestamp, actor, structured before/after metadata |
| PilotEvent | Minimal product analytics | Event type, opaque identifiers, categorical properties, timestamp |

### 7.2 CSV contract

The documented import template contains:

- `position`
- `step_title`
- `owner_name`
- `owner_email` — optional
- `due_offset_days` — optional integer
- `link_label` — optional
- `external_url` — optional valid `http` or `https` URL

CSV import is a self-service workflow creation path, not a founder-led migration service.

### 7.3 Data boundaries

#### The product stores

- Workflow and run names
- Client label
- Owner name and optional contact detail
- Step descriptions
- Due dates and offsets
- External URL and label
- Execution and exception states
- Reminder timestamps
- Operational history
- Minimal analytics events

#### The product does not store

- Uploaded files or file bytes
- Copies or previews of external pages
- Passwords, API tokens, or external-system credentials
- Invoice amounts, payments, bank details, financial transactions, or ledgers
- Bookkeeping source data
- Regulated compliance evidence
- Client portal messages
- Automatically imported data from third-party systems

Because free-text fields and URLs can still contain sensitive information, the UI must provide data-minimization guidance. The MVP does not claim suitability for regulated or compliance-controlled records.

### 7.4 Integrations

| System | Purpose | MVP | Boundary |
|---|---|---:|---|
| Managed authentication | Private operator access | Yes | Authentication only |
| Browser clipboard / `mailto:` | Manual reminder handoff | Yes | No delivery tracking or mailbox access |
| CSV | Import/export | Yes | User-initiated local transfer |
| External URLs | Source-record navigation | Yes | No fetching, indexing, previewing, or credential storage |
| Email provider API | Automatic messages | No | Excluded |
| Storage/CRM/accounting connectors | Synchronization | No | Excluded |
| Stripe | Payment | No | Pricing is still under validation |

### 7.5 Permissions

The MVP has one workspace operator. Owners are metadata and cannot sign in.

No client, employee, administrator, auditor, or enterprise role model is included.

## 8. Edge cases, risks, and open questions

### 8.1 Edge cases

| Item | Impact | Required handling |
|---|---|---|
| Due date passes while nobody is signed in | Missed event might be absent | Derive overdue state on read and append the overdue event idempotently |
| Step is rescheduled after becoming overdue | History could be rewritten | Preserve original overdue event and record the due-date change |
| Step completed after being overdue | Miss could disappear | Keep “previously overdue” history |
| Exception accepted without explanation | Weak accountability | Require a reason |
| Workflow changes during a run | Existing run becomes inconsistent | Use immutable run snapshots |
| Duplicate form submission | Duplicate history/reminders | Use mutation idempotency or transition guards |
| External URL contains confidential tokens | Sensitive data exposure | Show warning; do not fetch or log URL contents |
| CSV contains formulas | Spreadsheet injection on export | Escape cells beginning with formula-control characters |
| Owner is removed from defaults | Existing records break | Preserve historical owner snapshots |
| Run is archived with pending steps | Ambiguous ending | Require archive reason and retain unresolved states |
| Local date differs from workspace date | Wrong due state | Calculate using workspace time zone |
| Pilot asks for another concurrent run | Scope pressure | Record demand; do not add until core value is demonstrated |

### 8.2 Product and delivery risks

| Risk | Impact | Mitigation |
|---|---|---|
| Generic task tools are “good enough” | Weak willingness to switch | Test missed-step history and explicit exceptions in real onboarding |
| One-live-run limit blocks pilot usage | Pilot cannot use product naturally | Recruit pilots that can sequence tests; treat repeated requests as scope evidence |
| Manual reminders feel like extra work | Low adoption | Make copy/mail handoff fast and measure use before automating |
| CSV becomes migration support | Consumes solo-founder time | Publish one strict template and reject unsupported formats |
| Free text collects sensitive content | Privacy/support burden | Minimize fields, add warnings, avoid logging content |
| Two pilots produce noisy conclusions | False confidence | Use behavior to shape product, not claim market validation |
| $29 anchors pricing prematurely | Invalid revenue conclusion | Ask for payment explicitly after hands-on value is demonstrated |
| History model becomes an audit platform | Scope expansion | Limit history to core run events; make no compliance claim |

### 8.3 Open product questions

1. Is “one active run at a time” acceptable for both pilot agencies?
2. Should owner contact information be email-only, or is a display name enough?
3. Do users naturally define due dates as offsets from run start, or as manually entered dates?
4. Is an accepted exception sufficient, or do pilots need a distinct “not applicable” label?
5. Which CSV direction matters most: initial workflow import, operational export, or both?
6. Does missed-step history change behavior, or is a current overdue view sufficient?
7. Will either pilot make a paid commitment at $29/month after completing a real run?

## 9. Six-week indie delivery plan

| Week | Milestone | Outcome | Exit criteria |
|---|---|---|---|
| 1 | M0: Model and usability spike | Validate workflow/run snapshots, states, and overdue-event semantics | Core state transitions are documented and tested; a clickable or minimal functional flow is reviewed with a pilot |
| 2 | M1: First vertical slice | Create one workflow, start one run, complete one owned step, inspect history | Slice runs end-to-end with persisted data and authentication |
| 3 | M2: Operational states | Add due-state derivation, exceptions, run closure, and missed-step preservation | Automated tests cover overdue→completed, overdue→rescheduled, and exception paths |
| 4 | M3: External handoffs | Add links, manual reminders, CSV import/export, and data-boundary safeguards | CSV round-trip works; no upload/fetch path exists; reminder logging is idempotent |
| 5 | M4: Pilot-ready product | Finish empty/error states, accessibility baseline, analytics, and production preview | All P0 acceptance tests pass; both pilots can be onboarded without database edits |
| 6 | M5: Live pilot and decision | Observe real use, fix blocking defects, test price explicitly | Both pilots receive access; behavior and payment responses are recorded; continue/reshape/stop decision is written |

### First vertical slice

Build this before CSV, reminders, visual polish, or broad settings:

1. Authenticate one operator into one workspace.
2. Create one workflow with three ordered steps.
3. Assign an owner and due offset to every step.
4. Start one client-specific run from the workflow.
5. Show the copied steps with calculated due dates.
6. Mark one step completed.
7. Display the completion in append-only run history.
8. Reload the application and confirm the entire state persists.
9. Attempt cross-workspace access and verify it is rejected.

This slice proves the central data model: reusable definition → immutable run snapshot → owned execution → retained history.

### Suggested implementation slices after the vertical slice

1. Due states, overdue-event creation, exceptions, and run closure.
2. External links, manual reminder handoff, and reminder history.
3. CSV import/export, pilot analytics, accessibility, and failure hardening.

### Build-versus-buy guidance

- Buy or use a managed authentication service; authentication is not the product.
- Use managed serverless persistence and hosting appropriate for a small web application.
- Implement the workflow/run state model directly because it contains the product differentiation.
- Use a proven CSV parser rather than maintaining custom parsing logic.
- Do not buy or integrate file storage, workflow automation, email delivery, or payments for the MVP.

### Support-burden controls

- One documented CSV template only
- No custom migration work
- No external-system troubleshooting beyond confirming that a URL opens
- No founder-operated reminder service
- No manual database correction as a normal workflow
- Pilot feedback collected through a single founder-owned channel

## 10. Launch, validation, and kill triggers

### 10.1 Pilot audience

Start with the two existing pilot volunteers. Preserve their acquisition source separately if one came from warm outreach.

The product is ready for a broader cold test only after both pilots can complete the main flow without founder intervention.

### 10.2 Feedback method

For each pilot:

1. Observe workflow creation or CSV import.
2. Observe the first live-run setup.
3. Review behavior after at least one real due date.
4. Ask what they would have done without the product.
5. Ask which part was useful enough to retain.
6. Ask for a concrete paid commitment at the proposed price.
7. Record behavior separately from opinions.

### 10.3 Continue signals

Continue beyond the six-week MVP if:

- Both pilots activate.
- At least one uses the product across multiple sessions.
- At least one completes a real run or deliberately manages an exception.
- At least one reuses the workflow or has a scheduled second onboarding.
- Ownership or missed-step history is cited and observed as materially useful.
- No P0 workflow depends on portals, files, bookkeeping, or custom integrations.

### 10.4 Reshape triggers

Reshape the wedge before adding features if:

- Pilots use the checklist but ignore ownership and history.
- The main value is CSV formatting rather than live-run operation.
- Both pilots require concurrent runs before they can test the core outcome.
- Manual reminders create more work than they save.
- Users consistently want project management rather than onboarding accountability.

### 10.5 Kill triggers

Stop or return to discovery if:

- Neither pilot starts a live run within seven days after assisted onboarding.
- Neither pilot returns for a second operational session.
- No pilot completes or explicitly closes a real run.
- Both pilots prefer their existing spreadsheet after trying the core workflow.
- The product cannot be useful without files, bookkeeping, portals, or bespoke integrations.
- After ten qualified, hands-on prospects receive an explicit paid offer, none makes a concrete paid commitment at any tested price.

Two pilot rejections alone should not be treated as statistically conclusive pricing evidence, but they would invalidate any claim that $29/month has been validated.

## 11. Evidence handoff

### 11.1 Evidence ledger

| Evidence | Class | Supported conclusion | Does not establish |
|---|---|---|---|
| Cold traffic: 27 signups from 300 visits | Observed cold smoke experiment | 9% cold signup conversion; enough interest to justify bounded pilot validation | Product use, retention, payment, or feature-level demand |
| Warm traffic: 12 signups from 40 visits | Observed warm smoke experiment | 30% conversion within a relationship-influenced audience | Cold acquisition performance or general market conversion |
| Two pilot volunteers | Expressed pilot intent | Two initial candidates for hands-on testing | Activation, retention, payment, or successful onboarding |
| Discovery supports explicit owners | Upstream discovery summary | Ownership belongs in the MVP hypothesis | Exact owner model, permissions, or willingness to pay |
| Discovery supports reusable steps | Upstream discovery summary | Workflow/run reuse belongs in the MVP hypothesis | Required scale or number of workflows |
| Discovery supports external record links | Upstream discovery summary | URL references belong in MVP | Connector, preview, synchronization, or file-storage demand |
| Discovery supports CSV | Upstream discovery summary | A CSV boundary should be tested | Whether import, export, or both drives value |
| Sensitive file storage is separate | Explicit boundary | File upload/storage must be excluded | Compliance suitability |
| Bookkeeping is separate | Explicit boundary | Financial records and ledger behavior must be excluded | Need for future accounting integration |
| No payment was requested | Explicit experiment condition | Existing signup results contain no pricing evidence | Any validation of $29/month |
| $29/month | Assumption | Candidate price for an explicit paid test | Validated willingness to pay |

Cold and warm results must remain separate in all reporting. They may not be combined into “39 signups from 340 visits,” because doing so would obscure materially different acquisition conditions.

### 11.2 Supported product decisions

- Build a bounded pilot around owned, reusable onboarding steps.
- Include external URLs while keeping linked content external.
- Include CSV as a controlled boundary.
- Preserve missed-step history rather than only showing current status.
- Keep files, bookkeeping, portals, automation, and connectors out of the MVP.
- Use the two volunteers for hands-on validation.

### 11.3 Still unproven

- That signup interest converts to product activation
- That users will run real client onboarding in the product
- That missed-step history changes outcomes
- That workflow reuse produces retention
- That one active run is sufficient
- That both CSV import and export are necessary
- That agencies will pay
- That $29/month is an acceptable or optimal price
- That the two volunteers represent cold-market users

### 11.4 Current decision

**Decision:** Build the six-week bounded MVP for the two pilot volunteers, subject to the stated P0 boundary and kill triggers.

This is a decision to validate behavior—not a conclusion that the market, retention, or price is proven.

### 11.5 Next validation

| Action | Owner | Acceptance signal | Kill/reshape signal |
|---|---|---|---|
| Put the first vertical slice in front of both volunteers before expanding P0 | Founder | Both can create a workflow, start a run, and complete a step without product explanation beyond normal onboarding | Neither can map a real onboarding process into the model |
| Run at least one real due-date cycle | Founder and pilots | At least one overdue or at-risk step is acted on through the product | Product is not revisited during active onboarding |
| Make an explicit $29/month offer after hands-on use | Founder | Concrete payment or commitment contingent only on MVP readiness | No commitment; price remains unvalidated and requires further qualified tests |

## 12. Assumptions to confirm

1. One active workflow and one live run at a time are product limits for the pilot, not merely examples.
2. Step owners can be non-user records; only the agency operator signs in.
3. CSV includes both workflow import and run/workflow export.
4. Due offsets are calendar days from the run start unless the operator overrides the resulting date.
5. An accepted exception counts as terminal but remains visibly distinct from completion.
6. Pilot usage is free while willingness to pay is tested through an explicit commitment conversation.

The three decisions I would confirm first are the one-live-run limit, the non-user owner model, and whether CSV needs both import and export.

Nothing needs to return to broad `z-market-validate` before building the vertical slice. Payment validation does need to resume immediately after hands-on use: the existing smoke results justify a pilot, but they do not validate $29/month.