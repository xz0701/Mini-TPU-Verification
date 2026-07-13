`ifndef MINI_TPU_INVALID_ADDR_TEST_SV
`define MINI_TPU_INVALID_ADDR_TEST_SV

class mini_tpu_invalid_addr_test extends mini_tpu_base_test;

    `uvm_component_utils(mini_tpu_invalid_addr_test)

    function new(string name = "mini_tpu_invalid_addr_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        bit [31:0] data;

        phase.raise_objection(this);
        wait_for_reset();
        init_bus();

        `uvm_info("MINI_TPU_INVALID_TEST", "Starting invalid address response test", UVM_LOW)

        expect_read_resp(ADDR_CTRL, RESP_OKAY, data);
        expect_read_resp(ADDR_STATUS, RESP_OKAY, data);
        expect_read_resp(ADDR_CFG, RESP_OKAY, data);
        expect_read_resp(ADDR_DMA_CTRL, RESP_OKAY, data);
        expect_read_resp(ADDR_DMA_STATUS, RESP_OKAY, data);
        expect_read_resp(ADDR_DMA_CFG, RESP_OKAY, data);
        expect_read_resp(matrix_addr(ADDR_A_BASE, 0, 0), RESP_OKAY, data);
        expect_read_resp(matrix_addr(ADDR_B_BASE, 3, 3), RESP_OKAY, data);
        expect_read_resp(matrix_addr(ADDR_C_BASE, 1, 2), RESP_OKAY, data);
        expect_read_resp(matrix_addr(ADDR_DMA_A_SRC_BASE, 0, 0), RESP_OKAY, data);
        expect_read_resp(matrix_addr(ADDR_DMA_B_SRC_BASE, 1, 1), RESP_OKAY, data);

        expect_read_resp(12'h00c, RESP_SLVERR, data);
        expect_read_resp(12'h02c, RESP_SLVERR, data);
        expect_read_resp(12'h102, RESP_SLVERR, data);
        expect_read_resp(ADDR_C_BASE + (ARRAY_SIZE * ARRAY_SIZE * 4), RESP_SLVERR, data);
        expect_read_resp(12'h600, RESP_SLVERR, data);

        expect_write_resp(ADDR_CFG, 32'h1, 4'h1, RESP_OKAY);
        expect_write_resp(ADDR_DMA_CFG, 32'h7, 4'h1, RESP_OKAY);
        expect_write_resp(matrix_addr(ADDR_DMA_A_SRC_BASE, 0, 0), 32'h11, 4'h1, RESP_OKAY);
        expect_write_resp(matrix_addr(ADDR_DMA_B_SRC_BASE, 0, 0), 32'h22, 4'h1, RESP_OKAY);
        expect_write_resp(12'h00c, 32'h1, 4'h1, RESP_SLVERR);
        expect_write_resp(12'h02c, 32'h1, 4'h1, RESP_SLVERR);
        expect_write_resp(12'h102, 32'h2, 4'h1, RESP_SLVERR);
        expect_write_resp(ADDR_STATUS, 32'h3, 4'h1, RESP_SLVERR);
        expect_write_resp(ADDR_DMA_STATUS, 32'h3, 4'h1, RESP_SLVERR);
        expect_write_resp(ADDR_C_BASE, 32'h4, 4'h1, RESP_SLVERR);
        expect_write_resp(12'h600, 32'h5, 4'h1, RESP_SLVERR);

        `uvm_info("MINI_TPU_INVALID_TEST", "Invalid address response test completed", UVM_LOW)
        phase.drop_objection(this);
    endtask

endclass

`endif
