#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_workdir "${1:-}"
require_toolchain
SOURCE=$(source_dir libs-base)
if [[ "${LIBS_BASE_SHARED:-no}" == yes ]]; then
    BUILD=$(build_dir libs-base-side)
    PREFIX=$(prefix_dir libs-base-side)
else
    BUILD=$(build_dir libs-base)
    PREFIX=$(prefix_dir libs-base)
fi
FFI_PREFIX=$(prefix_dir libffi)
MAKEFILES=$(gnustep_makefiles)
MAKE_PREFIX=$(CDPATH= cd -- "$MAKEFILES/../../.." && pwd)
MAKE_BIN=$(gnustep_make_command)
BUILD_TRIPLET=$("$MAKEFILES/config.guess")

export GNUSTEP_MAKEFILES="$MAKEFILES"
export PATH="$MAKE_BIN:$MAKE_PREFIX/libexec:$MAKE_PREFIX/bin:$PATH"
export OBJC_RUNTIME_LIB=ng
export RUNTIME_VERSION=gnustep-2.0
export FOUNDATION_LIB=gnu
export GUI_LIB=none
export LIBRARY_COMBO=ng-gnu-none
export OBJC_LIB_FLAG=-lobjc
export gs_cv_objc_works=yes
export cross_gs_cv_objc_works=yes
export cross_objc2_runtime=1
export cross_non_fragile=yes
export cross_gs_cv_objc_compiler_supports_constant_string_class=yes
export cross_gs_cv_objc_load_method_worked=yes
export ac_cv_func_objc_sync_enter=yes
export ac_cv_func_objc_sync_exit=yes
export ac_cv_func_objc_enumerationMutation=yes
export ac_cv_func_objc_setEnumerationMutationHandler=no
export ac_cv_func_objc_setProperty=yes
export ac_cv_func__Block_copy=yes
export CC="$WORKDIR/build-emscripten/bin/emcc"
export CXX="$WORKDIR/build-emscripten/bin/em++"
export CPP="$WORKDIR/build-emscripten/bin/emcc -E"
export OBJC="$WORKDIR/build-emscripten/bin/em++"
export OBJCXX="$WORKDIR/build-emscripten/bin/em++"
export CFLAGS="${CFLAGS:-} -fconstant-string-class=NXConstantString -fwasm-exceptions -sWASM_LEGACY_EXCEPTIONS=0 -sSUPPORT_LONGJMP=wasm"
export OBJCFLAGS="${OBJCFLAGS:-} $CFLAGS"
export CPPFLAGS="${CPPFLAGS:-} -fobjc-runtime=gnustep-2.0 -DOBJC2RUNTIME=1 -I$WORKDIR/build-libobjc2/install/include -I$FFI_PREFIX/include"
export LDFLAGS="${LDFLAGS:-} -L$WORKDIR/build-libobjc2/install/lib -L$FFI_PREFIX/lib -lobjc -lffi -fwasm-exceptions -sWASM_LEGACY_EXCEPTIONS=0 -sDEFAULT_TO_CXX=1 -sSUPPORT_LONGJMP=wasm -Wl,--stack-first"
export LIBS="${LIBS:-} -lobjc -lffi"
export PKG_CONFIG=/usr/bin/false

cd "$BUILD"
cross_objc2_runtime=1 cross_non_fragile=yes "$SOURCE/configure" \
    --build="$BUILD_TRIPLET" \
    --host=wasm32-unknown-emscripten \
    --prefix="$PREFIX" \
    --enable-libffi \
    --disable-ffcall \
    --enable-invocations \
    --disable-newkvo \
    --disable-iconv \
    --disable-xml \
    --disable-xslt \
    --disable-tls \
    --disable-zeroconf \
    --disable-icu \
    --disable-libdispatch \
    --disable-nsurlsession \
    --disable-bfd \
    --disable-procfs \
    --disable-environment-config-file \
    --disable-importing-config-file \
    --with-installation-domain=LOCAL \
    --enable-pass-arguments \
    --disable-fake-main \
    --enable-nxconstantstring \
    cross_objc2_runtime=1 \
    cross_non_fragile=yes

