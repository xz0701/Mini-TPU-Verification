`ifndef MINI_TPU_AXI_AGENT_SV
`define MINI_TPU_AXI_AGENT_SV

class mini_tpu_axi_agent extends uvm_agent;

    `uvm_component_utils(mini_tpu_axi_agent)

    mini_tpu_sequencer   sequencer;
    mini_tpu_axi_driver  driver;
    mini_tpu_axi_monitor monitor;

    function new(string name = "mini_tpu_axi_agent", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sequencer = mini_tpu_sequencer::type_id::create("sequencer", this);
        driver    = mini_tpu_axi_driver::type_id::create("driver", this);
        monitor   = mini_tpu_axi_monitor::type_id::create("monitor", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction

endclass

`endif
