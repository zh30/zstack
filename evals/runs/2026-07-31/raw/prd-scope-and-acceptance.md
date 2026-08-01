# PRD: SoloSchedule

| Field | Value |
|---|---|
| Status | Draft |
| Owner | Founder |
| Last updated | 2026-07-31 |
| Version | 0.1 |
| Primary persona | Independent consultant or coach selling scheduled 1:1 sessions |
| Platform | Responsive web app |
| Source | User-provided feature notes |

> Scope decision: A solo-developer MVP cannot credibly make team round-robin, CRM, customer-facing analytics, and two native apps P0. They introduce separate multi-user, data-management, reporting, and platform workloads. Every requested feature is retained below, but P0 is limited to the smallest paid-booking loop. “Seamless” and “delightful” are product aspirations; concrete acceptance criteria define what those words mean.

## 1. Overview

### 1.1 One-liner

SoloSchedule helps independent service professionals publish their availability, accept paid appointments, and keep bookings synchronized with their calendar.

### 1.2 Problem

Independent consultants and coaches often combine a calendar, scheduling tool, payment link, and manual messages to sell appointments. This creates avoidable administration, payment chasing, and double-booking risk.

### 1.3 MVP outcome

A host can connect a calendar, publish one paid event type, share a booking link, and receive a confirmed paid booking without manual coordination.

### 1.4 Assumptions

- The initial user sells paid one-to-one appointments.
- Google Calendar and Stripe are sufficient for the first pilot.
- Hosts can use Stripe’s dashboard for refunds in v1.
- The product is responsive web-first; no native application is required to validate demand.
- SaaS pricing and the initial geographic market remain TBD.

### 1.5 Goals

- Reduce setup-to-published-booking-page time.
- Prevent confirmed double bookings.
- Combine scheduling and payment into one invitee flow.
- Validate that a narrow group of solo professionals will repeatedly use and pay for the product.

### 1.6 Non-goals for v1

- Teams, organizations, roles, or round-robin assignment.
- A general-purpose CRM or sales pipeline.
- Customer-facing analytics dashboards.
- Native iOS or Android applications.
- Multiple calendar providers.
- Group events, classes, recurring appointments, or multi-host meetings.
- Tax calculation, invoicing, subscriptions, coupons, or automated refund policies.

### 1.7 Success metrics

| Metric | Definition | Initial signal |
|---|---|---|
| Activation | Accepted pilot users who connect a calendar and publish an event type | At least 60% |
| Time to value | Median time from signup to published booking link | Under 10 minutes |
| Booking completion | Visitors who select a slot and complete required payment | At least 70% |
| Conflict rate | Confirmed bookings overlapping a calendar conflict | 0 |
| Repeat value | Activated hosts receiving at least three bookings within 30 days | 5 of the first 10 hosts |

Targets are assumptions for the pilot and should be revised after baseline data exists.

## 2. Users

### Primary persona

| Attribute | Detail |
|---|---|
| User | Independent consultant or coach |
| Primary job | Let a client choose and pay for an available appointment |
| Current workaround | Calendar, scheduling link, payment link, and manual messages |
| Trigger | Increasing coordination work or unpaid/no-show appointments |
| Anti-persona | Teams coordinating meetings among several staff members |

The invitee is a secondary user who should be able to complete a booking without creating an account.

## 3. Product principles

1. One reliable paid-booking path before additional scheduling modes.
2. Calendar availability is the source of truth.
3. The host controls availability, duration, price, and cancellation.
4. Invitees should never wonder whether payment or booking succeeded.
5. Every partial failure must be visible and recoverable.

## 4. Scope

| Feature | Priority | Decision |
|---|---:|---|
| Google Calendar sync | P0 | Required for availability and event creation |
| Public booking page | P0 | Core acquisition and booking surface |
| Stripe payments | P0 | Core to the paid-appointment wedge |
| Internal product instrumentation | P0 | Required to evaluate the pilot |
| Customer-facing analytics | P1 | Add after reliable booking data exists |
| Lightweight contact history | P1 | Derived from bookings, not a standalone CRM |
| Team round-robin | P2 | Conflicts with the solo-user MVP |
| Full CRM | P2 | Separate product surface and data model |
| Native iOS and Android apps | P2 | Responsive web validates demand first |

## 5. P0 journeys

### Host publishes an event

1. The host signs in and selects a time zone.
2. The host authorizes Google Calendar and selects calendars that block availability.
3. The host defines weekly availability.
4. The host creates an event type with duration and price.
5. The system validates the configuration and produces a public URL.

