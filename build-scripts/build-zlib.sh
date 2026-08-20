#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_workdir "${1:-}"
require_command cmake
require_command ninja
require_toolchain
SOURCE=$(source_dir zlib)
BUILD=$(build_dir zlib)
PREFIX=$(prefix_dir zlib)

cmake -S "$SOURCE" -B "$BUILD" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_SYSTEM_NAME=Emscripten \
    -DCMAKE_TOOLCHAIN_FILE="$SCRIPT_DIR/emscripten-toolchain.cmake" \
    -DCMAKE_OSX_ARCHITECTURES= \
    -DCMAKE_OSX_SYSROOT= \
    -DZLIB_BUILD_TESTING=OFF \
    -DZLIB_BUILD_SHARED=OFF
cmake --build "$BUILD" --target install --parallel "$(build_jobs)"
