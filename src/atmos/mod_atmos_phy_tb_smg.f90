!-------------------------------------------------------------------------------
!> module ATMOSPHERE / Physics Turbulence
!!
!! @par Description
!!          Sub-grid scale turbulence process
!!          Smagolinsky-type
!!
!! @author Team SCALE
!!
!! @par History
!! @li      2011-11-29 (S.Iga)       [new]
!! @li      2011-12-11 (H.Yashiro)   [mod] integrate to SCALE3
!! @li      2012-03-23 (H.Yashiro)   [mod] Explicit index parameter inclusion
!! @li      2012-03-27 (H.Yashiro)   [mod] reconstruction
!! @li      2012-07-02 (S.Nishizawa) [mod] reconstruction with Brown et al. (1994)
!! @li      2012-10-26 (S.Nishizawa) [mod] remove surface flux
!! @li      2013-06-13 (S.Nishizawa) [mod] change mixing length by Brown et al. (1994) and Scotti et al. (1993)
!!
!! - Reference
!!  - Brown et al., 1994:
!!    Large-eddy simulaition of stable atmospheric boundary layers with a revised stochastic subgrid model.
!!    Roy. Meteor. Soc., 120, 1485-1512
!!  - Scotti et al., 1993:
!!    Generalized Smagorinsky model for anisotropic grids.
!!    Phys. Fluids A, 5, 2306-2308
!!
!<
!-------------------------------------------------------------------------------
module mod_atmos_phy_tb
  !-----------------------------------------------------------------------------
  !
  !++ used modules
  !
  use mod_stdio, only: &
     IO_FID_LOG,  &
     IO_L
#ifdef DEBUG
  use mod_debug, only: &
     CHECK
  use mod_const, only: &
     UNDEF => CONST_UNDEF, &
     IUNDEF => CONST_UNDEF2
#endif
  !-----------------------------------------------------------------------------
  implicit none
  private
  !-----------------------------------------------------------------------------
  !
  !++ Public procedure
  !
  public :: ATMOS_PHY_TB_setup
  public :: ATMOS_PHY_TB
  public :: ATMOS_PHY_TB_main

  !-----------------------------------------------------------------------------
  !
  !++ included parameters
  !
  include 'inc_precision.h'
  include 'inc_index.h'
  include 'inc_tracer.h'

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
  real(RP), private,      save :: MOMZ_t(KA,IA,JA)
  real(RP), private,      save :: MOMX_t(KA,IA,JA)
  real(RP), private,      save :: MOMY_t(KA,IA,JA)
  real(RP), private,      save :: RHOT_t(KA,IA,JA)
  real(RP), private,      save :: QTRC_t(KA,IA,JA,QA)

  real(RP), private,      save :: nu_factC (KA,IA,JA) ! (Cs*Delta)^2 (cell center)
  real(RP), private,      save :: nu_factXY(KA,IA,JA) !              (x-y plane)
  real(RP), private,      save :: nu_factYZ(KA,IA,JA) !              (y-z plane)
  real(RP), private,      save :: nu_factZX(KA,IA,JA) !              (z-x plane)
  real(RP), private,      save :: nu_factZ (KA,IA,JA) !              (z edge)
  real(RP), private,      save :: nu_factX (KA,IA,JA) !              (x edge)
  real(RP), private,      save :: nu_factY (KA,IA,JA) !              (y edge)

  real(RP), private, save      :: Cs  = 0.13_RP ! Smagorinsky constant (Scotti et al. 1993)
  real(RP), private, parameter :: Ck  = 0.1_RP  ! SGS constant (Moeng and Wyngaard 1988)
  real(RP), private, parameter :: PrN = 0.7_RP  ! Prandtl number in neutral conditions
  real(RP), private, parameter :: RiC = 0.25_RP ! critical Richardson number
  real(RP), private, parameter :: FmC = 16.0_RP ! fum = sqrt(1 - c*Ri)
  real(RP), private, parameter :: FhB = 40.0_RP ! fuh = sqrt(1 - b*Ri)/PrN
  real(RP), private            :: RPrN          ! 1 / PrN
  real(RP), private            :: RRiC          ! 1 / RiC
  real(RP), private            :: PrNovRiC      ! PrN / RiC

  real(RP), private, parameter :: OneOverThree = 1.0_RP / 3.0_RP
  real(RP), private, parameter :: twoOverThree = 2.0_RP / 3.0_RP

  integer, private, parameter :: ZDIR = 1
  integer, private, parameter :: XDIR = 2
  integer, private, parameter :: YDIR = 3

  !-----------------------------------------------------------------------------
contains

  subroutine ATMOS_PHY_TB_setup
    use mod_stdio, only: &
       IO_FID_CONF
    use mod_grid, only: &
       CDZ => GRID_CDZ, &
       CDX => GRID_CDX, &
       CDY => GRID_CDY, &
       FDZ => GRID_FDZ, &
       FDX => GRID_FDX, &
       FDY => GRID_FDY, &
       CZ  => GRID_CZ, &
       FZ  => GRID_FZ
    use mod_process, only: &
       PRC_MPIstop
    use mod_atmos_vars, only: &
       ATMOS_TYPE_PHY_TB
    implicit none

    real(RP) :: ATMOS_PHY_TB_SMG_Cs

    NAMELIST / PARAM_ATMOS_PHY_TB_SMG / &
         ATMOS_PHY_TB_SMG_Cs

    integer :: k, i, j
    integer :: ierr
    !---------------------------------------------------------------------------

    if( IO_L ) write(IO_FID_LOG,*)
    if( IO_L ) write(IO_FID_LOG,*) '+++ Module[Physics-TB]/Categ[ATMOS]'
    if( IO_L ) write(IO_FID_LOG,*) '+++ Smagorinsky-type Eddy Viscocity Model'

    if ( ATMOS_TYPE_PHY_TB /= 'SMAGORINSKY' ) then
       if ( IO_L ) write(IO_FID_LOG,*) 'xxx ATMOS_TYPE_PHY_TB is not SMAGORINSKY. Check!'
       call PRC_MPIstop
    endif

    ATMOS_PHY_TB_SMG_Cs = Cs
    !--- read namelist
    rewind(IO_FID_CONF)
    read(IO_FID_CONF,nml=PARAM_ATMOS_PHY_TB_SMG,iostat=ierr)

    if( ierr < 0 ) then !--- missing
       if( IO_L ) write(IO_FID_LOG,*) '*** Not found namelist. Default used.'
    elseif( ierr > 0 ) then !--- fatal error
       write(*,*) 'xxx Not appropriate names in namelist PARAM_ATMOS_PHY_TB_SMG. Check!'
       call PRC_MPIstop
    endif
    if( IO_L ) write(IO_FID_LOG,nml=PARAM_ATMOS_PHY_TB_SMG)

    Cs = ATMOS_PHY_TB_SMG_Cs


    RPrN     = 1.0_RP / PrN
    RRiC     = 1.0_RP / RiC
    PrNovRiC = (1- PrN) * RRiC

#ifdef DEBUG
    nu_factC (:,:,:) = UNDEF
    nu_factXY(:,:,:) = UNDEF
    nu_factYZ(:,:,:) = UNDEF
    nu_factZX(:,:,:) = UNDEF
    nu_factZ (:,:,:) = UNDEF
    nu_factX (:,:,:) = UNDEF
    nu_factY (:,:,:) = UNDEF
#endif
    do j = JS, JE+1
    do i = IS, IE+1
    do k = KS, KE
       nu_factC (k,i,j) = ( Cs * mixlen(CDZ(k),CDX(i),CDY(j),CZ(k)) )**2
    enddo
    enddo
    enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
    do j = JS, JE
    do i = IS, IE
    do k = KS, KE
       nu_factXY(k,i,j) = ( Cs * mixlen(FDZ(k),CDX(i),CDY(j),FZ(k)) )**2
    enddo
    enddo
    enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
    do j = JS  , JE
    do i = IS-1, IE
    do k = KS, KE
       nu_factYZ(k,i,j) = ( Cs * mixlen(CDZ(k),FDX(i),CDY(j),CZ(k)) )**2
    enddo
    enddo
    enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
    do j = JS-1, JE
    do i = IS  , IE
    do k = KS  , KE
       nu_factZX(k,i,j) = ( Cs * mixlen(CDZ(k),CDX(i),FDY(j),CZ(k)) )**2
    enddo
    enddo
    enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
    do j = JS-1, JE
    do i = IS-1, IE
    do k = KS  , KE
       nu_factZ(k,i,j) = ( Cs * mixlen(CDZ(k),FDX(i),FDY(j),CZ(k) ) )**2
    enddo
    enddo
    enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
    do j = JS-1, JE
    do i = IS  , IE
    do k = KS  , KE
       nu_factX(k,i,j) = ( Cs * mixlen(FDZ(k),CDX(i),FDY(j),FZ(k)) )**2
    enddo
    enddo
    enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
    do j = JS  , JE
    do i = IS-1, IE
    do k = KS  , KE
       nu_factY(k,i,j) = ( Cs * mixlen(FDZ(k),FDX(i),CDY(j),FZ(k)) )**2
    enddo
    enddo
    enddo
