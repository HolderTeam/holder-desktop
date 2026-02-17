#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${BUILD_DIR:-build}"

meson setup "${BUILD_DIR}" --reconfigure
meson compile -C "${BUILD_DIR}"
