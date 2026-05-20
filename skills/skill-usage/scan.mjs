#!/usr/bin/env node
// Scan Claude Code transcript JSONL files for skill invocations and emit a
// per-skill measurement report. Companion script for the `skill-usage` skill;
// see SKILL.md in this directory for the procedure that drives it.
//
// The harness emits `attributionSkill: "<skill-name>"` on every assistant
// message inside a skill run. This script harvests that signal, deduplicates
// by `requestId`, groups invocations by `promptId`, and computes per-skill
// totals. No external npm dependencies.
//
// Usage:
//   node scan.mjs [--window-days N] [--projects-dir PATH] [--out PATH]
//
// Defaults:
//   --window-days 90
//   --projects-dir  ~/.claude/projects  (or %USERPROFILE%\.claude\projects on Windows)
//   --out  ./.claude/agent-verdicts/SKILL-USAGE-{YYYY-MM-DD}.json  (relative to CWD)
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

function parseArgs(argv) {
  const out = {
    windowDays: 90,
    projectsDir: path.join(os.homedir(), '.claude', 'projects'),
    outPath: null,
    help: false,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--window-days') out.windowDays = parseInt(argv[++i] ?? '', 10);
    else if (a === '--projects-dir') out.projectsDir = argv[++i] ?? out.projectsDir;
    else if (a === '--out') out.outPath = argv[++i] ?? null;
    else if (a === '-h' || a === '--help') out.help = true;
  }
  return out;
}

function printHelp() {
  console.log(`usage: node scan.mjs [--window-days N] [--projects-dir PATH] [--out PATH]

Scans ~/.claude/projects/*/*.jsonl + */subagents/*.jsonl, filters assistant
messages by the harness-emitted attributionSkill field, and writes a per-skill
measurement JSON.

Defaults:
  --window-days 90
  --projects-dir  <homedir>/.claude/projects
  --out           ./.claude/agent-verdicts/SKILL-USAGE-{date}.json (CWD-relative)
`);
}

function listJsonlFiles(projectsDir) {
  const files = [];
  if (!fs.existsSync(projectsDir)) return files;

  const projects = fs
    .readdirSync(projectsDir, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => path.join(projectsDir, d.name));

  for (const projPath of projects) {
    // root session files in the project dir
    const entries = fs.readdirSync(projPath, { withFileTypes: true });
    for (const e of entries) {
      if (e.isFile() && e.name.endsWith('.jsonl')) {
        files.push(path.join(projPath, e.name));
      }
    }
    // subagent sidechain files: <session>/subagents/*.jsonl
    for (const e of entries) {
      if (!e.isDirectory()) continue;
      const subAgentsDir = path.join(projPath, e.name, 'subagents');
      if (!fs.existsSync(subAgentsDir)) continue;
      for (const sf of fs.readdirSync(subAgentsDir)) {
        if (sf.endsWith('.jsonl')) {
          files.push(path.join(subAgentsDir, sf));
        }
      }
    }
  }
  return files;
}

function scanFile(filePath, records, counts) {
  let content;
  try {
    content = fs.readFileSync(filePath, 'utf8');
  } catch {
    counts.unreadable++;
    return;
  }
  const lines = content.split(/\r?\n/);
  for (const line of lines) {
    if (!line.trim()) continue;
    let obj;
    try {
      obj = JSON.parse(line);
    } catch {
      counts.malformed++;
      continue;
    }
    if (obj.type !== 'assistant') continue;
    if (!obj.attributionSkill) continue;
    if (!obj.message || !obj.message.usage) continue;
    if (!obj.requestId) continue;
    // Assistant messages don't carry `promptId`; the harness only emits it on
    // user / tool_result lines. We group invocations by (sessionId, skill)
    // for v1 — accurate for token totals and last-invoked timestamps, slight
    // undercount of invocation counts when the same skill runs twice in one
    // session. Acceptable trade-off; revisit by walking parentUuid chains
    // if invocation precision becomes load-bearing.
    records.push({
      skill: obj.attributionSkill,
      requestId: obj.requestId,
      sessionId: obj.sessionId ?? null,
      timestamp: obj.timestamp ?? null,
      usage: obj.message.usage,
    });
  }
}

