# PRD: OnboardRun — Ownership-Aware Client Onboarding Runbook

## Contents

1. Overview
2. Users and context
3. Solution
4. P0 user journeys
5. Requirements
6. UX and content notes
7. Data and integrations
8. Edge cases and risks
9. Indie delivery milestones
10. Launch and feedback
11. Appendix

| Field | Value |
|-------|--------|
| **Status** | Draft |
| **Owner** | Solo founder (OPC) |
| **Last updated** | 2026-07-31 |
| **Version** | 0.1 |
| **Primary persona** | Small-agency ops / account lead who owns client onboarding |
| **Platform** | Web app (desktop-first browser) |
| **Timeline** | 6-week solo MVP |
| **Related docs** | Discovery smoke results (this PRD §1.6, §11.1) |

## Revision history

| Version | Date | Summary |
|---------|------|---------|
| 0.1 | 2026-07-31 | Initial PRD from discovery materials: smoke metrics, P0 cut, exclusions, six-week solo plan |

---

## 1. Overview

### 1.1 One-liner

For small agencies that lose the thread during client onboarding, **OnboardRun** is a single-workflow runbook that makes every step owned, due-dated, completable with exceptions, and exportable — without becoming a portal, file vault, or bookkeeping system.

### 1.2 Problem statement

- **Current situation:** Small agencies onboard clients with a mix of Notion docs, shared spreadsheets, Slack threads, email checklists, and “who was supposed to do that?” memory. Steps exist, but ownership and live status do not.
- **Pain:** Onboarding stalls because nobody knows who owns the next step, what is overdue, what was skipped, or where the external record lives. Missed steps surface late (kickoff fails, access not granted, contract not countersigned).
- **Why now:** Discovery smoke showed clear signup interest for an ownership-first runbook wedge. Agencies already store files and money elsewhere; they need operational clarity, not another system of record for assets or invoices.
- **Cost of status quo:** (Assumption: qualitative only — no timed study yet.) Rework, delayed project start, founder/ops firefighting, and brittle handoffs when the original coordinator is busy.

### 1.3 Goals

**Product goals (user outcomes)**

1. An agency can define **one reusable onboarding workflow** with explicit step owners and due semantics.
2. An agency can start **one live run** for a real client and drive it to completion or exception without losing history.
3. At any moment, anyone on the team can answer: *what’s next, who owns it, is it late, what was missed, and where is the external link?*
4. Ops can **export CSV** and send **manual reminders** without leaving the product for basic coordination.

**Business goals (indie)**

1. Convert **2 pilot volunteers** into active weekly users of a real client run (not just signup).
2. Validate that ownership + due states + missed-step history are the wedge users return to — not portals or storage.
3. Collect willingness-to-pay signal **after** value is experienced. **$29/month is a hypothesis only** (no payment was requested in smoke).

### 1.4 Non-goals (v1)

Explicitly **out of scope** for this MVP / v1 cut:

| Non-goal | Why excluded now |
|----------|------------------|
| Client / vendor **portals** | Different product surface; delays ownership wedge |
| Sensitive **file storage** / vault | Discovery treats files as separate system of record |
| **Bookkeeping** / invoicing / payments collection in-product | Separate concern; pricing still unvalidated |
| Data **migration** tools (from Notion/Sheets/etc.) | Manual seed is enough for pilots |
| Native **connectors** (Slack, HubSpot, Google Drive, etc.) | Links + CSV substitute for MVP |
| **AI** generation / summarization / auto-assignment | Scope and trust risk for solo MVP |
| **Mobile** native apps | Desktop web first |
| **Enterprise roles** / SSO / complex RBAC | Small-agency single-workspace model |
| **Compliance** certifications, audit packs, legal-grade retention claims | Not the MVP job |

Also deferred (not P0 even if adjacent): multi-workflow libraries, templates marketplace, automated reminder sequences, multi-workspace agencies, white-label.

### 1.5 Success metrics

