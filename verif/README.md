# UVM Plan

This directory is reserved for the reusable UVM environment after the directed RTL smoke milestone passes.

Planned structure:

```text
agent/   driver, monitor, sequencer
env/     environment, scoreboard, coverage
seq/     matrix transaction and sequences
tests/   smoke, random, reset, stress tests
top/     UVM testbench top
```

The first UVM version should reuse the 4x4 matrix reference model from `tb/tb_systolic_smoke.sv`.
