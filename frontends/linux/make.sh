#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${BUILD_DIR:-build}"
COVERAGE_BUILD_DIR="${COVERAGE_BUILD_DIR:-build-coverage}"
MODE="${1:-run}"

setup_build() {
  local dir="$1"
  shift
  meson setup "${dir}" --reconfigure "$@"
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
  meson test -C "${COVERAGE_BUILD_DIR}" --print-errorlogs

  local out_dir="${COVERAGE_BUILD_DIR}/coverage"
  mkdir -p "${out_dir}"

  gcovr \
    --root . \
    --object-directory "${COVERAGE_BUILD_DIR}" \
    --filter 'src/' \
    --exclude 'tests/' \
    --gcov-executable gcov-13 \
    --gcov-ignore-errors all \
    --txt \
    --output "${out_dir}/summary-lines.txt"

  gcovr \
    --root . \
    --object-directory "${COVERAGE_BUILD_DIR}" \
    --filter 'src/' \
    --exclude 'tests/' \
    --gcov-executable gcov-13 \
    --gcov-ignore-errors all \
    --txt \
    --txt-metric branch \
    --output "${out_dir}/summary-branches.txt"

  gcovr \
    --root . \
    --object-directory "${COVERAGE_BUILD_DIR}" \
    --filter 'src/' \
    --exclude 'tests/' \
    --gcov-executable gcov-13 \
    --gcov-ignore-errors all \
    --html-details "${out_dir}/index.html" \
    --html-title "holder-desktop coverage"

  echo "Coverage line summary:   ${out_dir}/summary-lines.txt"
  echo "Coverage branch summary: ${out_dir}/summary-branches.txt"
  echo "Coverage HTML:    ${out_dir}/index.html"
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
