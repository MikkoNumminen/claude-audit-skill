# Methodology

Why the five-subagent pattern exists, how the case-study numbers
were measured, and the caveats that come with them.

## Why five subagents, not one

A single-agent review of a non-trivial codebase tends to produce
5–10 high-level notes and miss concrete cross-cutting bugs. The
observed failure mode is consistent: the model devotes early
attention to one category (say, concurrency), finds a handful of
issues, and by the time it reaches a later category
(resource-lifecycle) it has mostly forgotten the specific patterns
that initially tripped the concurrency scan.

Splitting the review into parallel subagents with non-overlapping
scopes bounds each model's attention to one category. Empirically
the aggregate produces substantially more findings — not because
five models have more total capacity (they do), but because each
one does its own scope *thoroughly* instead of juggling five.

Five scopes, chosen to be orthogonal:

| # | Scope | Typical bugs |
|---|-------|--------------|
| 1 | Resource lifecycle | file handles, subprocesses, tempfiles, sockets, GUI widgets |
| 2 | Data integrity | format assumptions, silent conversions, encoding drift |
| 3 | Concurrency | shared state, TOCTOU, daemon-thread death |
| 4 | Error paths | swallowed exceptions, pre-append errors, missing try/finally |
| 5 | External boundaries | timeouts, path traversal, shell interpolation |

If an issue straddles two scopes (e.g. a swallowed exception in a
subprocess shutdown path is both lifecycle + error paths), the
"most appropriate" subagent claims it. Some overlap is tolerable.
What matters is that the scopes are **non-overlapping enough that
parallel work on the fixes is safe** — you can merge resource-
lifecycle fixes and concurrency fixes simultaneously without
conflicts, because the scopes touch different parts of the code.

## Phase 1 is best-effort

Static-analysis tools (`ruff`, `mypy`, `bandit`, `vulture` for
Python; `eslint`, `tsc`, `npm audit` for JS/TS; `clippy`,
`cargo audit` for Rust; `golangci-lint`, `staticcheck`,
`govulncheck` for Go) are tried but not required. If a tool is
missing, the skill records it under "Skipped" with a reason and
moves on. Never fabricate tool output.

The skill runs best when you have the tools installed in a dev
venv or on `PATH`, but it produces useful output even with all of
Phase 1 skipped.

## Case-study numbers

One invocation on a ~150-file Python desktop app (2026-04-23)
produced:

- **66 findings**, severity split: 7 critical / 22 high / 24 medium
  / 13 low
- **26 `fix(*)` commits** landed across 7 parallel branches within
  24 hours of the audit
- Wall-clock for the audit itself: ~8 minutes of parallel-agent time

A free-form `review this codebase` pass on the same repo the day
before surfaced about 8 high-level notes, most of which
re-appeared as findings in the structured audit.

## Caveats

- **n = 1.** The 66-vs-8 comparison is one data point on one
  codebase. Expect the delta to vary with codebase size, language,
  prior audit coverage, and the person triaging the output.
- **Token cost.** Five parallel subagents is token-heavier than a
  single pass. The trade-off is that the additional findings tend
  to be concrete, actionable bugs rather than more prose. Whether
  that trade-off pays off depends on what the audit is for.
- **Pattern-matching is heuristic.** Some findings are false
  positives. The follow-up workflow includes a user-triage step
  (`~~strikethrough~~` false positives with a reason) so the
  tally stays honest over the fix cycle.
- **Not a security review.** This skill finds robustness bugs
  (things that will make the software break or corrupt data in
  practice). For exploitable vulnerabilities, use a security-
  focused review — the scopes overlap but the severity
  calibration is different.

## Measuring it yourself

If you want to compare a structured audit vs. a free-form review on
your own codebase, here is a reproducible protocol:

1. Run `git log -1 --format=%H > /tmp/audit_sha.txt` to record the
   exact commit.
2. In a fresh Claude Code session, ask `review this codebase for
   robustness issues`. Capture the number of findings.
3. In another fresh session on the same commit, invoke this skill.
   Capture the findings list from
   `docs/audits/audit-<YYYY-MM-DD>.md`.
4. Compare. Note which findings overlap, which are unique to
   either, and which are false positives in either.

Three runs per condition is the minimum to separate cache luck
from real signal. One run is only useful as a lower-bound sanity
check.