| Metric | Definition | Target / signal | Timeframe |
|--------|------------|-----------------|-----------|
| Pilot activation | Pilot account creates 1 workflow + 1 live run with ≥1 owned step completed | 2 / 2 pilots activate | Week 5–6 |
| Run progress | Live run reaches terminal state (completed or closed with exceptions) OR ≥70% steps resolved | ≥1 real client run per pilot | Week 6 |
| Ownership clarity | % of open steps with non-empty owner | ≥95% on active runs | Continuous |
| Weekly return | Pilot returns and updates a run in ≥2 distinct weeks | ≥1 of 2 pilots | By end of pilot |
| WTP signal (soft) | After 2 weeks of use, pilot answers “would you pay ~$29/mo?” (interview, not checkout) | Directional only; **not** a revenue claim | Post-pilot debrief |

**Leading product events (instrument if cheap):** workflow_created, run_started, step_completed, step_exceptioned, reminder_sent, csv_exported, missed_step_viewed.

### 1.6 Evidence treatment (mandatory)

Discovery produced **two traffic cohorts**. They must **never** be pooled into a single conversion rate for decisions.

| Cohort | Visits | Signups | Signup rate | Notes |
|--------|--------|---------|-------------|--------|
| **Cold smoke** | 300 | 27 | **9.0%** | Primary demand signal for strangers |
| **Warm traffic** | 40 | 12 | **30.0%** | Network / familiar audience — **report separately** |
| **Pooled (forbidden as headline)** | 340 | 39 | 11.5% | Do not use as “the” conversion rate |

**Additional evidence rules**

1. **Pilot volunteers:** 2 people volunteered for pilot. Treat as qualitative pipeline, not statistical proof of PMF.
2. **No payment requested** during smoke → **no revenue validation**. Any **$29/month** figure is a **pricing hypothesis**, not a discovered willingness-to-pay.
3. Supported product themes from discovery framing (not fabricated quotes):
   - Explicit **owners**
   - **Reusable** steps / workflow
   - **External record links**
   - **CSV** export
4. Explicit product boundaries from discovery: **sensitive file storage** and **bookkeeping** are **separate products/systems** — OnboardRun must not absorb them.
5. In all decks, READMEs, and investor-facing notes derived from this PRD: lead with cold metrics; warm metrics only as a secondary, labeled line.

**Assumption:** Signup intent maps to “interest in onboarding operational clarity,” not yet to retained paid usage.

---

## 2. Users & context

### 2.1 Primary persona

| Attribute | Detail |
|-----------|--------|
| Name / label | **Alex — Agency Ops / Account Lead** |
| Who they are | Operator at a small agency (≈2–15 people) who coordinates client kickoffs across sales, delivery, and sometimes finance |
| Context / environment | Desktop browser, multi-tab day, Slack/email interruptions, tools already include Drive/Dropbox, accounting software, CRM or spreadsheet pipeline |
| Top jobs-to-be-done | Start a new client cleanly; ensure every prerequisite is owned and done before delivery starts; recover when something was missed |
| Current tools / workarounds | Notion checklist, Google Sheet, shared doc, email CC chains, memory |
| Triggers to seek a solution | A kickoff fails because access/forms/contracts weren’t done; a team member asks “is this client ready?” and nobody knows; founder is tired of chasing steps |
| Anti-persona (not for) | Enterprise PMO needing complex role matrices; freelancers with one client and no handoff; teams whose real pain is file storage or AR/AP |

### 2.2 Secondary users (only if needed)

| Role | Need in MVP | Support level |
|------|-------------|---------------|
| Step owner (designer, strategist, AE) | See assigned steps, mark complete/exception | Same workspace member; no special portal |
| Founder (viewer/occasional actor) | Glance at overdue + exceptions | Same account model; no executive dashboard product |

No client-facing login in MVP.

### 2.3 Use contexts

