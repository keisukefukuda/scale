!-------------------------------------------------------------------------------
!> module LAND / Physics Bucket
!!
!! @par Description
!!          bucket-type land physics module
!!
!! @author Team SCALE
!! @li      2013-08-31 (T.Yamaura)  [new]
!<
!-------------------------------------------------------------------------------
module mod_land_phy_bucket
  !-----------------------------------------------------------------------------
  !
  !++ used modules
  !
  use mod_precision
  use mod_index
  use mod_stdio, only: &
     IO_FID_LOG,  &
     IO_L
  use mod_time, only: &
     TIME_rapstart, &
     TIME_rapend
  !-----------------------------------------------------------------------------
  implicit none
  private
  !-----------------------------------------------------------------------------
  !
  !++ Public procedure
  !
  public :: LAND_PHY_setup
  public :: LAND_PHY

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
  !-----------------------------------------------------------------------------

  ! limiter
  real(RP), private, parameter :: BETA_MIN = 0.0E-8_RP
  real(RP), private, parameter :: BETA_MAX = 1.0_RP

contains
  !-----------------------------------------------------------------------------
  !> Setup
  subroutine LAND_PHY_setup
    use mod_stdio, only: &
       IO_FID_CONF
    use mod_process, only: &
       PRC_MPIstop
    use mod_land_vars, only: &
       LAND_TYPE_PHY
    implicit none

    logical  :: dummy

    NAMELIST / PARAM_LAND_BUCKET / &
       dummy

    integer :: ierr
    !---------------------------------------------------------------------------

    if( IO_L ) write(IO_FID_LOG,*)
    if( IO_L ) write(IO_FID_LOG,*) '+++ Module[BUCKET]/Categ[LAND]'

    if ( LAND_TYPE_PHY /= 'BUCKET' ) then
       if( IO_L ) write(IO_FID_LOG,*) 'xxx LAND_TYPE_PHY is not BUCKET. Check!'
       call PRC_MPIstop
    endif

    !--- read namelist
    rewind(IO_FID_CONF)
    read(IO_FID_CONF,nml=PARAM_LAND_BUCKET,iostat=ierr)

    if( ierr < 0 ) then !--- missing
       if( IO_L ) write(IO_FID_LOG,*) '*** Not found namelist. Default used.'
    elseif( ierr > 0 ) then !--- fatal error
       write(*,*) 'xxx Not appropriate names in namelist PARAM_LAND_BUCKET. Check!'
       call PRC_MPIstop
    endif
    if( IO_L ) write(IO_FID_LOG,nml=PARAM_LAND_BUCKET)

    return
  end subroutine LAND_PHY_setup

  !-----------------------------------------------------------------------------
  !> Physical processes for land submodel
  subroutine LAND_PHY
    use mod_const, only: &
       DWATR => CONST_DWATR, &
       CL    => CONST_CL
    use mod_time, only: &
       dt => TIME_DTSEC_LAND
    use mod_land_vars, only: &
       SFLX_GH,    &
       SFLX_PREC,  &
       SFLX_QVLnd, &
       TG,         &
       QvEfc,      &
       ROFF,       &
       STRG,       &
       I_STRGMAX,  &
       I_STRGCRT,  &
       I_HCS,      &
       I_DZg,      &
       P => LAND_PROPERTY
 
    implicit none

    integer :: i,j
    !---------------------------------------------------------------------------

    do j = JS, JE
    do i = IS, IE

      ! update water storage
      STRG(i,j) = STRG(i,j) + ( SFLX_PREC(i,j) - SFLX_QVLnd(i,j) ) * dt

      if ( STRG(i,j) > P(i,j,I_STRGMAX) ) then
         ROFF(i,j) = ROFF(i,j) + STRG(i,j) - P(i,j,I_STRGMAX)
         STRG(i,j) = P(i,j,I_STRGMAX)
      endif

      ! update moisture efficiency
      QvEfc(i,j) = BETA_MAX
      if ( STRG(i,j) < P(i,j,I_STRGCRT) ) then
         QvEfc(i,j) = max( STRG(i,j)/P(i,j,I_STRGCRT), BETA_MIN )
      endif

      ! update ground temperature
      TG(i,j) = TG(i,j) - 2.0_RP * SFLX_GH(i,j) &
              / ( ( 1.0_RP - P(i,j,I_STRGMAX) * 1.E-3_RP ) * P(i,j,I_HCS) &
                + STRG(i,j) * 1.E-3_RP * DWATR * CL * P(i,j,I_DZg)    ) * dt

    end do
    end do

    return
  end subroutine LAND_PHY

end module mod_land_phy_bucket
