# Routing prompts

Each clean session received one request below plus all five descriptions from
the phase-specific `raw/candidate-descriptions.*.txt` file. Candidate order was
rotated left by `case_index % 5`, starting from alphabetical skill order. No
session received expected selections, grading notes, skill bodies, or another
run's response.

The baseline and compact phases used this wrapper:

> Route one user request using only the candidate frontmatter descriptions
> below. Do not use tools, inspect files, or load installed skill bodies.
>
> Candidate skills:
> [five phase descriptions in the rotated order]
>
> User request:
> [one request below]
>
> Reply with exactly two lines:
> selection: &lt;one candidate id or none&gt;
> reason: &lt;one concise sentence&gt;

The prefix phase inserted this sentence after the first sentence:

> These descriptions have been mechanically tail-truncated for a context-budget
> stress test.

## market-vague

Before I spend a month building an AI meeting-to-invoice tool for freelancers,
find demand signals, competitors, objections, and a viable solo-founder entry
wedge.

## market-public

Research public communities and competing products for my early product idea,
then give me an evidence-based go, narrow, or stop recommendation.

## discovery-plan

Help me recruit eight real users and write a non-leading interview guide focused
on what they did the last time this problem happened.

## discovery-debrief

I completed six interviews. Debrief my notes for leading questions, compliments,
past behavior, current spend, and evidence that people would actually switch.

## landing-waitlist

Write a coming-soon waitlist page for my unbuilt app, choose one CTA, give me a
cheap traffic plan, and define conversion thresholds that tell me whether to
continue.

## landing-metrics

My prelaunch page has 350 qualified visitors, 21 signups, four replies, and no
preorders. Help me interpret the funnel and choose the next bounded smoke test.

## prd-notes

Turn my research notes and feature list into a professional MVP PRD with explicit
scope, non-goals, acceptance criteria, risks, and milestones.

## prd-rewrite

My current product spec is vague and every feature is P0. Rewrite it into a
decision-ready PRD a solo developer can build from.

## seo-live-url

Audit my live SaaS site for keyword opportunities, choose a realistic primary
term, and map supporting queries to existing or new pages.

## seo-prd-map

Use this PRD to create an SEO keyword and page plan with search intent, long-tail
priorities, on-page briefs, and technical notes.

## none-code-fix

Fix the failing TypeScript unit test in the checkout service and run the relevant
test suite.

## none-architecture

Design a D1 schema and Hono API architecture for a multi-tenant billing service.

## boundary-real-interviews

I have a rough product idea and want to validate it by recruiting and
interviewing ten real customers about their past workflows.

## boundary-public-research

I have a rough idea but no customer access yet. Use public communities and
competitor evidence to decide whether it deserves deeper research.

## boundary-waitlist-demand

Validate demand for my unbuilt product by shipping a waitlist page, driving a
small amount of traffic, and defining success and kill thresholds.
