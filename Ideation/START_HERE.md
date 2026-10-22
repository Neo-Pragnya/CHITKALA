# CHITKALA — Technical Design Pack

**Full name:** Creative Hypermedia Intelligence Toolkit for Knowledge & Agentic Learning Automation  
**Project:** Open-source, local-first, AI-native personal knowledge OS  
**Status:** Architecture/design draft; no implementation implied  
**Date:** 2026-10-20

## Contents

| File                             | Use                                                                                                                |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `CHITKALA_TECHNICAL_DESIGN.md`   | Canonical 26-section Obsidian-friendly design; 14 Mermaid diagrams, threat model, architecture, rollout, contracts |
| `CHITKALA_TECHNICAL_DESIGN.html` | Visual, searchable design reader with Aurora/Parchment/Atlas themes; Mermaid renders if external CDN is reachable  |
| `schema.sql`                     | SQLite starter DDL covering vaults, documents, revisions, chunks/FTS, graph, agent runs, patches, grants and audit |
| `api.openapi.yaml`               | Draft OpenAPI 3.1 contract for optional HTTP service; not a running server                                         |
| `sample_skill.yaml`              | Agent skill manifest with scoped capabilities and budgets                                                          |
| `sample_publish.yaml`            | Private-by-default static publishing configuration example                                                         |
| `diagrams/*.mmd`                 | 14 individually reusable Mermaid source diagrams                                                                   |
| `CODE_ASSIST_HANDOFF.md`         | Practical task brief for a coding agent to begin a safe vertical slice                                             |
| `CHITKALA_PRIOR_ART_AND_STACK.md` | Lessons from Foam, SilverBullet, Logseq, OpenKnowledge, Zettlr, Trilium, Joplin, SiYuan, AppFlowy; Rust backend + TypeScript frontend split, crate map, contracts |
| `CHITKALA_KNOWLEDGE_PACKS_AND_TEXTBOOKS.md` | Textbooks (incl. medical), Knowledge Packs, the in-app Library, registries and large hosted repositories |
| `sample_book.yaml` · `sample_pack.yaml` · `sample_catalog.json` | Book project manifest, Knowledge Pack manifest and static registry catalog examples |
| `AWS/`                           | Optional cloud services on AWS: detailed design, implementation plan (C0–C11), interactive architecture diagrams   |

## Reading order

1. Open the HTML edition for a guided overview of architecture and delivery order.
2. Use the Markdown version for comments, Obsidian backlinks and architecture decision records.
3. Validate technical options and legal/licensing decisions before locking dependencies.
4. Hand `CODE_ASSIST_HANDOFF.md` plus the main spec to an implementation agent.
5. Begin with M0 (foundations) and M1 (vault integrity/editor/graph), not autonomous workflows or hosted sync.

## Important constraints

- Canonical user documents remain portable Markdown/MDX/files.
- Arbitrary MDX/HTML/JS content must never inherit privileged Tauri/Node filesystem access.
- Agent writes must use reviewable patches and revision preconditions.
- Semantic/vector indexes are reconstructable and obey vault privacy scopes.
- Public export uses an explicit allowlist; no inherited private links or assets.
- Sync and collaborative CRDT editing are separate architectural concerns.

## Validation performed on this pack

- Starter SQLite schema executed against an in-memory SQLite connection with FTS5.
- YAML manifests and proposed API parsed successfully.
- HTML side navigation links resolved; Mermaid source diagrams exported.

**Not yet validated:** native packaging, runtime sandboxing, specific release versions, model quality, real-device performance, hosted pricing, or compatibility with every Obsidian plugin.
