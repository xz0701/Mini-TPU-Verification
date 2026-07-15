interface mini_tpu_axi_if #(
    parameter int ADDR_WIDTH = 12,
    parameter int DATA_WIDTH = 32,
    parameter int EXT_MEM_WORDS = 4096
) (
    input logic clk,
    input logic rst_n
);

    logic [ADDR_WIDTH-1:0]     awaddr;
    logic [2:0]                awprot;
    logic                      awvalid;
    logic                      awready;
    logic [DATA_WIDTH-1:0]     wdata;
    logic [(DATA_WIDTH/8)-1:0] wstrb;
    logic                      wvalid;
    logic                      wready;
    logic [1:0]                bresp;
    logic                      bvalid;
    logic                      bready;
    logic [ADDR_WIDTH-1:0]     araddr;
    logic [2:0]                arprot;
    logic                      arvalid;
    logic                      arready;
    logic [DATA_WIDTH-1:0]     rdata;
    logic [1:0]                rresp;
    logic                      rvalid;
    logic                      rready;

    logic [31:0]               dma_mem_araddr;
    logic                      dma_mem_arvalid;
    logic                      dma_mem_arready;
    logic [DATA_WIDTH-1:0]     dma_mem_rdata;
    logic [1:0]                dma_mem_rresp;
    logic                      dma_mem_rvalid;
    logic                      dma_mem_rready;

    logic [DATA_WIDTH-1:0]     ext_mem [0:EXT_MEM_WORDS-1];

    task automatic ext_mem_clear();
        for (int idx = 0; idx < EXT_MEM_WORDS; idx++) begin
            ext_mem[idx] = '0;
        end
    endtask

    task automatic ext_mem_write_word(input bit [31:0] byte_addr, input bit [DATA_WIDTH-1:0] data);
        int unsigned word_idx;

        word_idx = byte_addr >> 2;
        if ((byte_addr[1:0] == 2'b00) && (word_idx < EXT_MEM_WORDS)) begin
            ext_mem[word_idx] = data;
        end
    endtask

    task automatic ext_mem_write_i8(input bit [31:0] byte_addr, input bit signed [7:0] data);
        ext_mem_write_word(byte_addr, {{(DATA_WIDTH-8){data[7]}}, data});
    endtask

endinterface
