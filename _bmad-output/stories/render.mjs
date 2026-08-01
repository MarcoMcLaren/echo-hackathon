#!/usr/bin/env node
/**
 * Renders stories.json -> STORIES.md (human-readable board).
 *   node _bmad-output/stories/render.mjs
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const data = JSON.parse(readFileSync(resolve(here, 'stories.json'), 'utf8'));

const MARK = { done: '✅', blocked: '⛔', ready: '☐' };

export function issueBody(s, data) {
  const epic = data.epics.find((e) => e.key === s.epic);
  const lines = [
    `**Epic:** ${s.epic} — ${epic.name}`,
    `**Spec:** \`${data.spec}\`${s.cap ? ` · **${s.cap}**` : ''}`,
    `**Framework:** ${s.framework} · **Size:** ${s.size}`,
    '',
    s.context,
    '',
    '### Acceptance criteria',
    ...s.ac.map((a) => `- [ ] ${a}`),
  ];
  if (s.notes) lines.push('', `> ${s.notes}`);
  return lines.join('\n');
}

export function labelsFor(s) {
  const out = [`epic:${s.epic.toLowerCase()}`, `fw:${s.framework}`, `size:${s.size.toLowerCase()}`];
  if (s.status === 'blocked') out.push('blocked');
  if (s.status === 'done') out.push('done');
  return out;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const counts = { done: 0, blocked: 0, ready: 0 };
  for (const s of data.stories) counts[s.status]++;

  const out = [
    `# ${data.project} — stories`,
    '',
    `${data.stories.length} stories across ${data.epics.length} epics · ` +
      `${counts.done} done · ${counts.ready} ready · ${counts.blocked} blocked`,
    '',
    `Derived from \`${data.spec}\`. Edit \`stories.json\`, not this file.`,
    'Push to GitHub with `node _bmad-output/stories/create-issues.mjs`.',
    '',
  ];

  for (const e of data.epics) {
    const mine = data.stories.filter((s) => s.epic === e.key);
    out.push(`## ${e.key} — ${e.name}`, '', `_${e.goal}_`, '');
    for (const s of mine) {
      out.push(`### ${MARK[s.status]} ${s.id} — ${s.title}`, '');
      out.push(issueBody(s, data), '');
    }
  }

  writeFileSync(resolve(here, 'STORIES.md'), out.join('\n'));
  console.log(
    `STORIES.md written — ${data.stories.length} stories ` +
      `(${counts.done} done, ${counts.ready} ready, ${counts.blocked} blocked)`,
  );
}
