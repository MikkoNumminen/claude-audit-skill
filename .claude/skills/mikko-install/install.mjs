#!/usr/bin/env node
// Install, update, or uninstall mikko-* skills from a claude-skills-style
// source repo into the user-wide or project-local Claude skill directory.
// Companion script for the `mikko-install` skill; see SKILL.md in this
// directory for the procedure that drives it.
//
// Per-skill comparison is directory-level: every file under the skill dir is
// hashed (SHA-256 of path+content, sorted, then concatenated and re-hashed)
// so we never silently clobber a hand-edited installed copy. A marker file
// `.mikko-install-source` records where each installed skill was installed
// from. No external npm dependencies.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import readline from 'node:readline';

function parseArgs(argv) {
  const out = {
    source: null,
    target: 'user',
    only: [],
    method: null, // resolved later
    uninstall: false,
    force: false,
    adopt: false,
    dryRun: false,
    list: false,
    help: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--source') out.source = argv[++i] ?? null;
    else if (a === '--target') out.target = argv[++i] ?? 'user';
    else if (a === '--only') out.only.push(argv[++i] ?? '');
    else if (a === '--method') out.method = argv[++i] ?? null;
    else if (a === '--uninstall') out.uninstall = true;
    else if (a === '--force') out.force = true;
    else if (a === '--adopt') out.adopt = true;
    else if (a === '--dry-run') out.dryRun = true;
    else if (a === '--list') out.list = true;
    else if (a === '-h' || a === '--help') out.help = true;
    else {
      console.error(`error: unknown arg ${a}`);
      process.exit(2);
    }
  }
  return out;
}

function printHelp() {
  console.log(`usage: node install.mjs [flags]

Install/update/uninstall mikko-* skills from a source repo.

Flags:
  --source PATH       source repo containing .claude/skills/mikko-*/
  --target user|project   user = ~/.claude/skills/, project = <cwd>/.claude/skills/  (default: user)
  --only NAME         restrict to one skill (repeatable)
  --method copy|symlink  default: copy on Windows, symlink elsewhere
  --uninstall         remove named skill(s) — requires --only
  --force             allow uninstall/update of hand-edited skill (interactive only)
  --adopt             claim and replace an unmanaged (no-marker) install
                      — interactive only unless combined with --force
  --dry-run           print actions, write nothing
  --list              show what's installed at the target

Exit codes:
  0 success
  2 bad args
  3 source not found
  4 auto-mode bypass refused
`);
}

function resolveTargetDir(target) {
  if (target === 'user') return path.join(os.homedir(), '.claude', 'skills');
  if (target === 'project') return path.join(process.cwd(), '.claude', 'skills');
  console.error(`error: --target must be "user" or "project", got "${target}"`);
  process.exit(2);
}

function probeSource(explicit) {
  if (explicit) {
    const abs = path.resolve(explicit);
    if (!fs.existsSync(path.join(abs, '.claude', 'skills'))) {
      console.error(`error: --source ${abs} does not contain .claude/skills/`);
      process.exit(3);
    }
    return abs;
  }
  // Probe cwd: does it have mikko-* sibling skills?
  const cwdSkillsDir = path.join(process.cwd(), '.claude', 'skills');
  if (fs.existsSync(cwdSkillsDir)) {
    const entries = fs.readdirSync(cwdSkillsDir);
    if (entries.some((n) => n.startsWith('mikko-') && fs.existsSync(path.join(cwdSkillsDir, n, 'SKILL.md')))) {
      return process.cwd();
    }
  }
  console.error('error: no --source given and could not auto-detect (cwd has no .claude/skills/mikko-*/SKILL.md siblings)');
  process.exit(3);
}

function listSourceSkills(sourceDir) {
  const skillsDir = path.join(sourceDir, '.claude', 'skills');
  if (!fs.existsSync(skillsDir)) return [];
  return fs
    .readdirSync(skillsDir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && d.name.startsWith('mikko-'))
    .map((d) => d.name)
    .filter((name) => fs.existsSync(path.join(skillsDir, name, 'SKILL.md')))
    .sort();
}

