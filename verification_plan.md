# Mini TPU Verification Plan

## Scope

The first milestone verifies a 4x4 signed int8 systolic-array matrix multiplication core.
The design computes:

```text
C = A x B
```

where `A` and `B` are 4x4 signed int8 matrices, and `C` is a 4x4 signed int32 matrix.

## Why 4x4

Real TPU designs use a much larger systolic matrix multiply unit. This project keeps the same systolic dataflow idea but scales it down to 4x4 so the RTL, timing, and verification model are small enough to debug by hand.

## Milestone 1: Directed RTL Smoke

- Instantiate `mini_tpu_core`.
- Drive one fixed 4x4 matrix pair.
- Use a SystemVerilog reference model in the testbench.
- Check every output element.
- Pass criteria: no mismatches and simulation prints `PASS`.
- Status: initial mixed signed case passed.

## Milestone 2: More Directed Cases

- Identity matrix.
- Zero matrix.
- Negative values.
- Large positive and negative int8 values.
- Back-to-back `start_i`.
- Reset during computation.
- Status: identity, zero, int8 edge, back-to-back start, and reset-during-compute are now part of `tb_systolic_smoke.sv`.

## Milestone 3: UVM Environment

- Transaction: two 4x4 input matrices and one expected 4x4 output matrix.
- Driver: controls `start_i` and matrix inputs.
- Monitor: samples `done_o` and output matrix.
- Scoreboard: computes golden matrix multiplication and compares output.
- Coverage: value classes, matrix positions, output sign, and matrix value mix.
- Status: first AXI-Lite UVM smoke files are in `verif/`; `mini_tpu_cov.sv` reports functional coverage in `run.log`.

## Milestone 4: Interface Expansion

- Add a simple register/control wrapper.
- Then connect the existing AXI-Lite verification experience to configure and observe the TPU core.
- Status: `mini_tpu_axi_lite.sv` adds an AXI4-Lite register map for control, A/B matrix writes, and C matrix readback. `tb_axi_lite_smoke.sv` is the first directed AXI smoke.

## Milestone 5: Scratchpad Memory

- Replace direct A/B/C register arrays in the AXI wrapper with a small scratchpad subsystem.
- Keep the same software-visible AXI-Lite map:
  - `0x100`: activation matrix A bank.
  - `0x200`: weight matrix B bank.
  - `0x300`: accumulator/result matrix C bank.
- Commit systolic-array output into the C bank when the core finishes.
- Preserve A/B write protection while the core is busy.
- Status: `mini_tpu_scratchpad.sv` now models A, B, and C banks behind the AXI-Lite wrapper.

## Milestone 6: Assertions and Regression

- Bind SystemVerilog assertions to the AXI-Lite wrapper.
- Check reset behavior, response stability, valid/invalid address responses, one-cycle start/done behavior, bounded completion, done sticky behavior, and busy-time input-bank write protection.
- Add Makefile regression targets:
  - `make regression`: directed systolic smoke, directed AXI smoke, and UVM smoke.
  - `make regression-cov`: UVM coverage run plus URG report generation.
- Interview-safe summary: this extends the project from datapath correctness to a memory-mapped TPU subsystem, then uses SVA and regression gates to lock down control, protocol, and data-integrity behavior.
