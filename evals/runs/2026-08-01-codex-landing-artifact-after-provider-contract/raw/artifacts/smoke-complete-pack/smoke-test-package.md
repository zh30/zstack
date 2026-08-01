# ClientTab: 10-day landing smoke test

## Test card

| Item | Locked choice |
|---|---|
| Test dates | August 3–12, 2026 (10 calendar days) |
| ICP | Hands-on support agents at small US SaaS teams who repeatedly work across client-specific admin, ticket, CRM, and documentation tabs |
| Problem | Rebuilding each client's browser context wastes time and creates account-mix-up risk |
| Single promise | Restore a saved client-specific tab workspace in one click |
| Single CTA | “Join the early-access waitlist” |
| Stage | Unbuilt concept; no firm ship date |
| Price signal | Truthful planned pricing from $9/month; no charge in this test |
| Stack | Cloudflare Pages + Pages Function, Buttondown, Plausible |
| Paid cap | $150 maximum, one cold paid lane |

## 1. Smoke protocol

### Hypothesis

If ClientTab offers one-click context restore to hands-on support agents at small US SaaS teams, then at least one **cold** acquisition lane will clear its pre-registered visitor-to-provider-confirmed-waitlist threshold within 10 days and generate at least three qualified cold-lane replies describing a recurring client-workspace problem or credible willingness to pay from $9/month.

Warm outreach is a separate diagnostic lane. It may help refine language, but it can never rescue or be pooled with a cold result.

### Metric contract

| Metric | Definition and source of truth |
|---|---|
| Qualified unique visitor | A unique Plausible visitor arriving through an allow-listed link aimed at US SaaS support practitioners. Bot/referral spam and founder QA are excluded. Reported separately by `decision_lane`. |
| CTA click | Plausible `click_cta` event. Diagnostic only. |
| Attempt | Plausible `attempt_waitlist` after browser validation. Not a conversion. |
| Confirmed waitlist | Buttondown API acceptance returned to the Pages Function and present in the Buttondown subscriber record. Invalid, duplicate, rejected, filtered, or attempted submissions do not count. |
| Visitor → waitlist CVR | Provider-confirmed subscribers in one lane ÷ qualified unique visitors in that same lane. Never calculate this across warm and cold traffic. |
| Welcome engagement | Delivered/opened welcome email by Buttondown lane. Opens are diagnostic because privacy features make them noisy. |
| Qualified reply | A human reply that names a repeated client-context workflow, current workaround/frequency, or explicit price reaction. “Cool idea” is not qualified. |
| Credible price intent | A reply explicitly saying $9/month or more is reasonable, asking to buy, or asking for an invoice. No payment is collected in this smoke test. |
| Cost per confirmed waitlist | Cold-paid spend ÷ cold-paid provider-confirmed subscribers. |

### Pre-registered, source-specific thresholds

Rates below are directional test bars, not universal benchmarks. Each lane must meet its own minimum sample before a strong or weak verdict.

| Decision lane | Exact sources | Minimum sample | Strong signal | Weak / reshape signal |
|---|---|---:|---|---|
| `warm_outreach` | `warm_email/outreach`, `warm_dm/outreach` | 30 qualified visitors | ≥15% CVR and ≥5 confirmed subscribers, plus ≥2 qualified replies | <7% CVR or ≤2 confirmed subscribers after minimum sample |
| `cold_community` | `reddit/community`, `x/social`, `indiehackers/community`, `support_forum/community` | 75 qualified visitors | ≥6% CVR and ≥5 confirmed subscribers, plus ≥2 qualified replies | <2% CVR or ≤1 confirmed subscriber after minimum sample |
| `cold_paid` | `reddit_ads/cpc` | 75 qualified visitors and $100+ spend | ≥4% CVR and ≥3 confirmed subscribers, with cost per confirmed subscriber ≤$50 | <1.5% CVR or ≤1 confirmed subscriber after minimum sample and $100+ spend |
| `unattributed` | Missing, malformed, or non-allow-listed UTMs | No decision eligibility | Never used for a source verdict | Investigate and fix; report count separately |

