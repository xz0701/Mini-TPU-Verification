# Mini TPU Project Summary

## Short English Pitch

I built and verified a parameterized mini TPU subsystem around a signed int8 systolic-array matrix multiplication core. The design supports 4x4 and 8x8 configurations, exposes a software-programmable AXI4-Lite register map, stores matrices in a scratchpad, and supports double-buffered input banks so one bank can be used for compute while the other is prepared for the next tile.

The verification environment is UVM-based. It includes focused tests, a scoreboard with a matrix-multiply reference model, functional coverage, a RAL frontdoor path, SystemVerilog assertions, and a Makefile regression flow that produces per-test logs, merged coverage, and a regression summary.

## Architecture

- `mini_tpu_core`: signed int8 systolic-array matrix multiply.
- `mini_tpu_scratchpad`: A/B double-buffered input banks and C result storage.
- `mini_tpu_axi_lite`: AXI4-Lite control/status and memory-mapped access.
- `mini_tpu_dma`: descriptor-controlled DMA preload engine.
- `mini_tpu_ext_mem_model`: testbench external memory for DMA read-master verification.

## Verification Scope

- Directed systolic-array smoke tests.
- AXI-Lite wrapper smoke tests.
- UVM end-to-end compute tests.
- Scratchpad memory read/write and read-only checks.
- Valid and invalid address response checks.
- Busy-time write-protection checks.
- Double-buffer compute/preload flow.
- DMA staging preload and ping-pong flow.
- DMA negative/error/sticky-status behavior.
- External-memory DMA preload flow.
- RAL frontdoor access.
- 4x4 and 8x8 regression coverage.

## Final Signoff

The final signoff run is `make regression-cov-all`.

Latest recorded result:

```text
Totals: pass=20 fail=0 total=20
Coverage report: sim/cov_report
  Group: 100%
```

Merged functional coverage:

```text
matrix_cg: 100%
operation_cg: 100%
dma_cg: 100%
```

## Interview Talking Points

- I started from a small systolic array and grew the project in stages instead of building everything at once.
- I kept 4x4 as a fast debug target and added 8x8 as a parameterized regression target.
- I added an AXI4-Lite software interface, then moved the design toward a more realistic TPU subsystem with scratchpad memory, double buffering, and DMA preload.
- I used UVM tests for scenario coverage, a scoreboard for end-to-end correctness, RAL for register-level access, SVA for protocol and control invariants, and merged coverage regression as the signoff gate.
- I kept scope boundaries clear: the project models the TPU-style data path and verification flow, but it is not a production TPU or a full SoC integration.
