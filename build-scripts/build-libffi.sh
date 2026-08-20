#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_workdir "${1:-}"
require_toolchain
SOURCE=$(source_dir libffi)
BUILD=$(build_dir libffi)
PREFIX=$(prefix_dir libffi)

if [[ ! -x "$SOURCE/configure" ]]; then
    require_command autoreconf
    (cd "$SOURCE" && ./autogen.sh && autoreconf -fi)
fi
[[ -x "$SOURCE/configure" ]] || die "libffi configure was not generated; install autoconf, automake, and libtool"

export CFLAGS="${CFLAGS:-} -fwasm-exceptions -sWASM_LEGACY_EXCEPTIONS=0 -sSUPPORT_LONGJMP=wasm"
export CXXFLAGS="${CXXFLAGS:-} $CFLAGS"
cd "$BUILD"
"$SOURCE/configure" --host=wasm32-unknown-emscripten \
    --prefix="$PREFIX" --disable-shared --enable-static --disable-docs
make MAKEINFO=true -j"$(build_jobs)"
make MAKEINFO=true install
