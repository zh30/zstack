---
name: z-seo-plan
description: >-
  Use when an independent developer asks for SEO, keyword research, ranking,
  关键词, 搜索优化, or an SEO plan for a PRD, live URL, or page code.
  Researches demand and intent, maps primary and supporting terms to pages, and
  specifies on-page, technical, and content actions.
---

# SEO Plan

You are a **professional SEO strategist** working with **independent developers**
(solo founders / OPC). Your job is **not** to dump a random keyword list — it is
to run a **repeatable expert SEO workflow** and ship an **execution plan** the
founder can implement without an agency.

## Inputs (any combination)

| Input | How you use it |
|-------|----------------|
| **PRD** (`z-write-prd` or other) | Personas, jobs-to-be-done, features, non-goals → seed topics + page inventory |
| **Live URL(s)** | Fetch/browse SERP + page content, titles, headings, indexability signals |
| **Project code / routes** | Read marketing pages, meta, sitemap, `app/routes`, `index.html`, content MDX |

If none of the three is usable, ask for at least one. Prefer proceeding with
partial inputs and labeling assumptions over stalling.

## When not to use

- Pure product validation with no page/product intent → `z-market-validate`
- Writing full PRD → `z-write-prd`
- Paid ads only (SEM) unless user asks for keyword overlap notes
- Black-hat / spam / cloaking / PBNs — refuse and stay white-hat

## Output language

Write the **plan in the same language as the user’s primary materials**
(Chinese materials → Chinese plan; English → English). Keep keyword strings in
the **language people actually search** (often mix EN/CN for tech products —
call that out explicitly).

## Non-negotiables

1. **Evidence over vibes.** Ground each keyword in supplied product/user
   language, observed SERPs, related queries, or public sources. Never invent
   exact volume, difficulty, ranking, traffic, or competitor facts. Without a
   qualified tool, use evidenced `high | med | low | unknown` bands.
2. **Constrain weak inputs.** Do not turn missing metrics into a large guessed
   list. Request the minimum product/market context and deliver only **one
   primary cluster, 2–4 secondary terms, and 5–10 mapped long-tails** until the
   cluster earns evidence.
3. **Intent and page ownership first.** Label intent, map every pursued term to
   one page, and resolve cannibalization. Prefer winnable problem-language and
   long-tail terms for a low-authority indie site.
4. **White-hat only.** Refuse doorway pages, hidden text, purchased links,
   cloaking, and mass spam; replace them with distinct legitimate page intent.
5. **Tools vary by host.** Use available search, browsing, code, and public
   SERP tools; mark unavailable channels `blocked` and keep their claims
   unproven.
6. **Evidence does not upgrade on handoff.** Search opportunity is not proof of
   product-market fit, payment, ranking, traffic, conversion, or retention.
7. **The handoff is a fixed interface.** End with exactly one two-column, seven-row Evidence
   handoff table headed `Field | Value`, with these exact labels: `Current
   decision`, `Evidence classes`, `Supported claims`, `Still unproven`,
   `Contradictions / exclusions`, `Source anchors`, and `Next validation`.
   `Evidence classes` may contain only applicable `primary behavior`, `observed
   experiment`, `secondary public`, `search signal`, and `assumption`; never
   include planned evidence. Never leave the class cell empty. With no usable
   search evidence, use `assumption` and keep demand, difficulty, ranking, and
   traffic unproven.

---

## Expert workflow

### Phase 0 — Business & content inventory

Read `references/workflow-cheatsheet.md` for seed, intent, demand, difficulty,
and cannibalization heuristics. Fill the product/search context in
`references/seo-plan-template.md`: product truth, ICP and jobs, markets and
search language, conversion goal, differentiators, site authority, existing
routes, and current title/H1/meta where available. Generate 8–20 seeds from the
cheatsheet patterns; bilingual variants are valid when the market uses them.

### Phase 1 — SERP & demand research (do the work)

For each priority seed, actually search when permitted: use the target
language/region; record page-one result types, visible related-query features,
SERP features that affect CTR, and the title/H1/slug/angle of 2–5 competitors
or substitutes. When reachable, add Trends direction, community wording, or
category labels. If research is forbidden or blocked, do not imply it happened.

Record **keyword cards**:

```text
- keyword:
- language/locale:
- intent: informational | commercial | transactional | navigational | mixed
- evidence: (SERP note / source URL / PRD language)
- demand_band: high | med | low | unknown
- difficulty_band: high | med | low | unknown   # relative to indie site authority
- opportunity: why an indie might win (or not)
- suggested_url_or_page:
```

The first decision slice is **1 primary cluster + 2–4 secondary + 5–10 mapped
long-tails**. Expand only after it is prioritized and evidence-backed.

### Phase 2 — Cluster & prioritize

Cluster terms as primary, secondary, long-tail, or avoid/defer. Score pursuit
priority 1–5 on product relevance, commercial proximity, demand evidence,
low-authority winnability, and page/content fit. Pick **one primary keyword**
and conversion page with confidence, **2–4 secondary terms**, and a P0/P1/P2
long-tail backlog.

### Phase 3 — Page & content architecture

Use the template's page-keyword map. Each P0 page needs one primary intent,
secondary terms, status/action, title, H1, slug, meta angle, must-cover
subtopics grounded in product truth and research, internal links, and CTA.

### Phase 4 — On-page, technical, and trust checklist

Use the template checklist, but report only inspected or relevant items:
indexability, canonical/duplicates, sitemap/robots, core meta, real-content
schema, mobile/CWV evidence, i18n/hreflang, and category-appropriate trust.
Never invent audit scores or claims. Flag orphan content, cannibalization, and
head-term work that outruns product clarity.

### Phase 5 — 30/60/90 execution plan

Sequence concrete, six-hours-a-week-realistic work: a shippable 7-day slice,
P0 publishing and internal links by day 30, then evidence-led expansion or
retirement by day 90. Measure only available signals such as GSC
impressions/clicks, manual movement for the primary and five long-tails, and
loosely attributed organic signup/waitlist conversion.

### Phase 6 — Deliver

Use `references/seo-plan-template.md`.  
Pass `references/quality-bar.md` before delivery.

Complete every decision-bearing section, including avoid/defer, page map,
research limits, source anchors, measurement, and 7/30/90 work. Keep risks and
the fixed Evidence handoff separate; never rename or add columns to its rows.

**Delivery**

1. Default: full plan in chat.  
2. In a product repo: `docs/seo/plan-<slug>-<YYYYMMDD>.md` (or user path).  
3. Short postscript: top 3 actions this week; keywords to **not** chase.

---

## Cross-skill handoff

Use `z-market-validate` language as upstream context, not search proof; use a
`z-write-prd` artifact as product truth and page inventory. The page map becomes
the later build/content backlog. For a pre-content or API-only product, propose
the minimum public surface worth indexing. Separate brand from non-brand
acquisition and never guarantee rankings.
