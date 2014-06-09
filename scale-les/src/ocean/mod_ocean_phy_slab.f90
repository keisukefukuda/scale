!-------------------------------------------------------------------------------
!> module OCEAN / Physics Fixed-SST
!!
!! @par Description
!!          ocean physics module, fixed SST
!!
!! @author Team SCALE
!!
!<
!-------------------------------------------------------------------------------
module mod_ocean_phy_slab
  !-----------------------------------------------------------------------------
  !
  !++ used modules
  !
  use scale_precision
  use scale_stdio
  use scale_prof
  use scale_grid_index
  !-----------------------------------------------------------------------------
  implicit none
  private
  !-----------------------------------------------------------------------------
  !
  !++ Public procedure
  !
  public :: OCEAN_PHY_driver_setup
  public :: OCEAN_PHY_driver_first
  public :: OCEAN_PHY_driver_final

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
  real(RP), private :: DZW    = 50.0_RP    !< water depth of slab ocean [m]
  logical,  private :: FLG_CR = .false.    !< is the fixed change rate used?
  real(RP), private :: CRATE  = 2.0E-5_RP  !< fixed change rate of water temperature [K/s]

  !-----------------------------------------------------------------------------
contains
  !-----------------------------------------------------------------------------
  !> Setup
  subroutine OCEAN_PHY_driver_setup( OCEAN_TYPE )
    use scale_process, only: &
       PRC_MPIstop
    implicit none

    character(len=*), intent(in) :: OCEAN_TYPE

    real(RP) :: OCEAN_SLAB_DEPTH
    logical  :: OCEAN_SLAB_FLG_CR
    real(RP) :: OCEAN_SLAB_CRATE

    NAMELIST / PARAM_OCEAN_SLAB / &
       OCEAN_SLAB_DEPTH,  &
       OCEAN_SLAB_FLG_CR, &
       OCEAN_SLAB_CRATE

    integer :: ierr
    !---------------------------------------------------------------------------

    if( IO_L ) write(IO_FID_LOG,*)
    if( IO_L ) write(IO_FID_LOG,*) '+++ Module[SLAB]/Categ[OCEAN]'

    OCEAN_SLAB_DEPTH  = DZW
    OCEAN_SLAB_FLG_CR = FLG_CR
    OCEAN_SLAB_CRATE  = CRATE

    if ( OCEAN_TYPE /= 'SLAB' ) then
       if( IO_L ) write(IO_FID_LOG,*) 'xxx OCEAN_TYPE is not SLAB. Check!'
       call PRC_MPIstop
    endif

    !--- read namelist
    rewind(IO_FID_CONF)
    read(IO_FID_CONF,nml=PARAM_OCEAN_SLAB,iostat=ierr)

    if( ierr < 0 ) then !--- missing
       if( IO_L ) write(IO_FID_LOG,*) '*** Not found namelist. Default used.'
    elseif( ierr > 0 ) then !--- fatal error
       write(*,*) 'xxx Not appropriate names in namelist PARAM_OCEAN_SLAB. Check!'
       call PRC_MPIstop
    endif
    if( IO_L ) write(IO_FID_LOG,nml=PARAM_OCEAN_SLAB)

    DZW    = OCEAN_SLAB_DEPTH
    FLG_CR = OCEAN_SLAB_FLG_CR
    CRATE  = OCEAN_SLAB_CRATE

    return
  end subroutine OCEAN_PHY_driver_setup

  !-----------------------------------------------------------------------------
  !> Physical processes for ocean submodel
  subroutine OCEAN_PHY_driver_first
    use scale_const, only: &
       DWATR => CONST_DWATR, &
       CL    => CONST_CL
    use scale_time, only: &
       dt => TIME_DTSEC_OCEAN
    use mod_ocean_vars, only: &
       TW
    use mod_cpl_vars, only: &
       CPL_getOcn
    implicit none

    ! work
    real(RP) :: WHFLX  (IA,JA)
    real(RP) :: PRECFLX(IA,JA)
    real(RP) :: QVFLX  (IA,JA)

    integer :: i, j
    !---------------------------------------------------------------------------

    if( IO_L ) write(IO_FID_LOG,*) '*** Ocean step: Slab'

    call CPL_getOcn( WHFLX  (:,:), & ! [OUT]
                         PRECFLX(:,:), & ! [OUT]
                         QVFLX  (:,:)  ) ! [OUT]

    ! update water temperature
    if( FLG_CR ) then

      do j = JS, JE
      do i = IS, IE
        TW(i,j) = TW(i,j) + CRATE * dt
      end do
      end do

    else

      do j = JS, JE
      do i = IS, IE
        TW(i,j) = TW(i,j) - WHFLX(i,j) / ( DWATR * CL * DZW ) * dt
      end do
      end do

    end if

    return
  end subroutine OCEAN_PHY_driver_first

  subroutine OCEAN_PHY_driver_final
    use mod_ocean_vars, only: &
       TW,                  &
       OCEAN_vars_fillhalo
    use mod_cpl_vars, only: &
       CPL_putOcn
    implicit none
    !---------------------------------------------------------------------------

    call OCEAN_vars_fillhalo

    call CPL_putOcn( TW(:,:) ) ! [IN]

    return
  end subroutine OCEAN_PHY_driver_final

end module mod_ocean_phy_slab
