# SPDX-License-Identifier: Apache-2.0
#
# Front door for this project.  Every command a human needs is a make target,
# so nobody has to remember west's argument order -- including future me.
#
#   make            show this help
#   make doctor     check the environment before blaming the code
#   make test       fault-injection tests on native_sim  (NO HARDWARE NEEDED)
#   make build      firmware for the real board
#   make flash      build + flash over SWD
#
# Target board is a variable on purpose: the whole point of putting the
# timing table in devicetree is that the board is swappable.
#     make build BOARD=blackpill_f401cc
#     make build BOARD=native_sim

BOARD ?= blackpill_f411ce

# ---------------------------------------------------------------------------
# Locate west.
#
# This repo is the manifest repo, so the workspace -- and the venv west lives
# in -- is the PARENT directory.  Resolving it here means `make` works in a
# shell where nobody remembered to `source .venv/bin/activate`, which is the
# single most common "why doesn't this work" of the first month.
# ---------------------------------------------------------------------------
REPO_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
WS_DIR   := $(abspath $(REPO_DIR)/..)
VENV_BIN := $(WS_DIR)/.venv/bin

WEST := $(shell if [ -x "$(VENV_BIN)/west" ]; then echo "$(VENV_BIN)/west"; \
                else command -v west || echo "west-not-found"; fi)
PYTHON := $(shell if [ -x "$(VENV_BIN)/python" ]; then echo "$(VENV_BIN)/python"; \
                  else command -v python3 || echo "python3"; fi)

BUILD_DIR := build/$(BOARD)

.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
.PHONY: help
help: ## show this help
	@echo "zephyr-ec-pwrseq  --  BOARD=$(BOARD)"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[1m%-12s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  west   : $(WEST)"
	@echo "  build  : $(BUILD_DIR)/"

# ---------------------------------------------------------------------------
.PHONY: doctor
doctor: ## check every assumption this project makes about the environment
	@./tools/doctor.sh

.PHONY: build
build: _need-west ## build firmware for $(BOARD)
	$(WEST) build -b $(BOARD) -d $(BUILD_DIR) .

.PHONY: rebuild
rebuild: _need-west ## build from scratch (use after changing DTS/Kconfig)
	$(WEST) build -p always -b $(BOARD) -d $(BUILD_DIR) .

.PHONY: run
run: ## build and run on native_sim (host executable, no hardware)
	$(WEST) build -p always -b native_sim -d build/native_sim .
	./build/native_sim/zephyr/zephyr.exe

.PHONY: flash
flash: build ## flash $(BOARD) over SWD (ST-Link + OpenOCD)
	$(WEST) flash -d $(BUILD_DIR) --runner openocd

.PHONY: debug
debug: build ## start a GDB session on the target
	$(WEST) debug -d $(BUILD_DIR) --runner openocd

.PHONY: test
test: _need-west ## run the fault-injection test suite on native_sim
	$(WEST) twister -T tests/ -p native_sim --inline-logs

.PHONY: dts
dts: build ## show the devicetree AS THE BUILD ACTUALLY EXPANDED IT
	@echo "--- $(BUILD_DIR)/zephyr/zephyr.dts ---"
	@echo "Rule of this project: change an overlay -> read this file."
	@echo "What you wrote and what the build used are different things."
	@cat $(BUILD_DIR)/zephyr/zephyr.dts

.PHONY: menuconfig
menuconfig: ## interactive Kconfig browser for the current build
	$(WEST) build -d $(BUILD_DIR) -t menuconfig

.PHONY: lint
lint: ## static checks (same ones CI runs)
	@echo "== clang-format =="
	@find src include -name '*.[ch]' 2>/dev/null | xargs -r clang-format --dry-run --Werror
	@echo "== shellcheck =="
	@command -v shellcheck >/dev/null && shellcheck tools/*.sh || echo "   (shellcheck not installed, skipped)"

.PHONY: evidence
evidence: ## regenerate every figure and timing number from captures/
	@echo "Not implemented until P4 (W06+)."
	@echo "It will re-derive docs/measurements.md and docs/img/*.png from"
	@echo "the raw captures in captures/, so that every number in the README"
	@echo "is checkable rather than merely claimed."
	@exit 1

.PHONY: clean
clean: ## remove build output
	rm -rf build/ twister-out*/

# ---------------------------------------------------------------------------
.PHONY: _need-west
_need-west:
	@if [ "$(WEST)" = "west-not-found" ]; then \
	  echo ""; \
	  echo "west not found."; \
	  echo ""; \
	  echo "  Expected it at: $(VENV_BIN)/west"; \
	  echo "  Fix:            ./tools/bootstrap.sh"; \
	  echo ""; \
	  exit 1; \
	fi
