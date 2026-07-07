`timescale 1ns/1ps

module tb_mini_tpu_uvm;

    import uvm_pkg::*;
    import mini_tpu_pkg::*;

    `include "uvm_macros.svh"

    logic clk;
    logic rst_n;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    mini_tpu_axi_if axi_if (
        .clk   (clk),
        .rst_n (rst_n)
    );

    mini_tpu_axi_lite dut (
        .clk_i         (clk),
        .rst_ni        (rst_n),
        .s_axi_awaddr  (axi_if.awaddr),
        .s_axi_awprot  (axi_if.awprot),
        .s_axi_awvalid (axi_if.awvalid),
        .s_axi_awready (axi_if.awready),
        .s_axi_wdata   (axi_if.wdata),
        .s_axi_wstrb   (axi_if.wstrb),
        .s_axi_wvalid  (axi_if.wvalid),
        .s_axi_wready  (axi_if.wready),
        .s_axi_bresp   (axi_if.bresp),
        .s_axi_bvalid  (axi_if.bvalid),
        .s_axi_bready  (axi_if.bready),
        .s_axi_araddr  (axi_if.araddr),
        .s_axi_arprot  (axi_if.arprot),
        .s_axi_arvalid (axi_if.arvalid),
        .s_axi_arready (axi_if.arready),
        .s_axi_rdata   (axi_if.rdata),
        .s_axi_rresp   (axi_if.rresp),
        .s_axi_rvalid  (axi_if.rvalid),
        .s_axi_rready  (axi_if.rready)
    );

    initial begin
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
    end

    initial begin
        uvm_config_db#(virtual mini_tpu_axi_if)::set(
            null,
            "*",
            "vif",
            axi_if
        );

        run_test();
    end

endmodule
