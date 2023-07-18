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

library lcls_timing_core;
use lcls_timing_core.TimingPkg.all;

library unisim;
use unisim.vcomponents.all;

entity AppTimeSlot is
   generic (
     MODE_DEST_G      : string := "TRIGGER";
     --  "TRIGGER" : get destination from dest signal
     --  "MESSAGE" : get destination from message dest field
     --  "CONTROL" : get destination from message control0 field
     --  "NONE"    : no destination dependence
     DEST_CHAN_G      : NaturalArray := ( 0 => 0 )
      );
   port (
      -- Clocks and resets
      clk                 : in    sl;
      rst                 : in    sl;
      trig                : in    sl;
      dest                : in    slv(2 downto 0) := "000";
      message             : in    TimingMessageType;
      timeSlot            : out   slv(4 downto 0);
      timeStamp           : out   slv(63 downto 0) );
end AppTimeSlot;

architecture mapping of AppTimeSlot is

  type RegType is record
    timeSlot  : slv( 4 downto 0);
    timeStamp : slv(63 downto 0);
  end record;

  constant REG_INIT_C : RegType := (
    timeSlot  => (others=>'0'),
    timeStamp => (others=>'0') );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType;
  
begin

  comb : process ( rst, r, trig, dest, message ) is
    variable v : RegType;
  begin
    v := r;

    if trig = '1' then
      v.timeStamp := message.timestamp;

      if MODE_DEST_G = "CONTROL" then
        -- UED
        v.timeSlot  := message.control(0)(4 downto 0);
      elsif MODE_DEST_G = "MESSAGE" then
        v.timeSlot  := toSlv(DEST_CHAN_G(conv_integer(message.beamRequest(7 downto 4)))+
                             conv_integer(message.acTimeSlot),5);
      elsif MODE_DEST_G = "TRIGGER" then
        v.timeSlot  := toSlv(DEST_CHAN_G(conv_integer(dest))+
                             conv_integer(message.acTimeSlot),5);
      else
        -- LCLS-I/LCLS-II
        v.timeSlot  := "00" & message.acTimeSlot;
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
  
end mapping;
