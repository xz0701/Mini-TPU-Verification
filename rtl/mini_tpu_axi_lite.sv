module mini_tpu_axi_lite #(
    parameter int ADDR_WIDTH = 12,
    parameter int DATA_WIDTH = 32,
    parameter int ARRAY_SIZE = 4,
    parameter int MAT_WIDTH  = 8,
    parameter int ACC_WIDTH  = 32
) (
    input  logic                         clk_i,
    input  logic                         rst_ni,

    input  logic [ADDR_WIDTH-1:0]        s_axi_awaddr,
    input  logic [2:0]                   s_axi_awprot,
    input  logic                         s_axi_awvalid,
    output logic                         s_axi_awready,

    input  logic [DATA_WIDTH-1:0]        s_axi_wdata,
    input  logic [(DATA_WIDTH/8)-1:0]    s_axi_wstrb,
    input  logic                         s_axi_wvalid,
    output logic                         s_axi_wready,

    output logic [1:0]                   s_axi_bresp,
    output logic                         s_axi_bvalid,
    input  logic                         s_axi_bready,

    input  logic [ADDR_WIDTH-1:0]        s_axi_araddr,
    input  logic [2:0]                   s_axi_arprot,
    input  logic                         s_axi_arvalid,
    output logic                         s_axi_arready,

    output logic [DATA_WIDTH-1:0]        s_axi_rdata,
    output logic [1:0]                   s_axi_rresp,
    output logic                         s_axi_rvalid,
    input  logic                         s_axi_rready
);

    localparam logic [ADDR_WIDTH-1:0] ADDR_CTRL   = 12'h000;
    localparam logic [ADDR_WIDTH-1:0] ADDR_STATUS = 12'h004;
    localparam logic [ADDR_WIDTH-1:0] ADDR_CFG    = 12'h008;
    localparam logic [ADDR_WIDTH-1:0] ADDR_A_BASE = 12'h100;
    localparam logic [ADDR_WIDTH-1:0] ADDR_B_BASE = 12'h200;
    localparam logic [ADDR_WIDTH-1:0] ADDR_C_BASE = 12'h300;

    localparam logic [1:0] RESP_OKAY  = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;
    localparam int MATRIX_ELEMENTS = ARRAY_SIZE * ARRAY_SIZE;
    localparam int MATRIX_IDX_W = (MATRIX_ELEMENTS <= 1) ? 1 : $clog2(MATRIX_ELEMENTS);

    logic [ADDR_WIDTH-1:0]     aw_addr_q;
    logic [DATA_WIDTH-1:0]     w_data_q;
    logic [(DATA_WIDTH/8)-1:0] w_strb_q;
    logic                      aw_pending_q;
    logic                      w_pending_q;

    logic signed [MAT_WIDTH-1:0] a_matrix [ARRAY_SIZE][ARRAY_SIZE];
    logic signed [MAT_WIDTH-1:0] b_matrix [ARRAY_SIZE][ARRAY_SIZE];
    logic signed [MAT_WIDTH-1:0] a_load_matrix [ARRAY_SIZE][ARRAY_SIZE];
    logic signed [MAT_WIDTH-1:0] b_load_matrix [ARRAY_SIZE][ARRAY_SIZE];
    logic signed [ACC_WIDTH-1:0] c_matrix [ARRAY_SIZE][ARRAY_SIZE];
    logic signed [ACC_WIDTH-1:0] core_c_matrix [ARRAY_SIZE][ARRAY_SIZE];

    logic core_start;
    logic core_busy;
    logic core_done;
    logic done_sticky_q;
    logic matrix_write_fire;
    logic matrix_write_allowed;
    logic a_bank_we;
    logic b_bank_we;
    logic load_bank_q;
    logic compute_bank_q;
    logic core_bank_q;
    logic selected_compute_bank;
    logic [MATRIX_IDX_W-1:0] matrix_wr_idx;

    assign s_axi_awready = rst_ni && !aw_pending_q && !s_axi_bvalid;
    assign s_axi_wready  = rst_ni && !w_pending_q  && !s_axi_bvalid;
    assign s_axi_arready = rst_ni && !s_axi_rvalid;

    assign selected_compute_bank = core_busy ? core_bank_q : compute_bank_q;
    assign matrix_write_allowed = !core_busy || (load_bank_q != core_bank_q);
    assign matrix_write_fire = aw_pending_q && w_pending_q && !s_axi_bvalid && w_strb_q[0] && matrix_write_allowed;
    assign a_bank_we = matrix_write_fire && is_matrix_addr(aw_addr_q, ADDR_A_BASE);
    assign b_bank_we = matrix_write_fire && is_matrix_addr(aw_addr_q, ADDR_B_BASE);
    assign matrix_wr_idx = is_matrix_addr(aw_addr_q, ADDR_B_BASE) ?
                           MATRIX_IDX_W'(matrix_index(aw_addr_q, ADDR_B_BASE)) :
                           MATRIX_IDX_W'(matrix_index(aw_addr_q, ADDR_A_BASE));

    mini_tpu_scratchpad #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .MAT_WIDTH (MAT_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) u_scratchpad (
        .clk_i             (clk_i),
        .rst_ni            (rst_ni),
        .a_we_i            (a_bank_we),
        .b_we_i            (b_bank_we),
        .load_bank_sel_i   (load_bank_q),
        .compute_bank_sel_i(selected_compute_bank),
        .wr_idx_i          (matrix_wr_idx),
        .wr_data_i         (w_data_q[MAT_WIDTH-1:0]),
        .c_commit_i        (core_done),
        .c_commit_matrix_i (core_c_matrix),
        .a_load_matrix_o   (a_load_matrix),
        .b_load_matrix_o   (b_load_matrix),
        .a_matrix_o        (a_matrix),
        .b_matrix_o        (b_matrix),
        .c_matrix_o        (c_matrix)
    );

    mini_tpu_core #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_WIDTH(MAT_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) u_core (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .start_i    (core_start),
        .a_matrix_i (a_matrix),
        .b_matrix_i (b_matrix),
        .busy_o     (core_busy),
        .done_o     (core_done),
        .c_matrix_o (core_c_matrix)
    );

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            aw_addr_q    <= '0;
            w_data_q     <= '0;
            w_strb_q     <= '0;
            aw_pending_q <= 1'b0;
            w_pending_q  <= 1'b0;
            s_axi_bresp  <= RESP_OKAY;
            s_axi_bvalid <= 1'b0;
            core_start   <= 1'b0;
            done_sticky_q <= 1'b0;
            load_bank_q  <= 1'b0;
            compute_bank_q <= 1'b0;
            core_bank_q  <= 1'b0;

        end else begin
            core_start <= 1'b0;

            if (core_done) begin
                done_sticky_q <= 1'b1;
            end

            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end

            if (s_axi_awvalid && s_axi_awready) begin
                aw_addr_q    <= s_axi_awaddr;
                aw_pending_q <= 1'b1;
            end

            if (s_axi_wvalid && s_axi_wready) begin
                w_data_q    <= s_axi_wdata;
                w_strb_q    <= s_axi_wstrb;
                w_pending_q <= 1'b1;
            end

            if (aw_pending_q && w_pending_q && !s_axi_bvalid) begin
                s_axi_bresp <= RESP_OKAY;

                if (aw_addr_q == ADDR_CTRL) begin
                    if (w_strb_q[0] && w_data_q[0] && !core_busy) begin
                        core_start <= 1'b1;
                        core_bank_q <= compute_bank_q;
                        done_sticky_q <= 1'b0;
                    end

                    if (w_strb_q[0] && w_data_q[1]) begin
                        done_sticky_q <= 1'b0;
                    end
                end else if (aw_addr_q == ADDR_CFG) begin
                    if (w_strb_q[0]) begin
                        load_bank_q <= w_data_q[0];
                        compute_bank_q <= w_data_q[1];
                    end
                end else if (is_matrix_addr(aw_addr_q, ADDR_A_BASE)) begin
                    s_axi_bresp <= RESP_OKAY;
                end else if (is_matrix_addr(aw_addr_q, ADDR_B_BASE)) begin
                    s_axi_bresp <= RESP_OKAY;
                end else begin
                    s_axi_bresp <= RESP_SLVERR;
                end

                s_axi_bvalid <= 1'b1;
                aw_pending_q <= 1'b0;
                w_pending_q  <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            s_axi_rdata  <= '0;
            s_axi_rresp  <= RESP_OKAY;
            s_axi_rvalid <= 1'b0;
        end else begin
            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end

            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rdata  <= read_data(s_axi_araddr);
                s_axi_rresp  <= read_resp(s_axi_araddr);
                s_axi_rvalid <= 1'b1;
            end
        end
    end

    function automatic logic [DATA_WIDTH-1:0] read_data(input logic [ADDR_WIDTH-1:0] addr);
        int unsigned idx;
        int unsigned row;
        int unsigned col;

        read_data = '0;

        if (addr == ADDR_CTRL) begin
            read_data = '0;
        end else if (addr == ADDR_STATUS) begin
            read_data[0] = core_busy;
            read_data[1] = done_sticky_q;
        end else if (addr == ADDR_CFG) begin
            read_data[0] = load_bank_q;
            read_data[1] = compute_bank_q;
            read_data[2] = core_bank_q;
        end else if (is_matrix_addr(addr, ADDR_A_BASE)) begin
            idx = matrix_index(addr, ADDR_A_BASE);
            row = idx / ARRAY_SIZE;
            col = idx % ARRAY_SIZE;
            read_data[MAT_WIDTH-1:0] = a_load_matrix[row][col];
        end else if (is_matrix_addr(addr, ADDR_B_BASE)) begin
            idx = matrix_index(addr, ADDR_B_BASE);
            row = idx / ARRAY_SIZE;
            col = idx % ARRAY_SIZE;
            read_data[MAT_WIDTH-1:0] = b_load_matrix[row][col];
        end else if (is_matrix_addr(addr, ADDR_C_BASE)) begin
            idx = matrix_index(addr, ADDR_C_BASE);
            row = idx / ARRAY_SIZE;
            col = idx % ARRAY_SIZE;
            read_data = c_matrix[row][col];
        end
    endfunction

    function automatic logic [1:0] read_resp(input logic [ADDR_WIDTH-1:0] addr);
        if ((addr == ADDR_CTRL) ||
            (addr == ADDR_STATUS) ||
            (addr == ADDR_CFG) ||
            is_matrix_addr(addr, ADDR_A_BASE) ||
            is_matrix_addr(addr, ADDR_B_BASE) ||
            is_matrix_addr(addr, ADDR_C_BASE)) begin
            read_resp = RESP_OKAY;
        end else begin
            read_resp = RESP_SLVERR;
        end
    endfunction

    function automatic bit is_matrix_addr(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [ADDR_WIDTH-1:0] base
    );
        is_matrix_addr = (addr >= base) &&
                         (addr < (base + (ARRAY_SIZE * ARRAY_SIZE * (DATA_WIDTH/8)))) &&
                         (addr[1:0] == 2'b00);
    endfunction

    function automatic int unsigned matrix_index(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [ADDR_WIDTH-1:0] base
    );
        matrix_index = (addr - base) >> 2;
    endfunction

endmodule
