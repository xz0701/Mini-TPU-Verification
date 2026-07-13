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

class mini_tpu_dma_ctrl_reg extends uvm_reg;

    `uvm_object_utils(mini_tpu_dma_ctrl_reg)

    uvm_reg_field start;
    uvm_reg_field clear_done;
    uvm_reg_field clear_error;

    function new(string name = "mini_tpu_dma_ctrl_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        start = uvm_reg_field::type_id::create("start");
        clear_done = uvm_reg_field::type_id::create("clear_done");
        clear_error = uvm_reg_field::type_id::create("clear_error");

        start.configure(this, 1, 0, "WO", 0, 1'b0, 1, 0, 0);
        clear_done.configure(this, 1, 1, "WO", 0, 1'b0, 1, 0, 0);
        clear_error.configure(this, 1, 2, "WO", 0, 1'b0, 1, 0, 0);
    endfunction

endclass

class mini_tpu_dma_status_reg extends uvm_reg;

    `uvm_object_utils(mini_tpu_dma_status_reg)

    uvm_reg_field busy;
    uvm_reg_field done;
    uvm_reg_field error;

    function new(string name = "mini_tpu_dma_status_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        busy = uvm_reg_field::type_id::create("busy");
        done = uvm_reg_field::type_id::create("done");
        error = uvm_reg_field::type_id::create("error");

        busy.configure(this, 1, 0, "RO", 1, 1'b0, 1, 0, 0);
        done.configure(this, 1, 1, "RO", 1, 1'b0, 1, 0, 0);
        error.configure(this, 1, 2, "RO", 1, 1'b0, 1, 0, 0);
    endfunction

endclass

class mini_tpu_dma_cfg_reg extends uvm_reg;

    `uvm_object_utils(mini_tpu_dma_cfg_reg)

    uvm_reg_field target_bank;
    uvm_reg_field copy_a;
    uvm_reg_field copy_b;

    function new(string name = "mini_tpu_dma_cfg_reg");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        target_bank = uvm_reg_field::type_id::create("target_bank");
        copy_a = uvm_reg_field::type_id::create("copy_a");
        copy_b = uvm_reg_field::type_id::create("copy_b");

        target_bank.configure(this, 1, 0, "RW", 0, 1'b0, 1, 0, 0);
        copy_a.configure(this, 1, 1, "RW", 0, 1'b1, 1, 0, 0);
        copy_b.configure(this, 1, 2, "RW", 0, 1'b1, 1, 0, 0);
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
    rand mini_tpu_dma_ctrl_reg   dma_ctrl;
    rand mini_tpu_dma_status_reg dma_status;
    rand mini_tpu_dma_cfg_reg    dma_cfg;
    uvm_mem                  a_mem;
    uvm_mem                  b_mem;
    uvm_mem                  c_mem;
    uvm_mem                  dma_a_src_mem;
    uvm_mem                  dma_b_src_mem;

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

        dma_ctrl = mini_tpu_dma_ctrl_reg::type_id::create("dma_ctrl");
        dma_ctrl.configure(this, null, "");
        dma_ctrl.build();
        default_map.add_reg(dma_ctrl, 12'h020, "WO");

        dma_status = mini_tpu_dma_status_reg::type_id::create("dma_status");
        dma_status.configure(this, null, "");
        dma_status.build();
        default_map.add_reg(dma_status, 12'h024, "RO");

        dma_cfg = mini_tpu_dma_cfg_reg::type_id::create("dma_cfg");
        dma_cfg.configure(this, null, "");
        dma_cfg.build();
        default_map.add_reg(dma_cfg, 12'h028, "RW");

        a_mem = new("a_mem", NUM_ELEMS, 32, "RW", UVM_NO_COVERAGE);
        a_mem.configure(this, "");
        default_map.add_mem(a_mem, 12'h100, "RW");

        b_mem = new("b_mem", NUM_ELEMS, 32, "RW", UVM_NO_COVERAGE);
        b_mem.configure(this, "");
        default_map.add_mem(b_mem, 12'h200, "RW");

        c_mem = new("c_mem", NUM_ELEMS, 32, "RO", UVM_NO_COVERAGE);
        c_mem.configure(this, "");
        default_map.add_mem(c_mem, 12'h300, "RO");

        dma_a_src_mem = new("dma_a_src_mem", NUM_ELEMS, 32, "RW", UVM_NO_COVERAGE);
        dma_a_src_mem.configure(this, "");
        default_map.add_mem(dma_a_src_mem, 12'h400, "RW");

        dma_b_src_mem = new("dma_b_src_mem", NUM_ELEMS, 32, "RW", UVM_NO_COVERAGE);
        dma_b_src_mem.configure(this, "");
        default_map.add_mem(dma_b_src_mem, 12'h500, "RW");

        lock_model();
    endfunction

endclass

`endif