- **When:** New deal closed → onboarding window (days to a few weeks).
- **Where:** Desktop web during work hours; quick status checks between meetings.
- **Constraints:** Must coexist with existing Drive/accounting/CRM via **links**, not replacement. Offline not required. Mobile browser usable by accident is fine; mobile design is not a goal.

---

## 3. Solution

### 3.1 Value proposition

For **agency ops leads** who **lose ownership and due status during client onboarding**, **OnboardRun** is an **ownership-aware runbook** that turns a reusable workflow into a live run with owners, due states, completions/exceptions, manual reminders, external links, CSV, and missed-step history. Unlike **Notion/Sheets checklists**, we make **live ownership and exception history first-class**. Unlike **client portals / PSAs**, we stay **thin, internal, and non-financial**.

### 3.2 Product principles (5)

1. **Ownership is mandatory, not decorative.** An open step without an owner is a defect state.
2. **One workflow, one live run first.** Depth over template sprawl.
3. **Links out; do not become the vault.** External records stay external.
4. **Exceptions are first-class.** Skipping is allowed only as an explicit, historical event.
5. **Solo-operable product.** No feature that requires a success team, connector eng, or compliance program to ship.

### 3.3 Scope summary

| In scope (MVP / P0) | Out of scope (v1) |
|---------------------|-------------------|
| One reusable workflow definition | Multi-workflow catalog / marketplace |
| One live run per client onboarding instance | Portfolio analytics across all clients |
| Step owners + due states | Automated SLA engines |
| Complete / exception paths | Client portal completion |
| Manual reminders | Automated drip / email sequences |
| External record links on steps | File upload / storage |
| CSV export | Bi-directional sync connectors |
| Missed-step / history of incomplete→exception or overdue | Full audit log product / compliance export packs |
| Simple workspace members (same role power for MVP) | Enterprise roles, SSO, SCIM |
| Web desktop-first | Native mobile, AI, bookkeeping, migration wizard |

---

## 4. User journeys (P0)

### Journey A — Define the reusable onboarding workflow

1. Alex creates a workspace / signs in.
2. Alex creates **Workflow: “Standard client onboarding”** (the single P0 workflow).
3. Alex adds ordered steps (e.g., “Collect brand assets link”, “Confirm billing contact”, “Schedule kickoff”).
4. For each step, Alex sets default **owner role/person**, optional **due offset** (e.g., +2 days from run start), and optional **external record link** placeholder or default URL pattern note.
5. Alex saves workflow as ready-to-run.

**Success state:** Workflow has ≥3 steps; every step has a default owner; workflow status = ready.  
**Failure / recovery:** Empty workflow cannot start a run; UI blocks with clear CTA to add steps + owners.

### Journey B — Start one live run for a real client

1. Alex clicks **Start run** from the workflow.
2. Alex enters client label (name) and run start date.
3. System materializes run steps from workflow; applies owners and computes due dates.
4. Alex adjusts any step owner/due/link for this client if needed.
5. Run appears in **Active** state with next due / overdue visible.

**Success state:** Live run exists with owned steps and due states.  
**Failure / recovery:** If workflow incomplete (no steps / missing owners), start is blocked with checklist of fix-ups.

### Journey C — Drive steps: complete, exception, remind

1. Owner (or Alex) opens the live run.
2. Completes a step → state **done**; timestamp + actor recorded.
3. Or marks **exception** with short reason (e.g., “N/A — client has no brand kit”) → state **exceptioned**; remains in history.
4. Alex sends a **manual reminder** on an open/overdue step (in-app notice and/or mailto / copy message — see FR).
5. Overdue open steps surface as **overdue** without auto-escalation theater.

**Success state:** Steps move to terminal step states; run progress % updates.  
**Failure / recovery:** Reminder failure is non-blocking; user can copy step summary manually.

### Journey D — Inspect missed steps + export CSV

1. Alex opens **Missed / history** for the run (or workspace filter).
2. Sees steps that were overdue, exceptioned, or reopened (MVP: overdue still open + exceptioned + completed late if tracked).
3. Exports **CSV** of run steps (owner, state, due, completed_at, exception_reason, link).
4. Uses CSV in existing ops spreadsheet if needed.

