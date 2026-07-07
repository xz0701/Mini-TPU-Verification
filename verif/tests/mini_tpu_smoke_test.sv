`ifndef MINI_TPU_SMOKE_TEST_SV
`define MINI_TPU_SMOKE_TEST_SV

class mini_tpu_smoke_test extends uvm_test;

    `uvm_component_utils(mini_tpu_smoke_test)

    mini_tpu_env env;
    mini_tpu_sequence seq;

    function new(string name = "mini_tpu_smoke_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = mini_tpu_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        seq = mini_tpu_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);

        repeat (5) @(posedge env.agent.driver.vif.clk);

        phase.drop_objection(this);
    endtask

endclass

`endif
