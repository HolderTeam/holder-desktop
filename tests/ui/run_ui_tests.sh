#!/usr/bin/env bash
set -euo pipefail

if [[ "${RUN_UI_TESTS:-0}" != "1" ]]; then
  echo "UI tests skipped (set RUN_UI_TESTS=1)"
  exit 0
fi

if [[ "${1:-}" != "--inner" ]]; then
  runtime_dir="$(mktemp -d /tmp/holder-linux-ui-runtime.XXXXXX)"
  chmod 700 "${runtime_dir}"
  XDG_RUNTIME_DIR="${runtime_dir}" dbus-run-session -- \
    xvfb-run -a -s "-screen 0 1920x1080x24" \
    "$0" --inner "$@"
  status=$?
  rm -rf "${runtime_dir}" || true
  exit "${status}"
fi

shift
BUILD_DIR="$1"
SOURCE_DIR="$2"
TEST_SCRIPT="${3:-tests/ui/test_smoke.py}"
APP_PATH="${BUILD_DIR}/holder-linux"

if [[ ! -x "${APP_PATH}" ]]; then
  echo "Missing app binary: ${APP_PATH}" >&2
  exit 1
fi

export NO_AT_BRIDGE=0
export GTK_A11Y=atspi
export PYTHONUNBUFFERED=1
export GSETTINGS_BACKEND=memory
export GTK_USE_PORTAL=0

exec timeout 120s python3 "${SOURCE_DIR}/${TEST_SCRIPT}" "${APP_PATH}"