function walkFiles(rootDir) {
  // Returns sorted relative paths of all files (excluding the marker file).
  const out = [];
  function rec(rel) {
    const abs = path.join(rootDir, rel);
    const entries = fs.readdirSync(abs, { withFileTypes: true });
    for (const e of entries) {
      const relChild = rel ? path.join(rel, e.name) : e.name;
      if (e.isDirectory()) rec(relChild);
      else if (e.isFile()) {
        if (e.name === '.mikko-install-source') continue;
        out.push(relChild);
      }
    }
  }
  if (!fs.existsSync(rootDir)) return [];
  rec('');
  return out.sort();
}

function hashDir(rootDir) {
  // Stable directory hash: for each file (sorted by relative path), hash
  // sha256(relPath + "\0" + fileBytes); concatenate per-file hashes and
  // hash again. Path separators normalised to forward-slash for
  // cross-platform stability.
  if (!fs.existsSync(rootDir)) return null;
  const files = walkFiles(rootDir);
  const outer = crypto.createHash('sha256');
  for (const rel of files) {
    const inner = crypto.createHash('sha256');
    const normRel = rel.split(path.sep).join('/');
    inner.update(normRel);
    inner.update('\0');
    inner.update(fs.readFileSync(path.join(rootDir, rel)));
    outer.update(inner.digest());
  }
  return outer.digest('hex');
}

function readMarker(skillDir) {
  const p = path.join(skillDir, '.mikko-install-source');
  if (!fs.existsSync(p)) return null;
  try {
    return fs.readFileSync(p, 'utf8').trim();
  } catch {
    return null;
  }
}

function writeMarker(skillDir, sourceDir) {
  const p = path.join(skillDir, '.mikko-install-source');
  fs.writeFileSync(p, sourceDir + '\n', 'utf8');
}

function rmrf(p) {
  if (!fs.existsSync(p)) return;
  fs.rmSync(p, { recursive: true, force: true });
}

function copyDir(src, dst) {
  fs.mkdirSync(dst, { recursive: true });
  for (const e of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, e.name);
    const d = path.join(dst, e.name);
    if (e.isDirectory()) copyDir(s, d);
    else if (e.isFile()) fs.copyFileSync(s, d);
  }
}

function tryInstall(srcDir, dstDir, method) {
  // Returns the method actually used ('copy' or 'symlink').
  // Atomic-ish: stage the new install in a sibling tempdir, then swap.
  // If the copy fails partway, the original install is still intact.
  const parent = path.dirname(dstDir);
  fs.mkdirSync(parent, { recursive: true });

  if (method === 'symlink') {
    // Symlinks land at the final path directly (atomic on POSIX; on Windows
    // requires Developer Mode). On failure we fall through to copy.
    try {
      // Remove any existing entry before symlinking — symlinkSync won't replace.
      rmrf(dstDir);
      fs.symlinkSync(srcDir, dstDir, 'dir');
      return 'symlink';
    } catch (err) {
      console.error(`note: symlink failed (${err.code ?? err.message}) — falling back to copy`);
      // fall through to copy below
    }
  }

  // Copy path: write to a tempdir alongside the target, then atomically rename.
  const stageDir = path.join(parent, `.${path.basename(dstDir)}.tmp-${process.pid}-${Date.now()}`);
  rmrf(stageDir);
  try {
    copyDir(srcDir, stageDir);
    rmrf(dstDir);
    fs.renameSync(stageDir, dstDir);
  } catch (err) {
    // Best-effort cleanup of the staging dir; the original dstDir is untouched
    // because we haven't called rmrf on it yet if the copy itself failed.
    rmrf(stageDir);
    throw err;
  }
  return 'copy';
}

async function promptYesNo(question) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stderr });
  return new Promise((resolve) => {
    rl.question(question + ' [y/N] ', (ans) => {
      rl.close();
      resolve(/^y(es)?$/i.test(ans.trim()));
    });
  });
}

function isInteractive() {
  return Boolean(process.stdin.isTTY && process.stderr.isTTY);
}

function defaultMethod() {
  return process.platform === 'win32' ? 'copy' : 'symlink';
}

function pad(s, n) {
  return s.length >= n ? s : s + ' '.repeat(n - s.length);
}

