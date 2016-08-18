#!/bin/bash

cat << EOF > base.run.conf

#################################################
#
# model configuration: run.conf only
#
#################################################

&PARAM_PROF
 PROF_mpi_barrier = .true.,
/

&PARAM_IO
 IO_LOG_BASENAME = "${RUN_IO_LOG_BASENAME}",
/

&PARAM_TIME
 TIME_STARTDATE             = ${TIME_STARTDATE},
 TIME_STARTMS               = ${TIME_STARTMS},
 TIME_DURATION              = ${TIME_DURATION},
 TIME_DURATION_UNIT         = "${TIME_UNIT}",
 TIME_DT                    = ${TIME_DT[$D]},
 TIME_DT_UNIT               = "${TIME_UNIT}",
 TIME_DT_ATMOS_DYN          = ${TIME_DT_ATMOS_DYN[$D]},
 TIME_DT_ATMOS_DYN_UNIT     = "${TIME_UNIT}",
 TIME_DT_ATMOS_PHY_MP       = ${TIME_DT_ATMOS_PHY_MP[$D]},
 TIME_DT_ATMOS_PHY_MP_UNIT  = "${TIME_UNIT}",
 TIME_DT_ATMOS_PHY_RD       = ${TIME_DT_ATMOS_PHY_RD[$D]},
 TIME_DT_ATMOS_PHY_RD_UNIT  = "${TIME_UNIT}",
 TIME_DT_ATMOS_PHY_SF       = ${TIME_DT_ATMOS_PHY_SF[$D]},
 TIME_DT_ATMOS_PHY_SF_UNIT  = "${TIME_UNIT}",
 TIME_DT_ATMOS_PHY_TB       = ${TIME_DT_ATMOS_PHY_TB[$D]},
 TIME_DT_ATMOS_PHY_TB_UNIT  = "${TIME_UNIT}",
 TIME_DT_OCEAN              = ${TIME_DT_OCEAN[$D]},
 TIME_DT_OCEAN_UNIT         = "${TIME_UNIT}",
 TIME_DT_LAND               = ${TIME_DT_LAND[$D]},
 TIME_DT_LAND_UNIT          = "${TIME_UNIT}",
 TIME_DT_URBAN              = ${TIME_DT_URBAN[$D]},
 TIME_DT_URBAN_UNIT         = "${TIME_UNIT}",
/

&PARAM_NEST
 USE_NESTING              = ${RUN_USE_NESTING},
 OFFLINE                  = .false.,
 ONLINE_DOMAIN_NUM        = ${DNUM},
 ONLINE_IAM_PARENT        = ${IAM_PARENT},
 ONLINE_IAM_DAUGHTER      = ${IAM_DAUGHTER},
 ONLINE_BOUNDARY_USE_QHYD = .true.,
 ONLINE_AGGRESSIVE_COMM   = .true.,
 ONLINE_SPECIFIED_MAXRQ   = 10000,
/

&PARAM_STATISTICS
 STATISTICS_checktotal     = .false.,
 STATISTICS_use_globalcomm = .false.,
/

&PARAM_RESTART
 RESTART_RUN          = ${RESTART_RUN},
 RESTART_OUTPUT       = .true.,
 RESTART_OUT_BASENAME = "${RESTART_OUT_BASENAME}",
 RESTART_IN_BASENAME  = "${RUN_RESTART_IN_BASENAME}",
/

&PARAM_TOPO
 TOPO_IN_BASENAME = "${RUN_TOPO_IN_BASENAME}",
/

&PARAM_LANDUSE
 LANDUSE_IN_BASENAME = "${RUN_LANDUSE_IN_BASENAME}",
/

&PARAM_LAND_PROPERTY
 LAND_PROPERTY_IN_FILENAME = "${RUN_LAND_PROPERTY_IN_FILENAME}",
/
EOF
