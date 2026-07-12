`ifndef MINI_TPU_RAL_MODEL_SV
`define MINI_TPU_RAL_MODEL_SV

class mini_tpu_ctrl_reg extends uvm_reg;

    `uvm_object_utils(mini_tpu_ctrl_reg)

    uvm_reg_field start;
    uvm_reg_field clear_done;

    function new(string name = "mini_tpu_ctrl_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        start = uvm_reg_field::type_id::create("start");
        clear_done = uvm_reg_field::type_id::create("clear_done");

        start.configure(this, 1, 0, "WO", 0, 1'b0, 1, 0, 0);
        clear_done.configure(this, 1, 1, "WO", 0, 1'b0, 1, 0, 0);
    endfunction

endclass

class mini_tpu_cfg_reg extends uvm_reg;

    `uvm_object_utils(mini_tpu_cfg_reg)

    uvm_reg_field load_bank;
    uvm_reg_field compute_bank;
    uvm_reg_field active_bank;

    function new(string name = "mini_tpu_cfg_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        load_bank = uvm_reg_field::type_id::create("load_bank");
        compute_bank = uvm_reg_field::type_id::create("compute_bank");
        active_bank = uvm_reg_field::type_id::create("active_bank");

        load_bank.configure(this, 1, 0, "RW", 0, 1'b0, 1, 0, 0);
        compute_bank.configure(this, 1, 1, "RW", 0, 1'b0, 1, 0, 0);
        active_bank.configure(this, 1, 2, "RO", 1, 1'b0, 1, 0, 0);
    endfunction

endclass

class mini_tpu_status_reg extends uvm_reg;

    `uvm_object_utils(mini_tpu_status_reg)

    uvm_reg_field busy;
    uvm_reg_field done;

    function new(string name = "mini_tpu_status_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        busy = uvm_reg_field::type_id::create("busy");
        done = uvm_reg_field::type_id::create("done");

        busy.configure(this, 1, 0, "RO", 1, 1'b0, 1, 0, 0);
        done.configure(this, 1, 1, "RO", 1, 1'b0, 1, 0, 0);
    endfunction

endclass

class mini_tpu_ral_model extends uvm_reg_block;

    `uvm_object_utils(mini_tpu_ral_model)

    localparam int ARRAY_SIZE = `MINI_TPU_ARRAY_SIZE;
    localparam int NUM_ELEMS = ARRAY_SIZE * ARRAY_SIZE;

    rand mini_tpu_ctrl_reg   ctrl;
    rand mini_tpu_cfg_reg    cfg;
    rand mini_tpu_status_reg status;
    uvm_mem                  a_mem;
    uvm_mem                  b_mem;
    uvm_mem                  c_mem;

    function new(string name = "mini_tpu_ral_model");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        default_map = create_map("default_map", 12'h000, 4, UVM_LITTLE_ENDIAN, 1);

        ctrl = mini_tpu_ctrl_reg::type_id::create("ctrl");
        ctrl.configure(this, null, "");
        ctrl.build();
        default_map.add_reg(ctrl, 12'h000, "WO");

        status = mini_tpu_status_reg::type_id::create("status");
        status.configure(this, null, "");
        status.build();
        default_map.add_reg(status, 12'h004, "RO");

        cfg = mini_tpu_cfg_reg::type_id::create("cfg");
        cfg.configure(this, null, "");
        cfg.build();
        default_map.add_reg(cfg, 12'h008, "RW");

        a_mem = new("a_mem", NUM_ELEMS, 32, "RW", UVM_NO_COVERAGE);
        a_mem.configure(this, "");
        default_map.add_mem(a_mem, 12'h100, "RW");

        b_mem = new("b_mem", NUM_ELEMS, 32, "RW", UVM_NO_COVERAGE);
        b_mem.configure(this, "");
        default_map.add_mem(b_mem, 12'h200, "RW");

        c_mem = new("c_mem", NUM_ELEMS, 32, "RO", UVM_NO_COVERAGE);
        c_mem.configure(this, "");
        default_map.add_mem(c_mem, 12'h300, "RO");

        lock_model();
    endfunction

endclass

`endif