async function runList(targetDir) {
  if (!fs.existsSync(targetDir)) {
    console.log(`mikko-install --list — target: ${targetDir}\n  (no skills directory yet)`);
    return 0;
  }
  const entries = fs
    .readdirSync(targetDir, { withFileTypes: true })
    .filter((d) => (d.isDirectory() || d.isSymbolicLink()) && d.name.startsWith('mikko-'))
    .map((d) => d.name)
    .sort();
  console.log(`mikko-install --list — target: ${targetDir}\n`);
  if (entries.length === 0) {
    console.log('  (no mikko-* skills installed)');
    return 0;
  }
  const maxLen = Math.max(...entries.map((n) => n.length));
  for (const name of entries) {
    const skillDir = path.join(targetDir, name);
    let kind = 'copy';
    let source;
    try {
      if (fs.lstatSync(skillDir).isSymbolicLink()) {
        kind = 'symlink';
        // Symlinks don't carry a marker file (the marker would land inside the
        // source repo). The link target itself IS the source pointer.
        try {
          source = fs.readlinkSync(skillDir);
        } catch {
          source = '(broken symlink)';
        }
      }
    } catch { /* ignore */ }
    if (kind === 'copy') {
      const marker = readMarker(skillDir);
      source = marker ?? '(no .mikko-install-source marker — manual install?)';
    }
    console.log(`  ${pad(name, maxLen + 2)} ${pad(kind, 8)} ${source}`);
  }
  console.log(`\n${entries.length} skill(s) installed.`);
  return 0;
}

async function runUninstall(args, sourceDir, targetDir, sourceSkills) {
  if (args.only.length === 0) {
    console.error('error: --uninstall requires --only NAME (refuses bulk uninstall)');
    process.exit(2);
  }
  console.log(`mikko-install --uninstall — target: ${targetDir}\n`);
  let removed = 0;
  let kept = 0;
  for (const name of args.only) {
    if (!name.startsWith('mikko-')) {
      console.log(`  ${pad(name, 32)} refused (not mikko-* prefixed)`);
      kept++;
      continue;
    }
    const dst = path.join(targetDir, name);
    if (!fs.existsSync(dst)) {
      console.log(`  ${pad(name, 32)} not installed`);
      continue;
    }
    // Compare against source if available.
    let drift = false;
    let reason = 'drift vs. source';
    if (sourceSkills.includes(name)) {
      const srcHash = hashDir(path.join(sourceDir, '.claude', 'skills', name));
      const dstHash = hashDir(dst);
      drift = srcHash !== dstHash;
    } else {
      drift = true;
      reason = 'no source to verify against';
    }
    if (drift && !args.force) {
      console.log(`  ${pad(name, 32)} refused (${reason} — re-run with --force)`);
      kept++;
      continue;
    }
    if (drift && args.force) {
      if (!isInteractive()) {
        console.error(`error: --force requested for ${name} but no TTY detected.`);
        console.error('auto-mode bypass refused — re-run in an interactive shell');
        process.exit(4);
      }
      const ok = await promptYesNo(`  ${name} (${reason}). Really remove?`);
      if (!ok) {
        console.log(`  ${pad(name, 32)} kept (user declined)`);
        kept++;
        continue;
      }
    }
    if (args.dryRun) {
      console.log(`  ${pad(name, 32)} would remove`);
    } else {
      rmrf(dst);
      console.log(`  ${pad(name, 32)} removed`);
    }
    removed++;
  }
  console.log(`\n${args.only.length} requested: ${removed} removed, ${kept} kept.`);
  return 0;
}

