module mini_tpu_axi_lite_sva #(
    parameter int ADDR_WIDTH = 12,
    parameter int DATA_WIDTH = 32,
    parameter int ARRAY_SIZE = 4
) (
    input logic                         clk_i,
    input logic                         rst_ni,

    input logic [ADDR_WIDTH-1:0]        s_axi_awaddr,
    input logic                         s_axi_awvalid,
    input logic                         s_axi_awready,
    input logic [DATA_WIDTH-1:0]        s_axi_wdata,
    input logic [(DATA_WIDTH/8)-1:0]    s_axi_wstrb,
    input logic                         s_axi_wvalid,
    input logic                         s_axi_wready,
    input logic [1:0]                   s_axi_bresp,
    input logic                         s_axi_bvalid,
    input logic                         s_axi_bready,
    input logic [ADDR_WIDTH-1:0]        s_axi_araddr,
    input logic                         s_axi_arvalid,
    input logic                         s_axi_arready,
    input logic [DATA_WIDTH-1:0]        s_axi_rdata,
    input logic [1:0]                   s_axi_rresp,
    input logic                         s_axi_rvalid,
    input logic                         s_axi_rready,

    input logic [ADDR_WIDTH-1:0]        aw_addr_q,
    input logic [DATA_WIDTH-1:0]        w_data_q,
    input logic [(DATA_WIDTH/8)-1:0]    w_strb_q,
    input logic                         aw_pending_q,
    input logic                         w_pending_q,
    input logic                         core_start,
    input logic                         core_busy,
    input logic                         core_done,
    input logic                         done_sticky_q,
    input logic                         a_bank_we,
    input logic                         b_bank_we,
    input logic                         load_bank_q,
    input logic                         core_bank_q
);

    localparam logic [ADDR_WIDTH-1:0] ADDR_CTRL   = 12'h000;
    localparam logic [ADDR_WIDTH-1:0] ADDR_STATUS = 12'h004;
    localparam logic [ADDR_WIDTH-1:0] ADDR_CFG    = 12'h008;
    localparam logic [ADDR_WIDTH-1:0] ADDR_A_BASE = 12'h100;
    localparam logic [ADDR_WIDTH-1:0] ADDR_B_BASE = 12'h200;
    localparam logic [ADDR_WIDTH-1:0] ADDR_C_BASE = 12'h300;
    localparam logic [1:0] RESP_OKAY  = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;
    localparam int DONE_BOUND_CYCLES = (3 * ARRAY_SIZE) + 4;

    wire write_fire = aw_pending_q && w_pending_q && !s_axi_bvalid;
    wire ctrl_write_fire = write_fire && (aw_addr_q == ADDR_CTRL) && w_strb_q[0];
    wire done_clear_fire = ctrl_write_fire && (w_data_q[1] || w_data_q[0]);

    default clocking cb @(posedge clk_i);
    endclocking

    function automatic bit is_matrix_addr(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [ADDR_WIDTH-1:0] base
    );
        is_matrix_addr = (addr >= base) &&
                         (addr < (base + (ARRAY_SIZE * ARRAY_SIZE * (DATA_WIDTH/8)))) &&
                         (addr[1:0] == 2'b00);
    endfunction

    function automatic bit is_valid_write_addr(input logic [ADDR_WIDTH-1:0] addr);
        is_valid_write_addr = (addr == ADDR_CTRL) ||
                              (addr == ADDR_CFG) ||
                              is_matrix_addr(addr, ADDR_A_BASE) ||
                              is_matrix_addr(addr, ADDR_B_BASE);
    endfunction

    function automatic bit is_valid_read_addr(input logic [ADDR_WIDTH-1:0] addr);
        is_valid_read_addr = (addr == ADDR_CTRL) ||
                             (addr == ADDR_STATUS) ||
                             (addr == ADDR_CFG) ||
                             is_matrix_addr(addr, ADDR_A_BASE) ||
                             is_matrix_addr(addr, ADDR_B_BASE) ||
                             is_matrix_addr(addr, ADDR_C_BASE);
    endfunction

    a_reset_outputs: assert property (
        !rst_ni |-> (!s_axi_awready && !s_axi_wready && !s_axi_arready &&
                    !s_axi_bvalid && !s_axi_rvalid && !core_start && !done_sticky_q)
    );

    a_bvalid_stable_until_ready: assert property (
        disable iff (!rst_ni)
        (s_axi_bvalid && !s_axi_bready) |=> (s_axi_bvalid && $stable(s_axi_bresp))
    );

    a_rvalid_stable_until_ready: assert property (
        disable iff (!rst_ni)
        (s_axi_rvalid && !s_axi_rready) |=> (s_axi_rvalid &&
                                             $stable(s_axi_rdata) &&
                                             $stable(s_axi_rresp))
    );

    a_awaddr_stable_until_ready: assert property (
        disable iff (!rst_ni)
        (s_axi_awvalid && !s_axi_awready) |=> (s_axi_awvalid && $stable(s_axi_awaddr))
    );

    a_wdata_stable_until_ready: assert property (
        disable iff (!rst_ni)
        (s_axi_wvalid && !s_axi_wready) |=> (s_axi_wvalid &&
                                             $stable(s_axi_wdata) &&
                                             $stable(s_axi_wstrb))
    );

    a_araddr_stable_until_ready: assert property (
        disable iff (!rst_ni)
        (s_axi_arvalid && !s_axi_arready) |=> (s_axi_arvalid && $stable(s_axi_araddr))
    );

    a_write_resp_valid_addr: assert property (
        disable iff (!rst_ni)
        (write_fire && is_valid_write_addr(aw_addr_q)) |=> (s_axi_bvalid && s_axi_bresp == RESP_OKAY)
    );

    a_write_resp_invalid_addr: assert property (
        disable iff (!rst_ni)
        (write_fire && !is_valid_write_addr(aw_addr_q)) |=> (s_axi_bvalid && s_axi_bresp == RESP_SLVERR)
    );

    a_read_resp_valid_addr: assert property (
        disable iff (!rst_ni)
        (s_axi_arvalid && s_axi_arready && is_valid_read_addr(s_axi_araddr)) |=>
            (s_axi_rvalid && s_axi_rresp == RESP_OKAY)
    );

    a_read_resp_invalid_addr: assert property (
        disable iff (!rst_ni)
        (s_axi_arvalid && s_axi_arready && !is_valid_read_addr(s_axi_araddr)) |=>
            (s_axi_rvalid && s_axi_rresp == RESP_SLVERR)
    );

    a_start_one_cycle: assert property (
        disable iff (!rst_ni)
        core_start |=> !core_start
    );

    a_start_only_when_idle: assert property (
        disable iff (!rst_ni)
        core_start |-> !core_busy
    );

    a_start_to_done_bounded: assert property (
        disable iff (!rst_ni)
        core_start |-> ##[1:DONE_BOUND_CYCLES] core_done
    );

    a_done_one_cycle: assert property (
        disable iff (!rst_ni)
        core_done |=> !core_done
    );

    a_done_sets_sticky: assert property (
        disable iff (!rst_ni)
        core_done |=> done_sticky_q
    );

    a_done_sticky_holds_until_clear: assert property (
        disable iff (!rst_ni)
        (done_sticky_q && !done_clear_fire) |=> done_sticky_q
    );

    a_no_active_input_bank_write_while_busy: assert property (
        disable iff (!rst_ni)
        (core_busy && (load_bank_q == core_bank_q)) |-> (!a_bank_we && !b_bank_we)
    );

    a_busy_input_write_targets_inactive_bank: assert property (
        disable iff (!rst_ni)
        (core_busy && (a_bank_we || b_bank_we)) |-> (load_bank_q != core_bank_q)
    );

endmodule

bind mini_tpu_axi_lite mini_tpu_axi_lite_sva #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ARRAY_SIZE(ARRAY_SIZE)
) u_mini_tpu_axi_lite_sva (
    .clk_i         (clk_i),
    .rst_ni        (rst_ni),
    .s_axi_awaddr  (s_axi_awaddr),
    .s_axi_awvalid (s_axi_awvalid),
    .s_axi_awready (s_axi_awready),
    .s_axi_wdata   (s_axi_wdata),
    .s_axi_wstrb   (s_axi_wstrb),
    .s_axi_wvalid  (s_axi_wvalid),
    .s_axi_wready  (s_axi_wready),
    .s_axi_bresp   (s_axi_bresp),
    .s_axi_bvalid  (s_axi_bvalid),
    .s_axi_bready  (s_axi_bready),
    .s_axi_araddr  (s_axi_araddr),
    .s_axi_arvalid (s_axi_arvalid),
    .s_axi_arready (s_axi_arready),
    .s_axi_rdata   (s_axi_rdata),
    .s_axi_rresp   (s_axi_rresp),
    .s_axi_rvalid  (s_axi_rvalid),
    .s_axi_rready  (s_axi_rready),
    .aw_addr_q     (aw_addr_q),
    .w_data_q      (w_data_q),
    .w_strb_q      (w_strb_q),
    .aw_pending_q  (aw_pending_q),
    .w_pending_q   (w_pending_q),
    .core_start    (core_start),
    .core_busy     (core_busy),
    .core_done     (core_done),
    .done_sticky_q (done_sticky_q),
    .a_bank_we     (a_bank_we),
    .b_bank_we     (b_bank_we),
    .load_bank_q   (load_bank_q),
    .core_bank_q   (core_bank_q)
);
