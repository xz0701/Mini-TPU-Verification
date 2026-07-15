# Mini TPU Signoff Checklist

## Signoff Snapshot

- Date: 2026-07-15
- Latest summary: `sim/regression_summary.txt`
- Result: `pass=20 fail=0 total=20`
- Merged coverage report: `sim/cov_report`
- Merged functional coverage: `Group: 100%`
- Functional covergroups:
  - `mini_tpu_pkg::mini_tpu_cov::matrix_cg`: 100%
  - `mini_tpu_pkg::mini_tpu_cov::operation_cg`: 100%
  - `mini_tpu_pkg::mini_tpu_cov::dma_cg`: 100%

## Final Commands

```sh
make regression-cov-all
```

Useful focused reruns:

```sh
make uvm-clean-run UVM_TEST=mini_tpu_dma_external_test ARRAY_SIZE=4
make uvm-clean-run UVM_TEST=mini_tpu_dma_external_test ARRAY_SIZE=8
make uvm-clean-run UVM_TEST=mini_tpu_dma_error_test ARRAY_SIZE=8
```

## Feature Gates

- Parameterized 4x4 and 8x8 systolic-array matrix multiply.
- AXI4-Lite software-visible control and status path.
- Scratchpad-backed A/B/C memories.
- Double-buffered A/B input banks.
- Busy-time inactive-bank preload.
- Descriptor-controlled DMA staging copy from `0x400` and `0x500`.
- DMA negative behavior: no-copy start, busy restart, active-bank conflict, sticky clear.
- External-memory DMA read path through `DMA_A_SRC_ADDR`, `DMA_B_SRC_ADDR`, and `DMA_CFG[3]`.
- UVM scoreboard compares computed C matrix against the reference model.
- RAL frontdoor smoke covers core CSRs, scratchpad memories, and DMA CSRs.
- SVA covers AXI-Lite response stability, valid/invalid response behavior, start/done rules, bank-write protection, and DMA sticky/error behavior.

## Regression Tests

- `mini_tpu_smoke_test`
- `mini_tpu_mem_test`
- `mini_tpu_invalid_addr_test`
- `mini_tpu_busy_write_test`
- `mini_tpu_double_buffer_test`
- `mini_tpu_dma_test`
- `mini_tpu_dma_error_test`
- `mini_tpu_dma_external_test`
- `mini_tpu_8x8_stress_test`
- `mini_tpu_ral_smoke_test`

Each UVM test is run in both 4x4 and 8x8 configurations by `make regression-cov-all`.

## Known Scope Boundaries

- The external DMA path uses a compact read-master channel in the mini TPU subsystem, not a full AXI4 master implementation.
- The external memory is a testbench model with programmable read latency and SLVERR behavior.
- The project is intended as a small TPU-style verification project, not a cycle-accurate reproduction of Google's production TPU.
- Performance modeling, cache coherency, interrupt delivery, and full SoC integration are out of scope for this milestone.

## Exit Criteria

- No `UVM_ERROR` or `UVM_FATAL` in the final regression summary.
- `fail=0` in `sim/regression_summary.txt`.
- Merged functional coverage is 100%.
- New feature work is frozen unless a regression failure is found.
