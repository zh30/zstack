# 10-day landing smoke test: ContextDock

Status: pre-test plan, prepared 2026-08-02. All result-dependent claims are TBD after test.

## 1. Experiment brief

| Field | Choice |
|---|---|
| ICP | Hands-on support agents and support leads at US SaaS teams of roughly 5–50 employees who repeatedly switch among named client accounts in Chrome |
| Problem | Rebuilding a client's working context from tabs, bookmarks, history, and memory slows each handoff and return visit |
| Promise | Restore a saved client-specific tab workspace in one click |
| Stage | Unbuilt concept; this test validates demand before product development |
| CTA | **Join the early-access waitlist** (the only CTA) |
| Price signal | Planned plans from $9/month; pricing may change before launch |
| Timebox | 10 consecutive days, starting only after the launch checklist passes |
| Stack | Cloudflare Pages + Pages Function, Buttondown, Plausible |
| Budget | Maximum $150 paid-media spend |

### Hypothesis

If we offer one-click restoration of client-specific Chrome tab workspaces to hands-on support agents at small US SaaS teams, qualified visitors will join an early-access waitlist at the source-specific rates below, and some subscribers will reply with a concrete recurring workflow or willingness to try a plan starting at $9/month.

### Funnel and source of truth

`qualified unique landing visitor → CTA click → valid form attempt → Buttondown-confirmed subscriber → welcome open/reply`

- Primary metric: provider-confirmed subscribers / qualified unique visitors, calculated separately in each decision lane.
- A qualified visitor is a Plausible unique visitor from the US in an allow-listed lane, excluding obvious bots, internal QA, and repeat QA devices.
- A conversion exists only in Buttondown's confirmed subscriber record after a successful provider response. `attempt_waitlist` is not a conversion.
- Double opt-in is recommended for consent clarity, deliverability, and list quality. Report both provider-accepted subscriptions and, if Buttondown exposes it, double-opt-in completions; use provider-accepted subscriptions for the registered page CVR and never blur the two.
- Secondary metrics: CTA click-through, valid attempt rate, double-opt-in completion, welcome open (diagnostic only), reply count, concrete recurring-use-case replies, explicit “I would pay/try at $9” replies, and paid-media cost per provider-confirmed subscriber.
- No payment is collected, so willingness to pay, retention, actual restore quality, and product usage remain unproven.

### Pre-registered source lanes and thresholds

Never pool warm outreach with cold traffic. Do not calculate a combined headline CVR across these lanes.

| Decision lane | Exact registered traffic | Minimum before lane verdict | Continue signal | Reshape / stop signal |
|---|---|---:|---:|---:|
| `cold_paid` | LinkedIn ad / paid social / `restore_tabs_v1` / `support_agent_static_a` | 80 qualified visitors | ≥4 confirmed subscribers (≥5%) and cost/subscriber ≤$30 | After ≥80: ≤1 confirmed (≤1.25%), or $150 cap reached with ≤2 |
| `cold_reddit` | Reddit / community / `restore_tabs_v1` / `r_customersuccess_problem` | 50 qualified visitors | ≥4 confirmed (≥8%) | After ≥50: 0–1 confirmed (≤2%) |
| `cold_community` | Support Driven / community / campaign / `support_driven_feedback` | 40 qualified visitors | ≥4 confirmed (≥10%) | After ≥40: 0–1 confirmed (≤2.5%) |
| `cold_social` | X / organic social / campaign / `founder_problem_story` | 40 qualified visitors | ≥3 confirmed (≥7.5%) | After ≥40: 0 confirmed |
| `warm_outreach` | Founder email or DM / warm outreach / campaign / `personal_note` | 20 qualified visitors | ≥4 confirmed (≥20%) plus ≥2 concrete replies | After ≥20: ≤1 confirmed or 0 concrete replies |

These are directional, pre-registered learning bars—not universal benchmarks. Rates below 50 visits are unstable. `unattributed` visitors and subscribers are reported separately and excluded from lane CVR. A lane below its minimum is inconclusive, not failed.

### Experiment-level success and kill rules

