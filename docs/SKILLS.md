# Skills catalog

Per-skill token-economics for everything in this repo. Numbers are author-estimated educated guesses unless otherwise noted; the `/skill-usage` skill exists to replace them with measured values from real Claude Code session transcripts.

This file is also a **receipt source** for the `/skill-registry` skill that powers [mikkonumminen.dev](https://github.com/MikkoNumminen/mikkonumminen.dev)'s contact-page PDF: when a consumer repo installs a skill from this library, the registry follows the symlink back to this repo and reads the corresponding row below.

## Catalog

| Skill                                | Tokens / use                                                                | Uses / year                                 |    Total | Notes                                                                                                                |
| ------------------------------------ | --------------------------------------------------------------------------: | ------------------------------------------: | -------: | -------------------------------------------------------------------------------------------------------------------- |
| [`audit`](../skills/audit/SKILL.md)             | ~5K (Phase 1 + Phase 3 orchestration; the 5 parallel sub-agents add ~80-100K Sonnet input each — counted toward the sub-agent budget, not the main thread) | ~5 (per repo, when shipping a new release)  |     ~25K | Largest cost is the parallel sub-agents — see [METHODOLOGY.md](METHODOLOGY.md) for the trade-off vs. serial audit    |
| [`skill-usage`](../skills/skill-usage/SKILL.md) | ~30K (the JSONL scan happens in a companion `scan.mjs` script; only the summary is read into Claude's context) | ~12 (quarterly per portfolio + ad-hoc)      |    ~360K | Designed to replace editorial estimates with measurements — see its SKILL.md for what it reports                     |
| [`mikko-help`](../skills/mikko-help/SKILL.md)   | ~5K (the cheapest skill — Glob + Read first 10 lines of each SKILL.md, no sub-agents)             | ~50 (ad-hoc; tab-completion replacement)    |    ~250K | Personal-namespace discoverability helper; fork-rename the prefix to brand your own copy                            |

## Caveats

- All "tokens per use" figures are author estimates. The `/skill-usage` skill is the upgrade path that replaces these with measured values from actual session transcripts (`~/.claude/projects/<project>/<session>.jsonl`). Until that's running quarterly against this catalog, treat these numbers as ballpark — ±3× error bars per Spacepotatis's [docs/SKILLS.md methodology](https://github.com/MikkoNumminen/Spacepotatis/blob/master/docs/SKILLS.md).
- "Uses per year" is the noisiest data point. It depends on personal cadence and shifts as the catalog of consumer repos grows. The `/skill-usage` skill's measured invocation count is the trustworthy source once enough data has accumulated (≥90-day window recommended).
- This catalog only covers skills hosted in *this* repo. The full portfolio registry (audits hosted in each consumer repo's own `.claude/skills/`, plus the receipts in their `docs/SKILLS.md`) lives at [mikkonumminen.dev](https://mikkonumminen-dev.vercel.app/contact) — run `skills` in the terminal there for the cross-repo view.

## When this catalog updates

- A new skill is added to `skills/` → add a row.
- The author re-estimates a token figure (typically after a methodology change) → update the row and note the rationale in the PR.
- A `/skill-usage` measurement run produces meaningfully different numbers → reconcile here, mark the row as "measured" with a link to the dated `SKILL-USAGE-{date}.json` it came from.
