/* SPDX-License-Identifier: Apache-2.0
 *
 * zephyr-ec-pwrseq -- laptop EC power-sequencing state machine.
 *
 * W01 scope: prove the toolchain end to end THROUGH THIS REPOSITORY.
 *
 * Building an upstream Zephyr sample proves Zephyr builds.  It does not prove
 * that this repo's manifest, CMakeLists, Kconfig and board selection are
 * right.  Those are separate failure modes, and finding out in W03 -- while
 * also debugging a state machine -- is how a week gets lost.  So the first
 * commit that runs is the smallest one that exercises the whole chain.
 *
 * The sequencer, the state machine and the fault handling arrive in W02-W05.
 */

#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/sys/util.h>
#include <version.h>

LOG_MODULE_REGISTER(ec_main, LOG_LEVEL_INF);

int main(void)
{
	LOG_INF("zephyr-ec-pwrseq (W01 skeleton)");
	LOG_INF("board  : %s", CONFIG_BOARD_TARGET);
	LOG_INF("zephyr : %s", KERNEL_VERSION_STRING);

	/* The resolution ceiling of every timing number this project will
	 * ever report.
	 *
	 * k_cycle_get_32() is the firmware-side clock used to timestamp EN and
	 * PG edges, and in W08 those timestamps get compared against the logic
	 * analyser's independent measurement of the same edges.  That
	 * comparison is only meaningful if the tick rate is known rather than
	 * assumed, and it is NOT a constant: it depends on the SoC clock tree
	 * and differs between the board and native_sim.
	 *
	 * Printing it at boot costs one line and makes every later measurement
	 * self-documenting -- the number is in the log next to the data it
	 * bounds.
	 */
	uint32_t hz = sys_clock_hw_cycles_per_sec();

	LOG_INF("cycle counter: %u Hz (%u ns per tick)", hz, (unsigned int)(1000000000ULL / hz));

	LOG_INF("skeleton up; sequencer lands in W03");

	return 0;
}
