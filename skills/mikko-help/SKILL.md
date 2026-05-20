---
name: mikko-help
description: List every installed `mikko-*` skill with its one-line description. The fast answer to "I know I have a skill for this but can't remember which one." Reads `~/.claude/skills/mikko-*/SKILL.md` frontmatter (plus any project-local `.claude/skills/mikko-*/SKILL.md`), extracts name + description, prints a single formatted table. Pass `--detect` to also scan the current working directory and recommend which `mikko-*` audit skills are likely to find signal — answers "I'm in a new codebase, which of my skills are relevant here?" No sub-agents, no network, no measurements — just a table (or a table with recommendations).
---

# mikko-help

The discoverability sidekick for the `mikko-*` skill namespace. Type `/mikko-help` when you remember you have a skill for something but can't recall its exact name.

`/mikko<Tab>` from any Claude Code prompt already lists the *names* of every installed `mikko-*` skill (free, built into the CLI). `mikko-help` adds the **descriptions** so you can pick by what each one does, not just by name.

## When to use

- "/mikko-help", "what mikko skills do I have", "list my skills", "remind me what's installed"
- "/mikko-help --detect", "which audit should I run on this repo", "what's relevant for this codebase"
- Onboarding a new machine after a `claude-skills` `./install.sh` run — quick verification that everything landed
- Before invoking another `mikko-*` skill, to confirm the exact name and what it expects
- When you've just `cd`'d into an unfamiliar codebase and want a friendly "here's what your toolkit would do here" pointer

NOT for: cross-repo registry of skills (use `/mikko-skill-registry` for that — it walks sibling repos, this only reads the local skills directory), token-usage measurements (`/mikko-skill-usage` does that), or a full description of any one skill (use `man <name>` patterns or read its SKILL.md directly).

## Flags

- (no flag) — list every installed `mikko-*` skill with its description. Default behavior; cheapest.
- `--detect` — also scan the current working directory's codebase shape (language, framework, security surface) and emit an ordered "which audit should I run here" recommendation alongside the listing. Adds ~10K tokens to the run.

## What this skill does

**Default mode (no flag):**

