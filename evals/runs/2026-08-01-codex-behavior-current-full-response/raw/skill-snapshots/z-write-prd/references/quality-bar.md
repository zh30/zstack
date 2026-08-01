# Quality bar — z-write-prd

Run this checklist before delivering the PRD.

## Must pass

- [ ] **One-liner** is specific (who + problem + approach), not a slogan only  
- [ ] **Problem** is in user language, not feature language  
- [ ] **Primary persona** is narrow enough to design against  
- [ ] **Non-goals** has ≥ 3 concrete items for v1  
- [ ] **Success metrics** are measurable by a solo founder  
- [ ] Every **P0** requirement—functional or non-functional—has concrete
      **acceptance criteria or a validation method**
- [ ] **MVP scope** could plausibly be built by 1 person in a bounded time  
- [ ] **Assumptions** are labeled; no fake research quotes  
- [ ] **Open questions** are listed, not hidden inside prose  
- [ ] IDs are stable (`FR-001`…) for later tickets/agents  
- [ ] Evidence handoff is one explicit seven-row table whose first-column field
      labels are the exact raw plain-text tokens from the template; none are
      formatted, translated, renamed, or replaced by prose
- [ ] Evidence handoff has exactly two columns headed `Field | Value`; no
      evidence-class, status, or detail column is added
- [ ] `Evidence classes` uses only primary behavior, observed experiment,
      secondary public, search signal, and assumption, while preserving
      supported/unproven claims, contradictions, anchors, and next validation;
      planned research, pilots, or payment tests do not add a current class
- [ ] `Evidence classes` is never empty; evidence-free inputs use `assumption`
- [ ] Quick PRD is roughly 1,000–2,500 words; default full core PRD is at most
      5,000 whitespace-delimited words (target ≤4,700 for safety) unless the
      user explicitly requested exhaustive depth
- [ ] Scope, evidence, metrics, and decisions have one canonical home instead of
      being repeated across prose, ledgers, requirements, and postscript

## Indie-specific

- [ ] Support burden called out if the product invites high-touch ops  
- [ ] No dependency on “hire a team” to hit MVP  
- [ ] Differentiation vs status quo is explicit (including “do nothing”)  
- [ ] First build slice is obvious from milestones  

## Anti-patterns (rewrite if present)

| Anti-pattern | Fix |
|--------------|-----|
| “Make it AI-powered / seamless / delightful” without behavior | Replace with user-visible behavior + AC |
| Entire roadmap stuffed into P0 | Split P0/P1/P2; protect MVP |
| Five personas for v1 | One primary; demote rest |
| Metrics only vanity (page views) | Add activation / retention / revenue proxies |
| Tech stack essay as PRD | Move to eng design; keep product constraints only |
| Empty Non-goals | Force cut list |
| Requirements without AC | Add Given/When/Then or checklist |
| Custom or prose-only evidence handoff | Restore the exact seven-row table and canonical evidence classes |
| Long document created by repetition | Keep one canonical statement; move only genuinely deep detail to an appendix |

## Depth dial

| User ask | Depth |
|----------|--------|
| “Quick PRD” / rough idea only | 1,000–2,500 words; lighter journeys; fewer FRs; more assumptions |
| “Professional PRD for build” | Target ≤4,700 and hard cap 5,000 whitespace-delimited core words; full template; strong AC; milestones |
| “Enterprise format” | Keep the core sharp; put explicitly requested governance/compliance depth in appendices |

## Definition of done

A stranger (or coding agent) reading only this PRD can answer:

1. Who is it for?  
2. What problem is solved?  
3. What ships in MVP vs not?  
4. How do we know it worked?  
5. What should be built first?
