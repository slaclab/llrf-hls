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

   constant NUM_AXI_MASTERS_C : natural := 7;

   constant AXI_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 28, 24);  -- [0x8FFFFFFF:0x80000000]

   constant AMC0_INDEX_C      : natural := 0;
   constant AMC1_INDEX_C      : natural := 1;
   constant RTM_INDEX_C       : natural := 2;
   constant TRIG_INDEX_C      : natural := 3;
   constant APP_INDEX_C       : natural := 4;
   --constant WAVEFORM_INDEX_C  : natural := 4;
   constant SYSGEN_INDEX_C    : natural := 5;
   constant MMCM_DRP_INDEX_C  : natural := 6;

   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray (NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray (NUM_AXI_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray  (NUM_AXI_MASTERS_C-1 downto 0);

   -- Internal dac/adc signals
   signal s_dacHs        : slv(31 downto 0);
   signal s_dacLs        : Slv32Array(2 downto 0);
   signal s_adcValues    : sampleDataVectorArray(1 downto 0, 5 downto 0);
   signal s_adcValids    : Slv6Array(1 downto 0);

   signal s_fpgaInterlock : sl := '0';

   -----------------Timing--------------------------
   --    New TimingTrig assignments
   --      Event selection and trigger delay/width
   --  (0) : accelTrig  Dest0
   --  (1) : stndbyTrig Dest0
   --  (2) : accelTrig  Dest1
   --  (3) : stndbyTrig Dest1
   --  (4) : accelTrig  Dest2
   --  (5) : stndbyTrig Dest2
   --  (6) : DaqMux
   --  (7) : triggers processing [like 120 Hz ] [timeslot update, diagnbus ]
   --  s_trigPulse assignments
   --     Output of TimingTrigMux
   --  (0) : Dest0
   --  (1) : Dest1
   --  (2) : Dest2
   --  output triggers
   --  trigRtmMod
   --  trigRtmSssb
   --  trigRtmFpga
   signal stdbyTrig       : sl;
   signal accelTrig       : sl;
   signal strobe_360Hz    : sl;
   
   signal trigInput     : slv(19 downto 0);
   signal s_trigPulse   : sl;
   signal s_trigStrobe  : sl;
   signal s_trigIndex   : sl;
   signal s_trigMode    : slv(1 downto 0);
   signal trigRtmMod      : sl;
   signal trigRtmSssb     : sl;
   signal trigRtmFpga     : sl;
   signal s_trigClock   : sl;
   signal s_trigRst     :  sl;
   signal s_trigLocked  : sl;
   signal s_clkDivide   : slv(15 downto 0);
   signal s_cleanClk    : slv(1 downto 0);
   signal s_cleanRst    : slv(1 downto 0);
   signal s_dOut        : slv(15 downto 0);
   signal s_clkOut      : slv(15 downto 0);
   signal s_timingClk2x : sl;
   signal s_timingClk2x_locked : sl;

   -----------------Waveform BRAM--------------------------
   constant WF_ADDR_WIDTH_C : positive := 11; --ite(DSP_CLK_2X_G, 11, 10);  -- 2048 Samples
   constant WF_DATA_WIDTH_C : positive := 32; --ite(DSP_CLK_2X_G, 16, 32);  -- 2048 Samples

   signal s_wfAddr : slv11Array(1 downto 0);
   signal s_wfData : slv32Array(1 downto 0);

   signal s_debugValids         :   Slv4Array(1 downto 0);
   signal s_debugValues         :   sampleDataVectorArray(1 downto 0, 3 downto 0);

   signal s_procValids         :   Slv4Array(1 downto 0) := (others=>(others=>'0'));
   signal s_procValues         :   sampleDataVectorArray(1 downto 0, 3 downto 0);

   constant  IODELAY_GROUP_C                        : string := "APP_DELAY_GROUP";
   attribute IODELAY_GROUP                          : string;
   attribute IODELAY_GROUP of U_IDELAYCTRL : label is IODELAY_GROUP_C;

   signal diagnClk             : sl;
   signal diagnRst             : sl;
   signal diagnAck             : sl;
   signal diagnDepth           : slv(3 downto 0);
   signal diagnBus             : DiagnosticBusType := DIAGNOSTIC_BUS_INIT_C;
   signal timingMessage        : TimingMessageType;
   signal timingMessageSlv     : slv(TIMING_MESSAGE_BITS_C-1 downto 0);
   signal timingMessageSlvO    : slv(TIMING_MESSAGE_BITS_C-1 downto 0);

   signal trigTimeslot         : slv(4 downto 0);
   signal trigTimestamp        : slv(63 downto 0);
   
   signal hlsStreamMaster      : AxiStreamMasterType;
   signal hlsStreamSlave       : AxiStreamSlaveType;
   signal rtmStreamMaster      : AxiStreamMasterType;
   signal rtmStreamSlave       : AxiStreamSlaveType;

   signal fault                : sl := '0';

   signal clk91 , rst91 , lck91  : sl;
   signal clk119, rst119, lck119 : sl;

   constant T_FEEDBACK     : integer := 0;
   constant T_RTM          : integer := 1;
   constant T_MOD          : integer := 2;
   constant T_SSSB         : integer := 3;
   constant T_NCHANNELS    : integer := 4;

   signal appTrigConfig     : EvrV2TriggerConfigArray(T_NCHANNELS-1 downto 0);
   signal appTrigConfigS    : EvrV2TriggerConfigArray(T_NCHANNELS-1 downto 0);
   signal appTrigConfigSlv  : Slv87Array             (T_NCHANNELS-1 downto 0);
   signal appTrigConfigSlvS : Slv87Array             (T_NCHANNELS-1 downto 0);
   signal appTrig           : slv                    (T_NCHANNELS-1 downto 0);
   
begin

    -- We want to see DAC values on DaqMux
   dacValids <= (others => (others => '1'));
   dacValues(0,0) <= s_dacLs(0);
   dacValues(0,1) <= s_dacLs(1);
   dacValues(0,2) <= s_dacLs(2);
   dacValues(0,3) <= s_dacHs;
   dacValues(0,4) <= (others => '0');
   dacValues(0,5) <= (others => '0');
   dacValues(0,6) <= (others => '0');
   dacValues(1,0) <= s_dacHs;
   dacValues(1,1) <= s_dacHs;
   dacValues(1,2) <= s_dacHs;
   dacValues(1,3) <= s_dacHs;
   dacValues(1,4) <= s_dacHs;
   dacValues(1,5) <= s_dacHs;
   dacValues(1,6) <= s_dacHs;

   GEN_ADC_SIGNALS :
   for i in 5 downto 0 generate
      s_adcValues(0,i) <= adcValues(0,i);
      s_adcValues(1,i) <= adcValues(1,i);
   end generate GEN_ADC_SIGNALS;

   s_adcValids(0) <= adcValids(0)(5 downto 0);
   s_adcValids(1) <= adcValids(1)(5 downto 0);

   ---------------------
   -- AXI-Lite Crossbar
   ---------------------
   U_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
         MASTERS_CONFIG_G   => AXI_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);


   accelTrig     <= timingTrig.trigPulse(0) or
                    timingTrig.trigPulse(2) or
                    timingTrig.trigPulse(4);
   stdbyTrig     <= timingTrig.trigPulse(1) or
                    timingTrig.trigPulse(3) or
                    timingTrig.trigPulse(5);
   strobe_360Hz  <= timingBus.strobe when (APP_TIMING_MODE_C /= 2) else
                    (timingBus.strobe and timingBus.message.acRates(0));
   
   --------------------
   -- LCLS ACCEL/STBY Trigger MUX
   --------------------
   U_TimingTrigMux: entity xil_defaultlib.TimingTrigMux
      generic map (
         TPD_G => TPD_G)
      port map (
         recClk         => timingClk,
         recRst         => timingRst,
         mode_i         => s_trigMode,
         strobe_i       => strobe_360Hz,  -- reset for new trigger
         trig_i(0)      => accelTrig,
         trig_i(1)      => stdbyTrig,
         trig_o         => s_trigPulse,
         trigStrobe_o   => s_trigStrobe,
         trigIndex_o    => s_trigIndex );

   trigRtmFpga   <= appTrig(T_RTM);

   U_TrigRtmMod : entity xil_defaultlib.TrigRateSuppressor
     generic map (
       TPD_G          => TPD_G,
       MIN_INTERVAL_G => ite((APP_TIMING_MODE_C=1 or APP_TIMING_MODE_C=3),833000,1300000) ) -- 7 ms
     port map (
       clk            => timingClk,
       rst            => timingRst,
       trig_i         => appTrig(T_MOD),
       trig_o         => trigRtmMod );

   U_TrigRtmSssb : entity xil_defaultlib.TrigRateSuppressor
     generic map (
       TPD_G          => TPD_G,
       MIN_INTERVAL_G => ite(APP_TIMING_MODE_C=1 or APP_TIMING_MODE_C=3,833000,1300000) ) -- 7 ms
     port map (
       clk            => timingClk,
       rst            => timingRst,
       trig_i         => appTrig(T_SSSB),
       trig_o         => trigRtmSssb );


--   ----------------
--   -- IQ Axi lite BRAM waveforms
--   ----------------
--   GEN_WAVEFORMS : for i in 1 downto 0 generate
--      -- Dual port RAM accessible from axiLite
--      -- waveform input to the System Generator
--      U_Waveform : entity surf.AxiDualPortRam
--         generic map (
--            TPD_G        => TPD_G,
--            --BRAM_EN_G    => true,
--            --REG_EN_G     => true,
--            --MODE_G       => "write-first",
--            ADDR_WIDTH_G => WF_ADDR_WIDTH_C,
--            DATA_WIDTH_G => WF_DATA_WIDTH_C,
--            INIT_G       => "0")
--         port map (
--            -- Axi clk domain
--            axiClk         => axilClk,
--            axiRst         => axilRst,
--            axiReadMaster  => axilReadMasters (WAVEFORM_INDEX_C+i),
--            axiReadSlave   => axiLReadSlaves  (WAVEFORM_INDEX_C+i),
--            axiWriteMaster => axilWriteMasters(WAVEFORM_INDEX_C+i),
--            axiWriteSlave  => axilWriteSlaves (WAVEFORM_INDEX_C+i),
--
--            -- Sysgen clk domain
--            clk  => jesdClk(1),
--            rst  => jesdRst(1),
--            en   => '1',
--            addr => s_wfAddr(i),
--            dout => s_wfData(i));
--   end generate GEN_WAVEFORMS;

   U_SYNC_TRIG : for i in 1 downto 0 generate

      U_SYNC_ONE_SHOT  : entity surf.SynchronizerOneShot
         generic map (
            TPD_G => TPD_G)
         port map (
            clk     => jesdClk(i),
            dataIn  => timingTrig.trigPulse(6),
            dataOut => trigHw(i));
   end generate;


   -----------------------
   -- timeslot latching --
   -----------------------
   U_TimeSlot : entity xil_defaultlib.AppTimeSlot
     generic map (
       MODE_1080HZ_G    => MODE_1080HZ_C,
       MODE_DEST_G      => MODE_DEST_C,
       DEST_CHAN_G      => DEST_CHAN_C )
     port map (
       clk        => timingClk,
       rst        => timingRst,
       trig       => s_trigPulse,
       message    => timingMessage,
       timeStamp  => trigTimestamp,
       timeSlot   => trigTimeslot );
   
   ----------------
   -- SYSGEN Module
   ----------------
   U_SysGen : entity xil_defaultlib.AppLlrfCore
      generic map (
         TPD_G                => TPD_G,
         AXI_BASE_ADDR_G      => AXI_CONFIG_C(SYSGEN_INDEX_C).baseAddr )
      port map(
         -- JESD Interface
         jesdClk     => jesdClk,
         jesdRst     => jesdRst,
         jesdClk2x   => jesdClk2x,
         jesdRst2x   => jesdRst2x,
         adcHs       => s_adcValues,
         adcHsValid  => s_adcValids,
         dacHs       => s_dacHs,
         dacLs       => s_dacLs,
         debug       => s_debugValues,
         debugValids => s_debugValids,
         diagnClk    => diagnClk,
         diagn       => diagnBus.data,
         diagnFixed  => diagnBus.fixed,
         diagnSevr   => diagnBus.sevr,
         diagnStrobe => diagnBus.strobe,
         rfSwitch       => s_fpgaInterlock,
         timingClk      => timingClk,
         timingRst      => timingRst,
         trigPulse      => appTrig(T_FEEDBACK),
         timeslot       => trigTimeslot,
         timestamp      => trigTimestamp,
         dmod           => timingTrig.dmod(191 downto 0),
	 bsa            => timingTrig.bsa(127 downto 0),
         trigDaqOut     => open,
         trigMode       => s_trigMode,
         trigIndex      => s_trigIndex,
         -- DAC SigGen
         dacSigCtrl     => dacSigCtrl,
         dacSigStatus   => dacSigStatus,
         dacSigValids   => dacSigValids,
         dacSigValues   => dacSigValues,
	 -- Fault status
	 faultIn        => fault,

         -- AXI-Lite Port
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => axilReadMasters (SYSGEN_INDEX_C),
         axiReadSlave   => axilReadSlaves  (SYSGEN_INDEX_C),
         axiWriteMaster => axilWriteMasters(SYSGEN_INDEX_C),
         axiWriteSlave  => axilWriteSlaves (SYSGEN_INDEX_C),

         -- Streaming port
         streamClk      => axilClk,
         streamRst      => axilRst,
         streamMaster   => hlsStreamMaster,
         streamSlave    => hlsStreamSlave );

   GEN_LCLS_I : if APP_TIMING_MODE_C = 1 generate
     V2FV1 : entity lcls_timing_core.EvrV2FromV1
       port map ( clk       => timingClk,
                  disable   => '0',
                  timingIn  => timingBus,
                  timingOut => timingMessage );

   end generate;

   GEN_LCLS_II : if APP_TIMING_MODE_C /= 1 generate
     timingMessage <= timingBus.message;
   end generate;

   U_DiagnBus : entity xil_defaultlib.AppDiagnBus
     generic map (
       FIFO_ADDR_WIDTH_G => 8 )  -- expect < 256 us delay in diagnBus
     port map (
       -- timingClk domain
       timingClk      => timingClk,
       timingRst      => timingRst,
       timingStrobe   => timingBus.strobe,
       timingMessage  => timingMessage,
       trigger        => timingTrig.trigPulse(8),
       -- diagnosticClk domain
       diagnosticClk  => diagnClk,
       diagnosticRst  => diagnRst,
       diagnosticBusI => diagnBus,
       diagnosticBusO => diagnosticBus );
                
   timingMessageSlv <= toSlv(timingMessage);

   V2FIFO : entity surf.FifoAsync
     generic map ( FWFT_EN_G     => true,
                   DATA_WIDTH_G  => TIMING_MESSAGE_BITS_C,
                   ADDR_WIDTH_G  => 4 )
     port map    ( rst           => diagnRst,
                   -- Write Ports (wr_clk domain)
                   wr_clk        => timingClk,
                   wr_en         => s_trigStrobe,
                   din           => timingMessageSlv,
                   -- Read Ports (rd_clk domain)
                   rd_clk        => diagnClk,
                   rd_en         => diagnBus.strobe,
                   dout          => timingMessageSlvO );

   diagnBus.timingMessage <= toTimingMessageType(timingMessageSlvO);

   diagnosticClk <= diagnClk;
   diagnosticRst <= diagnRst;

   -- Clock trigger divider - LCLS I  recovered timing clock*(3/21)
   -- Clock trigger divider - LCLS II recovered timing clock*(9/100)
   U_ClockManager : entity surf.ClockManagerUltraScale
     generic map (
       TPD_G              => 1 ns,
       TYPE_G             => "MMCM",
       INPUT_BUFG_G       => false,
       FB_BUFG_G          => true,
       NUM_CLOCKS_G       => 1,
       BANDWIDTH_G        => "OPTIMIZED",
       CLKIN_PERIOD_G     => ite(APP_TIMING_MODE_C=1 or APP_TIMING_MODE_C=3,8.403,5.385),
       DIVCLK_DIVIDE_G    => ite(APP_TIMING_MODE_C=1 or APP_TIMING_MODE_C=3,1    ,5),
       CLKFBOUT_MULT_F_G  => ite(APP_TIMING_MODE_C=1 or APP_TIMING_MODE_C=3,10.0 ,31.50),
       CLKOUT0_DIVIDE_F_G => ite(APP_TIMING_MODE_C=1 or APP_TIMING_MODE_C=3,70.0 ,70.0),
       CLKOUT0_PHASE_G    => 0.0,
       CLKOUT0_RST_HOLD_G => 32
       )
     port map (
       clkIn     => timingClk,
       rstIn     => timingRst,
       clkOut(0) => s_trigClock,
       rstOut(0) => s_trigRst,
       locked    => s_trigLocked,
       -- AXI-Lite Port
       axilClk         => axilClk,
       axilRst         => axilRst,
       axilReadMaster  => AXI_LITE_READ_MASTER_INIT_C,
       axilReadSlave   => open,
       axilWriteMaster => AXI_LITE_WRITE_MASTER_INIT_C,
       axilWriteSlave  => open
       );

   axilReadSlaves  (MMCM_DRP_INDEX_C) <= AXI_LITE_READ_SLAVE_INIT_C;
   axilWriteSlaves (MMCM_DRP_INDEX_C) <= AXI_LITE_WRITE_SLAVE_INIT_C;

   -----------------------
   -- AMC BAY[0] Interface
   -----------------------
   U_AMC0 : entity amc_carrier_core.AmcMrLlrfDownConvertCore
      generic map (
         TPD_G            => TPD_G,
         AXI_BASE_ADDR_G  => AXI_CONFIG_C(AMC0_INDEX_C).baseAddr)
      port map (
         -- JESD SYNC Interface
         jesdClk         => jesdClk(0),
         jesdRst         => jesdRst(0),
         jesdSysRef      => jesdSysRef(0),
         jesdRxSync      => jesdRxSync(0),
         -- DAC Interface (jesdClk domain)
         dacValues(0)    => s_dacLs(0),
         dacValues(1)    => s_dacLs(1),
         dacValues(2)    => s_dacLs(2),
         -- AXI-Lite Interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters (AMC0_INDEX_C),
         axilReadSlave   => axilReadSlaves  (AMC0_INDEX_C),
         axilWriteMaster => axilWriteMasters(AMC0_INDEX_C),
         axilWriteSlave  => axilWriteSlaves (AMC0_INDEX_C),
         -----------------------
         -- Application Ports --
         -----------------------
         -- AMC's JTAG Ports
         jtagPri         => jtagPri(0),
         jtagSec         => jtagSec(0),
         -- AMC's FPGA Clock Ports
         fpgaClkP        => fpgaClkP(0),
         fpgaClkN        => fpgaClkN(0),
         -- AMC's System Reference Ports
         sysRefP         => sysRefP(0),
         sysRefN         => sysRefN(0),
         -- AMC's Sync Ports
         syncInP         => syncInP(0),
         syncInN         => syncInN(0),
         syncOutP        => syncOutP(0),
         syncOutN        => syncOutN(0),
         -- AMC's Spare Ports
         spareP          => spareP(0),
         spareN          => spareN(0));

   -----------------------
   -- AMC BAY[1] Interface
   -----------------------
   U_UPCONVERT_V1 : if (UPCONVERT_V2_C = false) generate
      U_AMC1 : entity amc_carrier_core.AmcMrLlrfUpConvertCore
         generic map (
            TPD_G              => TPD_G,
            IODELAY_GROUP_G    => IODELAY_GROUP_C,
            AXI_BASE_ADDR_G    => AXI_CONFIG_C(AMC1_INDEX_C).baseAddr,
            TIMING_TRIG_MODE_G => TRUE)  -- Clock will be outpout on timingTrig port
         port map (
            -- JESD SYNC Interface
            jesdClk         => jesdClk(1),
            jesdRst         => jesdRst(1),
            jesdClk2x       => jesdClk2x(1),
            jesdRst2x       => jesdRst2x(1),
            jesdSysRef      => jesdSysRef(1),
            jesdRxSync      => jesdRxSync(1),
            -- DAC Interface (jesdClk domain)
            dacValues       => s_dacHs,
            recClk          => timingClk,
            recRst          => timingRst,
            -- Interlock and trigger
            timingTrig      => s_trigClock,
            fpgaInterlock   => s_fpgaInterlock,
            -- AXI-Lite Interface
            axilClk         => axilClk,
            axilRst         => axilRst,
            axilReadMaster  => axilReadMasters (AMC1_INDEX_C),
            axilReadSlave   => axilReadSlaves  (AMC1_INDEX_C),
            axilWriteMaster => axilWriteMasters(AMC1_INDEX_C),
            axilWriteSlave  => axilWriteSlaves (AMC1_INDEX_C),
            -----------------------
            -- Application Ports --
            -----------------------
            -- AMC's JTAG Ports
            jtagPri         => jtagPri(1),
            jtagSec         => jtagSec(1),
            -- AMC's FPGA Clock Ports
            fpgaClkP        => fpgaClkP(1),
            fpgaClkN        => fpgaClkN(1),
            -- AMC's System Reference Ports
            sysRefP         => sysRefP(1),
            sysRefN         => sysRefN(1),
            -- AMC's Sync Ports
            syncInP         => syncInP(1),
            syncInN         => syncInN(1),
            syncOutP        => syncOutP(1),
            syncOutN        => syncOutN(1),
            -- AMC's Spare Ports
            spareP          => spareP(1),
            spareN          => spareN(1));
   end generate;

   U_UPCONVERT_V2 : if (UPCONVERT_V2_C = true) generate
      U_AMC1 : entity amc_carrier_core.AmcMrLlrfGen2UpConvert
         generic map (
            TPD_G              => TPD_G,
            IODELAY_GROUP_G    => IODELAY_GROUP_C,
            AXI_BASE_ADDR_G    => AXI_CONFIG_C(AMC1_INDEX_C).baseAddr,
            TIMING_TRIG_MODE_G => TRUE)  -- Clock will be outpout on timingTrig port
         port map (
            -- JESD SYNC Interface
            jesdClk         => jesdClk(1),
            jesdRst         => jesdRst(1),
            jesdClk2x       => jesdClk2x(1),
            jesdRst2x       => jesdRst2x(1),
            jesdSysRef      => jesdSysRef(1),
            jesdRxSync      => jesdRxSync(1),

            jesdTxSync(6 downto 0) => jesdTxSync(1),
            jesdTxSync(9 downto 7) => open,

            -- DAC Interface (jesdClk domain)
            recClk          => timingClk,
            recRst          => timingRst,
            -- Interlock and trigger
            timingTrig      => s_trigClock,
            fpgaInterlock   => s_fpgaInterlock,
            -- AXI-Lite Interface
            axilClk         => axilClk,
            axilRst         => axilRst,
            axilReadMaster  => axilReadMasters(AMC1_INDEX_C),
            axilReadSlave   => axilReadSlaves(AMC1_INDEX_C),
            axilWriteMaster => axilWriteMasters(AMC1_INDEX_C),
            axilWriteSlave  => axilWriteSlaves(AMC1_INDEX_C),
            -----------------------
            -- Application Ports --
            -----------------------
            -- AMC's JTAG Ports
            jtagPri         => jtagPri(1),
            jtagSec         => jtagSec(1),
            -- AMC's FPGA Clock Ports
            fpgaClkP        => fpgaClkP(1),
            fpgaClkN        => fpgaClkN(1),
            -- AMC's System Reference Ports
            sysRefP         => sysRefP(1),
            sysRefN         => sysRefN(1),
            -- AMC's Sync Ports
            syncInP         => syncInP(1),
            syncInN         => syncInN(1),
            syncOutP        => syncOutP(1),
            syncOutN        => syncOutN(1),
            -- AMC's Spare Ports
            spareP          => spareP(1),
            spareN          => spareN(1));
   end generate;

--   ----------------
--   -- RTM Interface
--   ----------------

   U_RTM : entity amc_carrier_core.RtmRfInterlock
      generic map (
         TPD_G            => TPD_G,
         IODELAY_GROUP_G  => IODELAY_GROUP_C,
         AXIL_BASE_ADDR_G => AXI_CONFIG_C(RTM_INDEX_C).baseAddr,
         TDEST_G          => x"C1")
      port map (
         -- Recovered EVR clock
         recClk          => timingClk,
         recRst          => timingRst,
         -- Timing triggers
         stndbyTrig      => trigRtmMod,
         accelTrig       => trigRtmSssb,
         dataTrig        => trigRtmFpga,
         timestamp       => trigTimestamp(63 downto 0),
	 -- Fault Stauts
	 faultOut        => fault,
         -- AXI-Lite Interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMasters(RTM_INDEX_C),
         axilReadSlave   => axilReadSlaves(RTM_INDEX_C),
         axilWriteMaster => axilWriteMasters(RTM_INDEX_C),
         axilWriteSlave  => axilWriteSlaves(RTM_INDEX_C),
         -- AXI Stream Interface (axisClk domain)
         axisClk         => axilClk,
         axisRst         => axilRst,
         axisMaster      => rtmStreamMaster, 
         axisSlave       => rtmStreamSlave,
         -----------------------
         -- Application Ports --
         -----------------------
         -- RTM's Low Speed Ports
         rtmLsP          => rtmLsP,
         rtmLsN          => rtmLsN,
         -- RTM's Clock Reference
         genClkP         => genClkP,
         genClkN         => genClkN);

   --------------------
   -- Common IDELAYCTRL
   --------------------
   U_IDELAYCTRL : IDELAYCTRL
      generic map (
         SIM_DEVICE => "ULTRASCALE")
      port map (
         RDY    => open,
         REFCLK => jesdClk2x(1),
         RST    => jesdRst2x(1));

   U_STREAM_MUX : entity surf.AxiStreamMux
      generic map (
         TPD_G         => TPD_G,
	 PIPE_STAGES_G => 1,
	 NUM_SLAVES_G  => 2)
      port map (
         axisClk         => axilClk,
	 axisRst         => axilRst,
	 -- Slaves
	 sAxisMasters(0) => hlsStreamMaster,
	 sAxisMasters(1) => rtmStreamMaster,
	 sAxisSlaves(0)  => hlsStreamSlave,
	 sAxisSlaves(1)  => rtmStreamSlave,
	 -- Master
	 mAxisMaster     => obAppDebugMaster,
	 mAxisSlave      => obAppDebugSlave);

   debugValues <= s_debugValues;
   debugValids <= s_debugValids;

   --------------------------
   -- Terminate usued outputs
   --------------------------
   obBpMsgClientMaster <= AXI_STREAM_MASTER_INIT_C;
   ibBpMsgClientSlave  <= AXI_STREAM_SLAVE_FORCE_C;

   ibBpMsgServerSlave  <= AXI_STREAM_SLAVE_FORCE_C;

   ibAppDebugSlave  <= AXI_STREAM_SLAVE_FORCE_C;

   mpsObSlaves <= (others => AXI_STREAM_SLAVE_FORCE_C);
   timingPhy   <= TIMING_PHY_INIT_C;

   freezeHw <= (others => '0');


   GEN_APP_TIMING_CLK : if APP_TIMING_MODE_C=3 generate
     --
     -- Clock managers for synthesizing 119 MHz from 186 MHz timingClk
     --
     --   I don't think we care much about the relative phasing of these
     --   If we do, we can reset with a 71kHz strobe
     --
     U_MMCM_130 : entity surf.ClockManagerUltraScale
       generic map (
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => false,
         NUM_CLOCKS_G       => 1,
         CLKIN_PERIOD_G     => 5.385,    -- ClkIn 1300/7
         CLKFBOUT_MULT_F_G  => 55.125,   -- VCO = 1023.75
         DIVCLK_DIVIDE_G    => 10,
         CLKOUT0_DIVIDE_F_G => 11.25,    -- Clk =  91
         CLKOUT0_PHASE_G    => 0.0,
         CLKOUT0_RST_HOLD_G => 32
         )
       port map (
         clkIn     => timingClk,
         rstIn     => timingRst,
         clkOut(0) => clk91,
         rstOut(0) => rst91,
         locked    => lck91 );

     U_MMCM_119 : entity surf.ClockManagerUltraScale
       generic map (
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => false,
         NUM_CLOCKS_G       => 1,
         CLKIN_PERIOD_G     => 10.989,   -- ClkIn =   91
         CLKFBOUT_MULT_F_G  => 10.625,   -- VCO   = 966.875
         CLKOUT0_DIVIDE_F_G => 8.125,    -- Clk   =  119
         CLKOUT0_PHASE_G    => 0.0,
         CLKOUT0_RST_HOLD_G => 32
         )
       port map (
         clkIn     => clk91,
         rstIn     => rst91,
         clkOut(0) => clk119,
         rstOut(0) => rst119,
         locked    => lck119 );

     appTimingClk <= clk119;
     appTimingRst <= rst119;
     
   end generate;

   U_TrigReg : entity lcls_timing_core.EvrV2TrigReg
     generic map ( TRIGGERS_C => appTrigConfig'length )
     port map (
       axiClk          => axilClk,
       axiRst          => axilRst,
       axilWriteMaster => axilWriteMasters(TRIG_INDEX_C),
       axilWriteSlave  => axilWriteSlaves (TRIG_INDEX_C),
       axilReadMaster  => axilReadMasters (TRIG_INDEX_C),
       axilReadSlave   => axilReadSlaves  (TRIG_INDEX_C),
       -- configuration
       triggerConfig   => appTrigConfig );

   GEN_TRIG : for i in appTrigConfig'range generate

     appTrigConfigSlv(i) <= toSlv(appTrigConfig(i));
     appTrigConfigS  (i) <= toTriggerConfig(appTrigConfigSlvS(i));
     
     U_TrigRegSync : entity surf.SynchronizerVector
       generic map ( WIDTH_G => EVRV2_TRIGGER_CONFIG_BITS_C )
       port map (
         clk     => timingClk,
         dataIn  => appTrigConfigSlv(i),
         dataOut => appTrigConfigSlvS(i) );

     U_Trigger : entity lcls_timing_core.EvrV2Trigger
       generic map (
         CHANNELS_C   => 1,
         TRIG_DEPTH_C => 0 ) -- no FIFO pipeline
       port map (
         clk        => timingClk,
         rst        => timingRst,
         config     => appTrigConfigS(i),
         arm(0)     => s_trigPulse,
         fire       => s_trigPulse,
         trigstate  => appTrig       (i) );
   end generate GEN_TRIG;
   
end mapping;
