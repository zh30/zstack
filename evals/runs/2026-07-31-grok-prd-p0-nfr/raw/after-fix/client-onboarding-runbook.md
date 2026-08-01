# PRD: Agency Client Onboarding Runbook (MVP)

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
| **Owner** | Solo founder |
| **Last updated** | 2026-07-31 |
| **Version** | 0.1 |
| **Primary persona** | Small-agency ops lead / account manager who runs client onboarding |
| **Platform** | Web app (desktop-first) |
| **Timeline** | 6-week solo-developer MVP |
| **Related docs** | Cold/warm smoke metrics (inline §1.6); no market-validate report attached |

## Revision history

| Version | Date | Summary |
|---------|------|---------|
| 0.1 | 2026-07-31 | Initial PRD from discovery notes, smoke metrics, and MVP cut |

---

## 1. Overview

### 1.1 One-liner

For small agencies that lose ownership and due dates across client onboarding, this product is a **single ownership-aware runbook**: one reusable workflow, one live run per client, explicit owners/due states, completion and exceptions, manual reminders, external record links, CSV export, and missed-step history — without becoming a portal, file vault, or bookkeeping system.

### 1.2 Problem statement

- **Current situation:** Small agencies onboard clients with spreadsheets, shared docs, chat threads, and ad-hoc task lists. Steps are reusable in theory but drift per client; “who owns this?” and “is this late?” live in people’s heads or buried messages.
- **Pain:** Onboarding stalls when ownership is unclear, due states are invisible, and history of missed steps is not retained. Recovery is manual archaeology across tools.
- **Why now:** Smoke traffic showed enough cold and warm interest to justify a narrow runbook wedge before expanding into adjacent agency ops (files, portals, accounting).
- **Cost of status quo:** Delayed kickoffs, rework, embarrassed client handoffs, and founder/ops time spent chasing status instead of delivery. *(Exact $ cost not measured — Assumption: A-001.)*

### 1.3 Goals

**Product goals (user outcomes)**

1. An agency can define **one reusable onboarding workflow** with ordered steps.
2. For each new client, they can start **one live run** with **explicit owners** and **due states**.
3. They can mark steps **complete** or **exception**, send **manual reminders**, attach **external record links**, export **CSV**, and review **missed-step history**.

**Business goals (indie)**

1. Run a **paid-willingness conversation** with pilot volunteers after they complete ≥1 real client run (price $29/month is **hypothesis only** — not validated; no payment was requested in smoke).
2. Decide go / pivot / kill by end of week 6 using activation + pilot retention signals below — **without mixing cold and warm traffic**.

### 1.4 Non-goals (v1)

Explicitly **out of scope** for this MVP:

| Non-goal | Rationale |
|----------|-----------|
| Client portals | Different product surface; expands support and auth surface |
| Sensitive file storage | Discovery treats file vault as a **separate system**; links-only to external records |
| Bookkeeping / invoicing | Separate domain; do not absorb accounting |
| Migration tools (import from Asana/ClickUp/etc.) | Premature until retention proven |
| Connectors / OAuth integrations | Support and maintenance tax too high for solo 6-week build |
| AI suggestions / auto-chasing | No evidence; adds cost and trust surface |
| Native mobile apps | Desktop ops workflow first |
| Enterprise roles / SSO / multi-tenant admin matrices | Overkill for small-agency ICP |
| Compliance / audit / SOC2 scope | Not a compliance product; do not claim it |
| Multiple concurrent workflow templates | P0 is **one workflow** only |
| Automated reminder scheduling / email sequences | P0 is **manual** reminders only |
| Payments / billing in-app | $29/mo unvalidated; collect willingness offline if at all |

### 1.5 Success metrics

