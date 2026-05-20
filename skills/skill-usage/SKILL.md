---
name: skill-usage
description: Measure actual Claude Code skill usage from local transcript JSONL files. Walks `~/.claude/projects/*/*.jsonl` (and their `subagents/*.jsonl` sidechain files), filters assistant messages by the harness-emitted `attributionSkill` field, groups invocations by `(sessionId, skill)`, sums tokens deduped by `requestId`. Emits a dated `SKILL-USAGE-{YYYY-MM-DD}.json` with per-skill measured invocation counts and token totals. Designed to replace the editorial estimates in skill catalogs (`docs/SKILLS.md`, registry verdicts) with real receipts.
barney: Counts how often you've actually used each Claude Code skill by reading your local session logs. Replaces guesses with real numbers — run quarterly.
---

# Skill usage measurement

Replace author-estimated "tokens per use × uses per year" guesses with measured values from real Claude Code sessions.

The Claude Code harness already tags every assistant message inside a skill run with `"attributionSkill": "<skill-name>"`. This skill harvests that signal — no heuristic detection, no slash-command parsing, no fuzzy boundaries. The work is mostly file I/O, which the companion `scan.mjs` script handles; this SKILL.md is the procedure that drives the script and validates its output.

## When to use

- "`/skill-usage`", "measure my skill usage", "how many tokens has this skill actually used", "real receipts not estimates"
- Quarterly drift-check on the portfolio token-savings figures
- Before any public claim about token savings (interview demos, portfolio site, blog posts)
- After authoring a new skill, once it has been invoked enough times that the cadence claim is non-trivial

NOT for: real-time monitoring (the JSONL is flushed at session end, sometimes later), per-skill quality assessment (this counts invocations and tokens, not outcomes), or detecting which skill *should* have been used in a given session (the `attributionSkill` field tells you what *was* used).

## What this skill does

