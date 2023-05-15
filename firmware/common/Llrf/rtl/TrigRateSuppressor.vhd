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

library xil_defaultlib;

entity TrigRateSuppressor is
     generic (
       TPD_G          : time      := 1 ns;
       POLARITY_G     : sl        := '1';
       MIN_INTERVAL_G : natural );
     port (
       clk            : in  sl;
       rst            : in  sl;
       trig_i         : in  sl;
       trig_o         : out sl );
end TrigRateSuppressor;

architecture mapping of TrigRateSuppressor is

  constant COUNT_BITS_C : natural := bitSize(MIN_INTERVAL_G);
  
  type StateType is ( RISE_S, FALL_S, WAIT_S );
  type RegType is record
    state : StateType;
    count : slv(COUNT_BITS_C-1 downto 0);
    trig  : sl;
  end record;

  constant REG_INIT_C : RegType := (
    state => RISE_S,
    count => (others=>'0'),
    trig  => '0' );

  signal r    : RegType := REG_INIT_C;
  signal r_in : RegType; 
   
begin

  trig_o <= r.trig;
  
  comb: process (r, rst, trig_i) is
    variable v : RegType;
    variable ready : sl;
  begin
    v := r;

    ready := '0';
    if r.count = MIN_INTERVAL_G then
      ready := '1';
    else
      v.count := r.count+1;
    end if;
    
    
    case r.state is
      when RISE_S =>
        if trig_i = POLARITY_G then
          v.trig  := POLARITY_G;
          v.count := (others=>'0');
          v.state := FALL_S;
        end if;
      when FALL_S =>
        if trig_i = not POLARITY_G then
          v.trig  := not POLARITY_G;
          v.state := WAIT_S;
        end if;
      when WAIT_S =>
        if ready = '1' then
          v.state := RISE_S;
        end if;
    end case;

    if rst = '1' then
      v := REG_INIT_C;
    end if;

    r_in <= v;
  end process comb;

  seq : process ( clk ) is
  begin
    if rising_edge(clk) then
      r <= r_in;
    end if;
  end process seq;
  
end mapping;
