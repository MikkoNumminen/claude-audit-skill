#!/usr/bin/env node
// Smoke tests for install.mjs. Invokes the script as a subprocess against an
// isolated tmpdir source + target. No external test framework — plain Node,
// fail fast on first mismatch with a clear assertion message.
//
// Run with: node install.test.mjs
// Exits 0 on success, 1 on any failure.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const SCRIPT = path.join(path.dirname(fileURLToPath(import.meta.url)), 'install.mjs');

let passed = 0;
let failed = 0;

function assert(cond, msg) {
  if (!cond) throw new Error(`ASSERT FAILED: ${msg}`);
}

function test(name, fn) {
  try {
    fn();
    console.log(`  ok  ${name}`);
    passed++;
  } catch (err) {
    console.error(`  FAIL ${name}`);
    console.error(`       ${err.message}`);
    if (err.stack) console.error(err.stack.split('\n').slice(1, 4).join('\n'));
    failed++;
  }
}

function run(args, opts = {}) {
  const r = spawnSync('node', [SCRIPT, ...args], {
    encoding: 'utf8',
    cwd: opts.cwd ?? process.cwd(),
    env: { ...process.env, ...(opts.env ?? {}) },
  });
  return { code: r.status, stdout: r.stdout ?? '', stderr: r.stderr ?? '' };
}

function makeFixture() {
  // Build a throwaway source repo + target dir in a tmpdir.
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'mikko-install-test-'));
  const source = path.join(root, 'source');
  const target = path.join(root, 'target');
  const sourceSkills = path.join(source, '.claude', 'skills');
  fs.mkdirSync(sourceSkills, { recursive: true });
  fs.mkdirSync(target, { recursive: true });

  function addSkill(name, content = `---\nname: ${name}\n---\n# ${name}\n`) {
    const d = path.join(sourceSkills, name);
    fs.mkdirSync(d, { recursive: true });
    fs.writeFileSync(path.join(d, 'SKILL.md'), content);
  }
  addSkill('mikko-foo');
  addSkill('mikko-bar');

  return { root, source, target, addSkill, cleanup: () => fs.rmSync(root, { recursive: true, force: true }) };
}

// We force --method copy throughout so the tests work on Windows without
// Developer Mode. Symlink path is exercised lightly via the dry-run.

console.log('install.mjs smoke tests\n');

test('bad arg → exit 2', () => {
  const fx = makeFixture();
  try {
    const r = run(['--bogus'], { cwd: fx.root });
    assert(r.code === 2, `expected exit 2, got ${r.code}`);
    assert(/unknown arg/.test(r.stderr), `expected "unknown arg" in stderr, got: ${r.stderr}`);
  } finally { fx.cleanup(); }
});

test('--source not given, cwd has no siblings → exit 3', () => {
  const fx = makeFixture();
  try {
    const empty = path.join(fx.root, 'empty');
    fs.mkdirSync(empty);
    const r = run([], { cwd: empty });
    assert(r.code === 3, `expected exit 3, got ${r.code} (stderr: ${r.stderr})`);
  } finally { fx.cleanup(); }
});

test('fresh install (copy) installs both skills', () => {
  const fx = makeFixture();
  try {
    // Point --target user at an isolated dir via HOME override.
    const home = path.join(fx.root, 'fakehome');
    fs.mkdirSync(home);
    const env = process.platform === 'win32'
      ? { USERPROFILE: home, HOMEDRIVE: '', HOMEPATH: '' }
      : { HOME: home };
    const r = run(['--source', fx.source, '--target', 'user', '--method', 'copy'], { env });
    assert(r.code === 0, `expected exit 0, got ${r.code} (stderr: ${r.stderr})`);
    assert(fs.existsSync(path.join(home, '.claude', 'skills', 'mikko-foo', 'SKILL.md')),
      'mikko-foo not installed');
    assert(fs.existsSync(path.join(home, '.claude', 'skills', 'mikko-bar', 'SKILL.md')),
      'mikko-bar not installed');
    assert(/2 skills processed: 2 installed/.test(r.stdout),
      `expected "2 installed" in stdout, got: ${r.stdout}`);
    // Marker file written on copy
    assert(fs.existsSync(path.join(home, '.claude', 'skills', 'mikko-foo', '.mikko-install-source')),
      'marker file missing on copy install');
  } finally { fx.cleanup(); }
});

