!-------------------------------------------------------------------------------
!> module SCALE-RM (a main routine of regional model)
!!
!! @par Description
!!          SCALE: Scalable Computing by Advanced Library and Environment
!!          Limited area model for regional weather, regional climate, and large-Eddy Simulation (LES)
!!
!! @author Team SCALE
!!
!! @par History
!! @li      2014-12-12 (R.Yoshida)  [mod] from program of scalerm
!!
!<
!-------------------------------------------------------------------------------
module mod_rm_driver
  !-----------------------------------------------------------------------------
  !
  !++ used modules
  !
  use scale_precision
  use scale_stdio
  use scale_prof
  !-----------------------------------------------------------------------------
  implicit none
  private
  !-----------------------------------------------------------------------------
  !
  !++ included parameters
  !
#include "scale-rm.h"
  !-----------------------------------------------------------------------------
  !
  !++ Public procedure
  !
  public :: scalerm

  !-----------------------------------------------------------------------------
  !
  !++ Public parameters & variables
  !
  !-----------------------------------------------------------------------------
  !
  !++ Private procedure
  !
  !-----------------------------------------------------------------------------
  !
  !++ Private parameters & variables
  !
  character(len=H_MID), private, parameter :: MODELNAME = "SCALE-RM ver. "//VERSION

  !-----------------------------------------------------------------------------