| Metric | Definition | Target / signal | Timeframe |
|--------|------------|-----------------|-----------|
| **Activation (pilot)** | Pilot user creates 1 workflow + 1 live run + completes or exceptions ≥3 steps | 2 of 2 pilot volunteers activate | Weeks 4–6 |
| **Run completion** | Live run reaches terminal state (all steps complete **or** closed with documented exceptions) | ≥50% of started pilot runs reach terminal state | By week 6 |
| **Ownership clarity** | % of steps on live runs with a non-empty owner | ≥90% of steps on activated runs | Continuous in pilot |
| **Retention proxy** | Pilot starts a **second** client run (or reuses workflow for another client) | ≥1 of 2 pilots | By week 6 |
| **Willingness-to-pay signal** | Structured ask after real use: would they pay ~$29/mo (or counter) | Recorded yes/no/counter from both pilots; **not** a revenue target | Week 6 |
| **Traffic quality (reporting only)** | Keep cold vs warm **separate** forever in dashboards | Never blend rates | Ongoing |

**Not success metrics for MVP:** page views alone, vanity signup count, blended conversion, MRR (no payment collection).

### 1.6 Evidence treatment

Smoke results are **directional demand signals**, not product proof of retention or revenue.

| Cohort | Visits | Signups | Conversion | Pilot volunteers | Treatment rule |
|--------|--------|---------|------------|------------------|----------------|
| **Cold** | 300 | 27 | 9.0% | 2 (from cold pool) | Report cold metrics only against cold denominator |
| **Warm** | 40 | 12 | 30.0% | — | Report warm metrics only against warm denominator; **never average with cold** |
| **Payment** | — | — | — | — | **No payment was requested.** $29/month is a **pricing hypothesis** only (Assumption: A-002) |

**How evidence may be used**

- Justify building a **narrow** ownership-aware runbook (not a suite).
- Prioritize pilot design around the **two cold-origin volunteers**.
- Set conversion baselines for future landing tests **by cohort**.

**How evidence must not be used**

- Do not claim product-market fit.
- Do not claim validated pricing or willingness to pay.
- Do not blend cold+warm into “39 signups / 340 visits ≈ 11.5%” as a primary headline metric.
- Do not expand scope because signup count “felt good.”

---

## 2. Users & context

### 2.1 Primary persona

| Attribute | Detail |
|-----------|--------|
| **Name / label** | **Ops Alex** — small-agency onboarding owner |
| **Who they are** | Account manager, operations lead, or founder-operator at a 2–15 person agency (marketing, design, dev, consulting) |
| **Context / environment** | Desktop browser; multiple clients in flight; already uses email/Slack + Sheets/Notion + external CRM or drive links |
| **Top jobs-to-be-done** | Stand up a repeatable client onboarding path; assign owners; know what is due/late; close steps or record exceptions; hand off a clean history |
| **Current tools / workarounds** | Spreadsheet checklists, Notion databases, shared docs, chat pings, calendar reminders |
| **Triggers to seek a solution** | A client stalled mid-onboarding; a missed step discovered late; a new hire cannot see “how we onboard” |
| **Anti-persona (not for)** | Enterprise PMO; solo freelancers with one informal client; teams needing client-facing portals; accounting/bookkeeping operators |

### 2.2 Secondary users (MVP)

| Role | Need in MVP | Access model |
|------|-------------|--------------|
| **Step owner (colleague)** | See assigned steps, mark complete/exception, open links | **Assumption: A-003** — same workspace login / shared account is acceptable for pilot; no enterprise RBAC |
| **Agency founder (buyer)** | Care about stall rate and whether runs finish | Uses same UI; no separate exec dashboard in P0 |

### 2.3 Use contexts

- **When:** New client signed or kickoff scheduled; weekly status sweep; recovering from a missed step.
- **Where:** Desktop web during work hours.
- **Constraints:** Low training time; must work alongside existing file stores and CRMs via **links**, not replacement.

---

## 3. Solution

### 3.1 Value proposition

