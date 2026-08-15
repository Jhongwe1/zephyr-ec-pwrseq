# Bill of Materials

What each part is for, and **why that value** — because "why 10 kΩ" is a
question that gets asked, and "it was in the tutorial" is not an answer.

Purchasing list with vendor-specific search terms and acceptance checks:
`淘宝采购清单.txt` (kept out of this repo).

---

## Required

| # | Part | Spec | Qty | Role in the design |
|:-:|---|---|:-:|---|
| 1 | MCU board | **WeAct Black Pill, STM32F411CEU6** (512 KB Flash / 128 KB SRAM) | 2 | The EC. Second board is the platform emulator (stage 2) and a spare. |
| 2 | SWD probe | ST-Link V2 (or any CMSIS-DAP / J-Link) | 1 | **Debugger, not just a flasher.** Power sequencing is timing-sensitive code; without breakpoints and register views you are working blind. |
| 3 | USB–TTL adapter | CP2102 or CH340, **3.3 V capable** | 2 | Serial console. See "Why this is not optional" below. |
| 4 | Logic analyser | **CY7C68013A (FX2LP), 8 ch, 24 MHz**, sigrok/`fx2lafw` compatible | 2 | The entire physical-evidence layer. Second unit is schedule insurance, not luxury — see below. |
| 5 | Breadboard | 830 tie-point (MB-102) | 1 | |
| 6 | Jumper wires | M-M / M-F / F-F, 20 cm | 40 each | |
| 7 | LEDs | 5 mm through-hole, red / yellow / green | 10 each | Per-rail visual feedback. |
| 8 | Resistors | 1/4 W, **330 Ω, 4.7 kΩ, 10 kΩ, 22 kΩ, 1 MΩ** | 20 each | See below — every value is derived. |
| 9 | Capacitors | **1 µF**, 50 V, MLCC, through-hole | 20 | RC time constant. |
| 10 | Tactile switches | 6×6×5 mm, 4-pin | 20 | Fault injection + LID. |
| 11 | USB cable | **data** cable, USB-C | 2 | A charge-only cable costs an evening. |

## Recommended

| # | Part | Why |
|:-:|---|---|
| 12 | Digital multimeter (with capacitance range) | Miswired breadboard: 30 seconds with a meter, or a whole evening without one. |
| 13 | Logic analyser test hooks ×10 | The bundled jumper wires fall out of a breadboard. One nudge and the capture is ruined. |
| 14 | Rigid breadboard jumper kit | Tidy wiring photographs legibly — and the wiring photo is evidence. |

---

## Why each resistor value

```
EN (GPIO out) ──┬──[330Ω]──▶|──GND            red LED, visual feedback
                └──[ R ]──┬────────────────▶  PG (GPIO in)
                        [1µF]   [1MΩ]
                          │       │
                         GND     GND
                          └──[fault button]──GND
```

STM32 GPIO inputs are Schmitt-triggered; worst-case `V_IH ≈ 0.7 × VDD`.

With `V(t) = VDD·(1 − e^(−t/τ))` and `τ = RC`, solving `V(t) = 0.7·VDD` gives
**`t = τ·ln(1/0.3) = 1.204·τ`**.

| Rail | R | C | τ = RC | Theoretical `t_PG` |
|---|:--:|:--:|:--:|:--:|
| S5 | 10 kΩ | 1 µF | 10.0 ms | **12.0 ms** |
| S3 | 22 kΩ | 1 µF | 22.0 ms | **26.5 ms** |
| S0 | 4.7 kΩ | 1 µF | 4.7 ms | **5.7 ms** |

Three *different* time constants is the point: the three rails must be
distinguishable from each other on a captured waveform.

| Value | Why exactly this |
|---|---|
| **330 Ω** | LED current `(3.3 − 2)/330 ≈ 4 mA`. Both per-pin and per-port current limits are real; getting into the habit of computing the number matters more than the number. |
| **1 MΩ** | Pull-down on `PG`. **This is a safety element, not a convenience.** A disconnected `PG` line must read inactive: *"the signal is missing"* and *"the signal is 0"* have to be the same thing to the firmware. |
| **Why not the MCU's internal pull-down** | It is roughly 40 kΩ, which forms a divider with the 10 kΩ series resistor (≈2.64 V) and — more importantly — changes the time constant entirely. 1 MΩ ≫ 10 kΩ, so it perturbs the timing by under 1%. |
| **Fault button shorts the cap to ground** | A *controlled* fault: hold it to keep `PG` from ever arriving (F1), or press it after reaching S0 to drop `PG` mid-run (F2). **Never demonstrate a fault by unplugging a jumper** — a floating input is an undefined state, it is not repeatable, and it proves nothing about the logic. |

---

## Why the USB–TTL adapter is not optional

Two independent reasons, and the second is architectural:

1. Cheap ST-Link V2 clones have **no virtual COM port**. They flash; they do not
   carry a console. No console means no `printk`, no per-rail `t_PG` output —
   the firmware is a black box.
2. Capture Profile B — the README's main figure — puts **UART1_TX (PA9) on logic
   analyser channel 7**, so PulseView can decode the firmware's own log and lay
   it on the *same time axis* as the measured edges. That requires a **hardware
   UART on a physical pin**. The board's own USB-CDC console cannot be probed:
   there is no signal wire to clip onto.

---

## Why two logic analysers

It is the only instrument in this project that cannot be substituted by
software, and it gates P4 completely: with no capture, every timing number in
the README stays a claim. Unit cost is trivial; a dead-on-arrival unit costs a
reorder plus international shipping. The spare is the cheapest available
insurance against a single point of failure in the evidence chain.

**It must be the cheap `CY7C68013A` one.** More expensive analysers (Kingst,
DSLogic, ZEROPLUS) ship proprietary software with incomplete sigrok support —
here, paying more buys a device that does not work with this toolchain.

---

## Substitutions

Only one item is genuinely fixed: **the logic analyser must be sigrok
compatible.** Everything else is negotiable:

- **MCU** — any in-tree Zephyr board with ~10 free GPIOs and SWD. F401CC/CE is a
  drop-in (`make build BOARD=blackpill_f401cc`); RP2040, ESP32 and nRF52840 all
  work. F411 was chosen for cost, in-tree support, its user button on PA0 and
  its LED on PC13. **The timing table lives in devicetree precisely so the board
  is swappable.**
- **SWD probe** — any CMSIS-DAP probe, a J-Link, or a second RP2040 as picoprobe.
- **R/C values** — any set giving three clearly distinct time constants; recompute
  `t_PG` and update the devicetree.