contains
  !-----------------------------------------------------------------------------
  !> Setup
  subroutine scalerm( &
       comm_world,       &
       intercomm_parent, &
       intercomm_child,  &
       cnf_fname         )
    use scale_file, only: &
       FILE_Close_All
    use scale_process, only: &
       PRC_LOCAL_setup
    use scale_rm_process, only: &
       PRC_setup
    use scale_const, only: &
       CONST_setup
    use scale_calendar, only: &
       CALENDAR_setup
    use scale_random, only: &
       RANDOM_setup
    use scale_atmos_grid_cartesC_index, only: &
       ATMOS_GRID_CARTESC_INDEX_setup
    use scale_atmos_grid_cartesC, only: &
       ATMOS_GRID_CARTESC_setup, &
       DX, &
       DY
    use scale_comm_cartesC_nest, only: &
       COMM_CARTESC_NEST_setup
    use scale_ocean_grid_cartesC_index, only: &
       OCEAN_GRID_CARTESC_INDEX_setup
    use scale_ocean_grid_cartesC, only: &
       OCEAN_GRID_CARTESC_setup
    use scale_land_grid_cartesC_index, only: &
       LAND_GRID_CARTESC_INDEX_setup
    use scale_land_grid_cartesC, only: &
       LAND_GRID_CARTESC_setup
    use scale_urban_grid_cartesC_index, only: &
       URBAN_GRID_CARTESC_INDEX_setup
    use scale_urban_grid_cartesC, only: &
       URBAN_GRID_CARTESC_setup
    use scale_file_cartesC, only: &
       FILE_CARTESC_setup, &
       FILE_CARTESC_cleanup
    use scale_comm, only: &
       COMM_setup , &
       COMM_cleanup
    use scale_topography, only: &
       TOPO_setup
    use scale_landuse, only: &
       LANDUSE_setup
    use scale_atmos_grid_cartesC_real, only: &
       ATMOS_GRID_CARTESC_REAL_setup
    use scale_gridtrans, only: &
       GTRANS_setup
    use scale_rm_statistics, only: &
       STAT_setup
    use scale_time, only: &
       TIME_NOWDATE, &
       TIME_NOWMS,   &
       TIME_NOWSTEP
    use scale_file_history, only: &
       FILE_HISTORY_write, &
       FILE_HISTORY_set_nowdate, &
       FILE_HISTORY_finalize
    use scale_file_history_cartesC, only: &
       FILE_HISTORY_CARTESC_setup
    use scale_monitor, only: &
       MONIT_setup, &
       MONIT_write, &
       MONIT_finalize
    use scale_file_external_input_cartesC, only: &
       FILE_EXTERNAL_INPUT_CARTESC_setup
    use scale_atmos_hydrostatic, only: &
       ATMOS_HYDROSTATIC_setup
    use scale_atmos_thermodyn, only: &
       ATMOS_THERMODYN_setup
    use scale_atmos_hydrometeor, only: &
       ATMOS_HYDROMETEOR_setup
    use scale_atmos_saturation, only: &
       ATMOS_SATURATION_setup
    use scale_bulkflux, only: &
       BULKFLUX_setup
    use scale_roughness, only: &
       ROUGHNESS_setup
    use mod_atmos_driver, only: &
       ATMOS_driver_config
    use mod_admin_restart, only: &
       ADMIN_restart_setup, &
       ADMIN_restart_write
    use mod_admin_time, only: &
       ADMIN_TIME_setup,      &
       ADMIN_TIME_checkstate, &
       ADMIN_TIME_advance,    &
       TIME_DOATMOS_step,     &
       TIME_DOLAND_step,      &
       TIME_DOURBAN_step,     &
       TIME_DOOCEAN_step,     &
       TIME_DOresume,         &
       TIME_DOend
    use mod_atmos_admin, only: &
       ATMOS_admin_setup, &
       ATMOS_do
    use mod_atmos_vars, only: &
       ATMOS_vars_setup,                         &
       ATMOS_sw_check => ATMOS_RESTART_CHECK,    &
       ATMOS_vars_restart_check
    use mod_atmos_driver, only: &
       ATMOS_driver_setup,    &
       ATMOS_driver,           &
       ATMOS_driver_finalize
    use mod_ocean_admin, only: &
       OCEAN_admin_setup, &
       OCEAN_do
    use mod_ocean_vars, only: &
       OCEAN_vars_setup
    use mod_ocean_driver, only: &
       OCEAN_driver_setup, &
       OCEAN_driver
    use mod_land_admin, only: &
       LAND_admin_setup, &
       LAND_do
    use mod_land_vars, only: &
       LAND_vars_setup
    use mod_land_driver, only: &
       LAND_driver_setup, &
       LAND_driver
    use mod_urban_admin, only: &
       URBAN_admin_setup, &
       URBAN_do
    use mod_urban_vars, only: &
       URBAN_vars_setup
    use mod_urban_driver, only: &
       URBAN_driver_setup, &
       URBAN_driver
    use mod_cpl_admin, only: &
       CPL_admin_setup
    use mod_cpl_vars, only: &
       CPL_vars_setup
    use mod_user, only: &
       USER_config, &
       USER_setup, &
       USER_step
    implicit none

    integer,          intent(in) :: comm_world
    integer,          intent(in) :: intercomm_parent
    integer,          intent(in) :: intercomm_child
    character(len=*), intent(in) :: cnf_fname

    integer :: myrank
    logical :: ismaster
    !---------------------------------------------------------------------------

    !########## Initial setup ##########

    ! setup standard I/O
    call IO_setup( MODELNAME, cnf_fname )

    ! setup MPI
    call PRC_LOCAL_setup( comm_world, & ! [IN]
                          myrank,     & ! [OUT]
                          ismaster    ) ! [OUT]

    ! setup Log
    call IO_LOG_setup( myrank, ismaster )

    ! setup process
    call PRC_setup

    ! setup PROF
    call PROF_setup


    ! profiler start
    call PROF_setprefx('INIT')
    call PROF_rapstart('Initialize', 0)


    ! setup constants
    call CONST_setup

    ! setup calendar
    call CALENDAR_setup

    ! setup random number
    call RANDOM_setup

    ! setup horizontal/vertical grid coordinates (cartesian,idealized)
    call ATMOS_GRID_CARTESC_INDEX_setup
    call ATMOS_GRID_CARTESC_setup

    call OCEAN_GRID_CARTESC_INDEX_setup
    call OCEAN_GRID_CARTESC_setup

    call LAND_GRID_CARTESC_INDEX_setup
    call LAND_GRID_CARTESC_setup

    call URBAN_GRID_CARTESC_INDEX_setup
    call URBAN_GRID_CARTESC_setup

    ! setup submodel administrator
    call ATMOS_admin_setup
    call OCEAN_admin_setup
    call LAND_admin_setup
    call URBAN_admin_setup
    call CPL_admin_setup

    ! setup tracer index
    call ATMOS_HYDROMETEOR_setup
    call ATMOS_driver_config
    call USER_config

    ! setup file I/O
    call FILE_CARTESC_setup

    ! setup mpi communication
    call COMM_setup

    ! setup topography
    call TOPO_setup
    ! setup land use category index/fraction
    call LANDUSE_setup
    ! setup grid coordinates (real world)
    call ATMOS_GRID_CARTESC_REAL_setup

    ! setup grid transfer metrics (uses in ATMOS_dynamics)
    call GTRANS_setup

    ! setup restart
    call ADMIN_restart_setup
    ! setup time
    call ADMIN_TIME_setup( setup_TimeIntegration = .true. )
    ! setup statistics
    call STAT_setup
    ! setup history I/O
    call FILE_HISTORY_CARTESC_setup
    ! setup monitor I/O
    call MONIT_setup
    ! setup external in
    call FILE_EXTERNAL_INPUT_CARTESC_setup

    ! setup nesting grid
    call COMM_CARTESC_NEST_setup ( intercomm_parent, intercomm_child )

    ! setup common tools
    call ATMOS_HYDROSTATIC_setup
    call ATMOS_THERMODYN_setup
    call ATMOS_SATURATION_setup

    call BULKFLUX_setup( sqrt(DX**2+DY**2) )
    call ROUGHNESS_setup

    ! setup variable container
    call ATMOS_vars_setup
    call OCEAN_vars_setup
    call LAND_vars_setup
    call URBAN_vars_setup
    call CPL_vars_setup

    ! setup submodel driver
    call ATMOS_driver_setup
    call OCEAN_driver_setup
    call LAND_driver_setup
    call URBAN_driver_setup

    call USER_setup

    call PROF_rapend('Initialize', 0)

    !########## main ##########

#ifdef FIPP
    call fipp_start
#endif
#ifdef PAPI
    call PROF_PAPI_rapstart