For **Ops Alex** who **cannot see who owns which onboarding step or what is late**, **Agency Client Onboarding Runbook** is an **ownership-aware runbook** that **turns one reusable workflow into a live client run with owners, due states, exceptions, links, CSV, and missed-step history**. Unlike **spreadsheets and generic task tools**, we **optimize for onboarding run state** (not infinite projects, not portals, not files).

### 3.2 Product principles (settle debates)

1. **One workflow, one live run focus** — master the single happy path before multi-template sprawl.
2. **Ownership is first-class** — a step without an owner is incomplete setup, not a power feature.
3. **Links over storage** — point at external records; never become the file system of record.
4. **Exceptions are success-adjacent** — blocking reality is recorded, not hidden behind forced “complete.”
5. **Manual before automated** — humans send reminders in MVP; automation is a later privilege.
6. **History is a product** — missed and recovered steps remain inspectable.

### 3.3 Scope summary

| In scope (MVP / P0) | Out of scope (v1) |
|---------------------|-------------------|
| Exactly **one** reusable workflow (ordered steps) | Multiple templates, branching logic, conditionals |
| **One live run** per client onboarding instance | Portals, client login, multi-run dashboards as a product surface |
| Explicit **owners** + **due states** (e.g. open / due soon / overdue / done / exception) | Enterprise roles, SSO, fine-grained ACLs |
| **Complete** + **exception** outcomes per step | File upload/storage, e-sign, bookkeeping |
| **Manual reminders** (user-triggered) | Automated sequences, SMS, AI chase |
| **External record links** on steps | Connectors, OAuth, bidirectional sync |
| **CSV export** of run/step state | Full migration importers |
| **Missed-step history** (audit of overdue / missed events) | Compliance certifications, immutability guarantees for auditors |
| Desktop web app for agency staff | Native mobile, public marketing site features beyond smoke needs |

---

## 4. User journeys (P0)

### Journey A — Define the reusable workflow

1. Ops Alex signs in and creates **the** agency onboarding workflow (name + description).
2. Adds ordered steps (title, optional description, default owner label/person, default due offset optional).
3. Reorders steps if needed; saves workflow.
4. Sees empty-state CTA: “Start a live run for a client.”

**Success state:** Workflow has ≥1 step and is ready to instantiate.  
**Failure / recovery:** Cannot save empty workflow name; cannot start a run with zero steps — show blocking validation.

### Journey B — Start one live run

1. From workflow, chooses **Start run**.
2. Enters client name (and optional external client record link).
3. System clones steps into a live run; owners and due dates initialized from defaults (editable).
4. Lands on **Run board** showing each step’s owner + due state.

**Success state:** Run exists with step instances, each with owner field and due state.  
**Failure / recovery:** Missing client name blocks start; partial save not allowed for create.

### Journey C — Execute: complete, exception, remind, link

1. Owner or Ops Alex opens a step.
2. Attaches/edits **external record link(s)** (URL + optional label).
3. Marks **Complete** *or* **Exception** (exception requires a short reason).
4. For still-open steps, triggers **Manual reminder** (copies message or records that a reminder was sent + timestamp + channel note).
5. Due states update (including overdue when past due and not terminal).

**Success state:** Step is terminal (complete/exception) or still open with fresher chase signal.  
**Failure / recovery:** Exception without reason rejected; invalid URL warned (Assumption: A-004 — soft validation OK).

### Journey D — Missed-step history + CSV

1. Ops Alex opens **History** on a run (or step).
2. Sees chronological events: became overdue / marked missed / completed late / exception / reminder sent.
3. Exports **CSV** of current run step matrix (client, step, owner, due, state, exception reason, links).

**Success state:** History explains what slipped; CSV opens in Sheets without manual cleanup for core columns.  
**Failure / recovery:** Empty history message if no events yet; export still works for current snapshot.

### Journey E — Close the run

1. When all steps are complete or exception, system offers **Close run**.
2. Closed run is read-mostly (history + CSV still available).
3. Ops Alex can start **another** run from the same workflow for a new client (second-run retention signal).

