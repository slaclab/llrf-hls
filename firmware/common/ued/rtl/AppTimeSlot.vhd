-----------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 Timing Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'LCLS2 Timing Core', including this file,
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

entity AppTimeSlot is

   generic ( NUM_TRIG_PULSE_G  : integer := 5 );
   port (
      -- Timing data interface
      clk         : in  sl;
      rst         : in  sl;
      trig        : in  TimingTrigType;
      message     : in  TimingMessageType;
      pulse       : in  slv(NUM_TRIG_PULSE_G-1 downto 0);
      timeStamp   : out slv(63 downto 0);
      timeSlot    : out slv( 4 downto 0) );

end entity AppTimeSlot;

architecture rtl of AppTimeSlot is
    signal latchOneShot     : sl := '0'; 
begin
    U_LATCH_OS : entity surf.SynchronizerOneShot
      generic map (
         TPD_G         => TPD_G,
         BYPASS_SYNC_G => true)
      port map (
         clk     => clk,
         dataIn  => pulse(5),
         dataOut => latchOneShot);

   U_LATCH_TIMING : entity surf.RegisterVector
      generic map (
         TPD_G    => TPD_G,
         WIDTH_G  => 70)
      port map (
         clk                 => clk,
         en                  => latchOneShot,
         sig_i(63 downto 0)  => message.timeStamp,
         sig_i(69 downto 64) => message.control(0)(5 downto 0),
         reg_o(63 downto 0)  => timeStamp,
         reg_o(69 downto 64) => timeSlot);

end rtl;
