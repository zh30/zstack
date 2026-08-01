# Channel playbook — z-market-validate

Use this when running Phase 2. Adapt queries to the idea; keep both **problem language** and **product language**.

## Query recipes

Replace `{pain}`, `{audience}`, `{category}`, `{competitor}`:

| Intent | Example patterns |
|--------|------------------|
| Pain | `"{pain}"`, `I hate {pain}`, `sick of {pain}`, `{audience} struggling with` |
| Demand | `looking for {category}`, `recommend {category}`, `alternative to {competitor}` |
| Pay | `{competitor} pricing`, `worth paying for {category}`, `too expensive {category}` |
| Fail | `{competitor} shutdown`, `{category} scam`, `cancelled {competitor}`, `migrated from {competitor}` |
| Indie | `I built a {category}`, `MRR {category}`, `failed {category} startup` |
| CN (if relevant) | `{痛点}`, `有没有好用的{品类}`, `{竞品} 太贵`, `{竞品} 替代` |

## Channel tactics

### X / Twitter

- Semantic + keyword search for recent posts (last 12–24 months bias).
- Follow threads where buyers vent; note follower niche when obvious.
- Search builders AND buyers separately.

### Reddit

- Find 2–5 subreddits where the **buyer** hangs out (not only r/SaaS / r/Entrepreneur).
- Sort by relevance/comments; prefer posts with concrete workflows.
- Read controversial comments — objections hide there.

### Hacker News

- Search Algolia HN for `{category}`, Show HN launches, “Ask HN: how do you…”.
- Comments > story points for pain quality.

### Product Hunt

- Search similar products; read **critical** comments and “I switched from…”.
- Note pricing tiers if listed; treat upvotes as awareness, not demand proof.

### Indie Hackers

- Search product names and “revenue”, “failed”, “pivot”.
- Useful for **solo feasibility** and distribution stories.

### Review sites / stores

- Mine 1★ and 2★ themes: reliability, pricing, missing features, support load
  (support load = indie cost signal).

### China-oriented (optional)

- Prefer primary posts over marketing accounts.
- Discount pure lead-gen / course-selling threads unless they reveal buyer language.
- Map slang and category words carefully (same product, different names).

## Signal weight guide

| Weight | Criteria |
|--------|----------|
| **high** | Recent, specific workflow, money/time loss, repeated by multiple people |
| **med** | Clear opinion but generic, or older, or single-channel |
| **low** | Meme, promo, vague “this would be cool”, bot-like |

## Minimum scan checklist

Before scoring, confirm:

- [ ] ≥4 channels attempted  
- [ ] ≥3 demand-polarity signals  
- [ ] ≥3 objection / churn / “already solved” signals  
- [ ] ≥3 substitutes named  
- [ ] At least one **buyer-habitat** channel (not only founder Twitter)

## If tools are limited

Give the user this manual pass (30–60 min):

1. Reddit search + 2 buyer subreddits  
2. Twitter/X advanced search last 90 days  
3. HN Algolia  
4. PH search + 1 review site  
5. Note 10 quotes with links into the report template  

Still produce scores with wider uncertainty bands.
