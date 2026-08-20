#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_workdir "${1:-}"
require_command cmake
require_command ninja
require_command c++
SOURCE=$(source_dir llvm-project)
BUILD=$(build_dir llvm-project)
PREFIX=$(prefix_dir llvm-project)

CCACHE_ARGS=()
if command -v ccache >/dev/null 2>&1; then
    CCACHE_ARGS=(
        -DCMAKE_C_COMPILER_LAUNCHER=ccache
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
    )
fi

CONFIG_STAMP="$BUILD/.objc-wasm-tooling-config"
SOURCE_REV=$(git -C "$SOURCE" rev-parse HEAD 2>/dev/null || true)
SOURCE_STATE=$(git -C "$SOURCE" status --porcelain 2>/dev/null || true)
if command -v sha256sum >/dev/null 2>&1; then
    CONFIG_KEY=$(printf '%s\n%s\n%s\n' "$SOURCE_REV" "$SOURCE_STATE" "${CCACHE_ARGS[*]}" | sha256sum | awk '{print $1}')
else
    CONFIG_KEY=$(printf '%s\n%s\n%s\n' "$SOURCE_REV" "$SOURCE_STATE" "${CCACHE_ARGS[*]}" | shasum -a 256 | awk '{print $1}')
fi

# Existing build trees from before the stamp was introduced already contain
# their authoritative CMake configuration. Adopt them without reconfiguring;
# reconfiguration would regenerate LLVM's PCH files and invalidate the tree.
if [[ -f "$BUILD/CMakeCache.txt" && ! -f "$CONFIG_STAMP" ]]; then
    printf '%s\n' "$CONFIG_KEY" > "$CONFIG_STAMP"
fi

if [[ ! -f "$BUILD/CMakeCache.txt" || ! -f "$CONFIG_STAMP" || "$(cat "$CONFIG_STAMP")" != "$CONFIG_KEY" ]]; then
    cmake -S "$SOURCE/llvm" -B "$BUILD" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        '-DLLVM_ENABLE_PROJECTS=clang;lld' \
        -DLLVM_TARGETS_TO_BUILD=WebAssembly \
        -DLLVM_ENABLE_ASSERTIONS=OFF \
        -DLLVM_BUILD_TESTS=OFF \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_INCLUDE_BENCHMARKS=OFF \
        -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
        "${CCACHE_ARGS[@]}"
    printf '%s\n' "$CONFIG_KEY" > "$CONFIG_STAMP"
fi

cmake --build "$BUILD" --target install --parallel "$(build_jobs)"
