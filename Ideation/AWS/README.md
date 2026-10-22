# CHITKALA on AWS

How CHITKALA's **optional** cloud services (identity, model relay, hosted index, cloud agent runs, managed publishing,
encrypted sync, later collaboration, and the Knowledge Library for textbooks and large repositories) would be built on
AWS, without giving up the local-first core.

| File | What it is |
|---|---|
| [`CHITKALA_AWS_ARCHITECTURE.md`](CHITKALA_AWS_ARCHITECTURE.md) | Detailed design: invariants, service choices, data model, each capability's flow, security, observability, DR, cost drivers, ADRs, spikes |
| [`CHITKALA_AWS_IMPLEMENTATION_PLAN.md`](CHITKALA_AWS_IMPLEMENTATION_PLAN.md) | Phased plan C0–C11, sequenced behind desktop milestones M1–M5, with work items, tests, exit gates and risks |
| [`architecture/index.html`](architecture/index.html) | Interactive docs page: play each numbered flow, build the overview up stage by stage (M0 → M5) |
| `architecture/svg/` | Animated SVGs (overview, 8 stage maps, 11 zoom-ins and concept diagrams) |
| `architecture/drawio/` | Editable draw.io files |
| [`diagrams/arch_specs.py`](diagrams/arch_specs.py) | The diagrams as code: the source of truth for every picture |

## Diagrams

| Diagram | Shows |
|---|---|
| `chitkala-aws-overview` | Every service, 28 numbered steps, 8 stages (M0 → K) |
| `chitkala-sync` | E2EE sync: content-addressed ciphertext in S3, DynamoDB head compare-and-swap, push to other devices |
| `chitkala-intelligence` | Relay mode vs hosted-index mode; consent, Guardrails, Aurora hybrid retrieval |
| `chitkala-agent-run` | Step Functions run, policy broker, Fargate sandbox, review and commit on the desktop |
| `chitkala-publish` | Allowlisted bundle, isolated Astro build, Macie, CloudFront pointer promote/rollback |
| `chitkala-collab` | Later: Yjs relay forwarding encrypted updates |
| `chitkala-trust-zones` | The TDD's trust zones extended to AWS controls |
| `chitkala-delivery` | GitHub OIDC CI/CD, multi-account Organizations, signed desktop releases |
| `chitkala-textbook-pipeline` | Reviews → validate → PHI scan → render site/PDF/EPUB → build pack → KMS signing → release |
| `chitkala-library-install` | Catalog, entitlements, institution SSO, signed-cookie delivery, verify-and-mount, errata, mirrors, USB |
| `chitkala-hosted-repository` | Static edition sites at scale, OpenSearch hybrid search, "ask this book" with grounding checks |
| `chitkala-code-architecture` | TypeScript frontend → generated contracts → Tauri / Axum / Lambda hosts → one Rust service layer → crates |

## Rebuild

```bash
./diagrams/build.sh        # Python 3.10+, standard library only
```

The engine (`diagrams/tools/archlib.py`, `build_arch.py`) and the icons it uses are vendored from the
*Marvellous AWS Architectures Docs* skill, so the repo builds on its own. AWS icons are from the official AWS
Architecture Icons (see `diagrams/tools/icons/SOURCE.md`).

All backend services are Rust (shared crates with the desktop and self-host server); see
[`../CHITKALA_PRIOR_ART_AND_STACK.md`](../CHITKALA_PRIOR_ART_AND_STACK.md). The product side of textbooks and packs is specified in
[`../CHITKALA_KNOWLEDGE_PACKS_AND_TEXTBOOKS.md`](../CHITKALA_KNOWLEDGE_PACKS_AND_TEXTBOOKS.md).

**Status:** proposed design. Nothing here is implemented.
