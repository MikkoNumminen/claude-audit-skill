---
name: mikko-help
description: List every installed `mikko-*` skill with its one-line description. The fast answer to "I know I have a skill for this but can't remember which one." Reads `~/.claude/skills/mikko-*/SKILL.md` frontmatter (plus any project-local `.claude/skills/mikko-*/SKILL.md`), extracts name + description, prints a single formatted table. No sub-agents, no network, no measurements — just a table.
---

# mikko-help

The discoverability sidekick for the `mikko-*` skill namespace. Type `/mikko-help` when you remember you have a skill for something but can't recall its exact name.

`/mikko<Tab>` from any Claude Code prompt already lists the *names* of every installed `mikko-*` skill (free, built into the CLI). `mikko-help` adds the **descriptions** so you can pick by what each one does, not just by name.

## When to use

- "/mikko-help", "what mikko skills do I have", "list my skills", "remind me what's installed"
- Onboarding a new machine after a `claude-skills` `./install.sh` run — quick verification that everything landed
- Before invoking another `mikko-*` skill, to confirm the exact name and what it expects

NOT for: cross-repo registry of skills (use `/mikko-skill-registry` for that — it walks sibling repos, this only reads the local skills directory), token-usage measurements (`/mikko-skill-usage` does that), or a full description of any one skill (use `man <name>` patterns or read its SKILL.md directly).

## What this skill does

1. Glob `~/.claude/skills/mikko-*/SKILL.md` (user-wide skills).
2. Glob `.claude/skills/mikko-*/SKILL.md` relative to the current working directory (project-local skills).
3. For each path, read the first ~10 lines and extract the YAML frontmatter `name` and `description` fields.
4. Deduplicate by `name` (a skill installed both user-wide AND project-local appears once; the project-local copy wins, matching Claude Code's own resolution order).
5. Sort alphabetically.
6. Print a two-column table: name (green) + description-first-sentence (dim). Truncate descriptions longer than ~120 characters with an em-dash continuation.

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

For ~6-10 installed skills:

- 1-2 × `Glob` (~0.5K each)
- 6-10 × `Read` of first 10 lines (~0.5K each input, ~3-5K total)
- 1 × format + print (~1-2K output)

Total: ~5-8K tokens per invocation. The cheapest skill in the catalog.

Cadence: ad-hoc, usually a few times per week when actively iterating. ~50 uses/year for a regular Claude Code user; lower if you have the names memorized.

## Failure modes

- **No skills directory.** If neither `~/.claude/skills/` nor `.claude/skills/` exists, print "no mikko-* skills installed yet" and a hint to run `./install.sh --list` in a checked-out `claude-skills` clone. Exit cleanly.
- **YAML frontmatter parse failure.** Don't fail the whole run — fall back to dirname + "(no description)" and add a one-line note.
- **Symlinked skills.** When a skill is installed via `claude-skills/install.sh`, the directory is a symlink. `Glob` and `Read` follow symlinks transparently; nothing special needed.
- **Non-mikko-* skills in the same directory.** The glob filter excludes them. If the user wants to see Anthropic-shipped skills too, that's `/help` territory, not this skill.

## Limitations

- **Description truncation loses detail.** Full descriptions can be hundreds of characters with multiple invocation triggers. The table view shows only the first ~120 chars. For the full description, open the SKILL.md directly (path is available in the table if rendered with file links).
- **Local-only view.** This skill only sees what's installed on the current machine. Cross-repo / cross-machine inventory is the `/mikko-skill-registry` job.
- **No token economics.** This is a name + description list, not a usage report. For tokens-per-use math, run `/mikko-skill-usage` then read the resulting JSON.

## Why this skill exists

The `/mikko<Tab>` shortcut from Claude Code's built-in slash-completion already gives names. The gap that `mikko-help` fills is when you need **descriptions** to choose between two skills with similar names — or when you've installed a new skill and forgotten what it does without re-reading the SKILL.md.

For a portfolio audience: the skill exists as a discoverability anchor. A recruiter looking at `claude-skills/` sees that the `mikko-*` prefix has both a tab-complete-friendly grouping AND a built-in "what's in this namespace" command — that's a tiny but real signal of "the author thought about UX, not just function."