**Success state:** Run terminal; workflow reusable.  
**Failure / recovery:** Cannot close while any step still open (no silent force-close in P0 unless “force close with open steps” is explicitly chosen — **recommend block**; see open question Q-001).

---

## 5. Requirements

### 5.1 Functional requirements

| ID | Requirement | Priority | Acceptance criteria |
|----|-------------|----------|---------------------|
| **FR-001** | User can create and edit **exactly one** active onboarding workflow with ordered steps | P0 | Given a new account, when user creates a workflow with name + ≥1 step and saves, then it persists and reloads. User can add/edit/delete/reorder steps. UI does not offer a second concurrent workflow template in MVP (or additional templates are hidden/disabled). |
| **FR-002** | User can start **one live run** from the workflow for a named client | P0 | Given a saved workflow with ≥1 step, when user starts a run with client name, then a run is created with one step instance per workflow step, in order, linked to that client name. |
| **FR-003** | Each step instance has an **explicit owner** | P0 | Given a live run, when user views any step, then owner is visible. User can set/change owner (free-text name or simple person string in MVP). Steps can be filtered/sorted by owner on the run board. Empty owner is visually flagged. |
| **FR-004** | Each step instance has a **due state** derived from due date + terminal status | P0 | States include at least: `not_started` / `in_progress` (optional collapse OK), `due_soon` (Assumption: A-005 — within 48h), `overdue`, `completed`, `exception`. Given a due date in the past and non-terminal step, when board loads, then state is `overdue`. |
| **FR-005** | User can mark a step **complete** | P0 | Given an open step, when user marks complete, then state becomes `completed`, completion timestamp is stored, and step appears done on the board. |
| **FR-006** | User can mark a step as **exception** with reason | P0 | Given an open step, when user marks exception without reason, then save is rejected. With reason, state becomes `exception`, reason + timestamp stored, board shows exception affordance. |
| **FR-007** | User can send/log a **manual reminder** on an open step | P0 | Given an open step, when user triggers reminder, then system either (a) copies a reminder snippet to clipboard **and/or** (b) records reminder event with timestamp + optional note/channel. Reminder appears in history. No automatic send required for P0. |
| **FR-008** | User can attach **external record links** to a step | P0 | Given a step, when user adds URL + optional label, then link is stored and clickable (opens new tab). Multiple links per step allowed (Assumption: A-006 — ≥1 required support; ≥3 recommended). No file upload control exists. |
| **FR-009** | User can **export CSV** of a run | P0 | Given a live or closed run, when user exports CSV, then file downloads with columns at least: `client_name`, `step_order`, `step_title`, `owner`, `due_at`, `state`, `exception_reason`, `completed_at`, `link_urls`. Opens in standard spreadsheet tools. |
| **FR-010** | System records **missed-step history** | P0 | Given a step that becomes overdue, when due state flips to overdue (on load or periodic check), then a history event is recorded once per transition. History also records: completed, completed_late (if completed after due), exception, reminder_sent, owner_changed (nice-to-have same milestone). User can view chronological history for the run. |
| **FR-011** | User can **close a run** when all steps are terminal | P0 | Given all steps `completed` or `exception`, when user closes run, then run status is `closed` and edits to step outcomes are locked (history/CSV remain). |
| **FR-012** | User can start **another run** from the same workflow for a new client | P0 | Given an existing workflow, when user starts a new run with a different client name, then a separate run is created without mutating prior runs. *(Supports retention metric.)* |
| **FR-013** | Auth: user can sign up / sign in and only see own workspace data | P0 | Given user A’s runs, when user B signs in, then A’s data is not visible. Email/password or magic link acceptable. |
| **FR-014** | Run board lists all step instances with owner + due state at a glance | P0 | Given a run with N steps, when user opens run, then all N steps render with title, owner, due state without opening each step. |
| **FR-015** | Optional default due offset on workflow steps applies when run starts | P1 | Given workflow step default “due in D days,” when run starts, then step instance due_at = start_date + D unless overridden. |
| **FR-016** | Simple search/filter on run board by state or owner | P1 | Given mixed states, when user filters `overdue`, then only overdue steps show. |
| **FR-017** | Multiple workflows per workspace | P2 | Explicitly deferred; do not build in 6-week MVP. |
| **FR-018** | Email delivery of reminders | P2 | Deferred; manual only in P0. |

