/* SPDX-License-Identifier: Apache-2.0
 *
 * Plumbing test.
 *
 * WHAT THIS IS FOR
 *   Every other test in this repository will eventually fail for an
 *   interesting reason.  This one exists to fail for a BORING reason, and to
 *   be the first thing that runs, so that "the toolchain / twister / ztest
 *   harness is broken" is distinguishable from "my sequencer is wrong".
 *
 *   If this test fails, do not read the sequencer.  Read
 *   docs/runbook/R99-troubleshooting.md.
 *
 * WHAT IT ACTUALLY CHECKS
 *   The one thing at P0 that is genuinely load-bearing for everything after
 *   it: that the two clocks this project measures time with agree.
 *
 *   - k_uptime_get()    millisecond wall clock, used for timeouts
 *   - k_cycle_get_32()  cycle counter, used to timestamp EN and PG edges
 *
 *   Every timing number this project will ever publish is derived from the
 *   second one, and in P4 those timestamps get compared against a logic
 *   analyser's independent measurement of the same edges.  If
 *   sys_clock_hw_cycles_per_sec() does not describe the counter that
 *   k_cycle_get_32() reads -- a genuine possibility when the SoC clock tree
 *   is misconfigured, and the reason a board can boot happily while every
 *   delay is silently wrong -- then that comparison is meaningless, and so is
 *   the timing budget built on top of it.
 *
 *   Catching that here costs one test.  Catching it in P4, from a waveform
 *   that disagrees with the firmware by 30%, costs a weekend.
 */

#include <zephyr/ztest.h>
#include <zephyr/kernel.h>

#define SLEEP_MS 50U

/* Deliberately loose.  This is a sanity check, not a calibration: it must
 * catch "the cycle clock is off by an order of magnitude, or is not running",
 * and must never fail because a CI runner was busy.  A tight bound here would
 * produce a flaky test, and a flaky test guarding the foundations is worse
 * than no test -- people learn to re-run it instead of reading it.
 */
#define TOLERANCE_PCT 20U

ZTEST(ec_smoke, test_cycle_clock_agrees_with_uptime_clock)
{
	uint32_t hz = sys_clock_hw_cycles_per_sec();

	zassert_true(hz > 0, "sys_clock_hw_cycles_per_sec() is 0 -- "
			     "no cycle counter means no timing measurements");

	uint32_t c0 = k_cycle_get_32();
	int64_t u0 = k_uptime_get();

	k_msleep(SLEEP_MS);

	uint32_t c1 = k_cycle_get_32();
	int64_t u1 = k_uptime_get();

	/* Unsigned subtraction is correct across a 32-bit wrap, which is why
	 * the counter is read into uint32_t and subtracted before widening.
	 * At 100 MHz the counter wraps every ~43 s; 50 ms cannot span more
	 * than one wrap, so this is exact.
	 */
	uint32_t elapsed_cycles = c1 - c0;
	uint32_t cycle_ms = (uint32_t)(((uint64_t)elapsed_cycles * 1000U) / hz);
	uint32_t uptime_ms = (uint32_t)(u1 - u0);

	TC_PRINT("hz=%u  cycle_ms=%u  uptime_ms=%u  (slept %u)\n", hz, cycle_ms, uptime_ms,
		 SLEEP_MS);

	uint32_t lo = SLEEP_MS - (SLEEP_MS * TOLERANCE_PCT) / 100U;
	uint32_t hi = SLEEP_MS + (SLEEP_MS * TOLERANCE_PCT) / 100U;

	zassert_between_inclusive(uptime_ms, lo, hi, "uptime clock: slept %u ms, measured %u ms",
				  SLEEP_MS, uptime_ms);

	zassert_between_inclusive(cycle_ms, lo, hi,
				  "cycle counter disagrees with the sleep it measured: "
				  "slept %u ms, cycle counter says %u ms (hz=%u). "
				  "Either sys_clock_hw_cycles_per_sec() is wrong for this board, "
				  "or the clock tree is misconfigured.",
				  SLEEP_MS, cycle_ms, hz);
}

ZTEST_SUITE(ec_smoke, NULL, NULL, NULL, NULL, NULL);
