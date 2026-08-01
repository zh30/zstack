# Routing prompts — portable invocation revision

Three fresh, repository-blind agent contexts received only the five candidate
descriptions below, a batch of five natural-language requests, and this rule:
select exactly one candidate skill or `none`, with a concise reason. They did
not receive skill bodies, repository access, expected selections, or grading
notes.

## Candidate descriptions

### z-customer-discovery

Run Mom Test–style customer discovery for independent developers: recruit and
structure 5–15 real user interviews focused on past behavior (not future
intent), debrief each talk for violations, and synthesize evidence on three
gates — pain real/frequent, people already paying for bad solutions, and
willingness to switch. Use for user interviews, customer discovery, The Mom
Test, 用户访谈, or 客户发现.

### z-landing-smoke

Build a lowest-cost demand smoke test for independent developers: a concise
English landing page plus waitlist / email capture / pre-order CTA, a traffic
plan (Product Hunt, Reddit, X, small ads, niche communities), and success
metrics (conversion, opens, contact intent, prepaid). Use before writing lots
of product code to test if anyone cares. Triggers: smoke test, landing page,
waitlist, pre-order page, demand test, 落地页, or 等待列表.

### z-market-validate

Market-validate a rough product idea for independent developers: scan social
and community demand (X/Twitter, Reddit, HN, Product Hunt, Indie Hackers,
optional CN platforms), collect pro and con signals, and produce a realistic
report on commercial value, solo-founder fit, short-term return odds, and best
entry wedges. Use when the user has an early idea, wants market research,
demand validation, "is this worth building", or idea vetting.

### z-seo-plan

SEO execution expert for independent developers: from a PRD, live URL, or
project page code, research real search demand, pick primary and supporting
keywords, map intent and page targets, and deliver an actionable SEO plan with
on-page, technical, and content notes. Use when asked for SEO, keyword
research, 关键词, 搜索优化, SEO 方案, or a ranking plan.

### z-write-prd

Write a professional Product Requirements Document (PRD) from provided
material — idea notes, market-validate reports, user interviews, competitor
notes, or rough specs. Acts as a PRD author for independent developers:
problem, goals, users, scope, requirements, UX flows, metrics, risks, and MVP
cut. Use when asked for a PRD, product requirements, 需求文档, 写 PRD, or a
product spec.

## Requests

### Core A

- `market-vague`: Before I spend a month building an AI meeting-to-invoice
  tool for freelancers, find demand signals, competitors, objections, and a
  viable solo-founder entry wedge.
- `discovery-plan`: Help me recruit eight real users and write a non-leading
  interview guide focused on what they did the last time this problem happened.
- `landing-waitlist`: Write a coming-soon waitlist page for my unbuilt app,
  choose one CTA, give me a cheap traffic plan, and define conversion thresholds
  that tell me whether to continue.
- `prd-notes`: Turn my research notes and feature list into a professional MVP
  PRD with explicit scope, non-goals, acceptance criteria, risks, and milestones.
- `seo-live-url`: Audit my live SaaS site for keyword opportunities, choose a
  realistic primary term, and map supporting queries to existing or new pages.

### Core B

- `market-public`: Research public communities and competing products for my
  early product idea, then give me an evidence-based go, narrow, or stop
  recommendation.
- `discovery-debrief`: I completed six interviews. Debrief my notes for leading
  questions, compliments, past behavior, current spend, and evidence that people
  would actually switch.
- `landing-metrics`: My prelaunch page has 350 qualified visitors, 21 signups,
  four replies, and no preorders. Help me interpret the funnel and choose the
  next bounded smoke test.
- `prd-rewrite`: My current product spec is vague and every feature is P0.
  Rewrite it into a decision-ready PRD a solo developer can build from.
- `seo-prd-map`: Use this PRD to create an SEO keyword and page plan with search
  intent, long-tail priorities, on-page briefs, and technical notes.

### Boundaries

- `none-code-fix`: Fix the failing TypeScript unit test in the checkout service
  and run the relevant test suite.
- `none-architecture`: Design a D1 schema and Hono API architecture for a
  multi-tenant billing service.
- `boundary-real-interviews`: I have a rough product idea and want to validate
  it by recruiting and interviewing ten real customers about their past
  workflows.
- `boundary-public-research`: I have a rough idea but no customer access yet.
  Use public communities and competitor evidence to decide whether it deserves
  deeper research.
- `boundary-waitlist-demand`: Validate demand for my unbuilt product by shipping
  a waitlist page, driving a small amount of traffic, and defining success and
  kill thresholds.