**Success state:** CSV downloads; history explains what slipped.  
**Failure / recovery:** Empty history shows “No missed steps yet” — not an error.

### Journey E — Close the run

1. When all steps are done or exceptioned, Alex marks run **Completed**.
2. If some steps remain open, Alex may **force-close** only after confirming remaining opens become exceptions or remain visible as incomplete (product choice: **block complete until all terminal** — see FR-012).

**Success state:** Run terminal; history preserved.  
**Failure / recovery:** Attempt to complete with open steps → error listing open items.

---

### 4.1 State models (normative for MVP)

#### Run states

```
draft ──► active ──► completed
              │
              └──► archived (optional P1; if not built, use completed only)
```

| State | Meaning |
|-------|---------|
| `draft` | Run created but not yet started (optional; may collapse into active-only if simpler) |
| `active` | Live onboarding in progress |
| `completed` | All steps terminal (done or exceptioned) and user closed — or auto-complete when last step terminals (**Assumption: manual complete button**) |

#### Step states

```
open ──► done
  │
  ├──► exceptioned
  │
  └──► open + overdue (derived flag when due_at < now AND state=open)
```

| State / flag | Meaning |
|--------------|---------|
| `open` | Not finished |
| `done` | Completed successfully |
| `exceptioned` | Explicitly waived / failed with reason |
| `overdue` | **Derived:** `open` AND `due_at` in the past |

#### Owner rule

- Every step on an **active** run **must** have an `owner` (user id or display name in MVP).
- Clearing owner on active run is blocked or requires reassignment in same action.

---

## 5. Requirements

### 5.1 Functional requirements

| ID | Requirement | Priority | Acceptance criteria |
|----|-------------|----------|---------------------|
| **FR-001** | User can create **exactly one** primary onboarding **workflow** in MVP (product may allow more later; QA focuses on one) | P0 | Given a new workspace, when user creates a workflow with name + ≥1 step, then it persists and can be reopened after refresh. |
| **FR-002** | Workflow steps are **reusable** templates: ordered list with title, default owner, optional due offset, optional default external link | P0 | Given a workflow, when user adds/reorders/edits/deletes steps, then order and fields persist; deleting a step does not delete historical runs’ steps. |
| **FR-003** | User can start **one live run** from a workflow for a named client | P0 | Given a ready workflow (≥1 step, each with default owner), when user starts a run with client name + start date, then a run is created in `active` with materialized steps. |
| **FR-004** | Each run step has an **explicit owner** | P0 | Given an active run, when viewing any step, then owner is visible; saving a step with empty owner is rejected with validation error. |
| **FR-005** | Each run step has a **due state** (due date + derived overdue) | P0 | Given start date + due offset (or manual due), when current time passes due_at and step is open, then UI shows overdue; when step is done/exceptioned, overdue badge clears. |
| **FR-006** | User can mark a step **complete** | P0 | Given an open step, when user marks done, then state=`done`, `completed_at` set, actor recorded; run progress updates. |
| **FR-007** | User can mark a step **exception** with reason | P0 | Given an open step, when user marks exception and enters non-empty reason, then state=`exceptioned`, reason stored, timestamp/actor set. |
| **FR-008** | User can send a **manual reminder** for an open step | P0 | Given an open step with owner, when user triggers remind, then system records `reminder_sent_at` and provides at least one of: in-app confirmation, prefilled mailto, or copy-to-clipboard message including client, step, owner, due. (**Assumption:** email provider optional; mailto/copy acceptable for MVP.) |
| **FR-009** | User can attach **external record links** to steps | P0 | Given a step, when user sets a URL (http/https), then link is stored and openable in new tab; invalid URL rejected. No file upload control exists. |
| **FR-010** | User can **export CSV** of a run’s steps | P0 | Given a run with steps, when user exports CSV, then file downloads with columns at least: client, run_id, step_title, owner, state, due_at, completed_at, exception_reason, link, overdue(yes/no). |
| **FR-011** | User can view **missed-step history** for a run | P0 | Given a run that has overdue opens, exceptioned steps, or late completions, when user opens history, then those events/steps are listed with timestamps; completed-on-time only steps can be filtered out. |
| **FR-012** | User can **complete the run** only when all steps are terminal | P0 | Given a run with all steps `done` or `exceptioned`, when user marks run completed, then run state=`completed`. Given any `open` step, when user attempts complete, then action is blocked listing open steps. |
| **FR-013** | Auth + single workspace for pilot users | P0 | Given a pilot user, when they sign up/sign in, then they only see their workspace data; unauthenticated users cannot read runs. |
| **FR-014** | Simple teammate access (optional same-role members) | P1 | Given workspace owner invites member by email, member can view/edit runs. If invite not built in week 6, pilots share one login (**Assumption acceptable with note**). |
| **FR-015** | Workflow edit after runs exist does not rewrite past runs | P1 | Given a run already started, when workflow template changes, then existing run steps remain unchanged; only new runs pick up template changes. |
| **FR-016** | Dashboard list of active runs with overdue counts | P1 | Given ≥1 active run, when user opens home, then each run shows client name, progress, overdue count. |