The cold lanes remain separate from each other in the primary report as well. A secondary “all cold” total may be shown only as a descriptive count, never to apply a threshold or declare success.

### Timebox and sample rule

- Freeze the shipped headline, audience, and allow-list from August 3 through August 7. Only fix defects.
- On August 8, make at most one pre-planned hero change if both cold lanes have at least 35 visits and both are under 2% confirmed CVR. Mark all later rows `variant_b`; never merge variant A and B rates.
- Stop on August 12. If a lane misses minimum sample, label that lane **inconclusive / distribution not proven**, not weak product demand.
- Do not extend just to chase the target. A new traffic plan requires a new pre-registered test window.

## 2. Complete English page and share copy

The deployable implementation is in `landing/index.html`. Copy below is the locked content baseline.

### Metadata

- **Meta title:** ClientTab — Restore each client workspace in one click
- **Meta description:** A planned Chrome extension for hands-on support agents at small SaaS teams. Reopen each client's working tabs in one click. Planned pricing from $9/month.
- **Canonical URL:** `https://__REPLACE_WITH_DOMAIN__/`
- **OG title:** One-click client context restore for hands-on SaaS support
- **OG description / share blurb:** Stop rebuilding the same browser setup for every client. Join the early-access waitlist for ClientTab, a planned Chrome extension starting from $9/month.
- **OG type:** website
- **OG locale:** en_US
- **OG image alt concept:** “ClientTab concept preview showing four saved tabs for one client and a one-click restore control.”
- **Twitter card:** summary_large_image
- **Twitter title:** One-click client context restore for hands-on SaaS support
- **Twitter description:** A planned Chrome extension to restore client-specific tab workspaces in one click. Planned from $9/month.

### Headline variants

1. **Ship first:** Restore every client workspace in one click.
2. Stop rebuilding the same client tabs for every support case.
3. The client-tab workspace for hands-on SaaS support.

Only variant 1 ships initially. Variant 2 is the sole pre-planned fallback for the August 8 rule; variant 3 is held for a future test.

### Full page copy

**Nav**

- Product: ClientTab
- Button: Join the early-access waitlist

**Hero**

- Eyebrow: For hands-on support agents at small SaaS teams
- Headline: Restore every client workspace in one click.
- Body: Stop hunting through history and rebuilding the same browser setup. ClientTab is a planned Chrome extension that would reopen the right admin pages, tickets, docs, and dashboards for each client.
- Button: Join the early-access waitlist
- Price chip: Planned from $9/month
- Stage line: Concept-stage: not built yet, with no firm ship date.
- Concept preview labels: Acme Co. workspace; Support ticket · renewal issue; Admin · account settings; CRM · Acme Co.; Docs · SSO setup; Restore 4 tabs in one click.

**Problem**

- Heading: Client context disappears every time your tabs do.
- Rebuild from memory: You search history, Slack, the help desk, and bookmarks before the real support work even starts.
- Mix up client context: Similar-looking admin pages make it easy to open the wrong account or lose the thread mid-escalation.
- Repeat it tomorrow: Generic tab managers save windows, not the client-specific working sets your support queue demands.

**How it would work**

- Heading: A focused workflow, not another dashboard.
- Save the client set: Group the tabs you use for one client into a named workspace.
- Close with confidence: Clear browser clutter without relying on memory or a permanent tab pile.
- Restore in one click: Reopen that client's working context when the next ticket or escalation arrives.

**Built for**

- Support agents who directly work across client systems
- Small US SaaS teams with many recurring client contexts
- People who rebuild the same tab sets several times a week

**Not for**

- Teams looking for a help desk, CRM, or ticketing replacement
- Anyone who only needs a generic bookmark folder
- Organizations requiring a finished, audited product today

**Honest proof / founder note**

An honest founder note: ClientTab is a concept being tested before it is built. There are no customer claims, launch date, or finished extension yet. Early-access interest will decide whether a focused first version is worth building.

**Offer and form**

