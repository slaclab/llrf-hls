-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Application Core's Top Level
--
-- Note: Common-to-Application interface defined in HPS ESD: LCLSII-2.7-ES-0536
--
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 AMC Carrier Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'LCLS2 AMC Carrier Firmware', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.jesd204bpkg.all;
use surf.EthMacPkg.all;

library amc_carrier_core;
use amc_carrier_core.AmcCarrierPkg.all;
use amc_carrier_core.AppTopPkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;
use lcls_timing_core.EvrV2Pkg.all;

library xil_defaultlib;
use xil_defaultlib.AppOpts.all;

library unisim;
use unisim.vcomponents.all;

entity AppCore is
   generic (
      TPD_G              : time                    := 1 ns;
      SIM_SPEEDUP_G      : boolean                 := false;
      SIMULATION_G       : boolean                 := false;
      AXI_BASE_ADDR_G    : slv(31 downto 0)        := x"80000000";
      RF_INTERLOCK_RTM_G : boolean                 := false;
      JESD_USR_DIV_G     : natural);
   port (
      -- Clocks and resets
      jesdClk             : in    slv(1 downto 0);
      jesdRst             : in    slv(1 downto 0);
      jesdClk2x           : in    slv(1 downto 0);
      jesdRst2x           : in    slv(1 downto 0);
      jesdUsrClk          : in    slv(1 downto 0);
      jesdUsrRst          : in    slv(1 downto 0);
      appTimingClk        : out   sl := '0';
      appTimingRst        : out   sl := '1';
      -- DaqMux/Trig Interface (timingClk domain)
      freezeHw            : out   slv(1 downto 0);
      timingTrig          : in    TimingTrigType;
      trigHw              : out   slv(1 downto 0);
      trigCascBay         : in    slv(1 downto 0);
      -- JESD SYNC Interface (jesdClk[1:0] domain)
      jesdSysRef          : out   slv(1 downto 0);
      jesdRxSync          : in    slv(1 downto 0);
      jesdTxSync          : out   Slv7Array(1 downto 0) := (others=>(others=>'0'));
      -- ADC/DAC/Debug Interface (jesdClk[1:0] domain)
      adcValids           : in    Slv7Array(1 downto 0);
      adcValues           : in    sampleDataVectorArray(1 downto 0, 6 downto 0);
      dacValids           : out   Slv7Array(1 downto 0);
      dacValues           : out   sampleDataVectorArray(1 downto 0, 6 downto 0);
      debugValids         : out   Slv4Array(1 downto 0);
      debugValues         : out   sampleDataVectorArray(1 downto 0, 3 downto 0);
      -- DAC Signal Generator Interface
      -- If SIG_GEN_LANE_MODE_G = '0', (jesdClk[1:0] domain)
      -- If SIG_GEN_LANE_MODE_G = '1', (jesdClk2x[1:0] domain)
      dacSigCtrl          : out   DacSigCtrlArray(1 downto 0);
      dacSigStatus        : in    DacSigStatusArray(1 downto 0);
      dacSigValids        : in    Slv7Array(1 downto 0);
      dacSigValues        : in    sampleDataVectorArray(1 downto 0, 6 downto 0);
      -- AXI-Lite Interface (axilClk domain) [0x8FFFFFFF:0x80000000]
      axilClk             : in    sl;
      axilRst             : in    sl;
      axilReadMaster      : in    AxiLiteReadMasterType;
      axilReadSlave       : out   AxiLiteReadSlaveType;
      axilWriteMaster     : in    AxiLiteWriteMasterType;
      axilWriteSlave      : out   AxiLiteWriteSlaveType;
      ----------------------
      -- Top Level Interface
      ----------------------
      -- Timing Interface (timingClk domain)
      recTimingClk        : in    sl;
      recTimingRst        : in    sl;
      timingClk           : in    sl;
      timingRst           : in    sl;
      timingBus           : in    TimingBusType;
      timingPhy           : out   TimingPhyType;
      timingPhyClk        : in    sl;
      timingPhyRst        : in    sl;
      -- Diagnostic Interface (diagnosticClk domain)
      diagnosticClk       : out   sl;
      diagnosticRst       : out   sl;
      diagnosticBus       : out   DiagnosticBusType;
      -- Backplane Messaging Interface  (axilClk domain)
      obBpMsgClientMaster : out   AxiStreamMasterType;
      obBpMsgClientSlave  : in    AxiStreamSlaveType;
      ibBpMsgClientMaster : in    AxiStreamMasterType;
      ibBpMsgClientSlave  : out   AxiStreamSlaveType;
      obBpMsgServerMaster : out   AxiStreamMasterType;
      obBpMsgServerSlave  : in    AxiStreamSlaveType;
      ibBpMsgServerMaster : in    AxiStreamMasterType;
      ibBpMsgServerSlave  : out   AxiStreamSlaveType;
      -- Application Debug Interface (axilClk domain)
      obAppDebugMaster    : out   AxiStreamMasterType;
      obAppDebugSlave     : in    AxiStreamSlaveType;
      ibAppDebugMaster    : in    AxiStreamMasterType;
      ibAppDebugSlave     : out   AxiStreamSlaveType;
      -- MPS Concentrator Interface (ref156MHzClk domain)
      mpsObMasters        : in    AxiStreamMasterArray(14 downto 0);
      mpsObSlaves         : out   AxiStreamSlaveArray(14 downto 0);
      -- Misc. Interface
      ipmiBsi             : in    BsiBusType;
      gthFabClk           : in    sl;
      ethPhyReady         : in    sl;
      -----------------------
      -- Application Ports --
      -----------------------
      -- AMC's JTAG Ports
      jtagPri             : inout Slv5Array(1 downto 0);
      jtagSec             : inout Slv5Array(1 downto 0);
      -- AMC's FPGA Clock Ports
      fpgaClkP            : inout Slv2Array(1 downto 0);
      fpgaClkN            : inout Slv2Array(1 downto 0);
      -- AMC's System Reference Ports
      sysRefP             : inout Slv4Array(1 downto 0);
      sysRefN             : inout Slv4Array(1 downto 0);
      -- AMC's Sync Ports
      syncInP             : inout Slv4Array(1 downto 0);
      syncInN             : inout Slv4Array(1 downto 0);
      syncOutP            : inout Slv10Array(1 downto 0);
      syncOutN            : inout Slv10Array(1 downto 0);
      -- AMC's Spare Ports
      spareP              : inout Slv16Array(1 downto 0);
      spareN              : inout Slv16Array(1 downto 0);
      -- RTM's Low Speed Ports
      rtmLsP              : inout slv(53 downto 0);
      rtmLsN              : inout slv(53 downto 0);
      -- RTM's High Speed Ports
      rtmHsRxP            : in    sl;
      rtmHsRxN            : in    sl;
      rtmHsTxP            : out   sl := '0';
      rtmHsTxN            : out   sl := '1';
      -- RTM's Clock Reference
      genClkP             : in    sl;
      genClkN             : in    sl);
