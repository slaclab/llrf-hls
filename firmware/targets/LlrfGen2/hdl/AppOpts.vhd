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

  constant APP_TIMING_MODE_C : integer := 1; -- (1=NC, 2=SC, 3=NC from SC)
  constant UPCONVERT_V2_C    : boolean := true;
  --  Timeslot mapping
  constant MODE_1080HZ_C     : boolean := false;
  constant MODE_DEST_C       : boolean := true;
  -- HXR(3) => 1-6, SXR(4) => 7-12, DUMPBSY(2) => 13-18 
  constant DEST_CHAN_C       : NaturalArray := ( 0, 0, 12, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 );
end AppOpts;
