#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-behave-linux}"

require_cmd() {
  local cmd="$1"
  local hint="$2"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing dependency: ${cmd}" >&2
    echo "${hint}" >&2
    exit 1
  fi
}

run_with_isolated_backend() {
  local repo_root
  repo_root="$(cd .. && pwd)"
  local holder_dir="${HOLDER_DIR:-${repo_root}/../holder}"
  local holder_backend_bin="${HOLDER_BACKEND_BIN:-${holder_dir}/build/holder}"
  holder_dir="$(realpath "${holder_dir}")"
  holder_backend_bin="$(realpath "${holder_backend_bin}")"

  if [[ ! -x "${holder_backend_bin}" ]]; then
    echo "Missing Holder backend binary: ${holder_backend_bin}" >&2
    echo "Build it first (e.g. in ${holder_dir}) or set HOLDER_BACKEND_BIN." >&2
    exit 1
  fi

  require_cmd mktemp "Install coreutils from your package manager."

  local xdg_root
  xdg_root="$(mktemp -d /tmp/holder-integration-xdg.XXXXXX)"
  chmod 700 "${xdg_root}"

  local old_data="${XDG_DATA_HOME:-}"
  local old_config="${XDG_CONFIG_HOME:-}"
  local old_cache="${XDG_CACHE_HOME:-}"
  export XDG_DATA_HOME="${xdg_root}/data"
  export XDG_CONFIG_HOME="${xdg_root}/config"
  export XDG_CACHE_HOME="${xdg_root}/cache"
  mkdir -p "${XDG_DATA_HOME}" "${XDG_CONFIG_HOME}" "${XDG_CACHE_HOME}"

  local backend_log="${xdg_root}/holder-backend.log"
  (
    cd "${holder_dir}"
    XDG_DATA_HOME="${XDG_DATA_HOME}" \
      XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
      XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
      "${holder_backend_bin}" --bind 127.0.0.1 --port 0
  ) >"${backend_log}" 2>&1 &
  local backend_pid=$!

  cleanup_backend() {
    if kill -0 "${backend_pid}" >/dev/null 2>&1; then
      kill "${backend_pid}" >/dev/null 2>&1 || true
      wait "${backend_pid}" >/dev/null 2>&1 || true
    fi
    if [[ -n "${old_data}" ]]; then
      export XDG_DATA_HOME="${old_data}"
    else
      unset XDG_DATA_HOME || true
    fi
    if [[ -n "${old_config}" ]]; then
      export XDG_CONFIG_HOME="${old_config}"
    else
      unset XDG_CONFIG_HOME || true
    fi
    if [[ -n "${old_cache}" ]]; then
      export XDG_CACHE_HOME="${old_cache}"
    else
      unset XDG_CACHE_HOME || true
    fi
    rm -rf "${xdg_root}" || true
  }

  local info_path="${XDG_DATA_HOME}/holder/server/holder.json"
  for _ in $(seq 1 150); do
    if [[ -f "${info_path}" ]]; then
      break
    fi
    sleep 0.1
  done
  if [[ ! -f "${info_path}" ]]; then
    echo "Timed out waiting for backend info file: ${info_path}" >&2
    echo "Backend log: ${backend_log}" >&2
    tail -n 80 "${backend_log}" >&2 || true
    cleanup_backend
    exit 1
  fi

  if command -v curl >/dev/null 2>&1; then
    mapfile -t holder_info < <(
      python3 - "$info_path" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    obj = json.load(f)
print(obj.get("bind", "127.0.0.1"))
print(obj.get("port", 11499))
print(obj.get("auth_token", ""))
PY
    )
    local holder_bind="${holder_info[0]:-127.0.0.1}"
    local holder_port="${holder_info[1]:-11499}"
    local holder_token="${holder_info[2]:-}"
    local health_ok=0
    for _ in $(seq 1 100); do
      if curl -fsS \
        -H "Authorization: Bearer ${holder_token}" \
        "http://${holder_bind}:${holder_port}/health" >/dev/null; then
        health_ok=1
        break
      fi
      sleep 0.1
    done
    if [[ "${health_ok}" != "1" ]]; then
      echo "Timed out waiting for backend health check on ${holder_bind}:${holder_port}" >&2
      echo "Backend log: ${backend_log}" >&2
      tail -n 80 "${backend_log}" >&2 || true
      cleanup_backend
      exit 1
    fi
  fi

  "$@"
  local command_status=$?
  cleanup_backend
  return "${command_status}"
}

run_linux() {
  require_cmd behave "Ubuntu: sudo apt install python3-behave"
  local app_path="${HOLDER_FRONTEND_APP_PATH:-../frontends/linux/build/holder-desktop}"
  echo "Running: behave holder_frontend_tests/features -D app_path=${app_path} --tags=@linux --tags=-@backend"
  HOLDER_FRONTEND_TARGET=linux \
    behave holder_frontend_tests/features \
      -D app_path="${app_path}" \
      --tags=@linux \
      --tags=-@backend
}

run_linux_backend() {
  require_cmd behave "Ubuntu: sudo apt install python3-behave"
  local app_path="${HOLDER_FRONTEND_APP_PATH:-../frontends/linux/build/holder-desktop}"
  export HOLDER_FRONTEND_TARGET=linux
  echo "Running: behave holder_frontend_tests/features -D app_path=${app_path} --tags=@linux --tags=@backend"
  run_with_isolated_backend \
    behave holder_frontend_tests/features \
      -D app_path="${app_path}" \
      --tags=@linux \
      --tags=@backend
}

run_linux_ui_script() {
  local script_path="$1"
  local app_path="${HOLDER_FRONTEND_APP_PATH:-../frontends/linux/build/holder-desktop}"
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
  linux|behave-linux)
    run_linux
    ;;
  behave-linux-backend)
    run_linux_backend
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
    echo "Usage: $0 [deps-ubuntu|install-dev|behave-linux|behave-linux-backend|linux|ui-smoke|ui-create-card|ui-shortcut|ui-linux]"
    exit 2
    ;;
esac
