#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_workdir "${1:-}"
require_toolchain
SOURCE=$(source_dir icu)/icu4c/source
HOST_BUILD=$(build_dir icu-host)
BUILD=$(build_dir icu)
PREFIX=$(prefix_dir icu)

HOST_CC=${HOST_CC:-cc}
HOST_CXX=${HOST_CXX:-c++}
HOST_AR=${HOST_AR:-ar}
HOST_RANLIB=${HOST_RANLIB:-ranlib}
HOST_BUILD_TRIPLE=${HOST_BUILD_TRIPLE:-$(sh "$SOURCE/config.guess")}
HOST_CFLAGS=${HOST_CFLAGS:-}
HOST_CXXFLAGS=${HOST_CXXFLAGS:-}
HOST_CPPFLAGS=${HOST_CPPFLAGS:-}
HOST_LDFLAGS=${HOST_LDFLAGS:-}
HOST_LIBS=${HOST_LIBS:-}
CCACHE_BIN=$(command -v ccache || true)
if [[ -n "$CCACHE_BIN" ]]; then
    HOST_CC="$CCACHE_BIN $HOST_CC"
    HOST_CXX="$CCACHE_BIN $HOST_CXX"
fi
cd "$HOST_BUILD"
env CC="$HOST_CC" CXX="$HOST_CXX" AR="$HOST_AR" RANLIB="$HOST_RANLIB" \
    CFLAGS="$HOST_CFLAGS" CXXFLAGS="$HOST_CXXFLAGS" \
    CPPFLAGS="$HOST_CPPFLAGS" LDFLAGS="$HOST_LDFLAGS" LIBS="$HOST_LIBS" \
    "$SOURCE/configure" --prefix="$HOST_BUILD/install" \
    --disable-tests --disable-samples --disable-extras --enable-tools \
    --enable-static --disable-shared \
    --srcdir="$SOURCE" \
    --build="$HOST_BUILD_TRIPLE"
make -C "$HOST_BUILD" CC="$HOST_CC" CXX="$HOST_CXX" -j"$(build_jobs)"

export CFLAGS="${CFLAGS:-} -Wno-version-check"
export CXXFLAGS="${CXXFLAGS:-} -Wno-version-check"
if [[ -n "$CCACHE_BIN" ]]; then
    export CC="$CCACHE_BIN $CC"
    export CXX="$CCACHE_BIN $CXX"
fi
cd "$BUILD"
"$SOURCE/configure" --host=wasm32-unknown-emscripten \
    --prefix="$PREFIX" --disable-tests --disable-samples \
    --disable-extras --disable-tools --enable-static --disable-shared \
    --with-cross-build="$HOST_BUILD"
make CC="$CC" CXX="$CXX" -j"$(build_jobs)"
make install
