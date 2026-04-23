# claude-audit-skill

A [Claude Code](https://www.anthropic.com/claude-code) skill that runs
a multi-phase robustness audit on any codebase. Universal by design —
works on Python, JS/TS, Rust, and Go projects out of the box, and
degrades gracefully on languages it does not know.

> One invocation on a ~150-file Python desktop app produced
> **66 findings** across resource lifecycle, data integrity,
> concurrency, error paths, and external boundaries. The follow-up
> landed **26 `fix(*)` commits across 7 parallel branches** in a
> single day.
>
> A free-form single-agent "review this codebase" prompt on the same
> repo the day before had surfaced about 8 issues. n=1, but the gap
> is worth noticing.

## What it does

Three phases, one command:

1. **Phase 1 — static analysis.** Detects the project's language(s)
   from manifest files, runs the appropriate tools (`ruff`, `mypy`,
   `bandit`, `vulture` / `eslint`, `tsc`, `npm audit` / `clippy`,
   `cargo audit` / `golangci-lint`, `staticcheck`, `govulncheck`),
   skips missing tools cleanly.
2. **Phase 2 — five parallel subagents**, each with a non-overlapping
   scope: resource lifecycle, data integrity, concurrency, error
   paths, external boundaries. Each returns findings with `file:line`
   citations and severity `critical` / `high` / `medium` / `low`.
3. **Phase 3 — aggregated report.** Writes
   `docs/audits/audit-<YYYY-MM-DD>.md` with git SHA of the audited
   commit, severity tally, and a suggested branch topology for the
   fix follow-up.

## Install

### Project-local (per-repo)

```bash
cd /path/to/your/repo
git clone https://github.com/MikkoNumminen/claude-audit-skill.git .claude-audit-skill-tmp
mkdir -p .claude/skills
cp -r .claude-audit-skill-tmp/skill .claude/skills/audit
rm -rf .claude-audit-skill-tmp
```

Or use the installer:

```bash
git clone https://github.com/MikkoNumminen/claude-audit-skill.git
cd claude-audit-skill
./install.sh --target project --repo /path/to/your/repo
```

### User-level (available in every project)

```bash
git clone https://github.com/MikkoNumminen/claude-audit-skill.git
cd claude-audit-skill
./install.sh --target user
```

Installs as a symlink into `~/.claude/skills/audit/` so `git pull`
inside the repo updates the installed skill live.

## Use

In Claude Code, invoke by describing the task:

- `audit this codebase`
- `find bugs`
- `robustness review before the release`
- `check for leaks, races, and swallowed exceptions`

Claude Code loads the skill automatically when a trigger phrase
matches. The three phases run back to back; typical wall-clock time
is 5–15 min depending on repo size and how many static-analysis
tools are available.

## Evals

`skill/evals/evals.json` contains seven evaluation prompts covering:

- Generic audit invocation
- Pre-release robustness check framing
- Behaviour when static-analysis tools are missing
- Date-collision in `docs/audits/` (does not overwrite)
- Style / readability requests are not this skill
- Non-Python repo (Rust) — Phase 1 degrades correctly
- Severity-tally correctness against the body count

These are the behaviours any candidate skill edit must preserve.

## Why this exists

A single-agent code review tends to produce 5–10 high-level notes
and miss concrete cross-cutting bugs. A single model's attention is
finite; by the time it has thought about concurrency it has
forgotten the resource-lifecycle patterns it noticed earlier.
Splitting the review into five parallel subagents with
non-overlapping scopes appears to produce substantially more
findings with very little duplication, in roughly the same
wall-clock time as a single pass.

See [`docs/METHODOLOGY.md`](docs/METHODOLOGY.md) for the full
rationale, including the case-study numbers and the caveats that
come with measuring skills on a single run.

## Honest scope

This skill finds **robustness bugs** — leaks, races, swallowed
exceptions, silent conversions, missing timeouts. It does **not**:

- Find performance hotspots (use a profiler)
- Grade architectural decisions (that is a design review)
- Replace a security review (use `/security-review` for exploitable
  issues; the scopes overlap but are distinct)
- Fix anything — it writes a defect list, not a patch list. Fixes
  happen on follow-up branches.

## License

MIT. See [LICENSE](LICENSE).
