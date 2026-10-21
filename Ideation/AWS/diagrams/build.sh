#!/usr/bin/env bash
# Rebuild every CHITKALA-on-AWS diagram from arch_specs.py (Python 3.10+, standard library only).
# Engine: tools/archlib.py, vendored from the Marvellous AWS Architectures Docs skill; icons in tools/icons.
set -euo pipefail
cd "$(dirname "$0")"
python3 tools/build_arch.py arch_specs.py --out ../architecture \
  --title "CHITKALA on AWS — architecture" \
  --intro "Optional AWS services around CHITKALA's local-first core. Press ▶ to follow each numbered flow, or use the stage chips (M0 → M5) to build the overview up milestone by milestone."
