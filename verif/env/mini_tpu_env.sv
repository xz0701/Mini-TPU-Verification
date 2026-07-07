`ifndef MINI_TPU_ENV_SV
`define MINI_TPU_ENV_SV

class mini_tpu_env extends uvm_env;

    `uvm_component_utils(mini_tpu_env)

    mini_tpu_axi_agent agent;
    mini_tpu_scoreboard scoreboard;
    mini_tpu_cov cov;

    function new(string name = "mini_tpu_env", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = mini_tpu_axi_agent::type_id::create("agent", this);
        scoreboard = mini_tpu_scoreboard::type_id::create("scoreboard", this);
        cov = mini_tpu_cov::type_id::create("cov", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.item_collected_port.connect(scoreboard.item_collected_export);
        agent.monitor.item_collected_port.connect(cov.analysis_export);
    endfunction

endclass

`endif
