VCS      = vcs
SIM_DIR  = sim
FLIST   ?= ../script/filelist.f
TOP     ?= tb_systolic_smoke
ARRAY_SIZE ?= 4
UVM_OPTS ?=
COV_OPTS ?=
COV_RUN_OPTS ?=
DEFINE_OPTS ?= +define+MINI_TPU_ARRAY_SIZE=$(ARRAY_SIZE)

VCS_OPTS = -full64 \
           -sverilog \
           $(DEFINE_OPTS) \
           $(UVM_OPTS) \
           $(COV_OPTS) \
           -timescale=1ns/1ps \
           -debug_access+all \
           -top $(TOP) \
           -l compile.log

TEST    ?=
UVM_TEST ?= mini_tpu_smoke_test

SIM_OPTS = $(if $(TEST),+UVM_TESTNAME=$(TEST),) $(COV_RUN_OPTS) -l run.log

all: run

$(SIM_DIR):
	mkdir -p $(SIM_DIR)

compile: $(SIM_DIR)
	cd $(SIM_DIR) && $(VCS) $(VCS_OPTS) -f $(FLIST) -o simv

run: compile
	cd $(SIM_DIR) && ./simv $(SIM_OPTS)

setup-run:
	bash -lc 'source ../../env/setup.sh && $(MAKE) run'

axi-run:
	$(MAKE) run TOP=tb_axi_lite_smoke FLIST=../script/filelist_axi.f

axi-setup-run:
	bash -lc 'source ../../env/setup.sh && $(MAKE) axi-run'

uvm-run:
	$(MAKE) run TOP=tb_mini_tpu_uvm FLIST=../script/filelist_uvm.f TEST=$(UVM_TEST) UVM_OPTS="-ntb_opts uvm"

uvm-setup-run:
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-run'

uvm-cov-run:
	$(MAKE) run TOP=tb_mini_tpu_uvm FLIST=../script/filelist_uvm.f TEST=$(UVM_TEST) UVM_OPTS="-ntb_opts uvm" COV_OPTS="-cm line+cond+tgl+fsm+branch" COV_RUN_OPTS="-cm line+cond+tgl+fsm+branch"

uvm-cov-report:
	cd $(SIM_DIR) && urg -dir simv.vdb -metric line+cond+tgl+fsm+branch+group -report cov_report

uvm-cov-setup-run:
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-cov-run'

regression:
	bash -lc 'source ../../env/setup.sh && $(MAKE) run'
	bash -lc 'source ../../env/setup.sh && $(MAKE) axi-run'
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-run UVM_TEST=mini_tpu_smoke_test'
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-run UVM_TEST=mini_tpu_mem_test'
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-run UVM_TEST=mini_tpu_invalid_addr_test'
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-run UVM_TEST=mini_tpu_busy_write_test'

regression-cov:
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-cov-run'
	bash -lc 'source ../../env/setup.sh && $(MAKE) uvm-cov-report'

regression-8x8:
	bash -lc 'source ../../env/setup.sh && $(MAKE) regression ARRAY_SIZE=8'

clean:
	rm -rf $(SIM_DIR)/simv \
	       $(SIM_DIR)/simv.daidir \
	       $(SIM_DIR)/csrc \
	       $(SIM_DIR)/*.log \
	       $(SIM_DIR)/*.vpd \
	       $(SIM_DIR)/*.fsdb \
	       $(SIM_DIR)/*.vdb \
	       $(SIM_DIR)/cov_report \
	       $(SIM_DIR)/ucli.key \
	       $(SIM_DIR)/DVEfiles \
	       $(SIM_DIR)/inter.vpd

.PHONY: all compile run setup-run axi-run axi-setup-run uvm-run uvm-setup-run uvm-cov-run uvm-cov-report uvm-cov-setup-run regression regression-cov regression-8x8 clean