1. Walk `~/.claude/projects/*/` (every project Claude Code has been used in) and enumerate `*.jsonl` plus `*/subagents/*.jsonl` sidechain files.
2. For each line where `type == "assistant"` AND `attributionSkill` is set, record `{ skill, promptId, requestId, sessionId, timestamp, usage }`.
3. Deduplicate by `requestId` (the harness emits two adjacent assistant lines per API call when a message contains both thinking and tool_use blocks — they share `requestId` and `usage`).
4. Group records by `skill`, then by `promptId` to count invocations.
5. Compute per-skill: invocation count in window, average `tokens_per_use` (including cache-creation input + output, excluding cache-read which is a hit, not a cost), total tokens in window, and an extrapolated `uses_per_year` from the in-window rate.
6. Emit two files in `.claude/agent-verdicts/`: the dated `SKILL-USAGE-{YYYY-MM-DD}.json` (history) and a byte-identical `SKILL-USAGE-LATEST.json` (stable filename for consumers like `/skill-registry`'s transcript-measurement overlay).

End-to-end with no user pauses. The companion script does the parsing; the main thread validates the output and reports the summary.

## Procedure

### 1. Run the scanner (main thread)

```bash
node skills/skill-usage/scan.mjs --window-days 90 --out .claude/agent-verdicts/SKILL-USAGE-$(date +%Y-%m-%d).json
```

Args:

- `--window-days N` (default 90) — only sessions within the last N days count toward invocations and tokens. The 90-day default balances "enough data to extrapolate" vs "stale enough that a year-old burst of usage doesn't dominate the average." Override to 365 for an annual snapshot or 30 for a recent-trend check.
- `--out PATH` — output file path. Default writes to the current repo's `.claude/agent-verdicts/SKILL-USAGE-{YYYY-MM-DD}.json`.
- `--projects-dir PATH` — override the default `~/.claude/projects/` location. Useful for testing against a captured sample.

The scanner prints a one-line summary on success: `Wrote SKILL-USAGE-{date}.json — N skills measured across S sessions in {window} days.`

### 2. Validate the output (main thread)

Read the JSON. Sanity-check:

- Every entry has `name`, `invocations >= 0`, `tokens_per_use_avg >= 0`, `uses_per_year` (extrapolated).
- The skill names present match real skills (cross-check against `.claude/skills/*/SKILL.md` in the consumer repos you care about).
- `total_tokens_in_window` ≈ `invocations × tokens_per_use_avg` (within rounding).

If a skill is present in `~/.claude/skills/` (or any consumer's `.claude/skills/`) but missing from the output, the most likely cause is **zero invocations in the window**. The scanner only reports skills it observed — skills with no recorded use don't get a row. That's intentional: a row with `invocations: 0` would imply "we measured zero use" when in fact "we never saw a use" — different epistemic claim.

### 3. Done

Report the file path and a one-line summary: `Wrote SKILL-USAGE-{date}.json — N skills (M invocations, ~T total tokens) across S sessions in {window} days.`

The user decides whether to:

- Commit the JSON (mikkonumminen.dev tracks `SKILL-USAGE-*.json` in `.claude/agent-verdicts/` via gitignore exception — same pattern as `SKILL-REGISTRY-*`)
- Update `docs/SKILLS.md` catalog rows from the measured numbers
- Re-run `/skill-registry` to ingest the measurements as the 5th receipt source

Do NOT auto-commit. Do NOT mutate any other file. The measurement is a snapshot; how it informs other artifacts is a separate decision.

## Output schema

```ts
{
  generated_at: string,        // ISO 8601 UTC timestamp
  window_days: number,         // the --window-days arg used
  projects_scanned: number,    // count of directories under ~/.claude/projects/
  sessions_scanned: number,    // count of *.jsonl files (root + subagents) examined
  attributed_assistant_messages: number,  // total dedup'd assistant lines with attributionSkill set
  skills: [{
    name: string,              // value of attributionSkill, verbatim
    invocations: number,       // count of distinct promptIds with at least one attributed message
    tokens_per_use_avg: number, // mean of per-invocation totals
    uses_per_year: number,     // (invocations / window_days) * 365, rounded
    total_tokens_in_window: number,
    annual_total: number,      // tokens_per_use_avg * uses_per_year (matches /skill-registry's existing field name)
    sample_session_ids: string[],  // up to 5 sessionIds for spot-checking
    last_invoked: string       // ISO 8601 — most recent attributed message timestamp for this skill
  }]
}
```

### Token accounting convention

Per-invocation tokens sum these `usage` fields across all messages with that `promptId`:

- `input_tokens` — fresh input to the API
- `output_tokens` — model output
- `cache_creation_input_tokens` — input that becomes cache (paid once when written)

NOT summed:

- `cache_read_input_tokens` — input served from cache (already paid for upstream; ~10× cheaper per token but not free; tracking it would double-count across a single skill's multiple turns)

The convention matches how Anthropic's pricing actually bills cached vs fresh input — caches are a hit, not a cost. If you care about cache efficiency specifically, that's a separate report (the scanner could emit it as a sibling field; out of scope here).

### Sub-agent accounting

Sub-agent JSONL files (under `<session-id>/subagents/agent-<id>.jsonl`) carry the same `attributionSkill` as the parent session. The scanner walks them as siblings of the root session file and dedupes by `requestId` so sub-agent tokens are counted once. This matters: a skill like `/sync-readmes` spawns 6 parallel Sonnet sub-agents, each consuming ~20K tokens — ignoring them would understate the skill's actual cost by 5-10×.

## Token expectations

For a 90-day window across ~5 projects with ~100 total sessions:

- File I/O (script): ~5MB of JSONL read off disk; ~10-50ms per file; ~5-30s total wall-clock
- Main-context absorption: ~3K input (script summary line + JSON validation read) + ~1K output (report to user)
- Wall-clock for the model work: under 5s; the heavy lifting is in the script

The script is cheap because the harness already structured the data. Most existing token-measurement attempts re-derive what `attributionSkill` already gives you.

Cadence: quarterly per repo, ad-hoc before public claims. ~12 uses/year for an actively-maintained portfolio.

## Failure modes

- **`~/.claude/projects/` not found.** Either Claude Code has never run on this machine, or the user hasn't invoked the skill from a Claude Code session yet. The scanner exits 0 with a clear "no projects directory" message rather than failing the build.
- **JSONL file is partial / mid-write.** The last line may be incomplete. The scanner skips malformed lines, counts the skip, and continues. A "skipped N malformed lines" warning surfaces in the script output.
- **Same `sessionId` appears in multiple project directories.** Sub-agent JSONL files inherit the parent session's `sessionId` but may live in a different project directory (when the agent's `cwd` differs from the parent's). The scanner dedupes by `sessionId + requestId`, so cross-directory duplicates collapse cleanly.
- **`attributionSkill` field absent.** Some older transcript formats (pre-attribution) don't carry it. The scanner treats those messages as "no skill" and excludes them — they don't appear in the skills array. If most of your transcripts pre-date the attribution feature, the output will look sparse; rerun once enough new sessions accumulate.
- **Skill renamed mid-window.** If a skill was renamed (e.g., `/audit-old` → `/audit`), both names appear as separate rows. Manual reconciliation: edit the JSON post-emit, or accept that the renamed skill needs a fresh window to look "real."

## Limitations (measured, but not the whole story)

This skill produces an **invocation count + token total**, not a value claim. It doesn't measure:

- **Outcome quality.** A skill invoked 50 times producing low-quality output is still 50 invocations.
- **User abandonment.** A skill invoked and cancelled mid-run still counts as an invocation; tokens consumed up to the cancel point are summed honestly.
- **Counterfactual savings.** "How many tokens would you have used without this skill?" is unknowable; the scanner only sees what happened, not the parallel-universe alternative.

The output is an honest measurement of one specific quantity (token consumption attributed to a named skill across a time window). Combined with the editorial estimates in `docs/SKILLS.md` and the registry verdicts, it forms the receipt layer that makes portfolio claims falsifiable — but it's not the only claim worth making about a skill.

## Companion script

See [`scan.mjs`](scan.mjs) in this directory. ~200 lines of Node, no external npm deps. Reads JSONL line-by-line with a streaming parser to keep memory bounded; aggregates in-memory; writes one JSON file at the end.