#ifdef DEBUG
    i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

    return
  end subroutine ATMOS_PHY_TB_setup

  !-----------------------------------------------------------------------------
  !> Smagorinsky-type turblence
  !>
  !> comment:
  !>  1, Pr is given linearly (iga)
  !>  4, heat flux is not accurate yet. (i.e. energy is not conserved, see *1)
  !>  5, stratification effect is not considered.
  !-----------------------------------------------------------------------------
  subroutine ATMOS_PHY_TB( update_flag )
    use mod_time, only: &
       dttb => TIME_DTSEC_ATMOS_PHY_TB
    use mod_history, only: &
       HIST_in
    use mod_grid, only: &
       RCDZ => GRID_RCDZ, &
       RCDX => GRID_RCDX, &
       RCDY => GRID_RCDY, &
       RFDZ => GRID_RFDZ, &
       RFDX => GRID_RFDX, &
       RFDY => GRID_RFDY
    use mod_atmos_vars, only: &
       DENS_av, &
       MOMZ_av, &
       MOMX_av, &
       MOMY_av, &
       RHOT_av, &
       QTRC_av, &
       MOMZ_tp, &
       MOMX_tp, &
       MOMY_tp, &
       RHOT_tp, &
       QTRC_tp
    implicit none

    logical, intent(in) :: update_flag

    ! eddy viscosity/diffusion flux
    real(RP) :: qflx_sgs_momz(KA,IA,JA,3)
    real(RP) :: qflx_sgs_momx(KA,IA,JA,3)
    real(RP) :: qflx_sgs_momy(KA,IA,JA,3)
    real(RP) :: qflx_sgs_rhot(KA,IA,JA,3)
    real(RP) :: qflx_sgs_qtrc(KA,IA,JA,QA,3)

    ! diagnostic variables
    real(RP) :: tke(KA,IA,JA) ! TKE
    real(RP) :: nu (KA,IA,JA) ! eddy diffusion
    real(RP) :: Ri (KA,IA,JA) ! Richardoson number
    real(RP) :: Pr (KA,IA,JA) ! Prandtle number

    integer :: k, i, j, iq
    integer :: IIS, IIE, JJS, JJE

    if ( update_flag ) then
       call ATMOS_PHY_TB_main( &
            qflx_sgs_momz, qflx_sgs_momx, qflx_sgs_momy, & ! (out)
            qflx_sgs_rhot, qflx_sgs_qtrc,                & ! (out)
            tke, nu, Ri, Pr,                             & ! (out) diagnostic variables
            MOMZ_av, MOMX_av, MOMY_av, RHOT_av, DENS_av, QTRC_av & ! (in)
            )


       do JJS = JS, JE, JBLOCK
       JJE = JJS+JBLOCK-1
       do IIS = IS, IE, IBLOCK
       IIE = IIS+IBLOCK-1
          do j = JJS, JJE
          do i = IIS, IIE
          do k = KS, KE-1
             MOMZ_t(k,i,j) = - ( &
                  + ( qflx_sgs_momz(k+1,i,j,ZDIR) - qflx_sgs_momz(k,i  ,j  ,ZDIR) ) * RFDZ(k) &
                  + ( qflx_sgs_momz(k  ,i,j,XDIR) - qflx_sgs_momz(k,i-1,j  ,XDIR) ) * RCDX(i) &
                  + ( qflx_sgs_momz(k  ,i,j,YDIR) - qflx_sgs_momz(k,i  ,j-1,YDIR) ) * RCDY(j) )
          end do
          end do
          end do
          do j = JJS, JJE
          do i = IIS, IIE
          do k = KS, KE
             MOMX_t(k,i,j) = - ( &
                  + ( qflx_sgs_momx(k,i  ,j,ZDIR) - qflx_sgs_momx(k-1,i,j  ,ZDIR) ) * RCDZ(k) &
                  + ( qflx_sgs_momx(k,i+1,j,XDIR) - qflx_sgs_momx(k  ,i,j  ,XDIR) ) * RFDX(i) &
                  + ( qflx_sgs_momx(k,i  ,j,YDIR) - qflx_sgs_momx(k  ,i,j-1,YDIR) ) * RCDY(j) )
          end do
          end do
          end do
          do j = JJS, JJE
          do i = IIS, IIE
          do k = KS, KE
             MOMY_t(k,i,j) = - ( &
                  + ( qflx_sgs_momy(k,i,j  ,ZDIR) - qflx_sgs_momy(k-1,i  ,j,ZDIR) ) * RCDZ(k) &
                  + ( qflx_sgs_momy(k,i,j  ,XDIR) - qflx_sgs_momy(k  ,i-1,j,XDIR) ) * RCDX(i) &
                  + ( qflx_sgs_momy(k,i,j+1,YDIR) - qflx_sgs_momy(k  ,i  ,j,YDIR) ) * RFDY(j) )
          end do
          end do
          end do
          do j = JJS, JJE
          do i = IIS, IIE
          do k = KS, KE
             RHOT_t(k,i,j) = - ( &
                  + ( qflx_sgs_rhot(k,i,j,ZDIR) - qflx_sgs_rhot(k-1,i  ,j  ,ZDIR) ) * RCDZ(k) &
                  + ( qflx_sgs_rhot(k,i,j,XDIR) - qflx_sgs_rhot(k  ,i-1,j  ,XDIR) ) * RCDX(i) &
                  + ( qflx_sgs_rhot(k,i,j,YDIR) - qflx_sgs_rhot(k  ,i  ,j-1,YDIR) ) * RCDY(j) )
          end do
          end do
          end do
          do iq = 1, QA
          do j = JJS, JJE
          do i = IIS, IIE
          do k = KS, KE
             QTRC_t(k,i,j,iq) = - ( &
                  + ( qflx_sgs_qtrc(k,i,j,iq,ZDIR) - qflx_sgs_qtrc(k-1,i  ,j  ,iq,ZDIR) ) * RCDZ(k) &
                  + ( qflx_sgs_qtrc(k,i,j,iq,XDIR) - qflx_sgs_qtrc(k  ,i-1,j  ,iq,XDIR) ) * RCDX(i) &
                  + ( qflx_sgs_qtrc(k,i,j,iq,YDIR) - qflx_sgs_qtrc(k  ,i  ,j-1,iq,YDIR) ) * RCDY(j) )
          end do
          end do
          end do
          end do
       end do
       end do

       call HIST_in( tke(:,:,:), 'TKE',  'turburent kinetic energy', 'm2/s2', dttb )
       call HIST_in( nu (:,:,:), 'NU',   'eddy viscosity',           'm2/s',  dttb )
       call HIST_in( Pr (:,:,:), 'Pr',   'Prantle number',           'NIL',   dttb )
       call HIST_in( Ri (:,:,:), 'Ri',   'Richardson number',        'NIL',   dttb )

       call HIST_in( qflx_sgs_momz(:,:,:,ZDIR), 'SGS_ZFLX_MOMZ',   'SGS Z FLUX of MOMZ', 'kg/m/s2', dttb, zdim='half')
       call HIST_in( qflx_sgs_momz(:,:,:,XDIR), 'SGS_XFLX_MOMZ',   'SGS X FLUX of MOMZ', 'kg/m/s2', dttb, xdim='half')
       call HIST_in( qflx_sgs_momz(:,:,:,YDIR), 'SGS_YFLX_MOMZ',   'SGS Y FLUX of MOMZ', 'kg/m/s2', dttb, ydim='half')

       call HIST_in( qflx_sgs_momx(:,:,:,ZDIR), 'SGS_ZFLX_MOMX',   'SGS Z FLUX of MOMX', 'kg/m/s2', dttb, zdim='half')
       call HIST_in( qflx_sgs_momx(:,:,:,XDIR), 'SGS_XFLX_MOMX',   'SGS X FLUX of MOMX', 'kg/m/s2', dttb, xdim='half')
       call HIST_in( qflx_sgs_momx(:,:,:,YDIR), 'SGS_YFLX_MOMX',   'SGS Y FLUX of MOMX', 'kg/m/s2', dttb, ydim='half')

       call HIST_in( qflx_sgs_momy(:,:,:,ZDIR), 'SGS_ZFLX_MOMY',   'SGS Z FLUX of MOMY', 'kg/m/s2', dttb, zdim='half')
       call HIST_in( qflx_sgs_momy(:,:,:,XDIR), 'SGS_XFLX_MOMY',   'SGS X FLUX of MOMY', 'kg/m/s2', dttb, xdim='half')
       call HIST_in( qflx_sgs_momy(:,:,:,YDIR), 'SGS_YFLX_MOMY',   'SGS Y FLUX of MOMY', 'kg/m/s2', dttb, ydim='half')

       call HIST_in( qflx_sgs_rhot(:,:,:,ZDIR), 'SGS_ZFLX_RHOT',   'SGS Z FLUX of RHOT', 'kg K/m2/s', dttb, zdim='half')
       call HIST_in( qflx_sgs_rhot(:,:,:,XDIR), 'SGS_XFLX_RHOT',   'SGS X FLUX of RHOT', 'kg K/m2/s', dttb, xdim='half')
       call HIST_in( qflx_sgs_rhot(:,:,:,YDIR), 'SGS_YFLX_RHOT',   'SGS Y FLUX of RHOT', 'kg K/m2/s', dttb, ydim='half')

       if ( I_QV > 0 ) then
          call HIST_in( qflx_sgs_qtrc(:,:,:,I_QV,ZDIR), 'SGS_ZFLX_QV',   'SGS Z FLUX of QV', 'kg/m2 s', dttb, zdim='half')
          call HIST_in( qflx_sgs_qtrc(:,:,:,I_QV,XDIR), 'SGS_XFLX_QV',   'SGS X FLUX of QV', 'kg/m2 s', dttb, xdim='half')
          call HIST_in( qflx_sgs_qtrc(:,:,:,I_QV,YDIR), 'SGS_YFLX_QV',   'SGS Y FLUX of QV', 'kg/m2 s', dttb, ydim='half')
       endif

       if ( I_QC > 0 ) then
          call HIST_in( qflx_sgs_qtrc(:,:,:,I_QC,ZDIR), 'SGS_ZFLX_QC',   'SGS Z FLUX of QC', 'kg/m2 s', dttb, zdim='half')
          call HIST_in( qflx_sgs_qtrc(:,:,:,I_QC,XDIR), 'SGS_XFLX_QC',   'SGS X FLUX of QC', 'kg/m2 s', dttb, xdim='half')
          call HIST_in( qflx_sgs_qtrc(:,:,:,I_QC,YDIR), 'SGS_YFLX_QC',   'SGS Y FLUX of QC', 'kg/m2 s', dttb, ydim='half')
       endif

       if ( I_QR > 0 ) then
          call HIST_in( qflx_sgs_qtrc(:,:,:,I_QR,ZDIR), 'SGS_ZFLX_QR',   'SGS Z FLUX of QR', 'kg/m2 s', dttb, zdim='half')
          call HIST_in( qflx_sgs_qtrc(:,:,:,I_QR,XDIR), 'SGS_XFLX_QR',   'SGS X FLUX of QR', 'kg/m2 s', dttb, xdim='half')
          call HIST_in( qflx_sgs_qtrc(:,:,:,I_QR,YDIR), 'SGS_YFLX_QR',   'SGS Y FLUX of QR', 'kg/m2 s', dttb, ydim='half')
       endif

    end if

    do j = JS, JE
    do i = IS, IE
    do k = KS, IE-1
       MOMZ_tp(k,i,j) = MOMZ_tp(k,i,j) + MOMZ_t(k,i,j)
    end do
    end do
    end do
    do j = JS, JE
    do i = IS, IE
    do k = KS, IE
       MOMX_tp(k,i,j) = MOMX_tp(k,i,j) + MOMX_t(k,i,j)
       MOMY_tp(k,i,j) = MOMY_tp(k,i,j) + MOMY_t(k,i,j)
       RHOT_tp(k,i,j) = RHOT_tp(k,i,j) + RHOT_t(k,i,j)
    end do
    end do
    end do

    do iq = 1, QA
    do j = JS, JE
    do i = IS, IE
    do k = KS, IE
       QTRC_tp(k,i,j,iq) = QTRC_tp(k,i,j,iq) + QTRC_t(k,i,j,iq)
    end do
    end do
    end do
    end do

    return
  end subroutine ATMOS_PHY_TB


  subroutine ATMOS_PHY_TB_main( &
       qflx_sgs_momz, qflx_sgs_momx, qflx_sgs_momy, & ! (out)
       qflx_sgs_rhot, qflx_sgs_qtrc,                & ! (out)
       tke, nu_C, Ri, Pr,                           & ! (out) diagnostic variables
       MOMZ, MOMX, MOMY, RHOT, DENS, QTRC           ) ! (in)
    use mod_const, only: &
       GRAV => CONST_GRAV
    use mod_grid, only: &
       FDZ  => GRID_FDZ,  &
       FDX  => GRID_FDX,  &
       FDY  => GRID_FDY,  &
       RCDZ => GRID_RCDZ, &
       RCDX => GRID_RCDX, &
       RCDY => GRID_RCDY, &
       RFDZ => GRID_RFDZ, &
       RFDX => GRID_RFDX, &
       RFDY => GRID_RFDY
    implicit none

    ! SGS flux
    real(RP), intent(out) :: qflx_sgs_momz(KA,IA,JA,3)
    real(RP), intent(out) :: qflx_sgs_momx(KA,IA,JA,3)
    real(RP), intent(out) :: qflx_sgs_momy(KA,IA,JA,3)
    real(RP), intent(out) :: qflx_sgs_rhot(KA,IA,JA,3)
    real(RP), intent(out) :: qflx_sgs_qtrc(KA,IA,JA,QA,3)

    real(RP), intent(out) :: tke (KA,IA,JA) ! TKE
    real(RP), intent(out) :: nu_C(KA,IA,JA) ! eddy viscosity (center)
    real(RP), intent(out) :: Pr  (KA,IA,JA) ! Prantle number
    real(RP), intent(out) :: Ri  (KA,IA,JA) ! Richardson number

    real(RP), intent(in)  :: MOMZ(KA,IA,JA)
    real(RP), intent(in)  :: MOMX(KA,IA,JA)
    real(RP), intent(in)  :: MOMY(KA,IA,JA)
    real(RP), intent(in)  :: RHOT(KA,IA,JA)
    real(RP), intent(in)  :: DENS(KA,IA,JA)
    real(RP), intent(in)  :: QTRC(KA,IA,JA,QA)

    ! diagnostic variables
    real(RP) :: VELZ_C (KA,IA,JA)
    real(RP) :: VELZ_XY(KA,IA,JA)
    real(RP) :: VELX_C (KA,IA,JA)
    real(RP) :: VELX_YZ(KA,IA,JA)
    real(RP) :: VELY_C (KA,IA,JA)
    real(RP) :: VELY_ZX(KA,IA,JA)
    real(RP) :: POTT(KA,IA,JA)

    ! deformation rate tensor
    ! (cell center)
    real(RP) :: S33_C(KA,IA,JA)
    real(RP) :: S11_C(KA,IA,JA)
    real(RP) :: S22_C(KA,IA,JA)
    real(RP) :: S31_C(KA,IA,JA)
    real(RP) :: S12_C(KA,IA,JA)
    real(RP) :: S23_C(KA,IA,JA)
    ! (z edge or x-y plane)
    real(RP) :: S33_Z(KA,IA,JA)
    real(RP) :: S11_Z(KA,IA,JA)
    real(RP) :: S22_Z(KA,IA,JA)
    real(RP) :: S31_Z(KA,IA,JA)
    real(RP) :: S12_Z(KA,IA,JA)
    real(RP) :: S23_Z(KA,IA,JA)
    ! (x edge or y-z plane)
    real(RP) :: S33_X(KA,IA,JA)
    real(RP) :: S11_X(KA,IA,JA)
    real(RP) :: S22_X(KA,IA,JA)
    real(RP) :: S31_X(KA,IA,JA)
    real(RP) :: S12_X(KA,IA,JA)
    real(RP) :: S23_X(KA,IA,JA)
    ! (y edge or z-x plane)
    real(RP) :: S33_Y(KA,IA,JA)
    real(RP) :: S11_Y(KA,IA,JA)
    real(RP) :: S22_Y(KA,IA,JA)
    real(RP) :: S31_Y(KA,IA,JA)
    real(RP) :: S12_Y(KA,IA,JA)
    real(RP) :: S23_Y(KA,IA,JA)

    real(RP) :: nu_Z(KA,IA,JA)  ! eddy viscosity (z edge or x-y plane)
    real(RP) :: nu_X(KA,IA,JA)  !                (x edge or y-z plane)
    real(RP) :: nu_Y(KA,IA,JA)  !                (y edge or z-x plane)

    real(RP) :: S2(KA,IA,JA)     ! |S|^2
    real(RP) :: WORK_V(KA,IA,JA) ! work space (vertex)
    real(RP) :: WORK_Z(KA,IA,JA) !            (z edge or x-y plane)
    real(RP) :: WORK_X(KA,IA,JA) !            (x edge or y-z plane)
    real(RP) :: WORK_Y(KA,IA,JA) !            (y edge or z-x plane)

    real(RP) :: TMP1, TMP2, TMP3

    integer :: IIS, IIE
    integer :: JJS, JJE

    integer :: k, i, j, iq
    !---------------------------------------------------------------------------

#ifdef DEBUG
    VELZ_C (:,:,:) = UNDEF
    VELZ_XY(:,:,:) = UNDEF
    VELX_C (:,:,:) = UNDEF
    VELX_YZ(:,:,:) = UNDEF
    VELY_C (:,:,:) = UNDEF
    VELY_ZX(:,:,:) = UNDEF
    POTT(:,:,:) = UNDEF

    S33_C(:,:,:) = UNDEF
    S11_C(:,:,:) = UNDEF
    S22_C(:,:,:) = UNDEF
    S31_C(:,:,:) = UNDEF
    S12_C(:,:,:) = UNDEF
    S23_C(:,:,:) = UNDEF
    S33_Z(:,:,:) = UNDEF
    S11_Z(:,:,:) = UNDEF
    S22_Z(:,:,:) = UNDEF
    S31_Z(:,:,:) = UNDEF
    S12_Z(:,:,:) = UNDEF
    S23_Z(:,:,:) = UNDEF
    S33_X(:,:,:) = UNDEF
    S11_X(:,:,:) = UNDEF
    S22_X(:,:,:) = UNDEF
    S31_X(:,:,:) = UNDEF
    S12_X(:,:,:) = UNDEF
    S23_X(:,:,:) = UNDEF
    S33_Y(:,:,:) = UNDEF
    S11_Y(:,:,:) = UNDEF
    S22_Y(:,:,:) = UNDEF
    S31_Y(:,:,:) = UNDEF
    S12_Y(:,:,:) = UNDEF
    S23_Y(:,:,:) = UNDEF

    WORK_V(:,:,:) = UNDEF
    WORK_Z(:,:,:) = UNDEF
    WORK_X(:,:,:) = UNDEF
    WORK_Y(:,:,:) = UNDEF

    S2(:,:,:) = UNDEF

    nu_C(:,:,:) = UNDEF
    nu_Z(:,:,:) = UNDEF
    nu_X(:,:,:) = UNDEF
    nu_Y(:,:,:) = UNDEF

    tke (:,:,:) = UNDEF
    Pr  (:,:,:) = UNDEF
    Ri  (:,:,:) = UNDEF

    qflx_sgs_momz(:,:,:,:) = UNDEF
    qflx_sgs_momx(:,:,:,:) = UNDEF
    qflx_sgs_momy(:,:,:,:) = UNDEF
    qflx_sgs_rhot(:,:,:,:) = UNDEF
    qflx_sgs_qtrc(:,:,:,:,:) = UNDEF
#endif


    if( IO_L ) write(IO_FID_LOG,*) '*** Physics step: SGS Parameterization'

   ! momentum -> velocity
    do j = JS-1, JE+1
    do i = IS-1, IE+1
    do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, MOMZ(k,i,j) )
       call CHECK( __LINE__, DENS(k+1,i,j) )
       call CHECK( __LINE__, DENS(k,i,j) )
#endif
       VELZ_XY(k,i,j) = 2.0_RP * MOMZ(k,i,j) / ( DENS(k+1,i,j)+DENS(k,i,j) )
    enddo
    enddo
    enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
    do j = JS-1, JE+2
    do i = IS-1, IE+2
    do k = KS+1, KE
#ifdef DEBUG
       call CHECK( __LINE__, MOMZ(k,i,j) )
       call CHECK( __LINE__, MOMZ(k-1,i,j) )
       call CHECK( __LINE__, DENS(k,i,j) )
#endif
       VELZ_C(k,i,j) = 0.5_RP * ( MOMZ(k,i,j) + MOMZ(k-1,i,j) ) / DENS(k,i,j)
    enddo
    enddo
    enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
    do j = JS-1, JE+2
    do i = IS-1, IE+2
#ifdef DEBUG
       call CHECK( __LINE__, MOMZ(KS,i,j) )
       call CHECK( __LINE__, DENS(KS,i,j) )
#endif
       VELZ_C(KS,i,j) = 0.5_RP * MOMZ(KS,i,j) / DENS(KS,i,j) ! MOMZ(KS-1,i,j) = 0
    enddo
    enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

    do j = JS-1, JE+1
    do i = IS-1, IE+1
    do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, MOMX(k,i,j) )
       call CHECK( __LINE__, DENS(k,i+1,j) )
       call CHECK( __LINE__, DENS(k,i,j) )
#endif
       VELX_YZ(k,i,j) = 2.0_RP * MOMX(k,i,j) / ( DENS(k,i+1,j)+DENS(k,i,j) )
    enddo
    enddo
    enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
    do j = JS-1, JE+1
    do i = IS-1, IE+1
       VELX_YZ(KE+1,i,j) = 0.0_RP
    enddo
    enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
    do j = JS-1, JE+2
    do i = IS-1, IE+2
    do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, MOMX(k,i,j) )
       call CHECK( __LINE__, MOMX(k,i-1,j) )
       call CHECK( __LINE__, DENS(k,i,j) )
#endif
       VELX_C(k,i,j) = 0.5_RP * ( MOMX(k,i,j) + MOMX(k,i-1,j) ) / DENS(k,i,j)
    enddo
    enddo
    enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

    do j = JS-1, JE+1
    do i = IS-1, IE+1
    do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, MOMY(k,i,j) )
       call CHECK( __LINE__, DENS(k,i,j+1) )
       call CHECK( __LINE__, DENS(k,i,j) )
