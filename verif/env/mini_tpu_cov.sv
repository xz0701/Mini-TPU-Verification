`ifndef MINI_TPU_COV_SV
`define MINI_TPU_COV_SV

class mini_tpu_cov extends uvm_subscriber #(mini_tpu_item);

    `uvm_component_utils(mini_tpu_cov)

    localparam int ARRAY_SIZE = `MINI_TPU_ARRAY_SIZE;

    covergroup matrix_cg with function sample(
        int signed a_val,
        int signed b_val,
        int signed c_val,
        bit        diagonal,
        bit        corner
    );
        option.per_instance = 1;

        cp_a_value: coverpoint a_val {
            bins zero      = {0};
            bins pos_small = {[1:15]};
            bins neg_small = {[-15:-1]};
            bins pos_large = {[16:127]};
            bins neg_large = {[-128:-16]};
        }

        cp_b_value: coverpoint b_val {
            bins zero      = {0};
            bins pos_small = {[1:15]};
            bins neg_small = {[-15:-1]};
            bins pos_large = {[16:127]};
            bins neg_large = {[-128:-16]};
        }

        cp_c_value: coverpoint c_val {
            bins zero = {0};
            bins pos  = {[1:70000]};
            bins neg  = {[-70000:-1]};
        }

        cp_position: coverpoint {diagonal, corner} {
            bins diagonal_corner     = {2'b11};
            bins diagonal_non_corner = {2'b10};
            bins offdiag_corner      = {2'b01};
            bins offdiag_inner       = {2'b00};
        }

        cross_a_b_sign: cross cp_a_value, cp_b_value;
        cross_c_pos: cross cp_c_value, cp_position;
    endgroup

    covergroup operation_cg with function sample(bit has_negative, bit has_zero, bit has_positive);
        option.per_instance = 1;

        cp_has_negative: coverpoint has_negative {
            bins no  = {0};
            bins yes = {1};
        }

        cp_has_zero: coverpoint has_zero {
            bins no  = {0};
            bins yes = {1};
        }

        cp_has_positive: coverpoint has_positive {
            bins no  = {0};
            bins yes = {1};
        }

        cross_matrix_mix: cross cp_has_negative, cp_has_zero, cp_has_positive {
            ignore_bins impossible_empty_matrix =
                binsof(cp_has_negative) intersect {0} &&
                binsof(cp_has_zero)     intersect {0} &&
                binsof(cp_has_positive) intersect {0};
        }
    endgroup

    covergroup dma_cg with function sample(
        int unsigned target_bank,
        int unsigned copy_mode,
        int unsigned source_mode,
        int unsigned error_reason,
        bit          source_write_busy,
        int unsigned clear_op
    );
        option.per_instance = 1;

        cp_target_bank: coverpoint target_bank {
            bins bank0 = {0};
            bins bank1 = {1};
        }

        cp_copy_mode: coverpoint copy_mode {
            bins none   = {0};
            bins a_only = {1};
            bins b_only = {2};
            bins both   = {3};
        }

        cp_source_mode: coverpoint source_mode {
            bins staging  = {0};
            bins external = {1};
        }

        cp_error_reason: coverpoint error_reason {
            bins none        = {0};
            bins no_copy     = {1};
            bins dma_busy    = {2};
            bins target_busy = {3};
        }

        cp_source_write_busy: coverpoint source_write_busy {
            bins no  = {0};
            bins yes = {1};
        }

        cp_clear_op: coverpoint clear_op {
            bins none       = {0};
            bins done_only  = {1};
            bins error_only = {2};
            bins both       = {3};
        }
    endgroup

    int unsigned item_sample_count;
    int unsigned dma_sample_count;

    function new(string name = "mini_tpu_cov", uvm_component parent);
        super.new(name, parent);
        matrix_cg = new();
        operation_cg = new();
        dma_cg = new();
        item_sample_count = 0;
        dma_sample_count = 0;
    endfunction

    virtual function void write(mini_tpu_item t);
        bit has_negative;
        bit has_zero;
        bit has_positive;
        bit diagonal;
        bit corner;

        has_negative = 1'b0;
        has_zero     = 1'b0;
        has_positive = 1'b0;

        for (int row = 0; row < ARRAY_SIZE; row++) begin
            for (int col = 0; col < ARRAY_SIZE; col++) begin
                diagonal = (row == col);
                corner = ((row == 0) || (row == ARRAY_SIZE-1)) &&
                         ((col == 0) || (col == ARRAY_SIZE-1));

                matrix_cg.sample(
                    t.a_matrix[row][col],
                    t.b_matrix[row][col],
                    t.c_matrix[row][col],
                    diagonal,
                    corner
                );

                if ((t.a_matrix[row][col] < 0) || (t.b_matrix[row][col] < 0)) begin
                    has_negative = 1'b1;
                end
                if ((t.a_matrix[row][col] == 0) || (t.b_matrix[row][col] == 0)) begin
                    has_zero = 1'b1;
                end
                if ((t.a_matrix[row][col] > 0) || (t.b_matrix[row][col] > 0)) begin
                    has_positive = 1'b1;
                end
            end
        end

        operation_cg.sample(has_negative, has_zero, has_positive);
        item_sample_count++;
    endfunction

    virtual function void sample_dma(
        int unsigned target_bank,
        int unsigned copy_mode,
        int unsigned source_mode,
        int unsigned error_reason,
        bit          source_write_busy,
        int unsigned clear_op
    );
        dma_cg.sample(target_bank, copy_mode, source_mode, error_reason, source_write_busy, clear_op);
        dma_sample_count++;
    endfunction

    virtual function void report_phase(uvm_phase phase);
        real matrix_cov;
        real operation_cov;
        real dma_cov;
        real total_cov;

        super.report_phase(phase);

        matrix_cov = matrix_cg.get_inst_coverage();
        operation_cov = operation_cg.get_inst_coverage();
        dma_cov = dma_cg.get_inst_coverage();

        if ((item_sample_count == 0) && (dma_sample_count != 0)) begin
            total_cov = dma_cov;
        end else if (dma_sample_count == 0) begin
            total_cov = (matrix_cov + operation_cov) / 2.0;
        end else begin
            total_cov = (matrix_cov + operation_cov + dma_cov) / 3.0;
        end

        `uvm_info("MINI_TPU_COV",
            $sformatf("Functional coverage: matrix_cg=%0.2f%% operation_cg=%0.2f%% dma_cg=%0.2f%% total=%0.2f%%",
                      matrix_cov,
                      operation_cov,
                      dma_cov,
                      total_cov),
            UVM_LOW)
    endfunction

endclass

`endif