### 5.2 Non-functional requirements

| ID | Requirement | Priority | Acceptance criteria / validation method |
|----|-------------|----------|-----------------------------------------|
| **NFR-001** | Desktop web usable for core board at laptop widths | P0 | Primary flows usable at 1280×800 without horizontal dead-ends; no native mobile app required. Spot-check Journey B–D. |
| **NFR-002** | No in-app **file storage** for client artifacts | P0 | Code/product review: no upload endpoint, no object-storage binding for user files, no “attach file” control. Links only. |
| **NFR-003** | No **bookkeeping** entities or flows | P0 | No invoice/payment/ledger objects in data model or nav. Grep/IA review passes. |
| **NFR-004** | Cold vs warm analytics remain separable | P0 | If analytics installed, signup source cohort is a stored property (`cold` \| `warm` \| `unknown`). Reports never default to blended conversion as the only view. |
| **NFR-005** | Solo-operable cost envelope | P1 | MVP runs on a single low-cost stack (Assumption: A-007 — Cloudflare-native preferred per founder defaults) with no mandatory third-party AI spend. |
| **NFR-006** | Basic privacy: no leaking run data across accounts | P0 | Manual test: two accounts cannot read each other’s runs via direct object IDs (404/403). |
| **NFR-007** | Performance budget for pilot scale | P1 | Run board with ≤50 steps loads interactive UI in &lt;2s on broadband after first load (soft target; measure once in pilot). |

### 5.3 Tracking / analytics events

| Event | When | Properties |
|-------|------|------------|
| `signup_completed` | Account created | `cohort` (cold/warm/unknown) |
| `workflow_created` | First workflow saved | `step_count` |
| `run_started` | Live run created | `client_name_length` (not raw name if privacy-sensitive), `step_count` |
| `step_completed` | Step marked complete | `late` (bool) |
| `step_exception` | Step marked exception | — |
| `reminder_logged` | Manual reminder | — |
| `csv_exported` | Export downloaded | — |
| `run_closed` | Run closed | `exception_count`, `completed_count` |
| `wtp_recorded` | Founder logs pilot WTP answer | `answer` (yes/no/counter), **manual/offline OK** |

---

## 6. UX & content notes

### 6.1 Screens / pages (IA)

1. **Auth** — sign up / sign in  
2. **Workflow editor** — single workflow, ordered steps  
3. **Run list** — live + closed runs (minimal table)  
4. **Run board** — step instances, owners, due states (primary surface)  
5. **Step detail** — links, complete/exception, reminder, mini-history  
6. **Run history** — full event timeline  
7. **CSV export** — action on run board/detail  

No client portal routes. No billing pages. No files section.

### 6.2 Critical empty / error / permission states

| State | Behavior |
|-------|----------|
| **No workflow yet** | Empty state: explain “Define how you onboard once, then run it per client” + CTA Create workflow |
| **Workflow with 0 steps** | Block Start run; prompt Add first step |
| **No runs yet** | CTA Start first client run |
| **All steps healthy** | Board shows calm done/due_soon; no fake urgency |
| **Any overdue** | Overdue count badge on run; steps visually distinct |
| **Exception** | Reason visible on board tooltip or badge |
| **Closed run** | Banner “Closed — view only”; export still enabled |
| **Unauthorized / wrong account** | 403/404, no data leakage |
| **Invalid link URL** | Inline warning; allow save with warning (A-004) or require `http(s)://` |

### 6.3 Key copy (product-critical)

