`ifndef MINI_TPU_SCOREBOARD_SV
`define MINI_TPU_SCOREBOARD_SV

class mini_tpu_scoreboard extends uvm_component;

    `uvm_component_utils(mini_tpu_scoreboard)

    localparam int ARRAY_SIZE = 4;

    uvm_analysis_imp #(mini_tpu_item, mini_tpu_scoreboard) item_collected_export;
    uvm_event done_ev;

    function new(string name = "mini_tpu_scoreboard", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        item_collected_export = new("item_collected_export", this);
        done_ev = uvm_event_pool::get_global("mini_tpu_scoreboard_done");
    endfunction

    virtual function void write(mini_tpu_item item);
        int signed expected;
        int unsigned mismatch_count;

        mismatch_count = 0;

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                expected = item.expected_at(row, col);
                if (item.c_matrix[row][col] !== expected) begin
                    `uvm_error("MINI_TPU_SCB",
                        $sformatf("Mismatch C[%0d][%0d]: actual=%0d expected=%0d",
                                  row, col, item.c_matrix[row][col], expected))
                    mismatch_count++;
                end else begin
                    `uvm_info("MINI_TPU_SCB",
                        $sformatf("MATCH C[%0d][%0d] = %0d", row, col, item.c_matrix[row][col]),
                        UVM_LOW)
                end
            end
        end

        if (mismatch_count == 0) begin
            `uvm_info("MINI_TPU_SCB",
                $sformatf("PASS: case %s matched expected data", item.case_name),
                UVM_LOW)
        end

        done_ev.trigger();
    endfunction

endclass

`endif