function summarize(records, windowDays) {
  const cutoffMs = Date.now() - windowDays * 86_400_000;
  const inWindow = records.filter((r) => {
    const t = r.timestamp ? Date.parse(r.timestamp) : NaN;
    return Number.isFinite(t) && t >= cutoffMs;
  });

  // Dedupe by sessionId|requestId — the harness emits two adjacent assistant
  // lines per API call when a message has both thinking and tool_use blocks;
  // they share requestId and usage, so summing both would double-count.
  const seen = new Set();
  const unique = [];
  for (const r of inWindow) {
    const key = `${r.sessionId ?? ''}|${r.requestId}`;
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(r);
  }

  // Group by skill → sessionId → messages. Each (skill, sessionId) pair
  // counts as one invocation. See note in scanFile() about the undercount
  // when the same skill runs twice in one session.
  const bySkill = new Map();
  for (const r of unique) {
    let skillMap = bySkill.get(r.skill);
    if (!skillMap) {
      skillMap = new Map();
      bySkill.set(r.skill, skillMap);
    }
    const key = r.sessionId ?? '__unknown__';
    let list = skillMap.get(key);
    if (!list) {
      list = [];
      skillMap.set(key, list);
    }
    list.push(r);
  }

  const skills = [];
  for (const [skillName, invMap] of bySkill) {
    const invocations = invMap.size;
    let totalTokens = 0;
    let lastInvoked = '';
    const sessions = new Set();
    for (const msgs of invMap.values()) {
      let invTotal = 0;
      for (const m of msgs) {
        const u = m.usage;
        // Cost-bearing input + output. Excludes cache_read_input_tokens (a
        // cache hit, not a fresh cost). See SKILL.md "Token accounting
        // convention" for the rationale.
        invTotal +=
          (u.input_tokens ?? 0) +
          (u.output_tokens ?? 0) +
          (u.cache_creation_input_tokens ?? 0);
        if (m.sessionId) sessions.add(m.sessionId);
        if (m.timestamp && m.timestamp > lastInvoked) lastInvoked = m.timestamp;
      }
      totalTokens += invTotal;
    }
    const avgPerUse = invocations > 0 ? Math.round(totalTokens / invocations) : 0;
    const usesPerYear = Math.round((invocations / windowDays) * 365);
    skills.push({
      name: skillName,
      invocations,
      tokens_per_use_avg: avgPerUse,
      uses_per_year: usesPerYear,
      total_tokens_in_window: totalTokens,
      annual_total: avgPerUse * usesPerYear,
      sample_session_ids: [...sessions].slice(0, 5),
      last_invoked: lastInvoked || null,
    });
  }
  skills.sort((a, b) => b.annual_total - a.annual_total);
  return { skills, attributedDeduped: unique.length };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    printHelp();
    process.exit(0);
  }
  if (!Number.isFinite(args.windowDays) || args.windowDays <= 0) {
    console.error(`error: --window-days must be a positive integer, got ${args.windowDays}`);
    process.exit(2);
  }
  if (!args.outPath) {
    const date = new Date().toISOString().slice(0, 10);
    args.outPath = path.join('.claude', 'agent-verdicts', `SKILL-USAGE-${date}.json`);
  }

  if (!fs.existsSync(args.projectsDir)) {
    console.log(
      `skill-usage: projects dir not found at ${args.projectsDir} — nothing to scan.`,
    );
    process.exit(0);
  }

  const files = listJsonlFiles(args.projectsDir);
  if (files.length === 0) {
    console.log(`skill-usage: no JSONL files under ${args.projectsDir} — nothing to scan.`);
    process.exit(0);
  }

  const records = [];
  const counts = { malformed: 0, unreadable: 0 };
  for (const f of files) scanFile(f, records, counts);

  const { skills, attributedDeduped } = summarize(records, args.windowDays);

  const projectCount = fs
    .readdirSync(args.projectsDir, { withFileTypes: true })
    .filter((d) => d.isDirectory()).length;

  const output = {
    generated_at: new Date().toISOString(),
    window_days: args.windowDays,
    projects_scanned: projectCount,
    sessions_scanned: files.length,
    attributed_assistant_messages: attributedDeduped,
    skills,
  };

  const outAbs = path.resolve(args.outPath);
  fs.mkdirSync(path.dirname(outAbs), { recursive: true });
  const json = JSON.stringify(output, null, 2);
  fs.writeFileSync(outAbs, json);
  // Also write a SKILL-USAGE-LATEST.json sibling pointing at the same data.
  // Consumers like `/skill-registry`'s transcript-measurement overlay link to
  // a stable filename instead of having to lexicographic-sort dated files.
  // Byte-identical content; rewritten on every run so it always reflects the
  // freshest snapshot.
  const latestPath = path.join(path.dirname(outAbs), 'SKILL-USAGE-LATEST.json');
  fs.writeFileSync(latestPath, json);

  const totalInvs = skills.reduce((a, s) => a + s.invocations, 0);
  const totalTokens = skills.reduce((a, s) => a + s.total_tokens_in_window, 0);
  console.log(
    `Wrote ${outAbs} (+ ${latestPath}) — ${skills.length} skills (${totalInvs} invocations, ~${Math.round(totalTokens / 1000)}K total tokens) across ${files.length} sessions in ${args.windowDays} days.`,
  );
  if (counts.malformed > 0) console.log(`(skipped ${counts.malformed} malformed lines)`);
  if (counts.unreadable > 0) console.log(`(skipped ${counts.unreadable} unreadable files)`);
}

main();