### 5.2 Non-functional requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| **NFR-001** | Desktop-first responsive web; usable down to ~1280px width without horizontal panic | P0 | No native mobile |
| **NFR-002** | Core run page interactive in normal conditions; avoid multi-second empty spinners for &lt;100 steps | P0 | Solo-scale data |
| **NFR-003** | Do not store uploaded sensitive files; links only | P0 | Data boundary |
| **NFR-004** | No payment processing in MVP | P0 | Pricing unvalidated |
| **NFR-005** | Basic accessibility: labels on inputs, keyboard can complete primary step actions | P1 | Not a WCAG certification goal |
| **NFR-006** | Soft delete / retain run history for pilot duration | P1 | No compliance retention claim |

### 5.3 Tracking / analytics events

| Event | When | Properties |
|-------|------|------------|
| `signup_completed` | Account created | `cohort=cold\|warm\|unknown` if known |
| `workflow_created` | First workflow saved | `step_count` |
| `run_started` | Live run created | `step_count`, `client_len` |
| `step_completed` | Step → done | `run_id`, `was_overdue` |
| `step_exceptioned` | Step → exceptioned | `run_id`, `reason_len` |
| `reminder_manual` | Reminder triggered | `run_id`, `channel=mailto\|copy\|inapp` |
| `csv_exported` | CSV download | `run_id`, `row_count` |
| `missed_history_viewed` | History opened | `run_id` |
| `run_completed` | Run terminal | `duration_days`, `exception_count` |

---

## 6. UX & content notes

### 6.1 Screens / pages (IA)

1. **Auth** — sign up / sign in  
2. **Home** — active runs list (even if only one)  
3. **Workflow editor** — single workflow steps  
4. **Run detail** — primary daily surface: steps, owners, due, actions  
5. **Missed-step history** — filterable list (tab or subview on run)  
6. **Export** — control on run detail (not a separate app section)  
7. **Settings (minimal)** — account email; optional member invite (P1)

### 6.2 Critical empty / error states

| State | UX treatment |
|-------|--------------|
| No workflow yet | CTA: “Create your onboarding workflow” — explain one reusable checklist with owners |
| Workflow has steps without owners | Inline errors; cannot start run |
| No runs yet | CTA: “Start a live run for a client” |
| All steps clear (no overdue) | History empty: “Nothing missed yet” |
| Complete run blocked | Modal/list of remaining open steps |
| Invalid link | Field-level error, keep other edits |
| Reminder without owner | Impossible if FR-004 enforced; else block with assign-owner CTA |

### 6.3 Key copy (product-critical)

