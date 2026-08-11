#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# bootstrap.sh -- turn a bare Ubuntu 24.04 into a working build environment
#                 for this project, in one command.
#
# USAGE
#   git clone https://github.com/Jhongwe1/zephyr-ec-pwrseq
#   cd zephyr-ec-pwrseq
#   ./tools/bootstrap.sh
#
# WHAT IT DOES
#   1. checks the host has the versions Zephyr 4.4 requires
#   2. installs the OS packages from the official Getting Started list
#   3. creates a Python venv and installs west
#   4. turns the PARENT directory of this repo into a west workspace
#   5. fetches the pinned Zephyr tree + modules (see west.yml)
#   6. installs the Zephyr SDK (ARM cross toolchain)
#
# PROPERTIES
#   - idempotent: safe to re-run.  Completed steps are detected and skipped.
#   - loud: every step prints what it is about to do and why.
#   - non-interactive: never prompts.  If something needs a human, it stops
#     and says exactly what to type.
#
# It does NOT touch anything outside:
#   <workspace>/            (the parent dir of this repo)
#   apt packages            (system-wide, via sudo)

set -euo pipefail

# ---------------------------------------------------------------- presentation
BOLD=$'\033[1m'; RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; RST=$'\033[0m'
[ -t 1 ] || { BOLD=''; RED=''; GRN=''; YLW=''; RST=''; }

step()  { printf '\n%s==> [%s/%s] %s%s\n' "$BOLD" "$1" "$TOTAL_STEPS" "$2" "$RST"; }
info()  { printf '    %s\n' "$*"; }
ok()    { printf '    %sOK%s  %s\n' "$GRN" "$RST" "$*"; }
skip()  { printf '    %s--%s  %s (already done)\n' "$YLW" "$RST" "$*"; }
die()   { printf '\n%sFAILED:%s %s\n\n' "$RED" "$RST" "$*" >&2; exit 1; }

TOTAL_STEPS=7

# ---------------------------------------------------------------------- layout
# This script lives in <repo>/tools/, so the repo is one level up and the
# west workspace is two levels up.  Resolving it this way (instead of
# hard-coding a path) is what lets the script work from any clone location.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS_DIR="$(dirname "$REPO_DIR")"
VENV_DIR="$WS_DIR/.venv"
LOG_FILE="$WS_DIR/bootstrap.log"

printf '%szephyr-ec-pwrseq bootstrap%s\n' "$BOLD" "$RST"
info "repo      : $REPO_DIR"
info "workspace : $WS_DIR"
info "log       : $LOG_FILE"

# ------------------------------------------------------------------ 1. checks
step 1 "Checking host prerequisites"

# Version floors for Zephyr 4.4.  Checking these FIRST is worth minutes:
# every one of them otherwise surfaces much later as a confusing CMake error.
need_version() {
    local name="$1" have="$2" want="$3" fix="$4"
    [ -n "$have" ] || die "$name not found. Fix: $fix"
    # sort -V puts the lower version first; if $want sorts first, we are >= want
    if [ "$(printf '%s\n%s\n' "$want" "$have" | sort -V | head -1)" != "$want" ]; then
        die "$name is $have, need >= $want. Fix: $fix"
    fi
    ok "$name $have (need >= $want)"
}

command -v apt-get >/dev/null || die "This script targets Debian/Ubuntu. On other distros follow docs/runbook/R01-environment.md by hand."

if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091  # runtime file, not part of the repo
    . /etc/os-release
    info "distro    : ${PRETTY_NAME:-unknown}"
    case "${VERSION_ID:-}" in
        24.*|25.*|26.*) : ;;
        *) printf '    %sWARNING%s  Zephyr 4.4 targets Ubuntu 24.04 LTS or newer.\n' "$YLW" "$RST"
           printf '             On 22.04 the stock CMake is 3.22 and this WILL fail.\n' ;;
    esac
fi

need_version cmake   "$(cmake   --version 2>/dev/null | head -1 | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)" 3.28.0 "use Ubuntu 24.04 or newer"
need_version python3 "$(python3 --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1)"           3.12.0 "use Ubuntu 24.04 or newer"

# dtc ships in device-tree-compiler, which step 2 installs.  Only enforce the
# floor if it is already present; otherwise let step 2 provide it.
DTC_V="$(dtc --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1 || true)"
if [ -n "$DTC_V" ]; then
    need_version dtc "$DTC_V" 1.4.6 "sudo apt install device-tree-compiler"
else
    info "dtc not installed yet -- step 2 installs it"
fi

if ! sudo -n true 2>/dev/null; then
    info "sudo will prompt for your password in step 2."
fi

# ---------------------------------------------------------------- 2. packages
step 2 "Installing OS packages (official Zephyr Getting Started list)"