- **Proceed to a thin MVP:** at least two cold lanes each meet their minimum sample and continue signal, at least 12 total provider-confirmed cold subscribers, and at least 5 subscribers reply with a concrete repeated client-context workflow; at least 3 of those explicitly accept trying a plan from $9/month.
- **Retest the offer:** at least one cold lane clears its CVR bar but fewer than 5 concrete-use-case replies arrive. Interview/reply to subscribers and test one revised hero; do not build yet.
- **Fix distribution, not product:** fewer than 120 total qualified cold visits by day 10. No product verdict is allowed.
- **Reshape the ICP or promise:** at least 170 qualified cold visits across at least two cold lanes, no lane meets its continue signal, and total provider-confirmed cold signups are below 2%.
- **Park:** after one controlled hero retest adds another ≥100 qualified cold visits and remains below 2% with fewer than 3 concrete replies. This second test is outside the 10-day package.
- **Paid-channel early stop:** pause the ad after $60 or 40 qualified visitors, whichever is later, if it has zero confirmed subscribers. Never exceed $150 total. Do not reallocate to a new audience mid-test without recording a new lane.

## 2. Final landing-page copy

### Meta and social

- Meta title: **Restore Every Client Workspace in One Click | ContextDock**
- Meta description: **For hands-on support agents at small SaaS teams: save each client’s Chrome tabs and restore the full workspace in one click. In validation; planned from $9/month.**
- OG title: **One click back into the right client context**
- OG description: **ContextDock is a planned Chrome extension for hands-on SaaS support teams. Save client-specific tab workspaces and restore them in one click. Join the early-access waitlist.**
- OG image text: **One click. The right client tabs. Back to helping.**
- OG image spec: 1200×630, dark navy background, pale browser-tab cards, no product screenshot, logo, customer marks, or implied live UI. The HTML intentionally omits `og:image` until this truthful asset is hosted.

### Headline variants

1. Ship first: **Restore every client workspace in one click.**
2. Later controlled test: **Stop rebuilding the same client tabs.**
3. Later controlled test: **The client workspace switcher for hands-on SaaS support.**

Only variant 1 runs in this 10-day test. Do not rotate headlines while traffic sources differ.

### Page copy, section by section

**Nav:** ContextDock · Join the early-access waitlist

**Hero eyebrow:** Planned Chrome extension for hands-on support teams

**Hero headline:** Restore every client workspace in one click.

**Hero body:** Save the tabs you use for each client, then reopen the whole working context when the next ticket, handoff, or follow-up arrives—without hunting through history.

**Price/stage line:** In validation, not built yet. Planned plans from $9/month; pricing may change before launch. No firm ship date.

**Hero CTA:** Join the early-access waitlist

**Problem heading:** Client switching should not mean context rebuilding.

- You search history for the admin page, ticket, docs, logs, and account record you had open yesterday.
- A handoff starts with “Which tabs do I need?” instead of the customer’s issue.
- Generic bookmark folders go stale and still make you open every link by hand.

**Solution heading:** A small workflow for a repetitive support job.

1. **Save a client workspace.** Group the tabs you already use under that client.
2. **Keep contexts separate.** Return to the right set instead of mixing accounts in one crowded window.
3. **Restore in one click.** Reopen the saved workspace when that client needs you again.

**For heading:** Built for a narrow kind of support work.

**For:** Hands-on support agents, customer success engineers, and support leads at small SaaS teams who revisit multiple client accounts in Chrome.

**Not for:** Personal read-later lists, general research sessions, or teams looking for a full help desk, CRM, or password manager.

**Honest proof heading:** Help decide whether this should exist.

**Founder note:** This is a demand test, not a finished extension. There are no customer testimonials or usage claims yet. Early-access members will get short progress updates and may be invited to describe their current tab-switching workflow.

**Offer heading:** Early access, if the signal is real.

**Offer body:** Join to hear whether ContextDock moves forward and to be considered for the first feedback group. Planned plans start from $9/month, but joining is free and does not lock in a price or purchase.

**Offer CTA:** Join the early-access waitlist

**FAQ: Is ContextDock available now?**  
No. It is an unbuilt concept being tested before development. Joining the waitlist does not promise access or a ship date.

**FAQ: What would it do?**  
The planned core job is simple: save the Chrome tabs used for a client and restore that workspace in one click. The smoke test does not promise tab contents, logins, or unsaved work will be restored.

