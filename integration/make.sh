#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-linux}"

require_cmd() {
  local cmd="$1"
  local hint="$2"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing dependency: ${cmd}" >&2
    echo "${hint}" >&2
    exit 1
  fi
}

run_linux() {
  require_cmd behave "Ubuntu: sudo apt install python3-behave"
  local app_path="${HOLDER_FRONTEND_APP_PATH:-../frontends/linux/build/holder-linux}"
  HOLDER_FRONTEND_TARGET=linux \
    behave holder_frontend_tests/features \
      -D app_path="${app_path}" \
      --tags "linux"
}

case "${MODE}" in
  deps-ubuntu)
    echo "sudo apt update"
    echo "sudo apt install -y python3-behave python3-dogtail xvfb at-spi2-core dbus-x11 x11-utils"
    ;;
  install-dev)
    require_cmd python3 "Install Python 3 from your package manager."
    python3 -m pip install -e .[linux]
    ;;
  linux)
    run_linux
    ;;
  *)
    echo "Usage: $0 [deps-ubuntu|install-dev|linux]"
    exit 2
    ;;
esac
