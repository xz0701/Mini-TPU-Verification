`ifndef MINI_TPU_RAL_BUS_ITEM_SV
`define MINI_TPU_RAL_BUS_ITEM_SV

class mini_tpu_ral_bus_item extends uvm_sequence_item;

    `uvm_object_utils(mini_tpu_ral_bus_item)

    rand bit        write;
    rand bit [11:0] addr;
    rand bit [31:0] data;
    rand bit [3:0]  strb;
    bit [1:0]       resp;

    function new(string name = "mini_tpu_ral_bus_item");
        super.new(name);
        strb = 4'hf;
        resp = 2'b00;
    endfunction

endclass

`endif
