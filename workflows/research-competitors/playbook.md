# Playbook: find-competitors

**Version**: v0 (generic baseline, expected to evolve from real use)
**Last edited**: 2026-05-13

## Scope

This playbook covers **competitor discovery and initial profiling** for a product or product category. It applies when the user asks things like *"who competes with X"*, *"alternatives to X"*, *"who else is doing Y"*, or *"map the [category] space"*.

It does NOT cover:
- Deep competitive analysis (pricing teardowns, feature matrices) — that's a follow-up after discovery.
- Customer interviews or qualitative research.
- Market sizing — see a future `find-market-size` playbook.

## When to load

Load this playbook automatically when the user's request matches any of:

- "find competitors of …"
- "who competes with …"
- "alternatives to …"
- "what other [category] tools are there"
- "map the [category] space"
- "who else does X"

The user can also invoke explicitly: *"use the find-competitors playbook for [topic]"*.

## Source priority

Sources are ranked by general usefulness. **Always start from the top, but skip sources that don't fit the product type** (column 3).

| # | Source | Best for | Skip when | Search hint |
|---|---|---|---|---|
| 1 | **ProductHunt** (producthunt.com) | Recently launched consumer/SaaS products, indie tools | Looking for enterprise B2B niche | `site:producthunt.com [keyword]` |
| 2 | **G2** (g2.com) | B2B SaaS with real reviews, pricing, segments | Early-stage products with no reviews yet | `site:g2.com [category]` |
| 3 | **AlternativeTo** (alternativeto.net) | "Find products similar to X" — fast similarity discovery | Need original discovery, not similarity | `site:alternativeto.net [product]` |
| 4 | **YC Startup Directory** (ycombinator.com/companies) | Funded early-stage startups, by industry tag | Bootstrapped or non-US-centric products | `site:ycombinator.com/companies [tag]` |
| 5 | **HN "Show HN" search** (hn.algolia.com) | Dev tools, technical products, indie launches | Non-technical consumer products | `Show HN [keyword]` via Algolia |
| 6 | **GitHub trending + topic search** (github.com/topics) | Open-source alternatives, dev libraries | Closed-source competitors | `site:github.com/topics/[topic]` |
| 7 | **Crunchbase** (crunchbase.com — free tier) | Funding stage, founding date, basic firmographics | Detailed financials (paywalled) | `site:crunchbase.com [company]` |

**Rule of thumb**: aim to consult **at least 3 sources** before concluding. Single-source findings are weak.

## Query patterns

Use these as Tavily query templates. Replace `[X]` with the topic.

1. **Direct competitor search**
   `"competitors of [X]"` or `"alternatives to [X]"`

2. **Category landscape**
   `"best [category] tools 2026"` or `"top [category] software"`

3. **Open-source angle**
   `"open source [X]"` or `"[X] open source alternatives"`

4. **Listicles and comparisons** (good for breadth, weak for depth)
   `"[X] vs"` or `"[category] comparison"`

5. **Funding / new entrants**
   `"[category] startup funding"` or `"new [category] companies 2025"`

Run **2-3 different patterns** to triangulate. A single query gives you one perspective.

## Quality signals

### Green flags (worth deep-reading with `webfetch`)

- The result is the **company's own site** (not a listicle about them).
- The page has a **clear pricing page** linked from the result.
- The product description includes a **specific target audience**, not generic claims.
- Recent activity: blog posts, release notes, or commits within the last 6 months.
- The result appears in **multiple sources** (cross-referenced).

### Red flags (discard immediately)

- "Top 10 [X] in 2019" — outdated listicles.
- SEO content farms (no author, generic listicles, affiliate-link heavy).
- The "competitor" is actually a freelancer/agency, not a product.
- Marketing copy with zero specifics ("AI-powered", "next-generation", "best-in-class" without substance).
- Domain squatters or parked pages.

## Output expectations

All findings for a single investigation live under **`research/competitors/<subject-slug>/`**, where `<subject-slug>` is the product or category being investigated (the "subject"), not a competitor. Example: investigating competitors of a code review assistant → `research/competitors/code-review-assistants/`.

Inside that folder:

```
research/competitors/<subject-slug>/
├── SUMMARY.md                  # synthesis: clusters, gaps, pricing patterns, recommendations
├── <competitor-1-slug>.md      # one file per significant competitor
├── <competitor-2-slug>.md
└── ...
```

The investigation is "done" when you can populate one file per significant competitor following the template in `.agents/skills/research/SKILL.md` ("Competitor Analysis" section), plus a `SUMMARY.md`. At minimum:

- 3-7 competitors identified (fewer is suspicious; more probably means the category is too broad).
- Each competitor has: URL, one-line positioning, target audience, pricing model (or "unknown" + why), 3-5 key features, source citations.
- `SUMMARY.md` synthesizes patterns: clusters, gaps, dominant pricing models, where the subject fits in.

**Why a folder per subject**: keeps each investigation self-contained, makes re-investigations easy (you can later add `research/competitors/<subject-slug>-2027/` for a fresh snapshot), and avoids mixing competitor sets from unrelated investigations.

## Iteration log

Append a brief entry after each real use of this playbook. Format:

```
### YYYY-MM-DD — [topic researched]

- What worked: …
- What didn't: …
- Sources added/removed: …
- Query patterns that were useful: …
```

<!-- Entries below this line -->

### 2026-05-19 — business-spec-tools (conversational business specification)

- **What worked**: The playbook's source priority list (ProductHunt, G2, AlternativeTo, YC, HN, GitHub, Crunchbase) was useful for discovering adjacent tools (Productboard, Linear, Productlane, Specmatic). Tavily search with multiple query patterns helped triangulate the landscape.
- **What didn't**: The category is so novel that direct competitors don't exist. Standard queries ("competitors of X", "alternatives to X") didn't work because there's no X yet. Had to pivot to adjacent categories (PRD tools, API contract tools, stakeholder platforms) and synthesize the gap.
- **Sources added/removed**: None. The existing sources were appropriate, but the *absence* of results in those sources was itself a finding (market gap confirmed).
- **Query patterns that were useful**: 
  - `"business requirements" conversational specification tool client-friendly` — found AI-driven project spec tools (adjacent but not competitors).
  - `PRD product requirements document collaboration tool 2026` — found Productboard, Linear, Productlane (feature prioritization, not business rule capture).
  - `"living documentation" business rules versioned client stakeholder` — found articles on living docs but no tools that version business rules as first-class artifacts.
  - `Productboard Linear Productlane PRD collaboration tool` — direct search for known adjacent tools.
  - `Specmatic API specification contract testing tool` — found API contract tools (technical level, not business level).
- **Lesson learned**: When researching a novel category with no direct competitors, the playbook still works — but the output is a *gap analysis* rather than a *competitor list*. The synthesis becomes: "Here's what exists in adjacent spaces, here's what's missing, here's the opportunity."