- Eyebrow: Early access
- Heading: Spend less time reconstructing. Spend more time resolving.
- Body: Join to hear whether the extension moves forward and to help shape the smallest useful version. Planned pricing starts from $9/month; joining is free and is not a purchase.
- Field label: Work email
- Button: Join the early-access waitlist
- Privacy microcopy: One short update and an optional research question. Unsubscribe anytime. Your email is stored in Buttondown and will not be sold.
- Provider-confirmed success: You're on the list — check your inbox.
- Unconfirmed error: We couldn't confirm your signup. Please try again later.
- Unwired state: The waitlist is not connected yet. Please check back shortly.

**FAQ**

1. **Is ClientTab available now?** No. This page tests whether the problem and proposed one-click restore are worth building. There is no firm ship date.
2. **What would it cost?** Planned pricing starts from $9/month. Final tiers and terms are not set, and joining the waitlist does not lock you into a purchase.
3. **What would the extension access?** The intended workflow requires browser-tab permissions to save and reopen chosen URLs. Exact permissions, storage, and security design are still unproven and would be documented before release.
4. **Will it replace our help desk or CRM?** No. It is intended to restore the browser context around those tools, not replace them.
5. **What happens after I join?** If Buttondown accepts your email, you will see a confirmed message and receive a short welcome email. You may reply with the client setup you rebuild most often.
6. **How is my email used?** Only for this product validation and early-access updates. It is stored in Buttondown, never sold, and you can unsubscribe at any time.

**Final block and footer**

- Heading: Your next client should be one click away.
- Button: Join the early-access waitlist
- Footer: © 2026 ClientTab · Concept-stage smoke test
- Privacy: email stored in Buttondown, never sold
- Contact: `__REPLACE_WITH_CONTACT_EMAIL__`

No testimonials, customer logos, user counts, product-availability claims, or firm ship date appear anywhere.

## 3. Implementation pack

### Architecture

```text
Browser → Cloudflare Pages index.html
        → Plausible pageview/custom events (after verified setup)
        → same-origin POST /api/waitlist
          → Pages Function validates + allow-lists attribution
          → Buttondown API
          → only accepted provider status returns {ok:true}
        → browser emits submit_waitlist and shows confirmed copy
```

The landing page is static; the only server code is `landing/functions/api/waitlist.js`. The server must remain the confirmation boundary. A query string, hash, cookie, or browser storage value must never trigger confirmed UI or `submit_waitlist`.

### Form and privacy

- Required field: work email.
- Hidden bot honeypot: `company_website`; non-empty values are filtered and never forwarded.
- Attribution values: `utm_source`, `utm_medium`, `utm_campaign`, `utm_content` read from the landing URL. The Pages Function maps only exact allow-listed triples to a lane.
- Buttondown is the email system of record. Use double opt-in if supported by the verified account/configuration; it improves list quality for a US B2B test. API acceptance is the waitlist conversion; email confirmation can be reported separately.
- Do not sell the list. Provide unsubscribe handling through the provider. Replace the contact placeholder before launch.
- Do not log email addresses, tokens, authorization headers, request bodies, provider bodies, or free text. Diagnostic responses contain only bounded categories, HTTP status, and a non-PII request ID.

### Event dictionary

| Event | Trigger | Properties | Decision use |
|---|---|---|---|
| Plausible automatic pageview | One loaded page | Referrer and allow-listed UTMs | Denominator for unique visitors by source/lane |
| `view_landing` | Page script starts | Raw UTM fields | QA/diagnostic only; do not add to the pageview denominator |
| `click_cta` | Any waitlist anchor clicked | UTM fields | CTA click-through diagnostic |
| `attempt_waitlist` | Valid browser form submission begins | UTM fields | Form-friction diagnostic; never a conversion |
| `submit_waitlist` | Same-origin API reports Buttondown accepted the subscriber | Server-returned lane only | Client-side mirror; Buttondown record remains conversion source of truth |
| `waitlist_error` | API/network/validation path fails | Bounded error category only | Integration health; never a conversion |

Create matching Plausible custom-event goals only after verifying the current event script and call contract. Exclude founder QA traffic using Plausible's documented exclusion method after that contract is checked.

