# PRD: SoloProposal AI

| Field | Value |
|---|---|
| Status | Draft for review |
| Owner | Founder |
| Last updated | 2026-07-31 |
| Version | 0.1 |
| Primary persona | Independent web designers selling fixed-scope client projects |
| Platform | Desktop-first responsive web app |
| Source material | “An AI app for freelancers” |

> **Product-shaping assumption:** “AI app for freelancers” is too broad for an indie MVP. This PRD selects one high-value job: turning an unstructured client inquiry into a professional proposal. The product may expand into contracts, invoicing, and project operations only after validating this wedge.

## 1. Overview

### 1.1 One-liner

SoloProposal AI helps independent web designers turn messy client inquiries into accurate, editable proposals containing scope, deliverables, milestones, pricing, exclusions, and a client-ready email.

### 1.2 Problem statement

- **Current situation:** Freelancers collect project details through calls, messages, notes, and email, then manually assemble proposals using documents, templates, spreadsheets, or generic AI chat tools.
- **Pain:** The process is repetitive and slow, while missing assumptions or exclusions can cause scope disputes and unpaid work.
- **Why now:**  
  **Assumption:** Freelancers are increasingly comfortable using generative AI, but generic chat tools lack persistent business context, structured proposal workflows, and safeguards around scope and pricing.
- **Cost of the status quo:**  
  **Assumption:** Proposal preparation consumes non-billable time and inconsistent proposals reduce confidence, response speed, and conversion.

### 1.3 Goals

**Product goals**

1. Help a freelancer create a client-ready first proposal in 15 minutes or less.
2. Surface missing information and risky assumptions before proposal generation.
3. Preserve freelancer control over scope, pricing, terms, and final wording.
4. Produce consistently structured output without requiring prompt-writing skills.

**Business goals**

1. Validate whether proposal generation is painful enough to support a paid product.
2. Recruit 10 paying pilot users within eight weeks of pilot launch.
3. Identify one repeatable acquisition channel for independent web designers.
4. Learn whether the proposal workflow can expand into a broader freelancer operations product.

### 1.4 Non-goals for v1

The MVP will not include:

- General-purpose AI chat.
- Project management, time tracking, or task delivery.
- Invoicing, bookkeeping, tax advice, or payment collection.
- Legally binding contracts or electronic signatures.
- Automatic pricing decisions or promises about project profitability.
- A CRM, lead marketplace, or automated sales outreach.
- Agency teams, shared workspaces, roles, or approvals.
- Native mobile applications.
- Custom proposal-template design or pixel-level document layout.
- Automatic email sending or inbox access.

### 1.5 Success metrics

Targets below are hypotheses until customer discovery establishes baselines.

| Metric | Definition | Initial target | Timeframe |
|---|---|---:|---|
| Activation | New users who export a proposal within 24 hours of signup | ≥60% | Pilot |
| Time to value | Median time from starting a brief to first export | ≤15 minutes | Pilot |
| Output usefulness | Exported proposals rated at least 4/5 by their creator | ≥70% | Pilot |
| Repeat use | Activated users who create a second proposal | ≥30% | Within 30 days |
| Paid validation | Pilot users who pay for continued access | 10 users | First 8 weeks |
| Generation completion | Started generations that produce an editable result | ≥95% | Weekly |

## 2. Users and context

### 2.1 Primary persona

| Attribute | Detail |
|---|---|
| Label | Independent web designer |
| Who they are | A solo professional selling fixed-scope website projects directly to small-business clients |
| Context | Manages sales, delivery, and administration without dedicated operations support |
| Primary job-to-be-done | “When a prospect describes a project, help me turn the conversation into a clear proposal I can confidently send.” |
| Current alternatives | Google Docs, Notion templates, previous proposals, spreadsheets, ChatGPT, or writing from scratch |
| Trigger | A qualified prospect asks for a proposal, estimate, or statement of work |
| Desired outcome | A professional proposal that accurately defines what is included, excluded, priced, and expected next |
| Anti-persona | Agencies, marketplace gig workers, hourly staff augmentation, and regulated professionals requiring specialized legal documents |

### 2.2 Secondary users

No secondary user is included in the MVP. Clients receive exported documents but do not use the product directly.

### 2.3 Use context

- Primarily desktop use immediately after a discovery call or client email.
- The freelancer may paste incomplete or contradictory notes.
- The proposal may contain confidential client information.
- Users need manual control because scope, pricing, and terms vary by project.
- English-language proposals and user interface are assumed for MVP.

