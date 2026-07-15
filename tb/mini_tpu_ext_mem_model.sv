module mini_tpu_ext_mem_model #(
    parameter int DATA_WIDTH = 32,
    parameter int EXT_MEM_WORDS = 4096,
    parameter int READ_LATENCY = 2
) (
    mini_tpu_axi_if mem_if
);

    typedef enum logic [1:0] {
        ST_IDLE,
        ST_WAIT,
        ST_RESP
    } state_e;

    state_e state_q;
    int unsigned wait_count_q;
    int unsigned word_idx_q;
    logic [31:0] araddr_q;
    logic [DATA_WIDTH-1:0] rdata_q;
    logic [1:0] rresp_q;

    assign mem_if.dma_mem_arready = (state_q == ST_IDLE) && mem_if.rst_n;
    assign mem_if.dma_mem_rvalid = (state_q == ST_RESP) && mem_if.rst_n;
    assign mem_if.dma_mem_rdata = rdata_q;
    assign mem_if.dma_mem_rresp = rresp_q;

    always_ff @(posedge mem_if.clk or negedge mem_if.rst_n) begin
        if (!mem_if.rst_n) begin
            state_q <= ST_IDLE;
            wait_count_q <= 0;
            word_idx_q <= 0;
            araddr_q <= '0;
            rdata_q <= '0;
            rresp_q <= 2'b00;
        end else begin
            unique case (state_q)
                ST_IDLE: begin
                    if (mem_if.dma_mem_arvalid && mem_if.dma_mem_arready) begin
                        araddr_q <= mem_if.dma_mem_araddr;
                        word_idx_q <= mem_if.dma_mem_araddr >> 2;
                        if ((mem_if.dma_mem_araddr[1:0] != 2'b00) ||
                            ((mem_if.dma_mem_araddr >> 2) >= EXT_MEM_WORDS)) begin
                            rdata_q <= '0;
                            rresp_q <= 2'b10;
                        end else begin
                            rdata_q <= mem_if.ext_mem[mem_if.dma_mem_araddr >> 2];
                            rresp_q <= 2'b00;
                        end

                        wait_count_q <= READ_LATENCY;
                        state_q <= (READ_LATENCY == 0) ? ST_RESP : ST_WAIT;
                    end
                end

                ST_WAIT: begin
                    if (wait_count_q == 0) begin
                        state_q <= ST_RESP;
                    end else begin
                        wait_count_q <= wait_count_q - 1;
                    end
                end

                ST_RESP: begin
                    if (mem_if.dma_mem_rready) begin
                        state_q <= ST_IDLE;
                    end
                end

                default: begin
                    state_q <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
