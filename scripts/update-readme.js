#!/usr/bin/env node
// Regenerates the Available Skills table in README.md from SKILL.md frontmatters.
// Usage: node scripts/update-readme.js

import { readFileSync, writeFileSync, readdirSync, statSync } from 'fs';
import { join } from 'path';
import { fileURLToPath } from 'url';

const rootDir = new URL('..', import.meta.url).pathname;

/**
 * Minimal YAML frontmatter parser — handles quoted single-line values and
 * block scalars (> and >-) for the `name` and `description` fields.
 */
function parseFrontmatter(filePath) {
  const content = readFileSync(filePath, 'utf8');
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return null;

  const lines = match[1].split('\n');
  let name = null;
  let description = null;
  let inBlock = null; // 'name' | 'description' | null
  let blockLines = [];

  const finishBlock = () => {
    if (!inBlock) return;
    const value = blockLines.join(' ').replace(/\s+/g, ' ').trim();
    if (inBlock === 'name') name = value;
    if (inBlock === 'description') description = value;
    inBlock = null;
    blockLines = [];
  };

  for (const line of lines) {
    // New top-level key — finish any in-progress block
    if (/^\S/.test(line) && inBlock) finishBlock();

    const blockScalar = line.match(/^(name|description):\s*[>|]/);
    if (blockScalar) {
      inBlock = blockScalar[1];
      blockLines = [];
      continue;
    }

    const inlineName = line.match(/^name:\s*(.+)/);
    if (inlineName) {
      name = inlineName[1].replace(/^["']|["']$/g, '').trim();
      continue;
    }

    const inlineDesc = line.match(/^description:\s*(.+)/);
    if (inlineDesc) {
      description = inlineDesc[1].replace(/^["']|["']$/g, '').trim();
      continue;
    }

    // Continuation line for a block scalar
    if (inBlock && /^\s+/.test(line)) {
      blockLines.push(line.trim());
    }
  }

  finishBlock();
  return name && description ? { name, description } : null;
}

/** Return the first sentence of a description string. */
function firstSentence(text) {
  const m = text.match(/^.+?[.!?](?=\s|$)/);
  return (m ? m[0] : text.split('\n')[0]).trim();
}

// Collect skills from top-level directories that contain a SKILL.md
const skills = [];

for (const entry of readdirSync(rootDir)) {
  const skillPath = join(rootDir, entry, 'SKILL.md');
  try {
    statSync(skillPath); // throws if missing
  } catch {
    continue;
  }

  const parsed = parseFrontmatter(skillPath);
  if (parsed) {
    skills.push({
      dir: entry,
      name: parsed.name,
      description: firstSentence(parsed.description),
    });
  }
}

skills.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: 'base' }));

// Build the Markdown table
const rows = skills.map(s => `| [\`${s.name}\`](./${s.dir}/) | ${s.description} |`);
const table = ['| Skill | Description |', '| --- | --- |', ...rows].join('\n');

// Replace the marked region in README.md
const readmePath = join(rootDir, 'README.md');
const readme = readFileSync(readmePath, 'utf8');

const START = '<!-- skills-start -->';
const END = '<!-- skills-end -->';

if (!readme.includes(START) || !readme.includes(END)) {
  console.error(`README.md is missing ${START} / ${END} markers.`);
  process.exit(1);
}

const updated = readme.replace(
  new RegExp(`${START}[\\s\\S]*?${END}`),
  `${START}\n${table}\n${END}`,
);

writeFileSync(readmePath, updated);
console.log(`✓ Updated README.md with ${skills.length} skills`);
