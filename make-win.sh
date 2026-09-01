#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${BUILD_DIR:-build-win}"
MODE="${1:-test}"
MESON_SETUP_ARGS=(
  -Dterminal=true
)

packages=(
  git
  base-devel
  mingw-w64-ucrt-x86_64-meson
  mingw-w64-ucrt-x86_64-ninja
  mingw-w64-ucrt-x86_64-pkgconf
  mingw-w64-ucrt-x86_64-vala
  mingw-w64-ucrt-x86_64-gtk4
  mingw-w64-ucrt-x86_64-libadwaita
  mingw-w64-ucrt-x86_64-gtksourceview5
  mingw-w64-ucrt-x86_64-libspelling
  mingw-w64-ucrt-x86_64-libgee
  mingw-w64-ucrt-x86_64-libsoup3
  mingw-w64-ucrt-x86_64-json-glib
)

setup_build() {
  local ninja_file="${BUILD_DIR}/build.ninja"

  if [[ ! -f "${ninja_file}" ]]; then
    meson setup "${BUILD_DIR}" "${MESON_SETUP_ARGS[@]}"
    return
  fi

  meson setup "${BUILD_DIR}" --reconfigure "${MESON_SETUP_ARGS[@]}"
}

refresh_compiled_schemas() {
  # glib-compile-schemas scans the schema directory, so Meson may miss schema renames.
  rm -f "${BUILD_DIR}/data/gschemas.compiled"
}

install_deps() {
  pacman -S --needed --noconfirm "${packages[@]}"
}

build() {
  setup_build
  refresh_compiled_schemas
  meson compile -C "${BUILD_DIR}"
}

test_only() {
  build
  local schema_dir="${PWD}/${BUILD_DIR}/data"

  GSETTINGS_BACKEND=memory GSETTINGS_SCHEMA_DIR="${schema_dir}" \
    meson test -C "${BUILD_DIR}" --print-errorlogs
}

run_app() {
  build

  local schema_dir="${PWD}/${BUILD_DIR}/data"
  local app_path="./${BUILD_DIR}/holder-desktop.exe"

  GSETTINGS_SCHEMA_DIR="${schema_dir}" "${app_path}"
}

case "${MODE}" in
  deps)
    install_deps
    ;;
  build)
    build
    ;;
  test)
    test_only
    ;;
  run)
    run_app
    ;;
  *)
    echo "Usage: $0 [deps|build|test|run]"
    exit 2
    ;;
esac