- **Onboarding value prop:** “Every onboarding step has an owner, a due date, and a history — without another portal.”
- **Primary CTA:** “Start live run”
- **Empty state:** “No active client runs. Start one from your workflow.”
- **Exception prompt:** “Why is this step not being completed?” (required)
- **Boundary copy (settings or footer once):** “Store files and finances in your existing tools. OnboardRun tracks ownership and completion.”
- **Pricing:** Do **not** hard-sell $29 in-product during pilot. If asked, treat as hypothesis.

### 6.4 Visual / interaction notes

- Status chips: `open` / `overdue` / `done` / `exceptioned` must be visually distinct (color + text, not color alone).
- Overdue should be obvious but not alarmist spam.
- No fake AI sparkles, no empty “insights” widgets.

---

## 7. Data & integrations

### 7.1 Core concepts / entities

| Entity | Purpose | Key fields (conceptual) |
|--------|---------|-------------------------|
| **Workspace** | Tenant boundary for a small agency | id, name, created_at |
| **User** | Person who logs in | id, email, workspace_id |
| **Workflow** | Reusable onboarding definition | id, workspace_id, name, status |
| **WorkflowStep** | Template step | id, workflow_id, position, title, default_owner_ref, due_offset_days, default_link |
| **Run** | Live instance for one client | id, workflow_id, client_name, state, started_at, completed_at |
| **RunStep** | Materialized step | id, run_id, title, owner_ref, state, due_at, completed_at, exception_reason, link, last_reminded_at |
| **StepEvent** (minimal) | History for missed/audit lite | id, run_step_id, type (`completed`\|`exceptioned`\|`reminded`\|`reassigned`\|`due_changed`), at, actor_id, meta |
| **ReminderLog** | Manual reminder record | may fold into StepEvent |

**Not entities in MVP:** FileObject, Invoice, PortalUser, IntegrationConnection, RolePermissionMatrix, AISuggestion.

### 7.2 Data boundaries (hard walls)

| Data type | In OnboardRun? | Rule |
|-----------|----------------|------|
| Step ownership & status | **Yes** | System of record for onboarding execution state |
| External URLs | **Yes** | Pointers only |
| CSV exports | **Yes** (generated, not long-term warehouse) | User-downloaded |
| Client source files / brand kits | **No** | Link to Drive/Dropbox/etc. |
| Contracts PDFs as storage | **No** | Link out |
| Invoices, payments, time entries | **No** | Bookkeeping stays external |
| Client login identities | **No** | No portals |
| Secrets for third-party connectors | **No** | No connectors |

### 7.3 Integrations

| System | Purpose | MVP? | Notes |
|--------|---------|------|-------|
| Email magic link or password auth | Login | Y | Pick one simple auth path |
| `mailto:` / clipboard | Manual reminders | Y | Acceptable without ESP |
| Stripe | Billing | **N** | Hypothesis price only |
| Slack / HubSpot / Drive APIs | Sync | **N** | Links + CSV only |
| LLM providers | AI | **N** | Explicit non-goal |

### 7.4 Permissions & roles

- **MVP default:** single workspace; all authenticated members can edit workflows/runs (trusted small team).
- **No** enterprise roles, client roles, or field-level ACL.
- **Assumption:** If invite ships late, one shared pilot login is acceptable with that risk documented to pilots.

---

## 8. Edge cases & risks

| Item | Impact | Mitigation |
|------|--------|------------|
| Pilots try to upload files | Support load; scope creep | Clear empty-state + rejection of upload UX; link helper copy |
| Warm/cold metrics mixed in storytelling | False confidence | §1.6 rules; any public metric labeled |
| $29 assumed as validated price | Bad packaging / churn later | Soft WTP interview only after usage |
| Owner is free text vs user account | Ambiguous reminders | Prefer workspace user pick list; allow “external person name” only as P1 if needed |
| Timezones for due dates | False overdue | Store UTC; display in workspace TZ (**Assumption: single TZ setting default browser**) |
| Template edit rewrites live runs | Data loss trust break | FR-015: materialize on start |
| Solo founder support burden from “can you integrate X?” | Time sink | Public non-goals; CSV/link escape hatches |
| Two pilots insufficient for PMF claim | Overfitting | Treat as design partners; kill triggers below |