## 3. Solution

### 3.1 Value proposition

For independent web designers who lose non-billable time turning client conversations into proposals, SoloProposal AI is a guided proposal workspace that finds missing details and creates an editable, client-ready draft. Unlike generic AI chat, it retains the freelancer’s business defaults, uses a consistent proposal structure, and requires human confirmation of consequential assumptions.

### 3.2 Product principles

1. **Clarify before generating:** Expose missing information instead of silently inventing it.
2. **The freelancer remains accountable:** Scope, price, terms, and final output always require user review.
3. **Structured workflow over open-ended chat:** Optimize for one repeatable job.
4. **Editable by default:** Every generated section can be changed without regenerating the entire proposal.
5. **Fast first value:** A new user should reach a useful draft before completing extensive configuration.

### 3.3 Scope summary

| In scope: MVP/P0 | Out of scope: v1 |
|---|---|
| Lightweight business-profile setup | Full freelancer business suite |
| Structured or pasted client brief | Email and calendar ingestion |
| Missing-information analysis | Autonomous client communication |
| Clarifying questions and explicit assumptions | AI-determined final pricing |
| Structured proposal generation | Contracts and legal advice |
| Section-level editing and regeneration | Collaborative document editing |
| User-controlled pricing and terms | Client portal or e-signature |
| Print-ready PDF and copy export | Custom template marketplace |
| Saved drafts and basic versions | CRM and deal automation |
| Delete/export account data | Agency and team workflows |

## 4. P0 user journeys

### Journey A — Set up business defaults

1. The user creates an account.
2. The user enters their service type, business name, preferred tone, currency, default payment terms, and standard exclusions.
3. The system previews how those defaults will influence a proposal.
4. The user saves the profile or skips optional fields.

**Success state:** The profile is available as reusable context for future proposals.

**Failure/recovery:** Validation identifies invalid or missing required fields without discarding entered data.

### Journey B — Turn an inquiry into a proposal

1. The user starts a new proposal.
2. The user pastes client notes or completes a structured brief.
3. The system identifies missing, ambiguous, or conflicting information.
4. The system presents clarifying questions and labels any proposed assumptions.
5. The user answers, edits, or explicitly skips each question.
6. The system generates a structured proposal.
7. The user reviews and edits the result.

**Success state:** The user receives a complete, editable proposal whose assumptions are visible.

**Failure/recovery:** If generation fails, the brief remains saved and the user can retry without re-entering information.

### Journey C — Finalize and export

1. The user reviews scope, milestones, pricing, exclusions, and terms.
2. The product warns about unresolved placeholders or unconfirmed assumptions.
3. The user edits individual sections or requests section-level regeneration.
4. The user previews the final document.
5. The user exports a print-ready PDF or copies the formatted content.
6. The product records the export and requests lightweight feedback.

**Success state:** The user obtains a proposal they can send through their existing communication channel.

**Failure/recovery:** Export errors preserve the completed proposal and offer retry or copy-to-clipboard as a fallback.

## 5. Requirements

### 5.1 Functional requirements

