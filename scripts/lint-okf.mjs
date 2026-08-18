#!/usr/bin/env node
/**
 * lint-okf.mjs — validates a service's .okf against the Service Knowledge Standard.
 *
 * The standard calls the .okf "machine-parseable (YAML, schema: okf/1)". Nothing enforced
 * that, and 9 of 16 files across the fleet silently failed to parse — so the machine-readable
 * half of the standard was inert. This is the check that keeps it honest.
 *
 * Errors (fail the build):
 *   - the file does not parse as YAML
 *   - `schema` is not `okf/1`
 *   - `service.name` is missing
 *   - an `api` entry is not a mapping, or has neither `path` nor `route`
 * Warnings (reported, do not fail): standard sections that are absent.
 *
 * Usage: node lint-okf.mjs <file.okf> [more.okf ...]
 */
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const YAML = require('js-yaml');

// Service Knowledge Standard §2 — the sections a service .okf is expected to carry.
const EXPECTED = ['service', 'purpose', 'responsibilities', 'dependencies',
                  'data_model', 'api', 'invariants', 'migrations', 'coverage'];

let errors = 0;

for (const file of process.argv.slice(2)) {
  const before = errors;
  let doc;
  try {
    doc = YAML.load(readFileSync(file, 'utf8'));
  } catch (e) {
    const m = /line (\d+), column (\d+)/.exec(String(e.message ?? e));
    const line = m ? m[1] : 1;
    console.log(`::error file=${file},line=${line}::okf: not valid YAML — ${String(e.message ?? e).split('\n')[0]}`);
    errors++;
    continue;
  }

  if (doc === null || typeof doc !== 'object') {
    console.log(`::error file=${file},line=1::okf: top level must be a mapping`);
    errors++; continue;
  }
  if (doc.schema !== 'okf/1') {
    console.log(`::error file=${file},line=1::okf: schema must be "okf/1" (found ${JSON.stringify(doc.schema)})`);
    errors++;
  }
  if (!doc.service || typeof doc.service !== 'object' || !doc.service.name) {
    console.log(`::error file=${file},line=1::okf: service.name is required`);
    errors++;
  }
  if (Array.isArray(doc.api)) {
    doc.api.forEach((entry, i) => {
      if (entry === null || typeof entry !== 'object' || Array.isArray(entry)) {
        console.log(`::error file=${file},line=1::okf: api[${i}] is not a mapping — usually an unquoted value broke the flow mapping`);
        errors++;
      } else if (!entry.path && !entry.route) {
        console.log(`::error file=${file},line=1::okf: api[${i}] has neither "path" nor "route"`);
        errors++;
      }
    });
  }

  if (errors > before) continue;               // already reported — do not also claim ok
  const missing = EXPECTED.filter((k) => !(k in doc));
  const counts = ['api', 'data_model', 'invariants']
    .filter((k) => Array.isArray(doc[k]))
    .map((k) => `${k}=${doc[k].length}`)
    .join(' ');
  console.log(`  ok  ${file}  ${counts}${missing.length ? `   (no ${missing.join(', ')})` : ''}`);
}

console.log(`\nokf: ${errors ? `${errors} error(s)` : 'all files valid'}.`);
process.exit(errors ? 1 : 0);
