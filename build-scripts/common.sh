#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

die() {
    echo "error: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_workdir() {
    [[ $# -eq 1 ]] || die "usage: $(basename "$0") WORKDIR"
    WORKDIR=$(CDPATH= cd -- "$1" 2>/dev/null && pwd) || die "workdir does not exist: $1"
    export WORKDIR
    if command -v ccache >/dev/null 2>&1; then
        export CCACHE_DIR="${CCACHE_DIR:-$WORKDIR/.ccache}"
        mkdir -p "$CCACHE_DIR"
        export CCACHE_TEMPDIR="${CCACHE_TEMPDIR:-$CCACHE_DIR/tmp}"
        mkdir -p "$CCACHE_TEMPDIR"
    fi
}

source_dir() {
    local project=$1
    local path="$WORKDIR/$project"
    [[ -d "$path" ]] || die "missing checkout: $path (run download-deps.py first)"
    printf '%s\n' "$path"
}

gnustep_makefiles() {
    if [[ -n "${GNUSTEP_MAKEFILES:-}" && -d "$GNUSTEP_MAKEFILES" ]]; then
        printf '%s\n' "$GNUSTEP_MAKEFILES"
        return
    fi
    local prefix candidate
    if command -v brew >/dev/null 2>&1; then
        prefix=$(brew --prefix gnustep-make 2>/dev/null || true)
        for candidate in "$prefix/Library/GNUstep/Makefiles" "$prefix/share/GNUstep/Makefiles"; do
            [[ -d "$candidate" ]] && { printf '%s\n' "$candidate"; return; }
        done
    fi
    for candidate in \
        /opt/homebrew/opt/gnustep-make/share/GNUstep/Makefiles \
        /opt/homebrew/opt/gnustep-make/Library/GNUstep/Makefiles \
        /usr/local/opt/gnustep-make/share/GNUstep/Makefiles \
        /usr/local/opt/gnustep-make/Library/GNUstep/Makefiles \
        /usr/GNUstep/System/Library/Makefiles \
        /usr/local/GNUstep/System/Library/Makefiles \
        /usr/share/GNUstep/Makefiles; do
        [[ -d "$candidate" ]] && { printf '%s\n' "$candidate"; return; }
    done
    die "GNUstep Makefiles not found; install gnustep-make with Homebrew or set GNUSTEP_MAKEFILES"
}

gnustep_make_command() {
    local candidate version wrapper_dir
    if command -v gmake >/dev/null 2>&1; then
        candidate=$(command -v gmake)
    elif command -v make >/dev/null 2>&1; then
        version=$(make --version 2>/dev/null | head -n 1 || true)
        [[ "$version" == *"GNU Make"* ]] || die "GNUstep Make requires GNU make (install make with Homebrew)"
        candidate=$(command -v make)
    else
        die "GNUstep Make requires GNU make (install make with Homebrew)"
    fi
    wrapper_dir="$WORKDIR/build-gnustep-tools/bin"
    mkdir -p "$wrapper_dir"
    rm -f "$wrapper_dir/gmake"
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$candidate" > "$wrapper_dir/gmake"
    chmod 755 "$wrapper_dir/gmake"
    printf '%s\n' "$wrapper_dir"
}

build_dir() {
    local project=$1
    mkdir -p "$WORKDIR/build-$project"
    printf '%s\n' "$WORKDIR/build-$project"
}

prefix_dir() {
    local project=$1
    printf '%s\n' "$WORKDIR/build-$project/install"
}

build_jobs() {
    if [[ -n "${JOBS:-}" ]]; then
        printf '%s\n' "$JOBS"
    elif command -v nproc >/dev/null 2>&1; then
        nproc
    elif command -v sysctl >/dev/null 2>&1; then
        sysctl -n hw.ncpu
    else
        printf '2\n'
    fi
}

require_toolchain() {
    local toolchain="$WORKDIR/build-emscripten/bin"
    [[ -x "$toolchain/em++" ]] || die "Emscripten is not built: $toolchain/em++"
    export PATH="$toolchain:$WORKDIR/build-llvm-project/install/bin:$PATH"
    export EMSCRIPTEN_ROOT="$WORKDIR/emscripten"
    export EMSCRIPTEN="$WORKDIR/emscripten"
    export EMSDK="$WORKDIR/emscripten"
    export EM_CONFIG="$WORKDIR/build-emscripten/emscripten.config"
    export CC="$toolchain/emcc"
    export CXX="$toolchain/em++"
    export OBJC="$toolchain/emcc"
    export OBJCXX="$toolchain/em++"
    export AR="$toolchain/emar"
    export RANLIB="$toolchain/emranlib"
}

binaryen_root() {
    if [[ -n "${BINARYEN_ROOT:-}" ]]; then
        printf '%s\n' "$BINARYEN_ROOT"
        return
    fi
    local wasm_opt
    wasm_opt=$(command -v wasm-opt 2>/dev/null) || die "wasm-opt not found; set BINARYEN_ROOT"
    CDPATH= cd -- "$(dirname -- "$wasm_opt")" && pwd
}
