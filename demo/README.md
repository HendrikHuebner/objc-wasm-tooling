# Qt and Objective-C WebAssembly demo

This demo combines an Objective-C model with a Qt Widgets view/controller. It
also provides a headless mode for Node that checks the model and both
Objective-C and C++ exception paths without opening a browser.

Build Qt for WebAssembly first with [build-all.sh](../build-scripts/build-all.sh).
The Qt prefix is normally:

```text
workdir/build-qtbase/install
```

Then configure and build from the repository root:

```sh
QT_PREFIX="$PWD/workdir/build-qtbase/install"
BUILD="$PWD/build/demo"
export EMSDK="$PWD/workdir/build-emscripten"
export EM_CONFIG="$EMSDK/emscripten.config"
export EM_CACHE="$EMSDK/cache"
export PATH="$EMSDK/bin:$PWD/workdir/build-llvm-project/install/bin:$PWD/workdir/build-binaryen/install/bin:$PATH"

"$QT_PREFIX/bin/qt-cmake" \
  -S demo -B "$BUILD" -G Ninja \
  -DOBJC_RUNTIME="$PWD/workdir/build-libobjc2/libobjc.a" \
  -DOBJC_INCLUDE="$PWD/workdir/build-libobjc2/install/include" \
  -DBASE_INCLUDE="$PWD/workdir/build-libs-base/install/include" \
  -DBASE_ARCHIVE="$PWD/workdir/build-libs-base/install/lib/libgnustep-base.a" \
  -DFFI_INCLUDE="$PWD/workdir/build-libffi/install/include" \
  -DFFI_ARCHIVE="$PWD/workdir/build-libffi/install/lib/libffi.a"
cmake --build "$BUILD"
```

Run the UI with a local static-file server:

```sh
python3 -m http.server 8080 --directory "$BUILD"
```

Open `http://127.0.0.1:8080/objc-wasm-mvc.html`.

Run the UI-independent check with Node:

```sh
node --experimental-wasm-exnref -e \
  "const create=require('$BUILD/objc-wasm-mvc.js'); create({arguments:['--headless']}).then(() => process.exit(0)).catch(error => { console.error(error); process.exit(1); })"
```
