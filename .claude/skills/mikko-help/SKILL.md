---
name: mikko-help
description: Onboarding wizard for the `mikko-*` skill namespace. Detects the user's current stage (nothing installed → install stage; some installed → skills stage) and prints a short barney-style guide pointing to the next step. Does NOT list skills (that's `/mikko-skills`); does NOT install (that's `/mikko-install`); does NOT recommend audits for the current codebase (that's `/mikko-audit-suite`). Use whenever the user says "help", "mikko help", "I'm new here", "what do I do next", "how do I get started with mikko skills", or types `/mikko-help` directly. Always exits with a single concrete next-step command the user can run.
barney: The "what do I do next" answer. Looks at what you have installed and tells you the next step in plain English. Two stages: install → skills. Always ends with one command to run.
---

# mikko-help

A two-stage onboarding wizard. Reads the machine's current state, decides which stage the user is in, prints a short barney-style guide, and ends with exactly one command to run next.

## The two stages

| Stage | Detected by | Next step |
| --- | --- | --- |
| **0 — install** | No `mikko-*` skills found under `~/.claude/skills/` or `<cwd>/.claude/skills/` | `/mikko-install` |
| **1 — skills** | At least one `mikko-*` skill is installed somewhere | `/mikko-skills` |

That's it. There is no stage 2 in this skill — once you know what's installed, you pick a skill and run it. `mikko-help` is the door, not the corridor.

## When to use

- `/mikko-help`, "help", "mikko help"
- "I'm new here", "how do I get started", "what do I do next"
- After a fresh machine setup, before any mikko skills are installed
- When something feels off and you want a sanity check on the state

## When NOT to use

- **Not** for listing installed skills — that's `/mikko-skills`.
- **Not** for installing — that's `/mikko-install`.
- **Not** for recommending audits for the current codebase — that's `/mikko-audit-suite`.
- **Not** as a tutorial for any specific skill — read that skill's `SKILL.md` directly.

## Procedure

1. **Detect stage.**
   - `Glob` `~/.claude/skills/mikko-*/SKILL.md` (user-wide).
   - `Glob` `.claude/skills/mikko-*/SKILL.md` (project-local, relative to cwd).
   - If both globs return zero results → **Stage 0**.
   - Otherwise → **Stage 1**.

2. **Print the stage-appropriate guide.** See "Output format" below. Keep it short — under 10 lines of prose total.

3. **End with exactly one command** the user can run. This is the load-bearing line; everything else is context.

4. **Stop.** No listing, no recommendations, no follow-on questions. The user types the next command when ready.

## Output format

### Stage 0 — nothing installed yet

```
You don't have any mikko- skills installed yet. They live in a separate
git repo you clone once, then install with one command.

Steps:
  1. Clone the `claude-skills` repo (or whichever repo you got these
     skills from). Canonical default: github.com/MikkoNumminen/claude-skills
     — swap in your fork's URL if you have one.
  2. cd into it (or anywhere)
  3. Run the installer skill:

next: /mikko-install --source <path-to-cloned-repo>

The installer copies every mikko-*/ skill into ~/.claude/skills/.
After it finishes, run /mikko-help again — it'll point you to /mikko-skills.
```

### Stage 1 — at least one mikko-* skill installed

```
You've got N mikko- skill(s) installed (M user-wide, P project-local).

next: /mikko-skills

That prints the full list with a plain-English line per skill, so you
can pick the one you need. From there, run the skill's own slash
command (e.g. /mikko-audit, /mikko-readme-drift-sync).

If you just pulled fresh changes in the source repo, /mikko-install
will update everything in place.
```

The N / M / P numbers are filled in from the glob results. If P is 0 the project-local clause is dropped; same for M.

## What this skill does NOT do

- **Does not enumerate skills by name.** Stage 1 says "you have N" — for the list, the user runs `/mikko-skills`. This is the boundary that makes `mikko-help` short and stays out of `mikko-skills`'s territory.
- **Does not install anything.** Stage 0 tells the user the install command; it doesn't run it. (Even if the source repo is sitting in the cwd, the user has to confirm by invoking `/mikko-install` themselves.)
- **Does not detect codebase shape.** Recommending audits ("you're in a React repo, try `/mikko-react-anti-patterns-audit`") is `/mikko-audit-suite`'s job.
- **Does not remember state between runs.** Each invocation re-detects from scratch. No cache, no config file.

## Token expectations

Two globs + one short formatted print. The cheapest skill in the namespace by design. Run `/mikko-skill-usage` for measured numbers.

Cadence: a handful of times during onboarding, then almost never. Long-time users won't type `/mikko-help` because they know what comes next; they go straight to `/mikko-skills` or the specific skill they need.

## Failure modes

- **`~/.claude/` doesn't exist.** Either Claude Code has never run on this machine, or the user is in a sandbox. Treat as Stage 0; the install command still applies.
- **Globs return only the three meta-skills (`mikko-help`, `mikko-install`, `mikko-skills`) with no audit or work skills.** Effectively-Stage-0: the user has the plumbing but none of the actual tools. Treat as Stage 0 and add a one-line note: "(only meta-skills installed — run /mikko-install --source <path> to add the audit skills.)"
- **A SKILL.md is malformed.** Skip it silently in the count; this skill doesn't parse frontmatter beyond the existence check.

## Why two stages, not more

A real-life onboarding has many steps: clone, install, list, pick a skill, read its SKILL.md, run it, read the report, fix something. Compressing that into one wizard would be a chatbot, not a skill. The two stages here are the only two that this skill *can* unambiguously detect — anything past stage 1 depends on what the user wants to do, and that's their decision, not the wizard's.
