`ifndef MINI_TPU_RAL_DRIVER_SV
`define MINI_TPU_RAL_DRIVER_SV

class mini_tpu_ral_driver extends uvm_driver #(mini_tpu_ral_bus_item);

    `uvm_component_utils(mini_tpu_ral_driver)

    virtual mini_tpu_axi_if vif;

    function new(string name = "mini_tpu_ral_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual mini_tpu_axi_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("MINI_TPU_RAL_DRV", "Failed to get mini_tpu_axi_if")
        end
    endfunction

    virtual task run_phase(uvm_phase phase);
        mini_tpu_ral_bus_item req;

        wait_for_reset();
        init_bus();

        forever begin
            seq_item_port.get_next_item(req);
            if (req.write) begin
                axi_write(req.addr, req.data, req.strb, req.resp);
            end else begin
                axi_read(req.addr, req.data, req.resp);
            end
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

    task automatic axi_write(
        input  bit [11:0] addr,
        input  bit [31:0] data,
        input  bit [3:0]  strb,
        output bit [1:0]  resp
    );
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
        resp    = 2'b00;

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
            `uvm_error("MINI_TPU_RAL_DRV", $sformatf("Timeout waiting AWREADY addr=0x%0h", addr))
        end
        if (!w_done) begin
            `uvm_error("MINI_TPU_RAL_DRV", $sformatf("Timeout waiting WREADY addr=0x%0h", addr))
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
            `uvm_error("MINI_TPU_RAL_DRV", $sformatf("Timeout waiting BVALID addr=0x%0h", addr))
        end else begin
            resp = vif.bresp;
        end

        @(posedge vif.clk);
        @(negedge vif.clk);
        vif.bready <= 1'b0;
    endtask

    task automatic axi_read(
        input  bit [11:0] addr,
        output bit [31:0] data,
        output bit [1:0]  resp
    );
        bit ar_done;
        bit r_done;

        @(negedge vif.clk);
        vif.araddr  <= addr;
        vif.arvalid <= 1'b1;
        vif.rready  <= 1'b1;

        ar_done = 1'b0;
        r_done  = 1'b0;
        data    = '0;
        resp    = 2'b00;

        for (int timeout = 0; timeout < 50; timeout++) begin
            if (vif.arready === 1'b1) begin
                ar_done = 1'b1;
                break;
            end
            @(posedge vif.clk);
        end

        if (!ar_done) begin
            `uvm_error("MINI_TPU_RAL_DRV", $sformatf("Timeout waiting ARREADY addr=0x%0h", addr))
        end

        @(negedge vif.clk);
        vif.arvalid <= 1'b0;
        vif.araddr  <= '0;

        for (int timeout = 0; timeout < 50; timeout++) begin
            if (vif.rvalid === 1'b1) begin
                r_done = 1'b1;
                break;
            end
            @(posedge vif.clk);
        end

        if (!r_done) begin
            `uvm_error("MINI_TPU_RAL_DRV", $sformatf("Timeout waiting RVALID addr=0x%0h", addr))
        end else begin
            data = vif.rdata;
            resp = vif.rresp;
        end

        @(posedge vif.clk);
        @(negedge vif.clk);
        vif.rready <= 1'b0;
    endtask

endclass

`endif
