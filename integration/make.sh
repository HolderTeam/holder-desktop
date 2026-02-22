#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-linux}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec python3 "${SCRIPT_DIR}/run.py" "${MODE}"
