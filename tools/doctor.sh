#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# doctor.sh -- check every assumption this project makes about its environment.
#
# Run it BEFORE debugging a build failure.  Roughly half of "my code is
# broken" in an embedded project is actually "my environment is broken", and
# the two produce error messages that look identical to someone who has not
# seen them before.  This script separates them in ten seconds.
#
#   ./tools/doctor.sh          check everything
#   make doctor                same thing
#
# Exit status: 0 if nothing FAILED (warnings are allowed), 1 otherwise.

set -uo pipefail

BOLD=$'\033[1m'; RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; DIM=$'\033[2m'; RST=$'\033[0m'
[ -t 1 ] || { BOLD=''; RED=''; GRN=''; YLW=''; DIM=''; RST=''; }

FAILED=0
WARNED=0

pass() { printf '  %sPASS%s  %s\n' "$GRN" "$RST" "$1"; }
warn() { printf '  %sWARN%s  %s\n         %s-> %s%s\n' "$YLW" "$RST" "$1" "$DIM" "$2" "$RST"; WARNED=$((WARNED+1)); }
fail() { printf '  %sFAIL%s  %s\n         %s-> %s%s\n' "$RED" "$RST" "$1" "$DIM" "$2" "$RST"; FAILED=$((FAILED+1)); }
sect() { printf '\n%s%s%s\n' "$BOLD" "$1" "$RST"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS_DIR="$(dirname "$REPO_DIR")"
VENV_BIN="$WS_DIR/.venv/bin"

printf '%szephyr-ec-pwrseq doctor%s\n' "$BOLD" "$RST"
printf '  repo      : %s\n' "$REPO_DIR"
printf '  workspace : %s\n' "$WS_DIR"

# ---------------------------------------------------------------------- host
sect "Host"

case "$(uname -s)" in
    Linux) pass "OS is Linux ($(uname -r))" ;;
    *)     fail "OS is $(uname -s)" "native_sim only runs on Linux. Build inside WSL2 (Ubuntu 24.04), not Windows." ;;
esac

if grep -qi microsoft /proc/version 2>/dev/null; then
    pass "running under WSL2"
    # Building on /mnt/c goes through a filesystem bridge and is several times
    # slower than the Linux filesystem.  Over hundreds of builds that is hours.
    case "$REPO_DIR" in
        /mnt/*) warn "repo lives on the Windows filesystem ($REPO_DIR)" \
                     "Builds here are several times slower. Move the workspace under ~/ (see docs/runbook/R01)." ;;
        *)      pass "repo is on the Linux filesystem (fast builds)" ;;
    esac
fi

for t in cmake ninja dtc gcc git; do
    if command -v "$t" >/dev/null 2>&1; then
        pass "$t present"
    else
        fail "$t missing" "./tools/bootstrap.sh"
    fi
done

# ---------------------------------------------------------------------- west
sect "west / Python"

if [ -x "$VENV_BIN/west" ]; then
    pass "west in workspace venv ($("$VENV_BIN/west" --version 2>/dev/null | head -1))"
    WEST="$VENV_BIN/west"
elif command -v west >/dev/null 2>&1; then
    warn "west found on PATH but not in $VENV_BIN" "Fine, but bootstrap.sh expects the venv layout."
    WEST="$(command -v west)"
else
    fail "west not found" "./tools/bootstrap.sh"
    WEST=""
fi

# ----------------------------------------------------------------- workspace
sect "Workspace"

if [ -d "$WS_DIR/.west" ]; then
    pass "west workspace initialised"
else
    fail "no .west/ in $WS_DIR" "cd $WS_DIR && west init -l $(basename "$REPO_DIR")"
fi

if [ -f "$WS_DIR/zephyr/VERSION" ]; then
    ZVER="$(sed -n 's/^VERSION_MAJOR *= *//p;' "$WS_DIR/zephyr/VERSION" | tr -d ' ')"
    ZMIN="$(sed -n 's/^VERSION_MINOR *= *//p;' "$WS_DIR/zephyr/VERSION" | tr -d ' ')"
    ZPAT="$(sed -n 's/^PATCHLEVEL *= *//p;'    "$WS_DIR/zephyr/VERSION" | tr -d ' ')"
    pass "zephyr tree present (v${ZVER}.${ZMIN}.${ZPAT})"

    # The pin is the whole basis of "clone this and get my numbers".  A tree
    # that has silently drifted from west.yml makes every measurement in the
    # README describe a build nobody can reproduce -- so this is checked, not
    # trusted.
    PINNED="$(sed -n 's/^ *revision: *//p' "$REPO_DIR/west.yml" | head -1)"
    TREE_VER="v${ZVER}.${ZMIN}.${ZPAT}"
    case "$PINNED" in
        v[0-9]*)
            # The pin is a release tag, and `git describe` CANNOT confirm it
            # here: the workspace is fetched with `--narrow -o=--depth=1`,
            # which deliberately does not fetch tag refs.  describe then says
            # "No names found", a naive check falls back to the commit SHA,
            # compares it against "v4.4.2", and reports drift that does not
            # exist.  The VERSION file is generated from the tag and IS
            # present in a shallow clone -- compare that instead.
            if [ "$PINNED" = "$TREE_VER" ]; then
                pass "zephyr tree matches the pin in west.yml ($PINNED)"
            else
                # Not a warning.  A drifted tree means the README's timing
                # numbers describe a build nobody can reproduce, which is the
                # one property this project cannot give up.
                fail "zephyr tree is $TREE_VER but west.yml pins $PINNED" \
                     "cd $WS_DIR && west update --narrow -o=--depth=1"
            fi
            ;;
        *)
            ACTUAL="$(git -C "$WS_DIR/zephyr" rev-parse --short HEAD 2>/dev/null)"
            warn "west.yml pins a non-release revision '$PINNED' (tree at $ACTUAL)" \
                 "Release tags are reproducible and explainable; branches drift."
            ;;
    esac
