`ifndef MINI_TPU_RAL_ADAPTER_SV
`define MINI_TPU_RAL_ADAPTER_SV

class mini_tpu_ral_adapter extends uvm_reg_adapter;

    `uvm_object_utils(mini_tpu_ral_adapter)

    function new(string name = "mini_tpu_ral_adapter");
        super.new(name);
        supports_byte_enable = 1;
        provides_responses = 0;
    endfunction

    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        mini_tpu_ral_bus_item item;

        item = mini_tpu_ral_bus_item::type_id::create("item");
        item.write = (rw.kind == UVM_WRITE);
        item.addr  = rw.addr[11:0];
        item.data  = rw.data[31:0];
        item.strb  = byte_en_to_strb(rw.byte_en);

        return item;
    endfunction

    virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        mini_tpu_ral_bus_item item;

        if (!$cast(item, bus_item)) begin
            `uvm_fatal("MINI_TPU_RAL_ADAPT", "bus_item is not mini_tpu_ral_bus_item")
        end

        rw.kind   = item.write ? UVM_WRITE : UVM_READ;
        rw.addr   = item.addr;
        rw.data   = item.data;
        rw.status = (item.resp == 2'b00) ? UVM_IS_OK : UVM_NOT_OK;
    endfunction

    function bit [3:0] byte_en_to_strb(uvm_reg_byte_en_t byte_en);
        byte_en_to_strb = byte_en[3:0];

        if (byte_en_to_strb == 4'h0) begin
            byte_en_to_strb = 4'hf;
        end
    endfunction

endclass

`endif
