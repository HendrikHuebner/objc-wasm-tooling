#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_workdir "${1:-}"
require_command cmake
require_command ninja
require_toolchain
SOURCE=$(source_dir libobjc2)
BUILD=$(build_dir libobjc2)
PREFIX=$(prefix_dir libobjc2)

cmake -S "$SOURCE" -B "$BUILD" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_SYSTEM_NAME=Emscripten \
    -DCMAKE_TOOLCHAIN_FILE="$SCRIPT_DIR/emscripten-toolchain.cmake" \
    -DCMAKE_OSX_ARCHITECTURES= \
    -DCMAKE_OSX_SYSROOT= \
    -DLIBOBJC_WASM=ON \
    -DBUILD_SHARED_LIBOBJC=OFF \
    -DBUILD_STATIC_LIBOBJC=ON \
    -DEMBEDDED_BLOCKS_RUNTIME=ON \
    -DOLDABI_COMPAT=OFF \
    -DTESTS=OFF
cmake --build "$BUILD" --target objc-static --parallel "$(build_jobs)"
cmake --install "$BUILD"

# GNUstep Base expects this compatibility header under ObjectiveC2/ while
# libobjc2 installs it under objc/.
mkdir -p "$PREFIX/include/ObjectiveC2"
rm -f "$PREFIX/include/ObjectiveC2/blocks_runtime.h"
printf '#include <objc/blocks_runtime.h>\n' > "$PREFIX/include/ObjectiveC2/blocks_runtime.h"
