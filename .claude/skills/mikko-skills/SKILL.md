---
name: mikko-skills
description: List every installed `mikko-*` skill with a short plain-English (barney-style) description. Reads `~/.claude/skills/mikko-*/SKILL.md` (user-wide) and `.claude/skills/mikko-*/SKILL.md` (project-local) frontmatter; uses each skill's `barney:` field, falls back to a truncated `description` with a `(no barney)` tag when missing. Use whenever the user types `/mikko-skills`, asks "what mikko skills do I have", "list my skills", "remind me what's installed", or onboards a new machine. Pure inventory — does NOT install (that's `/mikko-install`), does NOT recommend (that's `/mikko-audit-suite`), does NOT guide the user (that's `/mikko-help`). One-screen output, no walls of text.
barney: Lists your mikko- skills with one-line plain-English descriptions. The "what do I have" answer. For "what should I run", use /mikko-help or /mikko-audit-suite.
---

# mikko-skills

Pure inventory. Prints every installed `mikko-*` skill with its barney-style one-liner. No install, no recommendation, no wizard.

## When to use

- `/mikko-skills`, "what mikko skills do I have", "list my skills"
- After a fresh `/mikko-install` run — sanity check that everything landed
- Before invoking another `mikko-*` skill, to confirm the exact name

## When NOT to use

- **Not** for the next-step guidance — `/mikko-help` does that.
- **Not** for installing — `/mikko-install`.
- **Not** for codebase-aware audit recommendations — `/mikko-audit-suite`.
- **Not** for full SKILL.md contents — open the file directly.

## Procedure

1. `Glob` `~/.claude/skills/mikko-*/SKILL.md` (user-wide) and `.claude/skills/mikko-*/SKILL.md` (project-local).
2. For each match, `Read` the first ~15 lines and parse the YAML frontmatter.
3. Extract `name` and `barney`. If `barney` is missing, fall back to the first sentence of `description` and tag the name with `(no barney)` so the gap is visible.
4. Deduplicate by `name`; project-local wins and gets `(project)` appended.
5. Sort alphabetically.
6. Print as below. One blank line between entries.

## Output format

```
your mikko-* skills:

  mikko-help
    The "what do I do next" answer. Two stages: install → skills.

  mikko-install
    Installs (or updates, or removes) mikko- skills from a cloned source repo.

  mikko-skills
    Lists your mikko- skills with one-line plain-English descriptions.

  ...  (more skills appear here after you install them)

tip: pick one and type its slash command. For the next-step guide, use /mikko-help.
```

Skill name on its own line, barney indented two spaces below. Long barney lines wrap at ~80 chars rather than truncating — barney is the payload, not a header.

## What this skill does NOT do

- Does not enumerate full descriptions — the barney is the only field shown. Read `SKILL.md` for the full contract.
- Does not detect codebase shape or recommend skills based on it.
- Does not install or modify any skill.
- Does not cache. Each invocation re-globs and re-reads.

## Failure modes

- **No skills installed.** Print `no mikko-* skills installed yet.` and a one-line hint: `Run /mikko-help to get started.` Exit cleanly.
- **Frontmatter parse failure.** Skip cleanly; print `<dirname>  (unreadable frontmatter)` instead.
- **Missing `barney:` field.** Show first sentence of `description` + `(no barney)` annotation. Don't infer a barney — that defeats the explicit-field design.

## Token expectations

One glob pair + N small reads + one formatted print. Cheap. Run `/mikko-skill-usage` for measured numbers. Cadence: a few times a week during active iteration, lower once names are memorized.

## Why this skill exists alongside `mikko-help`

`/mikko<Tab>` gives names only. `/mikko-help` gives next-step guidance with one recommended command. `/mikko-skills` gives the full inventory with descriptions. Three distinct jobs, three distinct skills — overlap was the problem the namespace had before this split.
