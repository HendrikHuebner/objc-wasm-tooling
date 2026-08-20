#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_workdir "${1:-}"
require_toolchain
SOURCE=$(source_dir libs-corebase)
BUILD=$(build_dir libs-corebase)
PREFIX=$(prefix_dir libs-corebase)
BASE_PREFIX="$WORKDIR/build-libs-base/install"
ICU_PREFIX="$WORKDIR/build-icu/install"

export GNUSTEP_MAKEFILES=$(gnustep_makefiles)
MAKE_PREFIX=$(CDPATH= cd -- "$GNUSTEP_MAKEFILES/../../.." && pwd)
MAKE_BIN=$(gnustep_make_command)
export PATH="$MAKE_BIN:$MAKE_PREFIX/libexec:$MAKE_PREFIX/bin:$PATH"
export OBJC_RUNTIME_LIB=ng
export RUNTIME_VERSION=gnustep-2.0
export FOUNDATION_LIB=gnu
export GUI_LIB=none
export LIBRARY_COMBO=ng-gnu-none
export OBJC_LIB_FLAG=-lobjc
export CC="$WORKDIR/build-emscripten/bin/emcc"
export CXX="$WORKDIR/build-emscripten/bin/em++"
export OBJC="$WORKDIR/build-emscripten/bin/em++"
export OBJCXX="$WORKDIR/build-emscripten/bin/em++"
export CPPFLAGS="${CPPFLAGS:-} -fobjc-runtime=gnustep-2.0 -I$WORKDIR/build-libobjc2/install/include -I$BASE_PREFIX/include -I$BASE_PREFIX/include/Foundation -I$ICU_PREFIX/include"
export LDFLAGS="${LDFLAGS:-} -L$WORKDIR/build-libobjc2/install/lib -L$BASE_PREFIX/lib -L$ICU_PREFIX/lib -lobjc -fwasm-exceptions -sWASM_LEGACY_EXCEPTIONS=0 -sDEFAULT_TO_CXX=1 -sSUPPORT_LONGJMP=wasm -Wl,--stack-first"
export LIBS="${LIBS:-} -lobjc"
export ICU_CFLAGS="-I$ICU_PREFIX/include"
export ICU_LIBS="-L$ICU_PREFIX/lib -licui18n -licuuc -licudata"
export ac_cv_search_objc_getClass=-lobjc

cd "$BUILD"
"$SOURCE/configure" --host=wasm32-unknown-emscripten \
    --target=wasm32-unknown-emscripten --prefix="$PREFIX" \
    --without-gcd --with-zoneinfo=/usr/share/zoneinfo
ln -sf "$SOURCE/Version" "$BUILD/Version"
ln -sf "$BUILD/Source/config.h" "$SOURCE/Source/config.h"
ln -sf "$BUILD/Source/GNUmakefile" "$SOURCE/Source/GNUmakefile"
ln -sf "$BUILD/Headers/CoreFoundation/CFBase.h" "$SOURCE/Headers/CoreFoundation/CFBase.h"
LIB_LINK_CMD="$WORKDIR/build-emscripten/bin/emar rcs \$@ \$^"
MAKE_INSTALL_VARS="GNUSTEP_LOCAL_LIBRARY=$PREFIX GNUSTEP_LOCAL_LIBRARIES=$PREFIX/lib GNUSTEP_LOCAL_HEADERS=$PREFIX/include"
MAKE_INCLUDE_FLAGS="-I$SOURCE/Headers -I$WORKDIR/build-libobjc2/install/include -I$BASE_PREFIX/include -I$ICU_PREFIX/include -include unistd.h -U_NATIVE_OBJC_EXCEPTIONS"
MAKE_INCLUDE_VARS=(
  "CC=$WORKDIR/build-emscripten/bin/emcc"
  "CXX=$WORKDIR/build-emscripten/bin/em++"
  "OBJC=$WORKDIR/build-emscripten/bin/em++"
  "CFLAGS=$MAKE_INCLUDE_FLAGS"
  "OBJCFLAGS=$MAKE_INCLUDE_FLAGS"
  "ADDITIONAL_CFLAGS=$MAKE_INCLUDE_FLAGS -DBUILDING_SELF"
  "ADDITIONAL_OBJCFLAGS=$MAKE_INCLUDE_FLAGS -DBUILDING_SELF"
)
make -C "$SOURCE/Source" AR=emar RANLIB=emranlib shared=no LIB_LINK_CMD="$LIB_LINK_CMD" "${MAKE_INCLUDE_VARS[@]}" -j"$(build_jobs)"
make -C "$SOURCE/Source" AR=emar RANLIB=emranlib shared=no LIB_LINK_CMD="$LIB_LINK_CMD" "${MAKE_INCLUDE_VARS[@]}" $MAKE_INSTALL_VARS install
