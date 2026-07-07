`ifndef MINI_TPU_AXI_DRIVER_SV
`define MINI_TPU_AXI_DRIVER_SV

class mini_tpu_axi_driver extends uvm_driver #(mini_tpu_item);

    `uvm_component_utils(mini_tpu_axi_driver)

    localparam int ARRAY_SIZE = 4;
    localparam bit [11:0] ADDR_CTRL   = 12'h000;
    localparam bit [11:0] ADDR_A_BASE = 12'h100;
    localparam bit [11:0] ADDR_B_BASE = 12'h200;

    virtual mini_tpu_axi_if vif;
    uvm_event programmed_ev;
    uvm_event checked_ev;

    function new(string name = "mini_tpu_axi_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual mini_tpu_axi_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("MINI_TPU_DRV", "Failed to get mini_tpu_axi_if")
        end

        programmed_ev = uvm_event_pool::get_global("mini_tpu_programmed");
        checked_ev = uvm_event_pool::get_global("mini_tpu_scoreboard_done");
    endfunction

    virtual task run_phase(uvm_phase phase);
        mini_tpu_item req;

        wait_for_reset();
        init_bus();

        forever begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            checked_ev.reset();
            programmed_ev.trigger();
            checked_ev.wait_ptrigger();
            seq_item_port.item_done();
        end
    endtask

    task automatic wait_for_reset();
        wait (vif.rst_n === 1'b1);
        repeat (2) @(posedge vif.clk);
    endtask

    task automatic init_bus();
        vif.awaddr  <= '0;
        vif.awprot  <= '0;
        vif.awvalid <= 1'b0;
        vif.wdata   <= '0;
        vif.wstrb   <= '0;
        vif.wvalid  <= 1'b0;
        vif.bready  <= 1'b0;
        vif.araddr  <= '0;
        vif.arprot  <= '0;
        vif.arvalid <= 1'b0;
        vif.rready  <= 1'b0;
    endtask

    task automatic drive_item(mini_tpu_item item);
        `uvm_info("MINI_TPU_DRV", $sformatf("Programming case %s over AXI-Lite", item.case_name), UVM_MEDIUM)

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                axi_write(matrix_addr(ADDR_A_BASE, row, col), {{24{item.a_matrix[row][col][7]}}, item.a_matrix[row][col]}, 4'h1);
                axi_write(matrix_addr(ADDR_B_BASE, row, col), {{24{item.b_matrix[row][col][7]}}, item.b_matrix[row][col]}, 4'h1);
            end
        end

        axi_write(ADDR_CTRL, 32'h0000_0001, 4'h1);
        `uvm_info("MINI_TPU_DRV", "Started mini TPU operation", UVM_MEDIUM)
    endtask

    task automatic axi_write(bit [11:0] addr, bit [31:0] data, bit [3:0] strb);
        bit aw_done;
        bit w_done;
        bit b_done;

        @(negedge vif.clk);
        vif.awaddr  <= addr;
        vif.awvalid <= 1'b1;
        vif.wdata   <= data;
        vif.wstrb   <= strb;
        vif.wvalid  <= 1'b1;
        vif.bready  <= 1'b1;

        aw_done = 1'b0;
        w_done  = 1'b0;
        b_done  = 1'b0;

        fork
            begin
                for (int timeout = 0; timeout < 50; timeout++) begin
                    if (vif.awready === 1'b1) begin
                        aw_done = 1'b1;
                        break;
                    end
                    @(posedge vif.clk);
                end
            end
            begin
                for (int timeout = 0; timeout < 50; timeout++) begin
                    if (vif.wready === 1'b1) begin
                        w_done = 1'b1;
                        break;
                    end
                    @(posedge vif.clk);
                end
            end
        join

        if (!aw_done) begin
            `uvm_fatal("MINI_TPU_DRV", $sformatf("Timeout waiting AWREADY addr=0x%0h", addr))
        end
        if (!w_done) begin
            `uvm_fatal("MINI_TPU_DRV", $sformatf("Timeout waiting WREADY addr=0x%0h", addr))
        end

        @(negedge vif.clk);
        vif.awvalid <= 1'b0;
        vif.awaddr  <= '0;
        vif.wvalid  <= 1'b0;
        vif.wdata   <= '0;
        vif.wstrb   <= '0;

        for (int timeout = 0; timeout < 50; timeout++) begin
            if (vif.bvalid === 1'b1) begin
                b_done = 1'b1;
                break;
            end
            @(posedge vif.clk);
        end

        if (!b_done) begin
            `uvm_fatal("MINI_TPU_DRV", $sformatf("Timeout waiting BVALID addr=0x%0h", addr))
        end
        if (vif.bresp != 2'b00) begin
            `uvm_fatal("MINI_TPU_DRV", $sformatf("AXI write error addr=0x%0h bresp=%0b", addr, vif.bresp))
        end

        @(posedge vif.clk);
        @(negedge vif.clk);
        vif.bready <= 1'b0;
    endtask

    function automatic bit [11:0] matrix_addr(bit [11:0] base, int unsigned row, int unsigned col);
        matrix_addr = base + (((row * ARRAY_SIZE) + col) << 2);
    endfunction

endclass

`endif