- **Onboarding value prop:** “One runbook. Clear owners. Nothing quietly missed.”  
- **Primary CTA:** “Start client run”  
- **Empty state:** “Your onboarding steps live here. Add the checklist you already run by hand.”  
- **Exception CTA:** “Record exception” (not “Skip”) — signals accountability.  
- **Reminder CTA:** “Log / copy reminder” — does not promise auto-email.  
- **Pricing:** Do **not** show $29/mo in-app during MVP pilot unless founder explicitly turns on a non-charging waitlist note. Off-product hypothesis only.

### 6.4 Due-state model (canonical)

| State | Meaning |
|-------|---------|
| `open` | Not terminal; not yet in due window (optional split: not_started / in_progress) |
| `due_soon` | Due within configured window (default 48h) |
| `overdue` | Past due, not terminal → emits missed/overdue history on transition |
| `completed` | Done |
| `exception` | Cannot complete as specified; reason required |

---

## 7. Data & integrations

### 7.1 Core concepts / entities

| Entity | Purpose | Key fields (conceptual) |
|--------|---------|-------------------------|
| **Workspace / Account** | Tenant boundary for solo/small team | `id`, `owner_user_id`, `cohort` |
| **User** | Login identity | `id`, `email`, `workspace_id` |
| **Workflow** | Reusable onboarding definition (one active in MVP) | `id`, `name`, `description` |
| **WorkflowStep** | Template step | `id`, `workflow_id`, `position`, `title`, `description`, `default_owner`, `default_due_offset_days` |
| **Run** | Live/closed instance for one client | `id`, `workflow_id`, `client_name`, `client_external_link`, `status` (`live`\|`closed`), `started_at`, `closed_at` |
| **RunStep** | Step instance | `id`, `run_id`, `position`, `title`, `owner`, `due_at`, `state`, `exception_reason`, `completed_at` |
| **StepLink** | External record pointer | `id`, `run_step_id`, `url`, `label` |
| **HistoryEvent** | Missed-step and action audit | `id`, `run_id`, `run_step_id?`, `type`, `payload`, `created_at` |

### 7.2 Data boundaries (hard walls)

| Data type | In this product? | Rule |
|-----------|------------------|------|
| Onboarding steps, owners, due states, exceptions | **Yes** | System of record for run execution state |
| External record **URLs** | **Yes** | Pointers only; content not ingested |
| Client files, contracts PDFs, creative assets | **No** | Remain in Drive/Dropbox/etc.; link out |
| Invoices, time entries, revenue, expenses | **No** | Bookkeeping stays external |
| Client portal messages | **No** | Out of scope |
| Compliance evidence packs | **No** | History is operational, not certified audit log |

### 7.3 Integrations

| System | Purpose | MVP? | Notes |
|--------|---------|------|-------|
| Email (transactional auth only) | Magic link / password reset | Y | Not for client reminder delivery |
| Stripe / payments | Subscriptions | **N** | Hypothesis only; no charge in MVP |
| CRM / PM tools | Sync | **N** | Links only |
| Object storage | Files | **N** | Explicitly forbidden for client artifacts |
| AI APIs | Suggestions | **N** | Excluded |

### 7.4 Permissions & roles

- **Default:** single workspace; all signed-in workspace members can edit runs (Assumption: A-003).  
- **Not in MVP:** client role, guest role, enterprise custom roles, field-level permissions.

---

## 8. Edge cases & risks

| Item | Impact | Mitigation |
|------|--------|------------|
| Users expect file uploads | Support noise; scope creep | Copy + empty-state: “Paste a link to the file where it already lives” |
| Reminder button expected to email teammates | Distrust if nothing sends | Label as “Copy/log reminder”; optional mailto: link |
| Overdue history spam on every page load | Noisy audit | Record **transition once**; idempotent overdue event |
| Pilot wants second workflow (sales vs delivery) | Pressure to expand | Document as P2; offer multiple **runs**, not templates |
| Warm vs cold metrics mixed in founder storytelling | False confidence | §1.6 rules; dashboard split |
| Pricing talk before value | Anchors wrong or scares pilots | No paywall; offline WTP interview at week 6 |
| Solo support burden from “agency OS” expectations | Time sink | Ruthless non-goals list in onboarding email to pilots |
| Shared-password team usage | Weak security | Accept for pilot; note upgrade path later |