#endif
       VELY_ZX(k,i,j) = 2.0_RP * MOMY(k,i,j) / ( DENS(k,i,j+1)+DENS(k,i,j) )
    enddo
    enddo
    enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
    do j = JS-1, JE+1
    do i = IS-1, IE+1
       VELY_ZX(KE+1,i,j) = 0.0_RP
    enddo
    enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
    do j = JS-1, JE+2
    do i = IS-1, IE+2
    do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, MOMY(k,i,j) )
       call CHECK( __LINE__, MOMY(k,i,j-1) )
       call CHECK( __LINE__, DENS(k,i,j) )
#endif
       VELY_C(k,i,j) = 0.5_RP * ( MOMY(k,i,j) + MOMY(k,i,j-1) ) / DENS(k,i,j)
    enddo
    enddo
    enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

    ! potential temperature
    do j = JS-1, JE+1
    do i = IS-1, IE+1
    do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, RHOT(k,i,j) )
       call CHECK( __LINE__, DENS(k,i,j) )
#endif
       POTT(k,i,j) = RHOT(k,i,j) / DENS(k,i,j)
    enddo
    enddo
    enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

    !##### Start Upadate #####

    do JJS = JS, JE, JBLOCK
    JJE = JJS+JBLOCK-1
    do IIS = IS, IE, IBLOCK
    IIE = IIS+IBLOCK-1

#ifdef DEBUG
       WORK_Z(:,:,:) = UNDEF; WORK_X(:,:,:) = UNDEF; WORK_Y(:,:,:) = UNDEF; WORK_V(:,:,:) = UNDEF
#endif
       ! w
       ! (x-y plane)
       ! WORK_Z = VELZ_XY
       ! (y-z plane)
       do j = JJS-1, JJE+1
       do i = IIS-1, IIE+1
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELZ_C(k,i+1,j) )
       call CHECK( __LINE__, VELZ_C(k,i,j) )
#endif
          WORK_X(k,i,j) = 0.5_RP * ( VELZ_C(k,i+1,j) + VELZ_C(k,i,j) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS-1, JJE+1
       do i = IIS-1, IIE+1
          WORK_X(KE+1,i,j) = 0.0_RP
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z-x plane)
       do j = JJS-1, JJE+1
       do i = IIS-1, IIE+1
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELZ_C(k,i,j+1) )
       call CHECK( __LINE__, VELZ_C(k,i,j) )
#endif
          WORK_Y(k,i,j) = 0.5_RP * ( VELZ_C(k,i,j+1) + VELZ_C(k,i,j) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS-1, JJE+1
       do i = IIS-1, IIE+1
          WORK_Y(KE+1,i,j) = 0.0_RP
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (vertex)
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELZ_XY(k,i,j) )
       call CHECK( __LINE__, VELZ_XY(k,i+1,j) )
       call CHECK( __LINE__, VELZ_XY(k,i,j+1) )
       call CHECK( __LINE__, VELZ_XY(k,i+1,j+1) )
#endif
          WORK_V(k,i,j) = 0.25_RP * ( VELZ_XY(k,i,j) + VELZ_XY(k,i+1,j) + VELZ_XY(k,i,j+1) + VELZ_XY(k,i+1,j+1) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! dw/dz
       ! (cell center)
       do j = JJS, JJE+1
       do i = IIS, IIE+1
       do k = KS+1, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELZ_XY(k,i,j) )
       call CHECK( __LINE__, VELZ_XY(k-1,i,j) )
       call CHECK( __LINE__, RCDZ(k) )
#endif
          S33_C(k,i,j) = ( VELZ_XY(k,i,j) - VELZ_XY(k-1,i,j) ) * RCDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS, JJE+1
       do i = IIS, IIE+1
#ifdef DEBUG
       call CHECK( __LINE__, VELZ_XY(KS,i,j) )
       call CHECK( __LINE__, RCDZ(KS) )
#endif
          S33_C(KS,i,j) = VELZ_XY(KS,i,j) * RCDZ(KS) ! VELZ_XY(KS-1,i,j) == 0
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z edge)
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS+1, KE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_V(k,i,j) )
       call CHECK( __LINE__, WORK_V(k-1,i,j) )
       call CHECK( __LINE__, RCDZ(k) )
#endif
          S33_Z(k,i,j) = ( WORK_V(k,i,j) - WORK_V(k-1,i,j) ) * RCDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS-1, JJE
       do i = IIS-1, IIE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_V(KS,i,j) )
       call CHECK( __LINE__, RCDZ(KS) )
#endif
          S33_Z(KS,i,j) = WORK_V(KS,i,j) * RCDZ(KS) ! WORK_V(KS-1,i,j) == 0
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (x edge)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Y(k+1,i,j) )
       call CHECK( __LINE__, WORK_Y(k,i,j) )
       call CHECK( __LINE__, RFDZ(k) )
#endif
          S33_X(k,i,j) = ( WORK_Y(k+1,i,j) - WORK_Y(k,i,j) ) * RFDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y edge)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_X(k+1,i,j) )
       call CHECK( __LINE__, WORK_X(k,i,j) )
       call CHECK( __LINE__, RFDZ(k) )
#endif
          S33_Y(k,i,j) = ( WORK_X(k+1,i,j) - WORK_X(k,i,j) ) * RFDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! 1/2 * dw/dx
       ! (cell center)
       do j = JJS, JJE+1
       do i = IIS, IIE+1
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELZ_C(k,i+1,j) )
       call CHECK( __LINE__, VELZ_C(k,i-1,j) )
       call CHECK( __LINE__, FDX(i) )
       call CHECK( __LINE__, FDX(i-1) )
#endif
          S31_C(k,i,j) = 0.5_RP * ( VELZ_C(k,i+1,j) - VELZ_C(k,i-1,j) ) / ( FDX(i) + FDX(i-1) )
       enddo
       enddo
       enddo
       ! (z edge)
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Y(k,i+1,j) )
       call CHECK( __LINE__, WORK_Y(k,i,j) )
       call CHECK( __LINE__, RFDX(i) )
#endif
          S31_Z(k,i,j) = 0.5_RP * ( WORK_Y(k,i+1,j) - WORK_Y(k,i,j) ) * RFDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (x edge)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_V(k,i,j) )
       call CHECK( __LINE__, WORK_V(k,i-1,j) )
       call CHECK( __LINE__, RCDX(i) )
#endif
          S31_X(k,i,j) = 0.5_RP * ( WORK_V(k,i,j) - WORK_V(k,i-1,j) ) * RCDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y edge)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, VELZ_XY(k,i+1,j) )
       call CHECK( __LINE__, VELZ_XY(k,i,j) )
       call CHECK( __LINE__, RFDX(i) )
#endif
          S31_Y(k,i,j) = 0.5_RP * ( VELZ_XY(k,i+1,j) - VELZ_XY(k,i,j) ) * RFDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! 1/2 * dw/dy
       ! (cell center)
       do j = JJS, JJE+1
       do i = IIS, IIE+1
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELZ_C(k,i,j+1) )
       call CHECK( __LINE__, VELZ_C(k,i,j-1) )
       call CHECK( __LINE__, FDY(j) )
       call CHECK( __LINE__, FDY(j-1) )
#endif
          S23_C(k,i,j) = 0.5_RP * ( VELZ_C(k,i,j+1) - VELZ_C(k,i,j-1) ) / ( FDY(j) + FDY(j-1) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z edge)
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_X(k,i,j+1) )
       call CHECK( __LINE__, WORK_X(k,i,j) )
       call CHECK( __LINE__, RFDY(j) )
#endif
          S23_Z(k,i,j) = 0.5_RP * ( WORK_X(k,i,j+1) - WORK_X(k,i,j) ) * RFDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (x edge)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, VELZ_XY(k,i,j+1) )
       call CHECK( __LINE__, VELZ_XY(k,i,j) )
       call CHECK( __LINE__, RFDY(j) )
#endif
          S23_X(k,i,j) = 0.5_RP * ( VELZ_XY(k,i,j+1) - VELZ_XY(k,i,j) ) * RFDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y edge)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_V(k,i,j) )
       call CHECK( __LINE__, WORK_V(k,i,j-1) )
       call CHECK( __LINE__, RCDY(j) )
#endif
          S23_Y(k,i,j) = 0.5_RP * ( WORK_V(k,i,j) - WORK_V(k,i,j-1) ) * RCDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif


#ifdef DEBUG
       WORK_Z(:,:,:) = UNDEF; WORK_X(:,:,:) = UNDEF; WORK_Y(:,:,:) = UNDEF; WORK_V(:,:,:) = UNDEF
#endif
       ! u
       ! (x-y plane)
       do j = JJS-1, JJE+1
       do i = IIS-1, IIE+1
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, VELX_C(k+1,i,j) )
       call CHECK( __LINE__, VELX_C(k,i,j) )
#endif
          WORK_Z(k,i,j) = 0.5_RP * ( VELX_C(k+1,i,j) + VELX_C(k,i,j) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y-z plane)
       ! WORK_X = VELX_YZ
       ! (z-x plane)
       do j = JJS-1, JJE
       do i = IIS-1, IIE+1
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELX_C(k,i,j+1) )
       call CHECK( __LINE__, VELX_C(k,i,j) )
#endif
          WORK_Y(k,i,j) = 0.5_RP * ( VELX_C(k,i,j+1) + VELX_C(k,i,j) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (vertex)
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, VELX_YZ(k,i,j) )
       call CHECK( __LINE__, VELX_YZ(k,i,j+1) )
       call CHECK( __LINE__, VELX_YZ(k+1,i,j) )
       call CHECK( __LINE__, VELX_YZ(k+1,i,j+1) )
#endif
          WORK_V(k,i,j) = 0.25_RP * ( VELX_YZ(k,i,j) + VELX_YZ(k,i,j+1) + VELX_YZ(k+1,i,j) + VELX_YZ(k+1,i,j+1) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! du/dx
       ! (cell center)
       do j = JJS, JJE+1
       do i = IIS, IIE+1
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELX_YZ(k,i,j) )
       call CHECK( __LINE__, VELX_YZ(k,i-1,j) )
       call CHECK( __LINE__, RCDX(i) )
#endif
          S11_C(k,i,j) = ( VELX_YZ(k,i,j) - VELX_YZ(k,i-1,j) ) * RCDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z edge)
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Y(k,i+1,j) )
       call CHECK( __LINE__, WORK_Y(k,i,j) )
       call CHECK( __LINE__, RFDX(i) )
#endif
          S11_Z(k,i,j) = ( WORK_Y(k,i+1,j) - WORK_Y(k,i,j) ) * RFDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (x edge)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_V(k,i,j) )
       call CHECK( __LINE__, WORK_V(k,i-1,j) )
       call CHECK( __LINE__, RCDX(i) )
#endif
          S11_X(k,i,j) = ( WORK_V(k,i,j) - WORK_V(k,i-1,j) ) * RCDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y edge)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Z(k,i+1,j) )
       call CHECK( __LINE__, WORK_Z(k,i,j) )
       call CHECK( __LINE__, RFDX(i) )
#endif
          S11_Y(k,i,j) = ( WORK_Z(k,i+1,j) - WORK_Z(k,i,j) ) * RFDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! 1/2 * du/dz
       ! (cell center)
       do j = JJS, JJE+1
       do i = IIS, IIE+1
       do k = KS+1, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S31_C(k,i,j) )
       call CHECK( __LINE__, VELX_C(k+1,i,j) )
       call CHECK( __LINE__, VELX_C(k-1,i,j) )
       call CHECK( __LINE__, FDZ(k) )
       call CHECK( __LINE__, FDZ(k-1) )
#endif
          S31_C(k,i,j) = S31_C(k,i,j) + &
               0.5_RP * ( VELX_C(k+1,i,j) - VELX_C(k-1,i,j) ) / ( FDZ(k) + FDZ(k-1) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS, JJE+1
       do i = IIS, IIE+1
#ifdef DEBUG
       call CHECK( __LINE__, S31_C(KS,i,j) )
       call CHECK( __LINE__, VELX_C(KS+1,i,j) )
       call CHECK( __LINE__, VELX_C(KS,i,j) )
       call CHECK( __LINE__, RFDZ(KS) )
#endif
          S31_C(KS,i,j) = S31_C(KS,i,j) + &
               0.5_RP * ( VELX_C(KS+1,i,j) - VELX_C(KS,i,j) ) * RFDZ(KS)
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS, JJE+1
       do i = IIS, IIE+1
#ifdef DEBUG
       call CHECK( __LINE__, S31_C(KE,i,j) )
       call CHECK( __LINE__, VELX_C(KE,i,j) )
       call CHECK( __LINE__, VELX_C(KE-1,i,j) )
       call CHECK( __LINE__, RFDZ(KE-1) )
#endif
          S31_C(KE,i,j) = S31_C(KE,i,j) + &
               0.5_RP * ( VELX_C(KE,i,j) - VELX_C(KE-1,i,j) ) * RFDZ(KE-1)
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z edge)
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS+1, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S31_Z(k,i,j) )
       call CHECK( __LINE__, WORK_V(k,i,j) )
       call CHECK( __LINE__, WORK_V(k-1,i,j) )
       call CHECK( __LINE__, RCDZ(k) )
#endif
          S31_Z(k,i,j) = S31_Z(k,i,j) + &
               0.5_RP * ( WORK_V(k,i,j) - WORK_V(k-1,i,j) ) * RCDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS-1, JJE
       do i = IIS-1, IIE
#ifdef DEBUG
       call CHECK( __LINE__, S31_Z(KS,i,j) )
       call CHECK( __LINE__, VELX_YZ(KS+1,i,j  ) )
       call CHECK( __LINE__, VELX_YZ(KS+1,i,j+1) )
       call CHECK( __LINE__, VELX_YZ(KS  ,i,j  ) )
       call CHECK( __LINE__, VELX_YZ(KS  ,i,j+1) )
       call CHECK( __LINE__, RCDZ(KS) )
#endif
          S31_Z(KS,i,j) = S31_Z(KS,i,j) + &
               0.25_RP * ( VELX_YZ(KS+1,i,j) + VELX_YZ(KS+1,i,j+1) &
                         - VELX_YZ(KS  ,i,j) - VELX_YZ(KS  ,i,j+1) ) * RFDZ(KS)
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS-1, JJE
       do i = IIS-1, IIE
#ifdef DEBUG
       call CHECK( __LINE__, S31_Z(KE,i,j) )
       call CHECK( __LINE__, VELX_YZ(KE  ,i,j  ) )
       call CHECK( __LINE__, VELX_YZ(KE  ,i,j+1) )
       call CHECK( __LINE__, VELX_YZ(KE-1,i,j  ) )
       call CHECK( __LINE__, VELX_YZ(KE-1,i,j+1) )
       call CHECK( __LINE__, RFDZ(KE) )
#endif
          S31_Z(KE,i,j) = S31_Z(KE,i,j) + &
               0.25_RP * ( VELX_YZ(KE  ,i,j) + VELX_YZ(KE  ,i,j+1) &
                         - VELX_YZ(KE-1,i,j) - VELX_YZ(KE-1,i,j+1) ) * RFDZ(KE-1)
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (x edge)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S31_X(k,i,j) )
       call CHECK( __LINE__, VELX_C(k+1,i,j+1) )
       call CHECK( __LINE__, VELX_C(k+1,i,j) )
       call CHECK( __LINE__, VELX_C(k,i,j+1) )
       call CHECK( __LINE__, VELX_C(k,i,j) )
       call CHECK( __LINE__, RFDZ(k) )
#endif
          S31_X(k,i,j) = S31_X(k,i,j) + &
               0.25_RP * ( VELX_C(k+1,i,j+1) + VELX_C(k+1,i,j) - VELX_C(k,i,j+1) - VELX_C(k,i,j) ) * RFDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y edge)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S31_Y(k,i,j) )
       call CHECK( __LINE__, VELX_YZ(k+1,i,j) )
       call CHECK( __LINE__, VELX_YZ(k,i,j) )
       call CHECK( __LINE__, RFDZ(k) )
