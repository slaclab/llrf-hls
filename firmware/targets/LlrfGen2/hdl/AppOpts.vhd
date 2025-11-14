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

library surf;
use surf.StdRtlPkg.all;

package AppOpts is

  constant APP_TIMING_MODE_C : integer := 2; -- 1 or 2 (LCLS-I/II)
  constant APP_CLKSEL_MODE_C : integer := 1; -- 1 or 2 (LCLS-I/II)
  constant APP_CLKSEL_STR_C  : string  := "LCLSIIPIC";
  constant UPCONVERT_V2_C    : boolean := true;
  constant USE_PROBE_CAL_C   : boolean := true;
  constant USE_BSVC_C        : boolean := false;
  
end AppOpts;
