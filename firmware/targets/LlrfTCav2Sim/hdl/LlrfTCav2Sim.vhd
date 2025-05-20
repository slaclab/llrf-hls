library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;
--use ieee.math_real.all;

library surf;
use surf.StdRtlPkg.all;
use surf.jesd204bpkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;

library lcls_timing_core;
use lcls_timing_core.EvrV2Pkg.all;
use lcls_timing_core.TimingPkg.all;
use lcls_timing_core.TPGPkg.all;

library amc_carrier_core;
use amc_carrier_core.AmcCarrierPkg.all;
use amc_carrier_core.AppTopPkg.all;

library xil_defaultlib;
use xil_defaultlib.AppOpts.all;

entity LlrfTCav2Sim is
end LlrfTCav2Sim;

architecture top_level of LlrfTCav2Sim is

  constant TPD_G : time := 1 ns;

  signal jesdClk, jesdRst     : sl;
  signal jesdClk2x, jesdRst2x : sl;
  signal axilClk, axilRst     : sl;
  signal axilWriteMaster      : AxiLiteWriteMasterType;
  signal axilWriteSlave       : AxiLiteWriteSlaveType;
  signal adcValues            : sampleDataVectorArray(1 downto 0, 6 downto 0);
  signal recTimingClk, recTimingRst : sl;
  signal timingClk, timingRst : sl;
  signal jtagPri              : Slv5Array(1 downto 0) := (others=>(others=>'0'));
  signal jtagSec              : Slv5Array(1 downto 0) := (others=>(others=>'0'));
  signal fpgaClkP             : Slv2Array(1 downto 0) := (others=>(others=>'0'));
  signal fpgaClkN             : Slv2Array(1 downto 0) := (others=>(others=>'0'));
  signal sysRefP              : Slv4Array(1 downto 0) := (others=>(others=>'0'));
  signal sysRefN              : Slv4Array(1 downto 0) := (others=>(others=>'0'));
  signal syncInP              : Slv4Array(1 downto 0) := (others=>(others=>'0'));
  signal syncInN              : Slv4Array(1 downto 0) := (others=>(others=>'0'));
  signal syncOutP             : Slv10Array(1 downto 0) := (others=>(others=>'0'));
  signal syncOutN             : Slv10Array(1 downto 0) := (others=>(others=>'0'));
  signal spareP               : Slv16Array(1 downto 0) := (others=>(others=>'0'));
  signal spareN               : Slv16Array(1 downto 0) := (others=>(others=>'0'));
  signal rtmLsP               : slv(53 downto 0) := (others=>'0');
  signal rtmLsN               : slv(53 downto 0) := (others=>'0');

  signal timingTrig           : TimingTrigType;
  signal timingBus            : TimingBusType;
  signal txData               : slv(15 downto 0);
  signal txDataK              : slv( 1 downto 0);
  signal tpgConfig            : TPGConfigType := TPG_CONFIG_INIT_C;
  signal appTimingBus         : TimingBusType;

  type RegType is record
    accelTrig  : sl;
    stdbyTrig  : sl;
    timingBus  : TimingBusType;
    timingTrig : TimingTrigType;
  end record;

  constant REG_INIT_C : RegType := (
    accelTrig  => '0',
    stdbyTrig  => '0',
    timingBus  => TIMING_BUS_INIT_C,
    timingTrig => TIMING_TRIG_INIT_C );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

  signal accelTrig, stdbyTrig : sl;
  constant accelConfig : EvrV2TriggerConfigType := (
    enabled  => '1', polarity => '1',
    complEn  => '0', complAnd => '0',
    delay    => toSlv(10,EVRV2_TRIG_WIDTH_C),
    width    => toSlv(3,EVRV2_TRIG_WIDTH_C),
    channel  => x"0", channels => x"0000",
    delayTap => (others=>'0'), loadTap  => '0' );

  constant stdbyConfig : EvrV2TriggerConfigType := (
    enabled  => '1', polarity => '1',
    complEn  => '0', complAnd => '0',
    delay    => toSlv(30,EVRV2_TRIG_WIDTH_C),
    width    => toSlv(3,EVRV2_TRIG_WIDTH_C),
    channel  => x"0", channels => x"0000",
    delayTap => (others=>'0'), loadTap  => '0' );

