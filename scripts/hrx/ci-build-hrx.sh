#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/checkout-hrx.sh"
. "${SCRIPT_DIR}/fetch-rocm-assets.sh"
"${SCRIPT_DIR}/build-hrx.sh"