end AppCore;

architecture mapping of AppCore is

begin

   U_BASE : entity xil_defaultlib.AppCoreBase
   generic map (
      TPD_G                 => TPD_G,
      SIM_SPEEDUP_G         => SIM_SPEEDUP_G,
      SIMULATION_G          => SIMULATION_G,
      AXI_BASE_ADDR_G       => AXI_BASE_ADDR_G,
      RF_INTERLOCK_RTM_G    => RF_INTERLOCK_RTM_G,
      JESD_USR_DIV_G        => JESD_USR_DIV_G )
   port map (
      -- Clocks and resets
      jesdClk                => jesdClk,
      jesdRst                => jesdRst,
      jesdClk2x              => jesdClk2x,
      jesdRst2x              => jesdRst2x,
      jesdUsrClk             => jesdUsrClk,
      jesdUsrRst             => jesdUsrRst,
      appTimingClk           => appTimingClk,
      appTimingRst           => appTimingRst,
      -- DaqMux/Trig Interface (timingClk domain)
      freezeHw               => freezeHw,
      timingTrig             => timingTrig,
      trigHw                 => trigHw,
      trigCascBay            => trigCascBay,
      -- JESD SYNC Interface (jesdClk[1:0] domain)
      jesdSysRef             => jesdSysRef,
      jesdRxSync             => jesdRxSync,
      jesdTxSync             => jesdTxSync,
      -- ADC/DAC/Debug Interface (jesdClk[1:0] domain)
      adcValids              => adcValids,
      adcValues              => adcValues,
      dacValids              => dacValids,
      dacValues              => dacValues,
      debugValids            => debugValids,
      debugValues            => debugValues,
      -- DAC Signal Generator Interface
      -- If SIG_GEN_LANE_MODE_G = '0', (jesdClk[1:0] domain)
      -- If SIG_GEN_LANE_MODE_G = '1', (jesdClk2x[1:0] domain)
      dacSigCtrl             => dacSigCtrl,
      dacSigStatus           => dacSigStatus,
      dacSigValids           => dacSigValids,
      dacSigValues           => dacSigValues,
      -- AXI-Lite Interface (axilClk domain) [0x8FFFFFFF:0x80000000]
      axilClk                => axilClk,
      axilRst                => axilRst,
      axilReadMaster         => axilReadMaster,
      axilReadSlave          => axilReadSlave,
      axilWriteMaster        => axilWriteMaster,
      axilWriteSlave         => axilWriteSlave,
      ----------------------
      -- Top Level Interface
      ----------------------
      -- Timing Interface (timingClk domain)
      recTimingClk           => recTimingClk,
      recTimingRst           => recTimingRst,
      timingClk              => timingClk,
      timingRst              => timingRst,
      timingBus              => timingBus,
      timingPhy              => timingPhy,
      timingPhyClk           => timingPhyClk,
      timingPhyRst           => timingPhyRst,
      -- Diagnostic Interface (diagnosticClk domain)
      diagnosticClk          => diagnosticClk,
      diagnosticRst          => diagnosticRst,
      diagnosticBus          => diagnosticBus,
      -- Backplane Messaging Interface  (axilClk domain)
      obBpMsgClientMaster    => obBpMsgClientMaster,
      obBpMsgClientSlave     => obBpMsgClientSlave,
      ibBpMsgClientMaster    => ibBpMsgClientMaster,
      ibBpMsgClientSlave     => ibBpMsgClientSlave,
      obBpMsgServerMaster    => obBpMsgServerMaster,
      obBpMsgServerSlave     => obBpMsgServerSlave,
      ibBpMsgServerMaster    => ibBpMsgServerMaster,
      ibBpMsgServerSlave     => ibBpMsgServerSlave,
      -- Application Debug Interface (axilClk domain)
      obAppDebugMaster       => obAppDebugMaster,
      obAppDebugSlave        => obAppDebugSlave,
      ibAppDebugMaster       => ibAppDebugMaster,
      ibAppDebugSlave        => ibAppDebugSlave,
      -- MPS Concentrator Interface (ref156MHzClk domain)
      mpsObMasters           => mpsObMasters,
      mpsObSlaves            => mpsObSlaves,
      -- Misc. Interface
      ipmiBsi                => ipmiBsi,
      gthFabClk              => gthFabClk,
      ethPhyReady            => ethPhyReady,
      -----------------------
      -- Application Ports --
      -----------------------
      -- AMC's JTAG Ports
      jtagPri                => jtagPri,
      jtagSec                => jtagSec,
      -- AMC's FPGA Clock Ports
      fpgaClkP               => fpgaClkP,
      fpgaClkN               => fpgaClkN,
      -- AMC's System Reference Ports
      sysRefP                => sysRefP,
      sysRefN                => sysRefN,
      -- AMC's Sync Ports
      syncInP                => syncInP,
      syncInN                => syncInN,
      syncOutP               => syncOutP,
      syncOutN               => syncOutN,
      -- AMC's Spare Ports
      spareP                 => spareP,
      spareN                 => spareN,
      -- RTM's Low Speed Ports
      rtmLsP                 => rtmLsP,
      rtmLsN                 => rtmLsN,
      -- RTM's High Speed Ports
      rtmHsRxP               => rtmHsRxP,
      rtmHsRxN               => rtmHsRxN,
      rtmHsTxP               => rtmHsTxP,
      rtmHsTxN               => rtmHsTxN,
      -- RTM's Clock Reference
      genClkP                => genClkP,
      genClkN                => genClkN );
end mapping;
