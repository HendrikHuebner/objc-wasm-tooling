# objc-wasm-tooling

Small Linux/macOS tooling for a pinned GNUstep Objective-C WebAssembly build.
The repository is being rebuilt in small steps. The first step is only source
acquisition: [`dependencies.toml`](dependencies.toml) is the source of truth
for repository URLs and commits, and [`download-deps.py`](download-deps.py)
creates lazy partial checkouts under `deps/`.

List the pinned repositories:

```sh
./download-deps.py --list
```

Fetch every pinned checkout:

```sh
./download-deps.py
```

Fetch only the repositories needed for the first toolchain bring-up:

```sh
./download-deps.py --only llvm-project emscripten libobjc2 libs-make libs-base
```

The downloader reuses an existing checkout when it is already at the pinned
commit. It refuses to replace a dirty checkout.
