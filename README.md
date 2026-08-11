# Laptop EC Power-Sequencing State Machine on Zephyr RTOS

[![CI](https://github.com/Jhongwe1/zephyr-ec-pwrseq/actions/workflows/ci.yml/badge.svg)](https://github.com/Jhongwe1/zephyr-ec-pwrseq/actions/workflows/ci.yml)

A laptop Embedded Controller's power-sequencing state machine, implemented on
an STM32F411 with Zephyr's State Machine Framework — where **the rail order and
timing budget live in devicetree rather than in C**, faults are **test cases
that run in CI without hardware**, and the resulting timing is **measured with
a logic analyser** rather than asserted.

> **Project status — W01 of 13 (2026-08-12).**
> Toolchain, workspace, CI and test plumbing are up and green.
> The sequencer itself lands in W03. Sections 5 (Measurements) and 6 (Pitfalls)
> are deliberately empty until there is something real to put in them.
> Nothing in this README is aspirational: if it is written as done, it is done.
>
> 中文操作手冊（環境建置、量測、疑難排解）在 **[RUNBOOK.md](RUNBOOK.md)**。

---

## 1. Why this project

When a laptop powers on, its supply rails cannot come up simultaneously. The
SoC's platform design guide specifies an order: assert a rail's `EN`, wait for
its `PG` (Power Good) to confirm the rail is actually up, only then move to the
next. Get the order wrong — or, worse, keep going when a rail fails to come up —
and the failure is not a crash. Parasitic diodes in the level shifters and ESD
structures between powered and unpowered domains can forward-conduct, which at
best leaves a rail at an undefined potential and at worst triggers CMOS latch-up.

The chip that owns this sequence is the Embedded Controller: the always-on
microcontroller that is first to wake and last to sleep. It is also the least
publicly discussed chip in the machine.

This project implements that responsibility properly and then **measures it**,
because the interesting engineering is not "three LEDs light up in order" — it
is everything around that:

- what happens when `PG` never arrives, arrives late, chatters, or is *already
  asserted before you assert `EN`*
- how you shut down safely from a half-powered state
- how you prove any of it is correct without a laboratory

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  PC (host)                                                              │
│  ├── west build / flash / debug   (ST-Link + OpenOCD)                   │
│  ├── tools/capture.sh             sigrok capture profiles      (W06)    │
│  └── tools/annotate.py            VCD -> measurement table + figures     │
└──────────┬──────────────────────────────────┬───────────────────────────┘
           │ UART1 (console + CH7 of capture) │ USB
           │                                  │
┌──────────▼───────────────────────┐   ┌──────▼──────────────────────────┐
│  EC MCU   (STM32F411 Black Pill) │   │  8ch Logic Analyser             │
│  ┌────────────────────────────┐  │   │  (fx2lafw / sigrok)             │
│  │ SMF hierarchical state m/c │  │   └─────────────────────────────────┘
│  │  G3 - S5 - S3 - S0 - S0ix  │  │                 ▲
│  ├────────────────────────────┤  │                 │ 8 probes
│  │ rail sequencer (DT-driven) │──┼─────────────────┘
│  │  EN[] / PG[] / ramp / t_o  │  │
│  ├────────────────────────────┤  │   EN / PG / PWR_BTN / PCH_PWROK /
│  │ trace ring buf (cycle ts)  │  │   SCI# / UART_TX
│  ├────────────────────────────┤  │
│  │ invariant observer         │  │
│  └────────────────────────────┘  │
└──────────┬───────────────────────┘
           │ EN / PG
┌──────────▼──────────────┐
│  RC delay network       │   Three rails, three time constants:
│  10k / 22k / 4.7k + 1uF │   a real analogue ramp, not a sleep() call.
│  1M pull-down (failsafe)│   A push-button shorts the cap to inject faults.
└─────────────────────────┘
```

### State hierarchy

```
                    ST_ROOT           run: 4s power-button force-off (F5)
                       │                   battery critical (F6), thermal (F7)
            ┌──────────┴──────────┐
        ST_OFF                 ST_ON      run: any PG dropping out (F2)
          │                       │
    ┌─────┴─────┐        ┌────────┼────────┐
  ST_G3    ST_FAULT    ST_S5   ST_S3    ST_S0
                                           └── ST_S0IX
```

Why the hierarchy is shaped this way — the part that matters:

- **`ST_ROOT`** holds what *every* state must answer: a 4-second power-button
  hold, battery-critical, thermal trip. A real EC's force-off must keep working
  when the system has hung, so it cannot live in any child state.
- **`ST_ON`** holds what every powered state must answer: any rail's `PG`
  dropping out. That is a shared responsibility of S5/S3/S0/S0ix, so it is
  written once in the parent.
- **`ST_FAULT`** is absorbing. Only user intervention or reset leaves it — it
  **never auto-retries**, because automatically re-enabling a shorted rail
  repeatedly injects high current into a fault.

### The core design decision: timing is data

```dts
power-sequencer {
    compatible = "ec,power-sequencer";
    /* Child order in the devicetree IS the power-up order.
     * Power-down is its strict reverse. */
    rail_s5 { rail-name = "S5_3V3_ALW";  enable-gpios = <...>; pg-gpios = <...>;
              ramp-delay-us = <500>; pg-timeout-ms = <50>; };
    rail_s3 { ... };
    rail_s0 { ... };
};
```

The C side is a generic engine that expands those nodes into a static array.
**Adding a rail is a devicetree node and zero lines of C. Changing board is a
different overlay.** The `native_sim` overlay maps the same nodes onto
`gpio_emul`, so the identical sequencer runs the fault-injection suite in CI
with no hardware attached.

### Invariants

Correctness is written as machine-checkable assertions rather than left to
whoever remembers:

| # | Invariant |
|---|---|
| **INV1** | If rail *i*'s `EN` is asserted, rails 0..*i*-1 all have `PG` asserted |
| **INV2** | After any fault, the terminal state has *every* `EN` de-asserted |
| **INV3** | De-assert order is the strict reverse of assert order |
| **INV4** | No unbounded wait — every wait has a timeout (`K_FOREVER` is banned) |

INV1 and INV3 are checked by an **observer module deliberately separated from
the sequencer**, so that a bug in the sequencing logic cannot also disable the
check on it. Safety-critical firmware calls this a monitor or safety supervisor.

## 3. How to run it

**Full instructions: [RUNBOOK.md](RUNBOOK.md)** (Traditional Chinese, zero-assumption).

Toolchain: Zephyr **4.4.2** (pinned in [`west.yml`](west.yml)), Zephyr SDK
**1.0.1**, Ubuntu 24.04 (WSL2 is fine).

```bash
mkdir -p ~/work/ec-ws && cd ~/work/ec-ws
git clone https://github.com/Jhongwe1/zephyr-ec-pwrseq
cd zephyr-ec-pwrseq
./tools/bootstrap.sh          # one command, bare OS -> working toolchain

make doctor                   # verify every assumption about the environment
make test                     # fault-injection suite on native_sim -- NO HARDWARE
make build                    # firmware for blackpill_f411ce
```

`make test` is the path that needs no hardware at all. That is deliberate: the
entire fault matrix is designed to be verifiable by anyone who clones this repo.

## 4. What I did / did not do

### Done
- [x] Reproducible workspace: this repo is its own west manifest repo, Zephyr
      pinned to a release tag, one-command bootstrap, environment self-check
- [x] CI building for both targets with warnings-as-errors
- [ ] Devicetree-driven rail sequencer (W03)
- [ ] SMF hierarchical state machine, G3→S5→S3→S0→S0ix (W05)
- [ ] F1–F4 fault handling, reverse shutdown, four invariants (W04–W05)
- [ ] Fault-injection matrix on `native_sim` + `gpio_emul` (W07)
- [ ] Logic-analyser capture, annotation and timing budget (W06–W08)

### Not done, and why
- **Real eSPI.** The STM32F411 has no eSPI peripheral. `SLP_S3#/S4#/S5#` and
  `PLTRST#` are modelled as GPIOs standing in for eSPI virtual wires. I have
  not validated real eSPI channel behaviour, reset timing or the OOB channel.
- **Keyboard matrix, touchpad, USB-PD/Type-C, charge control.** A scope
  decision: sequence one thing deeply rather than five things shallowly.
- **Real regulators.** `PG` comes from an RC network — a genuine analogue delay,
  but with no inrush current, load transient, soft-start or OCP/OVP behaviour.

## 5. Measurements and evidence

> **Empty by design until W06.** This section will contain annotated
> logic-analyser captures with a time axis, a `t_PG` distribution over 100 boot
> cycles, the derivation of the `PG` timeout from that distribution, and a
> cross-check of firmware cycle-counter timestamps against the instrument's
> independent measurement of the same edges.
>
> Every figure will be regenerated from the raw captures in `captures/` by
> `make evidence`. Nothing hand-drawn, nothing hand-measured.
>
> Writing this section before the measurements exist would be the single
> easiest way to make the rest of the document untrustworthy.

## 6. Pitfalls I hit

> Accumulates as they happen; the full log is [`LOG.md`](LOG.md).

- **`grep -q` inside a `pipefail` script inverts its own result.** The
  environment self-check reported the ARM toolchain missing at exactly the
  moment it was present: `grep -q` exits on first match and closes the pipe,
  the writer dies of `SIGPIPE`, and `pipefail` promotes that to a failed
  condition. Invisible in a shell without `pipefail`.
  → [R99](docs/runbook/R99-troubleshooting.md), `LOG.md` 2026-08-12.
- **A shallow clone has no tags, so `git describe` cannot verify a version
  pin.** The version check had to move to `zephyr/VERSION`, which is generated
  from the tag and survives `--depth=1`.

## 7. Limitations

The Power Good signals in this project are produced by an RC network. That is a
real analogue delay with a real time constant, but it is not a regulator: there
is no inrush current, no load transient, no output-capacitor soft-start, and no
OCP/OVP behaviour, and the load is a resistor and an LED. Platform-side
`SLP_S3#/S4#/S5#` and `PLTRST#` are GPIOs standing in for eSPI virtual wires,
because the STM32F411 has no eSPI peripheral; consequently no real eSPI channel
behaviour, reset timing or OOB path has been validated. I have not implemented
keyboard matrix scanning (including ghosting and NKRO), touchpad handling,
USB-PD/Type-C, CC/CV charge control or battery protection, and I have not tuned
a real thermal policy. Timing will be characterised at room temperature and a
single supply voltage only, with no coverage of temperature or voltage extremes;
a production design would set the `PG` timeout from the regulator's worst-case
turn-on specification plus margin, not from the measured distribution of one
board on one bench.

## 8. References

- ACPI Specification 6.5, §12 (Embedded Controller interface: §12.2.1 status
  bits, §12.3 command set)
- [Intel Open EC Firmware](https://github.com/intel/ecfw-zephyr) —
  `doc/reference/power_sequencing/`. Read as a specification for signal naming
  and flow; it is pinned to a much older Zephyr and is not a dependency here.
- Smart Battery Data Specification; SMBus 2.0
- Zephyr 4.4 documentation: [SMF](https://docs.zephyrproject.org/latest/services/smf/),
  `gpio_emul`, `native_sim`, Twister

---

*Author: Chung-Wei Lan. Built in the open, one commit at a time — the commit
history is part of the evidence.*
