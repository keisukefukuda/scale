#!/bin/bash

cat << EOF > conf/param.bucket.conf

#################################################
#
# model configuration: land parameter (bucket)
#
#################################################

&PARAM_LAND_DATA
 index       = 1,
 description = "bare ground",
 STRGMAX     =  0.20D0,
 STRGCRT     =  0.15D0,
 TCS         =  0.25D0,
 HCS         =  1.30D+6,
 DFW         =  3.38D-6,
 Z0M         =  0.01D0,
/

&PARAM_LAND_DATA
 index       = 2,
 description = "grassland",
 STRGMAX     =  0.20D0,
 STRGCRT     =  0.10D0,
 TCS         =  0.25D0,
 HCS         =  1.30D+6,
 DFW         =  3.38D-6,
 Z0M         =  0.10D0,
/

&PARAM_LAND_DATA
 index       = 3,
 description = "deciduous forest",
 STRGMAX     =  0.20D0,
 STRGCRT     =  0.05D0,
 TCS         =  0.25D0,
 HCS         =  1.30D+6,
 DFW         =  3.38D-6,
 Z0M         =  0.30D0,
/

&PARAM_LAND_DATA
 index       = 4,
 description = "paddy",
 STRGMAX     =  0.30D0,
 STRGCRT     =  0.03D0,
 TCS         =  0.25D0,
 HCS         =  2.00D+6,
 DFW         =  3.38D-6,
 Z0M         =  0.01D0,
/
EOF
