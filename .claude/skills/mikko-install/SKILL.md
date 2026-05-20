---
name: mikko-install
description: Install, update, or uninstall `mikko-*` skills from a `claude-skills`-style source repo into the user-wide skill directory (`~/.claude/skills/`) or a project-local one (`<repo>/.claude/skills/`). Copies each `.claude/skills/mikko-*/` directory from the source into the target; idempotent (re-running updates without duplicating). Use whenever the user says "install the mikko skills", "update my mikko skills", "install mikko-readme-drift-sync", "uninstall mikko-audit-suite", or after pulling fresh changes in a source repo. Does NOT clone the source repo (the user does that by hand); does NOT modify any skill that doesn't start with `mikko-`. Default install method is `copy` on Windows, `symlink` on macOS/Linux — explicit `--method copy|symlink` overrides.
barney: Installs (or updates, or removes) mikko- skills from a cloned source repo. One command, one skill, or all at once. Never touches anything that isn't mikko- prefixed.
---

# mikko-install

Manages installation of the `mikko-*` skill namespace. Reads skills from a source repo (a clone of `claude-skills` or similar) and writes them into Claude Code's skill directory.

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

- `--source PATH` — path to the source repo. If omitted, search: (1) cwd, (2) `D:/koodaamista/claude-skills/` on Windows or `~/koodaamista/claude-skills/` on Unix, (3) prompt.
- `--target user|project` — `user` → `~/.claude/skills/` (default). `project` → `<cwd>/.claude/skills/`.
- `--only NAME` — restrict to the named skill. Repeatable. Default: all `mikko-*` skills in source.
- `--method copy|symlink` — `copy` duplicates (default on Windows, safer without admin). `symlink` (default on macOS/Linux) picks up `git pull` updates automatically. On Windows `symlink` requires Developer Mode.
- `--uninstall` — remove the named skill(s). Requires `--only NAME` (refuses bulk uninstall).
- `--dry-run` — print what would happen, change nothing.
- `--list` — show what's installed and where each one came from.

## Procedure

1. **Resolve source.** Use `--source` if set; else probe known locations; else ask once and bail if no answer.
2. **Enumerate.** `Glob` `<source>/.claude/skills/mikko-*/SKILL.md`. The containing dir is one installable unit.
3. **Filter by `--only`** if set.
4. **Resolve target.** `~/.claude/skills/` or `<cwd>/.claude/skills/`. Create if missing.
5. **Per skill**: if target exists and matches source (symlink to it, or copy with identical SKILL.md), report `already-up-to-date`. If target exists but differs, report `skipped (would overwrite — remove manually first)`. Otherwise install via chosen method.
6. **Report.** One line per skill + summary count.

## Uninstall

`--uninstall --only mikko-foo` removes the installed skill. Refuses unless the target is (a) a symlink to a known source or (b) a copy whose `SKILL.md` matches the source — protects against deleting a hand-edited local skill. Override with `--force` (the skill asks for confirmation; no auto-mode bypass).

## What this skill does NOT do

- Does not clone, fetch, or pull from a remote.
- Does not edit installed skill content.
- Does not touch skills outside the `mikko-*` prefix.
- Does not delete `docs/audits/` or other user artifacts. Uninstall removes the skill directory only.

## Failure modes

- **Source not found.** Probes known locations; if none, asks once. If still nothing, exits with "I need a `--source PATH`".
- **Target exists as a non-symlink, non-copy directory.** Refuses to overwrite. User removes/renames by hand, then re-runs.
- **Symlink permission denied on Windows.** Falls back to copy with one-line note ("symlink failed — using copy. Enable Developer Mode for live updates.").
- **Malformed source frontmatter.** Installs anyway (harness surfaces the parse error), but flags in the report: `installed mikko-foo (warning: frontmatter parse failed at line N)`.

## Output format

```
mikko-install — source: D:/koodaamista/claude-skills

  mikko-ai-codegen-smell-audit     installed (copy)
  mikko-audit                       installed (copy)
  mikko-help                        installed (copy)
  mikko-install                     installed (copy)
  mikko-skills                       installed (copy)
  ...

N skills processed: X installed, Y updated, Z up-to-date, W skipped.

next: run /mikko-skills to see what's now available.
```

## Token expectations

~3–5K tokens per run. Cadence: a handful per machine per year (initial, occasional updates, rare uninstalls).