**FAQ: What will it cost?**  
Plans are currently expected to start from $9/month. Pricing may change before launch; joining the waitlist is free and creates no purchase obligation.

**FAQ: What about client data and privacy?**  
Privacy and workspace-storage design are not finalized because the extension is not built. We will not claim that tab data stays local or is encrypted until that architecture exists and is verified. The waitlist collects only your email and the bounded selections shown in the form.

**FAQ: What happens after I join?**  
Buttondown will handle confirmation. If the provider accepts your submission, check your inbox to confirm and receive occasional product updates. You can unsubscribe at any time.

**FAQ: Who is this not for?**  
It is not a help desk, CRM, password manager, session-recovery guarantee, or general-purpose bookmark organizer.

**Final heading:** Spend less of the next client handoff rebuilding tabs.

**Final body:** If one-click client context restore would change your support workflow, add your email. We will use the signal to decide whether to build.

**Final CTA:** Join the early-access waitlist

**Footer:** ContextDock is a concept in validation. Contact: `VERIFY_CONTACT_EMAIL`. Email is stored in Buttondown for this waitlist, used only for ContextDock research and updates, never sold, and removable by unsubscribe or a deletion request.

**Neutral local submission state:** Submission sent—check your inbox if Buttondown accepts it. This page cannot confirm that you are on the list.

## 3. Implementation and measurement

### Minimal architecture

- `index.html`: mobile-first static page, copy, form, attribution allow-list, query cleanup, and guarded Plausible loader.
- `functions/api/waitlist.js`: Cloudflare Pages Function. It enforces exact JSON media type, a 2 KiB streamed-body cap, plain-object JSON, bounded fields, a server-side attribution allow-list, and a 5-second provider timeout.
- The function is intentionally launch-blocked while any `VERIFY_BUTTONDOWN_*` value is unresolved. It does not guess Buttondown endpoint, authentication, success status, payload, or metadata/tag semantics.
- Plausible is also network-off until its official script URL, event API, site domain, and privacy behavior are verified and the `VERIFY_PLAUSIBLE_*` constants are replaced.
- No secrets belong in HTML. Store the Buttondown credential as a Cloudflare Pages encrypted environment variable after the official contract is verified.

### Form contract

| Item | Specification |
|---|---|
| Required | Email; browser validation plus server normalization and maximum length |
| Optional qualifiers | Role (support agent, support lead, customer success/solutions, other); client switching frequency (1–2/day, 3–5/day, 6+/day) |
| Consent | Unchecked required checkbox: receive waitlist and research updates; unsubscribe anytime |
| Hidden attribution | Exact `utm_source`, `utm_medium`, `utm_campaign`, `utm_content` values retained only for server allow-listing; canonical `variant=hero_a` |
| Provider | Buttondown, contract unresolved and launch-blocked pending official-doc verification |
| Visible success | Only neutral attempt acknowledgement locally; Buttondown owns confirmed/double-opt-in UX unless a signed or server-validated callback is later implemented |
| Conversion source | Provider-confirmed Buttondown subscriber export/record, not browser response or Plausible event |
| Unknown source | `unattributed`; excluded from every source-specific CVR |

Tradeoff: the two fixed-choice qualifiers add friction but distinguish relevant operators from curiosity signups without collecting risky free text.

### Event dictionary

| Event | Trigger | Properties (allow-listed only) | Authority |
|---|---|---|---|
| `view_landing` | One sanitized page load | `decision_lane`, `placement`, `variant` | Plausible denominator diagnostic |
| `click_cta` | CTA link/button activation | same three enums | Interest diagnostic |
| `attempt_waitlist` | Valid browser form handed to `/api/waitlist` | same three enums | Attempt only; never conversion |
| `submit_waitlist` | **Not emitted by page in this package** | none | Reserved for future provider-signed/server-validated success |
| `provider_confirmed_subscriber` | Buttondown accepted subscriber record/export | server-derived lane, provider timestamp, non-PII record ID | Sole conversion authority; reconciliation sheet only |
| `welcome_open` | Buttondown reporting | lane when provider record preserves it | Diagnostic, privacy-noisy |
| `welcome_reply` | Human review of inbox reply | lane + bounded intent class in private sheet | Strong qualitative evidence |

