# Metrics guide — z-landing-smoke

## Funnel

```text
Impression / click from channel
  → Landing view
    → CTA click
      → Email / pre-order submit
        → Welcome open / reply / pay
```

## What “good” roughly looks like (directional only)

These are **not laws**. Cold Reddit ≠ warm DM.

| Context | Visitor → email | Notes |
|---------|-----------------|-------|
| Warm / intent traffic | often higher (10%+ possible) | DM, niche community that asked for tool |
| Mixed social | often mid-single to low teens % | depends on ICP fit |
| Cold broad ads | can be 1–5% | watch cost per email |
| Pre-order on cold traffic | usually rare | any prepaid is strong signal |

**Better than rate alone:**

- 20 emails with thoughtful “I’d pay for X” replies  
  beats  
- 200 silent signups from giveaway hunters  

## Sample size humility

- &lt; 50 qualified visits → treat rates as **unstable**.  
- Prefer hitting a **minimum visit + conversion count** before kill decisions.  
- If traffic is impossible to get, the distribution thesis failed — different problem than product thesis.

## Email engagement

- Treat opens as a **diagnostic**, not a demand verdict; privacy features and
  email clients make them noisy.
- Compare against the founder's own provider and traffic-source baseline rather
  than a universal percentage.
- Zero apparent engagement may mean deliverability or weak subject/copy; check
  operations before killing the idea.
- Replies, qualified answers, bookings, and payments are stronger than opens.

## Conversion integrity

- Define one source of truth for a successful email conversion before launch.
- Increment the conversion only after the provider confirms acceptance. Invalid,
  rejected, duplicate, or merely attempted submissions do not count.
- A native cross-origin form often cannot prove success in its local submit
  handler. In that case, use the provider's confirmed subscriber record for the
  conversion count; optionally name the client-side signal `attempt_waitlist`,
  but never report it as `submit_waitlist` or as visitor-to-email conversion.
- The same boundary applies to visible UX. Do not replace the form with “You’re
  on the list” after a timeout or submit attempt. Show confirmed-success copy
  only after a verified callback or controlled provider success redirect;
  otherwise acknowledge only that the submission was sent and tell the user to
  check their inbox.
- If custom validation is used, prevent invalid submissions explicitly. Test one
  valid and one invalid submission before buying traffic.

## Attribution integrity

Source-specific decisions require the numerator and denominator to use the same
traffic class. Pageviews grouped by UTM plus one undifferentiated provider
subscriber total cannot produce source-specific conversion rates.

- Preserve UTMs or a derived traffic class in provider-supported subscriber
  metadata, or use distinct provider-native forms/tags for each source class.
- Verify with a real valid submission that the source value appears on the
  provider-confirmed subscriber record.
- Never infer subscriber source from aggregate timing or allocate a total across
  channels. If attribution is unavailable, report only the defensible aggregate
  and fix capture before applying source-specific thresholds.

## Paid intent hierarchy (strongest last)

1. Page view  
2. CTA click  
3. Email submit  
4. Qualifying form answer  
5. Reply with use case  
6. Calendar book  
7. Pre-order / deposit  

Climb this ladder before writing a large app.

## Kill criteria examples (adapt)

- After **200+** ICP-ish visits and **&lt; 1–2%** email CVR across 2 copy variants → reshape offer.  
- Strong CVR but **zero** replies after follow-up → interview before building.  
- **Any** organic prepay or credible “invoice me” request → prioritize learning
  from that buyer and testing a paid slice; one event is a lead, not proof of scale.
