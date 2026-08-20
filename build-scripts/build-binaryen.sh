#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_workdir "${1:-}"
require_command cmake
require_command ninja
SOURCE=$(source_dir binaryen)
BUILD=$(build_dir binaryen)
PREFIX=$(prefix_dir binaryen)

cmake -S "$SOURCE" -B "$BUILD" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DBUILD_TESTS=OFF
cmake --build "$BUILD" --target install --parallel "$(build_jobs)"

