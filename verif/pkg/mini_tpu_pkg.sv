`ifndef MINI_TPU_PKG_SV
`define MINI_TPU_PKG_SV

package mini_tpu_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "mini_tpu_item.sv"
    `include "mini_tpu_sequence.sv"
    `include "mini_tpu_sequencer.sv"
    `include "mini_tpu_axi_driver.sv"
    `include "mini_tpu_axi_monitor.sv"
    `include "mini_tpu_axi_agent.sv"
    `include "mini_tpu_scoreboard.sv"
    `include "mini_tpu_cov.sv"
    `include "mini_tpu_env.sv"
    `include "mini_tpu_smoke_test.sv"

endpackage

`endif
