-- CHITKALA local cache schema — design seed, NOT production migration.
-- SQLite 3.x with FTS5 enabled. Canonical document bodies live in the vault.
-- User-visible ids are strings (UUIDv7/ULID), references are stable across rename.
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS vaults (
    vault_id TEXT PRIMARY KEY,
    root_uri TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    kind TEXT NOT NULL DEFAULT 'user' CHECK(kind IN ('user','pack')),  -- 'pack' = read-only Library mount
    privacy_policy TEXT NOT NULL DEFAULT 'local-only'
        CHECK(privacy_policy IN ('local-only','external-with-consent','selected-folders-only')),
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS documents (
    document_id TEXT PRIMARY KEY,
    vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE CASCADE,
    relative_path TEXT NOT NULL,
    display_title TEXT NOT NULL,
    format TEXT NOT NULL CHECK(format IN ('md','mdx','html','canvas','other')),
    revision_hash TEXT NOT NULL,
    size_bytes INTEGER NOT NULL CHECK(size_bytes >= 0),
    frontmatter_json TEXT NOT NULL DEFAULT '{}',
    visibility TEXT NOT NULL DEFAULT 'private'
      CHECK(visibility IN ('private','draft','public')),
    is_deleted INTEGER NOT NULL DEFAULT 0 CHECK(is_deleted IN (0,1)),
    updated_at TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_documents_live_path
  ON documents(vault_id, relative_path) WHERE is_deleted = 0;
CREATE INDEX IF NOT EXISTS ix_documents_vault_title ON documents(vault_id, display_title);
CREATE INDEX IF NOT EXISTS ix_documents_vault_revision ON documents(vault_id, revision_hash);

CREATE TABLE IF NOT EXISTS document_revisions (
    document_id TEXT NOT NULL REFERENCES documents(document_id) ON DELETE CASCADE,
    revision_hash TEXT NOT NULL,
    parent_hash TEXT,
    committed_at TEXT NOT NULL,
    origin_type TEXT NOT NULL,
    origin_id TEXT,
    snapshot_uri TEXT, -- optional history archive; NULL if no snapshot retained
    PRIMARY KEY(document_id, revision_hash)
);

CREATE TABLE IF NOT EXISTS chunks (
    chunk_id TEXT PRIMARY KEY,
    document_id TEXT NOT NULL REFERENCES documents(document_id) ON DELETE CASCADE,
    revision_hash TEXT NOT NULL,
    heading_anchor TEXT,
    heading_path_json TEXT NOT NULL DEFAULT '[]',
    start_byte INTEGER NOT NULL,
    end_byte INTEGER NOT NULL,
    body_text TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    indexed_at TEXT NOT NULL,
    CHECK(start_byte >= 0 AND end_byte > start_byte)
);
CREATE INDEX IF NOT EXISTS ix_chunks_doc_revision ON chunks(document_id, revision_hash);
CREATE INDEX IF NOT EXISTS ix_chunks_content_hash ON chunks(content_hash);

-- NOTE: Ordinary content-mode FTS5 for schema simplicity. Maintain rows
-- transactionally with chunks. Production may use external-content FTS5.
CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
    chunk_id UNINDEXED,
    title,
    headings,
    body_text,
    tokenize='unicode61 remove_diacritics 2'
);

CREATE TABLE IF NOT EXISTS entities (
    entity_id TEXT PRIMARY KEY,
    vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    aliases_json TEXT NOT NULL DEFAULT '[]',
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_entities_vault_type ON entities(vault_id, entity_type);

-- Nodes are typed references; target IDs map to documents/entities/agents/etc.
-- Validate existence and scope in the domain layer; mixed-type target IDs
-- cannot be expressed as simple SQL foreign keys.
CREATE TABLE IF NOT EXISTS edges (
    edge_id TEXT PRIMARY KEY,
    vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE CASCADE,
    source_node_id TEXT NOT NULL,
    source_node_type TEXT NOT NULL,
    target_node_id TEXT NOT NULL,
    target_node_type TEXT NOT NULL,
    relation TEXT NOT NULL,
    provenance TEXT NOT NULL CHECK(provenance IN ('parsed','manual','agent_suggested')),
    validation_status TEXT NOT NULL DEFAULT 'confirmed'
      CHECK(validation_status IN ('confirmed','pending','rejected','broken')),
    confidence REAL CHECK(confidence IS NULL OR (confidence >= 0 AND confidence <= 1)),
    source_document_id TEXT REFERENCES documents(document_id) ON DELETE CASCADE,
    source_revision_hash TEXT,
    source_start_byte INTEGER,
    source_end_byte INTEGER,
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_edges_from ON edges(vault_id, source_node_id, relation);
CREATE INDEX IF NOT EXISTS ix_edges_to ON edges(vault_id, target_node_id, relation);
CREATE INDEX IF NOT EXISTS ix_edges_doc ON edges(source_document_id, source_revision_hash);

-- Model / index namespace changes should not merge vectors from different
-- dimensionalities or normalizations. Actual vector bytes live behind adapter.
CREATE TABLE IF NOT EXISTS embedding_records (
    chunk_id TEXT NOT NULL REFERENCES chunks(chunk_id) ON DELETE CASCADE,
    model_id TEXT NOT NULL,
    model_revision TEXT NOT NULL,
    dimensions INTEGER NOT NULL CHECK(dimensions > 0),
    index_namespace TEXT NOT NULL,
    vector_key TEXT NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY(chunk_id, model_id, model_revision, index_namespace)
);

CREATE TABLE IF NOT EXISTS agent_runs (
    run_id TEXT PRIMARY KEY,
    vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE CASCADE,
    agent_id TEXT NOT NULL,
    status TEXT NOT NULL
      CHECK(status IN ('CREATED','PLANNED','WAITING_PERMISSION','RUNNING',
        'PROPOSAL_READY','WAITING_REVIEW','COMMITTING','COMPLETED',
        'CANCELLED','FAILED','EXPIRED','REJECTED')),
    principal_id TEXT NOT NULL,
    task_digest TEXT,
    trace_id TEXT NOT NULL,
    budget_json TEXT NOT NULL DEFAULT '{}',
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    terminal_at TEXT
);
CREATE INDEX IF NOT EXISTS ix_agent_runs_vault_status ON agent_runs(vault_id, status, created_at);

CREATE TABLE IF NOT EXISTS agent_run_events (
    run_id TEXT NOT NULL REFERENCES agent_runs(run_id) ON DELETE CASCADE,
    sequence INTEGER NOT NULL CHECK(sequence >= 0),
    event_type TEXT NOT NULL,
    payload_redacted_json TEXT NOT NULL DEFAULT '{}',
    occurred_at TEXT NOT NULL,
    PRIMARY KEY(run_id, sequence)
);

CREATE TABLE IF NOT EXISTS patch_proposals (
    proposal_id TEXT PRIMARY KEY,
    run_id TEXT REFERENCES agent_runs(run_id) ON DELETE SET NULL,
    vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE CASCADE,
    document_id TEXT REFERENCES documents(document_id) ON DELETE CASCADE,
    operation TEXT NOT NULL,
    base_revision_hash TEXT,
    proposal_hash TEXT NOT NULL,
    patch_uri TEXT NOT NULL,
    approval_status TEXT NOT NULL DEFAULT 'pending'
      CHECK(approval_status IN ('pending','approved','rejected','expired','committed','conflict')),
    created_at TEXT NOT NULL,
    reviewed_at TEXT,
    reviewer_id TEXT
);
CREATE INDEX IF NOT EXISTS ix_patches_vault_status ON patch_proposals(vault_id, approval_status);

CREATE TABLE IF NOT EXISTS capability_grants (
    grant_id TEXT PRIMARY KEY,
    principal_id TEXT NOT NULL,
    vault_id TEXT REFERENCES vaults(vault_id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    scope_json TEXT NOT NULL,
    constraints_json TEXT NOT NULL DEFAULT '{}',
    approval_mode TEXT NOT NULL,
    granted_at TEXT NOT NULL,
    expires_at TEXT,
    revoked_at TEXT
);
CREATE INDEX IF NOT EXISTS ix_grants_principal ON capability_grants(principal_id, action, expires_at);

CREATE TABLE IF NOT EXISTS audit_events (
    event_id TEXT PRIMARY KEY,
    vault_id TEXT REFERENCES vaults(vault_id) ON DELETE SET NULL,
    actor_id TEXT NOT NULL,
    action TEXT NOT NULL,
    object_id TEXT,
    trace_id TEXT,
    details_redacted_json TEXT NOT NULL DEFAULT '{}',
    created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_audit_trace ON audit_events(trace_id, created_at);

CREATE TABLE IF NOT EXISTS publications (
    publication_id TEXT PRIMARY KEY,
    vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE CASCADE,
    manifest_hash TEXT NOT NULL,
    build_hash TEXT,
    target_id TEXT,
    state TEXT NOT NULL CHECK(state IN ('preview','ready','deployed','failed','rolled_back')),
    created_at TEXT NOT NULL,
    deployed_at TEXT
);

CREATE TABLE IF NOT EXISTS projection_watermarks (
    vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE CASCADE,
    projection_name TEXT NOT NULL,
    last_event_id TEXT,
    last_processed_at TEXT,
    PRIMARY KEY(vault_id, projection_name)
);

-- Example FTS query (never string-interpolate untrusted query directly):
-- SELECT chunk_id, title, snippet(chunks_fts, 3, '<mark>', '</mark>', '…', 20)
-- FROM chunks_fts WHERE chunks_fts MATCH ? ORDER BY rank LIMIT ?;

-- ---------------------------------------------------------------------------------------------------------
-- Knowledge Packs & books (see CHITKALA_KNOWLEDGE_PACKS_AND_TEXTBOOKS.md). Design seed, NOT a migration.
-- An installed pack is mounted as a vault with kind='pack'; its documents/chunks/edges use the tables above.
-- ---------------------------------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS registries (
    registry_id TEXT PRIMARY KEY,
    url TEXT NOT NULL UNIQUE,                 -- https://…, file://…, or a USB/intranet path
    title TEXT NOT NULL,
    pinned_key_id TEXT NOT NULL,              -- trust-on-first-use, shown as a fingerprint
    last_synced_at TEXT,
    enabled INTEGER NOT NULL DEFAULT 1 CHECK(enabled IN (0,1))
);

CREATE TABLE IF NOT EXISTS publisher_keys (
    key_id TEXT PRIMARY KEY,                  -- e.g. ed25519:<fingerprint>
    publisher_name TEXT NOT NULL,
    public_key TEXT NOT NULL,
    registry_id TEXT REFERENCES registries(registry_id) ON DELETE SET NULL,
    trust TEXT NOT NULL DEFAULT 'registry' CHECK(trust IN ('registry','user-pinned','institution-pinned')),
    revoked_at TEXT,
    revocation_reason TEXT
);

CREATE TABLE IF NOT EXISTS library_packs (
    pack_id TEXT NOT NULL,                    -- reverse-DNS id
    edition TEXT NOT NULL,
    revision TEXT NOT NULL,
    title TEXT NOT NULL,
    profile TEXT NOT NULL CHECK(profile IN ('textbook','reference','course','repository','medical')),
    publisher_key_id TEXT NOT NULL REFERENCES publisher_keys(key_id),
    manifest_hash TEXT NOT NULL,
    files_digest TEXT NOT NULL,
    license_spdx TEXT NOT NULL,
    entitlement TEXT NOT NULL CHECK(entitlement IN ('open','registered','paid','institutional')),
    ai_policy TEXT NOT NULL CHECK(ai_policy IN ('local-only','external-with-consent','publisher-hosted-only')),
    effective_date TEXT,
    review_by TEXT,
    registry_id TEXT REFERENCES registries(registry_id) ON DELETE SET NULL,
    PRIMARY KEY(pack_id, edition, revision)
);

CREATE TABLE IF NOT EXISTS library_installs (
    install_id TEXT PRIMARY KEY,
    pack_id TEXT NOT NULL,
    edition TEXT NOT NULL,
    revision TEXT NOT NULL,
    vault_id TEXT NOT NULL UNIQUE REFERENCES vaults(vault_id) ON DELETE CASCADE,  -- the read-only mount
    install_path TEXT NOT NULL,
    state TEXT NOT NULL CHECK(state IN ('downloading','verifying','indexing','ready','superseded','failed','removed')),
    verified_at TEXT,
    index_source TEXT NOT NULL DEFAULT 'prebuilt' CHECK(index_source IN ('prebuilt','rebuilt','lexical-only')),
    lease_expires_at TEXT,                    -- paid/institutional offline lease (usability contract, not DRM)
    installed_at TEXT NOT NULL,
    FOREIGN KEY(pack_id, edition, revision) REFERENCES library_packs(pack_id, edition, revision)
);
CREATE INDEX IF NOT EXISTS ix_installs_pack ON library_installs(pack_id, state);

CREATE TABLE IF NOT EXISTS pack_partitions (
    install_id TEXT NOT NULL REFERENCES library_installs(install_id) ON DELETE CASCADE,
    partition_id TEXT NOT NULL,
    title TEXT NOT NULL,
    document_count INTEGER NOT NULL CHECK(document_count >= 0),
    installed INTEGER NOT NULL DEFAULT 0 CHECK(installed IN (0,1)),
    PRIMARY KEY(install_id, partition_id)
);

CREATE TABLE IF NOT EXISTS overlays (
    overlay_id TEXT PRIMARY KEY,
    user_vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE CASCADE,
    overlay_document_id TEXT REFERENCES documents(document_id) ON DELETE CASCADE,  -- the Markdown note holding it
    pack_id TEXT NOT NULL,
    edition TEXT NOT NULL,
    revision TEXT NOT NULL,
    target_document_id TEXT NOT NULL,
    anchor_json TEXT NOT NULL,                -- W3C-style selectors: textQuote, position, textHash, heading path
    anchor_status TEXT NOT NULL DEFAULT 'exact'
      CHECK(anchor_status IN ('exact','relocated','needs-review','orphaned')),
    kind TEXT NOT NULL CHECK(kind IN ('highlight','note','link')),
    updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_overlays_target ON overlays(pack_id, target_document_id);

CREATE TABLE IF NOT EXISTS book_projects (
    book_id TEXT PRIMARY KEY,
    vault_id TEXT NOT NULL REFERENCES vaults(vault_id) ON DELETE CASCADE,
    root_path TEXT NOT NULL,                  -- folder containing book.yaml
    profile TEXT NOT NULL CHECK(profile IN ('textbook','reference','course','repository','medical')),
    title TEXT NOT NULL,
    UNIQUE(vault_id, root_path)
);

CREATE TABLE IF NOT EXISTS book_editions (
    book_id TEXT NOT NULL REFERENCES book_projects(book_id) ON DELETE CASCADE,
    edition TEXT NOT NULL,
    revision TEXT NOT NULL DEFAULT 'r0',
    state TEXT NOT NULL CHECK(state IN ('draft','in-review','frozen','published','superseded','retired')),
    manifest_hash TEXT,                       -- set at freeze
    erratum_severity TEXT CHECK(erratum_severity IN ('editorial','content','safety-critical')),
    frozen_at TEXT,
    published_at TEXT,
    PRIMARY KEY(book_id, edition, revision)
);

CREATE TABLE IF NOT EXISTS review_signoffs (
    signoff_id TEXT PRIMARY KEY,
    proposal_id TEXT NOT NULL REFERENCES patch_proposals(proposal_id) ON DELETE CASCADE,
    book_id TEXT NOT NULL REFERENCES book_projects(book_id) ON DELETE CASCADE,
    reviewer_id TEXT NOT NULL,
    reviewer_role TEXT NOT NULL CHECK(reviewer_role IN ('editor','peer-reviewer','clinical-reviewer','publisher')),
    proposal_hash TEXT NOT NULL,              -- approval binds to the exact proposal content
    decision TEXT NOT NULL CHECK(decision IN ('approve','request-changes','reject')),
    rule_ids_json TEXT NOT NULL DEFAULT '[]', -- which review rules this sign-off satisfies
    signed_at TEXT NOT NULL,
    UNIQUE(proposal_id, reviewer_id)
);