### Buttondown contract gate

The function intentionally returns `503 integration_unverified` until `VERIFY_BUTTONDOWN_CONTRACT=VERIFIED_BY_OWNER`. This run could not access current official docs. Before removing the gate, use the current official Buttondown documentation to verify and record:

1. subscriber-create endpoint and HTTP method;
2. exact authorization header format;
3. accepted success status codes, including duplicate behavior;
4. exact email field name;
5. whether lane attribution uses tags, metadata, IDs, slugs, or another shape;
6. double-opt-in behavior and which state counts as API acceptance.

Then configure these Cloudflare secrets/variables:

| Variable | Required value |
|---|---|
| `VERIFY_BUTTONDOWN_CONTRACT` | Set to `VERIFIED_BY_OWNER` only after documented checks and real tests |
| `BUTTONDOWN_API_ENDPOINT` | Current official subscriber-create endpoint |
| `BUTTONDOWN_AUTH_HEADER_VALUE` | Entire verified Authorization header value; secret |
| `BUTTONDOWN_EMAIL_FIELD` | Verified payload field name for email |
| `BUTTONDOWN_BASE_PAYLOAD_JSON` | Verified base JSON object, e.g. only fields supported by current docs |
| `BUTTONDOWN_ATTRIBUTION_FRAGMENT_WARM_OUTREACH` | Verified JSON fragment applying the warm lane tag/metadata |
| `BUTTONDOWN_ATTRIBUTION_FRAGMENT_COLD_COMMUNITY` | Verified JSON fragment applying the cold-community lane tag/metadata |
| `BUTTONDOWN_ATTRIBUTION_FRAGMENT_COLD_PAID` | Verified JSON fragment applying the cold-paid lane tag/metadata |
| `BUTTONDOWN_ATTRIBUTION_FRAGMENT_UNATTRIBUTED` | Verified JSON fragment explicitly marking unattributed records |
| `BUTTONDOWN_ACCEPTED_STATUS_CODES` | Comma-separated statuses proven by official docs and a valid test |

Launch remains blocked until a provider-confirmed record visibly preserves the correct lane for one valid submission through every lane, while an invalid email and unknown UTM do not enter a decision lane. Record the official documentation URL and verification date in the experiment log at setup time as `VERIFY_BUTTONDOWN_OFFICIAL_DOC_URL` and `VERIFY_BUTTONDOWN_DOC_DATE`.

### Plausible and Cloudflare gates

This run also cannot verify the current Plausible embed/custom-event contract or Cloudflare Pages deployment conventions. Before launch:

- Replace `__VERIFY_PLAUSIBLE_SCRIPT_SRC__` with the current official Plausible event-enabled script URL and `__REPLACE_WITH_DOMAIN__` with the exact configured domain.
- Verify that pageviews, `click_cta`, `attempt_waitlist`, `submit_waitlist`, and `waitlist_error` appear without PII in Plausible.
- Confirm Cloudflare Pages serves `index.html`, routes `/api/waitlist` to the function, exposes secrets only server-side, and applies HTTPS.
- Record current official documentation URLs and the verification date for both providers in the experiment log. Until then these integrations are **unverified**, not operational.

### Preflight acceptance test (traffic blocker)

1. Replace domain, OG image, contact email, and Plausible placeholders.
2. Confirm the page has one CTA label everywhere and stage/price copy is visible on mobile.
3. Submit one invalid email: no provider record, no `submit_waitlist`.
4. Submit one honeypot: no provider record, no confirmed UI.
5. Submit one real controlled email for every allow-listed lane and one unknown UTM: Buttondown record shows the matching lane or `unattributed`; confirmed UI appears only on provider acceptance.
6. Submit the same controlled email twice. Confirm the Buttondown export contains one subscriber and the reporting query counts one conversion; if duplicate API semantics are ambiguous, keep launch blocked and add provider-verified duplicate handling.
7. Force a bad provider token: neutral error UI, `waitlist_error`, no email/secret/raw body in logs.
8. Confirm Plausible receives the event names and no email.
9. Export Buttondown and reconcile each controlled conversion to Plausible source/lane. Any mismatch blocks distribution.