1. Glob `~/.claude/skills/mikko-*/SKILL.md` (user-wide skills).
2. Glob `.claude/skills/mikko-*/SKILL.md` relative to the current working directory (project-local skills).
3. For each path, read the first ~10 lines and extract the YAML frontmatter `name` and `description` fields.
4. Deduplicate by `name` (a skill installed both user-wide AND project-local appears once; the project-local copy wins, matching Claude Code's own resolution order).
5. Sort alphabetically.
6. Print a two-column table: name (green) + description-first-sentence (dim). Truncate descriptions longer than ~120 characters with an em-dash continuation.

**`--detect` mode (everything above, plus):**

7. Run the codebase-shape detection (see "`--detect` mode" section below).
8. Map detected signals to a recommendation list using the decision matrix.
9. Print the recommendation list AFTER the regular skill table, with one-line rationale per audit (why it's relevant here, or why it's being skipped).

End-to-end in one main-thread turn. No tools beyond `Glob` and `Read`. Output goes to the chat — nothing is written to disk.

## Output format

```
your installed mikko-* skills:

  mikko-audit            Run a multi-phase robustness audit of the current codebase…
  mikko-help             List every installed mikko-* skill with its one-line description.
  mikko-skill-registry   Walk every sibling repo under D:/koodaamista, find each .claude/…
  mikko-skill-usage      Measure actual Claude Code skill usage from local transcript JSONL…
  mikko-md-to-pdf        Render a markdown report (or any HTML) to a styled PDF using local…
  mikko-sync-readmes     Audit project data against sibling repos' READMEs and open a PR…

tip: `/mikko<Tab>` shows names only. For the cross-repo registry with token math, run `/mikko-skill-registry`.
```

Truncate descriptions at the first em-dash / period if shorter; otherwise hard-cap at 120 characters and append `…`. The goal is one-screen scannability, not full prose.

If both user-wide and project-local copies of the same skill exist, append `(project)` after the project-local one's name so the distinction is visible.

### `--detect` mode output

```
your installed mikko-* skills:

  mikko-audit                      Run a multi-phase robustness audit of the current codebase…
  mikko-ai-codegen-smell-audit     Read-only audit for ten LLM-codegen failure modes…
  mikko-help                       List every installed mikko-* skill with its description.
  mikko-react-anti-patterns-audit  Read-only audit for six React anti-patterns with a pre-flight fit check.
  mikko-security-audit             Multi-phase security audit + remediation, gated per phase.
  mikko-skill-usage                Measure actual Claude Code skill usage from local transcript JSONL.

detected codebase shape:
  • language: TypeScript + React (12 .tsx files, react in package.json)
  • framework: Astro (astro.config.mjs present)
  • testing: Vitest (vitest in devDependencies)
  • security surface: low (no auth/db/network deps detected)

suggested audits, in order:
  /mikko-react-anti-patterns-audit   → targets the React-specific layer (12 .tsx files)
  /mikko-ai-codegen-smell-audit      → universal LLM-codegen patterns, language-agnostic
  /mikko-audit                       → universal robustness audit, always useful

skipped:
  /mikko-security-audit              → low security surface detected; revisit if untrusted input is added
  /mikko-skill-usage                 → measurement skill, not an audit

tip: each suggestion is independent — invocations can be days/weeks apart.
```

## `--detect` mode

The detection pass is **fast and cheap** (~5K tokens) and produces a ranked list of which audit skills are most likely to find signal in the codebase Claude Code is currently rooted in. It deliberately doesn't run the audits — that's still the human's call. It just removes the "which one should I even start with?" friction.

### Detection signals

The detector reads up to ~5 files in the project root to fingerprint the codebase. It does NOT walk the source tree (that's each audit skill's own job):

| Signal | Reads | Detects |
| --- | --- | --- |
| `package.json` | dependencies + devDependencies | Node / JS / TS / React / React Native / Vue / Svelte / Next / Astro / Vite / framework versions; auth deps (`jsonwebtoken`, `passport`, `next-auth`); db deps (`pg`, `mongoose`, `sqlite3`, `drizzle-orm`); network/server (`express`, `fastify`, `hono`) |
| `tsconfig.json` (existence) | — | TypeScript layer |
| `pyproject.toml` / `requirements.txt` / `setup.py` | — | Python |
| `Cargo.toml` | — | Rust |
| `go.mod` | — | Go |
| `astro.config.mjs` / `next.config.{js,mjs,ts}` / `vite.config.{js,ts}` (existence) | — | Astro / Next.js / Vite (cross-checked with `package.json`) |
| `.eslintrc*` / `eslint.config.*` (existence) | — | Lint baseline present (suggests the linter already catches some patterns this skill's audits would otherwise duplicate) |
| `Glob` `*.{tsx,jsx,py,rs,go,vue,svelte}` (count) | — | File-extension density (used as secondary confirmation) |

### Decision matrix — which audits to suggest

| Detected shape | Suggested audits (in order) | Notes |
| --- | --- | --- |
| React (any flavor) | `react-anti-patterns-audit` → `ai-codegen-smell-audit` → `audit` | React-specific first because highest-signal-per-token |
| React Native | `react-anti-patterns-audit --force` → `ai-codegen-smell-audit` → `audit` | Five of six React checks apply; `--force` bypasses the web-shape pre-flight |
| TypeScript without React (Node API, CLI, library) | `audit` → `ai-codegen-smell-audit` | No framework-specific audit yet |
| Python | `audit` → `ai-codegen-smell-audit` | Universal-only; future `python-defensive-style-audit` would go first if it lands |
| Rust / Go | `audit` → `ai-codegen-smell-audit` | Same |
| Plain JS (no TS, no framework) | `audit` → `ai-codegen-smell-audit` | Universal-only |
| Unknown / mixed / no clear signal | `audit` | The safest fallback — runs on any source tree |
| Any of the above + security-sensitive deps detected | (above list) + `security-audit` | Auth / db / network deps lift `security-audit` from "skip" to "suggest" |

### What "security-sensitive" means

The detector flags a codebase as security-sensitive if `package.json` (or language equivalent) names any of:

- Auth libraries: `jsonwebtoken`, `passport`, `next-auth`, `iron-session`, `lucia`, `oauth4webapi`, `clerk-*`, `auth0-*`
- DB libraries: `pg`, `mongoose`, `sqlite3`, `drizzle-orm`, `prisma`, `kysely`, `typeorm`
- Server/network: `express`, `fastify`, `hono`, `koa`, `nestjs`, `tRPC`, `apollo-server`
- Crypto: `bcrypt`, `argon2`, `crypto-js`, `node-forge`

The list is intentionally conservative — a portfolio-rendering Astro site that imports `marked` for markdown is not security-sensitive; a Node API server with `express` + `pg` is. If your codebase has security surface that doesn't trigger any of these, that's still a fine reason to run `security-audit` — the detector is suggesting, not gatekeeping.

### What the detector does NOT do

- **Does not run audits.** It reads ~5 files, prints recommendations, and exits.
- **Does not walk the source tree.** Each audit skill walks its own scope; the detector is a hallway sign, not a tour guide.
- **Does not measure quality.** A codebase with many `.tsx` files isn't "more React than" one with few — the recommendation depends on whether the patterns apply, not how often.
- **Does not learn from history.** Each run starts fresh from the file signals. If you ran `mikko-audit` yesterday and it found nothing, `--detect` will still recommend it today because the recommendation is "this audit is relevant here," not "this audit hasn't fired yet."

## Procedure

### 1. Discover skills

```
Glob: ~/.claude/skills/mikko-*/SKILL.md
Glob: .claude/skills/mikko-*/SKILL.md   (relative to CWD)
```

Both globs are cheap. The user-wide path is platform-dependent — use `os.homedir()`-equivalent expansion (the `Glob` tool handles `~` on Unix; on Windows, expand `$USERPROFILE`/`$HOME` or use the absolute path explicitly).

### 2. Read frontmatter

For each matched `SKILL.md`, `Read` the first 10 lines. Parse the YAML frontmatter between the `---` delimiters. Extract `name` and `description`.

If the frontmatter is malformed or the file has none, fall back to the parent directory name as the `name` and `(no description)` as the description — log the skip in a `notes` section at the bottom of the output.

### 3. Format + print

Sort by name. Find the longest skill name (cap at 24 chars; longer names get truncated with `…`). Pad to that width + 4 spaces, then print the truncated description. Use `printHTML` style if rendering through a terminal that supports color; plain print otherwise.

### 4. Done

Print the tip line about `/mikko<Tab>` and `/mikko-skill-registry`, then exit. The whole skill should complete in under 5 seconds end-to-end.

## Token expectations

**Default mode** (no `--detect`), for ~6-10 installed skills:

- 1-2 × `Glob` (~0.5K each)
- 6-10 × `Read` of first 10 lines (~0.5K each input, ~3-5K total)
- 1 × format + print (~1-2K output)

Total: ~5-8K tokens per invocation. The cheapest skill in the catalog.

**`--detect` mode** adds:

- Up to 5 × `Read` of root-level config files (`package.json`, `tsconfig.json`, `pyproject.toml`, etc.) — ~3-5K input
- 3-5 × `Glob` to count file-extension density — ~1-2K
- 1 × matrix-mapping + formatted recommendation print — ~2-3K output

Total with `--detect`: ~10-15K tokens. Still cheap; the detection pass deliberately doesn't walk the source tree.

Cadence: ad-hoc, usually a few times per week when actively iterating. ~50 uses/year for a regular Claude Code user; lower if you have the names memorized. `--detect` mode used more sparingly — when first opening an unfamiliar repo or after `cd`'ing into a different consumer repo.

## Failure modes

- **No skills directory.** If neither `~/.claude/skills/` nor `.claude/skills/` exists, print "no mikko-* skills installed yet" and a hint to run `./install.sh --list` in a checked-out `claude-skills` clone. Exit cleanly.
- **YAML frontmatter parse failure.** Don't fail the whole run — fall back to dirname + "(no description)" and add a one-line note.
- **Symlinked skills.** When a skill is installed via `claude-skills/install.sh`, the directory is a symlink. `Glob` and `Read` follow symlinks transparently; nothing special needed.
- **Non-mikko-* skills in the same directory.** The glob filter excludes them. If the user wants to see Anthropic-shipped skills too, that's `/help` territory, not this skill.
- **`--detect` in a directory with no config files.** A plain `/tmp/scratch/` with one `.py` file and nothing else returns the "Unknown / mixed / no clear signal" row from the matrix. The recommendation is `audit` only. This is correct behavior, not a bug — the detector is honest about what it can and can't infer.
- **`--detect` in a polyglot monorepo.** A repo with both a Python backend AND a React frontend gets recommendations for both stacks. The output prints two grouped sections rather than collapsing into a single "polyglot" verdict — concrete is more useful than abstract here.

## Limitations

- **Description truncation loses detail.** Full descriptions can be hundreds of characters with multiple invocation triggers. The table view shows only the first ~120 chars. For the full description, open the SKILL.md directly (path is available in the table if rendered with file links).
- **Local-only view.** This skill only sees what's installed on the current machine. Cross-repo / cross-machine inventory is the `/mikko-skill-registry` job.
- **No token economics.** This is a name + description list, not a usage report. For tokens-per-use math, run `/mikko-skill-usage` then read the resulting JSON.
- **`--detect` is a heuristic, not a guarantee.** The decision matrix is opinionated — it picks the audits Mikko reaches for first on each codebase shape. Your priorities may differ. The recommendation is a "here's where I'd start" hallway sign, not a rule.
- **`--detect` doesn't dispatch audits.** It only suggests. The human still invokes each suggested audit by name. This is by design — skills are recipes, not orchestrators. A future "/mikko-audit-suite" skill could automate the dispatch loop, but that's a separate decision worth making explicitly rather than smuggling it into `mikko-help`.

## Why this skill exists

The `/mikko<Tab>` shortcut from Claude Code's built-in slash-completion already gives names. The gap that `mikko-help` fills is when you need **descriptions** to choose between two skills with similar names — or when you've installed a new skill and forgotten what it does without re-reading the SKILL.md.

For a portfolio audience: the skill exists as a discoverability anchor. A recruiter looking at `claude-skills/` sees that the `mikko-*` prefix has both a tab-complete-friendly grouping AND a built-in "what's in this namespace" command — that's a tiny but real signal of "the author thought about UX, not just function."
