############################
# DO NOT EDIT THE CODE BELOW
############################

# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load submodules' code and constraints
loadRuckusTcl $::env(TOP_DIR)/submodules

loadSource -path "$::TOP_DIR/common/Llrf/rtl/AppDiagnBus.vhd"
loadSource -path "$::TOP_DIR/common/Llrf/rtl/AppTimeSlot.vhd"
loadSource -path "$::TOP_DIR/common/Llrf/rtl/TimingTrigMux.vhd"
loadSource -path "$::TOP_DIR/common/Llrf/rtl/TrigRateSuppressor.vhd"

# Load target's source code and constraints
loadSource      -dir  "$::DIR_PATH/hdl"
loadConstraints -dir  "$::DIR_PATH/hdl"