## 4. UTM registry

Base URL: `https://__REPLACE_WITH_DOMAIN__/`

Only these exact source/medium/campaign triples enter a decision lane. `utm_content` distinguishes placements but cannot change the lane.

| Channel / placement | Decision lane | UTM link |
|---|---|---|
| Reddit organic | `cold_community` | `?utm_source=reddit&utm_medium=community&utm_campaign=cst_smoke_202608&utm_content=founder_post` |
| X founder account | `cold_community` | `?utm_source=x&utm_medium=social&utm_campaign=cst_smoke_202608&utm_content=problem_story` |
| Indie Hackers | `cold_community` | `?utm_source=indiehackers&utm_medium=community&utm_campaign=cst_smoke_202608&utm_content=milestone` |
| Approved support forum/Slack | `cold_community` | `?utm_source=support_forum&utm_medium=community&utm_campaign=cst_smoke_202608&utm_content=approved_post` |
| Reddit paid ad | `cold_paid` | `?utm_source=reddit_ads&utm_medium=cpc&utm_campaign=cst_smoke_202608&utm_content=one_click_context` |
| Personal email | `warm_outreach` | `?utm_source=warm_email&utm_medium=outreach&utm_campaign=cst_smoke_202608&utm_content=personal` |
| Personal DM | `warm_outreach` | `?utm_source=warm_dm&utm_medium=outreach&utm_campaign=cst_smoke_202608&utm_content=personal` |

Missing/unknown combinations map to `unattributed`, remain visible in reporting, and are excluded from all source thresholds. Never infer source from timing or allocate an undifferentiated subscriber total across lanes.

## 5. Ten-day traffic calendar

The $150 cap applies only to the `cold_paid` lane. Do not retarget warm contacts or upload a warm email list to the ad platform.

| Day | Lane | Action | Spend ceiling | Evidence checkpoint |
|---|---|---|---:|---|
| Aug 3 | QA only + `warm_outreach` | Complete preflight; send 10 personalized emails to known ICP-fit support practitioners using the warm email UTM. | $0 | Provider attribution reconciles; warm metrics start in their own rows. |
| Aug 4 | `cold_community` + `cold_paid` | Post one disclosed, value-first Reddit post where rules allow; launch one US Reddit ad audience/creative. | $30 cumulative | Check removals, bot quality, error events—not CVR verdict yet. |
| Aug 5 | `cold_community` + `warm_outreach` + `cold_paid` | Publish X problem story; send 10 additional personal DMs; let the same verified ad run up to another $30. Reply to every substantive comment. | $60 cumulative | Record objections verbatim by lane; do not edit hero. |
| Aug 6 | `cold_community` | Publish Indie Hackers milestone/critique post. No new warm outreach. | $60 cumulative | Review qualified-visitor mix and CTA-click friction. |
| Aug 7 | `cold_paid` | Add up to $30 if targeting and tracking are valid; pause immediately for broken attribution or obvious junk. | $90 cumulative | First 48–72h paid check; no final verdict below minimum sample. |
| Aug 8 | Analysis / controlled copy gate | Freeze distribution for two hours; if both cold lanes meet the pre-planned fallback condition, switch only headline to variant 2 and tag rows `variant_b`. | $90 cumulative | Never merge variant rates. Document decision before resuming. |
| Aug 9 | `cold_community` + `warm_outreach` + `cold_paid` | Post an honest “what we heard” X update; send the final 10 warm messages; add at most $15 to the unchanged ad if valid. | $105 cumulative | Compare lanes separately. Warm feedback can change language, not cold verdict. |
| Aug 10 | `cold_paid` | Add up to $30 only if CPC quality and provider attribution are sound. | $120 cumulative | Stop the ad if it already meets weak criteria at minimum sample. |
| Aug 11 | `cold_community` + `cold_paid` | Publish one approved niche support community post; allow a final $30 on the unchanged ad only if tracking remains valid. | $150 cumulative | Close remaining sample gaps without cross-post spam. |
| Aug 12 | All lanes closed | Stop ads/outreach at end of day; export Plausible and Buttondown; reconcile, tag invalid/unattributed, apply rules. | **$150 hard cap** | Write lane-by-lane verdict; schedule interviews only if rules call for them. |

