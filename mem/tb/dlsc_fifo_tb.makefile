
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += mem

V_DUT           += dlsc_fifo.v

SP_TESTBENCH    += dlsc_fifo_tb.sp

V_PARAMS_DEF    += \
    DATA=16 \
    ALMOST_FULL=0 \
    ALMOST_EMPTY=0 \
    COUNT=0 \
    FREE=0 \
    FAST_FLAGS=0 \
    FULL_IN_RESET=0 \
    BRAM=0

# must specify ADDR or DEPTH (but not both)
# COUNT/FREE only supported with power-of-2 DEPTH

sims0:
	$(MAKE) -f $(THIS) V_PARAMS="ADDR=1 DATA=1"
	$(MAKE) -f $(THIS) V_PARAMS="ADDR=4 DATA=8"
	$(MAKE) -f $(THIS) V_PARAMS="ADDR=8 DATA=32"
	$(MAKE) -f $(THIS) V_PARAMS="ADDR=4 ALMOST_FULL=15 ALMOST_EMPTY=1"
	$(MAKE) -f $(THIS) V_PARAMS="ADDR=4 ALMOST_FULL=1 ALMOST_EMPTY=15"

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="ADDR=4 ALMOST_FULL=3 ALMOST_EMPTY=7"
	$(MAKE) -f $(THIS) V_PARAMS="ADDR=4 FULL_IN_RESET=1"
	$(MAKE) -f $(THIS) V_PARAMS="ADDR=4 FAST_FLAGS=1"
	$(MAKE) -f $(THIS) V_PARAMS="ADDR=4 BRAM=1"
	$(MAKE) -f $(THIS) V_PARAMS="ADDR=4 COUNT=1 FREE=1"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="DEPTH=1"
	$(MAKE) -f $(THIS) V_PARAMS="DEPTH=1 FULL_IN_RESET=1 ALMOST_FULL=1 ALMOST_EMPTY=1 DATA=8"
	$(MAKE) -f $(THIS) V_PARAMS="DEPTH=2"
	$(MAKE) -f $(THIS) V_PARAMS="DEPTH=17 ALMOST_FULL=16 ALMOST_EMPTY=1"
	$(MAKE) -f $(THIS) V_PARAMS="DEPTH=17 ALMOST_FULL=1 ALMOST_EMPTY=16"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="DEPTH=17 ALMOST_FULL=13 ALMOST_EMPTY=4"
	$(MAKE) -f $(THIS) V_PARAMS="DEPTH=15 ALMOST_FULL=14 ALMOST_EMPTY=1"
	$(MAKE) -f $(THIS) V_PARAMS="DEPTH=15 ALMOST_FULL=1 ALMOST_EMPTY=14"
	$(MAKE) -f $(THIS) V_PARAMS="DEPTH=15 ALMOST_FULL=13 ALMOST_EMPTY=4"
	$(MAKE) -f $(THIS) V_PARAMS="ADDR=8 DATA=23 ALMOST_FULL=247 ALMOST_EMPTY=34 COUNT=1 FREE=1 FULL_IN_RESET=1 BRAM=1"

include $(DLSC_MAKEFILE_BOT)

