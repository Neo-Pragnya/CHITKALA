# CHITKALA on AWS

How CHITKALA's **optional** cloud services (identity, model relay, hosted index, cloud agent runs, managed publishing,
encrypted sync, and later collaboration) would be built on AWS, without giving up the local-first core.

| File | What it is |
|---|---|
| [`CHITKALA_AWS_ARCHITECTURE.md`](CHITKALA_AWS_ARCHITECTURE.md) | Detailed design: invariants, service choices, data model, each capability's flow, security, observability, DR, cost drivers, ADRs, spikes |
| [`CHITKALA_AWS_IMPLEMENTATION_PLAN.md`](CHITKALA_AWS_IMPLEMENTATION_PLAN.md) | Phased plan C0–C7, sequenced behind desktop milestones M1–M5, with work items, tests, exit gates and risks |
| [`architecture/index.html`](architecture/index.html) | Interactive docs page: play each numbered flow, build the overview up stage by stage (M0 → M5) |
| `architecture/svg/` | Animated SVGs (overview, 7 stage maps, 7 zoom-ins) |
| `architecture/drawio/` | Editable draw.io files |
| [`diagrams/arch_specs.py`](diagrams/arch_specs.py) | The diagrams as code: the source of truth for every picture |

## Diagrams

| Diagram | Shows |
|---|---|
| `chitkala-aws-overview` | Every service, 24 numbered steps, 7 stages |
| `chitkala-sync` | E2EE sync: content-addressed ciphertext in S3, DynamoDB head compare-and-swap, push to other devices |
| `chitkala-intelligence` | Relay mode vs hosted-index mode; consent, Guardrails, Aurora hybrid retrieval |
| `chitkala-agent-run` | Step Functions run, policy broker, Fargate sandbox, review and commit on the desktop |
| `chitkala-publish` | Allowlisted bundle, isolated Astro build, Macie, CloudFront pointer promote/rollback |
| `chitkala-collab` | Later: Yjs relay forwarding encrypted updates |
| `chitkala-trust-zones` | The TDD's trust zones extended to AWS controls |
| `chitkala-delivery` | GitHub OIDC CI/CD, multi-account Organizations, signed desktop releases |

## Rebuild

```bash
./diagrams/build.sh        # Python 3.10+, standard library only
```

The engine (`diagrams/tools/archlib.py`, `build_arch.py`) and the icons it uses are vendored from the
*Marvellous AWS Architectures Docs* skill, so the repo builds on its own. AWS icons are from the official AWS
Architecture Icons (see `diagrams/tools/icons/SOURCE.md`).

**Status:** proposed design. Nothing here is implemented.