test('rerun after install → already-up-to-date', () => {
  const fx = makeFixture();
  try {
    const home = path.join(fx.root, 'fakehome');
    fs.mkdirSync(home);
    const env = process.platform === 'win32'
      ? { USERPROFILE: home, HOMEDRIVE: '', HOMEPATH: '' }
      : { HOME: home };
    run(['--source', fx.source, '--target', 'user', '--method', 'copy'], { env });
    const r2 = run(['--source', fx.source, '--target', 'user', '--method', 'copy'], { env });
    assert(r2.code === 0, `expected exit 0 on rerun, got ${r2.code}`);
    assert(/2 up-to-date/.test(r2.stdout), `expected "2 up-to-date", got: ${r2.stdout}`);
  } finally { fx.cleanup(); }
});

test('drifted target → would-overwrite (no --force)', () => {
  const fx = makeFixture();
  try {
    const home = path.join(fx.root, 'fakehome');
    fs.mkdirSync(home);
    const env = process.platform === 'win32'
      ? { USERPROFILE: home, HOMEDRIVE: '', HOMEPATH: '' }
      : { HOME: home };
    run(['--source', fx.source, '--target', 'user', '--method', 'copy'], { env });
    // Hand-edit the installed mikko-foo.
    fs.writeFileSync(path.join(home, '.claude', 'skills', 'mikko-foo', 'SKILL.md'),
      '---\nname: mikko-foo\n---\n# tampered\n');
    const r = run(['--source', fx.source, '--target', 'user', '--method', 'copy'], { env });
    assert(r.code === 0, `expected exit 0, got ${r.code}`);
    assert(/would-overwrite/.test(r.stdout), `expected "would-overwrite", got: ${r.stdout}`);
    assert(/1 skipped/.test(r.stdout), `expected "1 skipped", got: ${r.stdout}`);
    // Verify the hand-edit survived.
    const txt = fs.readFileSync(path.join(home, '.claude', 'skills', 'mikko-foo', 'SKILL.md'), 'utf8');
    assert(/tampered/.test(txt), 'hand-edit was silently overwritten');
  } finally { fx.cleanup(); }
});

test('--dry-run changes nothing', () => {
  const fx = makeFixture();
  try {
    const home = path.join(fx.root, 'fakehome');
    fs.mkdirSync(home);
    const env = process.platform === 'win32'
      ? { USERPROFILE: home, HOMEDRIVE: '', HOMEPATH: '' }
      : { HOME: home };
    const r = run(['--source', fx.source, '--target', 'user', '--method', 'copy', '--dry-run'], { env });
    assert(r.code === 0, `expected exit 0, got ${r.code}`);
    assert(/would install/.test(r.stdout), `expected "would install", got: ${r.stdout}`);
    assert(!fs.existsSync(path.join(home, '.claude', 'skills', 'mikko-foo')),
      'dry-run installed a skill it should not have');
    assert(!/next: run/.test(r.stderr), 'dry-run should not print "next:" hint');
  } finally { fx.cleanup(); }
});

test('--list with no skills installed', () => {
  const fx = makeFixture();
  try {
    const home = path.join(fx.root, 'fakehome');
    fs.mkdirSync(home);
    const env = process.platform === 'win32'
      ? { USERPROFILE: home, HOMEDRIVE: '', HOMEPATH: '' }
      : { HOME: home };
    const r = run(['--list', '--target', 'user'], { env });
    assert(r.code === 0, `expected exit 0, got ${r.code}`);
    assert(/no skills directory|no mikko-\* skills installed/.test(r.stdout),
      `expected empty-list message, got: ${r.stdout}`);
  } finally { fx.cleanup(); }
});

test('--list after install shows skills with their source', () => {
  const fx = makeFixture();
  try {
    const home = path.join(fx.root, 'fakehome');
    fs.mkdirSync(home);
    const env = process.platform === 'win32'
      ? { USERPROFILE: home, HOMEDRIVE: '', HOMEPATH: '' }
      : { HOME: home };
    run(['--source', fx.source, '--target', 'user', '--method', 'copy'], { env });
    const r = run(['--list', '--target', 'user'], { env });
    assert(r.code === 0, `expected exit 0, got ${r.code}`);
    assert(/mikko-foo/.test(r.stdout), `expected mikko-foo in list, got: ${r.stdout}`);
    assert(/mikko-bar/.test(r.stdout), `expected mikko-bar in list, got: ${r.stdout}`);
    assert(r.stdout.includes(fx.source), `expected source path in list output, got: ${r.stdout}`);
  } finally { fx.cleanup(); }
});

