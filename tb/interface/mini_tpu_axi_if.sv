interface mini_tpu_axi_if #(
    parameter int ADDR_WIDTH = 12,
    parameter int DATA_WIDTH = 32
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

endinterface
