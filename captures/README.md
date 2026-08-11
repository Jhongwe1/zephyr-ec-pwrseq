# captures/

Raw logic-analyser captures. **These files are evidence. Do not "clean them up".**

`make evidence` regenerates every figure and every timing number in the README
from what is in here. That is the difference between a measurement a reader can
check and a measurement a reader has to take on faith — and it is why nothing
under this directory is listed in `.gitignore`.

## Naming

```
<profile>_<YYYYMMDD>_<HHMMSS>.sr     raw sigrok capture
<profile>_<YYYYMMDD>_<HHMMSS>.vcd    edge-encoded, derived from the .sr
```

Profiles: `normal`, `fault_f1`, `fault_f2`, `smbus`.

## Size policy

Commit `.vcd` always: it is text, it diffs, and it is small — a capture with a
few hundred edges is a few hundred lines. (The same data as CSV would be ~120
million rows, which is why the pipeline converts to VCD rather than CSV.)

Commit `.sr` when it is under ~10 MB. Above that, keep the `.vcd` in git, store
the `.sr` outside the repo, and record where it went in `LOG.md`. Do not reach
for Git LFS without a reason: it adds a setup step for anyone cloning this repo,
and the whole point of the pipeline is that cloning and re-running is easy.

## Provenance

Every capture needs a `LOG.md` entry on its date recording what was connected,
the sample rate, and which firmware commit was running. **A capture whose
provenance is unknown is not evidence.**
