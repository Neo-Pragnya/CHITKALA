---
title: "CHITKALA — Knowledge Packs, Textbooks & Large Knowledge Repositories"
aliases:
  - "CHITKALA Knowledge Packs"
  - "CHITKALA Textbooks"
project: CHITKALA
version: "0.1-draft"
status: "Proposed — extends CHITKALA_TECHNICAL_DESIGN.md v1.0-draft"
date: 2026-10-21
tags:
  - chitkala
  - textbooks
  - knowledge-packs
  - publishing
  - local-first
---

# CHITKALA — Knowledge Packs, Textbooks & Large Knowledge Repositories

> **Goal:** let people **write textbooks** (including high-stakes ones such as medical textbooks) and **large knowledge
> repositories** in CHITKALA, publish them as a hosted reader site, PDF and EPUB, and let readers **install them into
> their own CHITKALA app**, much as people open an Obsidian vault or install a community plugin. Once installed, a
> book works offline, is searchable and linkable from the reader's own notes, and can be questioned with cited AI answers.
>
> This document extends [`CHITKALA_TECHNICAL_DESIGN.md`](CHITKALA_TECHNICAL_DESIGN.md) (the "TDD"). The AWS
> realisation is in [`AWS/CHITKALA_AWS_ARCHITECTURE.md` §22](AWS/CHITKALA_AWS_ARCHITECTURE.md#22-knowledge-packs-textbooks--large-repositories).
> Machine-readable examples: [`sample_book.yaml`](sample_book.yaml), [`sample_pack.yaml`](sample_pack.yaml),
> [`sample_catalog.json`](sample_catalog.json). Status: proposed; nothing is implemented.

---

## Contents

1. [Concepts](#1-concepts)
2. [Principles](#2-principles)
3. [Personas and journeys](#3-personas-and-journeys)
4. [Book projects](#4-book-projects)
5. [Editorial workflow and editions](#5-editorial-workflow-and-editions)
6. [Build outputs](#6-build-outputs)
7. [The Knowledge Pack format (`.ckpack`)](#7-the-knowledge-pack-format-ckpack)
8. [Installing packs in the app (the Library)](#8-installing-packs-in-the-app-the-library)
9. [Registries and distribution](#9-registries-and-distribution)
10. [Large knowledge repositories](#10-large-knowledge-repositories)
11. [The medical profile](#11-the-medical-profile)
12. [Licensing and entitlements](#12-licensing-and-entitlements)
13. [Security and privacy](#13-security-and-privacy)
14. [Data model and API additions](#14-data-model-and-api-additions)
15. [Roadmap](#15-roadmap)
16. [Acceptance scenarios](#16-acceptance-scenarios)
17. [Open questions](#17-open-questions)

---

## 1. Concepts

| Term | Meaning |
|---|---|
| **Book project** | A folder in an author's vault with a `book.yaml` that orders documents into parts and chapters and says what to build. Its content is ordinary Markdown/MDX |
| **Edition** | A frozen, content-hashed state of a book project (`21e`, `2027.1`). Errata create **revisions** of an edition (`21e r3`) |
| **Knowledge Pack** | The installable, signed, versioned distribution of an edition: Markdown content, assets, a manifest and optional prebuilt indexes. File extension `.ckpack` |
| **Profile** | A named set of extra rules: `textbook`, `reference`, `course`, `repository`, `medical` |
| **Library** | The reader's collection of installed packs, mounted **read-only** beside their own vaults |
| **Overlay** | The reader's highlights, notes and links on a pack, stored in the reader's own vault, never inside the pack |
| **Registry** | A catalog of packs with editions, signatures and download locations. Can be a static folder on any web host, an intranet share, a USB stick, or the managed AWS registry |
| **Publisher** | The person or organisation whose key signs a pack |

---

## 2. Principles

1. **A pack is still Markdown.** Unzip a `.ckpack` and the content is readable in any editor (TDD P01, P07). CHITKALA
   adds structure, indexes and signatures; it never locks content into a binary format.
2. **Installed packs are read-only.** The reader's annotations live in their own vault as overlays. Updating or
   uninstalling a pack never destroys the reader's notes.
3. **Offline after install.** Reading, search, backlinks into the pack, graph and local AI over the pack need no
   network (TDD P02).
4. **Citations pin an edition.** Every citation into a pack carries `packId@edition+revision`, document id, span and
   text hash (TDD §9.5). An answer about dosing from the 21st edition never silently points at the 22nd.
5. **Signed ≠ safe.** Signatures prove who published a pack and that it wasn't altered. Pack content is still treated as
   untrusted content (TDD trust zone 3): no executable code with privilege, sandboxed interactive components only.
6. **Registries are static-first.** The registry protocol is plain signed JSON plus files, so a hospital, university or
   rural clinic can host one with no CHITKALA account. The managed AWS registry adds publisher accounts, entitlements,
   search and scale; it is not required.
7. **The publisher sets the AI policy.** A pack's manifest can forbid sending its text to external models. CHITKALA
   enforces this before building any model context (TDD §17.3).
8. **Honest licensing.** Paid packs are licence-gated (entitlement to download and to receive updates), not DRM. The
   product never claims that downloaded content cannot be copied.

---

## 3. Personas and journeys

| Persona | Needs |
|---|---|
| Textbook author | Write chapters in Markdown with figures, tables, equations, references and cross-references; see a book-like preview |
| Editor / editorial board | Review changes, track sign-offs, freeze editions, issue errata |
| Medical editor / clinical reviewer | Two-person review of dosing and safety content, effective dates, evidence links |
| Publisher / institution | Sign and distribute packs, control entitlements, host a branded reader site, run a private registry |
| Learner / clinician | Install a book, read offline, highlight, link it from their notes, ask cited questions, get errata |
| Repository maintainer | Publish a large, evolving knowledge base (100k+ documents) with fast search and partial installs |

### Journey T — Write a textbook and ship an edition

Create a book project → write chapters → insert figures, tables, references and cross-references → book preview with
numbering → editors review changes as patch proposals (TDD §10.8) → freeze edition `1e` → build hosted site, PDF, EPUB
and pack → publish to a registry → readers install.

### Journey L — Install a book like an Obsidian vault

Open **Library** in the app → browse a registry (or open a `.ckpack` file, or click "Open in CHITKALA" on the book's
website) → see publisher, signature, licence, size, AI policy and profile → install → the book appears read-only in the
workspace → read, search and link `[[pack:org.example.cardiology@3e/Heart Failure#Diagnosis]]` from personal notes →
highlights become overlay notes in the reader's vault → later, "3e r2 erratum available" → update → overlays re-anchor.

### Journey R — Explore a huge repository

Open a 250,000-document repository on the web → search instantly (sharded index) → ask a question, answer cites
sections → "Install the Cardiology collection" → partial install of 8,000 documents → full offline use of that subset.

---

## 4. Book projects

### 4.1 Layout in the author's vault

```text
Books/Clinical Cardiology/
├── book.yaml                     # structure + outputs (see sample_book.yaml)
├── front/  preface.md  contributors.md  how-to-use.md
├── part-1-foundations/
│   ├── 01-cardiac-anatomy.md
│   └── 02-physiology.md
├── part-2-disease/
│   └── 07-heart-failure.md
├── back/  glossary.md  appendix-drug-tables.md
├── figures/  hf-staging.svg  echo-views.png
├── references.bib                # BibTeX or CSL-JSON
└── assessments/  ch07-mcq.md
```

### 4.2 `book.yaml` (summary; full example in [`sample_book.yaml`](sample_book.yaml))

| Field | Purpose |
|---|---|
| `id`, `title`, `subtitle`, `language`, `edition` | Identity |
| `profile` | `textbook` · `reference` · `course` · `repository` · `medical` |
| `contributors[]` | Authors, editors, reviewers with roles (`author`, `editor`, `peer-reviewer`, `clinical-reviewer`) and ORCID |
| `structure` | `front`, `parts[] { title, chapters[] }`, `back`; each chapter refers to a document by path or id |
| `numbering` | Chapter, section, figure, table, equation numbering schemes |
| `references` | Bibliography file + CSL style (e.g. Vancouver for medicine, APA). Point it at a live CSL JSON/BibTeX export (e.g. Zotero Better BibTeX "keep updated"); the core watches it and re-resolves citations |
| `glossary`, `index` | Glossary source; index-term collection from `{index: term}` markers |
| `outputs` | Which of `site`, `pdf`, `epub`, `pack` to build and their options |
| `review` | Required approvals per content type (e.g. `dosage: 2 clinical-reviewer`) |
| `license`, `aiPolicy`, `visibility` | Licensing, AI use, private-by-default |

### 4.3 Authoring syntax (all plain Markdown extensions, readable elsewhere)

| Need | Syntax | Notes |
|---|---|---|
| Labelled figure | `![Heart failure stages](figures/hf-staging.svg){#fig:hf-stages}` + caption | Alt text is **required** (build fails without it) |
| Cross-reference | `[[#fig:hf-stages]]`, `[[07-heart-failure#tbl:nyha]]` | Rendered as "Figure 7.2" |
| Table label | caption line `Table: NYHA classes {#tbl:nyha}` | |
| Equation | `$$ … $$ {#eq:map}` | MathML in EPUB/site |
| Citation | `[@ponikowski2016]`, `[@ponikowski2016, p. 2135]` | Resolved from `references.bib`; DOI/PMID preserved |
| Callout | `> [!clinical-pearl]`, `> [!warning]`, `> [!key-point]` | Obsidian-compatible callouts; profile-specific types |
| Learning objectives | frontmatter `objectives: [...]` | Shown at chapter start, exported to course formats |
| Assessment | fenced ```` ```quiz ```` YAML block | Rendered interactive in site/app, as text in PDF |
| Index term | `{index: "heart failure, acute"}` | Back-of-book index |
| Structured block | fenced ```` ```drug-monograph ```` / ```` ```dose-table ```` (medical profile) | Validated against a schema (§11) |

Everything here builds on the existing parser adapter (TDD §7.1); book features are AST transforms, not a separate
editor.

---

## 5. Editorial workflow and editions

### 5.1 Review is the patch engine

Every change to a book project, by a person or an agent, can go through the same **patch proposal** flow the TDD uses
for agents (§10.8). For books this adds:

- **Reviewer roles** from `book.yaml`, and rules per content type (`review.rules`), e.g. any change inside a
  `dose-table` needs two `clinical-reviewer` approvals.
- **Numeric-change highlighting**: diffs that change numbers, units or drug names are flagged and cannot be
  bulk-approved.
- **Sign-off records** (who, when, which proposal hash) stored in the book's `.chitkala/reviews/` as Markdown/JSON, so
  they travel with the project.
- In the hosted setting, review runs through the cloud API with the same rules (AWS §22).

### 5.2 Edition lifecycle

```text
draft → in-review → frozen (edition N, content hash) → published (site/PDF/EPUB/pack)
                                   └→ erratum (revision rK) → published  … → superseded by edition N+1 → retired
```

- **Freeze** computes a manifest of every file hash; the edition id + manifest hash become the citation anchor.
- **Errata** are revisions of an edition: a signed delta plus an erratum notice (what changed, why, severity:
  `editorial`, `content`, `safety-critical`).
- **Superseded** editions stay installable unless retired by the publisher (with reason); readers who cite them keep
  working citations.

---

## 6. Build outputs

| Output | Built by | Notes |
|---|---|---|
| **Hosted reader site** | Astro (TDD §15) with book theme | Chapter navigation, numbered figures, glossary popovers, back-of-book index, sharded search, "Open in CHITKALA" install button, per-edition URLs `/3e/…` |
| **PDF** | **Typst** embedded in `chitkala-books` (Rust) preferred; Paged.js fallback (spikes K2, S-R6) | Print layout, running heads, footnotes/endnotes, PDF/UA tagging target |
| **DOCX / journal LaTeX** | Optional "Pandoc profile" using the user's own Pandoc install (Zettlr-style defaults files) | Not bundled (GPL); for submissions to journals and publishers |
| **EPUB 3** | EPUB builder | Reflowable, MathML, EPUB Accessibility 1.1 metadata |
| **Knowledge Pack** | `chitkala-packs` (Rust) via `chitkala build-book` / `chitkala verify-pack` (§7) | Content + manifest + signatures + optional prebuilt indexes; the same code runs on the desktop, in CI and in the AWS pipeline |
| **Metadata** | JSON-LD (`Book`, `Chapter`), ONIX later | Discovery and library cataloguing |

Builds run locally by default (desktop build worker, TDD §15). The managed AWS pipeline runs the same builders in
isolation for large books and adds signing and distribution (AWS §22).

**Quality gates for any output:** every figure has alt text; every cross-reference and citation resolves; no private
document is referenced (TDD §15.4 privacy rules); WCAG 2.2 AA checks on the site; EPUBCheck passes; profile rules pass
(§11).

---

## 7. The Knowledge Pack format (`.ckpack`)

### 7.1 Layout

A `.ckpack` is a ZIP (store or deflate) or an unpacked directory with this layout:

```text
org.example.clinical-cardiology@3e/
├── pack.yaml                 # manifest (see sample_pack.yaml)
├── pack.yaml.sig             # detached signature over pack.yaml
├── files.json                # every file: path, sha256, size, mime  (hash covered by pack.yaml)
├── content/                  # canonical Markdown/MDX + assets, structured as in the book project
├── book.yaml                 # structure, numbering, glossary refs (textbooks)
├── references.csl.json       # resolved bibliography
├── indexes/                  # OPTIONAL, rebuildable
│   ├── fts.sqlite            #   FTS5 tables for the pack
│   ├── graph.sqlite          #   documents, headings, links, entities, edges
│   └── embeddings/<namespace>.parquet   # chunk vectors; namespace = model id + version + dims
├── errata/                   # erratum notices (Markdown + structured JSON)
└── LICENSE, NOTICE
```

### 7.2 Manifest essentials (`pack.yaml`)

| Field | Purpose |
|---|---|
| `apiVersion: chitkala.dev/v1alpha1`, `kind: KnowledgePack` | Schema identity |
| `metadata.id` | Reverse-DNS id, e.g. `org.example.clinical-cardiology` |
| `metadata.edition`, `metadata.revision`, `metadata.version` | `3e`, `r2`, SemVer for tooling (`3.2.0`) |
| `metadata.publisher` | Name, key id (`publisherKeyId`), contact, URL |
| `spec.profile` | `textbook` · `reference` · `course` · `repository` · `medical` |
| `spec.license` | SPDX id or `LicenseRef-…` + URL; `spec.entitlement`: `open` · `registered` · `paid` · `institutional` |
| `spec.aiPolicy` | `local-only` · `external-with-consent` · `publisher-hosted-only` (see §13) |
| `spec.content` | Root, document count, total bytes, languages, `filesDigest` (sha256 of `files.json`) |
| `spec.indexes[]` | Type (`fts5`, `graph`, `embeddings`), engine version, model id/version/dimensions, digest |
| `spec.partitions[]` | Named subsets for partial install (e.g. per part or specialty) with their file lists |
| `spec.dependencies[]` | Other packs this one links to (`org.example.pharmacology@>=5e`) |
| `spec.compatibility` | `chitkala: ">=0.6.0 <1.0.0"` |
| `spec.supersedes`, `spec.effectiveDate`, `spec.reviewBy` | Edition lineage and currency (medical profile) |
| `spec.components` | Interactive MDX components used, with their trusted-registry lock hash |

### 7.3 Integrity and trust

- `files.json` lists every file's sha256; its digest is inside `pack.yaml`; `pack.yaml.sig` signs the manifest
  (Ed25519 or ECDSA P-256).
- Publisher public keys come from the registry (§9.3), can be pinned by the user or an institution, and can be revoked.
- Install verifies: signature → `files.json` digest → every file hash → schema and profile rules. Any failure aborts the
  install with a clear message. Tampered packs never mount.
- **Prebuilt indexes are hints, not truth.** The app may use them for instant search, but verifies digests and can
  always rebuild them from `content/` (TDD P05). Embeddings are used only if the reader's configured model matches the
  namespace; otherwise CHITKALA re-embeds locally in the background or stays lexical + graph only.

### 7.4 Updates and deltas

Files are content-addressed, so an erratum or new edition downloads only changed files. A **delta manifest** lists
added, changed and removed paths between two revisions; the app applies it to a new side-by-side directory and switches
atomically, keeping the previous revision until overlays are re-anchored.

---

## 8. Installing packs in the app (the Library)

### 8.1 Where packs live

```text
<app data>/CHITKALA/Library/
├── org.example.clinical-cardiology/
│   ├── 3e-r2/           # read-only, verified files (OS read-only flag + app-level write denial)
│   └── 3e-r1/           # kept until overlays are re-anchored, then garbage-collected
└── registry-cache/       # catalogs, publisher keys, revocation lists
```

The Library is outside every user vault and excluded from vault sync and backup by default (it can be re-downloaded).
Institutions can point the Library at a shared read-only location.

### 8.2 Mounting

An installed pack is mounted as a **read-only vault** with `vault.kind = pack`. The parser, index, graph and retrieval
treat it like any vault (TDD §6, §8, §9), with these rules:

- The trusted core denies every write into a pack mount (TDD invariant: only the core writes, and it refuses).
- Search has a scope picker: *My vaults*, *Library*, a specific pack or partition.
- Graph styling distinguishes pack nodes (publisher badge) from the reader's own notes.
- Agents can read packs only through grants (`vault.read` on `pack:org.example.clinical-cardiology@3e`), and
  never propose patches to them.

### 8.3 Linking from personal notes

`[[pack:org.example.clinical-cardiology@3e/Heart Failure#Diagnosis]]` resolves to the pack's document and heading.
Omitting the edition (`[[pack:org.example.clinical-cardiology/Heart Failure]]`) follows the newest installed edition;
the resolver records the edition it resolved to, so backlinks and citations stay pinned. In other Markdown editors the
link degrades to readable text.

### 8.4 Overlays (highlights and notes)

Highlights and margin notes are stored as Markdown files in the reader's vault, for example
`Annotations/org.example.clinical-cardiology/07-heart-failure.md`, each with an anchor:

```yaml
---
annotates: pack:org.example.clinical-cardiology@3e-r2
documentId: doc_hf_07
anchor:
  textQuote: {exact: "loop diuretics", prefix: "first-line ", suffix: " for congestion"}
  textHash: "sha256:…"
  heading: ["Heart Failure", "Management"]
color: yellow
---
Check renal function before escalating. See [[My Ward Protocols#Diuretics]].
```

Anchors follow the W3C Web Annotation selector model (quote + position + hash), so they survive reflow. On update, the
app re-anchors each overlay; overlays it cannot place exactly are listed for review, never dropped.

### 8.5 Install, update, uninstall

| Action | Behaviour |
|---|---|
| Install from registry | Show publisher, signature status, licence, entitlement, size, partitions, AI policy, profile warnings → download → verify → mount → index (prebuilt or rebuild) |
| Install from file | Same verification; unknown publisher keys require explicit trust |
| "Open in CHITKALA" | Site button opens `chitkala://install?registry=…&pack=…&edition=…`; the app shows the same install sheet |
| Partial install | Choose partitions; others appear as remote placeholders (titles only) with "install section" |
| Update | Notified by registry polling or push; shows erratum notes and severity; safety-critical errata show a banner on affected pages until updated |
| Uninstall / licence expiry | Removes content; overlays remain with "pack not installed" placeholders; citations keep their pinned metadata |

### 8.6 AI over installed packs

Retrieval treats pack chunks like vault chunks, with citations pinned to edition. The pack's `aiPolicy` applies:
`local-only` → pack text is never sent to an external model (only local models, or cloud relay is refused for those
chunks); `external-with-consent` → the reader's normal consent flow; `publisher-hosted-only` → questions over the pack
go to the publisher's hosted "ask this book" endpoint (§10.3), which returns cited answers.

---

## 9. Registries and distribution

### 9.1 Static registry protocol (works anywhere)

```text
https://books.example.org/registry/
├── catalog.json            # list of packs + editions (see sample_catalog.json)
├── catalog.json.sig        # signed by the registry key
├── keys/                   # publisher public keys + revocations.json (signed)
└── packs/org.example.clinical-cardiology/3e-r2/  pack.yaml, pack.yaml.sig, files.json, files/<sha256>
```

- Hostable on GitHub Pages, S3/CloudFront, an intranet web server, or a **local folder / USB drive** for offline
  clinics and classrooms.
- The app can subscribe to several registries (public, institutional, personal) and pins each registry's key on first
  use (with a visible fingerprint).
- Mirrors: any registry can be mirrored byte-for-byte; signatures make mirrors safe.

### 9.2 Managed registry (optional, AWS)

Adds publisher accounts, upload and validation, entitlements for paid and institutional packs, catalog search,
download signing, update push, install analytics (opt-in, aggregated) and large-repository hosting. Details: AWS §22.

### 9.3 Publisher trust

- Publisher keys are registered with the registry; verified organisations get a badge (domain or legal verification,
  process to be defined).
- Revocation lists are signed and checked on install and periodically; a revoked key blocks new installs and shows a
  warning on installed packs.
- Optional transparency log of published pack digests (spike K5) so silent re-publishing is detectable.

---

## 10. Large knowledge repositories

### 10.1 Targets (proposed, to be benchmarked)

| Dimension | Desktop (installed) | Hosted |
|---|---|---|
| Documents | 50k per pack, 200k across the Library on reference hardware | 1M+ per repository |
| Lexical search | ≤ 300 ms p95 warm for 50k | ≤ 200 ms p95 |
| First open after install | Readable in < 10 s using prebuilt indexes | n/a |
| Partial install | Any partition installable independently | n/a |

### 10.2 Desktop techniques

Prebuilt FTS and graph indexes attached as separate SQLite databases per pack (no import step); lazy embedding;
partitions; level-of-detail graph (TDD §8.4); background verification after first open with an "unverified index"
notice until complete.

### 10.3 Hosted reader at scale

- **Static first:** each edition pre-rendered; search via a sharded static index (per part/letter), so most reading
  never hits a server.
- **Hosted search and "ask this book"** for large corpora: a shared index per repository edition with lexical + vector +
  graph retrieval, cited answers pinned to edition, and the same Guardrails and citation verifier as the app.
- **Answer safety:** answers only from the repository's content; abstain when the evidence is missing; show sources
  first; the medical profile adds disclaimers and stricter abstention (§11).

---

## 11. The medical profile

`profile: medical` turns on rules for clinical and medical textbooks. It **supports** clinical publishing; it does not
make CHITKALA a clinical decision-support product or a medical device. Whether specific features (e.g. dose
calculators) fall under medical-device regulation in a given country requires legal review before release.

| Area | Rule |
|---|---|
| Structured content | `drug-monograph`, `dose-table`, `guideline-recommendation`, `case-study`, `mcq` blocks validated against JSON Schemas (units, routes, ranges, populations) |
| Units | UCUM unit codes in structured blocks; build fails on unknown units or ambiguous abbreviations (e.g. "U", "µg" vs "mcg" policy per book) |
| Evidence | Recommendations carry evidence references (DOI/PMID) and optional grade (e.g. GRADE); unresolved references fail the build |
| Review | Changes to structured clinical blocks need the number of `clinical-reviewer` approvals set in `book.yaml` (default 2); numeric diffs highlighted; no self-approval |
| Currency | `effectiveDate` and `reviewBy` per chapter; chapters past `reviewBy` are flagged in the app and on the site |
| Errata | Severity `safety-critical` triggers push notifications to installed copies and a banner on affected pages |
| Patient data | Packs must not contain protected health information. Builds run PHI detection on text and image metadata; findings block publishing until resolved or explicitly waived by two editors |
| Images | De-identification attestation per clinical image; EXIF/DICOM tags stripped; alt text required |
| Vocabularies | Optional coded terms (MeSH, ICD-10, SNOMED CT, RxNorm, LOINC). **Licensing differs** (SNOMED CT requires an affiliate licence in many countries; ICD-10 has WHO terms); the pack declares which it uses |
| AI answers | Only from installed or hosted pack content; must cite edition + section; must abstain on unsupported dosing or patient-specific questions; fixed disclaimer; no dose calculation unless a reviewed calculator component exists |
| Accessibility | WCAG 2.2 AA, EPUB Accessibility, colour-independent figures |

---

## 12. Licensing and entitlements

| Entitlement | Download | Updates | Typical licence |
|---|---|---|---|
| `open` | Anyone | Anyone | CC BY 4.0, CC BY-SA, Apache-2.0 for code samples |
| `registered` | Signed-in users | Signed-in users | Free with account |
| `paid` | Purchasers | During update period | Proprietary |
| `institutional` | Members via SSO (university, hospital) | While membership is valid | Site licence |

- Entitlements gate **downloads and updates** through signed, short-lived download grants. After download the content
  is on the reader's disk; CHITKALA does not claim otherwise.
- Optional **offline lease** for `paid`/`institutional`: the app records a lease expiry and, after expiry plus grace,
  hides the pack until re-validated. This is a usability contract, not a security boundary.
- Payments are out of scope for the core project; the managed registry integrates with a payment provider later.

---

## 13. Security and privacy

- Packs are **untrusted content** (TDD §17.2 zone 3) even when signed: Markdown is sanitised; MDX components must come
  from the pack's declared component lock and run in the sandboxed tier (TDD §7.4 tier 2); no scripts, no network by
  default.
- Prompt injection inside pack text is treated as data (TDD §17.1). Packs cannot carry skills or tools.
- Registry and install traffic is HTTPS; signatures make the transport untrusted-tolerant.
- **Reader privacy:** no reading analytics by default. Opt-in aggregate install counts only. Annotations are private and
  stay in the reader's vault (and E2EE sync if enabled).
- **Author privacy:** building a pack applies the same public-content rules as publishing (TDD §15.4): private notes,
  transclusions and comments never enter a pack.

---

## 14. Data model and API additions

- **Local schema:** `vaults.kind` (`user` | `pack`) plus `library_packs`, `library_installs`, `pack_partitions`,
  `registries`, `publisher_keys`, `overlays` and `book_projects`, `book_editions`, `review_signoffs` — see the
  "Knowledge Packs & books" block at the end of [`schema.sql`](schema.sql).
- **API:** registry, install grant, publisher upload, book build and "ask this book" operations — see the
  `Library`, `Books` and `Publishers` tags in [`api.openapi.yaml`](api.openapi.yaml).
- **Manifests:** [`sample_book.yaml`](sample_book.yaml), [`sample_pack.yaml`](sample_pack.yaml),
  [`sample_catalog.json`](sample_catalog.json).

---

## 15. Roadmap

These fit after the TDD's milestones; nothing here should start before its prerequisite gate passes (TDD §21.4).

| Milestone | Deliverable | Depends on | Exit gate |
|---|---|---|---|
| **K1 · Book projects** | `book.yaml`, numbering, cross-refs, citations, glossary, book preview, local site build | M3 (renderer), M4 (local publish) | Golden book fixture renders identically in site and preview; zero broken refs |
| **K2 · Print & EPUB** | PDF and EPUB builders, accessibility checks | K1 | EPUBCheck + PDF/UA checks pass on fixtures |
| **K3 · Packs & Library** | `.ckpack` build + verify, install from file, read-only mounts, pack links, overlays, updates | K1, M2 (retrieval) | Tampered-pack suite rejected; overlays survive an edition update |
| **K4 · Static registries** | Registry protocol, subscriptions, key pinning, revocation, "Open in CHITKALA" | K3 | Install from GitHub Pages and from a USB folder works offline |
| **K5 · Editorial workflow** | Roles, review rules, sign-offs, editions, errata | K1, M4 (patch review) | Rule fixtures: no self-approval, numeric diffs need N approvals |
| **K6 · Managed registry & large repos** | AWS registry, entitlements, hosted reader at scale, ask-this-book | K4, AWS C5 | See AWS plan C8–C10 |
| **K7 · Medical profile** | Schemas, unit checks, PHI scan, currency, safety errata, clinical AI rules | K5, K6 | Medical fixture suite; external clinical-editor review; legal review of claims |

---

## 16. Acceptance scenarios

**Scenario H — Build a textbook.** *Given* a book project with 20 chapters, 150 figures and 600 references, *when* the
author builds site, PDF, EPUB and pack, *then* every figure is numbered consistently in all outputs, every reference
resolves, a missing alt text fails the build with the file and line, and no private note appears in any output.

**Scenario I — Install and read offline.** *Given* a signed pack in a registry, *when* a reader installs it and turns
off the network, *then* the book opens, searches, links from personal notes and answers cited questions with a local
model; no write into the pack directory is possible.

**Scenario J — Edition update keeps notes.** *Given* 300 overlays on edition `3e-r1`, *when* `3e-r2` is installed,
*then* at least 99 % re-anchor exactly, the rest are listed for review, none are deleted, and old citations still
resolve to `3e-r1` text until the reader chooses to update them.

**Scenario K — Publisher forbids external AI.** *Given* a pack with `aiPolicy: local-only`, *when* the reader asks a
question with a cloud model selected, *then* no pack text is sent; the app answers from local models or explains why it
cannot.

**Scenario L — Safety-critical erratum.** *Given* a medical pack installed on 1,000 devices, *when* the publisher issues
a `safety-critical` erratum, *then* devices that check in show the banner on affected pages and offer the update, and
the hosted site shows the corrected text with an erratum notice.

**Scenario M — Partial install of a huge repository.** *Given* a 250,000-document repository with partitions, *when* a
reader installs one 8,000-document partition, *then* only that partition downloads, other sections show as placeholders,
and links into uninstalled sections offer "install section" instead of failing.

**Scenario N — Tampered pack.** *Given* a pack whose single file was modified after signing, *when* it is installed from
file, registry or mirror, *then* verification fails and nothing is mounted.

---

## 17. Open questions

| ID | Question |
|---|---|
| K1 | Pack container: ZIP vs directory-of-content-addressed-files only (ZIP is friendlier for email/USB; files are better for deltas). Proposal: both, same manifest |
| K2 | Typesetting engine: Typst (Rust, embeddable; **preferred** given ADR-016) vs Paged.js/WeasyPrint (HTML/CSS) for PDF; decide with spike S-R6 |
| K3 | Embedding namespace portability: which open embedding models should packs ship by default so most readers can reuse vectors |
| K4 | Edition naming and SemVer mapping; how errata map to versions |
| K5 | Transparency log (Sigstore-style) vs registry-signed history |
| K6 | Payments and tax handling for paid packs in the managed registry |
| K7 | Regulatory review for medical AI features per target country |
| K8 | Mobile reading app: same pack format, storage limits, partial installs by default |