test('--uninstall without --only refuses (exit 2)', () => {
  const fx = makeFixture();
  try {
    const home = path.join(fx.root, 'fakehome');
    fs.mkdirSync(home);
    const env = process.platform === 'win32'
      ? { USERPROFILE: home, HOMEDRIVE: '', HOMEPATH: '' }
      : { HOME: home };
    const r = run(['--source', fx.source, '--target', 'user', '--uninstall'], { env });
    assert(r.code === 2, `expected exit 2, got ${r.code}`);
    assert(/refuses bulk uninstall/.test(r.stderr), `expected bulk-refusal msg, got: ${r.stderr}`);
  } finally { fx.cleanup(); }
});

test('--uninstall happy path (matched skill)', () => {
  const fx = makeFixture();
  try {
    const home = path.join(fx.root, 'fakehome');
    fs.mkdirSync(home);
    const env = process.platform === 'win32'
      ? { USERPROFILE: home, HOMEDRIVE: '', HOMEPATH: '' }
      : { HOME: home };
    run(['--source', fx.source, '--target', 'user', '--method', 'copy'], { env });
    const r = run(['--source', fx.source, '--target', 'user', '--uninstall', '--only', 'mikko-foo'], { env });
    assert(r.code === 0, `expected exit 0, got ${r.code} (stderr: ${r.stderr})`);
    assert(!fs.existsSync(path.join(home, '.claude', 'skills', 'mikko-foo')),
      'mikko-foo not removed');
    assert(fs.existsSync(path.join(home, '.claude', 'skills', 'mikko-bar')),
      'mikko-bar should still be installed');
  } finally { fx.cleanup(); }
});

test('--uninstall drifted skill refused without --force', () => {
  const fx = makeFixture();
  try {
    const home = path.join(fx.root, 'fakehome');
    fs.mkdirSync(home);
    const env = process.platform === 'win32'
      ? { USERPROFILE: home, HOMEDRIVE: '', HOMEPATH: '' }
      : { HOME: home };
    run(['--source', fx.source, '--target', 'user', '--method', 'copy'], { env });
    fs.writeFileSync(path.join(home, '.claude', 'skills', 'mikko-foo', 'SKILL.md'),
      '---\nname: mikko-foo\n---\n# drifted\n');
    const r = run(['--source', fx.source, '--target', 'user', '--uninstall', '--only', 'mikko-foo'], { env });
    assert(r.code === 0, `expected exit 0, got ${r.code}`);
    assert(/refused \(drift/.test(r.stdout), `expected drift-refused, got: ${r.stdout}`);
    assert(fs.existsSync(path.join(home, '.claude', 'skills', 'mikko-foo')),
      'drifted skill was removed without --force');
  } finally { fx.cleanup(); }
});

test('--uninstall --force on drift without TTY → exit 4', () => {
  const fx = makeFixture();
  try {
    const home = path.join(fx.root, 'fakehome');
    fs.mkdirSync(home);
    const env = process.platform === 'win32'
      ? { USERPROFILE: home, HOMEDRIVE: '', HOMEPATH: '' }
      : { HOME: home };
    run(['--source', fx.source, '--target', 'user', '--method', 'copy'], { env });
    fs.writeFileSync(path.join(home, '.claude', 'skills', 'mikko-foo', 'SKILL.md'),
      '---\nname: mikko-foo\n---\n# drifted\n');
    const r = run(
      ['--source', fx.source, '--target', 'user', '--uninstall', '--only', 'mikko-foo', '--force'],
      { env },
    );
    assert(r.code === 4, `expected exit 4 (auto-mode bypass refused), got ${r.code}`);
    assert(/auto-mode bypass refused/.test(r.stderr), `expected refusal msg, got: ${r.stderr}`);
    assert(fs.existsSync(path.join(home, '.claude', 'skills', 'mikko-foo')),
      'skill removed despite TTY refusal');
  } finally { fx.cleanup(); }
});

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
