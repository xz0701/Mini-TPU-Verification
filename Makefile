VCS      = vcs
SIM_DIR  = sim
FLIST   ?= ../script/filelist.f
TOP     ?= tb_systolic_smoke
ARRAY_SIZE ?= 4
UVM_OPTS ?=
COV_OPTS ?=
COV_RUN_OPTS ?=
COV_METRICS ?= line+cond+tgl+fsm+branch
COV_REPORT_METRICS ?= line+cond+tgl+fsm+branch+group
COV_DB_ROOT ?= cov_work
COV_MERGED_DB ?= cov_merged.vdb
COV_REPORT_DIR ?= cov_report
ENABLE_COV ?= 0
DEFINE_OPTS ?= +define+MINI_TPU_ARRAY_SIZE=$(ARRAY_SIZE)
RUN_TAG ?= $(TOP)_$(ARRAY_SIZE)x$(ARRAY_SIZE)$(if $(TEST),_$(TEST),)
COMPILE_LOG ?= compile_$(RUN_TAG).log
RUN_LOG ?= run_$(RUN_TAG).log

ifeq ($(ENABLE_COV),1)
VCS_COV_OPTS = -cm $(COV_METRICS)
SIM_COV_OPTS = -cm $(COV_METRICS) -cm_name $(RUN_TAG) -cm_dir $(COV_DB_ROOT)/$(RUN_TAG).vdb
endif

REGRESSION_UVM_TESTS ?= mini_tpu_smoke_test \
                        mini_tpu_mem_test \
                        mini_tpu_invalid_addr_test \
                        mini_tpu_busy_write_test \
                        mini_tpu_double_buffer_test \
                        mini_tpu_dma_test \
                        mini_tpu_dma_error_test \
                        mini_tpu_dma_external_test \
                        mini_tpu_8x8_stress_test \
                        mini_tpu_ral_smoke_test

VCS_OPTS = -full64 \
           -sverilog \
           $(DEFINE_OPTS) \
           $(UVM_OPTS) \
           $(VCS_COV_OPTS) \
           $(COV_OPTS) \
           -timescale=1ns/1ps \
           -debug_access+all \
           -top $(TOP) \
           -l $(COMPILE_LOG)

TEST    ?=
UVM_TEST ?= mini_tpu_smoke_test

SIM_OPTS = $(if $(TEST),+UVM_TESTNAME=$(TEST),) $(SIM_COV_OPTS) $(COV_RUN_OPTS) -l $(RUN_LOG)

all: run

$(SIM_DIR):
	mkdir -p $(SIM_DIR)

compile: $(SIM_DIR)
	cd $(SIM_DIR) && $(VCS) $(VCS_OPTS) -f $(FLIST) -o simv

run: compile
	cd $(SIM_DIR) && ./simv $(SIM_OPTS)

clean-snapshot:
	rm -rf $(SIM_DIR)/simv \
	       $(SIM_DIR)/simv.daidir \
	       $(SIM_DIR)/csrc \
	       $(SIM_DIR)/vc_hdrs.h \
	       $(SIM_DIR)/ucli.key \
	       $(SIM_DIR)/DVEfiles

clean-run: clean-snapshot run

setup-run:
	bash -lc 'source ../../env/setup.sh && $(MAKE) run'

axi-run:
	$(MAKE) run TOP=tb_axi_lite_smoke FLIST=../script/filelist_axi.f

axi-setup-run:
	bash -lc 'source ../../env/setup.sh && $(MAKE) axi-run'

uvm-run:
	$(MAKE) run TOP=tb_mini_tpu_uvm FLIST=../script/filelist_uvm.f TEST=$(UVM_TEST) UVM_OPTS="-ntb_opts uvm"

uvm-clean-run:
	$(MAKE) clean-run TOP=tb_mini_tpu_uvm FLIST=../script/filelist_uvm.f TEST=$(UVM_TEST) UVM_OPTS="-ntb_opts uvm"

uvm-setup-run:
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-run'

