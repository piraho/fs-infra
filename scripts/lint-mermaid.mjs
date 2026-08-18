#!/usr/bin/env node
/**
 * lint-mermaid.mjs — compiles every ```mermaid fence in the given Markdown files.
 *
 * "Compiles" means mermaid's own parser accepts the source, so a diagram that passes
 * here is a diagram GitHub will render. Parse-only: no Chromium, no puppeteer.
 * Run it through scripts/check-mermaid.sh, which provisions mermaid + jsdom for it.
 *
 * Usage: node lint-mermaid.mjs <file.md> [more.md ...]
 * Exit:  0 = every fence compiled, 1 = at least one failed / no fences found where required.
 */
import { readFileSync } from 'node:fs';
import { JSDOM } from 'jsdom';

// mermaid sanitises labels through DOMPurify, which needs a real DOM even to parse.
const dom = new JSDOM('<!doctype html><html><body></body></html>', { pretendToBeVisual: true });
globalThis.window = dom.window;
globalThis.document = dom.window.document;
globalThis.Node = dom.window.Node;
globalThis.Element = dom.window.Element;
globalThis.HTMLElement = dom.window.HTMLElement;
Object.defineProperty(globalThis, 'navigator', { value: dom.window.navigator, configurable: true });

const mermaid = (await import('mermaid')).default;
mermaid.initialize({ startOnLoad: false, securityLevel: 'strict' });

// Diagram types GitHub's renderer is known to handle. Anything else is a portability risk:
// it may compile locally and still show as a grey error box in the GitHub UI.
const GITHUB_SAFE = new Set([
  'flowchart-v2', 'flowchart', 'graph', 'sequence', 'er', 'stateDiagram', 'class',
  'gantt', 'pie', 'journey', 'gitGraph', 'mindmap', 'timeline', 'quadrantChart', 'c4',
]);

const FENCE = /^[ \t]*```+[ \t]*mermaid[ \t]*$([\s\S]*?)^[ \t]*```+[ \t]*$/gm;

let files = process.argv.slice(2);
let total = 0, failed = 0;
const problems = [];

for (const file of files) {
  let text;
  try { text = readFileSync(file, 'utf8'); }
  catch { problems.push({ file, line: 0, msg: 'cannot read file' }); failed++; continue; }

  let m, found = 0;
  while ((m = FENCE.exec(text)) !== null) {
    found++; total++;
    const src = m[1];
    const line = text.slice(0, m.index).split('\n').length;   // 1-based line of the opening fence
    try {
      const { diagramType } = await mermaid.parse(src);
      if (!GITHUB_SAFE.has(diagramType)) {
        problems.push({ file, line, msg: `diagram type "${diagramType}" is not on the GitHub-safe list` });
        failed++;
      }
    } catch (e) {
      const msg = String(e?.message ?? e).split('\n').slice(0, 3).join(' / ');
      problems.push({ file, line, msg });
      failed++;
    }
  }
  if (found === 0) problems.push({ file, line: 0, msg: 'no ```mermaid fences found' , warn: true });
}

for (const p of problems) {
  const where = `${p.file}:${p.line}`;
  if (p.warn) console.log(`  warn  ${where}  ${p.msg}`);
  else console.log(`::error file=${p.file},line=${p.line}::mermaid: ${p.msg}`);
}
console.log(`\nmermaid: ${total - failed}/${total} diagram(s) compiled across ${files.length} file(s).`);
process.exit(failed ? 1 : 0);
