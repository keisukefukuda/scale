!-------------------------------------------------------------------------------
!> Program make tool for initial states for SCALE-LES
!!
!! @par Description
!!          SCALE: Scalable Computing by Advanced Library and Environment
!!          Numerical model for LES-scale weather
!!
!! @author Team SCALE
!!
!! @par History
!! @li      2012-04-08 (H.Yashiro)  [mod] merge all init programs
!! @li      2012-06-13 (Y.Sato)     [mod] add HBINW option
!!
!<
!-------------------------------------------------------------------------------
program scaleles_init
  !-----------------------------------------------------------------------------
  !
  !++ used modules
  !
  use mod_stdio, only: &
     IO_setup,   &
     IO_FID_CONF, &
     IO_FID_LOG, &
     IO_L
  use mod_process, only: &
     PRC_setup,    &
     PRC_MPIstart, &
     PRC_MPIstop,  &
     PRC_MPIfinish
  use mod_const, only: &
     CONST_setup
  use mod_random, only: &
     RANDOM_setup
  use mod_time, only: &
     TIME_setup,    &
     TIME_rapstart, &
     TIME_rapend,   &
     TIME_rapreport
  use mod_grid, only: &
     GRID_setup
  use mod_tracer, only: &
     TRACER_setup
  use mod_fileio, only: &
     FILEIO_setup
  use mod_comm, only: &
     COMM_setup
  use mod_topography, only: &
     TOPO_setup
  use mod_landuse, only: &
     LANDUSE_setup
  use mod_grid_real, only: &
     REAL_setup
  use mod_gridtrans, only: &
     GTRANS_setup
  use mod_interpolation, only: &
     INTERP_setup
  use mod_stats, only: &
     STAT_setup
  use mod_history, only: &
     HIST_setup
  use mod_atmos_hydrostatic, only: &
     ATMOS_HYDROSTATIC_setup
  use mod_atmos_thermodyn, only: &
     ATMOS_THERMODYN_setup
  use mod_atmos_saturation, only: &
     ATMOS_SATURATION_setup
  use mod_atmos_vars, only: &
     ATMOS_vars_setup
  use mod_mktopo, only: &
     MKTOPO_setup, &
     MKTOPO
  use mod_mkinit, only: &
     MKINIT_setup, &
     MKINIT
  use dc_log, only: &
     LogInit
  use gtool_file, only: &
     FileCloseAll
  !-----------------------------------------------------------------------------
  implicit none
  !-----------------------------------------------------------------------------
  !
  !++ parameters & variables
  !
  !=============================================================================

  !########## Initial setup ##########

  ! setup standard I/O
  call IO_setup

  ! start MPI
  call PRC_MPIstart

  ! setup process
  call PRC_setup

  ! setup Log
  call LogInit(IO_FID_CONF, IO_FID_LOG, IO_L)

  ! setup constants
  call CONST_setup

  ! setup random number
  call RANDOM_setup

  ! setup time
  call TIME_setup( .true. )

  call TIME_rapstart('Debug')
  call TIME_rapend  ('Debug')
  call TIME_rapstart('Initialize')

  ! setup horisontal/veritical grid system
  call GRID_setup

  ! setup tracer
  call TRACER_setup

  ! setup file I/O
  call FILEIO_setup

  ! setup mpi communication
  call COMM_setup

  ! setup topography
  call TOPO_setup
  ! setup land use category index/fraction
  call LANDUSE_setup
  ! setup coordinate in real world
  call REAL_setup

  ! setup grid transfer metrics (uses in ATMOS_dynamics)
  call GTRANS_setup
  ! setup Z-ZS interpolation factor (uses in History)
  call INTERP_setup

  ! setup statistics
  call STAT_setup
  ! setup history I/O
  call HIST_setup

  ! setup atmos
  call ATMOS_HYDROSTATIC_setup
  call ATMOS_THERMODYN_setup
  call ATMOS_SATURATION_setup
  call ATMOS_vars_setup

  ! setup mktopo
  call MKTOPO_setup

  ! setup mkinit
  call MKINIT_setup

  call TIME_rapend('Initialize')

  !########## main ##########

  call TIME_rapstart('Main')

  ! execute mktopo
  call TIME_rapstart('MkTopo')
  call MKTOPO
  call TIME_rapend  ('MkTopo')

  ! re-setup
  call REAL_setup

  ! execute mkinit
  call TIME_rapstart('MkInit')
  call MKINIT
  call TIME_rapend  ('MkInit')

  call TIME_rapend('Main')

  !########## Finalize ##########

  call TIME_rapreport

  call FileCloseAll

  ! stop MPI
  call PRC_MPIfinish

  stop
  !=============================================================================
end program scaleles_init