Before analytics loads, raw query values are mapped against the exact registry, then `history.replaceState` removes query and fragment. Raw URL, UTM, referrer, email, role, frequency, and provider data never enter Plausible. An unmatched tuple becomes the canonical `unattributed/unknown/hero_a` tuple and its raw values are discarded.

### Registered UTMs

Base URL below uses `https://VERIFY_DOMAIN/`; replace only after the Pages custom domain is live.

| Lane | Full path |
|---|---|
| Cold paid | `?utm_source=linkedin&utm_medium=paid_social&utm_campaign=restore_tabs_v1&utm_content=support_agent_static_a` |
| Cold Reddit | `?utm_source=reddit&utm_medium=community&utm_campaign=restore_tabs_v1&utm_content=r_customersuccess_problem` |
| Cold community | `?utm_source=support_driven&utm_medium=community&utm_campaign=restore_tabs_v1&utm_content=support_driven_feedback` |
| Cold social | `?utm_source=x&utm_medium=organic_social&utm_campaign=restore_tabs_v1&utm_content=founder_problem_story` |
| Warm outreach | `?utm_source=founder&utm_medium=warm_outreach&utm_campaign=restore_tabs_v1&utm_content=personal_note` |

Use exactly these tuples. Do not shorten, improvise, or tag warm DMs as social. Direct, missing, modified, and unknown tuples remain `unattributed`.

### Reporting sheet

One row per calendar day and lane: date, lane, qualified unique visitors, CTA clicks, valid attempts, Buttondown-confirmed subscribers, double-opt-in completions (if available), replies, concrete-use-case replies, $ spend, CVR, cost/confirmed subscriber, exclusions, and notes. Maintain separate sections for each cold lane, warm outreach, and unattributed. Never make a pooled warm+cold cell.

CVR formula per lane: `confirmed subscribers with matching provider-preserved lane / qualified unique Plausible visitors in the same lane × 100`.

Do not use source-specific rules until a real test signup proves the provider-confirmed subscriber record retains that canonical lane. If Buttondown cannot preserve it, use distinct verified provider forms/tags per lane or suspend lane CVRs and report only defensible aggregates.

### Welcome email and reply classification

- Subject: `Would one-click client tab restore help your support workflow?`
- Body: `Thanks for your interest in ContextDock. It is still an unbuilt concept. What happened the last time you had to reopen a client's working context? Reply with the tabs you needed and how long it took. Planned plans currently start from $9/month; would you try that if the core restore worked reliably? A short reply is perfect. — ContextDock`
- Private reply classes: `concrete_recurring_use`, `one_off_use`, `price_yes`, `price_no`, `unclear`. Do not send reply text or email addresses to analytics.

## 4. Ten-day traffic calendar

All dates are relative so the test starts only after instrumentation QA. Daily operator cap: 45 minutes replying in each active community. Obtain community permission and follow current rules before posting.

| Day | Channel and action | Budget | Registered link | Checkpoint |
|---:|---|---:|---|---|
| 1 | QA only: valid + invalid form tests, provider lane persistence, Plausible sanitized URL/event test; then publish | $0 | Each link once | No traffic until all launch gates pass |
| 2 | Warm: 5 personal messages to known ICP contacts; ask them to assess fit, not “support” a launch | $0 | Warm outreach | Record separately; reply personally |
| 3 | Cold community: request permission, then value-first Support Driven post | $0 | Cold community | Watch relevance and moderation |
| 4 | Cold paid: launch one LinkedIn US creative aimed at frontline SaaS support/customer support roles | $30 max | Cold paid | One audience, creative, and hero |
| 5 | Cold Reddit: one founder-disclosed problem post in an eligible buyer community after checking its rules | $0 | Cold Reddit | Do not cross-post identical copy |
| 6 | Cold social: publish X problem story and engage relevant replies | $0 | Cold social | No audience or headline changes |
| 7 | Warm: 5 more personal ICP messages; follow up only with responders | $0 | Warm outreach | Never add to cold totals |
| 8 | Paid checkpoint; add up to $45 only if at least 1 confirmed subscriber or 40-visitor read is not yet possible | $45 max | Cold paid | Pause under early-stop rule |
| 9 | Cold community follow-up: share one non-sensitive learning in the original thread; no second promotional post | $0 | Same original link | Drive replies, not a new lane |
| 10 | Add up to $75 to paid only if it remains eligible; export provider and analytics data; freeze results | $75 max | Cold paid | Apply rules without extending window |

