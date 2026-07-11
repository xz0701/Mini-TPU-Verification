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
- Status: first AXI-Lite UVM smoke files are in `verif/`; `mini_tpu_cov.sv` reports functional coverage in the per-test run log.

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

## Milestone 7: Subsystem Negative and Stress Tests

- Split UVM regression into focused tests instead of relying on one smoke sequence.
- `mini_tpu_smoke_test`: end-to-end matrix cases with scoreboard and functional coverage.
- `mini_tpu_mem_test`: scratchpad A/B readback, byte strobe behavior, and C-bank reset/read-before-compute behavior.
- `mini_tpu_invalid_addr_test`: valid/invalid read/write address response checks, including read-only STATUS/C write attempts.
- `mini_tpu_busy_write_test`: verifies A/B writes accepted during busy do not corrupt the in-flight compute or input banks.
- Status: these tests are included in `mini_tpu_pkg.sv` and wired into `make regression`.

## Milestone 8: 4x4 / 8x8 Parameter Scaling

- Add a shared `MINI_TPU_ARRAY_SIZE` compile-time configuration.
- Keep `ARRAY_SIZE=4` as the default quick regression target.
- Enable 8x8 runs through the same RTL, AXI-Lite map, UVM item, driver, monitor, scoreboard, coverage, and subsystem tests.
- The 8x8 address map uses the existing 12-bit windows exactly:
  - A bank: `0x100` through `0x1ff`.
  - B bank: `0x200` through `0x2ff`.
  - C bank: `0x300` through `0x3ff`.
- Run examples:
  - `make regression`
  - `make regression ARRAY_SIZE=8`
  - `make regression-8x8`
- Status: Makefile, directed testbenches, UVM top, and reusable UVM components now use the shared array-size configuration.

## Milestone 9: Regression Logging and Generic RTL Naming

- Replace overwritten `compile.log` / `run.log` outputs with per-target logs:
  - `compile_tb_mini_tpu_uvm_8x8_mini_tpu_smoke_test.log`
  - `run_tb_mini_tpu_uvm_8x8_mini_tpu_smoke_test.log`
- Rename the parameterized systolic array RTL from the 4x4-specific name to `systolic_array`.
- Add `mini_tpu_8x8_stress_test` to exercise dense signed, sparse diagonal, and checkerboard matrices across the configured array size.

## Milestone 10: UVM RAL

- Add a reusable RAL model for the memory-mapped TPU subsystem.
- Model `CTRL` as write-only control fields and `STATUS` as volatile read-only status fields.
- Model A/B scratchpad banks as RW memories and C result bank as RO memory.
- Add a dedicated RAL AXI-Lite frontdoor path:
  - `mini_tpu_ral_bus_item`
  - `mini_tpu_ral_adapter`
  - `mini_tpu_ral_sequencer`
  - `mini_tpu_ral_driver`
- Add `mini_tpu_ral_smoke_test` to program A/B memories, start the TPU, poll STATUS, and read C through RAL frontdoor access.

## Milestone 11: Regression Coverage Merge

- Keep normal `make regression` as the fast functional gate.
- Upgrade `make regression-cov` into a multi-test UVM coverage regression:
  - each UVM test writes an independent VDB under `sim/cov_work/`;
  - URG merges the per-test VDBs into `sim/cov_merged.vdb`;
  - the merged report is written under `sim/cov_report/`;
  - `script/gen_regression_summary.sh` emits `sim/regression_summary.txt`.
- Add `make regression-cov-all` as the 4x4 plus 8x8 coverage signoff target.
