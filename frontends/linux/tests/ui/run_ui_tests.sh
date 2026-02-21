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
BACKEND_PID=""
XDG_UI_ROOT=""

cleanup() {
  local status=$?
  if [[ -n "${BACKEND_PID}" ]] && kill -0 "${BACKEND_PID}" >/dev/null 2>&1; then
    kill "${BACKEND_PID}" >/dev/null 2>&1 || true
    wait "${BACKEND_PID}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${XDG_UI_ROOT}" ]]; then
    rm -rf "${XDG_UI_ROOT}" || true
  fi
  exit "${status}"
}

trap cleanup EXIT

if [[ ! -x "${APP_PATH}" ]]; then
  echo "Missing app binary: ${APP_PATH}" >&2
  exit 1
fi

XDG_UI_ROOT="$(mktemp -d /tmp/holder-linux-ui-xdg.XXXXXX)"
chmod 700 "${XDG_UI_ROOT}"
export XDG_DATA_HOME="${XDG_UI_ROOT}/data"
export XDG_CONFIG_HOME="${XDG_UI_ROOT}/config"
export XDG_CACHE_HOME="${XDG_UI_ROOT}/cache"
mkdir -p "${XDG_DATA_HOME}" "${XDG_CONFIG_HOME}" "${XDG_CACHE_HOME}"

if [[ "${RUN_UI_BACKEND_TESTS:-0}" == "1" && "${RUN_UI_AUTOSTART_BACKEND:-0}" == "1" ]]; then
  HOLDER_DIR="${HOLDER_DIR:-${SOURCE_DIR}/../../../holder}"
  HOLDER_BACKEND_BIN="${HOLDER_BACKEND_BIN:-${HOLDER_DIR}/build/holder}"
  HOLDER_DIR="$(realpath "${HOLDER_DIR}")"
  HOLDER_BACKEND_BIN="$(realpath "${HOLDER_BACKEND_BIN}")"

  if [[ ! -x "${HOLDER_BACKEND_BIN}" ]]; then
    echo "Missing Holder backend binary: ${HOLDER_BACKEND_BIN}" >&2
    echo "Build it first (e.g. in ${HOLDER_DIR}) or set HOLDER_BACKEND_BIN." >&2
    exit 1
  fi

  BACKEND_LOG="${XDG_UI_ROOT}/holder-backend.log"
  (
    cd "${HOLDER_DIR}"
    XDG_DATA_HOME="${XDG_DATA_HOME}" \
      XDG_CONFIG_HOME="${XDG_CONFIG_HOME}" \
      XDG_CACHE_HOME="${XDG_CACHE_HOME}" \
      "${HOLDER_BACKEND_BIN}" --bind 127.0.0.1 --port 0
  ) >"${BACKEND_LOG}" 2>&1 &
  BACKEND_PID=$!

  INFO_PATH="${XDG_DATA_HOME}/holder/server/holder.json"
  for _ in $(seq 1 150); do
    if [[ -f "${INFO_PATH}" ]]; then
      break
    fi
    sleep 0.1
  done
  if [[ ! -f "${INFO_PATH}" ]]; then
    echo "Timed out waiting for backend info file: ${INFO_PATH}" >&2
    echo "Backend log: ${BACKEND_LOG}" >&2
    tail -n 80 "${BACKEND_LOG}" >&2 || true
    exit 1
  fi

  if command -v curl >/dev/null 2>&1; then
    mapfile -t holder_info < <(
      python3 - "$INFO_PATH" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    obj = json.load(f)
print(obj.get("bind", "127.0.0.1"))
print(obj.get("port", 11499))
print(obj.get("auth_token", ""))
PY
    )
    HOLDER_BIND="${holder_info[0]:-127.0.0.1}"
    HOLDER_PORT="${holder_info[1]:-11499}"
    HOLDER_TOKEN="${holder_info[2]:-}"
    health_ok=0
    for _ in $(seq 1 100); do
      if curl -fsS \
        -H "Authorization: Bearer ${HOLDER_TOKEN}" \
        "http://${HOLDER_BIND}:${HOLDER_PORT}/health" >/dev/null; then
        health_ok=1
        break
      fi
      sleep 0.1
    done
    if [[ "${health_ok}" != "1" ]]; then
      echo "Timed out waiting for backend health check on ${HOLDER_BIND}:${HOLDER_PORT}" >&2
      echo "Backend log: ${BACKEND_LOG}" >&2
      tail -n 80 "${BACKEND_LOG}" >&2 || true
      exit 1
    fi
  fi
fi

export NO_AT_BRIDGE=0
export GTK_A11Y=atspi
export PYTHONUNBUFFERED=1
export GSETTINGS_BACKEND=memory
export GTK_USE_PORTAL=0

exec timeout 120s python3 "${SOURCE_DIR}/${TEST_SCRIPT}" "${APP_PATH}"
