!-------------------------------------------------------------------------------
!> module SCALE-RM prep
!!
!! @par Description
!!          This program is driver of preprocess tools
!!          1) boundary data (e.g. topography, land use index)
!!          2) initial data for ideal/real test cases
!!
!! @author Team SCALE
!!
!! @par History
!! @li      2012-04-08 (H.Yashiro)  [mod] merge all init programs
!! @li      2012-06-13 (Y.Sato)     [mod] add HBINW option
!! @li      2016-06-03 (H.Yashiro)  [mod] merge scale-rm_pp and scale-rm_init
!!
!<
!-------------------------------------------------------------------------------
module mod_rm_prep
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
  public :: scalerm_prep

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
  subroutine scalerm_prep( &
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
       ATMOS_GRID_CARTESC_setup
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
       COMM_setup
    use scale_topography, only: &
       TOPO_setup
    use scale_landuse, only: &
       LANDUSE_setup
    use scale_atmos_grid_cartesC_real, only: &
       ATMOS_GRID_CARTESC_REAL_setup,   &
       ATMOS_GRID_CARTESC_REAL_update_Z
    use scale_gridtrans, only: &
       GTRANS_setup
    use scale_rm_statistics, only: &
       STAT_setup
    use scale_atmos_hydrostatic, only: &
       ATMOS_HYDROSTATIC_setup
    use scale_atmos_thermodyn, only: &
       ATMOS_THERMODYN_setup
    use scale_atmos_hydrometeor, only: &
       ATMOS_HYDROMETEOR_setup
    use scale_atmos_saturation, only: &
       ATMOS_SATURATION_setup
    use mod_atmos_driver, only: &
       ATMOS_driver_config
    use mod_admin_restart, only: &
       ADMIN_restart_setup
    use mod_admin_time, only: &
       ADMIN_TIME_setup
    use mod_atmos_admin, only: &
       ATMOS_admin_setup
    use mod_atmos_vars, only: &
       ATMOS_vars_setup
    use mod_ocean_admin, only: &
       OCEAN_admin_setup
    use mod_ocean_vars, only: &
       OCEAN_vars_setup
    use mod_land_admin, only: &
       LAND_admin_setup
    use mod_land_vars, only: &
       LAND_vars_setup
    use mod_urban_admin, only: &
       URBAN_admin_setup
    use mod_urban_vars, only: &
       URBAN_vars_setup
    use mod_cpl_admin, only: &
       CPL_admin_setup
    use mod_cpl_vars, only: &
       CPL_vars_setup
    use mod_convert, only: &
       CONVERT_setup, &
       CONVERT
    use mod_mktopo, only: &
       MKTOPO_setup, &
       MKTOPO
    use mod_mkinit, only: &
       MKINIT_setup, &
       MKINIT
    use mod_user, only: &
       USER_config
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
    call ADMIN_TIME_setup( setup_TimeIntegration = .false. )
    ! setup statistics
    call STAT_setup

    ! setup nesting grid
    call COMM_CARTESC_NEST_setup ( intercomm_parent, intercomm_child )


    ! setup common tools
    call ATMOS_HYDROSTATIC_setup
    call ATMOS_THERMODYN_setup
    call ATMOS_SATURATION_setup

    ! setup variable container
    call ATMOS_vars_setup
    call OCEAN_vars_setup
    call LAND_vars_setup
    call URBAN_vars_setup
    call CPL_vars_setup

    ! setup preprocess converter
    call CONVERT_setup

    ! setup mktopo
    call MKTOPO_setup

    ! setup mkinit
    call MKINIT_setup

    call PROF_rapend('Initialize',0)

    !########## main ##########

    call PROF_setprefx('MAIN')
    call PROF_rapstart('Main_prep',0)

    ! execute preprocess
    call PROF_rapstart('Convert',1)
    call CONVERT
    call PROF_rapend  ('Convert',1)

    ! execute mktopo
    call PROF_rapstart('MkTopo',1)
    call MKTOPO
    call PROF_rapend  ('MkTopo',1)

    ! re-setup
    call ATMOS_GRID_CARTESC_REAL_update_Z

    ! execute mkinit
    call PROF_rapstart('MkInit',1)
    call MKINIT
    call PROF_rapend  ('MkInit',1)

    call PROF_rapend('Main_prep',0)

    !########## Finalize ##########

    ! setup file I/O
    call FILE_CARTESC_cleanup

    call FILE_Close_All

    call PROF_rapreport

    return
  end subroutine scalerm_prep

end module mod_rm_prep