#endif
          S31_Y(k,i,j) = S31_Y(k,i,j) + &
               0.5_RP * ( VELX_YZ(k+1,i,j) - VELX_YZ(k,i,j) ) * RFDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! 1/2 * du/dy
       ! (cell center)
       do j = JJS, JJE+1
       do i = IIS, IIE+1
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELX_C(k,i,j+1) )
       call CHECK( __LINE__, VELX_C(k,i,j-1) )
       call CHECK( __LINE__, FDY(j) )
       call CHECK( __LINE__, FDY(j-1) )
#endif
          S12_C(k,i,j) = 0.5_RP * ( VELX_C(k,i,j+1) - VELX_C(k,i,j-1) ) / ( FDY(j) + FDY(j-1) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z edge)
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELX_YZ(k,i,j+1) )
       call CHECK( __LINE__, VELX_YZ(k,i,j) )
       call CHECK( __LINE__, RFDY(j) )
#endif
          S12_Z(k,i,j) = 0.5_RP * ( VELX_YZ(k,i,j+1) - VELX_YZ(k,i,j) ) * RFDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (x edge)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Z(k,i,j+1) )
       call CHECK( __LINE__, WORK_Z(k,i,j) )
       call CHECK( __LINE__, RFDY(j) )
#endif
          S12_X(k,i,j) = 0.5_RP * ( WORK_Z(k,i,j+1) - WORK_Z(k,i,j) ) * RFDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y edge)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_V(k,i,j) )
       call CHECK( __LINE__, WORK_V(k,i,j-1) )
       call CHECK( __LINE__, RFDY(j) )
#endif
          S12_Y(k,i,j) = 0.5_RP * ( WORK_V(k,i,j) - WORK_V(k,i,j-1) ) * RCDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif


#ifdef DEBUG
       WORK_Z(:,:,:) = UNDEF; WORK_X(:,:,:) = UNDEF; WORK_Y(:,:,:) = UNDEF; WORK_V(:,:,:) = UNDEF
#endif
       ! v
       ! (x-y plane)
       do j = JJS-1, JJE+1
       do i = IIS-1, IIE+1
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, VELY_C(k+1,i,j) )
       call CHECK( __LINE__, VELY_C(k,i,j) )
#endif
          WORK_Z(k,i,j) = 0.5_RP * ( VELY_C(k+1,i,j) + VELY_C(k,i,j) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y-z plane)
       do j = JJS-1, JJE+1
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELY_C(k,i+1,j) )
       call CHECK( __LINE__, VELY_C(k,i,j) )
#endif
          WORK_X(k,i,j) = 0.5_RP * ( VELY_C(k,i+1,j) + VELY_C(k,i,j) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z-x plane)
       ! WORK_Y = VELY_ZX
       ! (vertex)
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, VELY_ZX(k,i,j) )
       call CHECK( __LINE__, VELY_ZX(k+1,i,j) )
       call CHECK( __LINE__, VELY_ZX(k,i+1,j) )
       call CHECK( __LINE__, VELY_ZX(k+1,i+1,j) )
#endif
          WORK_V(k,i,j) = 0.25_RP * ( VELY_ZX(k,i,j) + VELY_ZX(k+1,i,j) + VELY_ZX(k,i+1,j) + VELY_ZX(k+1,i+1,j) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! dv/dy
       ! (cell center)
       do j = JJS, JJE+1
       do i = IIS, IIE+1
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELY_ZX(k,i,j) )
       call CHECK( __LINE__, VELY_ZX(k,i,j-1) )
       call CHECK( __LINE__, RCDY(j) )
#endif
          S22_C(k,i,j) = ( VELY_ZX(k,i,j) - VELY_ZX(k,i,j-1) ) * RCDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z edge)
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_X(k,i,j+1) )
       call CHECK( __LINE__, WORK_X(k,i,j) )
       call CHECK( __LINE__, RFDY(j) )
#endif
          S22_Z(k,i,j) = ( WORK_X(k,i,j+1) - WORK_X(k,i,j) ) * RFDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (x edge)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Z(k,i,j+1) )
       call CHECK( __LINE__, WORK_Z(k,i,j) )
       call CHECK( __LINE__, RFDY(j) )
#endif
          S22_X(k,i,j) = ( WORK_Z(k,i,j+1) - WORK_Z(k,i,j) ) * RFDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y edge)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_V(k,i,j) )
       call CHECK( __LINE__, WORK_V(k,i,j-1) )
       call CHECK( __LINE__, RCDY(j) )
#endif
          S22_Y(k,i,j) = ( WORK_V(k,i,j) - WORK_V(k,i,j-1) ) * RCDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! 1/2 * dv/dx
       ! (cell center)
       do j = JJS, JJE+1
       do i = IIS, IIE+1
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, S12_C(k,i,j) )
       call CHECK( __LINE__, VELY_C(k,i-1,j) )
       call CHECK( __LINE__, FDX(i) )
       call CHECK( __LINE__, FDX(i-1) )
#endif
          S12_C(k,i,j) = S12_C(k,i,j) + &
               0.5_RP * ( VELY_C(k,i+1,j) - VELY_C(k,i-1,j) ) / ( FDX(i) + FDX(i-1) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z edge)
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, S12_Z(k,i,j) )
       call CHECK( __LINE__, VELY_ZX(k,i+1,j) )
       call CHECK( __LINE__, VELY_ZX(k,i,j) )
       call CHECK( __LINE__, RFDX(i) )
#endif
          S12_Z(k,i,j) = S12_Z(k,i,j) + &
               0.5_RP * ( VELY_ZX(k,i+1,j) - VELY_ZX(k,i,j) ) * RFDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (x edge)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S12_X(k,i,j) )
       call CHECK( __LINE__, WORK_V(k,i,j) )
       call CHECK( __LINE__, WORK_V(k,i-1,j) )
       call CHECK( __LINE__, RCDX(i) )
#endif
          S12_X(k,i,j) = S12_X(k,i,j) + &
               0.5_RP * ( WORK_V(k,i,j) - WORK_V(k,i-1,j) ) * RCDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y edge)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S12_Y(k,i,j) )
       call CHECK( __LINE__, WORK_Z(k,i+1,j) )
       call CHECK( __LINE__, WORK_Z(k,i,j) )
       call CHECK( __LINE__, RFDX(i) )
#endif
          S12_Y(k,i,j) = S12_Y(k,i,j) + &
               0.5_RP * ( WORK_Z(k,i+1,j) - WORK_Z(k,i,j) ) * RFDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! 1/2 * dv/dz
       ! (cell center)
       do j = JJS, JJE+1
       do i = IIS, IIE+1
       do k = KS+1, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S23_C(k,i,j) )
       call CHECK( __LINE__, VELY_C(k+1,i,j) )
       call CHECK( __LINE__, VELY_C(k-1,i,j) )
       call CHECK( __LINE__, FDZ(k) )
       call CHECK( __LINE__, FDZ(k-1) )
#endif
          S23_C(k,i,j) = S23_C(k,i,j) + &
               0.5_RP * ( VELY_C(k+1,i,j) - VELY_C(k-1,i,j) ) / ( FDZ(k) + FDZ(k-1) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS, JJE+1
       do i = IIS, IIE+1
#ifdef DEBUG
       call CHECK( __LINE__, S23_C(KS,i,j) )
       call CHECK( __LINE__, VELY_C(KS+1,i,j) )
       call CHECK( __LINE__, VELY_C(KS,i,j) )
       call CHECK( __LINE__, RFDZ(KS) )
#endif
          S23_C(KS,i,j) = S23_C(KS,i,j) + &
               0.5_RP * ( VELY_C(KS+1,i,j) - VELY_C(KS,i,j) ) * RFDZ(KS)
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS, JJE+1
       do i = IIS, IIE+1
#ifdef DEBUG
       call CHECK( __LINE__, S23_C(KE,i,j) )
       call CHECK( __LINE__, VELY_C(KE,i,j) )
       call CHECK( __LINE__, VELY_C(KE-1,i,j) )
       call CHECK( __LINE__, RFDZ(KE-1) )
#endif
          S23_C(KE,i,j) = S23_C(KE,i,j) + &
               0.5_RP * ( VELY_C(KE,i,j) - VELY_C(KE-1,i,j) ) * RFDZ(KE-1)
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z edge)
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS+1, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S23_Z(k,i,j) )
       call CHECK( __LINE__, WORK_V(k,i,j) )
       call CHECK( __LINE__, WORK_V(k-1,i,j) )
       call CHECK( __LINE__, RCDZ(k) )
#endif
          S23_Z(k,i,j) = S23_Z(k,i,j) + &
               0.5_RP * ( WORK_V(k,i,j) - WORK_V(k-1,i,j) ) * RCDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS-1, JJE
       do i = IIS-1, IIE
#ifdef DEBUG
       call CHECK( __LINE__, S23_Z(KS,i,j) )
       call CHECK( __LINE__, VELY_ZX(KS+1,i,j) )
       call CHECK( __LINE__, VELY_ZX(KS+1,i+1,j) )
       call CHECK( __LINE__, VELY_ZX(KS,i,j) )
       call CHECK( __LINE__, VELY_ZX(KS,i+1,j) )
       call CHECK( __LINE__, RCDZ(KS) )
#endif
          S23_Z(KS,i,j) = S23_Z(KS,i,j) + &
               0.25_RP * ( VELY_ZX(KS+1,i,j) + VELY_ZX(KS+1,i+1,j) &
                         - VELY_ZX(KS  ,i,j) - VELY_ZX(KS  ,i+1,j) ) * RFDZ(KS)
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS-1, JJE
       do i = IIS-1, IIE
#ifdef DEBUG
       call CHECK( __LINE__, S23_Z(KE,i,j) )
       call CHECK( __LINE__, VELY_ZX(KE,i,j) )
       call CHECK( __LINE__, VELY_ZX(KE,i+1,j) )
       call CHECK( __LINE__, VELY_ZX(KE-1,i,j) )
       call CHECK( __LINE__, VELY_ZX(KE-1,i+1,j) )
       call CHECK( __LINE__, RCDZ(KE-1) )
#endif
          S23_Z(KE,i,j) = S23_Z(KE,i,j) + &
               0.25_RP * ( VELY_ZX(KE  ,i,j) + VELY_ZX(KE  ,i+1,j) &
                         - VELY_ZX(KE-1,i,j) - VELY_ZX(KE-1,i+1,j) ) * RCDZ(KE-1)
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (x edge)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S23_X(k,i,j) )
       call CHECK( __LINE__, VELY_ZX(k+1,i,j) )
       call CHECK( __LINE__, VELY_ZX(k,i,j) )
       call CHECK( __LINE__, RFDZ(k) )
#endif
          S23_X(k,i,j) = S23_X(k,i,j) + &
               0.5_RP * ( VELY_ZX(k+1,i,j) - VELY_ZX(k,i,j) ) * RFDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y edge)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S23_Y(k,i,j) )
       call CHECK( __LINE__, WORK_X(k+1,i,j) )
       call CHECK( __LINE__, WORK_X(k,i,j) )
       call CHECK( __LINE__, RFDZ(k) )
#endif
          S23_Y(k,i,j) = S23_Y(k,i,j) + &
               0.5_RP * ( WORK_X(k+1,i,j) - WORK_X(k,i,j) ) * RFDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif


       ! nu_SGS = (Cs * Delta)^2 * |S|, |S|^2 = 2*Sij*Sij
       ! tke = ( nu / ( Ck*Delta ) )^2
#ifdef DEBUG
       S2(:,:,:) = UNDEF
       WORK_Z(:,:,:) = UNDEF; WORK_X(:,:,:) = UNDEF; WORK_Y(:,:,:) = UNDEF
#endif
       ! (cell center)
       do j = JJS, JJE+1
       do i = IIS, IIE+1
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, S11_C(k,i,j) )
       call CHECK( __LINE__, S22_C(k,i,j) )
       call CHECK( __LINE__, S33_C(k,i,j) )
       call CHECK( __LINE__, S31_C(k,i,j) )
       call CHECK( __LINE__, S12_C(k,i,j) )
       call CHECK( __LINE__, S23_C(k,i,j) )
#endif
          S2(k,i,j) = &
                 2.0_RP * ( S11_C(k,i,j)**2 + S22_C(k,i,j)**2 + S33_C(k,i,j)**2 ) &
               + 4.0_RP * ( S31_C(k,i,j)**2 + S12_C(k,i,j)**2 + S23_C(k,i,j)**2 )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! Ri = N^2 / |S|^2, N^2 = g / theta * dtheta/dz
       do j = JJS, JJE+1
       do i = IIS, IIE+1
       do k = KS+1, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, POTT(k+1,i,j) )
       call CHECK( __LINE__, POTT(k,i,j) )
       call CHECK( __LINE__, POTT(k-1,i,j) )
       call CHECK( __LINE__, FDZ(k) )
       call CHECK( __LINE__, FDZ(k-1) )
       call CHECK( __LINE__, S2(k,i,j) )
#endif
          Ri(k,i,j) = GRAV * ( POTT(k+1,i,j) - POTT(k-1,i,j) ) &
               / ( ( FDZ(k) + FDZ(k-1) ) * POTT(k,i,j) * max(S2(k,i,j),1.0E-20_RP) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS, JJE+1
       do i = IIS, IIE+1
#ifdef DEBUG
       call CHECK( __LINE__, POTT(KS+1,i,j) )
       call CHECK( __LINE__, POTT(KS,i,j) )
       call CHECK( __LINE__, RFDZ(KS) )
       call CHECK( __LINE__, S2(KS,i,j) )
#endif
          Ri(KS,i,j) = GRAV * ( POTT(KS+1,i,j) - POTT(KS,i,j) ) &
               * RFDZ(KS) / (POTT(KS,i,j) * max(S2(KS,i,j),1.0E-20_RP) )
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS, JJE+1
       do i = IIS, IIE+1
#ifdef DEBUG
       call CHECK( __LINE__, POTT(KE,i,j) )
       call CHECK( __LINE__, POTT(KE-1,i,j) )
       call CHECK( __LINE__, RFDZ(KE-1) )
       call CHECK( __LINE__, S2(KE,i,j) )
#endif
          Ri(KE,i,j) = GRAV * ( POTT(KE,i,j) - POTT(KE-1,i,j) ) &
               * RFDZ(KE-1) / (POTT(KE,i,j) * max(S2(KE,i,j),1.0E-20_RP) )
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS, JJE+1
       do i = IIS, IIE+1
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, Ri(k,i,j) )
       call CHECK( __LINE__, nu_factC(k,i,j) )
       call CHECK( __LINE__, S2(k,i,j) )
#endif
          if ( Ri(k,i,j) < 0.0_RP ) then ! stable
             nu_C(k,i,j) = nu_factC(k,i,j) &
                  * sqrt( S2(k,i,j) * (1.0_RP - FmC*Ri(k,i,j)) )
          else if ( Ri(k,i,j) < RiC ) then ! weakly stable
             nu_C(k,i,j) = nu_factC(k,i,j) &
                  * sqrt( S2(k,i,j) ) * ( 1.0_RP - Ri(k,i,j)*RRiC )**4
          else ! strongly stable
             nu_C(k,i,j) = 0.0_RP
          endif
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! tke = (nu/(Ck * Delta))^2 = ( nu * Cs / Ck )^2 / ( Cs * Delta )^2
       do j = JJS, JJE+1
       do i = IIS, IIE+1
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, nu_C(k,i,j) )
       call CHECK( __LINE__, nu_factC(k,i,j) )
