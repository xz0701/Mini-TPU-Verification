`ifndef MINI_TPU_MEM_TEST_SV
`define MINI_TPU_MEM_TEST_SV

class mini_tpu_mem_test extends mini_tpu_base_test;

    `uvm_component_utils(mini_tpu_mem_test)

    function new(string name = "mini_tpu_mem_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        bit [7:0] a_exp [ARRAY_SIZE][ARRAY_SIZE];
        bit [7:0] b_exp [ARRAY_SIZE][ARRAY_SIZE];
        bit [31:0] data;

        phase.raise_objection(this);
        wait_for_reset();
        init_bus();

        `uvm_info("MINI_TPU_MEM_TEST", "Starting scratchpad write/readback test", UVM_LOW)

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                a_exp[row][col] = (row * ARRAY_SIZE + col) * 7 + 8'h13;
                b_exp[row][col] = 8'hf0 - ((row * ARRAY_SIZE + col) * 5);

                expect_write_resp(matrix_addr(ADDR_A_BASE, row, col), {24'h0, a_exp[row][col]}, 4'h1, RESP_OKAY);
                expect_write_resp(matrix_addr(ADDR_B_BASE, row, col), {24'h0, b_exp[row][col]}, 4'hf, RESP_OKAY);
            end
        end

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                check_matrix_low_byte(ADDR_A_BASE, row, col, a_exp[row][col]);
                check_matrix_low_byte(ADDR_B_BASE, row, col, b_exp[row][col]);
            end
        end

        expect_write_resp(matrix_addr(ADDR_A_BASE, 0, 0), 32'h0000_0055, 4'h1, RESP_OKAY);
        check_matrix_low_byte(ADDR_A_BASE, 0, 0, 8'h55);

        expect_write_resp(matrix_addr(ADDR_A_BASE, 0, 0), 32'h0000_00aa, 4'h0, RESP_OKAY);
        check_matrix_low_byte(ADDR_A_BASE, 0, 0, 8'h55);

        expect_write_resp(matrix_addr(ADDR_A_BASE, 0, 0), 32'h0000_0080, 4'hf, RESP_OKAY);
        check_matrix_low_byte(ADDR_A_BASE, 0, 0, 8'h80);

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                expect_read_resp(matrix_addr(ADDR_C_BASE, row, col), RESP_OKAY, data);
                if (data !== 32'h0) begin
                    `uvm_error("MINI_TPU_MEM_TEST",
                        $sformatf("C bank should remain zero before first compute C[%0d][%0d]=0x%0h",
                                  row, col, data))
                end
            end
        end

        `uvm_info("MINI_TPU_MEM_TEST", "Scratchpad memory test completed", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass

`endif
