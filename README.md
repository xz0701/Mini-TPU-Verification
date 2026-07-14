# Mini-TPU-Verification

Mini TPU RTL and verification project.

The design is a parameterized signed int8 systolic-array matrix multiplication core with an AXI4-Lite scratchpad wrapper. The default quick configuration is 4x4, and the same RTL/UVM flow can run 8x8 with `ARRAY_SIZE=8`.

## Current Structure

```text
rtl/
  tpu_mac_cell.sv
  systolic_array.sv
  mini_tpu_core.sv
  mini_tpu_scratchpad.sv
  mini_tpu_axi_lite.sv
tb/
  mini_tpu_config.svh
  tb_systolic_smoke.sv
  tb_axi_lite_smoke.sv
script/
  filelist.f
  filelist_axi.f
  filelist_uvm.f
verif/
  agent/
  env/
  ral/
  seq/
  tests/
  top/
```

## Run

```sh
make run
```

If VCS is not already in `PATH`, use:

```sh
make setup-run
```

Run the 8x8 configuration with:

```sh
make regression ARRAY_SIZE=8
```

or:

```sh
make regression-8x8
```

## Directed Cases

`tb/tb_systolic_smoke.sv` currently checks:

- mixed signed matrix multiply
- identity matrix behavior
- zero matrix behavior
- int8 edge values
- back-to-back operation
- reset during computation
- post-reset operation

## AXI-Lite Wrapper

`mini_tpu_axi_lite.sv` wraps the core with a small AXI4-Lite register map:

```text
0x000 CTRL    bit0=start, bit1=clear done sticky
0x004 STATUS  bit0=busy, bit1=done sticky
0x008 CFG     bit0=load bank, bit1=compute bank, bit2=active compute bank
0x020 DMA_CTRL    bit0=start, bit1=clear done, bit2=clear error
0x024 DMA_STATUS  bit0=busy, bit1=done sticky, bit2=error sticky
0x028 DMA_CFG     bit0=target bank, bit1=copy A, bit2=copy B
0x100 A bank, one signed int8 per 32-bit word
0x200 B bank, one signed int8 per 32-bit word
0x300 C bank, one signed int32 per 32-bit word
0x400 DMA A source staging, one signed int8 per 32-bit word
0x500 DMA B source staging, one signed int8 per 32-bit word
```

The A/B scratchpad is double-buffered. `CFG.load_bank` selects which input bank AXI reads and writes use, while `CFG.compute_bank` selects the input bank used by the next TPU operation. During an active compute, writes to the inactive bank are accepted so software or a future DMA path can preload the next tile.

The first DMA block is descriptor controlled through AXI-Lite. Software stages source A/B tiles in the `0x400` and `0x500` windows, programs `DMA_CFG`, then starts a copy into the selected inactive A/B scratchpad bank. This models the data-movement path before adding a full external AXI master.

DMA negative tests cover no-copy starts, busy restarts, source-staging writes while busy, active-bank conflicts, and done/error sticky clear behavior.

For 8x8, each bank uses 64 words, so the existing 12-bit map covers:

```text
A: 0x100 - 0x1ff
B: 0x200 - 0x2ff
C: 0x300 - 0x3ff
```

Run the AXI-Lite directed smoke with:

```sh
make axi-setup-run
```

## UVM Smoke

The first UVM smoke uses the AXI-Lite wrapper:

```sh
make uvm-setup-run
```

The UVM sequence writes A/B matrices, starts the TPU through `CTRL`, waits for `STATUS.done`, reads C, and checks the result in the scoreboard.

Functional coverage is printed by `mini_tpu_cov` in the per-test run log.

The UVM environment also includes a RAL model:

```text
CTRL       0x000, write-only start / clear-done fields
STATUS     0x004, read-only busy / done fields
CFG        0x008, load-bank / compute-bank selection
DMA_CTRL   0x020, DMA start / clear sticky fields
DMA_STATUS 0x024, DMA busy / done / error fields
DMA_CFG    0x028, DMA target-bank and A/B copy enables
A memory   0x100, RW scratchpad bank
B memory   0x200, RW scratchpad bank
C memory   0x300, RO result bank
DMA A src  0x400, RW source staging memory
DMA B src  0x500, RW source staging memory
```

Run the RAL frontdoor smoke with:

```sh
make uvm-run UVM_TEST=mini_tpu_ral_smoke_test
```

Regression runs use per-target logs instead of overwriting one file. Examples:

```text
sim/run_tb_systolic_smoke_8x8.log
sim/run_tb_mini_tpu_uvm_8x8_mini_tpu_smoke_test.log
sim/run_tb_mini_tpu_uvm_8x8_mini_tpu_8x8_stress_test.log
```

For a single UVM coverage run:

```sh
make uvm-cov-setup-run
make uvm-cov-report
```

For a coverage regression with one VDB per UVM test and a merged URG report:

```sh
make regression-cov ARRAY_SIZE=8
```

For both 4x4 and 8x8 coverage regression:

```sh
make regression-cov-all
```

The generated artifacts are:

```text
sim/cov_work/                 per-test VDBs
sim/cov_merged.vdb            merged coverage database
sim/cov_report/               merged HTML/text URG report
sim/regression_summary.txt    pass/fail and coverage summary
```