**Open product questions**

1. Is reminder MVP satisfied by mailto/copy only, or is transactional email required for pilot credibility?
2. Should due offsets be business days or calendar days? (**Assumption: calendar days**)
3. Can a `done` step be reopened? (**Assumption: yes, with event log — small control**)
4. One workflow hard-cap in UI vs soft guidance? (**Assumption: allow multiple in data model, document “one is enough” for MVP success criteria**)
5. Workspace TZ default — browser vs explicit setting?

---

## 9. Milestones (indie delivery — 6 weeks)

| Milestone | Week | Outcome | Exit criteria |
|-----------|------|---------|---------------|
| **M0 — Spike & skeleton** | 1 | Auth + empty shell + entity model | User can sign in; DB tables for workflow/run/step exist; deploy preview URL |
| **M1 — Vertical slice** | 2 | **First vertical slice** (see below) end-to-end | Create workflow → start run → complete one step → see state persist on refresh |
| **M2 — Ownership & due** | 3 | Owners, due dates, overdue derivation, exceptions | FR-004–007 pass manual test script |
| **M3 — Coordination tools** | 4 | Manual reminders, external links, CSV export | FR-008–010 pass; sample CSV opens in Sheets |
| **M4 — History & close** | 5 | Missed-step history, run completion rules, pilot polish | FR-011–012 pass; empty/error states done |
| **M5 — Pilot** | 6 | 2 pilots on real/simulated client runs; feedback + WTP soft ask | Activation metrics from §1.5; written pilot notes; go/no-go |

### 9.1 First vertical slice (build this first)

**Goal:** Prove the product spine without coordination extras.

**Slice path (must work on preview deploy):**

1. Sign in  
2. Create workflow “Standard onboarding” with 3 steps and default owners  
3. Start run for client “Acme Co”  
4. Open run detail  
5. Mark step 1 **done**  
6. Refresh — step 1 still **done**, steps 2–3 **open**  
7. Mark step 2 **exceptioned** with reason  
8. Confirm progress reflects 2/3 terminal  

**Explicitly not in the first slice:** CSV, reminders, history UI, invites, overdue badges (can stub due_at).

### 9.2 Build vs buy

| Piece | Choice | Rationale |
|-------|--------|-----------|
| Auth | Buy (e.g. Clerk/Auth.js/Supabase Auth/Cloudflare Access pattern per stack) | Don’t write password crypto |
| Hosting | Serverless web (Cloudflare-friendly per OPC defaults) | Low ops |
| Email ESP | Skip or minimal | mailto/copy first |
| Grid/CSV | Hand-roll CSV string | Trivial |
| Rich text | Plain text fields | Avoid editor time sink |

### 9.3 Support burden watchlist

- “Where do I upload the contract?” → restate boundary  
- “Can it sync Slack?” → non-goal; manual reminder  
- “Can clients fill this?” → portal non-goal  
- Password resets / invite confusion if multi-user ships  

---

## 10. Launch & feedback

- **Beta audience:** The **2 pilot volunteers** first; optionally 2–3 cold signups who reply to a short screener (agency ops, currently onboarding clients).
- **Feedback channel:** 20-minute weekly call or async Loom + shared note; in-product “feedback” mailto.
- **Instrumentation:** Cohort label cold/warm if known; else `unknown`.
- **Kill / pivot triggers** (honest indie gates):

| Trigger | Window | Action |
|---------|--------|--------|
| Neither pilot starts a live run | End of week 2 of pilot | Kill or re-interview problem |
| Both pilots abandon after &lt;2 logins | End of pilot | Pivot messaging or problem; do not add portals/AI as hail-mary |
| Both say core job is actually files or invoicing | Any debrief | **Do not** absorb those scopes; consider adjacent product or stop |
| No one will discuss paid plan even hypothetically after real use | Post-pilot | Revisit value prop; **do not** claim $29 validation |
| Warm-only interest; cold signups never reply | 4 weeks outreach | Treat demand as weak outside network; rethink channel or wedge |