| ID | Requirement | Priority | Acceptance criteria |
|---|---|---:|---|
| FR-001 | The user can create an account and securely access saved proposals. | P0 | A user can sign in, sign out, and access only their own data; an expired session prompts reauthentication without deleting saved work. |
| FR-002 | The user can configure reusable business defaults. | P0 | The profile supports business name, service description, tone, currency, payment terms, and exclusions; saved values appear in subsequent drafts; optional fields can be skipped. |
| FR-003 | The user can create a project brief from pasted notes or structured fields. | P0 | The user can enter client name, project objective, deliverables, timing, constraints, and notes; a draft persists before AI generation; blank required input is rejected with an actionable message. |
| FR-004 | The system identifies gaps, conflicts, and ambiguous scope before generation. | P0 | Analysis returns categorized questions or a “sufficient information” state; inferred facts are labeled as assumptions; the system does not invent a price or deadline. |
| FR-005 | The user can resolve or explicitly skip clarification questions. | P0 | Each question can be answered, edited, or skipped; skipped items remain visibly marked; user responses become part of proposal context. |
| FR-006 | The system generates a structured proposal from confirmed inputs. | P0 | Output contains client summary, objectives, deliverables, process, milestones, pricing, exclusions, client responsibilities, terms, and next steps; absent information appears as a visible placeholder rather than a fabricated fact. |
| FR-007 | The user retains direct control over pricing. | P0 | The user can enter fixed-price items, optional items, currency, deposit, and payment schedule; AI-generated text cannot overwrite confirmed amounts without explicit approval; totals are calculated consistently. |
| FR-008 | The user can edit and selectively regenerate proposal sections. | P0 | All content is editable; a single section can be regenerated without changing other sections; regeneration shows the proposed replacement before it is accepted. |
| FR-009 | The system warns before exporting incomplete work. | P0 | Unresolved placeholders, skipped high-impact questions, and unconfirmed pricing are listed; the user may return to edit or explicitly export despite the warning. |
| FR-010 | The user can export the proposal. | P0 | The proposal has a readable print preview; PDF export preserves headings, tables, and page breaks; formatted copy is available if PDF generation fails. |
| FR-011 | The user can save, duplicate, rename, and delete proposals. | P0 | Changes persist across sessions; deletion requires confirmation; duplicating a proposal creates an independent draft without carrying over export history. |
| FR-012 | The user can rate generated output and provide optional feedback. | P0 | After export, the user can submit a 1–5 usefulness rating and optional text; feedback submission never blocks export. |
| FR-013 | The user can apply simple brand settings. | P1 | A user can upload a logo and select an accent color; unsupported files receive an actionable error; branding appears in preview and export. |
| FR-014 | The user can share a read-only proposal link. | P1 | The user can create and revoke a unique link; recipients cannot edit the proposal or access other user data. |
| FR-015 | The user can track basic proposal status. | P1 | A proposal can be marked draft, sent, accepted, declined, or archived; status changes are timestamped. |
| FR-016 | The product can sell a subscription through hosted checkout. | P1 | A user can purchase, view, and cancel a plan; failed payments do not delete proposals; plan limits are shown before enforcement. |
| FR-017 | The product supports reusable proposal templates. | P2 | Users can save a completed structure as a template and choose it when starting a proposal. |
| FR-018 | The product supports contracts, e-signatures, invoicing, or payments. | P2 | Requires a separate validated specification before implementation. |

### 5.2 Non-functional requirements

| ID | Requirement | Priority | Notes |
|---|---|---:|---|
| NFR-001 | Protect confidential client and proposal data. | P0 | Encrypt data in transit and at rest; do not expose one user’s data to another; disclose AI-provider data handling. |
| NFR-002 | Provide user-controlled deletion. | P0 | Users can delete individual proposals and request account-data deletion. |
| NFR-003 | Complete most AI generations within 30 seconds. | P0 | Initial pilot target: at least 90% under normal input sizes; display progress and allow retry on timeout. |
| NFR-004 | Prevent duplicate generation charges from retries. | P0 | Repeated requests with the same operation identifier return the existing result or create only one billed generation. |
| NFR-005 | Maintain an LLM cost budget. | P0 | **Assumption:** target variable AI cost is at most US$0.20 per completed proposal during the pilot; record usage by generation. |
| NFR-006 | Meet an accessible web baseline. | P0 | P0 flows are keyboard operable, fields have labels, focus is visible, and status/error messages are announced to assistive technology. |
| NFR-007 | Preserve work during recoverable failures. | P0 | Briefs and manual edits are autosaved; a failed generation or export does not erase the current draft. |

### 5.3 Analytics events

| Event | Trigger | Key properties |
|---|---|---|
| `account_created` | Signup completes | acquisition source |
| `profile_completed` | Business defaults saved | fields completed |
| `brief_started` | New brief created | input method |
| `brief_analyzed` | Gap analysis completes | question count, duration, error |
| `proposal_generated` | Draft generation completes | duration, estimated cost, error |
| `section_regenerated` | User regenerates one section | section, accepted/rejected |
| `proposal_exported` | PDF or copy export succeeds | format, time since brief started |
| `output_rated` | User submits feedback | rating, feedback present |
| `proposal_deleted` | User confirms deletion | proposal age |
| `subscription_started` | Payment completes | plan, acquisition source |

Analytics must exclude proposal text, client names, and other confidential content.

## 6. UX and content notes

### 6.1 Information architecture

- Sign in and account recovery
- Dashboard
  - Recent proposals
  - New proposal
- New proposal
  - Brief
  - Clarification
  - Generate
- Proposal editor
  - Content
  - Pricing
  - Preview
  - Export
- Business profile
- Account, privacy, and billing settings

### 6.2 Critical states

