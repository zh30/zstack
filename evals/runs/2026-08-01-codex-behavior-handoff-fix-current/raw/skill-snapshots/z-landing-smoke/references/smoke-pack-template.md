# Smoke pack template — z-landing-smoke

---

# Landing smoke test: {product name}

## Contents

1. Hypothesis
2. Metrics and decision rules
3. Landing-page copy
4. Form and tracking
5. Implementation notes
6. Traffic plan
7. Explicit non-build scope
8. Evidence handoff

| Field | Value |
|-------|--------|
| **Date** | YYYY-MM-DD |
| **Timebox** | e.g. 10 days |
| **ICP** | |
| **CTA type** | waitlist / early access / pre-order |
| **Page language** | English (default) |
| **Stack** | |

## 1. Hypothesis

If we offer **{promise}** to **{ICP}** via **{CTA}**, then **{metric}** will be
at least **{threshold}** within **{timebox}** under **{traffic plan}**.

## 2. Metrics & decision rules

| Metric | Definition | Success | Kill / pivot |
|--------|------------|---------|--------------|
| Visitors | | | |
| Email CVR | emails / visitors | | |
| Opens | welcome open rate | | |
| Intent signals | replies / “I’d pay” | | |
| Revenue | pre-orders $ | | |

**Decision:** …

## 3. Landing page copy (English)

### Meta

- **Title:**  
- **Description:**  
- **OG line:**  

### Headline variants

1. (ship this)  
2.  
3.  

### Full page

#### Nav
…

#### Hero
…

#### Problem
…

#### Solution (3 steps)
1.  
2.  
3.  

#### For / not for
…

#### Offer / CTA block
…

#### FAQ
…

#### Final CTA + footer
…

## 4. Form & tracking

| Item | Spec |
|------|------|
| Fields | |
| Provider | |
| Success message | Verified success after provider callback/redirect, or neutral attempt acknowledgement when confirmation is unavailable |
| Events | `view_landing`, `click_cta`, `attempt_waitlist`; add a success event only when a verified provider callback/redirect exists |
| Successful-conversion source of truth | Provider confirmation / verified callback / controlled success redirect |
| Confirmed-conversion attribution | Provider metadata or distinct verified form/tag per source class |
| UTM scheme | |

`submit_waitlist` must mean a provider-confirmed success. If the chosen native
form cannot expose that state reliably, use the provider's subscriber record as
the conversion source of truth, do not emit a success event on submit attempt,
and do not show confirmed-success copy after a timeout or unverified submission.
If thresholds differ by source, verify that the confirmed subscriber record also
preserves the matching UTM or traffic class; aggregate page UTMs are not enough.

## 5. Implementation notes

- Host:  
- Domain:  
- Files to create:  
- Pre-order processor (if any):  

For create/build/implement/complete-package requests in a writable workspace,
actually create the minimal deployable page file. Do not substitute a file list
or offer to create the page later. Mark every external-service placeholder and
list the setup still requiring user-owned credentials.

## 6. Traffic plan

| Day / window | Channel | Action | UTM | Notes |
|--------------|---------|--------|-----|-------|
| | | | | |

### Channel posts (drafts)

#### X
…

#### Reddit
…

#### Other
…

## 7. What we will NOT build during the smoke

- …

## 8. Evidence handoff

| Outcome | Next step |
|---------|-----------|
| Strong | |
| Mixed | |
| Weak | |

In the final `Evidence classes` cell, delete non-applicable choices and keep only
canonical class names without qualifiers.

The seven first-column labels below are literal interface tokens. Copy them as
plain text with no Markdown styling, code ticks, links, punctuation, translation,
or synonyms. Valid: `| Current decision |`. Invalid:
`| **Current decision** |`.

| Field | Value |
|-------|-------|
| Current decision | `TBD after test` / proceed / retest / reshape / park |
| Evidence classes | primary behavior / observed experiment / secondary public / search signal / assumption |
| Supported claims | Only claims supported by attributed, provider-confirmed results |
| Still unproven | Payment, retention, or product value not tested by this CTA |
| Contradictions / exclusions | Weak sources, failed variants, invalid attempts, and attribution gaps |
| Source anchors | Dated metric slice, provider export, analytics view, and upstream paths |
| Next validation | One action + owner + pre-registered success/fail signal |

Before the experiment has run, keep result-dependent rows `TBD after test`.
Never copy the hypothesis or aggregate traffic into the supported-claims row.