#endif
          tke(k,i,j) = ( nu_C(k,i,j) * Cs / Ck )**2 / nu_factC(k,i,j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! Pr = nu_m / nu_h = fm / fh
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, Ri(k,i,j) )
#endif
          if ( Ri(k,i,j) < 0.0_RP ) then ! stable
             Pr(k,i,j) = sqrt( ( 1.0_RP - FmC*Ri(k,i,j) )  &
                             / ( 1.0_RP - FhB*Ri(k,i,j) ) ) * PrN
          else if ( Ri(k,i,j) < RiC ) then ! weakly stable
             Pr(k,i,j) = PrN / ( 1.0_RP - PrNovRiC * Ri(k,i,j) )
          else ! strongly stable
             Pr(k,i,j) = 1.0_RP
          endif
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

#ifdef DEBUG
       S2(:,:,:) = UNDEF
       WORK_Z(:,:,:) = UNDEF; WORK_X(:,:,:) = UNDEF; WORK_Y(:,:,:) = UNDEF
#endif
       ! (z edge)
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, S11_Z(k,i,j) )
       call CHECK( __LINE__, S22_Z(k,i,j) )
       call CHECK( __LINE__, S33_Z(k,i,j) )
       call CHECK( __LINE__, S31_Z(k,i,j) )
       call CHECK( __LINE__, S12_Z(k,i,j) )
       call CHECK( __LINE__, S23_Z(k,i,j) )
#endif
          S2(k,i,j) = &
                 2.0_RP * ( S11_Z(k,i,j)**2 + S22_Z(k,i,j)**2 + S33_Z(k,i,j)**2 ) &
               + 4.0_RP * ( S31_Z(k,i,j)**2 + S12_Z(k,i,j)**2 + S23_Z(k,i,j)**2 )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! Ri
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS+1, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, POTT(k+1,i,j) )
       call CHECK( __LINE__, POTT(k+1,i+1,j) )
       call CHECK( __LINE__, POTT(k+1,i,j+1) )
       call CHECK( __LINE__, POTT(k+1,i+1,j+1) )
       call CHECK( __LINE__, POTT(k,i,j) )
       call CHECK( __LINE__, POTT(k,i+1,j) )
       call CHECK( __LINE__, POTT(k,i,j+1) )
       call CHECK( __LINE__, POTT(k,i+1,j+1) )
       call CHECK( __LINE__, POTT(k-1,i,j) )
       call CHECK( __LINE__, POTT(k-1,i+1,j) )
       call CHECK( __LINE__, POTT(k-1,i,j+1) )
       call CHECK( __LINE__, POTT(k-1,i+1,j+1) )
       call CHECK( __LINE__, FDZ(k) )
       call CHECK( __LINE__, FDZ(k-1) )
       call CHECK( __LINE__, S2(k,i,j) )
#endif
          TMP1 = ( POTT(k+1,i,j) + POTT(k+1,i+1,j) + POTT(k+1,i,j+1) + POTT(k+1,i+1,j+1) ) * 0.25_RP
          TMP2 = ( POTT(k  ,i,j) + POTT(k  ,i+1,j) + POTT(k  ,i,j+1) + POTT(k  ,i+1,j+1) ) * 0.25_RP
          TMP3 = ( POTT(k-1,i,j) + POTT(k-1,i+1,j) + POTT(k-1,i,j+1) + POTT(k-1,i+1,j+1) ) * 0.25_RP
          WORK_Z(k,i,j) = GRAV * ( TMP1 - TMP3 ) &
               / ( ( FDZ(k) + FDZ(k-1) ) * TMP2 * max(S2(k,i,j),1.0E-20_RP) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS-1, JJE
       do i = IIS-1, IIE
#ifdef DEBUG
       call CHECK( __LINE__, POTT(KE,i,j) )
       call CHECK( __LINE__, POTT(KE,i+1,j) )
       call CHECK( __LINE__, POTT(KE,i,j+1) )
       call CHECK( __LINE__, POTT(KE,i+1,j+1) )
       call CHECK( __LINE__, POTT(KE-1,i,j) )
       call CHECK( __LINE__, POTT(KE-1,i+1,j) )
       call CHECK( __LINE__, POTT(KE-1,i,j+1) )
       call CHECK( __LINE__, POTT(KE-1,i+1,j+1) )
       call CHECK( __LINE__, RFDZ(KE-1) )
       call CHECK( __LINE__, S2(KE,i,j) )
#endif
          TMP2 = ( POTT(KE  ,i,j) + POTT(KE  ,i+1,j) + POTT(KE  ,i,j+1) + POTT(KE  ,i+1,j+1) ) * 0.25_RP
          TMP3 = ( POTT(KE-1,i,j) + POTT(KE-1,i+1,j) + POTT(KE-1,i,j+1) + POTT(KE-1,i+1,j+1) ) * 0.25_RP
          WORK_Z(KE,i,j) = 0.5_RP * GRAV * ( TMP2 - TMP3 ) &
               * RFDZ(KE-1) / ( TMP2 * max(S2(KE,i,j),1.0E-20_RP) )
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS-1, JJE
       do i = IIS-1, IIE
#ifdef DEBUG
       call CHECK( __LINE__, POTT(KS+1,i,j) )
       call CHECK( __LINE__, POTT(KS+1,i+1,j) )
       call CHECK( __LINE__, POTT(KS+1,i,j+1) )
       call CHECK( __LINE__, POTT(KS+1,i+1,j+1) )
       call CHECK( __LINE__, POTT(KS,i,j) )
       call CHECK( __LINE__, POTT(KS,i+1,j) )
       call CHECK( __LINE__, POTT(KS,i,j+1) )
       call CHECK( __LINE__, POTT(KS,i+1,j+1) )
       call CHECK( __LINE__, RFDZ(KS-1) )
       call CHECK( __LINE__, S2(KS,i,j) )
#endif
          TMP1 = ( POTT(KS+1,i,j) + POTT(KS+1,i+1,j) + POTT(KS+1,i,j+1) + POTT(KS+1,i+1,j+1) ) * 0.25_RP
          TMP2 = ( POTT(KS  ,i,j) + POTT(KS  ,i+1,j) + POTT(KS  ,i,j+1) + POTT(KS  ,i+1,j+1) ) * 0.25_RP
          WORK_Z(KS,i,j) = 0.5_RP * GRAV * ( TMP1 - TMP2 ) &
               * RFDZ(KS) / ( TMP2 * max(S2(KS,i,j),1.0E-20_RP) )
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Z(k,i,j) )
       call CHECK( __LINE__, nu_factZ(k,i,j) )
       call CHECK( __LINE__, S2(k,i,j) )
#endif
          if ( WORK_Z(k,i,j) < 0.0_RP ) then
             nu_Z(k,i,j) = nu_factZ(k,i,j) &
                  * sqrt( S2(k,i,j) * (1.0_RP - FmC*WORK_Z(k,i,j)) )
          else if ( WORK_Z(k,i,j) < RiC ) then
             nu_Z(k,i,j) = nu_factZ(k,i,j) &
                  * sqrt( S2(k,i,j) ) * ( 1.0_RP - WORK_Z(k,i,j)*RRiC )**4
          else
             nu_Z(k,i,j) = 0.0_RP
          endif
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
#ifdef DEBUG
       S2(:,:,:) = UNDEF
       WORK_Z(:,:,:) = UNDEF; WORK_X(:,:,:) = UNDEF; WORK_Y(:,:,:) = UNDEF
#endif
       ! (x edge)
       do j = JJS-1, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S11_X(k,i,j) )
       call CHECK( __LINE__, S22_X(k,i,j) )
       call CHECK( __LINE__, S33_X(k,i,j) )
       call CHECK( __LINE__, S31_X(k,i,j) )
       call CHECK( __LINE__, S12_X(k,i,j) )
       call CHECK( __LINE__, S23_X(k,i,j) )
#endif
          S2(k,i,j) = &
                 2.0_RP * ( S11_X(k,i,j)**2 + S22_X(k,i,j)**2 + S33_X(k,i,j)**2 ) &
               + 4.0_RP * ( S31_X(k,i,j)**2 + S12_X(k,i,j)**2 + S23_X(k,i,j)**2 )
       enddo
       enddo
       enddo

#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! Ri
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, POTT(k+1,i,j) )
       call CHECK( __LINE__, POTT(k+1,i,j+1) )
       call CHECK( __LINE__, POTT(k,i,j) )
       call CHECK( __LINE__, POTT(k,i,j+1) )
       call CHECK( __LINE__, RFDZ(k) )
       call CHECK( __LINE__, S2(k,i,j) )
#endif
          TMP1 = ( POTT(k+1,i,j) + POTT(k+1,i,j+1) ) * 0.5_RP
          TMP2 = ( POTT(k  ,i,j) + POTT(k  ,i,j+1) ) * 0.5_RP
          WORK_X(k,i,j) = 2.0_RP * GRAV * ( TMP1 - TMP2 ) &
               * RFDZ(k) / ( ( TMP1 + TMP2 ) * max(S2(k,i,j),1.0E-20_RP) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_X(k,i,j) )
       call CHECK( __LINE__, nu_factX(k,i,j) )
       call CHECK( __LINE__, S2(k,i,j) )
#endif
          if ( WORK_X(k,i,j) < 0.0_RP ) then
             nu_X(k,i,j) = nu_factX(k,i,j) &
                  * sqrt( S2(k,i,j) * (1.0_RP - FmC*WORK_X(k,i,j)) )
          else if ( WORK_X(k,i,j) < RiC ) then
             nu_X(k,i,j) = nu_factX(k,i,j) &
                  * sqrt( S2(k,i,j) ) * ( 1.0_RP - WORK_X(k,i,j)*RRiC )**4
          else
             nu_X(k,i,j) = 0.0_RP
          endif
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
#ifdef DEBUG
       S2(:,:,:) = UNDEF
       WORK_Z(:,:,:) = UNDEF; WORK_X(:,:,:) = UNDEF; WORK_Y(:,:,:) = UNDEF
#endif
       ! (y edge)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S11_Y(k,i,j) )
       call CHECK( __LINE__, S22_Y(k,i,j) )
       call CHECK( __LINE__, S33_Y(k,i,j) )
       call CHECK( __LINE__, S31_Y(k,i,j) )
       call CHECK( __LINE__, S12_Y(k,i,j) )
       call CHECK( __LINE__, S23_Y(k,i,j) )
#endif
          S2(k,i,j) = &
                 2.0_RP * ( S11_Y(k,i,j)**2 + S22_Y(k,i,j)**2 + S33_Y(k,i,j)**2 ) &
               + 4.0_RP * ( S31_Y(k,i,j)**2 + S12_Y(k,i,j)**2 + S23_Y(k,i,j)**2 )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! Ri
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, POTT(k+1,i,j) )
       call CHECK( __LINE__, POTT(k+1,i+1,j) )
       call CHECK( __LINE__, POTT(k,i,j) )
       call CHECK( __LINE__, POTT(k,i+1,j) )
       call CHECK( __LINE__, RFDZ(k) )
       call CHECK( __LINE__, S2(k,i,j) )
#endif
          TMP1 = ( POTT(k+1,i,j) + POTT(k+1,i+1,j) ) * 0.5_RP
          TMP2 = ( POTT(k  ,i,j) + POTT(k  ,i+1,j) ) * 0.5_RP
          WORK_Y(k,i,j) = 2.0_RP * GRAV * ( TMP1 - TMP2 ) &
               * RFDZ(k) / ( ( TMP1 + TMP2 ) * max(S2(k,i,j),1.0E-20_RP) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Y(k,i,j) )
       call CHECK( __LINE__, nu_factY(k,i,j) )
       call CHECK( __LINE__, S2(k,i,j) )
#endif
          if ( WORK_Y(k,i,j) < 0.0_RP ) then
             nu_Y(k,i,j) = nu_factY(k,i,j) &
                  * sqrt( S2(k,i,j) * (1.0_RP - FmC*WORK_Y(k,i,j)) )
          else if ( WORK_Y(k,i,j) < RiC ) then
             nu_Y(k,i,j) = nu_factY(k,i,j) &
                  * sqrt( S2(k,i,j) ) * ( 1.0_RP - WORK_Y(k,i,j)*RRiC )**4
          else
             nu_Y(k,i,j) = 0.0_RP
          endif
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif


       !##### momentum equation (z) #####
       ! (cell center)
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS+1, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, DENS(k,i,j) )
       call CHECK( __LINE__, nu_C(k,i,j) )
       call CHECK( __LINE__, S33_C(k,i,j) )
       call CHECK( __LINE__, S11_C(k,i,j) )
       call CHECK( __LINE__, S22_C(k,i,j) )
       call CHECK( __LINE__, tke(k,i,j) )
#endif
          qflx_sgs_momz(k,i,j,ZDIR) = DENS(k,i,j) * ( &
               - 2.0_RP * nu_C(k,i,j) &
               * ( S33_C(k,i,j) - ( S11_C(k,i,j) + S22_C(k,i,j) + S33_C(k,i,j) ) * OneOverThree ) &
             + twoOverThree * tke(k,i,j) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS, JJE
       do i = IIS, IIE
          qflx_sgs_momz(KS,i,j,ZDIR) = 0.0_RP ! bottom boundary
          qflx_sgs_momz(KE,i,j,ZDIR) = 0.0_RP ! top boundary
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y edge)
       do j = JJS,   JJE
       do i = IIS-1, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, DENS(k,i,j) )
       call CHECK( __LINE__, DENS(k,i+1,j) )
       call CHECK( __LINE__, DENS(k+1,i,j) )
       call CHECK( __LINE__, DENS(k+1,i+1,j) )
       call CHECK( __LINE__, nu_Y(k,i,j) )
       call CHECK( __LINE__, S31_Y(k,i,j) )
#endif
          qflx_sgs_momz(k,i,j,XDIR) = - 0.5_RP * ( DENS(k,i,j)+DENS(k,i+1,j)+DENS(k+1,i,j)+DENS(k+1,i+1,j) ) &
                               * nu_Y(k,i,j) * S31_Y(k,i,j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (x edge)
       do j = JJS-1, JJE
       do i = IIS,   IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, DENS(k,i,j) )
       call CHECK( __LINE__, DENS(k,i,j+1) )
       call CHECK( __LINE__, DENS(k+1,i,j) )
       call CHECK( __LINE__, DENS(k+1,i,j+1) )
       call CHECK( __LINE__, nu_X(k,i,j) )
       call CHECK( __LINE__, S23_X(k,i,j) )
#endif
          qflx_sgs_momz(k,i,j,YDIR) = - 0.5_RP * ( DENS(k,i,j)+DENS(k,i,j+1)+DENS(k+1,i,j)+DENS(k+1,i,j+1) ) &
                               * nu_X(k,i,j) * S23_X(k,i,j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       !##### momentum equation (x) #####
       ! (y edge)
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, DENS(k,i,j) )
       call CHECK( __LINE__, DENS(k,i+1,j) )
       call CHECK( __LINE__, DENS(k+1,i,j) )
       call CHECK( __LINE__, DENS(k+1,i+1,j) )
       call CHECK( __LINE__, nu_Y(k,i,j) )
       call CHECK( __LINE__, S31_Y(k,i,j) )
#endif
          qflx_sgs_momx(k,i,j,ZDIR) = - 0.5_RP * ( DENS(k,i,j)+DENS(k,i+1,j)+DENS(k+1,i,j)+DENS(k+1,i+1,j) ) &
                               * nu_Y(k,i,j) * S31_Y(k,i,j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS, JJE
       do i = IIS, IIE
          qflx_sgs_momx(KS-1,i,j,ZDIR) = 0.0_RP ! bottom boundary
          qflx_sgs_momx(KE  ,i,j,ZDIR) = 0.0_RP ! top boundary
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (cell center)
       do j = JJS, JJE
       do i = IIS, IIE+1
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, DENS(k,i,j) )
       call CHECK( __LINE__, nu_C(k,i,j) )
       call CHECK( __LINE__, S11_C(k,i,j) )
       call CHECK( __LINE__, S22_C(k,i,j) )
       call CHECK( __LINE__, S33_C(k,i,j) )
       call CHECK( __LINE__, tke(k,i,j) )
