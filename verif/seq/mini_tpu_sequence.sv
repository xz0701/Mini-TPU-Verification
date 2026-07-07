`ifndef MINI_TPU_SEQUENCE_SV
`define MINI_TPU_SEQUENCE_SV

class mini_tpu_sequence extends uvm_sequence #(mini_tpu_item);

    `uvm_object_utils(mini_tpu_sequence)

    function new(string name = "mini_tpu_sequence");
        super.new(name);
    endfunction

    virtual task body();
        send_case(0);
        send_case(1);
        send_case(2);
        send_case(3);
        send_case(4);
        send_case(5);
        send_case(6);
        send_case(7);
        send_case(8);
        send_case(9);
        send_case(10);
        send_case(11);
    endtask

    virtual task send_case(int unsigned case_id);
        mini_tpu_item item;
        item = mini_tpu_item::type_id::create("item");

        start_item(item);
        unique case (case_id)
            0: item.set_mixed_signed();
            1: item.set_identity();
            2: item.set_all_zero();
            3: item.set_int8_edge();
            4: item.set_positive_large();
            5: item.set_negative_large();
            6: item.set_bipolar_no_zero();
            7: item.set_value_class_sweep();
            8: item.set_negative_zero_only();
            9: item.set_cross_sweep_low();
            10: item.set_cross_sweep_high();
            11: item.set_negative_corner_outputs();
            default: item.set_mixed_signed();
        endcase
        `uvm_info("MINI_TPU_SEQ", $sformatf("Starting case %0d: %s", case_id, item.case_name), UVM_MEDIUM)
        finish_item(item);
    endtask

endclass

`endif
