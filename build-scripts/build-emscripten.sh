#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_workdir "${1:-}"
require_command python3
require_command node
require_command npm
SOURCE=$(source_dir emscripten)
[[ -d "$WORKDIR/build-llvm-project/install/bin" ]] || die "build LLVM before Emscripten"
[[ -x "$WORKDIR/build-binaryen/install/bin/wasm-opt" ]] || die "build Binaryen before Emscripten"
BUILD=$(build_dir emscripten)
BIN="$BUILD/bin"
mkdir -p "$BIN"

BINARYEN="$WORKDIR/build-binaryen/install"
NODE=$(command -v node)
LLVM="$WORKDIR/build-llvm-project/install/bin"
CONFIG="$BUILD/emscripten.config"

python3 - "$CONFIG" "$LLVM" "$BINARYEN" "$NODE" <<'PY'
from pathlib import Path
import sys

config, llvm, binaryen, node = map(Path, sys.argv[1:])
config.write_text(
    f"LLVM_ROOT = {str(llvm)!r}\n"
    f"BINARYEN_ROOT = {str(binaryen)!r}\n"
    f"NODE_JS = {str(node)!r}\n"
)
PY

export EMSDK="$WORKDIR/emsdk"
export EMSDK_ROOT="$WORKDIR/emsdk"
export EMSCRIPTEN="$SOURCE"
export EMSCRIPTEN_ROOT="$SOURCE"
export EM_CONFIG="$CONFIG"
export LLVM_ROOT="$LLVM"
export BINARYEN_ROOT="$BINARYEN"
export PATH="$BIN:$LLVM:$BINARYEN:$PATH"

# bootstrap.py asks about installing developer git hooks when stdin is a TTY.
# Builds must be unattended, and the hooks are not part of the toolchain.
python3 "$SOURCE/bootstrap.py" </dev/null
for name in emcc em++ emar emranlib emcmake; do
    ln -sfn "$SCRIPT_DIR/emscripten-wrapper.sh" "$BIN/$name"
done

"$BIN/em++" --version