#endif
          qflx_sgs_momx(k,i,j,XDIR) = DENS(k,i,j) * ( &
               - 2.0_RP * nu_C(k,i,j) &
               * ( S11_C(k,i,j) - ( S11_C(k,i,j) + S22_C(k,i,j) + S33_C(k,i,j) ) * OneOverThree ) &
             + twoOverThree * tke(k,i,j) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z edge)
       do j = JJS-1, JJE
       do i = IIS,   IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, DENS(k,i,j) )
       call CHECK( __LINE__, DENS(k,i+1,j) )
       call CHECK( __LINE__, DENS(k,i,j+1) )
       call CHECK( __LINE__, DENS(k,i+1,j+1) )
       call CHECK( __LINE__, nu_Z(k,i,j) )
       call CHECK( __LINE__, S12_Z(k,i,j) )
#endif
          qflx_sgs_momx(k,i,j,YDIR) = - 0.5_RP * ( DENS(k,i,j)+DENS(k,i+1,j)+DENS(k,i,j+1)+DENS(k,i+1,j+1) ) &
                               * nu_Z(k,i,j) * S12_Z(k,i,j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       !##### momentum equation (y) #####
       ! (x edge)
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, DENS(k,i,j) )
       call CHECK( __LINE__, DENS(k,i,j+1) )
       call CHECK( __LINE__, DENS(k+1,i,j) )
       call CHECK( __LINE__, DENS(k+1,i,j+1) )
       call CHECK( __LINE__, nu_X(k,i,j) )
       call CHECK( __LINE__, S23_X(k,i,j) )
#endif
          qflx_sgs_momy(k,i,j,ZDIR) = - 0.5_RP * ( DENS(k,i,j)+DENS(k,i,j+1)+DENS(k+1,i,j)+DENS(k+1,i,j+1) ) &
                               * nu_X(k,i,j) * S23_X(k,i,j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS, JJE
       do i = IIS, IIE
          qflx_sgs_momy(KS-1,i,j,ZDIR) = 0.0_RP ! bottom boundary
          qflx_sgs_momy(KE  ,i,j,ZDIR) = 0.0_RP ! top boundary
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! (z edge)
       do j = JJS,   JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, DENS(k,i,j) )
       call CHECK( __LINE__, DENS(k,i+1,j) )
       call CHECK( __LINE__, DENS(k,i,j+1) )
       call CHECK( __LINE__, DENS(k,i+1,j+1) )
       call CHECK( __LINE__, nu_Z(k,i,j) )
       call CHECK( __LINE__, S12_Z(k,i,j) )
#endif
          qflx_sgs_momy(k,i,j,XDIR) = - 0.5_RP * ( DENS(k,i,j)+DENS(k,i+1,j)+DENS(k,i,j+1)+DENS(k,i+1,j+1) ) &
                               * nu_Z(k,i,j) * S12_Z(k,i,j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! (z-x plane)
       do j = JJS, JJE+1
       do i = IIS, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, DENS(k,i,j) )
       call CHECK( __LINE__, nu_C(k,i,j) )
       call CHECK( __LINE__, S11_C(k,i,j) )
       call CHECK( __LINE__, S22_C(k,i,j) )
       call CHECK( __LINE__, S33_C(k,i,j) )
       call CHECK( __LINE__, tke(k,i,j) )
#endif
          qflx_sgs_momy(k,i,j,YDIR) = DENS(k,i,j) * ( &
               - 2.0_RP * nu_C(k,i,j) &
               * ( S22_C(k,i,j) - ( S11_C(k,i,j) + S22_C(k,i,j) + S33_C(k,i,j) ) * OneOverThree ) &
             + twoOverThree * tke(k,i,j) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       !##### Thermodynamic Equation #####

#ifdef DEBUG
       S33_Z(:,:,:) = UNDEF; S33_X(:,:,:) = UNDEF; S33_Y(:,:,:) = UNDEF
       S22_Z(:,:,:) = UNDEF; S22_X(:,:,:) = UNDEF; S22_Y(:,:,:) = UNDEF
       S11_Z(:,:,:) = UNDEF; S11_X(:,:,:) = UNDEF; S11_Y(:,:,:) = UNDEF
       S31_Z(:,:,:) = UNDEF; S31_X(:,:,:) = UNDEF; S31_Y(:,:,:) = UNDEF
       S12_Z(:,:,:) = UNDEF; S12_X(:,:,:) = UNDEF; S12_Y(:,:,:) = UNDEF
       S23_Z(:,:,:) = UNDEF; S23_X(:,:,:) = UNDEF; S23_Y(:,:,:) = UNDEF
#endif


#ifdef DEBUG
       WORK_Z(:,:,:) = UNDEF; WORK_X(:,:,:) = UNDEF; WORK_Y(:,:,:) = UNDEF
#endif
       ! w
       ! (z edge)
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELZ_C(k,i,j) )
       call CHECK( __LINE__, VELZ_C(k,i+1,j) )
       call CHECK( __LINE__, VELZ_C(k,i,j+1) )
       call CHECK( __LINE__, VELZ_C(k,i+1,j+1) )
#endif
          WORK_Z(k,i,j) = 0.25_RP * ( VELZ_C(k,i,j) + VELZ_C(k,i+1,j) + VELZ_C(k,i,j+1) + VELZ_C(k,i+1,j+1) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (x edge)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELZ_XY(k,i,j) )
       call CHECK( __LINE__, VELZ_XY(k,i,j+1) )
#endif
          WORK_X(k,i,j) = 0.5_RP * ( VELZ_XY(k,i,j) + VELZ_XY(k,i,j+1) )
       enddo
       enddo
       enddo
       ! (y edge)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELZ_XY(k,i,j) )
       call CHECK( __LINE__, VELZ_XY(k,i+1,j) )
#endif
          WORK_Y(k,i,j) = 0.5_RP * ( VELZ_XY(k,i,j) + VELZ_XY(k,i+1,j) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! dw/dz
       ! (x-y plane)
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, VELZ_C(k+1,i,j) )
       call CHECK( __LINE__, VELZ_C(k,i,j) )
       call CHECK( __LINE__, RFDZ(k) )
#endif
          S33_Z(k,i,j) = ( VELZ_C(k+1,i,j) - VELZ_C(k,i,j) ) * RFDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y-z plane)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS+1, KE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Y(k,i,j) )
       call CHECK( __LINE__, WORK_Y(k-1,i,j) )
       call CHECK( __LINE__, RCDZ(k) )
#endif
          S33_X(k,i,j) = ( WORK_Y(k,i,j) - WORK_Y(k-1,i,j) ) * RCDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS  , JJE
       do i = IIS-1, IIE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Y(KS,i,j) )
       call CHECK( __LINE__, RCDZ(KS) )
#endif
          S33_X(KS,i,j) = WORK_Y(KS,i,j) * RCDZ(KS) ! WORK_Y(k-1,i,j) = 0
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z-x plane)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS+1, KE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_X(k,i,j) )
       call CHECK( __LINE__, WORK_X(k-1,i,j) )
       call CHECK( __LINE__, RCDZ(k) )
#endif
          S33_Y(k,i,j) = ( WORK_X(k,i,j) - WORK_X(k-1,i,j) ) * RCDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS-1, JJE
       do i = IIS  , IIE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_X(KS,i,j) )
       call CHECK( __LINE__, RCDZ(KS) )
#endif
          S33_Y(KS,i,j) = WORK_X(KS,i,j) * RCDZ(KS) ! WORK_Z(KS-1,i,j) = 0
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! 1/2 * dw/dx
       ! (x-y plane)
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, VELZ_XY(k,i+1,j) )
       call CHECK( __LINE__, VELZ_XY(k,i-1,j) )
       call CHECK( __LINE__, FDX(i) )
       call CHECK( __LINE__, FDX(i-1) )
#endif
          S31_Z(k,i,j) = 0.5_RP * ( VELZ_XY(k,i+1,j) - VELZ_XY(k,i-1,j) ) / ( FDX(i) + FDX(i-1) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y-z plane)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELZ_C(k,i+1,j) )
       call CHECK( __LINE__, VELZ_C(k,i,j) )
       call CHECK( __LINE__, RFDX(i) )
#endif
          S31_X(k,i,j) = 0.5_RP * ( VELZ_C(k,i+1,j) - VELZ_C(k,i,j) ) * RFDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z-x plane)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Z(k,i,j) )
       call CHECK( __LINE__, WORK_Z(k,i-1,j) )
       call CHECK( __LINE__, RCDX(i) )
#endif
          S31_Y(k,i,j) = 0.5_RP * ( WORK_Z(k,i,j) - WORK_Z(k,i-1,j) ) * RCDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! 1/2 * dw/dy
       ! (x-y plane)
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_X(k,i,j) )
       call CHECK( __LINE__, WORK_X(k,i,j-1) )
       call CHECK( __LINE__, RCDY(j) )
#endif
          S23_Z(k,i,j) = 0.5_RP * ( WORK_X(k,i,j) - WORK_X(k,i,j-1) ) * RCDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y-z plane)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Z(k,i,j) )
       call CHECK( __LINE__, WORK_Z(k,i,j-1) )
       call CHECK( __LINE__, RCDY(j) )
#endif
          S23_X(k,i,j) = 0.5_RP * ( WORK_Z(k,i,j) - WORK_Z(k,i,j-1) ) * RCDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z-x plane)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Z(k,i,j) )
       call CHECK( __LINE__, WORK_Z(k,i-1,j) )
       call CHECK( __LINE__, RCDX(i) )
#endif
          S23_Y(k,i,j) = 0.5_RP * ( WORK_Z(k,i,j) - WORK_Z(k,i-1,j) ) *RCDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif


#ifdef DEBUG
       WORK_Z(:,:,:) = UNDEF; WORK_X(:,:,:) = UNDEF; WORK_Y(:,:,:) = UNDEF
#endif
       ! u
       ! (z edge)
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELX_YZ(k,i,j+1) )
       call CHECK( __LINE__, VELX_YZ(k,i,j) )
#endif
          WORK_Z(k,i,j) = 0.5_RP * ( VELX_YZ(k,i,j+1) + VELX_YZ(k,i,j) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (x edge)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, VELX_C(k,i,j) )
       call CHECK( __LINE__, VELX_C(k+1,i,j) )
       call CHECK( __LINE__, VELX_C(k,i,j+1) )
       call CHECK( __LINE__, VELX_C(k+1,i,j+1) )
#endif
          WORK_X(k,i,j) = 0.25_RP * ( VELX_C(k,i,j) + VELX_C(k+1,i,j) + VELX_C(k,i,j+1) + VELX_C(k+1,i,j+1) )
       enddo
       enddo
       enddo
       ! (y edge)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELX_YZ(k+1,i,j) )
       call CHECK( __LINE__, VELX_YZ(k,i,j) )
#endif
          WORK_Y(k,i,j) = 0.5_RP * ( VELX_YZ(k+1,i,j) + VELX_YZ(k,i,j) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! du/dx
       ! (x-y plane)
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Y(k,i,j) )
       call CHECK( __LINE__, WORK_Y(k,i-1,j) )
       call CHECK( __LINE__, RCDX(i) )
#endif
          S11_Z(k,i,j) = ( WORK_Y(k,i,j) - WORK_Y(k,i-1,j) ) * RCDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y-z plane)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELX_C(k,i+1,j) )
       call CHECK( __LINE__, VELX_C(k,i,j) )
       call CHECK( __LINE__, RFDX(i) )
#endif
          S11_X(k,i,j) = ( VELX_C(k,i+1,j) - VELX_C(k,i,j) ) * RFDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z-x plane)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Z(k,i,j) )
       call CHECK( __LINE__, WORK_Z(k,i-1,j) )
       call CHECK( __LINE__, RCDX(i) )
#endif
          S11_Y(k,i,j) = ( WORK_Z(k,i,j) - WORK_Z(k,i-1,j) ) * RCDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! 1/2 * du/dy
       ! (x-y plane)
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_X(k,i,j) )
       call CHECK( __LINE__, WORK_X(k,i,j-1) )
       call CHECK( __LINE__, RCDY(j) )
#endif
          S12_Z(k,i,j) = 0.5_RP * ( WORK_X(k,i,j) - WORK_X(k,i,j-1) ) * RCDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y-z plane)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELX_YZ(k,i,j+1) )
       call CHECK( __LINE__, VELX_YZ(k,i,j-1) )
       call CHECK( __LINE__, FDY(j) )
       call CHECK( __LINE__, FDY(j-1) )
#endif
          S12_X(k,i,j) = 0.5_RP * ( VELX_YZ(k,i,j+1) - VELX_YZ(k,i,j-1) ) / ( FDY(j) + FDY(j-1) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z-x plane)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELX_C(k,i,j+1) )
       call CHECK( __LINE__, VELX_C(k,i,j) )
       call CHECK( __LINE__, RFDY(j) )
#endif
          S12_Y(k,i,j) = 0.5_RP * ( VELX_C(k,i,j+1) - VELX_C(k,i,j) ) * RFDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! 1/2 * du/dz
       ! (x-y plane)
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S31_Z(k,i,j) )
       call CHECK( __LINE__, VELX_C(k+1,i,j) )
       call CHECK( __LINE__, VELX_C(k,i,j) )
       call CHECK( __LINE__, RFDZ(k) )
#endif
          S31_Z(k,i,j) = S31_Z(k,i,j) + &
               0.5_RP * ( VELX_C(k+1,i,j) - VELX_C(k,i,j) ) * RFDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y-z plane)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS+1, KE
#ifdef DEBUG
       call CHECK( __LINE__, S31_X(k,i,j) )
       call CHECK( __LINE__, VELX_YZ(k+1,i,j) )
       call CHECK( __LINE__, VELX_YZ(k-1,i,j) )
       call CHECK( __LINE__, FDZ(k) )
       call CHECK( __LINE__, FDZ(k-1) )
#endif
          S31_X(k,i,j) = S31_X(k,i,j) + &
               0.5_RP * ( VELX_YZ(k+1,i,j) - VELX_YZ(k-1,i,j) ) / ( FDZ(k) + FDZ(k-1) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS  , JJE
       do i = IIS-1, IIE
#ifdef DEBUG
       call CHECK( __LINE__, S31_X(KS,i,j) )
       call CHECK( __LINE__, VELX_YZ(KS+1,i,j) )
       call CHECK( __LINE__, VELX_YZ(KS,i,j) )
       call CHECK( __LINE__, RFDZ(KS) )
#endif
          S31_X(KS,i,j) = S31_X(KS,i,j) + &
               0.5_RP * ( VELX_YZ(KS+1,i,j) - VELX_YZ(KS,i,j) ) * RFDZ(KS)
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z-x plane)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS+1, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S31_Y(k,i,j) )
       call CHECK( __LINE__, WORK_X(k,i,j) )
       call CHECK( __LINE__, WORK_X(k-1,i,j) )
       call CHECK( __LINE__, RCDZ(k) )
#endif
          S31_Y(k,i,j) = S31_Y(k,i,j) + &
               0.5_RP * ( WORK_X(k,i,j) - WORK_X(k-1,i,j) ) * RCDZ(k)
       enddo
       enddo
       enddo
       do j = JJS-1, JJE
       do i = IIS  , IIE
#ifdef DEBUG
       call CHECK( __LINE__, S31_Y(KS,i,j) )
       call CHECK( __LINE__, VELX_YZ(KS+1,i,j) )
       call CHECK( __LINE__, VELX_YZ(KS+1,i+1,j) )
       call CHECK( __LINE__, VELX_YZ(KS+1,i,j+1) )
       call CHECK( __LINE__, VELX_YZ(KS+1,i+1,j+1) )
       call CHECK( __LINE__, RCDZ(KS) )
