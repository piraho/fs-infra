# Architecture Documentation Standard

Every repo on the platform carries a root **`ARCHITECTURE.md`**: one page that answers *what this repo is
responsible for, what it is made of, how data is shaped, and how a request actually moves through it* —
in diagrams, not paragraphs. It renders natively on GitHub and every diagram in it is **compiled in CI**.

This is the visual companion to the [Service Knowledge Standard](./SERVICE-KNOWLEDGE-STANDARD.md).
Same discipline, different medium.

| File | Audience | Answers |
|------|----------|---------|
| `README.md` | human | How do I build, run, and operate it? |
| `<service>.md` | human + AI | What is it, in prose? |
| `<service>.okf` | AI / tools | What are the machine-checkable facts? |
| **`ARCHITECTURE.md`** | **human + AI** | **What shape is it? How does it fit, decompose, store, and flow?** |

## 1. Required sections

Every `ARCHITECTURE.md` has these, in this order. A section that genuinely does not apply is kept with an
explicit *"Not applicable — <reason>"* line, never silently dropped: an absent ER diagram must be a
statement that the service is stateless, not an omission the reader has to guess about.

| # | Section | Diagram | Required when |
|---|---------|---------|---------------|
| 1 | **Responsibility** | — | always. What it owns, and the lines it does not cross. |
| 2 | **System context** | `flowchart` | always. The repo as one box, its callers, callees, and datastores. |
| 3 | **Component structure** | `flowchart` | always. Internal layers — edge → controller → service → repository → store. |
| 4 | **Data model** | `erDiagram` | whenever the repo owns a schema. Tables, keys, real cardinalities. |
| 5 | **Request flows** | `sequenceDiagram` | always. The 2–4 flows that carry the service's actual value. |
| 6 | **State machines** | `stateDiagram-v2` | whenever a row has a lifecycle column (status, level, state). |
| 7 | **Failure modes & invariants** | — | always. What breaks, what must never be violated, linked to `CON-*` ids. |
| 8 | **Change protocol** | — | always. Which diagram to redraw when which file changes. |

## 2. Diagram rules

**GitHub-safe types only.** `flowchart`, `sequenceDiagram`, `erDiagram`, `stateDiagram-v2`, `classDiagram`,
`gantt`, `pie`, `journey`, `mindmap`, `timeline`, `quadrantChart`, `gitGraph`. The linter rejects anything
else, because a type GitHub cannot render is a grey error box no matter how well it parses locally.

**Legible on a phone.** Diagrams are read in PR review on small screens. Prefer `flowchart LR` for context
(wide, shallow) and `flowchart TB` for layering (narrow, deep). Past ~25 nodes, split into two diagrams.

**No colour as the only signal.** Style is welcome, but the meaning must survive greyscale and colour
blindness — put it in the label or the arrow, not only in a fill.

**Diagrams state facts, not aspirations.** A box that does not exist in the code does not go in the diagram.
Planned work is written in prose and marked *planned*, never drawn as though it shipped. When a diagram and
the code disagree, the diagram is the bug.

**Label every edge.** An unlabelled arrow is a guess. `A -->|POST /v1/sessions| B` is worth five sentences.

## 3. Compiling

Every fenced ` ```mermaid ` block is parsed by mermaid's own parser. If it compiles here, GitHub renders it.

```bash
scripts/check-mermaid.sh                 # ARCHITECTURE.md + docs/*.md
scripts/check-mermaid.sh path/to/file.md # specific files
```

Parse-only — no Chromium, no puppeteer. The first run provisions `mermaid` + `jsdom` into
`~/.cache/fs-mermaid-lint` (override with `MERMAID_LINT_HOME`); later runs are instant. Failures are emitted
as `::error file=…,line=…::` so they land as inline annotations on the PR diff.

## 4. The sync rule (enforced in CI)

`scripts/check-docs-in-sync.sh` fails a PR that changes the **shape** of a service without redrawing it.
Shape-changing paths, and the diagram each one invalidates:

| Changed path | Diagram that is now stale |
|---|---|
| `**/db/migration/*.sql` | §4 Data model (ER) |
| `**/*Controller.java` | §3 Component structure, §5 Request flows |
| `**/*Client.java` | §2 System context |
| `docker-compose.yml`, `deploy/**`, `gateway/**`, `terraform/**`, `Dockerfile` | §2 System context, infrastructure |

A bug fix inside an existing method changes no shape and does **not** trip this rule — the rule is meant to
keep diagrams true, not to tax every commit. Genuine exceptions use `[docs-ok]` in a commit message.

## 5. CI wiring

Every repo carries `.github/workflows/architecture.yml`. It compiles the diagrams, and — in repos whose
`ci.yml` does not already run the guard — also checks the sync rules, so neither check is run twice.

```yaml
name: architecture
on:
  pull_request: {}
  push: { branches: [ main ] }
jobs:
  architecture:
    runs-on: [self-hosted, macOS]
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: actions/setup-node@v4
        with: { node-version: "22" }
      # Only where ci.yml does not already run it:
      - name: Architecture docs in sync
        run: bash scripts/check-docs-in-sync.sh "origin/${{ github.base_ref || 'main' }}"
      - name: Mermaid diagrams compile
        run: bash scripts/check-mermaid.sh
```

`fetch-depth: 0` is required — the sync guard diffs against the PR base and cannot do that on a shallow
clone.

## 6. Reference implementations

- **Service with a schema** — [`fs-identity/ARCHITECTURE.md`](https://github.com/piraho/fs-identity/blob/main/ARCHITECTURE.md)
- **Stateless orchestrator** — [`fs-assistant/ARCHITECTURE.md`](https://github.com/piraho/fs-assistant/blob/main/ARCHITECTURE.md)
- **Client app** — [`fs-web/ARCHITECTURE.md`](https://github.com/piraho/fs-web/blob/main/ARCHITECTURE.md)
- **Whole platform** — [`fs-product/ARCHITECTURE.md`](https://github.com/piraho/fs-product/blob/main/ARCHITECTURE.md)