async function runInstall(args, sourceDir, targetDir, sourceSkills) {
  const method = args.method ?? defaultMethod();
  if (method !== 'copy' && method !== 'symlink') {
    console.error(`error: --method must be copy or symlink, got "${method}"`);
    process.exit(2);
  }
  let skills = sourceSkills;
  if (args.only.length > 0) {
    const missing = args.only.filter((n) => !sourceSkills.includes(n));
    if (missing.length > 0) {
      console.error(`error: --only includes skills not in source: ${missing.join(', ')}`);
      process.exit(2);
    }
    skills = args.only;
  }
  if (skills.length === 0) {
    console.log(`mikko-install — source: ${sourceDir}\n  (no mikko-* skills found)`);
    return 0;
  }
  if (!args.dryRun) fs.mkdirSync(targetDir, { recursive: true });

  console.log(`mikko-install — source: ${sourceDir}`);
  console.log(`             target: ${targetDir}`);
  console.log(`             method: ${method}${args.dryRun ? ' (dry-run)' : ''}\n`);

  const maxLen = Math.max(...skills.map((n) => n.length));
  let installed = 0;
  let updated = 0;
  let upToDate = 0;
  let skipped = 0;

  for (const name of skills) {
    const srcSkill = path.join(sourceDir, '.claude', 'skills', name);
    const dstSkill = path.join(targetDir, name);

    const srcHash = hashDir(srcSkill);
    const dstExists = fs.existsSync(dstSkill);
    let dstHash = null;
    if (dstExists) dstHash = hashDir(dstSkill);

    if (dstExists && srcHash === dstHash) {
      console.log(`  ${pad(name, maxLen + 2)} already-up-to-date`);
      upToDate++;
      continue;
    }

    if (dstExists && srcHash !== dstHash) {
      // Drift. Refuse silent overwrite.
      const marker = readMarker(dstSkill);
      const fromUs = marker !== null;

      // Marker-bearing drift: --force updates it.
      if (fromUs && args.force) {
        if (args.dryRun) {
          console.log(`  ${pad(name, maxLen + 2)} would update (drift, --force)`);
        } else {
          const used = tryInstall(srcSkill, dstSkill, method);
          if (used === 'copy') writeMarker(dstSkill, sourceDir);
          console.log(`  ${pad(name, maxLen + 2)} updated (${used}, was drifted)`);
        }
        updated++;
        continue;
      }

      // Unmanaged drift (no marker — pre-existing or manual install): --adopt
      // claims it. In auto-mode (no TTY) require --force too, mirroring the
      // uninstall flow — explicit user intent is needed because the existing
      // content may be hand-authored work the user wants to keep.
      if (!fromUs && args.adopt) {
        if (!isInteractive() && !args.force) {
          console.error(`error: --adopt requested for ${name} but no TTY detected.`);
          console.error('auto-mode bypass refused — re-run with --force or in an interactive shell');
          process.exit(4);
        }
        if (args.dryRun) {
          console.log(`  ${pad(name, maxLen + 2)} would adopt + replace (no marker)`);
        } else {
          const used = tryInstall(srcSkill, dstSkill, method);
          if (used === 'copy') writeMarker(dstSkill, sourceDir);
          console.log(`  ${pad(name, maxLen + 2)} adopted (${used}, replaced unmanaged install)`);
        }
        updated++;
        continue;
      }

      // Otherwise, refuse.
      const hint = fromUs ? '--force' : '--adopt (to claim unmanaged install)';
      console.log(`  ${pad(name, maxLen + 2)} would-overwrite (rerun with ${hint} or remove manually)`);
      skipped++;
      continue;
    }

    // Fresh install or marker-blessed update.
    if (args.dryRun) {
      console.log(`  ${pad(name, maxLen + 2)} would install (${method})`);
      installed++;
      continue;
    }
    const used = tryInstall(srcSkill, dstSkill, method);
    // Marker isn't applicable inside a symlinked dir (would write into source).
    if (used === 'copy') writeMarker(dstSkill, sourceDir);
    console.log(`  ${pad(name, maxLen + 2)} installed (${used})`);
    installed++;
  }

  console.log(
    `\n${skills.length} skills processed: ${installed} installed, ${updated} updated, ${upToDate} up-to-date, ${skipped} skipped.`,
  );
  // Print the next-step hint to stderr so the LLM driving the skill doesn't
  // mistake it for a command to auto-run. Skip on dry-run since nothing changed.
  if (!args.dryRun && installed + updated > 0) {
    console.error('\nnext: run /mikko-skills to see what is now available.');
  }
  return 0;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    printHelp();
    process.exit(0);
  }

  const targetDir = resolveTargetDir(args.target);

  if (args.list) {
    process.exit(await runList(targetDir));
  }

  const sourceDir = probeSource(args.source);
  const sourceSkills = listSourceSkills(sourceDir);

  if (args.uninstall) {
    process.exit(await runUninstall(args, sourceDir, targetDir, sourceSkills));
  }

  process.exit(await runInstall(args, sourceDir, targetDir, sourceSkills));
}

main().catch((err) => {
  console.error(`fatal: ${err.stack ?? err.message ?? err}`);
  process.exit(1);
});
