---
name: mikko-install
description: Install, update, list, or uninstall `mikko-*` skills from the cloned `claude-skills` source repo into the user-wide skill directory (`~/.claude/skills/mikko-*`). Wraps the existing `install-mikko.sh` and `install.sh` scripts so the install loop is reachable from inside any Claude Code session via a slash command — no need to leave the conversation, find the repo, and run bash by hand. Use whenever the user says "install the mikko skills", "install everything", "add mikko-readme-drift-sync", "update my mikko skills", "what's new since last install", or "uninstall mikko-foo". Locates the source repo via the current working directory, parent directories, or known sibling locations (configurable). Does NOT clone the repo (the user clones it once, by hand). Does NOT touch skills outside the `mikko-*` prefix.
barney: Installs, updates, or removes mikko-* skills from the claude-skills source repo, without you having to leave the chat. Wraps install-mikko.sh / install.sh so you don't have to remember where they live.
---

# mikko-install

The slash-command face of the `claude-skills` installers. Reads `mikko-*` skills from a cloned source repo on disk and writes them into `~/.claude/skills/` via the repo's existing bash scripts. Lets you install / update / remove from inside any Claude Code session.

## When to invoke

- "install the mikko skills" / "install everything" — bulk install all `mikko-*` skills, mikko-prefixed.
- "install `<name>`" (e.g. "install readme-drift-sync", "install ai-codegen-smell-audit") — install one specific skill.
- "update my mikko skills" / "re-run the install" — after a `git pull` in the source repo, re-copy everything so installed copies match source.
- "what mikko skills are new since last install" / "anything new to install" — list source skills that aren't installed yet.
- "uninstall `mikko-foo`" / "remove `mikko-foo`" — delete the user-wide install of one skill.

## When NOT to invoke

- **Not** for cloning the source repo. The user clones `claude-skills` once, by hand. This skill assumes the clone already exists on disk.
- **Not** for non-`mikko-*` skills. Anthropic-shipped skills and skills under other namespaces are out of scope.
- **Not** for editing skill content. Edit the source repo and re-run install; never hand-edit the installed copy.
- **Not** for installing into a project (only user-wide is in scope here). For per-project install, use the underlying `./install.sh <name> --target project --repo <path>` directly — that's a different use case.

## Procedure

### 1. Locate the source repo

The source repo is the cloned `claude-skills` directory. The skill looks for it, in order:

1. **Current working directory** — if `cwd` contains `install-mikko.sh` AND a `skills/` directory, use cwd.
2. **Parent directory of cwd** — walk up two levels checking for the same markers (handles "I'm in `<repo>/some/sub/dir/`").
3. **Known sibling locations** — `D:/koodaamista/claude-skills/` on Windows, `~/koodaamista/claude-skills/` on Unix-likes. These are the canonical author-machine paths; harmless on a fresh checkout.
4. **Ask the user once** — if none of the above hit, ask: "Where's your claude-skills clone? (full path)". Bail with a clear message if no answer.

Once located, verify by checking that `<source>/install-mikko.sh` and `<source>/skills/*/SKILL.md` both exist. Cache the resolved path in the conversation context for the rest of the turn.

### 2. Map intent to action

The skill dispatches based on what the user asked for. Default to **install all** when intent is unclear.

| Intent | Action |
| --- | --- |
| "install everything" / "install the mikko skills" / "update my mikko skills" | `bash <source>/install-mikko.sh` |
| "what's new" / "list new skills" / "anything to install" | Glob source `skills/*/SKILL.md`, glob `~/.claude/skills/mikko-*/SKILL.md`, normalise names, diff. Print the source-but-not-installed names. |
| "install `<name>`" | `bash <source>/install.sh <name> --target user` (uses `install.sh`, not `install-mikko.sh`, so this is a SYMLINK install keeping the source name). Note this skips the `mikko-` prefix unless `<name>` already has it. |
| "install `<name>` with the mikko- prefix" | `cp -R <source>/skills/<name>/ ~/.claude/skills/mikko-<name>/` (mirrors what install-mikko.sh does for one skill) |
| "uninstall `mikko-<name>`" | Confirm with the user once, then `rm -rf ~/.claude/skills/mikko-<name>`. **Always confirm before deleting.** |
| "dry run" / "show me what would happen" | Add `--dry-run` to `install-mikko.sh`; for `install.sh` describe what would happen in chat without invoking. |

