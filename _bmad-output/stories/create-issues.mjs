#!/usr/bin/env node
/**
 * Creates GitHub issues from stories.json via the gh CLI.
 *
 *   node _bmad-output/stories/create-issues.mjs --dry-run     # print, create nothing
 *   node _bmad-output/stories/create-issues.mjs               # create labels + issues
 *   node _bmad-output/stories/create-issues.mjs --project 3   # also add each to a project
 *   node _bmad-output/stories/create-issues.mjs --skip-done   # omit already-finished stories
 *
 * Requires: gh (winget install GitHub.cli), then `gh auth login`.
 * Creating issues is irreversible-ish — run --dry-run first.
 */
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { issueBody, labelsFor } from './render.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const data = JSON.parse(readFileSync(resolve(here, 'stories.json'), 'utf8'));

const argv = process.argv.slice(2);
const dryRun = argv.includes('--dry-run');
const skipDone = argv.includes('--skip-done');
const projectIdx = argv.indexOf('--project');
const project = projectIdx >= 0 ? argv[projectIdx + 1] : null;

const LABEL_COLORS = {
  'fw:rn': '61dafb', 'fw:flutter': '02569b', 'fw:both': '8250df',
  blocked: 'b60205', done: '0e8a16',
  'size:s': 'c2e0c6', 'size:m': 'fef2c0', 'size:l': 'f9d0c4',
};
const EPIC_COLOR = '1d76db';

function gh(args) {
  if (dryRun) { console.log('  gh ' + args.join(' ')); return ''; }
  return execFileSync('gh', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}

// A dry run prints commands and touches nothing, so it must work without gh installed.
if (!dryRun) {
  try {
    execFileSync('gh', ['--version'], { stdio: 'ignore' });
  } catch {
    console.error('gh CLI not found. Install it (winget install GitHub.cli), then `gh auth login`.');
    console.error('Or preview with: node _bmad-output/stories/create-issues.mjs --dry-run');
    process.exit(1);
  }
}

const stories = skipDone ? data.stories.filter((s) => s.status !== 'done') : data.stories;

console.log(`${dryRun ? 'DRY RUN — ' : ''}${stories.length} issues\n`);

// --- labels -------------------------------------------------------------
console.log('Labels:');
const labels = new Set();
for (const s of stories) labelsFor(s).forEach((l) => labels.add(l));
for (const l of [...labels].sort()) {
  const color = LABEL_COLORS[l] ?? EPIC_COLOR;
  const epic = l.startsWith('epic:')
    ? data.epics.find((e) => e.key.toLowerCase() === l.slice(5))
    : null;
  try {
    gh(['label', 'create', l, '--color', color, '--description',
        epic ? `${epic.key} — ${epic.name}` : l, '--force']);
    if (!dryRun) console.log(`  ok ${l}`);
  } catch (e) {
    console.error(`  FAILED ${l}: ${String(e.stderr ?? e).trim().split('\n')[0]}`);
  }
}

// --- issues -------------------------------------------------------------
console.log('\nIssues:');
let created = 0;
for (const s of stories) {
  const args = [
    'issue', 'create',
    '--title', `${s.id} — ${s.title}`,
    '--body', issueBody(s, data),
  ];
  for (const l of labelsFor(s)) args.push('--label', l);
  if (project) args.push('--project', project);

  try {
    const out = gh(args);
    created++;
    console.log(`  ${s.id.padEnd(7)} ${dryRun ? '(dry run)' : out.trim()}`);
  } catch (e) {
    console.error(`  ${s.id.padEnd(7)} FAILED: ${String(e.stderr ?? e).trim().split('\n')[0]}`);
  }
}

console.log(`\n${dryRun ? 'Would create' : 'Created'} ${created}/${stories.length} issues.`);
if (dryRun) console.log('Re-run without --dry-run to create them.');