#endif
          S31_Y(KS,i,j) = S31_Y(KS,i,j) + &
               0.125_RP * ( VELX_YZ(KS+1,i,j) + VELX_YZ(KS+1,i+1,j) + VELX_YZ(KS+1,i,j+1) + VELX_YZ(KS+1,i+1,j+1) &
                          - VELX_YZ(KS  ,i,j) - VELX_YZ(KS  ,i+1,j) - VELX_YZ(KS  ,i,j+1) - VELX_YZ(KS  ,i+1,j+1) ) * RCDZ(KS)
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS-1, JJE
       do i = IIS  , IIE
#ifdef DEBUG
       call CHECK( __LINE__, S31_Y(KE,i,j) )
       call CHECK( __LINE__, VELX_YZ(KE,i,j) )
       call CHECK( __LINE__, VELX_YZ(KE,i+1,j) )
       call CHECK( __LINE__, VELX_YZ(KE,i,j+1) )
       call CHECK( __LINE__, VELX_YZ(KE,i+1,j+1) )
       call CHECK( __LINE__, RCDZ(KE-1) )
#endif
          S31_Y(KE,i,j) = S31_Y(KE,i,j) + &
               0.125_RP * ( VELX_YZ(KE  ,i,j) + VELX_YZ(KE  ,i+1,j) + VELX_YZ(KE  ,i,j+1) + VELX_YZ(KE  ,i+1,j+1) &
                          - VELX_YZ(KE-1,i,j) - VELX_YZ(KE-1,i+1,j) - VELX_YZ(KE-1,i,j+1) - VELX_YZ(KE-1,i+1,j+1) ) * RCDZ(KE-1)
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif


#ifdef DEBUG
       WORK_Z(:,:,:) = UNDEF; WORK_X(:,:,:) = UNDEF; WORK_Y(:,:,:) = UNDEF
#endif
       ! v
       ! (z edge)
       do j = JJS-1, JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELY_ZX(k,i+1,j) )
       call CHECK( __LINE__, VELY_ZX(k,i,j) )
#endif
          WORK_Z(k,i,j) = 0.5_RP * ( VELY_ZX(k,i+1,j) + VELY_ZX(k,i,j) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (x edge)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, VELY_ZX(k+1,i,j) )
       call CHECK( __LINE__, VELY_ZX(k,i,j) )
#endif
          WORK_X(k,i,j) = 0.5_RP * ( VELY_ZX(k+1,i,j) + VELY_ZX(k,i,j) )
       enddo
       enddo
       enddo
       ! (y edge)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, VELY_C(k,i,j) )
       call CHECK( __LINE__, VELY_C(k+1,i,j) )
       call CHECK( __LINE__, VELY_C(k,i+1,j) )
       call CHECK( __LINE__, VELY_C(k+1,i+1,j) )
#endif
          WORK_Y(k,i,j) = 0.25_RP * ( VELY_C(k,i,j) + VELY_C(k+1,i,j) + VELY_C(k,i+1,j) + VELY_C(k+1,i+1,j) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! dv/dy
       ! (x-y plane)
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_X(k,i,j) )
       call CHECK( __LINE__, WORK_X(k,i,j-1) )
       call CHECK( __LINE__, RCDY(j) )
#endif
          S22_Z(k,i,j) = ( WORK_X(k,i,j) - WORK_X(k,i,j-1) ) * RCDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y-z plane)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Z(k,i,j) )
       call CHECK( __LINE__, WORK_Z(k,i,j-1) )
       call CHECK( __LINE__, RCDY(j) )
#endif
          S22_X(k,i,j) = ( WORK_Z(k,i,j) - WORK_Z(k,i,j-1) ) * RCDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z-x plane)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, VELY_C(k,i,j+1) )
       call CHECK( __LINE__, VELY_C(k,i,j) )
       call CHECK( __LINE__, RFDY(j) )
#endif
          S22_Y(k,i,j) = ( VELY_C(k,i,j+1) - VELY_C(k,i,j) ) * RFDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! 1/2 * dv/dz
       ! (x-y plane)
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S23_Z(k,i,j) )
       call CHECK( __LINE__, VELY_C(k+1,i,j) )
       call CHECK( __LINE__, VELY_C(k,i,j) )
       call CHECK( __LINE__, RFDZ(k) )
#endif
          S23_Z(k,i,j) = S23_Z(k,i,j) + &
               0.5_RP * ( VELY_C(k+1,i,j) - VELY_C(k,i,j) ) * RFDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y-z plane)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS+1, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S23_X(k,i,j) )
       call CHECK( __LINE__, WORK_Y(k,i,j) )
       call CHECK( __LINE__, WORK_Y(k-1,i,j) )
       call CHECK( __LINE__, RCDZ(k) )
#endif
          S23_X(k,i,j) = S23_X(k,i,j) + &
               0.5_RP * ( WORK_Y(k,i,j) - WORK_Y(k-1,i,j) ) * RCDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS  , JJE
       do i = IIS-1, IIE
#ifdef DEBUG
       call CHECK( __LINE__, S23_X(KS,i,j) )
       call CHECK( __LINE__, VELY_ZX(KS+1,i,j) )
       call CHECK( __LINE__, VELY_ZX(KS+1,i+1,j) )
       call CHECK( __LINE__, VELY_ZX(KS+1,i,j+1) )
       call CHECK( __LINE__, VELY_ZX(KS+1,i+1,j+1) )
       call CHECK( __LINE__, VELY_ZX(KS,i,j) )
       call CHECK( __LINE__, VELY_ZX(KS,i+1,j) )
       call CHECK( __LINE__, VELY_ZX(KS,i,j+1) )
       call CHECK( __LINE__, VELY_ZX(KS,i+1,j+1) )
       call CHECK( __LINE__, RCDZ(KS) )
#endif
          S23_X(KS,i,j) = S23_X(KS,i,j) + &
               0.125_RP * ( VELY_ZX(KS+1,i,j) + VELY_ZX(KS+1,i+1,j) + VELY_ZX(KS+1,i,j+1) + VELY_ZX(KS+1,i+1,j+1) &
                           -VELY_ZX(KS  ,i,j) - VELY_ZX(KS  ,i+1,j) - VELY_ZX(KS  ,i,j+1) - VELY_ZX(KS  ,i+1,j+1) ) * RCDZ(KS)
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS  , JJE
       do i = IIS-1, IIE
#ifdef DEBUG
       call CHECK( __LINE__, S23_X(KE,i,j) )
       call CHECK( __LINE__, VELY_ZX(KE,i,j) )
       call CHECK( __LINE__, VELY_ZX(KE,i+1,j) )
       call CHECK( __LINE__, VELY_ZX(KE,i,j+1) )
       call CHECK( __LINE__, VELY_ZX(KE,i+1,j+1) )
       call CHECK( __LINE__, VELY_ZX(KE-1,i,j) )
       call CHECK( __LINE__, VELY_ZX(KE-1,i+1,j) )
       call CHECK( __LINE__, VELY_ZX(KE-1,i,j+1) )
       call CHECK( __LINE__, VELY_ZX(KE-1,i+1,j+1) )
       call CHECK( __LINE__, RCDZ(KE-1) )
#endif
          S23_X(KE,i,j) = S23_X(KE,i,j) + &
               0.125_RP * ( VELY_ZX(KE  ,i,j) + VELY_ZX(KE  ,i+1,j) + VELY_ZX(KE  ,i,j+1) + VELY_ZX(KE  ,i+1,j+1) &
                           -VELY_ZX(KE-1,i,j) - VELY_ZX(KE-1,i+1,j) - VELY_ZX(KE-1,i,j+1) - VELY_ZX(KE-1,i+1,j+1) ) * RCDZ(KE-1)
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z-x plane)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS+1, KE
#ifdef DEBUG
       call CHECK( __LINE__, S23_Y(k,i,j) )
       call CHECK( __LINE__, VELY_ZX(k+1,i,j) )
       call CHECK( __LINE__, VELY_ZX(k-1,i,j) )
       call CHECK( __LINE__, FDZ(k) )
       call CHECK( __LINE__, FDZ(k-1) )
#endif
          S23_Y(k,i,j) = S23_Y(k,i,j) + &
               0.5_RP * ( VELY_ZX(k+1,i,j) - VELY_ZX(k-1,i,j) ) / ( FDZ(k) + FDZ(k-1) )
       enddo
       enddo
       enddo
       do j = JJS-1, JJE
       do i = IIS  , IIE
#ifdef DEBUG
       call CHECK( __LINE__, S23_Y(KS,i,j) )
       call CHECK( __LINE__, VELY_ZX(KS+1,i,j) )
       call CHECK( __LINE__, VELY_ZX(KS,i,j) )
       call CHECK( __LINE__, RFDZ(KS) )
#endif
          S23_Y(KS,i,j) = S23_Y(KS,i,j) + &
               0.5_RP * ( VELY_ZX(KS+1,i,j) - VELY_ZX(KS,i,j) ) * RFDZ(KS)
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! 1/2 * dv/dx
       ! (x-y plane)
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S23_Z(k,i,j) )
       call CHECK( __LINE__, WORK_Y(k,i,j) )
       call CHECK( __LINE__, WORK_Y(k,i-1,j) )
       call CHECK( __LINE__, RCDX(i) )
#endif
          S12_Z(k,i,j) = S12_Z(k,i,j) + &
               0.5_RP * ( WORK_Y(k,i,j) - WORK_Y(k,i-1,j) ) * RCDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (y-z plane)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, S12_X(k,i,j) )
       call CHECK( __LINE__, VELY_C(k,i+1,j) )
       call CHECK( __LINE__, VELY_C(k,i,j) )
       call CHECK( __LINE__, RFDX(i) )
#endif
          S12_X(k,i,j) = S12_X(k,i,j) + &
               0.5_RP * ( VELY_C(k,i+1,j) - VELY_C(k,i,j) ) * RFDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z-x plane)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, S12_Y(k,i,j) )
       call CHECK( __LINE__, VELY_ZX(k,i+1,j) )
       call CHECK( __LINE__, VELY_ZX(k,i-1,j) )
       call CHECK( __LINE__, FDX(i) )
       call CHECK( __LINE__, FDX(i-1) )
#endif
          S12_Y(k,i,j) = S12_Y(k,i,j) + &
               0.5_RP * ( VELY_ZX(k,i+1,j) - VELY_ZX(k,i-1,j) ) / ( FDX(i) + FDX(i-1) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif


#ifdef DEBUG
       S2(:,:,:) = UNDEF
       WORK_Z(:,:,:) = UNDEF; WORK_X(:,:,:) = UNDEF; WORK_Y(:,:,:) = UNDEF
#endif
       ! (x-y plane)
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, S11_Z(k,i,j) )
       call CHECK( __LINE__, S22_Z(k,i,j) )
       call CHECK( __LINE__, S33_Z(k,i,j) )
       call CHECK( __LINE__, S31_Z(k,i,j) )
       call CHECK( __LINE__, S12_Z(k,i,j) )
       call CHECK( __LINE__, S23_Z(k,i,j) )
#endif
          S2(k,i,j) = &
                 2.0_RP * ( S11_Z(k,i,j)**2 + S22_Z(k,i,j)**2 + S33_Z(k,i,j)**2 ) &
               + 4.0_RP * ( S31_Z(k,i,j)**2 + S12_Z(k,i,j)**2 + S23_Z(k,i,j)**2 )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! Ri
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, POTT(k+1,i,j) )
       call CHECK( __LINE__, POTT(k,i,j) )
       call CHECK( __LINE__, RFDZ(k) )
       call CHECK( __LINE__, S2(k,i,j) )
#endif
          WORK_Z(k,i,j) = 2.0_RP * GRAV * ( POTT(k+1,i,j) - POTT(k,i,j) ) &
               * RFDZ(k) / ( ( POTT(k+1,i,j) + POTT(k,i,j) ) * max(S2(k,i,j),1.0E-20_RP) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Z(k,i,j) )
       call CHECK( __LINE__, nu_factXY(k,i,j) )
       call CHECK( __LINE__, S2(k,i,j) )
#endif
          if ( WORK_Z(k,i,j) < 0.0_RP ) then
             nu_Z(k,i,j) = nu_factXY(k,i,j) * RPrN &
                  * sqrt( S2(k,i,j) * (1.0_RP - FhB*WORK_Z(k,i,j)) )
          else if ( WORK_Z(k,i,j) < RiC ) then
             nu_Z(k,i,j) = nu_factXY(k,i,j) * RPrN &
                  * sqrt( S2(k,i,j) ) * ( 1.0_RP - WORK_Z(k,i,j)*RRiC )**4 &
                  * ( 1.0_RP - PrNovRiC*WORK_Z(k,i,j) )
          else
             nu_Z(k,i,j) = 0.0_RP
          endif
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
#ifdef DEBUG
       S2(:,:,:) = UNDEF
       WORK_Z(:,:,:) = UNDEF; WORK_X(:,:,:) = UNDEF; WORK_Y(:,:,:) = UNDEF
#endif
       ! (y-z plane)
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, S11_X(k,i,j) )
       call CHECK( __LINE__, S22_X(k,i,j) )
       call CHECK( __LINE__, S33_X(k,i,j) )
       call CHECK( __LINE__, S31_X(k,i,j) )
       call CHECK( __LINE__, S12_X(k,i,j) )
       call CHECK( __LINE__, S23_X(k,i,j) )
#endif
          S2(k,i,j) = &
                 2.0_RP * ( S11_X(k,i,j)**2 + S22_X(k,i,j)**2 + S33_X(k,i,j)**2 ) &
               + 4.0_RP * ( S31_X(k,i,j)**2 + S12_X(k,i,j)**2 + S23_X(k,i,j)**2 )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! Ri
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS+1, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, POTT(k+1,i+1,j) )
       call CHECK( __LINE__, POTT(k+1,i,j) )
       call CHECK( __LINE__, POTT(k,i+1,j) )
       call CHECK( __LINE__, POTT(k,i,j) )
       call CHECK( __LINE__, POTT(k-1,i+1,j) )
       call CHECK( __LINE__, POTT(k-1,i,j) )
       call CHECK( __LINE__, FDZ(k) )
       call CHECK( __LINE__, FDZ(k-1) )
       call CHECK( __LINE__, S2(k,i,j) )
#endif
          TMP1 = ( POTT(k+1,i+1,j) + POTT(k+1,i,j) ) * 0.5_RP
          TMP2 = ( POTT(k  ,i+1,j) + POTT(k  ,i,j) ) * 0.5_RP
          TMP3 = ( POTT(k-1,i+1,j) + POTT(k-1,i,j) ) * 0.5_RP
          WORK_X(k,i,j) = 2.0_RP * GRAV * ( TMP1 - TMP3 ) &
               / ( ( FDZ(k) + FDZ(k-1) ) * TMP2 * max(S2(k,i,j),1.0E-20_RP) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS  , JJE
       do i = IIS-1, IIE
#ifdef DEBUG
       call CHECK( __LINE__, POTT(KE,i+1,j) )
       call CHECK( __LINE__, POTT(KE,i,j) )
       call CHECK( __LINE__, POTT(KE-1,i+1,j) )
       call CHECK( __LINE__, POTT(KE-1,i,j) )
       call CHECK( __LINE__, RFDZ(KE-1) )
       call CHECK( __LINE__, S2(KE,i,j) )
#endif
          TMP2 = ( POTT(KE  ,i+1,j) + POTT(KE  ,i,j) ) * 0.5_RP
          TMP3 = ( POTT(KE-1,i+1,j) + POTT(KE-1,i,j) ) * 0.5_RP
          WORK_X(KE,i,j) = 0.5_RP * GRAV * ( TMP2 - TMP3 ) &
               * RFDZ(KE-1) / ( TMP2 * max(S2(KE,i,j),1.0E-20_RP) )
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS  , JJE
       do i = IIS-1, IIE
#ifdef DEBUG
       call CHECK( __LINE__, POTT(KS+1,i+1,j) )
       call CHECK( __LINE__, POTT(KS+1,i,j) )
       call CHECK( __LINE__, POTT(KS,i+1,j) )
       call CHECK( __LINE__, POTT(KS,i,j) )
       call CHECK( __LINE__, RFDZ(KS) )
       call CHECK( __LINE__, S2(KS,i,j) )
#endif
          TMP1 = ( POTT(KS+1,i+1,j) + POTT(KS+1,i,j) ) * 0.5_RP
          TMP2 = ( POTT(KS  ,i+1,j) + POTT(KS  ,i,j) ) * 0.5_RP
          WORK_X(KS,i,j) = 0.5_RP * GRAV * ( TMP1 - TMP2 ) &
               * RFDZ(KS) / ( TMP2 * max(S2(KS,i,j),1.0E-20_RP) )
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS  , JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_X(k,i,j) )
       call CHECK( __LINE__, nu_factYZ(k,i,j) )
       call CHECK( __LINE__, S2(k,i,j) )