begin

  tpgConfig.pulseIdWrEn <= '0';
  
  recTimingClk <= jesdClk;
  recTimingRst <= jesdRst;
  timingClk <= recTimingClk;
  timingRst <= recTimingRst;
  axilClk      <= jesdClk;
  axilRst      <= jesdRst;
  
  process
  begin
    jesdClk2x <= '1';
    jesdClk   <= '1';
    wait for 1.5 ns;
    jesdClk2x <= '0';
    wait for 1.5 ns;
    jesdClk2x <= '1';
    jesdClk   <= '0';
    wait for 1.5 ns;
    jesdClk2x <= '0';
    wait for 1.5 ns;
  end process;

  process
  begin
    jesdRst   <= '1';
    jesdRst2x <= '1';
    wait for 100 ns;
    jesdRst   <= '0';
    jesdRst2x <= '0';
    wait;
  end process;

  --
  --  Do some configuration
  --
  U_AxilSim : entity work.AxiLiteWriteMasterSim
    generic map ( CMDS => (0 => (addr=>x"86000000" , value=> x"00000000"), -- mode,source
                           1 => (addr=>x"86000004" , value=> x"00000004"), -- timeSlotF
                           2 => (addr=>x"86000008" , value=> x"00000000"), -- dest/trig0
                           3 => (addr=>x"8600000C" , value=> x"00060006"), -- dest/trig1
                           4 => (addr=>x"86000010" , value=> x"000C000C"), -- dest/trig2
                           5 => (addr=>x"83000000" , value=> x"80010000"), -- app
                           6 => (addr=>x"83000004" , value=> x"00000010"), -- delay
                           7 => (addr=>x"83000008" , value=> x"00000010")  -- width
                           ) )
    port map ( clk    => axilClk,
               rst    => axilRst,
               master => axilWriteMaster,
               slave  => axilWriteSlave,
               done   => open );
  
   U_UsSim : entity lcls_timing_core.TPGMini
     generic map ( NARRAYSBSA => 0,
                   STREAM_INTF => false )
     port map ( statusO   => open,
                configI   => tpgConfig,
                --
                txClk     => recTimingClk,
                txRst     => recTimingRst,
                txRdy     => '1',
                txData    => txData,
                txDataK   => txDataK );

  U_UsCore : entity lcls_timing_core.TimingCore
    generic map ( TPD_G => TPD_G,
                  CLKSEL_MODE_G => "LCLSII" )
    port map (
      gtTxUsrClk       => timingClk,
      gtTxUsrRst       => timingRst,

      gtRxRecClk       => recTimingClk,
      gtRxData         => txData,
      gtRxDataK        => txDataK,
      gtRxDispErr      => "00",
      gtRxDecErr       => "00",
      gtRxControl      => open,
      gtRxStatus       => TIMING_PHY_STATUS_FORCE_C,
      gtTxReset        => open,
      gtLoopback       => open,
      tpgMiniTimingPhy => open,
      timingClkSel     => open,
      -- Decoded timing message interface
      appTimingClk     => recTimingClk,
      appTimingRst     => recTimingRst,
      appTimingBus     => timingBus,
      appTimingMode    => open,
      -- AXI Lite interface
      axilClk          => axilClk,
      axilRst          => axilRst,
      axilReadMaster   => AXI_LITE_READ_MASTER_INIT_C,
      axilReadSlave    => open,
      axilWriteMaster  => AXI_LITE_WRITE_MASTER_INIT_C,
      axilWriteSlave   => open
      );

  --
  --  Generate timingTrig
  --  Insert ACRates into timingBus
  --
  U_ACCEL : entity lcls_timing_core.EvrV2Trigger
    port map (
      clk        => recTimingClk,
      rst        => recTimingRst,
      config     => accelConfig,
      arm (0)    => r.accelTrig,
      fire       => r.timingTrig.trigPulse(7),
      trigstate  => accelTrig );

  U_STDBBY : entity lcls_timing_core.EvrV2Trigger
    port map (
      clk        => recTimingClk,
      rst        => recTimingRst,
      config     => stdbyConfig,
      arm (0)    => r.stdbyTrig,
      fire       => r.timingTrig.trigPulse(7),
      trigstate  => stdbyTrig );

  comb : process (r, recTimingRst, timingBus, accelTrig, stdbyTrig) is
    variable v : RegType;
  begin
    v := r;

    v.timingBus.strobe := '0';
    v.accelTrig        := '0';
    v.stdbyTrig        := '0';

    v.timingTrig.trigPulse := (others=>'0');
    v.timingTrig.trigPulse(0) := accelTrig;
    v.timingTrig.trigPulse(1) := stdbyTrig;
    
    if timingBus.strobe = '1' then
      v.timingBus := timingBus;
      v.timingBus.message.acTimeSlot := r.timingBus.message.acTimeSlot;

      -- offset the timeslots every 1024 frames
      if ((timingBus.message.pulseId(10)='0' and timingBus.message.pulseId(4 downto 0)=toSlv(10,5)) or
          (timingBus.message.pulseId(10)='1' and timingBus.message.pulseId(4 downto 0)=toSlv(40,5))) then
        v.timingBus.message.acRates(0) := '1';
        -- reset the timeslot every 1024 frames
        if (r.timingBus.message.acTimeSlot = toSlv(6,3) or
            timingBus.message.pulseId(9 downto 5) = toSlv(0,5))then
          v.timingBus.message.acTimeSlot := toSlv(1,3);
        else
          v.timingBus.message.acTimeSlot := r.timingBus.message.acTimeSlot+1;
        end if;
      end if;

      v.timingTrig.timeStamp := timingBus.message.timeStamp;
      if r.timingBus.message.acRates/=0 then
        if r.timingBus.message.acTimeSlot = toSlv(1,6) then
          v.accelTrig := '1';
        end if;
        if (r.timingBus.message.acTimeSlot = toSlv(1,6) or 
            r.timingBus.message.acTimeSlot = toSlv(4,6)) then
          v.stdbyTrig := '1';
          v.timingTrig.trigPulse(7) := '1'; -- align
        end if;
      end if;
    end if;

    if recTimingRst = '1' then
      v := REG_INIT_C;
    end if;

    rin <= v;
    
    appTimingBus <= r.timingBus;
    timingTrig   <= r.timingTrig;
  end process comb;

  seq : process (recTimingClk) is
  begin
    if rising_edge(recTimingClk) then
      r <= rin;
    end if;
  end process seq;
  
  U_BASE : entity xil_defaultlib.AppCoreSim
   generic map (
      TPD_G                 => TPD_G,
      --SIM_SPEEDUP_G         => SIM_SPEEDUP_G,
      SIMULATION_G          => true,
      RF_INTERLOCK_RTM_G    => false,
      JESD_USR_DIV_G        => 4 )
   port map (
      -- Clocks and resets
      jesdClk                => (others=>jesdClk),
      jesdRst                => (others=>jesdRst),
      jesdClk2x              => (others=>jesdClk2x),
      jesdRst2x              => (others=>jesdRst2x),
      jesdUsrClk             => (others=>jesdClk),
      jesdUsrRst             => (others=>jesdRst),
      appTimingClk           => open,
      appTimingRst           => open,
      -- DaqMux/Trig Interface (timingClk domain)
      freezeHw               => "00",
      timingTrig             => timingTrig,
      trigHw                 => open,
      trigCascBay            => "00",
      -- JESD SYNC Interface (jesdClk[1:0] domain)
      jesdSysRef             => open,
      jesdRxSync             => "00",
      jesdTxSync             => open,
      -- ADC/DAC/Debug Interface (jesdClk[1:0] domain)
      adcValids              => (others=>(others=>'1')),
      adcValues              => adcValues,
      dacValids              => open,
      dacValues              => open,
      debugValids            => open,
      debugValues            => open,
      -- DAC Signal Generator Interface
      -- If SIG_GEN_LANE_MODE_G = '0', (jesdClk[1:0] domain)
      -- If SIG_GEN_LANE_MODE_G = '1', (jesdClk2x[1:0] domain)
      dacSigCtrl             => open,
      dacSigStatus           => (others=>DAC_SIG_STATUS_INIT_C),
      dacSigValids           => (others=>(others=>'1')),
      dacSigValues           => adcValues,
      -- AXI-Lite Interface (axilClk domain) [0x8FFFFFFF:0x80000000]
      axilClk                => axilClk,
      axilRst                => axilRst,
      axilReadMaster         => AXI_LITE_READ_MASTER_INIT_C,
      axilReadSlave          => open,
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
      timingBus              => appTimingBus,
      timingPhy              => open,
      timingPhyClk           => timingClk,
      timingPhyRst           => timingRst,
      -- Diagnostic Interface (diagnosticClk domain)
      diagnosticClk          => open,
      diagnosticRst          => open,
      diagnosticBus          => open,
      -- Backplane Messaging Interface  (axilClk domain)
      obBpMsgClientMaster    => open,
      obBpMsgClientSlave     => AXI_STREAM_SLAVE_INIT_C,
      ibBpMsgClientMaster    => AXI_STREAM_MASTER_INIT_C,
      ibBpMsgClientSlave     => open,
      obBpMsgServerMaster    => open,
      obBpMsgServerSlave     => AXI_STREAM_SLAVE_INIT_C,
      ibBpMsgServerMaster    => AXI_STREAM_MASTER_INIT_C,
      ibBpMsgServerSlave     => open,
      -- Application Debug Interface (axilClk domain)
      obAppDebugMaster       => open,
      obAppDebugSlave        => AXI_STREAM_SLAVE_INIT_C,
      ibAppDebugMaster       => AXI_STREAM_MASTER_INIT_C,
      ibAppDebugSlave        => open,
      -- MPS Concentrator Interface (ref156MHzClk domain)
      mpsObMasters           => (others=>AXI_STREAM_MASTER_INIT_C),
      mpsObSlaves            => open,
      -- Misc. Interface
      ipmiBsi                => BSI_BUS_INIT_C,
      gthFabClk              => jesdClk,
      ethPhyReady            => '1',
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
      rtmHsRxP               => '0',
      rtmHsRxN               => '1',
      rtmHsTxP               => open,
      rtmHsTxN               => open,
      -- RTM's Clock Reference
      genClkP                => '0',
      genClkN                => '1' );

end top_level;
    
