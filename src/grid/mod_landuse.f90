!-------------------------------------------------------------------------------
!> module LANDUSE
!!
!! @par Description
!!          Land use category module
!!          Manage land use category index&fraction
!!
!! @author Team SCALE
!!
!<
!-------------------------------------------------------------------------------
module mod_landuse
  !-----------------------------------------------------------------------------
  !
  !++ used modules
  !
  use mod_stdio, only: &
     IO_FID_LOG, &
     IO_L,       &
     IO_FILECHR, &
     IO_SYSCHR
  use mod_time, only: &
     TIME_rapstart, &
     TIME_rapend
  !-----------------------------------------------------------------------------
  implicit none
  private
  !-----------------------------------------------------------------------------
  !
  !++ included parameters
  !
  include "inc_precision.h"
  include "inc_index.h"

  !-----------------------------------------------------------------------------
  !
  !++ Public procedure
  !
  public :: LANDUSE_setup
  public :: FRAC_OCEAN_write
  
  !-----------------------------------------------------------------------------
  !
  !++ Public parameters & variables
  !
  real(RP), public, save :: LANDUSE_frac_ocean(1,IA,JA) !< ocean fraction
  real(RP), public, save :: LANDUSE_frac_river(1,IA,JA) !< river fraction
  real(RP), public, save :: LANDUSE_frac_lake (1,IA,JA) !< lake  fraction

  integer,  public, parameter :: LUCA = 2 !< number of vegetation category

  integer,  public,      save :: LANDUSE_index_vegetation(1,IA,JA,LUCA) !< index    of vegetation category
  real(RP), public,      save :: LANDUSE_frac_vegetation (1,IA,JA,LUCA) !< fraction of vegetation category

  !-----------------------------------------------------------------------------
  !
  !++ Private procedure
  !
  private :: FRAC_OCEAN_read

  !-----------------------------------------------------------------------------
  !
  !++ Private parameters & variables
  !
  character(len=IO_FILECHR), private :: LANDUSE_IN_BASENAME  = ''               !< basename of the input  file
  character(len=IO_FILECHR), private :: LANDUSE_OUT_BASENAME = ''               !< basename of the output file
  character(len=IO_SYSCHR),  private :: LANDUSE_OUT_TITLE    = 'SCALE3 LANDUSE' !< title    of the output file
  character(len=IO_SYSCHR),  private :: LANDUSE_OUT_DTYPE    = 'DEFAULT'        !< REAL4 or REAL8

  !-----------------------------------------------------------------------------
contains
  !-----------------------------------------------------------------------------
  !> Setup
  subroutine LANDUSE_setup
    use mod_stdio, only: &
       IO_FID_CONF
    use mod_process, only: &
       PRC_MPIstop
    implicit none

    namelist / PARAM_LANDUSE / &
       LANDUSE_IN_BASENAME,  &
       LANDUSE_OUT_BASENAME, &
       LANDUSE_OUT_DTYPE

    integer :: ierr
    !---------------------------------------------------------------------------

    if( IO_L ) write(IO_FID_LOG,*)
    if( IO_L ) write(IO_FID_LOG,*) '+++ Module[LANDUSE]/Categ[GRID]'

    !--- read namelist
    rewind(IO_FID_CONF)
    read(IO_FID_CONF,nml=PARAM_LANDUSE,iostat=ierr)

    if( ierr < 0 ) then !--- missing
       if( IO_L ) write(IO_FID_LOG,*) '*** Not found namelist. Default used.'
    elseif( ierr > 0 ) then !--- fatal error
       write(*,*) 'xxx Not appropriate names in namelist PARAM_LANDUSE. Check!'
       call PRC_MPIstop
    endif
    if( IO_L ) write(IO_FID_LOG,nml=PARAM_LANDUSE)

    LANDUSE_frac_ocean(:,:,:) = 1.0_RP
    LANDUSE_frac_river(:,:,:) = 0.0_RP
    LANDUSE_frac_lake (:,:,:) = 0.0_RP

    LANDUSE_index_vegetation(:,:,:,:) = -999
    LANDUSE_frac_vegetation (:,:,:,:) = 0.0_RP

    ! read from file
    call FRAC_OCEAN_read

    ! write to file
    call FRAC_OCEAN_write

    return
  end subroutine LANDUSE_setup

  !-----------------------------------------------------------------------------
  !> Read land-ocean fraction
  subroutine FRAC_OCEAN_read
    use mod_fileio, only: &
       FILEIO_read
    use mod_comm, only: &
       COMM_vars8, &
       COMM_wait
    implicit none
    !---------------------------------------------------------------------------

    if( IO_L ) write(IO_FID_LOG,*)
    if( IO_L ) write(IO_FID_LOG,*) '*** Input land-ocean fraction file ***'

    if ( LANDUSE_IN_BASENAME /= '' ) then

       call FILEIO_read( LANDUSE_frac_ocean(1,:,:),                      & ! [OUT]
                         LANDUSE_IN_BASENAME, 'FRAC_OCEAN', 'XY', step=1 ) ! [IN]
       ! fill IHALO & JHALO
       call COMM_vars8( LANDUSE_frac_ocean(1,:,:), 1 )
       call COMM_wait ( LANDUSE_frac_ocean(1,:,:), 1 )

    else

       if( IO_L ) write(IO_FID_LOG,*) '*** land-ocean fraction file is not specified.'
       if( IO_L ) write(IO_FID_LOG,*) '*** Assume all grids are ocean'

    endif

    return
  end subroutine FRAC_OCEAN_read

  !-----------------------------------------------------------------------------
  !> Write land-ocean fraction
  subroutine FRAC_OCEAN_write
    use mod_fileio, only: &
       FILEIO_write
    implicit none
    !---------------------------------------------------------------------------

    if ( LANDUSE_OUT_BASENAME /= '' ) then

       if( IO_L ) write(IO_FID_LOG,*)
       if( IO_L ) write(IO_FID_LOG,*) '*** Output land-ocean fraction file ***'

       call FILEIO_write( LANDUSE_frac_ocean(1,:,:),  LANDUSE_OUT_BASENAME, LANDUSE_OUT_TITLE, & ! [IN]
                          'FRAC_OCEAN', 'OCEAN fraction', '0-1', 'XY',      LANDUSE_OUT_DTYPE  ) ! [IN]

    endif

    return
  end subroutine FRAC_OCEAN_write

end module mod_landuse