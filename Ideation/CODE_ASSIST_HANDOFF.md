# CHITKALA — Code Assist Implementation Brief

## Objective

Build the first thin, safe, local-first vertical slice of **CHITKALA: Creative Hypermedia Intelligence Toolkit for Knowledge & Agentic Learning Automation**. Follow `CHITKALA_TECHNICAL_DESIGN.md` as the architecture contract. Treat every component and file as a proposed design until it is implemented and verified by tests.

## Non-negotiable invariants

1. Never modify an existing Obsidian vault during import without explicit opt-in.
2. Markdown files and attachments remain the canonical user data.
3. Never execute imported JavaScript/MDX in the privileged application origin.
4. All agent-originated document mutations are staged patch proposals requiring user review.
5. File writes use atomic transaction/copy-and-swap with `baseRevision` checks.
6. Every returned citation includes immutable document revision + span reference.
7. Vector/graph/FTS projections can be reconstructed from canonical vault data.
8. Privacy scopes apply *before* constructing model contexts, not only in the UI.
9. No commercial or production-licensed SDK dependency without a documented ADR.
10. Do not claim a feature is working until tests and a manual workflow prove it.

## First delivery: M0 + early M1

### Task 1 — Scaffold

- pnpm monorepo with Tauri 2, React/TypeScript, Rust core crates and package boundaries from section 6.
- CI: Rust unit tests, TS unit/typecheck, lint, license scan, Playwright smoke.
- Three design themes and four-pane shell, including tabbed + stacked documents.
- Simple command palette and keyboard navigation.

**Exit:** app runs in dev mode on at least one OS, CI provides reproducible build instructions, no direct privileged bridge in untrusted content components.

### Task 2 — File integrity core

- `openVault`, `readDocument`, `writeDocumentAtomic`, `listDocuments`, `scanVault`.
- Path policy broker with symlink checks and vault-root scoping.
- SHA-256 current revision; stable document ID sidecar; file transaction journal.
- Original directory remains unmodified for scan/import copy mode.
- Add recovery tests for crash/interrupted file writes.

**Exit:** isolated 500-note fixture round trip has byte-identical imports; concurrent write conflict caught by revision precondition.

### Task 3 — Markdown editor

- CodeMirror with safe preview, frontmatter and wikilink syntax adapters.
- Explorer, command palette, tabs, stacked reading mode, outline.
- Autosave and undo/redo; rich content does not execute arbitrary code.

**Exit:** create, open, edit, save, close, reopen round-trip; no data loss, works without network.

### Task 4 — Deterministic indexing

- Integrate starter `schema.sql` as a reviewed migration (it is not production-ready as supplied).
- Build file scanner, AST link/heading extraction, FTS5 index, backlinks, aliases and broken link report.
- Idempotent event replay, watcher dedupe, graph neighborhood query.

**Exit:** adding/renaming/deleting a note updates search, backlinks and graph correctly; `rebuild-index` yields same projections.

### Task 5 — Read-only intelligence spike

- Source-aware chunker, deterministic citation model, hybrid retrieval adapters with lexical fallback.
- Mock model to verify context scopes/citation contracts; optional external/local model config.
- Read-only Q&A; no agent writing yet.

**Exit:** answers cite exact source spans; scope exclusions and missing-evidence test pass.

## Implementation artifacts to produce for each task

- `ADR-xxx.md`: decision and alternatives.
- `SPEC.md`: inputs, outputs and invariants.
- Unit/integration/E2E tests, including negative/adversarial cases.
- Screenshot or short UX capture for interactive work.
- Benchmark output against declared hardware and dataset.
- `CHANGELOG.md`: what is implemented and what remains proposed.

## Ordered acceptance demo

> Open vault copy → open Markdown note → follow wikilink → inspect backlink → search text → ask grounded question → inspect clickable citation → draft an edit proposal → accept it → verify saved revision and updated index.

The final patch proposal step may be delivered **after** read-only intelligence passes its tests. Do not fake the final demo with mocked filesystem mutations.

## Deferred by design

Managed SaaS, billing, end-to-end encrypted sync, multi-user CRDT sessions, arbitrary runtime execution, plugin marketplace, production publish deploy and unsupervised long-running agents are outside this first delivery.
