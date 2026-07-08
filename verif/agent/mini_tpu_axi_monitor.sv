`ifndef MINI_TPU_AXI_MONITOR_SV
`define MINI_TPU_AXI_MONITOR_SV

class mini_tpu_axi_monitor extends uvm_component;

    `uvm_component_utils(mini_tpu_axi_monitor)

    localparam int ARRAY_SIZE = `MINI_TPU_ARRAY_SIZE;
    localparam bit [11:0] ADDR_STATUS = 12'h004;
    localparam bit [11:0] ADDR_A_BASE = 12'h100;
    localparam bit [11:0] ADDR_B_BASE = 12'h200;
    localparam bit [11:0] ADDR_C_BASE = 12'h300;

    virtual mini_tpu_axi_if vif;
    uvm_analysis_port #(mini_tpu_item) item_collected_port;
    uvm_event programmed_ev;
    int unsigned observed_count;

    function new(string name = "mini_tpu_axi_monitor", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual mini_tpu_axi_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("MINI_TPU_MON", "Failed to get mini_tpu_axi_if")
        end

        item_collected_port = new("item_collected_port", this);
        programmed_ev = uvm_event_pool::get_global("mini_tpu_programmed");
        observed_count = 0;
    endfunction

    virtual task run_phase(uvm_phase phase);
        mini_tpu_item item;

        wait (vif.rst_n === 1'b1);

        forever begin
            programmed_ev.wait_ptrigger();
            poll_done();

            item = mini_tpu_item::type_id::create("item");
            item.case_name = case_name_by_index(observed_count);
            observed_count++;
            read_matrices_and_result(item);
            item_collected_port.write(item);
        end
    endtask

    task automatic poll_done();
        bit [31:0] status;

        for (int timeout = 0; timeout < 200; timeout++) begin
            axi_read(ADDR_STATUS, status);
            if (status[1]) begin
                return;
            end
            repeat (1) @(posedge vif.clk);
        end

        `uvm_fatal("MINI_TPU_MON", "Timeout waiting for done sticky status")
    endtask

    task automatic read_matrices_and_result(mini_tpu_item item);
        bit [31:0] data;

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                axi_read(matrix_addr(ADDR_A_BASE, row, col), data);
                item.a_matrix[row][col] = data[7:0];

                axi_read(matrix_addr(ADDR_B_BASE, row, col), data);
                item.b_matrix[row][col] = data[7:0];

                axi_read(matrix_addr(ADDR_C_BASE, row, col), data);
                item.c_matrix[row][col] = data;
            end
        end
    endtask

    task automatic axi_read(bit [11:0] addr, output bit [31:0] data);
        bit ar_done;
        bit r_done;

        @(negedge vif.clk);
        vif.araddr  <= addr;
        vif.arvalid <= 1'b1;
        vif.rready  <= 1'b1;

        ar_done = 1'b0;
        r_done  = 1'b0;

        for (int timeout = 0; timeout < 50; timeout++) begin
            if (vif.arready === 1'b1) begin
                ar_done = 1'b1;
                break;
            end
            @(posedge vif.clk);
        end
        if (!ar_done) begin
            `uvm_fatal("MINI_TPU_MON", $sformatf("Timeout waiting ARREADY addr=0x%0h", addr))
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
            `uvm_fatal("MINI_TPU_MON", $sformatf("Timeout waiting RVALID addr=0x%0h", addr))
        end
        if (vif.rresp != 2'b00) begin
            `uvm_fatal("MINI_TPU_MON", $sformatf("AXI read error addr=0x%0h rresp=%0b", addr, vif.rresp))
        end

        data = vif.rdata;

        @(posedge vif.clk);
        @(negedge vif.clk);
        vif.rready <= 1'b0;
    endtask

    function automatic bit [11:0] matrix_addr(bit [11:0] base, int unsigned row, int unsigned col);
        matrix_addr = base + (((row * ARRAY_SIZE) + col) << 2);
    endfunction

    function automatic string case_name_by_index(int unsigned index);
        unique case (index)
            0: case_name_by_index = "mixed_signed";
            1: case_name_by_index = "identity";
            2: case_name_by_index = "all_zero";
            3: case_name_by_index = "int8_edge";
            4: case_name_by_index = "positive_large";
            5: case_name_by_index = "negative_large";
            6: case_name_by_index = "bipolar_no_zero";
            7: case_name_by_index = "value_class_sweep";
            8: case_name_by_index = "negative_zero_only";
            9: case_name_by_index = "cross_sweep_low";
            10: case_name_by_index = "cross_sweep_high";
            11: case_name_by_index = "negative_corner_outputs";
            default: case_name_by_index = $sformatf("case_%0d", index);
        endcase
    endfunction

endclass

`endif
