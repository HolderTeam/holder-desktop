#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-linux}"

run_linux() {
  local app_path="${HOLDER_FRONTEND_APP_PATH:-../frontends/linux/build/holder-linux}"
  HOLDER_FRONTEND_TARGET=linux \
    behave holder_frontend_tests/features \
      -D app_path="${app_path}" \
      --tags "linux"
}

case "${MODE}" in
  install-dev)
    python3 -m pip install -e .[linux]
    ;;
  linux)
    run_linux
    ;;
  *)
    echo "Usage: $0 [install-dev|linux]"
    exit 2
    ;;
esac
