#!/usr/bin/env bash
set -euo pipefail

PATCH_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

[[ $# -ge 1 ]] || {
    echo "usage: $(basename "$0") DEPENDENCIES.toml --dir WORKDIR" >&2
    exit 1
}
MANIFEST=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")
shift
WORKDIR=''
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)
            [[ $# -ge 2 ]] || { echo "error: --dir needs a value" >&2; exit 1; }
            WORKDIR=$2
            shift 2
            ;;
        *)
            echo "error: unexpected argument: $1" >&2
            exit 1
            ;;
    esac
done
[[ -n "$WORKDIR" ]] || { echo "error: --dir is required" >&2; exit 1; }
WORKDIR=$(CDPATH= cd -- "$WORKDIR" 2>/dev/null && pwd) || {
    echo "error: workdir does not exist: $WORKDIR" >&2
    exit 1
}
[[ -f "$MANIFEST" ]] || { echo "error: manifest does not exist: $MANIFEST" >&2; exit 1; }

commit_for() {
    python3 - "$MANIFEST" "$1" <<'PY'
import sys
import tomllib

manifest, name = sys.argv[1:]
with open(manifest, "rb") as stream:
    repositories = tomllib.load(stream).get("repository", [])
for repository in repositories:
    if repository.get("name") == name:
        print(repository["commit"])
        break
else:
    raise SystemExit(f"repository is not in manifest: {name}")
PY
}

prepare_project() {
    local project=$1
    local checkout="$WORKDIR/$project"
    local expected
    local current
    local dirty

    [[ -d "$checkout/.git" ]] || {
        echo "error: missing Git checkout: $checkout" >&2
        return 1
    }
    expected=$(commit_for "$project")
    current=$(git -C "$checkout" rev-parse HEAD)
    if [[ "$current" != "$expected" ]]; then
        dirty=$(git -C "$checkout" status --porcelain)
        [[ -z "$dirty" ]] || {
            echo "error: $checkout is dirty at $current; refusing to switch to $expected" >&2
            return 1
        }
        git -C "$checkout" checkout --detach "$expected"
        current=$(git -C "$checkout" rev-parse HEAD)
    fi
    [[ "$current" == "$expected" ]] || {
        echo "error: could not prepare $project at $expected" >&2
        return 1
    }
    echo "prepared $project at $expected"
}

apply_one() {
    local patch=$1
    local project=$2
    local checkout="$WORKDIR/$project"

    if [[ "$(head -n 1 "$patch")" =~ ^From[[:space:]][0-9a-f]{40}[[:space:]] ]]; then
        if python3 - "$patch" "$checkout" <<'PY'
import re
import subprocess
import sys

patch_path, checkout = sys.argv[1:]
text = open(patch_path, encoding="utf-8").read()
parts = re.split(r"(?m)(?=^From [0-9a-f]{40} )", text)
parts = [part for part in parts if part.strip()]
for part in parts:
    already = subprocess.run(
        ["git", "-C", checkout, "apply", "--reverse", "--check"],
        input=part.encode(),
    )
    if already.returncode == 0:
        print("already applied part")
        continue
    before = subprocess.run(
        ["git", "-C", checkout, "status", "--porcelain"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    result = subprocess.run(
        ["git", "-C", checkout, "apply", "--3way"],
        input=part.encode(),
    )
    if result.returncode:
        result = subprocess.run(
            ["git", "-C", checkout, "apply"],
            input=part.encode(),
        )
    if result.returncode:
        # Mail patches in this queue intentionally overlap: a later cleanup
        # patch can rewrite a line introduced by an earlier patch.  If the
        # checkout was already patched, restore the pre-existing side of any
        # conflict and treat this part as already applied.  A clean checkout
        # still fails normally, so genuine patch/revision drift is not hidden.
        conflicted = subprocess.run(
            ["git", "-C", checkout, "diff", "--name-only", "--diff-filter=U"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.splitlines()
        if before.strip() and conflicted:
            subprocess.run(
                ["git", "-C", checkout, "checkout", "--ours", "--", *conflicted],
                check=True,
            )
            subprocess.run(["git", "-C", checkout, "add", "--", *conflicted], check=True)
            print("already applied part with overlapping queued changes")
            continue
        raise SystemExit(result.returncode)
PY
        then
            echo "applied $(basename -- "$patch")"
            return 0
        fi
    elif git -C "$checkout" apply --check "$patch" >/dev/null 2>&1; then
        git -C "$checkout" apply --3way "$patch"
        echo "applied $(basename -- "$patch")"
        return 0
    elif git -C "$checkout" apply --reverse --check "$patch" >/dev/null 2>&1; then
        echo "already applied $(basename -- "$patch")"
        return 0
    elif command -v patch >/dev/null 2>&1 \
        && (cd "$checkout" && patch --dry-run -N -p1 < "$patch" >/dev/null 2>&1); then
        (cd "$checkout" && patch -N -p1 < "$patch")
        echo "applied $(basename -- "$patch")"
        return 0
    elif command -v patch >/dev/null 2>&1 \
        && (cd "$checkout" && patch --dry-run -R -p1 < "$patch" >/dev/null 2>&1); then
        echo "already applied $(basename -- "$patch")"
        return 0
    else
        echo "error: patch does not apply cleanly: $patch" >&2
        return 1
    fi
}

shopt -s nullglob
patches=("$PATCH_DIR"/*.patch)
[[ ${#patches[@]} -gt 0 ]] || {
    echo "no patches found in $PATCH_DIR"
    exit 0
}

prepared=()
for patch in "${patches[@]}"; do
    filename=$(basename -- "$patch")
    stem=${filename%.patch}
    if [[ "$stem" != *@* ]]; then
        echo "error: patch must be named PATCHNAME@PROJECT.patch: $filename" >&2
        exit 1
    fi
    project=${stem##*@}
    seen=0
    if [[ ${#prepared[@]} -gt 0 ]]; then
        for prepared_project in "${prepared[@]}"; do
            [[ "$prepared_project" == "$project" ]] && seen=1
        done
    fi
    if [[ "$seen" -eq 0 ]]; then
        prepare_project "$project" || exit 1
        prepared+=("$project")
    fi
    apply_one "$patch" "$project" || exit 1
done

echo "all patches applied; build artifacts were not cleaned"
