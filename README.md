# claude-skills

> A library of reusable [Claude Code](https://www.anthropic.com/claude-code) skills — small markdown files that teach Claude how to do specific jobs across any codebase. Drop a skill into a Claude Code skills directory, and from then on the recipe is part of Claude's vocabulary.

This repo started life as `claude-audit-skill` housing a single audit skill. It now hosts a small family of skills — mostly read-only audits, plus one cross-cutting measurement tool.

## What's in here

| Skill                                                                       | What it does                                                                                                                                                                                                                                  | Status    |
| --------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| [`audit`](skills/audit/SKILL.md)                                            | Multi-phase robustness audit. Five parallel sub-agents review the codebase across resource lifecycle, data integrity, concurrency, error paths, and external boundaries. Produces `docs/audits/audit-YYYY-MM-DD.md` with severity-ranked bugs. | shipped   |
| [`skill-usage`](skills/skill-usage/SKILL.md)                                | Measure actual Claude Code skill usage from local transcript JSONL files. Counts invocations and sums tokens per skill across all sessions in `~/.claude/projects/`. Emits a dated JSON that the portfolio's `/skill-registry` consumes as a receipt source. | shipped   |
| [`mikko-help`](skills/mikko-help/SKILL.md)                                  | Personal helper: lists every installed `mikko-*` skill with its one-line description. Solves "I know I have a skill for this but can't remember which one." Useful as-is for anyone adopting the `mikko-` namespace; fork-friendly otherwise (search-and-replace the prefix to brand for yourself). | shipped   |
| _planned: more audit variants (security, AI-codegen-smell, save-roundtrip)_ | port from the consumer repos where they currently live                                                                                                                                                                                        | upcoming  |

Each skill has its own SKILL.md with the full recipe — when to invoke, what it reads, what it writes, what it explicitly refuses to do. Read the SKILL.md to learn what a skill does; read [`docs/METHODOLOGY.md`](docs/METHODOLOGY.md) for the `audit` skill's design rationale specifically.

## What a "skill" is

If you've used [Claude Code](https://www.anthropic.com/claude-code) you already know. If not: Claude Code is a command-line assistant that can read and edit your code. A *skill* is a markdown file under `.claude/skills/<name>/SKILL.md` that teaches Claude Code how to do one specific job — like a recipe card. When you describe the job, Claude recognises the recipe and follows it.

This library is a collection of recipes you can install into any project.

## Install

Two installers, for two different intents:

### `install.sh` — one skill at a time, original name, symlinked

Best when you want a specific skill in a specific project, and you'd like `git pull` updates here to propagate automatically.

```bash
# install one skill into your user-wide Claude Code config
# (available in every project on your machine)
./install.sh audit --target user
./install.sh skill-usage --target user

# install one skill into a specific project repo
./install.sh audit --target project --repo /path/to/your/repo

# list available skills
./install.sh --list
```

After install, the skill is available as `/audit` (or `/skill-usage`, etc.) inside any Claude Code session whose project sees that skills directory. The script is idempotent — re-running just updates the symlink. It refuses to overwrite a non-symlink directory.

### `install-mikko.sh` — every skill at once, namespaced under a prefix, copied

Best when you want the whole library grouped under one slash-tab namespace (`/mikko<Tab>` for me; replace with your own).

```bash
# install every skill under ~/.claude/skills/mikko-<name>/  (the default)
./install-mikko.sh

# use a different prefix for someone else's namespace
./install-mikko.sh --prefix bobs-

# preview without writing
./install-mikko.sh --dry-run
```

Each library skill is **copied** (not symlinked) to `~/.claude/skills/<prefix><skill-name>/`, and the `SKILL.md` frontmatter's `name:` field is rewritten in the copy so Claude Code's skill listing matches the directory name. Skills already starting with the prefix (e.g. `mikko-help`) aren't double-prefixed. Re-running replaces the prior copies cleanly.

After this, typing `/mikko<Tab>` (or `/bobs<Tab>`) from any Claude Code prompt lists just your namespace's skills — handy when you've installed enough that the unprefixed `/` + Tab menu mixes them with built-ins.

Trade-off vs `install.sh`: copies don't auto-update with `git pull` here. To refresh, re-run `install-mikko.sh` (it's idempotent).

## Why split skills across multiple repos?

Three audiences:

1. **Me (Mikko)** — I want to maintain one canonical version of each audit skill rather than copy-pasted forks in every consumer repo. Symlinks let me edit once, propagate everywhere.
2. **My portfolio (`mikkonumminen.dev`)** — the site's contact-page terminal renders a registry of all my skills. The registry skill walks consumer repos for installed copies; this library is the source of truth they install from.
3. **Anyone else** — clone, run `./install.sh <name> --target user`, and you have the skill. No npm, no global state, no surprises.

The trade-off vs vendoring (copy-into-each-repo) is that consumer repos depend on this one being checked out somewhere. That's acceptable for a personal toolbox; less so if you're shipping skills as a published artifact. If you want copies instead of symlinks, replace `ln -s` with `cp -R` in `install.sh` — the rest of the structure stays the same.

## What's verifiable vs editorial

The audit skill produces real outputs (markdown reports, GitHub PRs) against real codebases. Its claims (severity counts, missed-pattern lists) are auditable from the resulting report. The `skill-usage` skill measures actual transcript data from Claude Code's local JSONL files — no synthetic estimates, no extrapolation.

What's **not** in this repo: a marketplace, a registry, or any kind of "ratings" claim. It's a small personal toolbox surfaced publicly because the recipes are reusable.

## Repo layout

```
.
├── README.md                      this file
├── LICENSE                        MIT
├── install.sh                     symlink installer for ONE skill at a time, original name
├── install-mikko.sh               copy-installer for ALL skills under a chosen prefix
├── docs/
│   ├── METHODOLOGY.md             the audit skill's design rationale
│   └── SKILLS.md                  per-skill token-economics catalog
└── skills/
    ├── audit/
    │   ├── SKILL.md               the audit recipe
    │   └── evals/                 sample inputs and gold outputs
    ├── skill-usage/
    │   ├── SKILL.md               the measurement recipe
    │   └── scan.mjs               companion script: scans ~/.claude/projects/*.jsonl
    └── mikko-help/
        └── SKILL.md               personal-namespace discoverability helper
```

## License

[MIT](LICENSE). Skills are markdown files; use them however you like.
