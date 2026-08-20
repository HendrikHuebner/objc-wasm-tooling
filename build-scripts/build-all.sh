#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[[ $# -eq 1 ]] || { echo "usage: $(basename "$0") WORKDIR" >&2; exit 1; }
mkdir -p "$1"
WORKDIR=$(CDPATH= cd -- "$1" && pwd)
LOG_DIR="$WORKDIR/build-logs"
mkdir -p "$LOG_DIR"

# Keep prerequisites explicit instead of relying on a failed child script to
# explain why a later dependency could not be built. This also lets independent
# dependencies continue after one build fails.
projects=(
    llvm-project
    binaryen
    emscripten
    libobjc2
    libs-base
    zlib
    libffi
    icu
    libs-corebase
    qtbase
)

script_for() {
    printf '%s/build-%s.sh\n' "$SCRIPT_DIR" "$1"
}

prerequisites_for() {
    case "$1" in
        llvm-project) printf '\n' ;;
        binaryen) printf '\n' ;;
        emscripten) printf 'llvm-project binaryen\n' ;;
        libobjc2) printf 'llvm-project emscripten\n' ;;
        libs-base) printf 'llvm-project emscripten libobjc2\n' ;;
        zlib|libffi|icu) printf 'llvm-project emscripten\n' ;;
        libs-corebase) printf 'llvm-project emscripten libobjc2 libs-base icu\n' ;;
        qtbase) printf 'llvm-project emscripten\n' ;;
        *) printf '\n' ;;
    esac
}

contains() {
    local needle=$1
    shift
    local value
    for value in "$@"; do
        [[ "$value" == "$needle" ]] && return 0
    done
    return 1
}

built=()
not_built=()
failed=()

state_is_built() {
    contains "$1" "${built[@]}"
}

state_is_failed() {
    contains "$1" "${failed[@]}"
}

for project in "${projects[@]}"; do
    script=$(script_for "$project")
    log="$LOG_DIR/$project.log"
    : > "$log"

    if [[ ! -x "$script" ]]; then
        printf 'not built: %s (build script unavailable)\n' "$project" | tee -a "$log"
        not_built+=("$project")
        continue
    fi

    if [[ ! -d "$WORKDIR/$project" ]]; then
        printf 'not built: missing checkout %s\n' "$WORKDIR/$project" | tee -a "$log"
        not_built+=("$project")
        continue
    fi

    blocked_by=''
    for prerequisite in $(prerequisites_for "$project"); do
        if ! state_is_built "$prerequisite"; then
            blocked_by="$prerequisite"
            break
        fi
    done
    if [[ -n "$blocked_by" ]]; then
        printf 'not built: prerequisite %s was not built\n' "$blocked_by" | tee -a "$log"
        not_built+=("$project")
        continue
    fi

    printf 'building %s (log: %s)\n' "$project" "$log"
    if "$script" "$WORKDIR" >"$log" 2>&1; then
        printf 'built: %s\n' "$project"
        built+=("$project")
    else
        status=$?
        printf 'failed: %s (exit %s; log: %s)\n' "$project" "$status" "$log"
        printf '\nbuild failed with exit status %s\n' "$status" >> "$log"
        failed+=("$project")
    fi
done

print_group() {
    local label=$1
    shift
    printf '%s (%s):' "$label" "$#"
    if [[ $# -eq 0 ]]; then
        printf ' none\n'
    else
        printf ' %s\n' "$*"
    fi
}

printf '\nBuild summary\n'
if ((${#built[@]})); then print_group 'Built' "${built[@]}"; else print_group 'Built'; fi
if ((${#not_built[@]})); then print_group 'Not built' "${not_built[@]}"; else print_group 'Not built'; fi
if ((${#failed[@]})); then print_group 'Failed' "${failed[@]}"; else print_group 'Failed'; fi
printf 'Logs: %s\n' "$LOG_DIR"