### Source-specific drafts and etiquette

**Reddit organic — cold community**

Title: “Support folks: how often do you rebuild the same client-specific tab setup?”

Body: “I keep seeing hands-on SaaS support work start with the same scavenger hunt: ticket, client admin, CRM record, docs, then the right Slack thread. I’m testing a concept for a Chrome extension that would save those tabs as a client workspace and restore them in one click. It isn’t built, there’s no ship date, and planned pricing would start from $9/month. I’d value blunt feedback on whether this is a recurring problem or just tab-hoarding with a nicer name. If the concept fits your workflow, the early-access page is here: [UTM link]. I’m the maker.”

Do: read rules, use the correct feedback flair, answer objections, remove the link if moderators require it. Don’t: duplicate the same post across subreddits or imply the extension exists.

**X — cold community**

“A support ticket rarely lives in one tab. It’s the ticket + client admin + CRM + docs + the context you found yesterday. Then the browser closes and you rebuild it all. I’m testing an unbuilt Chrome extension concept to restore each client workspace in one click. Planned from $9/mo; no firm ship date. Join the early-access waitlist: [UTM link]”

Do: pin during the test and engage replies. Don’t: add a second CTA or claim customers.

**Indie Hackers — cold community**

Title: “Smoke-testing one-click client tab restore before writing the extension”

Angle: share the narrow ICP, unbuilt status, one-click promise, $9/month starting-price signal, and the exact question: “For support operators, is client-specific context restore frequent and painful enough to pay for?” Include the cold-community UTM link once. Ask for critique, not upvotes.

**Approved niche community — cold community**

Permission note to moderator: “I’m validating an unbuilt Chrome extension concept for SaaS support agents. May I share one short feedback post with a clearly disclosed waitlist link? No follow-up promotion.” Publish only after approval.

**Personal email/DM — warm outreach (reported separately)**

“Hi [Name] — because you work hands-on in SaaS support, I’d value two minutes of blunt feedback. I’m testing, not yet building, a Chrome extension concept that would restore client-specific tab workspaces in one click. Planned pricing starts from $9/month and there’s no ship date. Would you look at this page and tell me what feels wrong? [warm UTM link]”

Do: personalize to a known role and stop after one non-response. Don’t: paste warm replies or conversions into a cold result.

**Reddit ad — cold paid**

- Primary: “Still rebuilding the same ticket, admin, CRM, and docs tabs for every client?”
- Headline: “Restore each client workspace in one click”
- Description: “Planned Chrome extension for hands-on SaaS support. Not built yet. From $9/month.”
- Button/link destination: the page with the registered paid UTM; the landing-page button remains “Join the early-access waitlist.”
- Targeting intent: US users in communities/interests directly tied to SaaS customer support/help-desk operations; exclude broad productivity/tab audiences where possible.
- Do: use one audience and one creative for the first 48 hours. Don’t: retarget warm contacts, expand geography, or change audience and copy together.

## 6. Reporting and decision rules

Use `measurement-template.csv` daily. Keep one row per date and lane; additionally split on `variant_a`/`variant_b` if the fallback triggers. Reconcile final subscriber counts from Buttondown, not Plausible `submit_waitlist` alone.

### Final decision matrix