**Success state:** The URL displays bookable slots that exclude calendar conflicts.

**Recovery:** Expired authorization or invalid availability is identified with a specific corrective action.

### Invitee books and pays

1. The invitee opens the public booking page.
2. The page shows slots in the invitee’s detected time zone.
3. The invitee selects a slot and enters contact details.
4. The system rechecks availability and temporarily holds the slot.
5. The invitee completes Stripe Checkout.
6. The system confirms the booking, creates the calendar event, and sends confirmation messages.

**Success state:** Both parties see the same confirmed time and payment status.

**Recovery:** Failed or abandoned payment releases the hold. A slot taken during checkout produces an explicit conflict message and alternative slots.

### Host manages a booking

1. The host opens the dashboard.
2. The host reviews upcoming bookings and payment status.
3. The host cancels a booking when necessary.
4. The calendar event and both parties’ notifications are updated.

## 6. Functional requirements

| ID | Requirement | Priority | Acceptance criteria |
|---|---|---:|---|
| FR-001 | A host can create an account and set a canonical time zone. | P0 | Time zone is required before publishing; saved times remain consistent after sign-out and sign-in. |
| FR-002 | A host can connect one Google account and select calendars that block availability. | P0 | OAuth success displays the connected account; busy events remove overlapping slots; revoked access stops publishing and prompts reconnection. |
| FR-003 | A host can define weekly availability and date-specific overrides. | P0 | Slots are generated only inside allowed periods; overrides supersede weekly rules; daylight-saving transitions are handled using named time zones. |
| FR-004 | A host can create and publish one or more event types. | P0 | Each published type has a title, duration, price, currency, availability, and unique public URL; incomplete types cannot be published. |
| FR-005 | An invitee can view and select an available slot without an account. | P0 | The page shows host, event, duration, price, and invitee-local time; unavailable dates and an empty state are explicit. |
| FR-006 | The system prevents two invitees from confirming the same slot. | P0 | Availability is rechecked server-side before checkout; a temporary hold has a defined expiry; only one confirmation can succeed for a host and time interval. |
| FR-007 | An invitee can pay through Stripe Checkout. | P0 | The displayed amount matches Checkout; cancellation or failure does not confirm a booking; webhook processing is idempotent; card details never pass through SoloSchedule servers. |
| FR-008 | A successful payment produces one confirmed booking and calendar event. | P0 | Duplicate webhooks do not create duplicates; the event contains the correct attendees and time; a calendar-write failure is retried and surfaced to the host. |
| FR-009 | Host and invitee receive booking confirmation. | P0 | Confirmation includes event name, date, time zone, payment status, and cancellation link; notification failure does not duplicate or invalidate the booking. |
| FR-010 | A host can view and cancel upcoming bookings. | P0 | The dashboard shows booking and payment status; cancellation updates the calendar and notifies both parties; refund handling links the host to Stripe in v1. |
| FR-011 | The product records funnel and reliability events. | P0 | Signup, calendar connection, publication, slot selection, checkout start, payment success/failure, confirmation, and cancellation are recorded without card data. |
| FR-012 | A host can view basic booking and revenue analytics. | P1 | The host can select a date range and see bookings, cancellations, completed payment value, and booking-page conversion. |
| FR-013 | A host can review lightweight contact history. | P1 | Contacts are created from bookings and show name, email, booking history, and total paid; no manual pipeline or lead stages. |
| FR-014 | Organizations can distribute bookings by round-robin rules. | P2 | Requires organization membership, member availability, deterministic assignment, manual override, and reassignment behavior before promotion to P0. |
| FR-015 | Hosts can manage bookings through native mobile apps. | P2 | Requires separately scoped iOS and Android PRDs after web retention is demonstrated. |
| FR-016 | Hosts can manage contacts in a full CRM. | P2 | Requires separately validated workflows for notes, fields, pipeline stages, import/export, and deletion. |

## 7. Non-functional requirements

| ID | Requirement | Priority | Notes |
|---|---|---:|---|
| NFR-001 | Booking confirmation must be idempotent and conflict-safe. | P0 | Payment, booking, and calendar writes require explicit intermediate states and retry behavior. |
| NFR-002 | OAuth credentials and personal data must be protected. | P0 | Use least-privilege scopes, encrypted storage, secure session cookies, and account disconnection/deletion controls. |
| NFR-003 | Booking is keyboard-accessible and screen-reader usable. | P0 | Target WCAG 2.2 AA for the public flow. |
| NFR-004 | Time calculations remain correct across time zones and daylight-saving changes. | P0 | Automated tests cover representative DST gaps, repeated hours, and cross-zone booking. |
| NFR-005 | Public booking pages remain usable on mobile web. | P0 | Slot selection, forms, Stripe redirect, and confirmation require no horizontal scrolling. |

