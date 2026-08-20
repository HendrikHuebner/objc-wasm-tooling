#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
WORKDIR=${WORKDIR:-$ROOT/workdir}
BUILD=${DEMO_BUILD_DIR:-$ROOT/build/demo}
PORT=${PORT:-8080}
MODE=serve

usage() {
    cat <<EOF
Usage: $(basename "$0") [--build-only|--headless|--serve] [--port PORT]

Build the Qt/Objective-C WebAssembly demo using the source-built toolchain.

  --build-only  configure and build, then exit
  --headless    configure, build, and run the Node.js headless check
  --serve       configure, build, and serve the browser demo (default)
  --port PORT   HTTP port for --serve (default: $PORT)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build-only) MODE=build; shift ;;
        --headless) MODE=headless; shift ;;
        --serve) MODE=serve; shift ;;
        --port)
            [[ $# -ge 2 ]] || { echo "error: --port needs a value" >&2; exit 2; }
            PORT=$2
            shift 2
            ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

QT_PREFIX="$WORKDIR/build-qtbase/install"
EMSCRIPTEN_BUILD="$WORKDIR/build-emscripten"
LLVM_PREFIX="$WORKDIR/build-llvm-project/install"
BINARYEN_PREFIX="$WORKDIR/build-binaryen/install"

for required in \
    "$QT_PREFIX/bin/qt-cmake" \
    "$EMSCRIPTEN_BUILD/bin/em++" \
    "$WORKDIR/build-libobjc2/libobjc.a" \
    "$WORKDIR/build-libs-base/install/lib/libgnustep-base.a" \
    "$WORKDIR/build-libffi/install/lib/libffi.a"; do
    [[ -e "$required" ]] || {
        echo "error: missing $required; run build-scripts/build-all.sh first" >&2
        exit 1
    }
done

export EMSDK="$EMSCRIPTEN_BUILD"
export EM_CONFIG="$EMSCRIPTEN_BUILD/emscripten.config"
export EM_CACHE="$EMSCRIPTEN_BUILD/cache"
export EMSCRIPTEN_ROOT="$WORKDIR/emscripten"
export LLVM_ROOT="$LLVM_PREFIX/bin"
export BINARYEN_ROOT="$BINARYEN_PREFIX"
export PATH="$EMSCRIPTEN_BUILD/bin:$LLVM_PREFIX/bin:$BINARYEN_PREFIX/bin:$PATH"
mkdir -p "$EM_CACHE"

"$QT_PREFIX/bin/qt-cmake" \
    -S "$SCRIPT_DIR" -B "$BUILD" -G Ninja \
    -DOBJC_RUNTIME="$WORKDIR/build-libobjc2/libobjc.a" \
    -DOBJC_INCLUDE="$WORKDIR/build-libobjc2/install/include" \
    -DBASE_INCLUDE="$WORKDIR/build-libs-base/install/include" \
    -DBASE_ARCHIVE="$WORKDIR/build-libs-base/install/lib/libgnustep-base.a" \
    -DFFI_INCLUDE="$WORKDIR/build-libffi/install/include" \
    -DFFI_ARCHIVE="$WORKDIR/build-libffi/install/lib/libffi.a"
cmake --build "$BUILD"

if [[ "$MODE" == build ]]; then
    exit 0
fi

if [[ "$MODE" == headless ]]; then
    node --experimental-wasm-exnref -e \
        "const create=require('$BUILD/objc-wasm-mvc.js'); create({arguments:['--headless']}).then(() => process.exit(0)).catch(error => { console.error(error); process.exit(1); })"
    exit 0
fi

echo "Serving $BUILD at http://127.0.0.1:$PORT/objc-wasm-mvc.html"
exec python3 -m http.server "$PORT" --directory "$BUILD"
