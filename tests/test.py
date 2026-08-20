from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess
import tomllib


TESTS_ROOT = Path(__file__).resolve().parent


def run_case(case: Path, workdir: Path, args: argparse.Namespace) -> bool:
    with (case / "test.toml").open("rb") as stream:
        recipe = tomllib.load(stream)

    source = case / recipe["source"]
    build = workdir / "build-tests"
    build.mkdir(parents=True, exist_ok=True)
    output = build / f"{case.name}.js"
    compiler = Path(args.emxx or workdir / "build-emscripten" / "bin" / "em++")
    runtime = Path(args.runtime or workdir / "build-libobjc2" / "libobjc.a")
    include = Path(args.objc_include or workdir / "build-libobjc2" / "install" / "include")
    suite = recipe.get("suite", "runtime")
    base_prefix = workdir / "build-libs-base" / "install"
    base_archive = base_prefix / "lib" / "libgnustep-base.a"
    ffi_prefix = workdir / "build-libffi" / "install"
    ffi_archive = ffi_prefix / "lib" / "libffi.a"
    include_paths = [include]
    libraries = [runtime]
    if suite == "library":
        include_paths.insert(0, base_prefix / "include")
        include_paths.insert(1, ffi_prefix / "include")
        libraries = ["-Wl,--whole-archive", base_archive,
                     "-Wl,--no-whole-archive", runtime, ffi_archive]

    required = [compiler, runtime, include]
    if suite == "library":
        required.extend([base_prefix / "include", base_archive,
                         ffi_prefix / "include", ffi_archive])
    missing = [str(path) for path in required if not path.exists()]
    if missing and not args.dry_run:
        print("missing source-built test dependency:")
        for path in missing:
            print(f"  {path}")
        return False

    command = [
        str(compiler), str(source),
        "-fobjc-runtime=gnustep-2.0",
        "-fconstant-string-class=NXConstantString",
        "-fwasm-exceptions", "-sWASM_LEGACY_EXCEPTIONS=0",
        "-sSUPPORT_LONGJMP=wasm", "-Wl,--stack-first",
        "-sALLOW_TABLE_GROWTH",
        "-sDEFAULT_LIBRARY_FUNCS_TO_INCLUDE=$stackAlloc",
        "-Wno-js-compiler",
        *sum((["-I", str(path)] for path in include_paths), []),
        *recipe.get("flags", []), *map(str, libraries), "-o", str(output),
    ]
    print("+", " ".join(command))
    if args.dry_run:
        return True

    environment = os.environ.copy()
    environment.update({
        "EM_CONFIG": str(workdir / "build-emscripten" / "emscripten.config"),
        "EM_CACHE": str(workdir / "build-emscripten" / "cache"),
        "EMSCRIPTEN_ROOT": str(workdir / "emscripten"),
        "LLVM_ROOT": str(workdir / "build-llvm-project" / "install" / "bin"),
        "BINARYEN_ROOT": str(workdir / "build-binaryen" / "install"),
        "PATH": ":".join([
            str(workdir / "build-emscripten" / "bin"),
            str(workdir / "build-llvm-project" / "install" / "bin"),
            str(workdir / "build-binaryen" / "install" / "bin"),
            environment.get("PATH", ""),
        ]),
    })
    (workdir / "build-emscripten" / "cache").mkdir(parents=True, exist_ok=True)
    subprocess.run(command, check=True, env=environment)

    node = args.node or "node"
    result = subprocess.run(
        [node, "--experimental-wasm-exnref", str(output)],
        check=False, text=True, capture_output=True, env=environment,
    )
    print(result.stdout, end="")
    print(result.stderr, end="")
    if result.returncode != 0:
        print(f"FAIL: Node exited with {result.returncode}")
        return False
    expected = recipe.get("expected")
    if expected and expected not in result.stdout.splitlines():
        print(f"FAIL: expected output line {expected!r}")
        return False
    return True


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run Objective-C language/runtime/library Wasm integration tests.")
    parser.add_argument("--workdir", type=Path, default=TESTS_ROOT.parent / "build")
    parser.add_argument("--case", help="run one test directory")
    parser.add_argument("--suite", choices=("runtime", "library", "all"), default="runtime",
                        help="test suite to run (default: runtime)")
    parser.add_argument("--list", action="store_true", help="list tests")
    parser.add_argument("--keep-going", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--emxx", help="override the source-built em++ path")
    parser.add_argument("--runtime", help="override the libobjc.a path")
    parser.add_argument("--objc-include", help="override libobjc2 include path")
    parser.add_argument("--node", help="Node.js executable")
    args = parser.parse_args(argv)
    args.workdir = args.workdir.resolve()

    cases = sorted(
        path for path in TESTS_ROOT.iterdir()
        if (path / "test.toml").exists()
        and (args.suite == "all" or tomllib.loads((path / "test.toml").read_text()).get("suite", "runtime") == args.suite)
    )
    if args.case:
        cases = [case for case in cases if case.name == args.case]
    if not cases:
        print("No matching tests.")
        return 1
    if args.list:
        print("\n".join(case.name for case in cases))
        return 0

    passed_cases = []
    failed_cases = []
    for case in cases:
        print(f"==> {case.name}")
        try:
            passed = run_case(case, args.workdir, args)
        except subprocess.CalledProcessError as error:
            print(f"FAIL: command exited with {error.returncode}")
            passed = False
        if not passed:
            failed_cases.append(case.name)
        else:
            passed_cases.append(case.name)

    print("\nTest summary")
    print(f"  Passed: {len(passed_cases)}")
    print(f"  Failed: {len(failed_cases)}")
    if passed_cases:
        print("  Passed cases: " + ", ".join(passed_cases))
    if failed_cases:
        print("  Failed cases: " + ", ".join(failed_cases))
    return len(failed_cases)


if __name__ == "__main__":
    raise SystemExit(main())