### 3. Execute the action

Run the bash command via the `Bash` tool. Capture stdout / stderr / exit code. On non-zero exit, print the error block to the user and bail — don't try to "fix" install failures from inside this skill.

### 4. Confirm + summarise

After a successful install, print a one-line summary:

```
installed N skill(s) into ~/.claude/skills/  (M new, K updated)
```

If the user requested "what's new" without installing, just print the list and stop — don't install on a list query.

### 5. Restart hint

End the run with: `Claude Code picks up new skills on the next conversation turn — no restart needed.` (Empirically true; the harness re-globs the skills dir each turn.)

## Output format

Default (install all):

```
mikko-install — source: D:/koodaamista/claude-skills

[install-mikko.sh output here]

installed 9 skill(s) into ~/.claude/skills/ (1 new, 8 updated)
```

"What's new":

```
mikko-install — source: D:/koodaamista/claude-skills

new skills available (not installed):
  mikko-readme-drift-sync
  mikko-foo  (if applicable)

run /mikko-install to add them.
```

Uninstall:

```
mikko-install — about to remove:
  ~/.claude/skills/mikko-foo

confirm? [y/N]
```

## What this skill does NOT do

- **Does not clone, fetch, or pull from a remote.** The user runs `git pull` in the source repo by hand. This skill reads from whatever's already on disk.
- **Does not edit installed skill content.** Source is the source of truth; the installed copy is downstream.
- **Does not touch skills outside the `mikko-*` prefix.** Anthropic-shipped skills (`init`, `review`, etc.) and other namespaces are invisible to this skill.
- **Does not double-prefix.** Source skills already starting with `mikko-` (like `mikko-help`, `mikko-audit-suite`, this skill itself) install as-is, not as `mikko-mikko-foo`. `install-mikko.sh` already handles that — the skill just delegates.
- **Does not auto-uninstall.** Removing a skill always asks for confirmation, even with explicit `--force` from the user.

## Failure modes

- **Source repo not found.** Probes the known locations; if nothing matches, asks the user once. If still nothing, exits with `error: can't find your claude-skills clone — pass the path explicitly.`
- **`install-mikko.sh` or `install.sh` missing from source.** Should never happen on a clean clone; if it does, the skill exits with `error: <source>/install-mikko.sh is missing — your clone might be partial. Re-clone or git pull.`
- **Permission denied writing to `~/.claude/skills/`.** Surface the underlying bash error; don't try to escalate privileges.
- **Symlink fails on Windows without Developer Mode (for `install.sh` per-skill).** `install.sh` symlinks; on Windows Git Bash with default settings, that may fall back to copy. `install-mikko.sh` copies by design — recommend `install-mikko.sh` on Windows when symlink-vs-copy doesn't matter.
- **Skill installed but not appearing as a slash command.** Tell the user: `Claude Code reads ~/.claude/skills/ each turn. If /<skill-name> still doesn't trigger, check that ~/.claude/skills/<name>/SKILL.md exists and the frontmatter has a name: field matching the directory.`

## Why this skill exists

The `claude-skills` repo ships with two bash installers (`install.sh`, `install-mikko.sh`) that work fine on the command line. They're not discoverable from inside a Claude Code conversation — to use them you have to (a) know they exist, (b) find the cloned repo, (c) `cd` there, (d) remember the flags, (e) run the script. Five steps no `/mikko-help` ever tells you about.

This skill closes that loop. Once installed (via `install-mikko.sh` one time on a fresh machine), `/mikko-install` lets you add the next skill, update everything after a `git pull`, or remove a skill — all without leaving the chat.

The chicken-and-egg of "you need install to install" is solved by `install-mikko.sh` being the bootstrap (one-time bash invocation), after which this skill is the steady-state installer (slash command from any session).

## Token expectations

~3–5K tokens per typical invocation:
- Source probe + verification: ~1K (Glob + existence checks)
- Action dispatch: ~1K (bash invocation + capture)
- Summary print: ~1K

Run `/mikko-skill-usage` for measured numbers after a few invocations.

Cadence: once at machine setup, then a handful of times per year when new skills land or you want to update.
