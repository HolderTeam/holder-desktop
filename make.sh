#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${BUILD_DIR:-build}"
COVERAGE_BUILD_DIR="${COVERAGE_BUILD_DIR:-build-coverage}"
MODE="${1:-run}"

setup_build() {
  local dir="$1"
  shift
  if [[ -f "${dir}/build.ninja" ]]; then
    meson setup "${dir}" --reconfigure "$@"
  else
    meson setup "${dir}" "$@"
  fi
}

build() {
  setup_build "${BUILD_DIR}"
  meson compile -C "${BUILD_DIR}"
}

test_only() {
  build
  meson test -C "${BUILD_DIR}" --print-errorlogs
}

run_app() {
  test_only
  "./${BUILD_DIR}/holder-desktop"
}

coverage() {
  setup_build "${COVERAGE_BUILD_DIR}" -Db_coverage=true
  meson compile -C "${COVERAGE_BUILD_DIR}"
  GSETTINGS_BACKEND=memory meson test -C "${COVERAGE_BUILD_DIR}" --print-errorlogs

  local out_dir="${COVERAGE_BUILD_DIR}/coverage"
  mkdir -p "${out_dir}"
  local -a gcovr_common_flags=(
    --root .
    --object-directory "${COVERAGE_BUILD_DIR}"
    --filter 'src/'
    --exclude 'tests/'
    --gcov-executable gcov-13
    --gcov-ignore-errors all
    --exclude-unreachable-branches
    --exclude-throw-branches
    --exclude-function-lines
  )

  gcovr \
    "${gcovr_common_flags[@]}" \
    --txt \
    --txt-metric line \
    --output "${out_dir}/summary-lines.txt"

  gcovr \
    "${gcovr_common_flags[@]}" \
    --txt \
    --txt-metric branch \
    --output "${out_dir}/summary-branches.txt"

  gcovr \
    "${gcovr_common_flags[@]}" \
    --html-details "${out_dir}/index.html" \
    --html-title "holder-desktop coverage"

  gcovr \
    "${gcovr_common_flags[@]}" \
    --json-pretty \
    --output "${out_dir}/coverage.json"

  echo "Coverage line summary:   ${out_dir}/summary-lines.txt"
  echo "Coverage branch summary: ${out_dir}/summary-branches.txt"
  echo "Coverage JSON:           ${out_dir}/coverage.json"
  echo "Coverage HTML:           ${out_dir}/index.html"
  cat "${out_dir}/summary-lines.txt"
  cat "${out_dir}/summary-branches.txt"
}

case "${MODE}" in
  build)
    build
    ;;
  test)
    test_only
    ;;
  run)
    run_app
    ;;
  coverage)
    coverage
    ;;
  *)
    echo "Usage: $0 [build|test|run|coverage]"
    exit 2
    ;;
esac
