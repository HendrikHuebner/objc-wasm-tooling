#!/usr/bin/env bash
set -euo pipefail

BIN_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WORKDIR=$(CDPATH= cd -- "$BIN_DIR/../.." && pwd)
SOURCE="$WORKDIR/emscripten"
LLVM_ROOT="$WORKDIR/build-llvm-project/install/bin"
BINARYEN_ROOT="$WORKDIR/build-binaryen/install"

[[ -f "$SOURCE/emcc.py" ]] || {
    echo "error: missing Emscripten checkout: $SOURCE" >&2
    exit 1
}
[[ -d "$LLVM_ROOT" ]] || {
    echo "error: missing LLVM install: $LLVM_ROOT" >&2
    exit 1
}

[[ -x "$BINARYEN_ROOT/bin/wasm-opt" ]] || {
    echo "error: missing Binaryen install: $BINARYEN_ROOT/bin/wasm-opt" >&2
    exit 1
}

case "$(basename -- "$0")" in
    emcc) TARGET=emcc.py ;;
    em++) TARGET=em++.py ;;
    emar) TARGET=emar.py ;;
    emranlib) TARGET=emranlib.py ;;
    emcmake) TARGET=emcmake.py ;;
    *) echo "error: unsupported Emscripten entry point: $0" >&2; exit 1 ;;
esac

export EMSDK="$WORKDIR/emsdk"
export EMSDK_ROOT="$WORKDIR/emsdk"
export EMSCRIPTEN="$SOURCE"
export EMSCRIPTEN_ROOT="$SOURCE"
export EM_CONFIG="$WORKDIR/build-emscripten/emscripten.config"
export LLVM_ROOT
export BINARYEN_ROOT
export PATH="$BIN_DIR:$LLVM_ROOT:$BINARYEN_ROOT:$PATH"

exec python3 "$SOURCE/$TARGET" "$@"