Total paid cap: `$30 + $45 + $75 = $150`; later tranches are conditional, not automatic.

### Ready-to-post channel copy

**Support Driven (ask moderators first)**

> Founder research: how do small SaaS support teams reopen client context?
>
> When a client issue returns after a day or a handoff, I often see the same setup work: reopen the ticket, admin, docs, logs, and account record before touching the problem. I am testing—not yet building—a narrow Chrome extension that would save those tabs per client and restore the workspace in one click.
>
> If you work hands-on in support, what happened the last time you had to reconstruct that context? I made a short page with the exact scope and planned price from $9/month. Join only if you would genuinely want early access: [cold-community UTM link]
>
> I am the maker; there is no live product or ship date yet.

Do: answer every substantive comment and disclose stage. Don’t: DM commenters without permission, manufacture urgency, or imply moderator endorsement.

**Reddit (use only where feedback posts and external links are allowed)**

> Title: Support agents: how often do you rebuild the same client tabs?
>
> I’m validating a small idea before writing code. For support work that jumps among clients, the repeated cost seems to be reconstructing the working set: ticket, admin, logs, docs, billing, and notes.
>
> The concept is a Chrome extension that saves a workspace per client and restores those tabs in one click. It is not built, has no ship date, and planned pricing starts from $9/month.
>
> Is this a recurring job in your team, or do bookmarks/tab groups already solve it? If the narrow concept fits, the early-access waitlist is here: [cold-Reddit UTM link]. I’m the maker and welcome blunt counterexamples.

Do: choose one relevant buyer subreddit and comply with its current rules. Don’t: post to multiple subreddits at once, argue with “bookmarks solve it,” or count comments as conversions.

**X**

> A support ticket reopens. Before helping, you reopen the client’s admin, logs, docs, billing, and old ticket—again.
>
> I’m testing an unbuilt Chrome extension that would save that client workspace and restore it in one click. Planned from $9/month; no ship date yet.
>
> If that matches your hands-on SaaS support workflow: [cold-social UTM link]

Do: pin during the test and discuss real workarounds. Don’t: use “launched,” quote signups as customers, or change the link’s UTM tuple.

**Warm personal note (send only to people the founder genuinely knows)**

> Hi [Name]—I remember you work hands-on with SaaS customers. I’m testing a narrow idea before building: save the tabs used for each client, then restore that workspace in one click. It’s unbuilt, with planned pricing from $9/month. Would you look at this page and join only if you would actually want early access? [warm UTM link] Either way, what happened the last time you rebuilt a client’s tab context?

Do: personalize the reason for contacting them. Don’t: ask for a favor-signup or move this response into a cold lane.

**Paid creative**

- Primary text: `Back on a client issue? Stop hunting through history for the same admin, ticket, docs, and logs. ContextDock is a planned Chrome extension to restore each client's saved tab workspace in one click. In validation; planned from $9/month.`
- Headline: `Restore the right client tabs in one click`
- CTA: `Join the early-access waitlist` in the creative and destination. Use no platform button if that exact label is unavailable; if the platform forces a different visible CTA, do not run the ad there.
- Visual: honest conceptual arrangement of browser-tab cards labeled `Admin`, `Ticket`, `Logs`, `Docs`, plus `Client workspace`; mark `Concept` visibly. No fake extension UI.

## 5. Decision procedure

1. Freeze the 10-day window, page variant, allow-list, exclusions, and provider export timestamp.
2. Reconcile each Buttondown-confirmed record to its provider-preserved canonical lane. Put unknowns in `unattributed`; do not infer from signup time.
3. Remove internal QA and documented bot traffic from denominators. Record exclusions rather than deleting source records.
4. Evaluate each lane only after its minimum. Keep warm outreach in its own table and narrative.
5. Count replies using the pre-registered private classes; a click, submit attempt, open, or vague compliment is not a concrete use case.
6. Apply experiment-level rules in order: distribution failure → proceed → retest → reshape. `Park` requires the later controlled retest.
7. Write one decision sentence with the dated source slices that support it. Do not upgrade the evidence class beyond observed experiment.

