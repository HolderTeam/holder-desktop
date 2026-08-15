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

refresh_compiled_schemas() {
  local dir="$1"
  # glib-compile-schemas scans the schema directory, so Meson may miss schema renames.
  rm -f "${dir}/data/gschemas.compiled"
}

install_dev_desktop_assets() {
  local app_id="$1"
  local data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
  local desktop_dir="${data_home}/applications"
  local icon_theme_dir="${data_home}/icons/hicolor"
  local -a icon_sizes=(16 24 32 48 64 128 256 512)

  mkdir -p "${desktop_dir}"
  {
    while IFS= read -r line; do
      case "${line}" in
        Name=*)
          printf 'Name=Holder (Development)\n'
          ;;
        Exec=*)
          printf 'Exec=%s/%s/holder-desktop\n' "${PWD}" "${BUILD_DIR}"
          ;;
        Icon=*)
          printf 'Icon=%s\n' "${app_id}"
          ;;
        *)
          printf '%s\n' "${line}"
          ;;
      esac
    done < data/team.holder.Holder.desktop
  } > "${desktop_dir}/${app_id}.desktop"

  for size in "${icon_sizes[@]}"; do
    mkdir -p "${icon_theme_dir}/${size}x${size}/apps"
    cp \
      "data/icons/hicolor/${size}x${size}/apps/team.holder.Holder.png" \
      "${icon_theme_dir}/${size}x${size}/apps/team.holder.Holder.png"
    cp \
      "data/icons/hicolor/${size}x${size}/apps/team.holder.Holder.png" \
      "${icon_theme_dir}/${size}x${size}/apps/${app_id}.png"
  done

  if [[ ! -f "${icon_theme_dir}/index.theme" ]]; then
    {
      printf '[Icon Theme]\n'
      printf 'Name=Hicolor\n'
      printf 'Comment=Fallback icon theme\n'
      printf 'Directories='
      local sep=''
      for size in "${icon_sizes[@]}"; do
        printf '%s%sx%s/apps' "${sep}" "${size}" "${size}"
        sep=','
      done
      printf '\n\n'

      for size in "${icon_sizes[@]}"; do
        printf '[%sx%s/apps]\n' "${size}" "${size}"
        printf 'Size=%s\n' "${size}"
        printf 'Context=Applications\n'
        printf 'Type=Fixed\n\n'
      done
    } > "${icon_theme_dir}/index.theme"
  fi

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -f "${icon_theme_dir}" || true
  fi

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q "${desktop_dir}" || true
  fi
}

build() {
  setup_build "${BUILD_DIR}"
  refresh_compiled_schemas "${BUILD_DIR}"
  meson compile -C "${BUILD_DIR}"
}

test_only() {
  build
  meson test -C "${BUILD_DIR}" --print-errorlogs
}

run_app() {
  test_only
  local app_id="${HOLDER_DESKTOP_APPLICATION_ID:-team.holder.Holder.Devel}"
  install_dev_desktop_assets "${app_id}"
  HOLDER_DESKTOP_APPLICATION_ID="${app_id}" \
    XDG_DATA_DIRS="${PWD}/data:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" \
    "./${BUILD_DIR}/holder-desktop"
}

coverage() {
  setup_build "${COVERAGE_BUILD_DIR}" -Db_coverage=true
  refresh_compiled_schemas "${COVERAGE_BUILD_DIR}"
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