# Emscripten emits runnable JS during configure, so Autoconf may incorrectly
# run the ObjC2/non-fragile probes instead of using the cross-build values.
sed -i.bak \
    -e 's/OBJC2RUNTIME 0/OBJC2RUNTIME 1/' \
    -e 's/GS_NONFRAGILE     0/GS_NONFRAGILE     1/' \
    "$BUILD/Headers/GNUstepBase/GSConfig.h"
rm -f "$BUILD/Headers/GNUstepBase/GSConfig.h.bak"
sed -i.bak '/^#define off_t /d' "$BUILD/Headers/GNUstepBase/config.h"
rm -f "$BUILD/Headers/GNUstepBase/config.h.bak"
sed -i.bak 's/^OBJC2RUNTIME=0$/OBJC2RUNTIME=1/' "$BUILD/config.mak"
rm -f "$BUILD/config.mak.bak"
ln -sf "$BUILD/base.make" "$SOURCE/base.make"
ln -sf "$BUILD/config.mak" "$SOURCE/config.mak"
ln -sf "$BUILD/config.status" "$SOURCE/config.status"
ln -sf "$BUILD/Source/gnustep-base.pc" "$SOURCE/Source/gnustep-base.pc"
ln -sf "$BUILD/Headers/GNUstepBase/config.h" "$SOURCE/Headers/GNUstepBase/config.h"
ln -sf "$BUILD/Headers/GNUstepBase/GSConfig.h" "$SOURCE/Headers/GNUstepBase/GSConfig.h"
ln -sf "$BUILD/Headers/GNUstepBase/config.h" "$SOURCE/Source/config.h"
ln -sf "$BUILD/Headers/GNUstepBase/GSConfig.h" "$SOURCE/Source/GNUstepBase/GSConfig.h"
if [[ "${LIBS_BASE_SHARED:-no}" == yes ]]; then
    SHARED_LIB_LINK_CMD='$(CC) -sSIDE_MODULE=1 $(ALL_LDFLAGS) -o $(LIB_LINK_OBJ_DIR)/$(LIB_LINK_VERSION_FILE) $^ $(INTERNAL_LIBRARIES_DEPEND_UPON) $(SHARED_LD_POSTFLAGS)'
    make -C "$SOURCE/Source" GNUSTEP_BUILD_DIR="$BUILD" GNUSTEP_TARGET_OS=emscripten GNUSTEP_TARGET_CPU=wasm32 \
        AR=emar RANLIB=emranlib OBJC2RUNTIME=1 shared=yes base=yes add=no \
        HAVE_SHARED_LIBS=yes SHARED_LIBEXT=.wasm SHARED_CFLAGS=-fPIC \
        SHARED_LIB_LINK_CMD="$SHARED_LIB_LINK_CMD" -j"$(build_jobs)"
    make -C "$SOURCE/Source" GNUSTEP_BUILD_DIR="$BUILD" GNUSTEP_TARGET_OS=emscripten GNUSTEP_TARGET_CPU=wasm32 \
        AR=emar RANLIB=emranlib OBJC2RUNTIME=1 shared=yes base=yes add=no \
        HAVE_SHARED_LIBS=yes SHARED_LIBEXT=.wasm SHARED_CFLAGS=-fPIC \
        SHARED_LIB_LINK_CMD="$SHARED_LIB_LINK_CMD" \
        GNUSTEP_LOCAL_LIBRARY="$PREFIX" GNUSTEP_LOCAL_LIBRARIES="$PREFIX/lib" GNUSTEP_LOCAL_HEADERS="$PREFIX/include" install
    exit 0
fi
LIB_LINK_CMD="$WORKDIR/build-emscripten/bin/emar rcs "'$@ $^'
MAKE_INSTALL_VARS="GNUSTEP_LOCAL_LIBRARY=$PREFIX GNUSTEP_LOCAL_LIBRARIES=$PREFIX/lib GNUSTEP_LOCAL_HEADERS=$PREFIX/include"
make -C "$SOURCE/Source" AR=emar RANLIB=emranlib OBJC2RUNTIME=1 shared=no base=yes add=no LIB_LINK_CMD="$LIB_LINK_CMD" -j1
make -C "$SOURCE/Source" AR=emar RANLIB=emranlib OBJC2RUNTIME=1 shared=no base=yes add=no LIB_LINK_CMD="$LIB_LINK_CMD" $MAKE_INSTALL_VARS install
