#! /bin/bash -x
#
# for 3 team (NST) cluster
#
#BSUB -q bm
#BSUB -n 16
#BSUB -J scale3
#BSUB -o scale3_log
#BSUB -e scale3_error

export OMP_NUM_THREADS=1

export HMDIR=/home/yashiro/scale3
export BIN=${HMDIR}/bin/NST-ifort
export EXE=scale3

export OUTDIR=${HMDIR}/output/scale3_1x1

mkdir -p ${OUTDIR}
cd ${OUTDIR}

########################################################################
cat << End_of_SYSIN > ${OUTDIR}/${EXE}.cnf

#####
#
# Scale3 benchmark configuration
#
#####

&PARAM_PRC
 PRC_NUM_X       = 4,
 PRC_NUM_Y       = 4,
 PRC_PERIODIC_X  = .true.,
 PRC_PERIODIC_Y  = .true.,
/

&PARAM_TIME
 TIME_STARTDATE             = 2000, 1, 1, 0, 0, 0,
 TIME_STARTMS               = 0.D0,
 TIME_DURATION              = 3.0D0,
 TIME_DURATION_UNIT         = "SEC",
 TIME_DT                    = 0.6D0,
 TIME_DT_UNIT               = "SEC",
 TIME_DT_ATMOS_DYN          = 0.03D0,
 TIME_DT_ATMOS_DYN_UNIT     = "SEC",
 TIME_NSTEP_ATMOS_DYN       = 20,
 TIME_DT_ATMOS_PHY_MP       = 0.6D0,
 TIME_DT_ATMOS_PHY_MP_UNIT  = "SEC",
 TIME_DT_ATMOS_RESTART      = 3.0D0,
 TIME_DT_ATMOS_RESTART_UNIT = "SEC",
/

&PARAM_GRID
 GRID_OUT_BASENAME = '',
 GRID_DXYZ         = 20.D0,
 GRID_KMAX         = 336,
 GRID_IMAX         = 63,
 GRID_JMAX         = 63,
 GRID_BUFFER_DZ    = 6.0D3,
 GRID_BUFFFACT     = 1.1D0,
/

&PARAM_ATMOS
 ATMOS_TYPE_DYN    = "fent_fct",
 ATMOS_TYPE_PHY_TB = "smagorinsky",
 ATMOS_TYPE_PHY_MP = "NDW6",
 ATMOS_TYPE_PHY_RD = "mstrnX",
/

&PARAM_ATMOS_VARS
 ATMOS_QTRC_NMAX              = 11,
 ATMOS_RESTART_IN_BASENAME    = "${HMDIR}/output/init_coldbubble/init_coldbubble_63072000000.000",
 ATMOS_RESTART_OUTPUT         = .true.,
 ATMOS_RESTART_OUT_BASENAME   = "check_coldbubble",
 ATMOS_RESTART_CHECK          = .false.,
 ATMOS_RESTART_CHECK_BASENAME = "${HMDIR}/data/coldbubble/check_coldbubble_63072000000.600",
/

&PARAM_ATMOS_REFSTATE
 ATMOS_REFSTATE_TYPE         = "UNIFORM",
 ATMOS_REFSTATE_POTT_UNIFORM = 300.D0
/

&PARAM_ATMOS_BOUNDARY
 ATMOS_BOUNDARY_OUT_BASENAME = "boundary",
 ATMOS_BOUNDARY_VALUE_VELX   =  0.D0,
 ATMOS_BOUNDARY_TAUZ         =  1.D0,
/

&PARAM_ATMOS_DYN
 ATMOS_DYN_NUMERICAL_DIFF = 1.D-3,
/

&PARAM_OCEAN
 OCEAN_TYPE = "FIXEDSST",
/

&PARAM_HISTORY
 HISTORY_OUT_BASENAME      = "history",
 HISTORY_DEFAULT_TINTERVAL = 3.0D0,
 HISTORY_DEFAULT_TUNIT     = "SEC",
 HISTORY_DEFAULT_AVERAGE   = .false.,
 HISTORY_DATATYPE          = "REAL4",
/

&HISTITEM item='DENS' /
#&HISTITEM item='MOMX' /
#&HISTITEM item='MOMY' /
#&HISTITEM item='MOMZ' /
#&HISTITEM item='RHOT' /
#&HISTITEM item='PRES' /
#&HISTITEM item='T'    /
&HISTITEM item='U'    /
&HISTITEM item='V'    /
&HISTITEM item='W'    /
&HISTITEM item='PT'   /

#&HISTITEM item='QV'   /
#&HISTITEM item='QC'   /
#&HISTITEM item='QR'   /
#&HISTITEM item='QI'   /
#&HISTITEM item='QS'   /
#&HISTITEM item='QG'   /
#&HISTITEM item='NC'   /
#&HISTITEM item='NR'   /
#&HISTITEM item='NI'   /
#&HISTITEM item='NS'   /
#&HISTITEM item='NG'   /

End_of_SYSIN
########################################################################

# run
echo "job ${RUNNAME} started at " `date`
mpijob $BIN/$EXE ${EXE}.cnf
echo "job ${RUNNAME} end     at " `date`

exit
