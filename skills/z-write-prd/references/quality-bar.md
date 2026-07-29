# Quality bar — z-write-prd

Run this checklist before delivering the PRD.

## Must pass

- [ ] **One-liner** is specific (who + problem + approach), not a slogan only  
- [ ] **Problem** is in user language, not feature language  
- [ ] **Primary persona** is narrow enough to design against  
- [ ] **Non-goals** has ≥ 3 concrete items for v1  
- [ ] **Success metrics** are measurable by a solo founder  
- [ ] Every **P0** requirement has **acceptance criteria**  
- [ ] **MVP scope** could plausibly be built by 1 person in a bounded time  
- [ ] **Assumptions** are labeled; no fake research quotes  
- [ ] **Open questions** are listed, not hidden inside prose  
- [ ] IDs are stable (`FR-001`…) for later tickets/agents  

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

## Depth dial

| User ask | Depth |
|----------|--------|
| “Quick PRD” / rough idea only | Lighter journeys; fewer FRs; more assumptions |
| “Professional PRD for build” | Full template; strong AC; milestones |
| “Enterprise format” | Full template + optional RACI/compliance appendix — still keep MVP sharp |

## Definition of done

A stranger (or coding agent) reading only this PRD can answer:

1. Who is it for?  
2. What problem is solved?  
3. What ships in MVP vs not?  
4. How do we know it worked?  
5. What should be built first?