- **No proposals:** Explain the outcome and provide one primary “Create proposal” action.
- **Insufficient brief:** Explain which details are missing and why they matter.
- **Conflicting information:** Show both conflicting statements and ask the user to resolve them.
- **AI timeout:** Preserve the brief, explain that no work was lost, and offer retry.
- **Unresolved placeholders:** List every unresolved item before export.
- **Export failure:** Offer retry and formatted copy as a fallback.
- **Usage limit reached:** Preserve work and clearly explain the limit and available action.
- **Deleted account or proposal:** Confirm what will be removed and whether recovery is possible.

### 6.3 Key copy

- **Onboarding value proposition:** “Turn the client conversation into a proposal you can confidently send.”
- **Primary CTA:** “Create proposal”
- **Clarification heading:** “A few details could prevent scope problems”
- **Generation disclaimer:** “Review scope, pricing, dates, and terms before sending.”
- **Empty state:** “Paste your client notes. We’ll organize the gaps before drafting.”

## 7. Data and integrations

### 7.1 Core entities

| Entity | Purpose | Key fields |
|---|---|---|
| User | Account identity and ownership | ID, email, created date, account state |
| Business Profile | Reusable freelancer context | business name, services, tone, currency, terms, exclusions |
| Client | Minimal proposal recipient context | ID, display name, company name |
| Project Brief | Source input and clarification state | objective, notes, deliverables, constraints, answers, assumptions |
| Proposal | Editable client-facing document | title, sections, pricing, status, revision, timestamps |
| Generation Run | AI request record | input reference, model, status, duration, cost estimate, error |
| Export | Export history | format, timestamp, proposal revision |
| Feedback | Output-quality signal | rating, optional comment |
| Subscription | Paid-plan state | provider customer ID, plan, status |

### 7.2 Integrations

| System | Purpose | MVP? | Notes |
|---|---|---:|---|
| Authentication provider | Secure account access | Yes | Prefer managed authentication |
| LLM provider | Analyze briefs and generate proposals | Yes | Require suitable data-retention terms and provider abstraction |
| PDF renderer | Print-ready export | Yes | Prefer a reliable managed or browser-native approach |
| Product analytics | Funnel and reliability measurement | Yes | Do not send proposal content or client PII |
| Error monitoring | Diagnose failures | Yes | Redact user-entered content |
| Stripe Checkout | Paid subscription | Pilot/P1 | Use hosted checkout to reduce billing scope |
| Email provider | Transactional account email | If required | No proposal delivery in MVP |

### 7.3 Permissions and roles

The MVP is single-user. Every business profile, brief, proposal, generation, and export belongs to exactly one user. Team access and shared editing require a separate product decision.

## 8. Edge cases and risks

| Item | Impact | Mitigation |
|---|---|---|
| AI invents requirements, dates, or terms | Scope disputes and lost trust | Label assumptions, prohibit fabricated price/date values, and warn before export |
| User treats output as legal advice | Liability and unsafe reliance | Clearly position terms as editable business language, not legal advice |
| Client information is sensitive | Privacy concerns may block adoption | Minimize collection, document provider handling, redact logs, support deletion |
| Generated proposals feel generic | Users return to templates or ChatGPT | Use business defaults, structured clarification, section regeneration, and output feedback |
| PDF formatting creates support tickets | High maintenance burden for a solo founder | Offer one constrained template initially; defer custom layouts |
| Broad freelancer positioning weakens messaging | Low conversion and unclear roadmap | Launch to one profession and one job-to-be-done |
| Users expect CRM, invoicing, and contracts | Scope expansion and slow delivery | State non-goals in onboarding and collect demand before expansion |
| AI cost exceeds subscription economics | Unsustainable margins | Track cost per generation, cap context, cache safe intermediate results, set usage limits |
| Poor inputs create poor outputs | Low perceived quality | Provide examples, structured fields, clarification questions, and visible placeholders |
| Users need many language or jurisdiction variants | Support and compliance complexity | Launch with English and user-supplied terms; validate expansion markets separately |

**Support-burden hotspots**

- Custom PDF layouts and brand requests.
- Questions about whether generated terms are legally valid.
- Recovery of deleted proposals.
- Confusion over usage limits and failed generations.
- Output-quality complaints caused by incomplete briefs.

## 9. Open product questions

