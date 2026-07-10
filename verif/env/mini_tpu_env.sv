`ifndef MINI_TPU_ENV_SV
`define MINI_TPU_ENV_SV

class mini_tpu_env extends uvm_env;

    `uvm_component_utils(mini_tpu_env)

    mini_tpu_axi_agent agent;
    mini_tpu_scoreboard scoreboard;
    mini_tpu_cov cov;
    mini_tpu_ral_model ral_model;
    mini_tpu_ral_adapter ral_adapter;
    mini_tpu_ral_sequencer ral_sequencer;
    mini_tpu_ral_driver ral_driver;

    function new(string name = "mini_tpu_env", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = mini_tpu_axi_agent::type_id::create("agent", this);
        scoreboard = mini_tpu_scoreboard::type_id::create("scoreboard", this);
        cov = mini_tpu_cov::type_id::create("cov", this);
        ral_model = mini_tpu_ral_model::type_id::create("ral_model");
        ral_model.configure(null, "");
        ral_model.build();
        ral_adapter = mini_tpu_ral_adapter::type_id::create("ral_adapter");
        ral_sequencer = mini_tpu_ral_sequencer::type_id::create("ral_sequencer", this);
        ral_driver = mini_tpu_ral_driver::type_id::create("ral_driver", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agent.monitor.item_collected_port.connect(scoreboard.item_collected_export);
        agent.monitor.item_collected_port.connect(cov.analysis_export);
        ral_driver.seq_item_port.connect(ral_sequencer.seq_item_export);
        ral_model.default_map.set_sequencer(ral_sequencer, ral_adapter);
        ral_model.default_map.set_auto_predict(1);
    endfunction

endclass

`endif
