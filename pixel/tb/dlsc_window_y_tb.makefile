
include $(DLSC_MAKEFILE_TOP)

DLSC_DEPENDS    += pixel

V_DUT           += dlsc_window_y.v

SP_TESTBENCH    += dlsc_window_y_tb.sp

V_PARAMS_DEF    += \
    WIN=5 \
    MAX_X=1024 \
    XB=10 \
    BITS=8 \
    EDGE_MODE=1 \
    USE_LAST_X=0

sims0:
	$(MAKE) -f $(THIS) V_PARAMS=""
	$(MAKE) -f $(THIS) V_PARAMS="EDGE_MODE=3 WIN=3"
	$(MAKE) -f $(THIS) V_PARAMS="EDGE_MODE=3 WIN=5"
	$(MAKE) -f $(THIS) V_PARAMS="EDGE_MODE=3 WIN=7"

sims1:
	$(MAKE) -f $(THIS) V_PARAMS="EDGE_MODE=3 WIN=9 BITS=7"
	$(MAKE) -f $(THIS) V_PARAMS="EDGE_MODE=3 WIN=11 BITS=5"
	$(MAKE) -f $(THIS) V_PARAMS="EDGE_MODE=3 WIN=13 BITS=4"

sims2:
	$(MAKE) -f $(THIS) V_PARAMS="EDGE_MODE=0"
	$(MAKE) -f $(THIS) V_PARAMS="EDGE_MODE=0 USE_LAST_X=1"
	$(MAKE) -f $(THIS) V_PARAMS="EDGE_MODE=0 USE_LAST_X=1 WIN=1"
	$(MAKE) -f $(THIS) V_PARAMS="EDGE_MODE=2"

sims3:
	$(MAKE) -f $(THIS) V_PARAMS="MAX_X=384 XB=9"
	$(MAKE) -f $(THIS) V_PARAMS="WIN=7"
	$(MAKE) -f $(THIS) V_PARAMS="BITS=12"
	$(MAKE) -f $(THIS) V_PARAMS="WIN=15 BITS=4 EDGE_MODE=3"

include $(DLSC_MAKEFILE_BOT)