#endif
          if ( WORK_X(k,i,j) < 0.0_RP ) then
             nu_X(k,i,j) = nu_factYZ(k,i,j) * RPrN &
                  * sqrt( S2(k,i,j) * (1.0_RP - FhB*WORK_X(k,i,j)) )
          else if ( WORK_X(k,i,j) < RiC ) then
             nu_X(k,i,j) = nu_factYZ(k,i,j) * RPrN &
                  * sqrt( S2(k,i,j) ) * ( 1.0_RP - WORK_X(k,i,j)*RRiC )**4 &
                  * ( 1.0_RP - PrNovRiC*WORK_X(k,i,j) )
          else
             nu_X(k,i,j) = 0.0_RP
          endif
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

#ifdef DEBUG
       S2(:,:,:) = UNDEF
       WORK_Z(:,:,:) = UNDEF; WORK_X(:,:,:) = UNDEF; WORK_Y(:,:,:) = UNDEF
#endif
       ! (z-x plane)
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, S11_Y(k,i,j) )
       call CHECK( __LINE__, S22_Y(k,i,j) )
       call CHECK( __LINE__, S33_Y(k,i,j) )
       call CHECK( __LINE__, S31_Y(k,i,j) )
       call CHECK( __LINE__, S12_Y(k,i,j) )
       call CHECK( __LINE__, S23_Y(k,i,j) )
#endif
          S2(k,i,j) = &
                 2.0_RP * ( S11_Y(k,i,j)**2 + S22_Y(k,i,j)**2 + S33_Y(k,i,j)**2 ) &
               + 4.0_RP * ( S31_Y(k,i,j)**2 + S12_Y(k,i,j)**2 + S23_Y(k,i,j)**2 )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! Ri
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS+1, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, POTT(k+1,i,j+1) )
       call CHECK( __LINE__, POTT(k+1,i,j) )
       call CHECK( __LINE__, POTT(k,i,j+1) )
       call CHECK( __LINE__, POTT(k,i,j) )
       call CHECK( __LINE__, POTT(k-1,i,j+1) )
       call CHECK( __LINE__, POTT(k-1,i,j) )
       call CHECK( __LINE__, FDZ(k) )
       call CHECK( __LINE__, FDZ(k-1) )
       call CHECK( __LINE__, S2(k,i,j) )
#endif
          TMP1 = ( POTT(k+1,i,j+1) + POTT(k+1,i,j) ) * 0.5_RP
          TMP2 = ( POTT(k  ,i,j+1) + POTT(k  ,i,j) ) * 0.5_RP
          TMP3 = ( POTT(k-1,i,j+1) + POTT(k-1,i,j) ) * 0.5_RP
          WORK_Y(k,i,j) = 2.0_RP * GRAV * ( TMP1 - TMP3 ) &
               / ( ( FDZ(k) + FDZ(k-1) ) * TMP2 * max(S2(k,i,j),1.0E-20_RP) )
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS-1, JJE
       do i = IIS  , IIE
#ifdef DEBUG
       call CHECK( __LINE__, POTT(KE,i,j+1) )
       call CHECK( __LINE__, POTT(KE,i,j) )
       call CHECK( __LINE__, POTT(KE-1,i,j+1) )
       call CHECK( __LINE__, POTT(KE-1,i,j) )
       call CHECK( __LINE__, RFDZ(KE-1) )
       call CHECK( __LINE__, S2(KE,i,j) )
#endif
          TMP2 = ( POTT(KE  ,i,j+1) + POTT(KE  ,i,j) ) * 0.5_RP
          TMP3 = ( POTT(KE-1,i,j+1) + POTT(KE-1,i,j) ) * 0.5_RP
          WORK_Y(KE,i,j) = 0.5_RP * GRAV * ( TMP2 - TMP3 ) &
               * RFDZ(KE-1) / ( TMP2 * max(S2(KE,i,j),1.0E-20_RP) )
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS-1, JJE
       do i = IIS  , IIE
#ifdef DEBUG
       call CHECK( __LINE__, POTT(KS+1,i,j+1) )
       call CHECK( __LINE__, POTT(KS+1,i,j) )
       call CHECK( __LINE__, POTT(KS,i,j+1) )
       call CHECK( __LINE__, POTT(KS,i,j) )
       call CHECK( __LINE__, RFDZ(KS) )
       call CHECK( __LINE__, S2(KS,i,j) )
#endif
          TMP1 = ( POTT(KS+1,i,j+1) + POTT(KS+1,i,j) ) * 0.5_RP
          TMP2 = ( POTT(KS  ,i,j+1) + POTT(KS  ,i,j) ) * 0.5_RP
          WORK_Y(KS,i,j) = 0.5_RP * GRAV * ( TMP1 - TMP2 ) &
               * RFDZ(KS) / ( TMP2 * max(S2(KS,i,j),1.0E-20_RP) )
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS-1, JJE
       do i = IIS  , IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, WORK_Y(k,i,j) )
       call CHECK( __LINE__, nu_factZX(k,i,j) )
       call CHECK( __LINE__, S2(k,i,j) )
#endif
          if ( WORK_Y(k,i,j) < 0.0_RP ) then
             nu_Y(k,i,j) = nu_factZX(k,i,j) * RPrN &
                  * sqrt( S2(k,i,j) * (1.0_RP - FhB*WORK_Y(k,i,j)) )
          else if ( WORK_Y(k,i,j) < RiC ) then
             nu_Y(k,i,j) = nu_factZX(k,i,j) * RPrN &
                  * sqrt( S2(k,i,j) ) * ( 1.0_RP - WORK_Y(k,i,j)*RRiC )**4 &
                  * ( 1.0_RP - PrNovRiC*WORK_Y(k,i,j) )
          else
             nu_Y(k,i,j) = 0.0_RP
          endif
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
#ifdef DEBUG
       WORK_Z(:,:,:) = UNDEF; WORK_X(:,:,:) = UNDEF; WORK_Y(:,:,:) = UNDEF
#endif


       ! (x-y plane)
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, DENS(k,i,j) )
       call CHECK( __LINE__, DENS(k+1,i,j) )
       call CHECK( __LINE__, nu_Z(k,i,j) )
       call CHECK( __LINE__, POTT(k+1,i,j) )
       call CHECK( __LINE__, POTT(k,i,j) )
       call CHECK( __LINE__, RFDZ(k) )
#endif
          qflx_sgs_rhot(k,i,j,ZDIR) = - 0.5_RP * ( DENS(k,i,j)+DENS(k+1,i,j) ) &
                               * nu_Z(k,i,j) &
                               * ( POTT(k+1,i,j)-POTT(k,i,j) ) * RFDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS, JJE
       do i = IIS, IIE
          qflx_sgs_rhot(KS-1,i,j,ZDIR) = 0.0_RP
          qflx_sgs_rhot(KE  ,i,j,ZDIR) = 0.0_RP
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! (y-z plane)
       do j = JJS,   JJE
       do i = IIS-1, IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, DENS(k,i,j) )
       call CHECK( __LINE__, DENS(k,i+1,j) )
       call CHECK( __LINE__, nu_X(k,i,j) )
       call CHECK( __LINE__, POTT(k,i+1,j) )
       call CHECK( __LINE__, POTT(k,i,j) )
       call CHECK( __LINE__, RFDX(i) )
#endif
          qflx_sgs_rhot(k,i,j,XDIR) = - 0.5_RP * ( DENS(k,i,j)+DENS(k,i+1,j) ) &
                               * nu_X(k,i,j) &
                               * ( POTT(k,i+1,j)-POTT(k,i,j) ) * RFDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z-x plane)
       do j = JJS-1, JJE
       do i = IIS,   IIE
       do k = KS, KE
#ifdef DEBUG
       call CHECK( __LINE__, DENS(k,i,j) )
       call CHECK( __LINE__, DENS(k,i,j+1) )
       call CHECK( __LINE__, nu_Y(k,i,j) )
       call CHECK( __LINE__, POTT(k,i,j+1) )
       call CHECK( __LINE__, POTT(k,i,j) )
       call CHECK( __LINE__, RFDY(j) )
#endif
          qflx_sgs_rhot(k,i,j,YDIR) = - 0.5_RP * ( DENS(k,i,j)+DENS(k,i,j+1) ) &
                               * nu_Y(k,i,j) &
                               * ( POTT(k,i,j+1)-POTT(k,i,j) ) * RFDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

    enddo
    enddo


    !##### Tracers #####
    do iq = 1, QA

    do JJS = JS, JE, JBLOCK
    JJE = JJS+JBLOCK-1
    do IIS = IS, IE, IBLOCK
    IIE = IIS+IBLOCK-1

       ! (x-y plane)
       do j = JJS, JJE
       do i = IIS, IIE
       do k = KS, KE-1
#ifdef DEBUG
       call CHECK( __LINE__, DENS(k,i,j) )
       call CHECK( __LINE__, DENS(k+1,i,j) )
       call CHECK( __LINE__, nu_Z(k,i,j) )
       call CHECK( __LINE__, QTRC(k+1,i,j,iq) )
       call CHECK( __LINE__, QTRC(k,i,j,iq) )
       call CHECK( __LINE__, RFDZ(k) )
#endif
          qflx_sgs_qtrc(k,i,j,iq,ZDIR) = - 0.5_RP * ( DENS(k,i,j)+DENS(k+1,i,j) ) &
                               * nu_Z(k,i,j) &
                               * ( QTRC(k+1,i,j,iq)-QTRC(k,i,j,iq) ) * RFDZ(k)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       do j = JJS, JJE
       do i = IIS, IIE
          qflx_sgs_qtrc(KS-1,i,j,iq,ZDIR) = 0.0_RP
          qflx_sgs_qtrc(KE  ,i,j,iq,ZDIR) = 0.0_RP
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

       ! (y-z plane)
       do j = JJS,   JJE
       do i = IIS-1, IIE
       do k = KS,   KE
#ifdef DEBUG
       call CHECK( __LINE__, DENS(k,i,j) )
       call CHECK( __LINE__, DENS(k,i+1,j) )
       call CHECK( __LINE__, nu_X(k,i,j) )
       call CHECK( __LINE__, QTRC(k,i+1,j,iq) )
       call CHECK( __LINE__, QTRC(k,i,j,iq) )
       call CHECK( __LINE__, RFDX(i) )
#endif
          qflx_sgs_qtrc(k,i,j,iq,XDIR) = - 0.5_RP * ( DENS(k,i,j)+DENS(k,i+1,j) ) &
                               * nu_X(k,i,j) &
                               * ( QTRC(k,i+1,j,iq)-QTRC(k,i,j,iq) ) * RFDX(i)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif
       ! (z-x plane)
       do j = JJS-1, JJE
       do i = IIS,   IIE
       do k = KS,   KE
#ifdef DEBUG
       call CHECK( __LINE__, DENS(k,i,j) )
       call CHECK( __LINE__, DENS(k,i,j+1) )
       call CHECK( __LINE__, nu_Y(k,i,j) )
       call CHECK( __LINE__, QTRC(k,i,j+1,iq) )
       call CHECK( __LINE__, QTRC(k,i,j,iq) )
       call CHECK( __LINE__, RFDY(j) )
#endif
          qflx_sgs_qtrc(k,i,j,iq,YDIR) = - 0.5_RP * ( DENS(k,i,j)+DENS(k,i,j+1) ) &
                               * nu_Y(k,i,j) &
                               * ( QTRC(k,i,j+1,iq)-QTRC(k,i,j,iq) ) * RFDY(j)
       enddo
       enddo
       enddo
#ifdef DEBUG
       i = IUNDEF; j = IUNDEF; k = IUNDEF
#endif

    enddo
    enddo
#ifdef DEBUG
       IIS = IUNDEF; IIE = IUNDEF; JJS = IUNDEF; JJE = IUNDEF
#endif

    enddo ! scalar quantities loop
#ifdef DEBUG
       iq = IUNDEF
#endif

    return
  end subroutine ATMOS_PHY_TB_main


  function mixlen(dz, dx, dy, z)
  use mod_const, only: &
     KARMAN  => CONST_KARMAN
    implicit none
    real(RP), intent(in) :: dz
    real(RP), intent(in) :: dx
    real(RP), intent(in) :: dy
    real(RP), intent(in) :: z
    real(RP) :: mixlen ! (out)

    real(RP) :: d0

    d0 = fact(dz, dx, dy) * ( dz * dx * dy )**OneOverThree ! Scotti et al. (1993)
    mixlen = sqrt( 1.0_RP / ( 1.0_RP/d0**2 + 1.0_RP/(KARMAN*z)**2 ) ) ! Brown et al. (1994)

    return
  end function mixlen

  function fact(dz, dx, dy)
    real(RP), intent(in) :: dz
    real(RP), intent(in) :: dx
    real(RP), intent(in) :: dy
    real(RP) :: fact ! (out)

    real(RP), parameter :: oot = -1.0_RP/3.0_RP
    real(RP), parameter :: fot =  5.0_RP/3.0_RP
    real(RP), parameter :: eot = 11.0_RP/3.0_RP
    real(RP), parameter :: tof = -3.0_RP/4.0_RP
    real(RP) :: a1, a2, b1, b2, dmax


    dmax = max(dz, dx, dy)
    if ( dz .eq. dmax ) then
       a1 = dx / dmax
       a2 = dy / dmax
    else if ( dx .eq. dmax ) then
       a1 = dz / dmax
       a2 = dy / dmax
    else ! dy .eq. dmax
       a1 = dz / dmax
       a2 = dx / dmax
    end if
    b1 = atan( a1/a2 )
    b2 = atan( a2/a1 )

   fact = 1.736_RP * (a1*a2)**oot &
         * ( 4.0_RP*p1(b1)*a1**oot + 0.222_RP*p2(b1)*a1**fot + 0.077*p3(b1)*a1**eot - 3.0_RP*b1 &
           + 4.0_RP*p1(b2)*a2**oot + 0.222_RP*p2(b2)*a2**fot + 0.077*p3(b2)*a2**eot - 3.0_RP*b2 &
           )**tof
   return
  end function fact
  function p1(z)
    real(RP), intent(in) :: z
    real(RP) :: p1 ! (out)

    p1 = 2.5_RP * p2(z) - 1.5_RP * sin(z) * cos(z)**TwoOverThree
    return
  end function p1
  function p2(z)
    real(RP), intent(in) :: z
    real(RP) :: p2 ! (out)

    p2 = 0.986_RP * z + 0.073_RP * z**2 - 0.418_RP * z**3 + 0.120_RP * z**4
    return
  end function p2
  function p3(z)
    real(RP), intent(in) :: z
    real(RP) :: p3 ! (out)

    p3 = 0.976_RP * z + 0.188_RP * z**2 - 1.169_RP * z**3 + 0.755_RP * z**4 - 0.151_RP * z**5
    return
  end function p3

end module mod_atmos_phy_tb