## 8. UX and information architecture

- Sign in and onboarding
- Calendar connection
- Availability settings
- Event-type editor
- Public booking page
- Stripe Checkout
- Booking confirmation
- Host booking dashboard
- Account and integration settings

Critical states include no available slots, expired calendar authorization, slot conflict, abandoned payment, successful payment awaiting calendar creation, notification failure, and canceled booking.

## 9. Data and integrations

### Core entities

| Entity | Purpose |
|---|---|
| Host | Account, time zone, and integration ownership |
| Calendar connection | OAuth identity, token state, and blocking calendars |
| Availability rule | Weekly windows and date overrides |
| Event type | Public slug, duration, price, currency, and publication state |
| Slot hold | Temporary reservation during checkout |
| Booking | Invitee, interval, lifecycle, and external identifiers |
| Payment | Stripe session, payment status, amount, and currency |
| Contact | Booking-derived invitee history |
| Product event | Funnel and reliability measurement |

### External systems

- Google Calendar API for busy-time reads and event writes.
- Stripe Checkout and webhooks for payment.
- A transactional email provider for confirmations.

Build-versus-buy recommendation: use hosted Stripe Checkout and a managed email service. Do not build card collection, calendar infrastructure, or native notification delivery for the MVP.

## 10. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Payment succeeds but calendar creation fails | Paid user lacks a usable appointment | Persist a confirmed booking first, retry calendar writes, alert the host, and define a manual refund path |
| OAuth access expires | Incorrect availability | Stop accepting bookings when freshness cannot be verified and request reconnection |
| Time-zone or DST error | Missed appointment | Store named zones and UTC instants; test transitions explicitly |
| Calendar support requests dominate operations | High solo-founder burden | Launch with Google only and provide visible connection diagnostics |
| Broader features dilute the wedge | Slow launch and unclear demand | Require retention evidence before promoting P1/P2 work |
| No-shows remain high despite prepayment | Weak customer outcome | Measure cancellations and validate deposit/cancellation-policy needs |

## 11. Milestones

| Milestone | Outcome | Exit criteria |
|---|---|---|
| M0 — Integration spike | Retire calendar, payment, and time-zone risks | OAuth, free/busy lookup, test Checkout webhook, slot hold, and DST tests work in a disposable prototype |
| M1 — Free-booking vertical slice | Validate scheduling loop | Host publishes availability; invitee books; calendar event is created without conflicts |
| M2 — Paid-booking MVP | Validate the product wedge | Stripe payment, confirmation, cancellation, retries, and host dashboard pass end-to-end tests |
| M3 — Pilot hardening | Launch to initial users | Funnel tracking, accessible mobile web flow, operational alerts, and support documentation are ready |
| M4 — Evidence-led expansion | Select the next feature | Pilot data justifies analytics, contact history, or another narrowly scoped improvement |

**Suggested first build slice:** one host, one Google Calendar, one event type, one public page, and one successful free booking. Add Stripe only after conflict prevention and calendar creation are reliable.

## 12. Launch and feedback

- **Beta audience:** 10 independent consultants or coaches who already sell paid sessions.
- **Feedback channel:** In-product feedback link plus founder interviews after the first and third completed bookings.
- **Pause trigger:** Any confirmed double booking or unresolved paid-without-event incident.
- **Pivot trigger:** Fewer than three of ten activated hosts receive repeat bookings after onboarding and availability issues are addressed.

## 13. Open questions

1. Which narrow profession should be the first market: coaches, consultants, tutors, or another segment?
2. Is full payment mandatory, or should the MVP support deposits?
3. What cancellation and refund policy must the product enforce?
4. Is Google Calendar sufficient for the first ten customers?
5. How will SoloSchedule charge hosts: subscription, booking fee, or another model?

The three decisions to confirm first are the initial profession, the reduced P0 scope, and the payment/refund policy. The best implementation slices are calendar availability, conflict-safe free booking, and then paid booking with failure recovery. Customer interviews or a landing-page smoke test should validate whether integrated payment is a compelling wedge before investing in team scheduling or native apps.
