`ifndef MINI_TPU_BASE_TEST_SV
`define MINI_TPU_BASE_TEST_SV

class mini_tpu_base_test extends uvm_test;

    `uvm_component_utils(mini_tpu_base_test)

    localparam int ARRAY_SIZE = `MINI_TPU_ARRAY_SIZE;
    localparam bit [11:0] ADDR_CTRL   = 12'h000;
    localparam bit [11:0] ADDR_STATUS = 12'h004;
    localparam bit [11:0] ADDR_CFG    = 12'h008;
    localparam bit [11:0] ADDR_A_BASE = 12'h100;
    localparam bit [11:0] ADDR_B_BASE = 12'h200;
    localparam bit [11:0] ADDR_C_BASE = 12'h300;
    localparam bit [1:0]  RESP_OKAY   = 2'b00;
    localparam bit [1:0]  RESP_SLVERR = 2'b10;

    mini_tpu_env env;
    virtual mini_tpu_axi_if vif;

    function new(string name = "mini_tpu_base_test", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = mini_tpu_env::type_id::create("env", this);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        if (!uvm_config_db#(virtual mini_tpu_axi_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("MINI_TPU_BASE", "Failed to get mini_tpu_axi_if")
        end
    endfunction

    task automatic wait_for_reset();
        wait (vif.rst_n === 1'b1);
        repeat (3) @(posedge vif.clk);
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
        resp    = RESP_OKAY;

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
            `uvm_error("MINI_TPU_BASE", $sformatf("Timeout waiting AWREADY addr=0x%0h", addr))
        end
        if (!w_done) begin
            `uvm_error("MINI_TPU_BASE", $sformatf("Timeout waiting WREADY addr=0x%0h", addr))
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
            `uvm_error("MINI_TPU_BASE", $sformatf("Timeout waiting BVALID addr=0x%0h", addr))
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
        resp    = RESP_OKAY;

        for (int timeout = 0; timeout < 50; timeout++) begin
            if (vif.arready === 1'b1) begin
                ar_done = 1'b1;
                break;
            end
            @(posedge vif.clk);
        end

        if (!ar_done) begin
            `uvm_error("MINI_TPU_BASE", $sformatf("Timeout waiting ARREADY addr=0x%0h", addr))
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
            `uvm_error("MINI_TPU_BASE", $sformatf("Timeout waiting RVALID addr=0x%0h", addr))
        end else begin
            data = vif.rdata;
            resp = vif.rresp;
        end

        @(posedge vif.clk);
        @(negedge vif.clk);
        vif.rready <= 1'b0;
    endtask

    task automatic expect_write_resp(
        input bit [11:0] addr,
        input bit [31:0] data,
        input bit [3:0]  strb,
        input bit [1:0]  exp_resp
    );
        bit [1:0] resp;

        axi_write(addr, data, strb, resp);
        if (resp !== exp_resp) begin
            `uvm_error("MINI_TPU_BASE",
                $sformatf("Write response mismatch addr=0x%0h actual=%0b expected=%0b",
                          addr, resp, exp_resp))
        end
    endtask

    task automatic expect_read_resp(
        input  bit [11:0] addr,
        input  bit [1:0]  exp_resp,
        output bit [31:0] data
    );
        bit [1:0] resp;

        axi_read(addr, data, resp);
        if (resp !== exp_resp) begin
            `uvm_error("MINI_TPU_BASE",
                $sformatf("Read response mismatch addr=0x%0h actual=%0b expected=%0b",
                          addr, resp, exp_resp))
        end
    endtask

    task automatic load_item(mini_tpu_item item);
        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                expect_write_resp(matrix_addr(ADDR_A_BASE, row, col),
                                  {{24{item.a_matrix[row][col][7]}}, item.a_matrix[row][col]},
                                  4'h1,
                                  RESP_OKAY);
                expect_write_resp(matrix_addr(ADDR_B_BASE, row, col),
                                  {{24{item.b_matrix[row][col][7]}}, item.b_matrix[row][col]},
                                  4'h1,
                                  RESP_OKAY);
            end
        end
    endtask

    task automatic start_core();
        expect_write_resp(ADDR_CTRL, 32'h0000_0001, 4'h1, RESP_OKAY);
    endtask

    task automatic poll_done();
        bit [31:0] status;

        for (int timeout = 0; timeout < 200; timeout++) begin
            expect_read_resp(ADDR_STATUS, RESP_OKAY, status);
            if (status[1]) begin
                return;
            end
            repeat (1) @(posedge vif.clk);
        end

        `uvm_error("MINI_TPU_BASE", "Timeout waiting for done sticky status")
    endtask

    task automatic expect_busy_seen();
        bit [31:0] status;

        for (int timeout = 0; timeout < 20; timeout++) begin
            expect_read_resp(ADDR_STATUS, RESP_OKAY, status);
            if (status[0]) begin
                return;
            end
            if (status[1]) begin
                break;
            end
            @(posedge vif.clk);
        end

        `uvm_error("MINI_TPU_BASE", "Expected to observe busy before operation completed")
    endtask

    task automatic check_result(mini_tpu_item item);
        bit [31:0] data;
        int signed actual;
        int signed expected;

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                expect_read_resp(matrix_addr(ADDR_C_BASE, row, col), RESP_OKAY, data);
                actual = int'($signed(data));
                expected = item.expected_at(row, col);
                if (actual !== expected) begin
                    `uvm_error("MINI_TPU_BASE",
                        $sformatf("Result mismatch %s C[%0d][%0d] actual=%0d expected=%0d",
                                  item.case_name, row, col, actual, expected))
                end
            end
        end
    endtask

    task automatic check_matrix_low_byte(
        input bit [11:0] base,
        input int unsigned row,
        input int unsigned col,
        input bit [7:0] exp_data
    );
        bit [31:0] data;

        expect_read_resp(matrix_addr(base, row, col), RESP_OKAY, data);
        if (data[7:0] !== exp_data) begin
            `uvm_error("MINI_TPU_BASE",
                $sformatf("Matrix readback mismatch addr=0x%0h actual=0x%0h expected=0x%0h",
                          matrix_addr(base, row, col), data[7:0], exp_data))
        end
    endtask

    task automatic clear_done_sticky();
        bit [31:0] status;

        expect_write_resp(ADDR_CTRL, 32'h0000_0002, 4'h1, RESP_OKAY);
        expect_read_resp(ADDR_STATUS, RESP_OKAY, status);
        if (status[1] !== 1'b0) begin
            `uvm_error("MINI_TPU_BASE", "Done sticky did not clear")
        end
    endtask

    function automatic bit [11:0] matrix_addr(bit [11:0] base, int unsigned row, int unsigned col);
        matrix_addr = base + (((row * ARRAY_SIZE) + col) << 2);
    endfunction

endclass

`endif
