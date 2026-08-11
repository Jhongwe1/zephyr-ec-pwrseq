# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(zephyr_ec_pwrseq LANGUAGES C)

target_include_directories(app PRIVATE include)

target_sources(app PRIVATE
  src/main.c
)

# Sources added as the project grows (kept here as a visible roadmap):
#   src/pwrseq.c      W03  devicetree-driven rail sequencer
#   src/smf_states.c  W05  hierarchical state machine
#   src/invariant.c   W04  independent invariant observer
#   src/ec_trace.c    W04  cycle-timestamped event ring buffer