# Sentinel: apt is slow and this script is meant to be re-run often.
PKG_STAMP="$WS_DIR/.bootstrap-apt-done"
if [ -f "$PKG_STAMP" ]; then
    skip "apt packages"
else
    sudo apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
        git cmake ninja-build gperf ccache dfu-util device-tree-compiler wget \
        python3-dev python3-venv python3-tk xz-utils file make gcc gcc-multilib \
        g++-multilib libsdl2-dev libmagic1
    touch "$PKG_STAMP"
    ok "apt packages installed"
fi

# -------------------------------------------------------------------- 3. venv
step 3 "Creating Python venv and installing west"

# Zephyr requires an isolated Python environment: Ubuntu 24.04 ships PEP 668
# ("externally managed") and will refuse a system-wide `pip install west`.
if [ -x "$VENV_DIR/bin/west" ]; then
    skip "venv at $VENV_DIR"
else
    [ -d "$VENV_DIR" ] || python3 -m venv "$VENV_DIR"
    # shellcheck disable=SC1091
    . "$VENV_DIR/bin/activate"
    pip install --quiet --upgrade pip
    pip install --quiet west
    ok "west $("$VENV_DIR/bin/west" --version 2>/dev/null | head -1)"
fi
# shellcheck disable=SC1091
. "$VENV_DIR/bin/activate"

# --------------------------------------------------------------- 4. west init
step 4 "Initialising the west workspace"

# `west init -l` means "local": this repo IS the manifest repo.  The Zephyr
# tree becomes a dependency of THIS project, not the other way round.  That is
# what makes `git clone && west init -l . && west update` reproduce the exact
# tree these measurements were taken against.
if [ -d "$WS_DIR/.west" ]; then
    skip "west workspace at $WS_DIR"
else
    ( cd "$WS_DIR" && west init -l "$(basename "$REPO_DIR")" )
    ok "workspace initialised"
fi

# ------------------------------------------------------------- 5. west update
step 5 "Fetching Zephyr + modules (this is the slow one)"

if [ -f "$WS_DIR/zephyr/VERSION" ]; then
    skip "zephyr tree present ($WS_DIR/zephyr)"
    info "to re-sync after changing west.yml:  west update --narrow -o=--depth=1"
else
    info "--narrow -o=--depth=1 fetches only the pinned revision, shallow."
    info "Full history is ~2.5 GB and 20-40 min; this is ~10x smaller/faster."
    info "Need full history later (e.g. git blame for an upstream patch)?"
    info "  cd \$WS/zephyr && git fetch --unshallow"
    ( cd "$WS_DIR" && west update --narrow -o=--depth=1 )
    ok "zephyr tree fetched"
fi

( cd "$WS_DIR" && west zephyr-export >/dev/null )
ok "west zephyr-export (CMake package registry)"

# -------------------------------------------------------- 6. python packages
step 6 "Installing Zephyr's Python dependencies"

# NOTE: `west packages pip --install` replaced the old
# `pip install -r zephyr/scripts/requirements.txt` flow.  Guides that still
# show requirements.txt are stale; following them gives a broken env.
( cd "$WS_DIR" && west packages pip --install )
ok "python dependencies installed"

# --------------------------------------------------------------- 7. Zephyr SDK
step 7 "Installing the Zephyr SDK (ARM cross toolchain)"

# Only the ARM toolchain is needed:
#   - blackpill_f411ce -> arm-zephyr-eabi
#   - native_sim       -> the HOST gcc, which is already installed
# Pulling every toolchain would cost several GB for nothing.
# Not `... | grep -q`: grep -q closes the pipe on first match, west dies of
# SIGPIPE, and `set -o pipefail` at the top of this file turns that into a
# failed condition -- so the SDK would be re-downloaded on every run precisely
# because it was already installed.  Capture, then match.
SDK_LIST="$(west sdk list 2>/dev/null || true)"
case "$SDK_LIST" in
  *arm-zephyr-eabi*)
    skip "Zephyr SDK with arm-zephyr-eabi" ;;
  *)
    ( cd "$WS_DIR/zephyr" && west sdk install -t arm-zephyr-eabi )
    ok "Zephyr SDK installed" ;;
esac

# ------------------------------------------------------------------- epilogue
cat <<EOF

${GRN}${BOLD}Bootstrap complete.${RST}

Every new shell needs the venv activated.  Add this to ~/.bashrc:

    alias ecws='source $VENV_DIR/bin/activate && cd $WS_DIR'

Then verify the environment end to end:

    cd $REPO_DIR
    make doctor      # checks every assumption this project makes
    make test        # fault-injection tests on native_sim (no hardware)
    make build       # firmware for blackpill_f411ce

If any of those fail, docs/runbook/R99-troubleshooting.md is indexed by the
exact error message.
EOF
