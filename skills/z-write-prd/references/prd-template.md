# PRD template — z-write-prd

Fill every section that applies. Use `TBD` + `Assumption:` rather than deleting
a section silently. Remove truly N/A sections only with a one-line note.

Artifact budget: roughly 1,000–2,500 words for a quick PRD. For a default full
core PRD, target at most 4,700 whitespace-delimited words and never exceed
5,000. Preserve P0 acceptance criteria and Evidence handoff; compress repetition
and implementation-level detail first.

Suggested filename: `docs/prd/<product-slug>.md`

---

# PRD: {Product name}

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
11. Evidence handoff
12. Appendix

| Field | Value |
|-------|--------|
| **Status** | Draft / Review / Approved |
| **Owner** | |
| **Last updated** | YYYY-MM-DD |
| **Version** | 0.1 |
| **Primary persona** | |
| **Platform** | |
| **Related docs** | e.g. market-validate report path/URL |

## Revision history

| Version | Date | Summary |
|---------|------|---------|
| 0.1 | | Initial PRD from provided materials |

---

## 1. Overview

### 1.1 One-liner

One sentence: who + problem + approach.

### 1.2 Problem statement

- **Current situation:**  
- **Pain:**  
- **Why now:**  
- **Cost of status quo:** (time / money / risk — only if known)

### 1.3 Goals

**Product goals (user outcomes)**

1. …  
2. …

**Business goals (indie)**

1. … (e.g. first 10 paying users, validate willingness to pay)

### 1.4 Non-goals (v1)

Explicit list of what we will **not** build / serve yet:

- …  
- …

### 1.5 Success metrics

| Metric | Definition | Target / signal | Timeframe |
|--------|------------|-----------------|-----------|
| | | | |

Prefer leading indicators an indie can measure without a data team.

---

## 2. Users & context

### 2.1 Primary persona

| Attribute | Detail |
|-----------|--------|
| Name / label | |
| Who they are | |
| Context / environment | |
| Top jobs-to-be-done | |
| Current tools / workarounds | |
| Triggers to seek a solution | |
| Anti-persona (not for) | |

### 2.2 Secondary users (only if needed)

…

### 2.3 Use contexts

When / where / constraints (mobile on the go, desktop deep work, offline, etc.).

---

## 3. Solution

### 3.1 Value proposition

For **{persona}** who **{problem}**, **{product}** is a **{category}** that
**{key benefit}**. Unlike **{alternative}**, we **{differentiation}**.

### 3.2 Product principles (3–5)

Rules that settle future debates, e.g. “manual override always available”,
“one happy path before power features”.

### 3.3 Scope summary

| In scope (MVP / P0) | Out of scope (v1) |
|---------------------|-------------------|
| | |

---

## 4. User journeys (P0)

### Journey A — {name}

1. …  
2. …  
3. …  

**Success state:** …  
**Failure / recovery:** …

### Journey B — {name}

…

---

## 5. Requirements

### 5.1 Functional requirements

| ID | Requirement | Priority | Acceptance criteria |
|----|-------------|----------|---------------------|
| FR-001 | | P0 | |
| FR-002 | | P0 | |
| FR-003 | | P1 | |

### 5.2 Non-functional requirements

| ID | Requirement | Priority | Acceptance criteria / validation method |
|----|-------------|----------|-----------------------------------------|
| NFR-001 | | P0/P1 | |

Every P0 NFR must be independently verifiable. Use a measurable threshold, an
observable negative check (for example, “no upload endpoint exists”), or a
short test procedure rather than a Notes-only row.

### 5.3 Tracking / analytics events (optional)

| Event | When | Properties |
|-------|------|------------|
| | | |

---

## 6. UX & content notes

### 6.1 Screens / pages (IA)

- …  

### 6.2 Critical empty / error states

- …  

### 6.3 Key copy (only if product-critical)

- Onboarding:  
- Primary CTA:  
- Empty state:  

---

## 7. Data & integrations

### 7.1 Core concepts / entities

| Entity | Purpose | Key fields (conceptual) |
|--------|---------|-------------------------|
| | | |

### 7.2 Integrations

| System | Purpose | MVP? | Notes |
|--------|---------|------|-------|
| | | Y/N | |

### 7.3 Permissions & roles

Default: single-user. Multi-seat only if in scope.

---

## 8. Edge cases & risks

| Item | Impact | Mitigation |
|------|--------|------------|
| | | |

**Open product questions**

1. …  

---

## 9. Milestones (indie delivery)

| Milestone | Outcome | Exit criteria |
|-----------|---------|---------------|
| M0 Spike | | |
| M1 Vertical slice | | |
| M2 MVP pilot | | |

**Suggested first build slice:** …

---

## 10. Launch & feedback

- **Beta audience:**  
- **Feedback channel:**  
- **Kill / pivot triggers:**  

## 11. Evidence handoff

| Field | Value |
|-------|-------|
| Current decision | Build / validate first / reshape / hold, with approved P0 boundary |
| Evidence classes | primary behavior / observed experiment / secondary public / search signal / assumption |
| Supported claims | Product and scope decisions directly supported by sources |
| Still unproven | Assumed requirements, payment, retention, feasibility, or edge cases |
| Contradictions / exclusions | Rejected ideas, non-goals, and conflicting source evidence |
| Source anchors | Interview ids, report/metric paths, links, and requirement ids |
| Next validation | One action + owner + acceptance or kill signal |

Requirements may be necessary for a build without being market-validated. Keep
that distinction explicit for implementation and SEO consumers.

---

## 12. Appendix

### 12.1 Source materials used

- …

### 12.2 Assumptions log

| ID | Assumption | Impact if wrong |
|----|------------|-----------------|
| A-001 | | |

### 12.3 Glossary

| Term | Definition |
|------|------------|
| | |

### 12.4 Rejected ideas (optional)

What we considered and cut — prevents re-litigating.
