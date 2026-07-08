`timescale 1ns/1ps
`include "mini_tpu_config.svh"

module tb_axi_lite_smoke;

    localparam int ADDR_WIDTH = 12;
    localparam int DATA_WIDTH = 32;
    localparam int ARRAY_SIZE = `MINI_TPU_ARRAY_SIZE;

    localparam logic [ADDR_WIDTH-1:0] ADDR_CTRL   = 12'h000;
    localparam logic [ADDR_WIDTH-1:0] ADDR_STATUS = 12'h004;
    localparam logic [ADDR_WIDTH-1:0] ADDR_A_BASE = 12'h100;
    localparam logic [ADDR_WIDTH-1:0] ADDR_B_BASE = 12'h200;
    localparam logic [ADDR_WIDTH-1:0] ADDR_C_BASE = 12'h300;

    logic clk;
    logic rst_n;

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

    logic signed [7:0]  a_matrix [ARRAY_SIZE][ARRAY_SIZE];
    logic signed [7:0]  b_matrix [ARRAY_SIZE][ARRAY_SIZE];
    int signed          expected [ARRAY_SIZE][ARRAY_SIZE];
    int                 error_count;

    mini_tpu_axi_lite #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_SIZE(ARRAY_SIZE),
        .MAT_WIDTH (8),
        .ACC_WIDTH (32)
    ) dut (
        .clk_i         (clk),
        .rst_ni        (rst_n),
        .s_axi_awaddr  (awaddr),
        .s_axi_awprot  (awprot),
        .s_axi_awvalid (awvalid),
        .s_axi_awready (awready),
        .s_axi_wdata   (wdata),
        .s_axi_wstrb   (wstrb),
        .s_axi_wvalid  (wvalid),
        .s_axi_wready  (wready),
        .s_axi_bresp   (bresp),
        .s_axi_bvalid  (bvalid),
        .s_axi_bready  (bready),
        .s_axi_araddr  (araddr),
        .s_axi_arprot  (arprot),
        .s_axi_arvalid (arvalid),
        .s_axi_arready (arready),
        .s_axi_rdata   (rdata),
        .s_axi_rresp   (rresp),
        .s_axi_rvalid  (rvalid),
        .s_axi_rready  (rready)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        error_count = 0;
        init_axi_master();
        init_matrices();
        compute_expected();

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        load_matrices_over_axi();
        axi_write(ADDR_CTRL, 32'h0000_0001, 4'h1);
        poll_done();
        check_c_over_axi();

        if (error_count == 0) begin
            $display("[MINI_TPU_AXI_SMOKE] PASS: AXI-Lite programmed %0dx%0d TPU result matched expected data.",
                     ARRAY_SIZE, ARRAY_SIZE);
        end else begin
            $fatal(1, "[MINI_TPU_AXI_SMOKE] FAIL: %0d mismatches detected.", error_count);
        end

        $finish;
    end

    task automatic init_axi_master();
        awaddr  = '0;
        awprot  = '0;
        awvalid = 1'b0;
        wdata   = '0;
        wstrb   = '0;
        wvalid  = 1'b0;
        bready  = 1'b0;
        araddr  = '0;
        arprot  = '0;
        arvalid = 1'b0;
        rready  = 1'b0;
    endtask

    task automatic init_matrices();
        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                a_matrix[row][col] = '0;
                b_matrix[row][col] = '0;
            end
        end

        a_matrix[0][0] =  1; a_matrix[0][1] =  2; a_matrix[0][2] =  3; a_matrix[0][3] =  4;
        a_matrix[1][0] = -1; a_matrix[1][1] =  0; a_matrix[1][2] =  2; a_matrix[1][3] =  1;
        a_matrix[2][0] =  3; a_matrix[2][1] = -2; a_matrix[2][2] =  1; a_matrix[2][3] =  0;
        a_matrix[3][0] =  2; a_matrix[3][1] =  1; a_matrix[3][2] = -3; a_matrix[3][3] =  2;

        b_matrix[0][0] =  1; b_matrix[0][1] =  0; b_matrix[0][2] = -1; b_matrix[0][3] =  2;
        b_matrix[1][0] =  2; b_matrix[1][1] =  1; b_matrix[1][2] =  0; b_matrix[1][3] = -2;
        b_matrix[2][0] = -1; b_matrix[2][1] =  3; b_matrix[2][2] =  2; b_matrix[2][3] =  1;
        b_matrix[3][0] =  0; b_matrix[3][1] = -2; b_matrix[3][2] =  1; b_matrix[3][3] =  1;
    endtask

    task automatic compute_expected();
        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                expected[row][col] = 0;
                for (int k = 0; k < ARRAY_SIZE; k++) begin
                    expected[row][col] += a_matrix[row][k] * b_matrix[k][col];
                end
            end
        end
    endtask

    task automatic load_matrices_over_axi();
        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                axi_write(matrix_addr(ADDR_A_BASE, row, col), {{24{a_matrix[row][col][7]}}, a_matrix[row][col]}, 4'h1);
                axi_write(matrix_addr(ADDR_B_BASE, row, col), {{24{b_matrix[row][col][7]}}, b_matrix[row][col]}, 4'h1);
            end
        end
    endtask

    task automatic poll_done();
        logic [31:0] status;

        status = '0;
        for (int timeout = 0; timeout < 100; timeout++) begin
            axi_read(ADDR_STATUS, status);
            if (status[1]) begin
                return;
            end
            repeat (1) @(posedge clk);
        end

        $fatal(1, "[MINI_TPU_AXI_SMOKE] Timeout waiting for done status.");
    endtask

    task automatic check_c_over_axi();
        logic [31:0] actual;

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                axi_read(matrix_addr(ADDR_C_BASE, row, col), actual);
                if ($signed(actual) !== expected[row][col]) begin
                    $display("[MINI_TPU_AXI_SMOKE] MISMATCH C[%0d][%0d]: actual=%0d expected=%0d",
                             row, col, $signed(actual), expected[row][col]);
                    error_count++;
                end else begin
                    $display("[MINI_TPU_AXI_SMOKE] MATCH C[%0d][%0d] = %0d",
                             row, col, $signed(actual));
                end
            end
        end
    endtask

    task automatic axi_write(
        input logic [ADDR_WIDTH-1:0]     addr,
        input logic [DATA_WIDTH-1:0]     data,
        input logic [(DATA_WIDTH/8)-1:0] strb
    );
        bit aw_done;
        bit w_done;
        bit b_done;

        @(negedge clk);
        awaddr  = addr;
        awvalid = 1'b1;
        wdata   = data;
        wstrb   = strb;
        wvalid  = 1'b1;
        bready  = 1'b1;
        aw_done = 1'b0;
        w_done  = 1'b0;
        b_done  = 1'b0;

        fork
            begin
                for (int timeout = 0; timeout < 50; timeout++) begin
                    if (awready === 1'b1) begin
                        aw_done = 1'b1;
                        break;
                    end
                    @(posedge clk);
                end
                if (!aw_done) begin
                    $fatal(1, "[MINI_TPU_AXI_SMOKE] Timeout waiting AWREADY addr=0x%0h", addr);
                end
                @(negedge clk);
                awvalid = 1'b0;
                awaddr  = '0;
            end
            begin
                for (int timeout = 0; timeout < 50; timeout++) begin
                    if (wready === 1'b1) begin
                        w_done = 1'b1;
                        break;
                    end
                    @(posedge clk);
                end
                if (!w_done) begin
                    $fatal(1, "[MINI_TPU_AXI_SMOKE] Timeout waiting WREADY addr=0x%0h", addr);
                end
                @(negedge clk);
                wvalid = 1'b0;
                wdata  = '0;
                wstrb  = '0;
            end
        join

        for (int timeout = 0; timeout < 50; timeout++) begin
            if (bvalid === 1'b1) begin
                b_done = 1'b1;
                break;
            end
            @(posedge clk);
        end
        if (!b_done) begin
            $fatal(1, "[MINI_TPU_AXI_SMOKE] Timeout waiting BVALID addr=0x%0h", addr);
        end
        if (bresp !== 2'b00) begin
            $fatal(1, "[MINI_TPU_AXI_SMOKE] AXI write SLVERR at addr=0x%0h", addr);
        end
        @(posedge clk);
        @(negedge clk);
        bready = 1'b0;
    endtask

    task automatic axi_read(
        input  logic [ADDR_WIDTH-1:0] addr,
        output logic [DATA_WIDTH-1:0] data
    );
        bit ar_done;
        bit r_done;

        @(negedge clk);
        araddr  = addr;
        arvalid = 1'b1;
        rready  = 1'b1;
        ar_done = 1'b0;
        r_done  = 1'b0;

        for (int timeout = 0; timeout < 50; timeout++) begin
            if (arready === 1'b1) begin
                ar_done = 1'b1;
                break;
            end
            @(posedge clk);
        end
        if (!ar_done) begin
            $fatal(1, "[MINI_TPU_AXI_SMOKE] Timeout waiting ARREADY addr=0x%0h", addr);
        end
        @(negedge clk);
        arvalid = 1'b0;
        araddr  = '0;

        for (int timeout = 0; timeout < 50; timeout++) begin
            if (rvalid === 1'b1) begin
                r_done = 1'b1;
                break;
            end
            @(posedge clk);
        end
        if (!r_done) begin
            $fatal(1, "[MINI_TPU_AXI_SMOKE] Timeout waiting RVALID addr=0x%0h", addr);
        end
        data = rdata;
        if (rresp !== 2'b00) begin
            $fatal(1, "[MINI_TPU_AXI_SMOKE] AXI read SLVERR at addr=0x%0h", addr);
        end
        @(posedge clk);
        @(negedge clk);
        rready = 1'b0;
    endtask

    function automatic logic [ADDR_WIDTH-1:0] matrix_addr(
        input logic [ADDR_WIDTH-1:0] base,
        input int unsigned row,
        input int unsigned col
    );
        matrix_addr = base + (((row * ARRAY_SIZE) + col) << 2);
    endfunction

endmodule
