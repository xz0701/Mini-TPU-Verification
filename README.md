# Mini-TPU-Verification

Mini TPU RTL and verification project.

The first milestone is a 4x4 signed int8 systolic-array matrix multiplication core. The project starts with a directed smoke test before growing into a UVM environment.

## Current Structure

```text
rtl/
  tpu_mac_cell.sv
  systolic_array_4x4.sv
  mini_tpu_core.sv
tb/
  tb_systolic_smoke.sv
script/
  filelist.f
verif/
  agent/
  env/
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
0x100 A[0][0]..A[3][3], one signed int8 per 32-bit word
0x200 B[0][0]..B[3][3], one signed int8 per 32-bit word
0x300 C[0][0]..C[3][3], one signed int32 per 32-bit word
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

Functional coverage is printed in `run.log` by `mini_tpu_cov`.

For VCS code coverage:

```sh
make uvm-cov-setup-run
make uvm-cov-report
```

The generated HTML/text coverage report is written under `sim/cov_report/`.
