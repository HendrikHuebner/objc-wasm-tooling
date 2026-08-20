#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_workdir "${1:-}"
require_command cmake
require_command ninja
require_toolchain
SOURCE=$(source_dir qtbase)
BUILD=$(build_dir qtbase)
PREFIX=$(prefix_dir qtbase)
CCACHE_CMAKE_ARGS=()
if command -v ccache >/dev/null 2>&1; then
    CCACHE_CMAKE_ARGS=(
        -DCMAKE_C_COMPILER_LAUNCHER=ccache
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
    )
fi
QT_HOST_PATH=${QT_HOST_PATH:-${2:-}}
if [[ -z "$QT_HOST_PATH" ]]; then
    QT_HOST_PATH="$WORKDIR/build-qtbase-host/install"
    HOST_BUILD="$WORKDIR/build-qtbase-host"
    mkdir -p "$HOST_BUILD" "$QT_HOST_PATH"
    if [[ ! -x "$QT_HOST_PATH/bin/qtpaths" && ! -x "$QT_HOST_PATH/bin/qmake" ]]; then
        host_path_backup=${PATH:-}
        unset EMSCRIPTEN EMSCRIPTEN_ROOT EM_CONFIG CC CXX OBJC OBJCXX AR RANLIB
        unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS LIBS
        export PATH="$host_path_backup"
        host_cache="$HOST_BUILD/CMakeCache.txt"
        host_ccache_ready=true
        if command -v ccache >/dev/null 2>&1 &&
           ! grep -q 'CMAKE_C_COMPILER_LAUNCHER:STRING=ccache' "$host_cache" 2>/dev/null; then
            host_ccache_ready=false
        fi
        if [[ ! -f "$host_cache" || "$host_ccache_ready" != true ]]; then
            cd "$HOST_BUILD"
            "$SOURCE/configure" \
                -release -static -prefix "$QT_HOST_PATH" \
                -nomake examples -nomake tests -no-feature-opengl \
                -cmake-generator Ninja -- \
                "${CCACHE_CMAKE_ARGS[@]}"
        fi
        cmake --build "$HOST_BUILD" --parallel "$(build_jobs)"
        cmake --install "$HOST_BUILD"
    fi
fi
[[ -n "$QT_HOST_PATH" && -d "$QT_HOST_PATH" ]] || die "could not create a native Qt host prefix"
require_toolchain

cd "$BUILD"
"$SOURCE/configure" \
    -qt-host-path "$QT_HOST_PATH" \
    -platform wasm-emscripten \
    -static \
    -no-feature-thread \
    -feature-wasm-exceptions \
    -cmake-generator Ninja \
    -nomake examples \
    -nomake tests \
    -prefix "$PREFIX" \
    -release \
    -- \
    -DCMAKE_C_FLAGS='-fwasm-exceptions -sWASM_LEGACY_EXCEPTIONS=0' \
    -DCMAKE_CXX_FLAGS='-fwasm-exceptions -sWASM_LEGACY_EXCEPTIONS=0' \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
    "${CCACHE_CMAKE_ARGS[@]}"
cmake --build "$BUILD" --parallel "$(build_jobs)"
cmake --install "$BUILD"
