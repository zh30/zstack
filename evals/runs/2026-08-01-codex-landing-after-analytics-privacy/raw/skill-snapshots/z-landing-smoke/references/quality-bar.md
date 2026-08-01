# Quality bar — z-landing-smoke

## Must pass

- [ ] Clear **ICP** and **single promise**  
- [ ] **One primary CTA** (waitlist / early access / pre-order)  
- [ ] Hypothesis + **numeric success and kill criteria** + timebox  
- [ ] Full **English landing copy** (unless user required another language)  
- [ ] Form/tracking/UTM specified; conversion counts only provider-confirmed
      success, never invalid, failed, or merely attempted submissions
- [ ] Visible form state is equally truthful: confirmed-success copy appears
      only after a provider-signed/server-validated callback or redirect, never
      from an attempt, timeout, or client-controlled URL/storage flag
- [ ] Source-specific CVR is backed by confirmed-subscriber attribution, not
      page-level UTMs plus an undifferentiated subscriber total
- [ ] Only allow-listed source/campaign combinations enter warm or cold lanes;
      missing/unknown attribution is retained as `unattributed` and excluded
- [ ] Form/provider logs exclude secrets, email, free text, authorization
      headers, and raw response bodies; diagnostics use safe categories/status
- [ ] Analytics loads only after attribution is allow-listed and receives
      bounded canonical lane/placement/variant values; raw query strings, full
      URLs, arbitrary UTMs/referrers, email, and form text are never emitted
- [ ] Named-provider endpoint/auth/status/payload semantics are sourced to
      current official docs with a verification date; uncertain mappings use a
      visible `VERIFY_*` placeholder and block launch rather than guessing
- [ ] For a create/build/implement/complete-package request in a writable
      workspace, the minimal deployable page is materialized, not deferred
- [ ] **Traffic plan** with ≥ 3 concrete channel actions  
- [ ] Explicit **what not to build** during smoke  
- [ ] Honest stage disclosure (no fake social proof)  
- [ ] Decision matrix for strong / mixed / weak outcomes  
- [ ] Evidence handoff is one seven-row table with every exact template label
- [ ] Evidence handoff has exactly two columns headed `Field | Value`; no
      evidence-class, metric, status, or detail column is added
- [ ] Every handoff label is plain first-column text with no bold, italics,
      code, link, punctuation, translation, or synonym
- [ ] `Evidence classes` contains only applicable canonical class names; the
      other rows distinguish confirmed results from hypotheses and use `TBD
      after test` before result-dependent evidence exists; planned interviews,
      traffic, or payment tests do not add a current class
- [ ] `Evidence classes` is never empty; pre-test plans use `assumption`

## Anti-patterns

| Bad | Fix |
|-----|-----|
| Landing only, no traffic plan | Add Phase 5 |
| “Launch on PH” as entire strategy | Multi-channel + DM |
| Full app architecture in smoke pack | Delete; page + form only |
| Five CTAs | One CTA |
| Fake logos / counters | Remove |
| No kill criteria | Force numbers |
| UTM pageviews + one untagged subscriber total | Preserve source on each confirmed subscriber or do not claim source CVR |
| Unknown UTM silently defaults into a decision lane | Mark it `unattributed`, retain it, and exclude it from lane thresholds |
| Raw provider body or submitted email in logs | Log only safe category/status and a non-PII request id |
| Raw query/UTM/referrer values copied into analytics props | Allow-list first; emit only bounded lane/placement/variant enums and discard unknown raw values |
| Guessed provider tag/metadata name, ID, or payload shape | Verify current official docs or use a launch-blocking `VERIFY_*` placeholder |
| “You’re on the list” after an unverified cross-origin submit | Show a neutral submission acknowledgement or use a verified success callback/redirect |
| “I can create the page next” after a complete-package request | Create the minimal deployable file now; use labeled placeholders for missing external configuration |
| `**Current decision**` or another decorated handoff label | Use the exact plain-text label in the first column |
| Three-column Evidence handoff | Keep exactly `Field | Value`; put classes only in the `Evidence classes` value cell |

## Definition of done

Founder can:

1. Publish a page today or tomorrow  
2. Know exactly where to post for 7–14 days  
3. Know when to build, rewrite, or stop  
