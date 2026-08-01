# Quality bar — z-landing-smoke

## Must pass

- [ ] Clear **ICP** and **single promise**  
- [ ] **One primary CTA** (waitlist / early access / pre-order)  
- [ ] Hypothesis + **numeric success and kill criteria** + timebox  
- [ ] Full **English landing copy** (unless user required another language)  
- [ ] Form/tracking/UTM specified; conversion counts only provider-confirmed
      success, never invalid, failed, or merely attempted submissions
- [ ] Visible form state is equally truthful: confirmed-success copy appears
      only after a verified callback/redirect, never after an attempt or timeout
- [ ] Source-specific CVR is backed by confirmed-subscriber attribution, not
      page-level UTMs plus an undifferentiated subscriber total
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
| “You’re on the list” after an unverified cross-origin submit | Show a neutral submission acknowledgement or use a verified success callback/redirect |
| “I can create the page next” after a complete-package request | Create the minimal deployable file now; use labeled placeholders for missing external configuration |
| `**Current decision**` or another decorated handoff label | Use the exact plain-text label in the first column |
| Three-column Evidence handoff | Keep exactly `Field | Value`; put classes only in the `Evidence classes` value cell |

## Definition of done

Founder can:

1. Publish a page today or tomorrow  
2. Know exactly where to post for 7–14 days  
3. Know when to build, rewrite, or stop  
