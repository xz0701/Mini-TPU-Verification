`ifndef MINI_TPU_RAL_SEQUENCER_SV
`define MINI_TPU_RAL_SEQUENCER_SV

class mini_tpu_ral_sequencer extends uvm_sequencer #(mini_tpu_ral_bus_item);

    `uvm_component_utils(mini_tpu_ral_sequencer)

    function new(string name = "mini_tpu_ral_sequencer", uvm_component parent);
        super.new(name, parent);
    endfunction

endclass

`endif
