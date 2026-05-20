---
name: mikko-install
description: Install, update, or uninstall `mikko-*` skills from a `claude-skills`-style source repo into the user-wide skill directory (`~/.claude/skills/`) or a project-local one (`<repo>/.claude/skills/`). Copies each `.claude/skills/mikko-*/` directory from the source into the target; idempotent (re-running updates without duplicating). Use whenever the user says "install the mikko skills", "update my mikko skills", "install mikko-readme-drift-sync", "uninstall mikko-audit-suite", or after pulling fresh changes in a source repo. Does NOT clone the source repo (the user does that by hand); does NOT modify any skill that doesn't start with `mikko-`. Default install method is `copy` on Windows, `symlink` on macOS/Linux — explicit `--method copy|symlink` overrides.
barney: Installs (or updates, or removes) mikko- skills from a cloned source repo. One command, one skill, or all at once. Never touches anything that isn't mikko- prefixed.
---

# mikko-install

Manages installation of the `mikko-*` skill namespace. Reads skills from a source repo (a clone of `claude-skills` or similar) and writes them into Claude Code's skill directory.

The deterministic work lives in **`install.mjs`** in this skill directory. SKILL.md is the procedure that drives the script; the script does the file I/O, hashing, and safety checks. Do not re-implement the file operations in the main thread — invoke `node install.mjs` with the appropriate flags.

## When to use

- "install the mikko skills" / "install all mikko skills"
- "install `mikko-readme-drift-sync`" (specific skill)
- "update my mikko skills" (after `git pull` in the source repo)
- "uninstall `mikko-foo`"
- "what mikko skills are installed and from where"

## When NOT to use

- **Not** for cloning the source repo. User clones by hand; this skill assumes the clone exists on disk.
- **Not** for non-`mikko-*` skills. Other namespaces (e.g. Anthropic-shipped) are out of scope.
- **Not** for editing skill content. Update the source repo and re-run install; don't hand-edit the installed copy.

## Flags

- `--source PATH` — path to the source repo. If omitted, probe cwd for `.claude/skills/mikko-*/SKILL.md` siblings; if nothing found, bail with exit 3 and ask the user to pass `--source` explicitly. (No interactive prompt — the script is designed to work headless.)
- `--target user|project` — `user` → `~/.claude/skills/` (default). `project` → `<cwd>/.claude/skills/`.
- `--only NAME` — restrict to the named skill. Repeatable. Default: all `mikko-*` skills in source.
- `--method copy|symlink` — `copy` duplicates (default on Windows, safer without admin). `symlink` (default on macOS/Linux) picks up `git pull` updates automatically. On symlink failure (Windows without Developer Mode) the script falls back to copy and writes a one-line stderr note.
- `--uninstall` — remove the named skill(s). Requires `--only NAME` (refuses bulk uninstall).
- `--force` — required when uninstalling or overwriting a skill whose installed copy doesn't match the source. Interactive only — see "Auto-mode and --force" below.
- `--dry-run` — print what would happen, change nothing.
- `--list` — show what's installed at the target and which source each entry came from.

## Procedure

1. **Resolve source.** Use `--source` if set; else probe cwd for `.claude/skills/mikko-*/SKILL.md` siblings; else bail with exit 3 (the user re-runs with an explicit `--source PATH`).
2. **Resolve target.** `~/.claude/skills/` (default) or `<cwd>/.claude/skills/` per `--target`. Created on demand.
3. **Listing (`--list`).** Walk the target directory; for each `mikko-*` entry, read its `.mikko-install-source` marker file (written by previous installs) to report where it came from. Symlinks are reported as `symlink`; bare copies without a marker show `(no .mikko-install-source marker — manual install?)`. No source resolution required.
4. **Enumerate source skills.** `install.mjs` lists `<source>/.claude/skills/mikko-*/` directories that contain a `SKILL.md`.
5. **Filter** by `--only` if set; error out if any requested name isn't in the source.
6. **Per-skill directory-level comparison.** For each candidate, hash the entire skill directory (every file: `sha256(relpath + \0 + bytes)` per file, sorted by relpath, then hashed again) on both source and target side. The `.mikko-install-source` marker is excluded from the hash. If hashes match → `already-up-to-date`. If target exists with a different hash → `would-overwrite (rerun with --force or remove manually)` (never silently clobber). Otherwise install via the chosen method and write a fresh `.mikko-install-source` marker pointing at the source repo path.
7. **Report.** One line per skill + summary count of installed / updated / up-to-date / skipped.

## Uninstall

`--uninstall --only mikko-foo` removes the installed skill. If the installed copy's directory hash matches the source it's removed without ceremony. If it has drifted (or there's no matching source skill to compare against) the script refuses unless `--force` is also passed. See below.

## Auto-mode and `--force`

`--force` is needed for two situations: (a) overwriting a drifted installed skill on install/update, (b) uninstalling a drifted installed skill. In both cases:

- **Interactive shell** (TTY present): the script prompts `[y/N]` before proceeding.
- **Auto-mode** (no TTY, e.g. invoked headless by an orchestrator): the script refuses with exit code 4 and the message `auto-mode bypass refused — re-run in an interactive shell`. There is no env-var or flag to override; a hand-edited skill stays put until a human confirms.

## What this skill does NOT do

- Does not clone, fetch, or pull from a remote.
- Does not edit installed skill content.
- Does not touch skills outside the `mikko-*` prefix.
- Does not delete `docs/audits/` or other user artifacts. Uninstall removes the skill directory only.
- Does not validate `SKILL.md` content beyond directory hashing — trust your sources. A malicious source repo could ship a `SKILL.md` with prompt-injection content, which the harness would honor at use time. Only install from sources you trust.

## Failure modes and exit codes

- **`0` success** — including idempotent no-ops and dry runs.
- **`2` bad args** — unknown flag, bad `--target` value, `--uninstall` without `--only`, `--only` naming a skill not in source.
- **`3` source not found** — `--source` path missing or no auto-detected source; cwd has no `mikko-*` siblings.
- **`4` auto-mode bypass refused** — `--force` requested on a drifted skill without a TTY.
- **Symlink permission denied** (Windows without Developer Mode) — script falls back to copy with one-line stderr note. Exit 0.
- **Drifted installed copy** — reported as `would-overwrite`; user removes manually or passes `--force` in an interactive shell.
- **Malformed source frontmatter** — installed anyway (harness surfaces the parse error at use time); not separately flagged here.

## Output format

```
mikko-install — source: /path/to/claude-skills
             target: /home/user/.claude/skills
             method: symlink

  mikko-ai-codegen-smell-audit  installed (symlink)
  mikko-audit                   already-up-to-date
  mikko-help                    would-overwrite (rerun with --force or remove manually)
  mikko-install                 installed (symlink)
  mikko-skills                  installed (symlink)
  ...

N skills processed: X installed, Y updated, Z up-to-date, W skipped.

next: run /mikko-skills to see what is now available.
```

## Token expectations

Most of the work is in `install.mjs` (file I/O, ~50ms–2s wall-clock for ~10 skills). Main-thread LLM tokens: ~2–3K for arg validation + output summary. Run `/mikko-skill-usage` for measured numbers after this skill has been used a few times.