| Outcome after reconciliation | Action |
|---|---|
| Proceed bar met | Scope only save, label, list, and one-click reopen for a thin Chrome prototype; interview the five concrete-use respondents first |
| CVR bar met, reply bar missed | Send one reply question, conduct five short interviews, revise only hero/problem language, then rerun one cold lane |
| Cold traffic minimum missed | Test channel access/creative for five more days under a new protocol; make no product-demand claim |
| Reshape bar met | Narrow to the strongest role/workflow revealed in replies, or change promise; run a fresh page |
| Paid lane costly but an organic lane strong | Stop ads; continue only the qualifying organic lane and assess whether acquisition can be repeatable |
| Warm strong, all cold weak | Treat as network affinity, not market proof; do not build until a cold lane validates |

## 6. Explicit non-build scope

During this smoke test, do not build the extension, account system, workspace sync, tab-content capture, CRM/help-desk integrations, AI tab grouping, team sharing, billing, admin dashboard, onboarding, browser-store listing, polished product demo, referral loop, or full brand site. Do not promise local-only storage, encryption, login restoration, cross-device sync, or session recovery until implemented and tested.

## 7. Launch and QA checklist

- Replace `VERIFY_DOMAIN`, `VERIFY_CONTACT_EMAIL`, all Plausible contract constants, and all Buttondown contract constants.
- Using current official Buttondown documentation, record the docs URL and verification date in `artifacts/README.md`; verify endpoint, auth header, request payload, accepted status, double-opt-in behavior, and metadata/tag type.
- Create one Buttondown automation/welcome email using the supplied copy. Confirm the privacy/unsubscribe behavior and account sender identity.
- Deploy to Cloudflare Pages and add the Buttondown credential as an encrypted environment variable, never a client variable.
- Using current official Plausible documentation, record URLs/date; verify script source, domain value, custom-event API, privacy behavior, and whether SPA/manual pageview handling changes the implementation.
- Submit one valid test for every registered UTM tuple and prove the matching lane appears on each provider-confirmed subscriber. Submit one unknown tuple and prove it remains `unattributed`.
- Test invalid email, missing consent, wrong media type, malformed JSON, `null`, array, scalar, >2 KiB chunked body, provider rejection, provider timeout, and network failure. Expect bounded categories only; verify logs contain no PII, secrets, bodies, or exception text.
- Verify raw query and fragment disappear before analytics initialization and never appear in Plausible. Confirm only canonical lane/placement/variant properties are sent.
- Confirm local UX says only “Submission sent” after a provider-accepted API response; it never claims confirmed membership. Check Buttondown’s provider-owned double-opt-in experience.
- Confirm the page has only the exact CTA `Join the early-access waitlist`, no testimonial/logo/count/ship-date claim, and planned pricing is consistently `from $9/month`.
- Test keyboard navigation, visible focus, label association, checkbox validation, 320 px layout, reduced-motion mode, and social preview after the real OG image is hosted.
- Zero analytics traffic or waitlist requests is expected until these gates are resolved. Do not buy ads before all checks pass.

## 8. Evidence handoff

| Field | Value |
|---|---|
| Current decision | TBD after test |
| Evidence classes | assumption |
| Supported claims | TBD after test |
| Still unproven | Demand, source-specific conversion, willingness to pay, acquisition cost, product usefulness, privacy architecture, retention, and ship timing are TBD after test |
| Contradictions / exclusions | No supplied behavioral evidence or test results; warm outreach must never be pooled with cold traffic; invalid attempts, QA, bots, and unattributed records are excluded from source-lane CVR |
| Source anchors | Pre-registered protocol dated 2026-08-02 in this file; observed anchors will be the frozen Plausible lane export, Buttondown confirmed-subscriber export, spend export, and coded reply sheet after day 10 |
| Next validation | Founder runs the gated 10-day test; proceed only if two cold lanes, ≥12 confirmed cold subscribers, ≥5 concrete-use replies, and ≥3 price-positive replies meet the registered rules |
