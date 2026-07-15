`ifndef MINI_TPU_PKG_SV
`define MINI_TPU_PKG_SV

package mini_tpu_pkg;

    import uvm_pkg::*;
    `include "mini_tpu_config.svh"
    `include "uvm_macros.svh"

    `include "mini_tpu_item.sv"
    `include "mini_tpu_sequence.sv"
    `include "mini_tpu_sequencer.sv"
    `include "mini_tpu_axi_driver.sv"
    `include "mini_tpu_axi_monitor.sv"
    `include "mini_tpu_axi_agent.sv"
    `include "mini_tpu_ral_bus_item.sv"
    `include "mini_tpu_ral_sequencer.sv"
    `include "mini_tpu_ral_driver.sv"
    `include "mini_tpu_ral_adapter.sv"
    `include "mini_tpu_ral_model.sv"
    `include "mini_tpu_scoreboard.sv"
    `include "mini_tpu_cov.sv"
    `include "mini_tpu_env.sv"
    `include "mini_tpu_base_test.sv"
    `include "mini_tpu_smoke_test.sv"
    `include "mini_tpu_mem_test.sv"
    `include "mini_tpu_invalid_addr_test.sv"
    `include "mini_tpu_busy_write_test.sv"
    `include "mini_tpu_double_buffer_test.sv"
    `include "mini_tpu_dma_test.sv"
    `include "mini_tpu_dma_error_test.sv"
    `include "mini_tpu_dma_external_test.sv"
    `include "mini_tpu_8x8_stress_test.sv"
    `include "mini_tpu_ral_smoke_test.sv"

endpackage

`endif
