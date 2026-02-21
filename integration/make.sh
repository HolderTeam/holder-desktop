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

run_linux_ui_script() {
  local script_path="$1"
  local app_path="${HOLDER_FRONTEND_APP_PATH:-../frontends/linux/build/holder-linux}"
  local repo_root
  repo_root="$(cd .. && pwd)"

  require_cmd python3 "Ubuntu: sudo apt install python3"
  require_cmd xvfb-run "Ubuntu: sudo apt install xvfb"
  require_cmd dbus-run-session "Ubuntu: sudo apt install dbus-x11"

  RUN_UI_TESTS=1 \
    "${PWD}/linux_ui/run_ui_tests.sh" \
    "${script_path}" \
    "${app_path}" \
    "${repo_root}"
}

run_linux_ui_smoke() {
  run_linux_ui_script "${PWD}/linux_ui/test_smoke.py"
}

run_linux_ui_create_card() {
  RUN_UI_BACKEND_TESTS=1 RUN_UI_AUTOSTART_BACKEND=1 \
    run_linux_ui_script "${PWD}/linux_ui/test_create_card.py"
}

run_linux_ui_shortcut() {
  RUN_UI_BACKEND_TESTS=1 RUN_UI_AUTOSTART_BACKEND=1 RUN_UI_SHORTCUT_TESTS=1 \
    run_linux_ui_script "${PWD}/linux_ui/test_create_card_shortcut.py"
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
  ui-smoke)
    run_linux_ui_smoke
    ;;
  ui-create-card)
    run_linux_ui_create_card
    ;;
  ui-shortcut)
    run_linux_ui_shortcut
    ;;
  ui-linux)
    run_linux_ui_smoke
    run_linux_ui_create_card
    ;;
  *)
    echo "Usage: $0 [deps-ubuntu|install-dev|linux|ui-smoke|ui-create-card|ui-shortcut|ui-linux]"
    exit 2
    ;;
esac
