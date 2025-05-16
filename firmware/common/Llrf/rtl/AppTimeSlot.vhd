-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Application timing latch
--
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
use surf.AxiLitePkg.all;

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AppTimeSlot is
   generic (
     MODE_DEST_G      : string := "TRIGGER";
     DEST_CHAN_G      : NaturalArray := (0, 6, 12)
     --  "TRIGGER" : get destination from dest signal
     --  "MESSAGE" : get destination from message dest field
     --  "CONTROL" : get destination from message control0 field
     --  "NONE"    : no destination dependence
      );
   port (
      -- Clocks and resets
      clk                 : in    sl;
      rst                 : in    sl;
      strobe              : in    sl;
      trig                : in    sl;
      dest                : in    slv(DEST_CHAN_G'range) := (others=>'0');
      message             : in    TimingMessageType;
      timeSlot            : out   slv(4 downto 0);
      timeStamp           : out   slv(63 downto 0);
      -- Axi-lite
      axiClk              : in    sl;
      axiRst              : in    sl;
      axiReadMaster       : in    AxiLiteReadMasterType;
      axiReadSlave        : out   AxiLiteReadSlaveType;
      axiWriteMaster      : in    AxiLiteWriteMasterType;
      axiWriteSlave       : out   AxiLiteWriteSlaveType );
end AppTimeSlot;

architecture mapping of AppTimeSlot is

  type ModeType is ( S_TRIGGER, S_MESSAGE, S_CONTROL );

  function toSlv(mode : ModeType) return slv is
    variable v : slv(3 downto 0);
  begin
    case mode is
      when S_TRIGGER  => v := x"0";
      when S_MESSAGE  => v := x"1";
      when S_CONTROL  => v := x"2";
    end case;
    return v;
  end function toSlv;

  function toMode(v : slv) return ModeType is
    variable mode : ModeType;
  begin
    case v is
      when x"2"   => mode := S_CONTROL;
      when x"1"   => mode := S_MESSAGE;
      when others => mode := S_TRIGGER;
    end case;
    return mode;
  end function toMode;

  function toMode(s : string) return ModeType is
    variable mode : ModeType;
  begin
    case s is
      when "TRIGGER" => mode := S_TRIGGER;
      when "MESSAGE" => mode := S_MESSAGE;
      when "CONTROL" => mode := S_CONTROL;
    end case;
    return mode;
  end function toMode;

  -- timeslot source: message.acTimeSlot or register setting
  type SourceType is ( V_MESSAGE, V_REG );
  
  function toSlv(source : SourceType) return slv is
    variable v : slv(0 downto 0);
  begin
    case source is
      when V_MESSAGE  => v := "0";
      when V_REG      => v := "1";
    end case;
    return v;
  end function toSlv;

  function toSource(v : slv) return SourceType is
    variable source : SourceType;
  begin
    case v is
      when "0" => source := V_MESSAGE;
      when "1" => source := V_REG;
    end case;
    return source;
  end function toSource;

  type RegType is record
    timeStamp : slv(63 downto 0);
    timeSlot  : slv( 4 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    timeStamp => (others=>'0'),
    timeSlot  => (others=>'0'));

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;

  type ConfigType is record
    mode       : ModeType;
    tsSource   : SourceType;
    timeSlotF  : slv(4 downto 0);
    destChan   : Slv5Array(DEST_CHAN_G'range);
    trigChan   : Slv5Array(DEST_CHAN_G'range);
  end record;

  function toSlv5Array(a : NaturalArray) return Slv5Array is
    variable v : Slv5Array(a'range);
    variable i : integer;
  begin
    for i in a'range loop
      v(i) := toSlv(a(i),5);
    end loop;
    return v;
  end function toSlv5Array;
  
  constant CONFIG_INIT_C : ConfigType := (
    mode       => toMode(MODE_DEST_G),
    tsSource   => V_MESSAGE,
    timeSlotF  => toSlv(0,5),
    destChan   => toSlv5Array(DEST_CHAN_G),
    trigChan   => toSlv5Array(DEST_CHAN_G) );

  constant CONFIG_BITS_C : natural := 10 + 10*DEST_CHAN_G'length;
  
  function toSlv(config : ConfigType) return slv is
    variable v : slv(CONFIG_BITS_C-1 downto 0);
    variable i : integer := 0;
  begin
    assignSlv(i, v, toSlv(config.mode));
    assignSlv(i, v, toSlv(config.tsSource));
    assignSlv(i, v, config.timeSlotF);
    for j in DEST_CHAN_G'range loop
      assignSlv(i, v, config.destChan(j));
      assignSlv(i, v, config.trigChan(j));
    end loop;
    return v;
  end function toSlv;

  function toConfig(v : slv) return ConfigType is
    variable config : ConfigType;
    variable vmode  : slv(3 downto 0);
    variable vsrc   : slv(0 downto 0);
    variable i : integer := 0;
  begin
    assignRecord(i, v, vmode);
    config.mode := toMode(vmode);
    assignRecord(i, v, vsrc);
    config.tsSource := toSource(vsrc);
    assignRecord(i, v, config.timeSlotF);
    for j in DEST_CHAN_G'range loop
      assignRecord(i, v, config.destChan(j));
      assignRecord(i, v, config.trigChan(j));
    end loop;
    return config;
  end function toConfig;

  type AxilRegType is record
    config     : ConfigType;
    axiWriteS  : AxiLiteWriteSlaveType;
    axiReadS   : AxiLiteReadSlaveType;
  end record;

  constant AXIL_REG_INIT_C : AxilRegType := (
    config     => CONFIG_INIT_C,
    axiWriteS  => AXI_LITE_WRITE_SLAVE_INIT_C,
    axiReadS   => AXI_LITE_READ_SLAVE_INIT_C );

  signal c     : AxilRegType := AXIL_REG_INIT_C;
  signal cin   : AxilRegType;

  signal configSV, configV : slv(CONFIG_BITS_C-1 downto 0);
  signal configS           : ConfigType;

begin

  assert (MODE_DEST_G = "CONTROL" or MODE_DEST_G = "MESSAGE" or
          MODE_DEST_G = "TRIGGER")
    report "AppTimeSlot: MODE_DEST_G must be CONTROL,MESSAGE, or TRIGGER" severity failure;
  
  comb : process ( rst, r, configS, trig, dest, message ) is
    variable v : RegType;
    variable i : integer;
  begin
    v := r;

    -- always latch the timestamp at the time of strobe
    if strobe = '1' then
      v.timeStamp  := message.timestamp;
    end if;

    if strobe = '1' then
      if configS.tsSource = V_MESSAGE then
        v.timeSlot := "00" & message.acTimeSlot;
      else
        v.timeSlot := configS.timeSlotF;
      end if;
    end if;
    
    -- latch the timeslot at the time of strobe
    if (strobe = '1'   and configS.mode = S_CONTROL) then
      v.timeSlot  := message.control(0)(4 downto 0);
    end if;
      
    if (strobe = '1'   and configS.mode = S_MESSAGE) then
      i := conv_integer(message.beamRequest(7 downto 4));
      if i < DEST_CHAN_G'length then
        v.timeSlot  := v.timeSlot + configS.destChan(i);
      end if;
    end if;

    if configS.mode = S_TRIGGER then
      if trig = '1' then
        for i in DEST_CHAN_G'range loop
          if dest(i) = '1' then
            v.timeSlot  := r.timeSlot + configS.trigChan(i);
          end if;               
        end loop;
      end if;
    end if;

    if rst = '1' then
      v := REG_INIT_C;
    end if;

    r_in <= v;

    timeSlot  <= r.timeSlot;
    timeStamp <= r.timeStamp;
  end process comb;

  seq : process ( clk) is
  begin
    if rising_edge(clk) then
      r <= r_in;
    end if;
  end process seq;

   reg_comb: process(c, axiRst, axiReadMaster, axiWriteMaster) is
     variable v   : AxilRegType;
     variable ep  : AxiLiteEndPointType;
     variable vmode : slv(3 downto 0);
     variable vts   : slv(0 downto 0);
   begin
     v := c;

     -- Start transaction block
     axiSlaveWaitTxn(ep, axiWriteMaster, axiReadMaster, v.axiWriteS, v.axiReadS);

     vmode := toSlv(c.config.mode);
     axiSlaveRegister(ep, x"000", 0, vmode);
     v.config.mode := toMode(vmode);
     vts := toSlv(c.config.tsSource);
     axiSlaveRegister(ep, x"000", 8, vts);
     v.config.tsSource := toSource(vts);
     axiSlaveRegister(ep, x"004", 0, v.config.timeSlotF);

     for i in DEST_CHAN_G'range loop
       axiSlaveRegister(ep, toSlv(4*i+8,12), 0, v.config.destChan(i));
       axiSlaveRegister(ep, toSlv(4*i+8,12),16, v.config.trigChan(i));
     end loop;
     
     axiSlaveDefault (ep, v.axiWriteS, v.axiReadS);

     if axiRst = '1' then
       v := AXIL_REG_INIT_C;
     end if;

     cin <= v;

     axiReadSlave  <= c.axiReadS;
     axiWriteSlave <= c.axiWriteS;
   end process;

   reg_seq: process(axiClk) is
   begin
     if rising_edge(axiClk) then
       c <= cin;
     end if;
   end process;

   configV <= toSlv(c.config);
  
   U_SyncMode : entity surf.SynchronizerVector
     generic map ( WIDTH_G => configV'length )
     port map ( clk     => clk,
                dataIn  => configV,
                dataOut => configSV );

   configS <= toConfig( configSV );

end mapping;
