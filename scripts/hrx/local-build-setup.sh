#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel)"

. "${SCRIPT_DIR}/local-env.sh"

"${SCRIPT_DIR}/checkout-hrx.sh"
"${SCRIPT_DIR}/checkout-llama.sh"
"${SCRIPT_DIR}/fetch-rocm-assets.sh"