uvm-cov-run:
	mkdir -p $(SIM_DIR)/$(COV_DB_ROOT)
	$(MAKE) run TOP=tb_mini_tpu_uvm FLIST=../script/filelist_uvm.f TEST=$(UVM_TEST) UVM_OPTS="-ntb_opts uvm" ENABLE_COV=1

uvm-cov-report:
	cd $(SIM_DIR) && urg -dir $(COV_DB_ROOT)/*.vdb -metric $(COV_REPORT_METRICS) -dbname $(COV_MERGED_DB) -report $(COV_REPORT_DIR)

uvm-cov-setup-run:
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-cov-run'

regression-summary:
	REGRESSION_UVM_TESTS="$(REGRESSION_UVM_TESTS)" bash script/gen_regression_summary.sh $(SIM_DIR) $(SIM_DIR)/regression_summary.txt

regression:
	bash -lc 'source ../../env/setup.sh && $(MAKE) run'
	bash -lc 'source ../../env/setup.sh && $(MAKE) axi-run'
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-run UVM_TEST=mini_tpu_smoke_test'
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-run UVM_TEST=mini_tpu_mem_test'
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-run UVM_TEST=mini_tpu_invalid_addr_test'
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-run UVM_TEST=mini_tpu_busy_write_test'
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-run UVM_TEST=mini_tpu_double_buffer_test'
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-run UVM_TEST=mini_tpu_dma_test'
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-run UVM_TEST=mini_tpu_dma_error_test'
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-run UVM_TEST=mini_tpu_dma_external_test'
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-run UVM_TEST=mini_tpu_8x8_stress_test'
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-run UVM_TEST=mini_tpu_ral_smoke_test'

regression-cov:
	$(MAKE) clean-cov
	set -e; \
	for test in $(REGRESSION_UVM_TESTS); do \
	    bash -lc "source ../../env/setup.sh && $(MAKE) uvm-cov-run ARRAY_SIZE=$(ARRAY_SIZE) UVM_TEST=$$test"; \
	done
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-cov-report'
	$(MAKE) regression-summary

regression-cov-all: clean-cov
	set -e; \
	for array_size in 4 8; do \
	    for test in $(REGRESSION_UVM_TESTS); do \
	        bash -lc "source ../../env/setup.sh && $(MAKE) uvm-cov-run ARRAY_SIZE=$$array_size UVM_TEST=$$test"; \
	    done; \
	done
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-cov-report'
	$(MAKE) regression-summary

regression-8x8:
	bash -lc 'source ../../env/setup.sh && $(MAKE) regression ARRAY_SIZE=8'

clean-cov:
	rm -rf $(SIM_DIR)/$(COV_DB_ROOT) \
	       $(SIM_DIR)/$(COV_MERGED_DB) \
	       $(SIM_DIR)/$(COV_REPORT_DIR) \
	       $(SIM_DIR)/regression_summary.txt \
	       $(SIM_DIR)/run_*.log \
	       $(SIM_DIR)/compile_*.log \
	       $(SIM_DIR)/cm.log

clean:
	rm -rf $(SIM_DIR)/simv \
	       $(SIM_DIR)/simv.daidir \
	       $(SIM_DIR)/csrc \
	       $(SIM_DIR)/*.log \
	       $(SIM_DIR)/*.vpd \
	       $(SIM_DIR)/*.fsdb \
	       $(SIM_DIR)/*.vdb \
	       $(SIM_DIR)/$(COV_DB_ROOT) \
	       $(SIM_DIR)/$(COV_MERGED_DB) \
	       $(SIM_DIR)/$(COV_REPORT_DIR) \
	       $(SIM_DIR)/regression_summary.txt \
	       $(SIM_DIR)/ucli.key \
	       $(SIM_DIR)/DVEfiles \
	       $(SIM_DIR)/inter.vpd

.PHONY: all compile run clean-snapshot clean-run setup-run axi-run axi-setup-run uvm-run uvm-clean-run uvm-setup-run uvm-cov-run uvm-cov-report uvm-cov-setup-run regression regression-summary regression-cov regression-cov-all regression-8x8 clean-cov clean