- **Continue / expand triggers:** ≥1 pilot completes a real client run and states they would be upset if the tool disappeared; requests are for *more runbook depth* (templates, reminders), not for portals/storage.

---

## 11. Appendix

### 11.1 Source materials used

- User brief: ownership-aware client-onboarding runbook for small agencies; six-week solo MVP PRD request  
- Discovery support themes: explicit owners, reusable steps, external record links, CSV  
- Explicit separations: sensitive file storage, bookkeeping  
- Smoke metrics: cold **27/300** signups; warm **12/40** signups (keep separate); **2** pilot volunteers  
- Pricing: **no payment requested**; **$29/month = hypothesis only**  
- P0 feature list and exclusion list as provided by founder  

### 11.2 Assumptions log

| ID | Assumption | Impact if wrong |
|----|------------|-----------------|
| A-001 | Primary user is agency ops/account lead on desktop web | UX and IA misaligned |
| A-002 | mailto/copy satisfies manual reminders for pilots | Need ESP week 4–5 |
| A-003 | Calendar-day due offsets are enough | Missed business-day expectations |
| A-004 | Materialized run steps (not live-bound to template) | Template-sync feature pressure |
| A-005 | Same-role workspace members acceptable (no RBAC) | Enterprise-like pilot blocked |
| A-006 | $29/mo is a plausible future price to *discuss*, not charge | Packaging rethink |
| A-007 | One happy-path workflow validates the wedge | Need multi-workflow sooner |
| A-008 | Cold 9% signup indicates interest in *this* problem framing | Landing promised something else — recheck copy vs product |

### 11.3 Glossary

| Term | Definition |
|------|------------|
| **Workflow** | Reusable ordered template of onboarding steps |
| **Run** | Live instance of a workflow for one client |
| **Owner** | Person accountable for finishing a step |
| **Exception** | Explicit non-completion with reason; terminal step state |
| **Missed-step history** | View of overdue, exceptioned, and/or late steps and related events |
| **External record link** | URL pointing at a system of record outside OnboardRun |
| **Cold traffic** | Unfamiliar visitors in smoke test (300 visits) |
| **Warm traffic** | Familiar/network visitors (40 visits) — not mixed into cold KPI |
| **Pricing hypothesis** | $29/month idea without payment test |

### 11.4 Rejected ideas (cut list)

| Idea | Why cut |
|------|---------|
| Client portal checklist | Different product; not ownership wedge |
| In-app file vault | Discovery boundary; security/support cost |
| Invoicing / bookkeeping | Separate system of record |
| Slack/HubSpot native connectors | Solo MVP time; CSV/links substitute |
| AI step generation | Distraction; trust/accuracy issues |
| Mobile app | Premature |
| Enterprise RBAC / SSO | Wrong segment for v1 |
| Compliance certification scope | Not required to learn |
| Migration wizard from Notion | Manual setup OK for 2 pilots |
| Multi-product “agency OS” | Violates thin-wedge strategy |

### 11.5 P0 acceptance test script (manual)

1. Sign up → land on empty home.  
2. Create workflow with 3 steps, each with owner + due offset + one link.  
3. Fail to start run if an owner removed (validation).  
4. Start run “Acme Co”.  
5. Observe due dates computed; set clock or due_at to force one overdue badge.  
6. Complete step 1.  
7. Exception step 2 with reason.  
8. Send manual reminder on step 3; confirm log/feedback.  
9. Open missed-step history; see overdue and/or exception.  
10. Export CSV; open in spreadsheet; verify columns.  
11. Attempt complete run → blocked until step 3 terminal.  
12. Complete step 3 → complete run → state completed.  
13. Confirm no file upload entry point exists in UI.

---

*End of PRD v0.1 — ready for founder review and implementation planning.*
