# WebAssembly tooling for GNUStep Objective-C

This is still work in progress.

We currently require using patched versions of LLVM/clang, emscripten, libobjc2, libs-base in order to target WASM with Objective-C.

This repo contains a patch-based "build system" to run some basic integration tests and demos for Objective-C with emscripten.

I'm working on upstreaming some of these patches.

## Prerequisites

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

Apply Patches:
```
./build-scripts/patch-all.sh dependencies.toml --dir workdir
```

Build:
```
sh build-scripts/build-all.sh workdir  
```

Tests:
```
python3 tests/test.py --workdir workdir --suite all
```

## Objective-C in the browser demo

See demo directory.

This example runs a small Qt-UI in the webbrowser, with a small Objective-C Model-View-Controller separation to demonstrate KVO.

## Limitations

This _mostly_ works but there are some caveats, which should be addressed eventually

1. Emscripten "Dynamic Linking" does not work for Objective-C yet, due to more weird issues with emscripten trying to export internal symbols of the runtime to JavaScript and failing due to '$'s
2. When linking static archives with wasm-ld we currently need to set `--whole-archive` in order to prevent it from garbage collecting seemingly unreachable Objective-C symbols. Wasm-ld needs an `-ObjC` flag to prevent this while allowing linker-gc.
3. libobjc2's "block-to-IMP" isn't supported, because it mmap's `PROT_EXEC` pages to allocate IMP trampolines which is not possible in WASM.
4. libs-base is LGPL so generally be careful with static linking it in proprietary code
