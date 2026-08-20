# WebAssembly tooling for GNUStep Objective-C

This is still work in progress.

We currently require using patched versions of LLVM/clang, emscripten, libobjc2, libs-base in order to target WASM with Objective-C.

This repo contains a patch-based "build system" to run some basic integration tests and demos for Objective-C with emscripten.

I'm working on upstreaming some of these patches.

## Prerequisits

```
  python
  node
  cmake
  ninja
  make
  autoconf
  automake
  libtool
  ccache (Optional but always a good idea when messing with LLVM)
  gnustep-make
```

## Usage

Download all the repos/dependencies (Including some optional ones like qt, libffi, zlib, icu)
```
 python3 download-deps.py dependencies.toml --dir workdir
```

Build:
```
sh build-scripts/build-all.sh workdir  
```

Tests:
```
python3 tests/test.py --workdir workdir --suite all
```
