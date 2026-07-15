`ifndef MINI_TPU_DMA_ERROR_TEST_SV
`define MINI_TPU_DMA_ERROR_TEST_SV

class mini_tpu_dma_error_test extends mini_tpu_base_test;

    `uvm_component_utils(mini_tpu_dma_error_test)

    localparam int unsigned DMA_ERR_NONE        = 0;
    localparam int unsigned DMA_ERR_NO_COPY     = 1;
    localparam int unsigned DMA_ERR_BUSY        = 2;
    localparam int unsigned DMA_ERR_TARGET_BUSY = 3;

    localparam int unsigned DMA_CLR_NONE  = 0;
    localparam int unsigned DMA_CLR_DONE  = 1;
    localparam int unsigned DMA_CLR_ERROR = 2;
    localparam int unsigned DMA_CLR_BOTH  = 3;

    function new(string name = "mini_tpu_dma_error_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        bit [31:0] data;

        phase.raise_objection(this);
        wait_for_reset();
        init_bus();

        `uvm_info("MINI_TPU_DMA_ERROR_TEST", "Starting DMA negative/error test", UVM_LOW)

        clear_dma_status();

        expect_write_resp(ADDR_DMA_CFG, 32'h0000_0000, 4'h1, RESP_OKAY);
        sample_dma_cov(0, 0, DMA_ERR_NONE, 0, DMA_CLR_NONE);
        expect_write_resp(ADDR_DMA_CTRL, 32'h0000_0001, 4'h1, RESP_OKAY);
        expect_dma_status(1'b0, 1'b0, 1'b1, "no-copy start should set error sticky");
        sample_dma_cov(0, 0, DMA_ERR_NO_COPY, 0, DMA_CLR_NONE);

        expect_write_resp(ADDR_DMA_CTRL, 32'h0000_0004, 4'h1, RESP_OKAY);
        expect_dma_status(1'b0, 1'b0, 1'b0, "clear error sticky after no-copy start");
        sample_dma_cov(0, 0, DMA_ERR_NONE, 0, DMA_CLR_ERROR);

        expect_write_resp(matrix_addr(ADDR_DMA_A_SRC_BASE, 0, 0), 32'h0000_0011, 4'h1, RESP_OKAY);
        expect_write_resp(ADDR_DMA_CFG, 32'h0000_0002, 4'h1, RESP_OKAY);
        sample_dma_cov(0, 1, DMA_ERR_NONE, 0, DMA_CLR_NONE);
        expect_write_resp(ADDR_DMA_CFG, 32'h0000_0006, 4'h1, RESP_OKAY);
        sample_dma_cov(0, 3, DMA_ERR_NONE, 0, DMA_CLR_NONE);
        expect_write_resp(ADDR_DMA_CTRL, 32'h0000_0001, 4'h1, RESP_OKAY);
        wait_dma_busy();

        expect_write_resp(matrix_addr(ADDR_DMA_A_SRC_BASE, 0, 0), 32'h0000_007e, 4'h1, RESP_OKAY);
        expect_write_resp(ADDR_DMA_CTRL, 32'h0000_0001, 4'h1, RESP_OKAY);
        sample_dma_cov(0, 3, DMA_ERR_BUSY, 1, DMA_CLR_NONE);
        wait_dma_done_allow_error();
        expect_dma_status(1'b0, 1'b1, 1'b1, "busy restart should leave done and error sticky set");
        expect_read_resp(matrix_addr(ADDR_DMA_A_SRC_BASE, 0, 0), RESP_OKAY, data);
        if (data[7:0] !== 8'h11) begin
            `uvm_error("MINI_TPU_DMA_ERROR_TEST",
                $sformatf("DMA source staging changed while busy actual=0x%0h expected=0x11", data[7:0]))
        end

        expect_write_resp(ADDR_DMA_CTRL, 32'h0000_0006, 4'h1, RESP_OKAY);
        expect_dma_status(1'b0, 1'b0, 1'b0, "clear both DMA sticky bits");
        sample_dma_cov(0, 3, DMA_ERR_NONE, 0, DMA_CLR_BOTH);

        expect_write_resp(ADDR_DMA_CFG, 32'h0000_0005, 4'h1, RESP_OKAY);
        sample_dma_cov(1, 2, DMA_ERR_NONE, 0, DMA_CLR_NONE);
        expect_write_resp(ADDR_DMA_CTRL, 32'h0000_0001, 4'h1, RESP_OKAY);
        wait_dma_done_allow_error();
        expect_dma_status(1'b0, 1'b1, 1'b0, "B-only DMA should complete without error");
        expect_write_resp(ADDR_DMA_CTRL, 32'h0000_0002, 4'h1, RESP_OKAY);
        expect_dma_status(1'b0, 1'b0, 1'b0, "clear done sticky only");
        sample_dma_cov(1, 2, DMA_ERR_NONE, 0, DMA_CLR_DONE);

        expect_write_resp(ADDR_DMA_CFG, 32'h0000_0007, 4'h1, RESP_OKAY);
        sample_dma_cov(1, 3, DMA_ERR_NONE, 0, DMA_CLR_NONE);

        expect_write_resp(ADDR_DMA_CFG, 32'h0000_0002, 4'h1, RESP_OKAY);
        expect_write_resp(ADDR_CFG, 32'h0000_0000, 4'h1, RESP_OKAY);
        start_core();
        expect_write_resp(ADDR_DMA_CTRL, 32'h0000_0001, 4'h1, RESP_OKAY);
        expect_dma_status(1'b0, 1'b0, 1'b1, "DMA to active core bank should set error sticky");
        sample_dma_cov(0, 1, DMA_ERR_TARGET_BUSY, 0, DMA_CLR_NONE);

        poll_done();
        clear_done_sticky();
        expect_write_resp(ADDR_DMA_CTRL, 32'h0000_0004, 4'h1, RESP_OKAY);
        expect_dma_status(1'b0, 1'b0, 1'b0, "clear target-busy error sticky");
        sample_dma_cov(0, 1, DMA_ERR_NONE, 0, DMA_CLR_ERROR);

        `uvm_info("MINI_TPU_DMA_ERROR_TEST", "DMA negative/error test completed", UVM_LOW)
        phase.drop_objection(this);
    endtask

    task automatic expect_dma_status(
        input bit exp_busy,
        input bit exp_done,
        input bit exp_error,
        input string msg
    );
        bit [31:0] status;

        expect_read_resp(ADDR_DMA_STATUS, RESP_OKAY, status);
        if ((status[0] !== exp_busy) || (status[1] !== exp_done) || (status[2] !== exp_error)) begin
            `uvm_error("MINI_TPU_DMA_ERROR_TEST",
                $sformatf("%s: status=0x%0h expected busy/done/error=%0b/%0b/%0b",
                          msg, status, exp_busy, exp_done, exp_error))
        end
    endtask

    task automatic wait_dma_busy();
        bit [31:0] status;

        for (int timeout = 0; timeout < 20; timeout++) begin
            expect_read_resp(ADDR_DMA_STATUS, RESP_OKAY, status);
            if (status[0]) begin
                return;
            end
            repeat (1) @(posedge vif.clk);
        end

        `uvm_error("MINI_TPU_DMA_ERROR_TEST", "Timeout waiting for DMA busy")
    endtask

    task automatic wait_dma_done_allow_error();
        bit [31:0] status;

        for (int timeout = 0; timeout < (ARRAY_SIZE * ARRAY_SIZE * 4); timeout++) begin
            expect_read_resp(ADDR_DMA_STATUS, RESP_OKAY, status);
            if (status[1]) begin
                return;
            end
            repeat (1) @(posedge vif.clk);
        end

        `uvm_error("MINI_TPU_DMA_ERROR_TEST", "Timeout waiting for DMA done sticky")
    endtask

    function void sample_dma_cov(
        int unsigned target_bank,
        int unsigned copy_mode,
        int unsigned error_reason,
        bit          source_write_busy,
        int unsigned clear_op
    );
        env.cov.sample_dma(target_bank, copy_mode, 0, error_reason, source_write_busy, clear_op);
    endfunction

endclass

`endif