**Support burden (indie)**

- Highest ticket risk: “Where do I upload files?” and “Why didn’t my teammate get an email?”  
- Pre-write two help snippets before pilot starts.

**Open product questions**

1. **Q-001:** Allow force-close with open steps, or hard-block until all terminal?  
2. **Q-002:** Owner as free-text vs simple workspace member list?  
3. **Q-003:** Is one workflow **enforced** in schema or only in UI?  
4. **Q-004:** Due-soon window 24h vs 48h vs custom?  
5. **Q-005:** Should reminder create a `mailto:` with prefilled owners, or clipboard text only?

---

## 9. Milestones (indie delivery — 6 weeks)

| Milestone | Week | Outcome | Exit criteria |
|-----------|------|---------|---------------|
| **M0 Spike** | W1 | Auth + data model + empty shell | User can sign in; Workflow/Run tables migrate; deploy preview URL |
| **M1 Vertical slice** | W2 | **First vertical slice (see below)** end-to-end | FR-001, FR-002, FR-003, FR-005, FR-014 paths work on preview; one demo script recorded |
| **M2 Run execution** | W3 | Due states, exceptions, links, manual reminders | FR-004, FR-006, FR-007, FR-008 green |
| **M3 History + CSV + close** | W4 | Missed-step history, export, close run, second run | FR-009–FR-012 green; seed script for overdue event |
| **M4 Pilot hardening** | W5 | Empty states, cohort tagging, help copy, bug bash | NFR-002/003/004/006 checked; both pilots invited with script |
| **M5 Pilot + decision** | W6 | Real usage + WTP conversations + kill/pivot/continue | Metrics in §1.5 reviewed; written go/no-go note |

### 9.1 First vertical slice (build this first)

**Goal:** Prove the core loop on production-like preview in **week 2**.

**Slice definition (must all work together):**

1. Sign in  
2. Create workflow with 3 steps (e.g. Kickoff call → Collect brand assets link → Schedule delivery)  
3. Start run for client “Acme”  
4. Assign owners on step instances  
5. Mark one step complete  
6. See board reflect owner + completed state  

**Explicitly not in the first slice:** CSV, history, reminders, exceptions, due-soon logic, polish.

**Demo script (5 minutes):** “Here is our onboarding checklist → here is Acme’s live run → Sam owns assets → done.”

### 9.2 Build vs buy

| Piece | Choice | Why |
|-------|--------|-----|
| Auth | Buy/managed (e.g. platform auth or lightweight library) | Do not invent crypto |
| DB | Serverless SQL (e.g. D1) | Fits solo + edge defaults |
| Hosting | Single web+API deploy | One surface to operate |
| Email | Transactional only if magic link needed | Avoid marketing ESP |
| CSV | Hand-rolled minimal serializer | Too small to buy |
| File storage | **Do not buy** | Out of boundary |

---

## 10. Launch & feedback

- **Beta audience:** The **two cold-smoke pilot volunteers** first; optionally 1–2 warm signups **tracked separately**, same product, separate reporting.  
- **Feedback channel:** 20-minute weekly call + shared note (or form) with prompts: stalled steps, missing ownership clarity, file-upload temptation, reminder expectations.  
- **Pilot script constraints:** Real or recent client onboarding only (not toy data after day 1).  
- **Kill / pivot triggers (week 6):**