| Outcome | Required evidence | Decision |
|---|---|---|
| Proceed to thin MVP | At least one cold lane reaches its minimum sample **and** strong CVR/count bar, while cold-attributed respondents produce ≥3 qualified replies total, including ≥2 recurring-workflow accounts or ≥2 credible $9+ price-intent signals | Write a thin PRD for save/name/restore only; interview the strongest cold respondents before implementation. Warm results are shown separately and do not satisfy this rule. |
| Retest offer | A cold lane reaches minimum sample with 2–5.9% community CVR or 1.5–3.9% paid CVR, or CTA clicks are healthy but confirmed CVR is weak | Rewrite pain/hero using attributed objections; run a new test with the same lane. Do not add features. |
| Interview before build | A cold lane clears its CVR/count bar but yields fewer than 3 qualified cold replies and no credible price intent | Treat it as curiosity, not durable demand. Interview 5 cold-lane subscribers; require repeated past behavior and willingness to switch before a PRD. |
| Reshape ICP/problem | A cold lane reaches its minimum sample and weak threshold, with valid tracking and no major mismatch | Change the ICP or problem framing. Do not let strong warm conversion override it. |
| Distribution inconclusive | No cold lane reaches minimum sample, or attribution/provider reconciliation fails | No product verdict. Repair channel access or instrumentation and pre-register a new test. |
| Park | Both cold lanes independently reach their minimum samples and weak bars across the controlled variant(s), with ≤1 qualified cold reply total | Archive the concept and evidence. Do not build the extension to manufacture progress. |
| Paid-intent escalation | Any cold-attributed person asks to pay/invoice at $9+ | Interview that person within 48 hours and test a truthful paid commitment separately. One request is a lead, not proof of scale. |

### Non-negotiable analysis rules

- Never pool warm outreach with cold traffic in a rate, threshold, chart headline, or decision.
- Never infer a subscriber's lane from time of day or aggregate totals.
- Exclude `unattributed` from source decisions but disclose its count.
- Treat opens as diagnostics, not demand. Treat attempts and CTA clicks as funnel diagnostics, not conversions.
- Report all spend, including zero-conversion spend. Do not exceed $150.
- Freeze results at the timebox end; note late email replies separately.

## 7. Welcome email and contact-intent probe

**Subject:** Which client setup do you rebuild most often?

**Body:**

“Thanks for joining the ClientTab early-access waitlist. This is still an unbuilt concept with no firm ship date. The idea is simple: save the tabs tied to one client, then restore that workspace in one click. Planned pricing starts from $9/month.

Would you reply with two lines?

1. The last time you had to rebuild a client-specific browser setup, what did you open?
2. If that context came back reliably in one click, would $9/month feel reasonable, too high, or suspiciously low?

Your answer will help decide whether this should be built at all. You can unsubscribe below.”

Buttondown should send this only after the verified subscriber workflow accepts the address. Tag replies with the same decision lane as the provider record; do not overwrite missing attribution.

## 8. Explicit non-build scope

During these 10 days, do **not** build:

- the Chrome extension or a fake interactive product demo;
- authentication, sync, team sharing, roles, billing, CRM/help-desk integrations, AI tab grouping, or workspace search;
- a multi-page marketing site, blog, referral loop, brand system, testimonial/logo section, or waitlist counter;
- pricing tiers beyond the truthful “planned from $9/month” signal;
- a firm roadmap or ship date.

If the proceed rule passes, the first product scope is still only: save selected current tabs to a named client workspace, list saved workspaces, and restore one workspace in one click. Privacy/security design and Chrome permission review must happen before coding that MVP.

## 9. Evidence handoff

| Field | Value |
|---|---|
| Current decision | TBD after test |
| Evidence classes | assumption |
| Supported claims | TBD after test |
| Still unproven | Actual demand, cold-lane conversion, Buttondown/Plausible attribution, willingness to pay, extension feasibility, safe permissions/storage, repeat usage, retention, and product value are all unproven. |
| Contradictions / exclusions | No testimonials, logos, user counts, firm ship date, provider-verified results, or public research were supplied. Warm and cold traffic are explicitly separate; invalid attempts and unattributed records are excluded from source thresholds. |
| Source anchors | Pre-registered plan dated 2026-08-01; `artifacts/landing/index.html`; `artifacts/landing/functions/api/waitlist.js`; `artifacts/measurement-template.csv`. Result anchors are TBD after test and must include dated Plausible slices plus Buttondown provider-confirmed export. |
| Next validation | Owner: founder. By 2026-08-03, verify current provider contracts and pass the valid/invalid attribution preflight; then run August 3–12. Success/fail signals are the lane-specific bars in Section 1. |
