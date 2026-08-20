#!/usr/bin/env python3
"""Fetch the pinned source repositories into a local dependency directory.

Each checkout is a partial clone with no initial working tree.  The requested
commit is fetched and checked out only when that repository is missing or is
not already at the pinned revision.  Dirty checkouts are never overwritten.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import subprocess
import sys
import tomllib


ROOT = Path(__file__).resolve().parent


@dataclass(frozen=True)
class Repository:
    name: str
    url: str
    commit: str
    branch: str | None = None


def load_repositories(path: Path) -> list[Repository]:
    with path.open("rb") as stream:
        data = tomllib.load(stream)
    result = [
        Repository(
            name=item["name"],
            url=item["url"],
            commit=item["commit"],
            branch=item.get("branch"),
        )
        for item in data.get("repository", [])
    ]
    if not result:
        raise ValueError(f"{path} does not contain any [[repository]] entries")
    names = [repository.name for repository in result]
    if len(names) != len(set(names)):
        raise ValueError(f"{path} contains duplicate repository names")
    return result


def run(
    command: list[str], *, cwd: Path | None = None, quiet: bool = False
) -> str:
    print("+", " ".join(command))
    try:
        completed = subprocess.run(
            command,
            cwd=cwd,
            check=True,
            text=True,
            capture_output=True,
        )
    except subprocess.CalledProcessError as error:
        if error.stdout:
            print(error.stdout, end="")
        if error.stderr:
            print(error.stderr, end="", file=sys.stderr)
        raise
    if completed.stdout and not quiet:
        print(completed.stdout, end="")
    if completed.stderr and not quiet:
        print(completed.stderr, end="", file=sys.stderr)
    return completed.stdout.strip()


def checkout(repository: Repository, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)

    if not destination.exists():
        clone = [
            "git", "clone", "--filter=blob:none",
        ]
        if repository.branch:
            clone.extend(["--branch", repository.branch])
        clone.extend([repository.url, str(destination)])
        run(clone)
    elif not (destination / ".git").exists():
        raise RuntimeError(
            f"{destination} exists but is not a Git checkout; refusing to remove it"
        )

    current = run(["git", "rev-parse", "HEAD"], cwd=destination, quiet=True)
    dirty = bool(run(["git", "status", "--porcelain"], cwd=destination, quiet=True))
    # `git clone --no-checkout` leaves an empty index and reports every file
    # as a staged deletion. This is an interrupted/incomplete checkout, not a
    # user edit, so it is safe to populate it with the requested revision.
    tracked = run(["git", "ls-files"], cwd=destination, quiet=True)
    untracked = run(
        ["git", "ls-files", "--others", "--exclude-standard"],
        cwd=destination,
        quiet=True,
    )
    remaining = [path for path in destination.iterdir() if path.name != ".git"]
    empty_partial_clone = not tracked and not untracked and not remaining
    if current == repository.commit:
        if empty_partial_clone:
            run(["git", "checkout", "--detach", repository.commit], cwd=destination)
            print(f"    {repository.name}: completed the pinned checkout {repository.commit}")
        else:
            print(f"    {repository.name}: already at {repository.commit}")
        return
    if dirty and not empty_partial_clone:
        raise RuntimeError(
            f"{destination} is dirty at {current}; refusing to replace it with "
            f"{repository.commit}"
        )

    # Fetching the object by hash keeps an existing partial clone lazy and
    # works even when the pinned commit is no longer the branch tip.
    run(["git", "fetch", "--filter=blob:none", "origin", repository.commit], cwd=destination)
    run(["git", "checkout", "--detach", repository.commit], cwd=destination)
    print(f"    {repository.name}: checked out {repository.commit}")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Lazily clone and pin objc-wasm-tooling dependencies"
    )
    parser.add_argument("manifest", type=Path, help="dependency manifest")
    parser.add_argument(
        "--dir", type=Path, default=ROOT / "deps",
        help="checkout directory (default: %(default)s)",
    )
    parser.add_argument(
        "--only", nargs="+", metavar="NAME",
        help="fetch only these repository names; default is every manifest entry",
    )
    parser.add_argument(
        "--list", action="store_true", help="list manifest entries without fetching"
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    repositories = load_repositories(args.manifest.expanduser().resolve())
    by_name = {repository.name: repository for repository in repositories}

    if args.list:
        for repository in repositories:
            print(f"{repository.name}\t{repository.commit}\t{repository.url}")
        return 0

    names = args.only or [repository.name for repository in repositories]
    unknown = [name for name in names if name not in by_name]
    if unknown:
        raise SystemExit(f"unknown repository: {', '.join(unknown)}")

    for name in names:
        repository = by_name[name]
        print(f"==> {repository.name}")
        checkout(repository, args.dir.expanduser().resolve() / repository.name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