1. Is the initial profession specifically web designers, or another freelancer segment with stronger proposal frequency and willingness to pay?
2. Should the product optimize for fixed-price projects only, or support hourly engagements in MVP?
3. Which export matters most: PDF, Google Docs, Word, or a shareable web link?
4. Which markets, currencies, and languages should the first release support?
5. Is the initial business model per month, per proposal, or a limited free trial followed by subscription?

## 10. Milestones

Timelines are planning assumptions for one developer, not delivery commitments.

| Milestone | Outcome | Exit criteria |
|---|---|---|
| M0 — Workflow spike | Validate the core input-to-output experience without full product infrastructure | Five representative briefs produce structured proposals; gaps and hallucination patterns are documented; three target users review outputs |
| M1 — Vertical slice | One user can complete the entire P0 workflow | Sign in → enter brief → clarify → generate → edit → export works with saved state and error recovery |
| M2 — Private MVP | A small cohort can use the product with minimal founder intervention | 10 invited users onboard; privacy controls, telemetry, feedback, and generation-cost tracking work |
| M3 — Paid pilot | Test willingness to pay and repeat usage | Hosted billing works; at least 10 users are asked to pay; activation, repeat use, and cancellations are reviewed |
| M4 — Scope decision | Decide whether to deepen proposals or expand the workflow | Evidence supports one next investment: templates, sharing/status, or an adjacent freelancer task |

**Suggested first build slice:** A single-page prototype that accepts pasted discovery notes, asks clarification questions, generates a fixed proposal structure, and supports manual editing. Test output usefulness before building billing, branding, or a full dashboard.

**Build vs. buy**

- Buy managed authentication and hosted billing.
- Use an external LLM behind a small provider interface.
- Start with one controlled print/PDF template.
- Build the proposal workflow, clarification logic, and editing experience; these are the product’s differentiation.

## 11. Launch and feedback

- **Beta audience:** 10–20 independent web designers who regularly send fixed-price proposals.
- **Recruitment:** Founder communities, design communities, personal network, and direct outreach to freelancers who publicly offer project-based services.
- **Feedback channel:** Short in-product rating after export plus optional 20-minute interviews with activated and churned users.
- **Pilot behavior to observe:** Time to first export, edits by section, skipped clarification questions, repeat proposals, and willingness to pay.
- **Kill or pivot triggers:**
  - Fewer than 30% of qualified testers export a proposal after completing a brief.
  - Users consistently prefer a saved prompt in a generic AI tool.
  - Proposal creation is too infrequent to support recurring pricing.
  - Users value another adjacent problem—such as client follow-up or scope-change management—substantially more.
  - Output requires high-touch founder editing to become usable.

## 12. Assumptions log

| ID | Assumption | Impact if wrong |
|---|---|---|
| A-001 | Proposal creation is the strongest initial wedge for an AI freelancer product. | A different job-to-be-done should replace the MVP scope. |
| A-002 | Independent web designers are the best first persona. | Messaging, templates, and workflow may need another vertical. |
| A-003 | Users primarily work on desktop. | Mobile-first capture or native applications may become necessary. |
| A-004 | English-only output is acceptable for the first pilot. | Localization becomes an MVP dependency. |
| A-005 | Users will manually send exported proposals. | Sharing or email integration must move into P0. |
| A-006 | A constrained proposal format is sufficient initially. | Customization will increase design and support scope. |
| A-007 | Users will trust a hosted product with client notes if privacy is explicit. | Local processing, zero-retention providers, or stronger controls may be required. |
| A-008 | A US$0.20 variable-cost target per proposal supports viable pricing. | Model choice, limits, or pricing must change. |
| A-009 | Repeat proposal creation is frequent enough for subscription pricing. | Per-proposal credits or a broader workflow may be more appropriate. |

## Decisions to confirm

1. Confirm the initial wedge: proposal creation rather than a general freelancer assistant.
2. Confirm the first persona: independent web designers selling fixed-price projects.
3. Confirm the first output channel: PDF/manual sending rather than share links or email integration.

## Best next implementation slices

1. Prototype brief analysis and structured proposal generation with five realistic sample inquiries.
2. Build the editable proposal flow with explicit assumptions, pricing control, and incomplete-work warnings.
3. Add persistence, export, privacy controls, telemetry, and pilot feedback collection.

Customer discovery should precede substantial implementation. Validate proposal frequency, current workaround, consequence of a poor proposal, preferred export format, and willingness to pay with at least 8–12 target freelancers; the rest of the PRD can then be revised from evidence rather than assumptions.