else
    fail "no zephyr tree at $WS_DIR/zephyr" "./tools/bootstrap.sh"
fi

if [ -n "$WEST" ] && [ -f "$WS_DIR/zephyr/VERSION" ]; then
    # Deliberately NOT `west sdk list | grep -q ...`.
    #
    # `grep -q` exits the instant it matches and closes the pipe.  The writer
    # upstream of it then dies of SIGPIPE, and because this script runs under
    # `set -o pipefail`, the pipeline's status becomes that failure -- so the
    # check reports "toolchain missing" EXACTLY WHEN THE TOOLCHAIN IS PRESENT.
    # The bug is invisible in a shell without pipefail, which is why it
    # survives review.  Capture the output, then match it.
    SDK_LIST="$("$WEST" sdk list 2>/dev/null || true)"
    case "$SDK_LIST" in
        *arm-zephyr-eabi*)
            pass "Zephyr SDK has arm-zephyr-eabi (needed for the real board)" ;;
        *)
            warn "arm-zephyr-eabi toolchain not found" \
                 "cd $WS_DIR/zephyr && west sdk install -t arm-zephyr-eabi  (native_sim still works without it)" ;;
    esac
fi

# ------------------------------------------------------------------ repo hygiene
sect "Repository"

# CRLF is the classic Windows-edits-it, Linux-runs-it failure.  The symptom is
# "bad interpreter: No such file or directory" on a file that plainly exists,
# because the invisible ^M is part of the interpreter path.
CRLF_HITS=0
while IFS= read -r f; do
    # Same SIGPIPE-under-pipefail hazard as the SDK check above, and here it
    # fails the dangerous way round: a matching `grep -q` would make the
    # condition look FALSE, silently passing a file that really does have
    # CRLF.  Read into a variable, then match.
    head_bytes="$(head -c 4096 "$f" 2>/dev/null || true)"
    case "$head_bytes" in
        *$'\r'*)
            fail "CRLF line endings in $f" \
                 "sed -i 's/\r\$//' '$f'   (.gitattributes prevents recurrence)"
            CRLF_HITS=$((CRLF_HITS+1)) ;;
    esac
done < <(find "$REPO_DIR/tools" -name '*.sh' 2>/dev/null)
[ "$CRLF_HITS" -eq 0 ] && pass "shell scripts have Unix line endings"

for f in tools/*.sh; do
    [ -e "$REPO_DIR/$f" ] || continue
    if [ -x "$REPO_DIR/$f" ]; then
        pass "$f is executable"
    else
        fail "$f is not executable" "chmod +x $f && git update-index --chmod=+x $f"
    fi
done

# git identity is not cosmetic here: Zephyr upstream enforces DCO, which
# requires Signed-off-by to match the commit author exactly, under a real
# name.  Getting this wrong is discovered at PR time in W10, after the commits
# already exist -- and fixing it then means rewriting history.
GIT_NAME="$(git -C "$REPO_DIR" config user.name  2>/dev/null || true)"
GIT_MAIL="$(git -C "$REPO_DIR" config user.email 2>/dev/null || true)"
if [ -n "$GIT_NAME" ] && [ -n "$GIT_MAIL" ]; then
    pass "git identity: $GIT_NAME <$GIT_MAIL>"
    case "$GIT_NAME" in
        *\ *) : ;;
        *) warn "git user.name '$GIT_NAME' looks like a handle, not a legal name" \
                "Zephyr's DCO requires a real name. git config --global user.name 'First Last'" ;;
    esac
else
    fail "git user.name / user.email not set" \
         "git config --global user.name 'First Last'; git config --global user.email 'you@example.com'"
fi

# ------------------------------------------------------------------- summary
sect "Summary"
if [ "$FAILED" -eq 0 ] && [ "$WARNED" -eq 0 ]; then
    printf '  %sEverything checks out.%s  Next: make test\n\n' "$GRN" "$RST"
elif [ "$FAILED" -eq 0 ]; then
    printf '  %s%d warning(s), 0 failures.%s  Safe to continue.\n\n' "$YLW" "$WARNED" "$RST"
else
    printf '  %s%d failure(s), %d warning(s).%s  Fix the failures above first.\n' "$RED" "$FAILED" "$WARNED" "$RST"
    printf '  Error messages are indexed in docs/runbook/R99-troubleshooting.md\n\n'
    exit 1
fi
