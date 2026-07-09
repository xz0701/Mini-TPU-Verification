# UVM Plan

This directory contains the reusable UVM environment for the AXI-Lite mini TPU subsystem.

Planned structure:

```text
agent/   driver, monitor, sequencer
env/     environment, scoreboard, coverage
seq/     matrix transaction and sequences
tests/   smoke, random, reset, stress tests
top/     UVM testbench top
```

Current focused tests:

- `mini_tpu_smoke_test`
- `mini_tpu_mem_test`
- `mini_tpu_invalid_addr_test`
- `mini_tpu_busy_write_test`
- `mini_tpu_8x8_stress_test`

The UVM matrix item, driver, monitor, scoreboard, and coverage components use `MINI_TPU_ARRAY_SIZE`, so the same environment can run both 4x4 and 8x8 configurations.