#endif

    if( IO_L ) write(IO_FID_LOG,*)
    if( IO_L ) write(IO_FID_LOG,*) '++++++ START TIMESTEP ++++++'
    call PROF_setprefx('MAIN')
    call PROF_rapstart('Main_Loop', 0)

    do

      ! report current time
      call ADMIN_TIME_checkstate

      if ( TIME_DOresume ) then
         ! resume state from restart files
         call resume_state

         ! history&monitor file output
         call MONIT_write('MAIN')
         call FILE_HISTORY_write ! if needed
      end if


      ! time advance
      call ADMIN_TIME_advance
      call FILE_HISTORY_set_nowdate( TIME_NOWDATE, TIME_NOWMS, TIME_NOWSTEP )

      ! user-defined procedure
      call USER_step

      ! change to next state
      if( OCEAN_do .AND. TIME_DOOCEAN_step ) call OCEAN_driver
      if( LAND_do  .AND. TIME_DOLAND_step  ) call LAND_driver
      if( URBAN_do .AND. TIME_DOURBAN_step ) call URBAN_driver
      if( ATMOS_do .AND. TIME_DOATMOS_step ) call ATMOS_driver

      ! history&monitor file output
      call MONIT_write('MAIN')
      call FILE_HISTORY_write

      ! restart output
      call ADMIN_restart_write

      if( TIME_DOend ) exit

      if( IO_L ) call flush(IO_FID_LOG)

    enddo

    call PROF_rapend('Main_Loop', 0)

    if( IO_L ) write(IO_FID_LOG,*) '++++++ END TIMESTEP ++++++'
    if( IO_L ) write(IO_FID_LOG,*)


    call PROF_setprefx('FIN')

    call PROF_rapstart('All', 1)

    if( ATMOS_do ) call ATMOS_driver_finalize

#ifdef FIPP
    call fipp_stop
#endif
#ifdef PAPI
    call PROF_PAPI_rapstop
#endif

    !########## Finalize ##########

    ! check data
    if( ATMOS_sw_check ) call ATMOS_vars_restart_check

    call PROF_rapstart('Monit', 2)
    call MONIT_finalize
    call PROF_rapend  ('Monit', 2)

    call PROF_rapstart('File', 2)
    call FILE_HISTORY_finalize
    ! clean up resource allocated for I/O
    call FILE_CARTESC_cleanup

    call COMM_cleanup

    call FILE_Close_All
    call PROF_rapend  ('File', 2)

    call PROF_rapend  ('All', 1)

    call PROF_rapreport
#ifdef PAPI
    call PROF_PAPI_rapreport
#endif

    return
  end subroutine scalerm

  !-----------------------------------------------------------------------------
  subroutine resume_state
    use mod_atmos_driver, only: &
       ATMOS_driver_resume1, &
       ATMOS_driver_resume2, &
       ATMOS_SURFACE_SET
    use mod_ocean_driver, only: &
       OCEAN_driver_resume, &
       OCEAN_SURFACE_SET
    use mod_land_driver, only: &
       LAND_driver_resume, &
       LAND_SURFACE_SET
    use mod_urban_driver, only: &
       URBAN_driver_resume, &
       URBAN_SURFACE_SET
    use mod_atmos_vars, only: &
       ATMOS_vars_calc_diagnostics, &
       ATMOS_vars_history_setpres, &
       ATMOS_vars_restart_read
    use mod_ocean_vars, only: &
       OCEAN_vars_restart_read
    use mod_land_vars, only: &
       LAND_vars_restart_read
    use mod_urban_vars, only: &
       URBAN_vars_restart_read
    use mod_user, only: &
       USER_resume0, &
       USER_resume
    use mod_atmos_admin, only: &
       ATMOS_do
    use mod_ocean_admin, only: &
       OCEAN_do
    use mod_land_admin, only: &
       LAND_do
    use mod_urban_admin, only: &
       URBAN_do
    use mod_admin_restart, only: &
       ADMIN_restart_read
    implicit none
    !---------------------------------------------------------------------------

    ! read restart data
    call ADMIN_restart_read

    ! setup user-defined procedure before setup of other components
    call USER_resume0

    if ( ATMOS_do ) then
       ! calc diagnostics
       call ATMOS_vars_calc_diagnostics
       call ATMOS_vars_history_setpres
    endif

    ! setup surface condition
    if( ATMOS_do ) call ATMOS_SURFACE_SET( countup=.false. )
    if( OCEAN_do ) call OCEAN_SURFACE_SET( countup=.false. )
    if( LAND_do  ) call LAND_SURFACE_SET ( countup=.false. )
    if( URBAN_do ) call URBAN_SURFACE_SET( countup=.false. )

    ! setup submodel driver
    if( ATMOS_do ) call ATMOS_driver_resume1
    if( OCEAN_do ) call OCEAN_driver_resume
    if( LAND_do  ) call LAND_driver_resume
    if( URBAN_do ) call URBAN_driver_resume
    if( ATMOS_do ) call ATMOS_driver_resume2

    ! setup user-defined procedure
    call USER_resume

    return
  end subroutine resume_state

end module mod_rm_driver