| Trigger | Action |
|---------|--------|
| &lt;1 pilot activates (workflow + run + ≥3 step actions) | **Kill or major problem rethink** — demand may be polite signups only |
| Both pilots activate but **zero** second runs and qualitative “would not use weekly” | **Pivot** workflow shape or ICP; do not add portals/files to “save” it |
| Pilots only want file vault / portal / accounting | **Refuse scope absorption**; consider separate product or walk away |
| Activation OK + second run + positive WTP signal (even counter-price) | **Continue** — consider P1 filters/defaults and a real pricing test |
| Founder blends cold/warm to justify expansion | Process failure — reset reporting before any build expansion |

---

## 11. Appendix

### 11.1 Source materials used

- User brief: ownership-aware client-onboarding runbook for small agencies  
- Discovery constraints: owners, reusable steps, external links, CSV; files & bookkeeping separate  
- Smoke metrics: cold 27/300; warm 12/40; 2 pilot volunteers; no payment requested; $29/mo hypothesis  
- Explicit P0 list and exclusion list from founder  
- Timeline: six-week solo-developer MVP  

### 11.2 Assumptions log

| ID | Assumption | Impact if wrong |
|----|------------|-----------------|
| **A-001** | Status-quo cost is primarily time/reputation, not a measured $ figure | Messaging may need tighter ROI proof later |
| **A-002** | ~$29/month is a reasonable **hypothesis** for small agencies | WTP interviews may force $0 tool expectation or higher price |
| **A-003** | Shared workspace without enterprise RBAC is enough for pilot | May need simple member invites earlier |
| **A-004** | Soft URL validation is acceptable | Bad links reduce trust; tighten if pilots complain |
| **A-005** | Due-soon window default = 48 hours | Adjust if agencies think weekly |
| **A-006** | Multiple links per step needed soon | If only one link ever used, simplify UI |
| **A-007** | Cloudflare-native web stack is preferred default for this founder | Swap stack without changing product requirements |
| **A-008** | “One workflow” means one **template** per workspace in MVP, many runs | If agencies refuse single template, FR-017 accelerates |

### 11.3 Glossary

| Term | Definition |
|------|------------|
| **Workflow** | Reusable ordered checklist for how the agency onboards clients |
| **Run** | One client’s live (or closed) instance of the workflow |
| **Owner** | Named person accountable for a step instance |
| **Due state** | Derived lifecycle label from due date + completion/exception |
| **Exception** | Terminal non-completion with required reason |
| **External record link** | URL pointing to a source of truth outside this product |
| **Missed-step history** | Event log of overdue/missed and related recovery actions |
| **Cold traffic** | Unwarmed visitors (300 → 27 in smoke) |
| **Warm traffic** | Pre-existing relationship/list traffic (40 → 12); reported separately |

### 11.4 Rejected ideas (do not re-litigate in MVP)

| Idea | Why rejected now |
|------|------------------|
| Client portal | Different product; auth + UX explosion |
| File storage | Discovery boundary; compliance/support weight |
| Bookkeeping | Separate category |
| AI task writing / auto-chase | Unvalidated; cost + trust |
| Connectors to PM tools | Maintenance tax pre-retention |
| Migration wizard | No incumbent lock-in proven |
| Mobile apps | Desktop ops first |
| Enterprise roles / SSO | Wrong ICP segment |
| Compliance certification scope | Not the wedge |
| In-app $29 checkout | Payment not requested; hypothesis only |

### 11.5 Requirements traceability (P0 → journeys)

| P0 capability | FR IDs | Journeys |
|---------------|--------|----------|
| One workflow | FR-001 | A |
| One live run | FR-002, FR-012, FR-014 | B, E |
| Owners / due states | FR-003, FR-004 | B, C |
| Completion / exceptions | FR-005, FR-006 | C |
| Manual reminders | FR-007 | C |
| Links | FR-008 | C |
| CSV | FR-009 | D |
| Missed-step history | FR-010 | D |
| Close / hygiene | FR-011, FR-013 | E |

---

*End of PRD v0.1 — ready for founder review and ticket breakdown from FR-001 onward.*
