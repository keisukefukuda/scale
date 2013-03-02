#! /bin/bash -x

# Arguments
BINDIR=${1}
INITNAME=${2}
BINNAME=${3}
INITCONF=${4}
RUNCONF=${5}
TPROC=${6}

# System specific
MPIEXEC="mpiexec"

# Generate run.sh

cat << EOF1 > ./run.sh
#! /bin/bash -x
################################################################################
#
# for OAKLEAF-FX
#
################################################################################
#PJM --rsc-list "rscgrp=short"
#PJM --rsc-list "node=${TPROC}"
#PJM --rsc-list "elapse=00:30:00"
#PJM -j
#PJM -s
export PARALLEL=8
export OMP_NUM_THREADS=8

ln -sv ${BINDIR}/${INITNAME} .
ln -sv ${BINDIR}/${BINNAME}  .

fprof="fipp -C -Srange -Ihwm -d prof"
rm -rf ./prof

# run
          ${MPIEXEC} ./${INITNAME} ${INITCONF} || exit
\${fprof} ${MPIEXEC} ./${BINNAME}  ${RUNCONF}  || exit

################################################################################
EOF1
