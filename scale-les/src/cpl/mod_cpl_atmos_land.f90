!-------------------------------------------------------------------------------
!> module COUPLER / Atmosphere-Land Surface fluxes
!!
!! @par Description
!!          Surface flux between atmosphere and land with Bulk Method
!!
!! @author Team SCALE
!!
!! @par History
!! @li      2013-08-31 (T.Yamaura)  [new]
!<
!-------------------------------------------------------------------------------
module mod_cpl_atmos_land
  !-----------------------------------------------------------------------------
  !
  !++ used modules
  !
  use mod_precision
  use mod_stdio
  use mod_prof
  use mod_grid_index
  use mod_tracer
  !-----------------------------------------------------------------------------
  implicit none
  private
  !-----------------------------------------------------------------------------
  !
  !++ Public procedure
  !
  public :: CPL_AtmLnd_setup
  public :: CPL_AtmLnd_solve
  public :: CPL_AtmLnd_unsolve

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
contains
  !-----------------------------------------------------------------------------
  !
  !-----------------------------------------------------------------------------
  subroutine CPL_AtmLnd_setup
    use mod_cpl_vars, only: &
       CPL_flushAtm,            &
       CPL_flushLnd,            &
       CPL_AtmLnd_flushCPL
    implicit none
    !---------------------------------------------------------------------------

    call CPL_flushAtm
    call CPL_flushLnd
    call CPL_AtmLnd_flushCPL

    return
  end subroutine CPL_AtmLnd_setup

  subroutine CPL_AtmLnd_solve
    use mod_process, only: &
       PRC_MPIstop
    use mod_grid_real, only: &
       CZ => REAL_CZ, &
       FZ => REAL_FZ
    use mod_cpl_vars, only: &
       CPL_AtmLnd_putCPL,     &
       CPL_AtmLnd_getAtm2CPL, &
       CPL_AtmLnd_getLnd2CPL, &
       LST
    implicit none

    ! parameters
    integer,  parameter :: nmax     = 100       ! maximum iteration number
    real(RP), parameter :: redf_min = 1.0E-2_RP ! minimum reduced factor
    real(RP), parameter :: redf_max = 1.0_RP    ! maximum reduced factor
    real(RP), parameter :: TFa      = 0.5_RP    ! factor a in Tomita (2009)
    real(RP), parameter :: TFb      = 1.1_RP    ! factor b in Tomita (2009)
    real(RP), parameter :: res_min  = 1.0_RP    ! minimum number of residual

    ! works
    integer :: i, j, n

    real(RP) :: RES   (IA,JA)
    real(RP) :: DRES  (IA,JA)
    real(RP) :: oldRES(IA,JA) ! RES in previous step
    real(RP) :: redf  (IA,JA) ! reduced factor

    real(RP) :: XMFLX (IA,JA) ! x-momentum flux at the surface [kg/m2/s]
    real(RP) :: YMFLX (IA,JA) ! y-momentum flux at the surface [kg/m2/s]
    real(RP) :: ZMFLX (IA,JA) ! z-momentum flux at the surface [kg/m2/s]
    real(RP) :: SWUFLX(IA,JA) ! upward shortwave flux at the surface [W/m2]
    real(RP) :: LWUFLX(IA,JA) ! upward longwave flux at the surface [W/m2]
    real(RP) :: SHFLX (IA,JA) ! sensible heat flux at the surface [W/m2]
    real(RP) :: LHFLX (IA,JA) ! latent heat flux at the surface [W/m2]
    real(RP) :: GHFLX (IA,JA) ! ground heat flux at the surface [W/m2]

    real(RP) :: DZ  (IA,JA) ! height from the surface to the lowest atmospheric layer [m]

    real(RP) :: DENS(IA,JA) ! air density at the lowest atmospheric layer [kg/m3]
    real(RP) :: MOMX(IA,JA) ! momentum x at the lowest atmospheric layer [kg/m2/s]
    real(RP) :: MOMY(IA,JA) ! momentum y at the lowest atmospheric layer [kg/m2/s]
    real(RP) :: MOMZ(IA,JA) ! momentum z at the lowest atmospheric layer [kg/m2/s]
    real(RP) :: RHOS(IA,JA) ! air density at the sruface [kg/m3]
    real(RP) :: PRES(IA,JA) ! pressure at the surface [Pa]
    real(RP) :: ATMP(IA,JA) ! air temperature at the surface [K]
    real(RP) :: QV  (IA,JA) ! ratio of water vapor mass to total mass at the lowest atmospheric layer [kg/kg]
    real(RP) :: PREC(IA,JA) ! precipitaton flux at the surface [kg/m2/s]
    real(RP) :: SWD (IA,JA) ! downward short-wave radiation flux at the surface (upward positive) [W/m2]
    real(RP) :: LWD (IA,JA) ! downward long-wave radiation flux at the surface (upward positive) [W/m2]

    real(RP) :: TG  (IA,JA) ! soil temperature [K]
    real(RP) :: QVEF(IA,JA) ! efficiency of evaporation [no unit]
    real(RP) :: EMIT(IA,JA) ! emissivity in long-wave radiation [no unit]
    real(RP) :: ALB (IA,JA) ! surface albedo in short-wave radiation [no unit]
    real(RP) :: TCS (IA,JA) ! thermal conductivity for soil [W/m/K]
    real(RP) :: DZG (IA,JA) ! soil depth [m]
    real(RP) :: Z0M (IA,JA) ! roughness length for momemtum [m]
    real(RP) :: Z0H (IA,JA) ! roughness length for heat [m]
    real(RP) :: Z0E (IA,JA) ! roughness length for vapor [m]

    if( IO_L ) write(IO_FID_LOG,*) '*** CPL solve: Atmos-Land'

    call CPL_AtmLnd_getAtm2CPL( &
      DENS, MOMX, MOMY, MOMZ, & ! (out)
      RHOS, PRES, ATMP, QV,   & ! (out)
      PREC, SWD, LWD          ) ! (out)

    call CPL_AtmLnd_getLnd2CPL( &
      TG, QVEF, EMIT, & ! (out)
      ALB, TCS, DZG,  & ! (out)
      Z0M, Z0H, Z0E   ) ! (out)

    DZ(:,:) = CZ(KS,:,:) - FZ(KS-1,:,:)

    redf  (:,:) = 1.0_RP
    oldRES(:,:) = 1.0E+5_RP

    do n = 1, nmax

      ! calc. surface fluxes
      call heat_balance( &
        RES, DRES,                                              & ! (out)
        XMFLX, YMFLX, ZMFLX,                                    & ! (out)
        SWUFLX, LWUFLX, SHFLX, LHFLX, GHFLX,                    & ! (out)
        DZ, LST,                                                & ! (in)
        DENS, MOMX, MOMY, MOMZ, RHOS, PRES, ATMP, QV, SWD, LWD, & ! (in)
        TG, QVEF, EMIT, ALB, TCS, DZG, Z0M, Z0H, Z0E            ) ! (in)

      do j = JS-1, JE+1
      do i = IS-1, IE+1

        if( redf(i,j) < 0.0_RP ) then
          redf(i,j) = 1.0_RP
        end if

        if( abs(RES(i,j)) > abs(oldRES(i,j)) ) then
          redf(i,j) = max( TFa*redf(i,j), redf_min )
        else
          redf(i,j) = min( TFb*redf(i,j), redf_max )
        end if

        if( DRES(i,j) > 0.0_RP ) then
          redf(i,j) = -1.0_RP
        end if

        ! update surface temperature
        LST(i,j)  = LST(i,j) - redf(i,j) * RES(i,j)/DRES(i,j)

        ! save residual in this step
        oldRES(i,j) = RES(i,j)

      end do
      end do

      if( maxval(abs(RES(IS-1:IE+1,JS-1:JE+1))) < res_min ) then
        ! iteration converged
        exit
      end if

    end do

    if( n > nmax ) then
      ! not converged and stop program
      if( IO_L ) write(IO_FID_LOG,*) 'Error: surface tempearture is not converged.'
      call PRC_MPIstop
    end if

    ! put residual in ground heat flux
    GHFLX(:,:) = GHFLX(:,:) - RES(:,:)

    call CPL_AtmLnd_putCPL( &
      XMFLX, YMFLX, ZMFLX,  &
      SWUFLX, LWUFLX,       &
      SHFLX, LHFLX, GHFLX,  &
      PREC                  )

    return
  end subroutine CPL_AtmLnd_solve

  subroutine CPL_AtmLnd_unsolve
    use mod_process, only: &
       PRC_MPIstop
    use mod_grid_real, only: &
       CZ => REAL_CZ, &
       FZ => REAL_FZ
    use mod_cpl_vars, only: &
       CPL_AtmLnd_putCPL,     &
       CPL_AtmLnd_getAtm2CPL, &
       CPL_AtmLnd_getLnd2CPL, &
       LST
    implicit none

    ! works
    integer :: i, j

    real(RP) :: RES  (IA,JA)
    real(RP) :: DRES (IA,JA)

    real(RP) :: XMFLX (IA,JA) ! x-momentum flux at the surface [kg/m2/s]
    real(RP) :: YMFLX (IA,JA) ! y-momentum flux at the surface [kg/m2/s]
    real(RP) :: ZMFLX (IA,JA) ! z-momentum flux at the surface [kg/m2/s]
    real(RP) :: SWUFLX(IA,JA) ! upward shortwave flux at the surface [W/m2]
    real(RP) :: LWUFLX(IA,JA) ! upward longwave flux at the surface [W/m2]
    real(RP) :: SHFLX (IA,JA) ! sensible heat flux at the surface [W/m2]
    real(RP) :: LHFLX (IA,JA) ! latent heat flux at the surface [W/m2]
    real(RP) :: GHFLX (IA,JA) ! ground heat flux at the surface [W/m2]

    real(RP) :: DZ  (IA,JA) ! height from the surface to the lowest atmospheric layer [m]

    real(RP) :: DENS(IA,JA) ! air density at the lowest atmospheric layer [kg/m3]
    real(RP) :: MOMX(IA,JA) ! momentum x at the lowest atmospheric layer [kg/m2/s]
    real(RP) :: MOMY(IA,JA) ! momentum y at the lowest atmospheric layer [kg/m2/s]
    real(RP) :: MOMZ(IA,JA) ! momentum z at the lowest atmospheric layer [kg/m2/s]
    real(RP) :: RHOS(IA,JA) ! air density at the sruface [kg/m3]
    real(RP) :: PRES(IA,JA) ! pressure at the surface [Pa]
    real(RP) :: ATMP(IA,JA) ! air temperature at the surface [K]
    real(RP) :: QV  (IA,JA) ! ratio of water vapor mass to total mass at the lowest atmospheric layer [kg/kg]
    real(RP) :: PREC(IA,JA) ! precipitaton flux at the surface [kg/m2/s]
    real(RP) :: SWD (IA,JA) ! downward short-wave radiation flux at the surface (upward positive) [W/m2]
    real(RP) :: LWD (IA,JA) ! downward long-wave radiation flux at the surface (upward positive) [W/m2]

    real(RP) :: TG  (IA,JA) ! soil temperature [K]
    real(RP) :: QVEF(IA,JA) ! efficiency of evaporation [no unit]
    real(RP) :: EMIT(IA,JA) ! emissivity in long-wave radiation [no unit]
    real(RP) :: ALB (IA,JA) ! surface albedo in short-wave radiation [no unit]
    real(RP) :: TCS (IA,JA) ! thermal conductivity for soil [W/m/K]
    real(RP) :: DZG (IA,JA) ! soil depth [m]
    real(RP) :: Z0M (IA,JA) ! roughness length for momemtum [m]
    real(RP) :: Z0H (IA,JA) ! roughness length for heat [m]
    real(RP) :: Z0E (IA,JA) ! roughness length for vapor [m]

    if( IO_L ) write(IO_FID_LOG,*) '*** CPL unsolve: Atmos-Land'

    call CPL_AtmLnd_getAtm2CPL( &
      DENS, MOMX, MOMY, MOMZ, & ! (out)
      RHOS, PRES, ATMP, QV,   & ! (out)
      PREC, SWD, LWD          ) ! (out)

    call CPL_AtmLnd_getLnd2CPL( &
      TG, QVEF, EMIT, & ! (out)
      ALB, TCS, DZG,  & ! (out)
      Z0M, Z0H, Z0E   ) ! (out)

    DZ(:,:) = CZ(KS,:,:) - FZ(KS-1,:,:)

    ! calc. surface fluxes
    call heat_balance( &
      RES, DRES,                                              & ! (out)
      XMFLX, YMFLX, ZMFLX,                                    & ! (out)
      SWUFLX, LWUFLX, SHFLX, LHFLX, GHFLX,                    & ! (out)
      DZ, LST,                                                & ! (in)
      DENS, MOMX, MOMY, MOMZ, RHOS, PRES, ATMP, QV, SWD, LWD, & ! (in)
      TG, QVEF, EMIT, ALB, TCS, DZG, Z0M, Z0H, Z0E            ) ! (in)

    call CPL_AtmLnd_putCPL( &
      XMFLX, YMFLX, ZMFLX,  &
      SWUFLX, LWUFLX,       &
      SHFLX, LHFLX, GHFLX,  &
      PREC                  )

    return
  end subroutine CPL_AtmLnd_unsolve

! --- Private procedure

  subroutine heat_balance( &
      RES, DRES,                                              & ! (out)
      XMFLX, YMFLX, ZMFLX,                                    & ! (out)
      SWUFLX, LWUFLX, SHFLX, LHFLX, GHFLX,                    & ! (out)
      DZ, TS,                                                 & ! (in)
      DENS, MOMX, MOMY, MOMZ, RHOS, PRES, ATMP, QV, SWD, LWD, & ! (in)
      TG, QVEF, EMIT, ALB, TCS, DZG, Z0M, Z0H, Z0E            ) ! (in)
    use mod_const, only: &
      GRAV   => CONST_GRAV,  &
      CPdry  => CONST_CPdry, &
      Rvap   => CONST_Rvap,  &
      STB    => CONST_STB,   &
      LH0    => CONST_LH0,   &
      P00    => CONST_PRE00
    use mod_atmos_saturation, only: &
      qsat => ATMOS_SATURATION_pres2qsat_all
    use mod_cpl_bulkcoef, only: &
      CPL_bulkcoef
    implicit none

    ! argument
    real(RP), intent(out) :: RES   (IA,JA) ! residual in the equation of heat balance
    real(RP), intent(out) :: DRES  (IA,JA) ! d(residual) / d(Ts)
    real(RP), intent(out) :: XMFLX (IA,JA) ! x-momentum flux at the surface [kg/m2/s]
    real(RP), intent(out) :: YMFLX (IA,JA) ! y-momentum flux at the surface [kg/m2/s]
    real(RP), intent(out) :: ZMFLX (IA,JA) ! z-momentum flux at the surface [kg/m2/s]
    real(RP), intent(out) :: SWUFLX(IA,JA) ! upward shortwave flux at the surface [W/m2]
    real(RP), intent(out) :: LWUFLX(IA,JA) ! upward longwave flux at the surface [W/m2]
    real(RP), intent(out) :: SHFLX (IA,JA) ! sensible heat flux at the surface [W/m2]
    real(RP), intent(out) :: LHFLX (IA,JA) ! latent heat flux at the surface [W/m2]
    real(RP), intent(out) :: GHFLX (IA,JA) ! ground heat flux at the surface [W/m2]

    real(RP), intent(in) :: DZ  (IA,JA) ! height from the surface to the lowest atmospheric layer [m]
    real(RP), intent(in) :: TS  (IA,JA) ! skin temperature [K]

    real(RP), intent(in) :: DENS(IA,JA) ! air density at the lowest atmospheric layer [kg/m3]
    real(RP), intent(in) :: MOMX(IA,JA) ! momentum x at the lowest atmospheric layer [kg/m2/s]
    real(RP), intent(in) :: MOMY(IA,JA) ! momentum y at the lowest atmospheric layer [kg/m2/s]
    real(RP), intent(in) :: MOMZ(IA,JA) ! momentum z at the lowest atmospheric layer [kg/m2/s]
    real(RP), intent(in) :: RHOS(IA,JA) ! air density at the sruface [kg/m3]
    real(RP), intent(in) :: PRES(IA,JA) ! pressure at the surface [Pa]
    real(RP), intent(in) :: ATMP(IA,JA) ! air temperature at the surface [K]
    real(RP), intent(in) :: QV  (IA,JA) ! ratio of water vapor mass to total mass at the lowest atmospheric layer [kg/kg]
    real(RP), intent(in) :: SWD (IA,JA) ! downward short-wave radiation flux at the surface (upward positive) [W/m2]
    real(RP), intent(in) :: LWD (IA,JA) ! downward long-wave radiation flux at the surface (upward positive) [W/m2]

    real(RP), intent(in) :: TG  (IA,JA) ! soil temperature [K]
    real(RP), intent(in) :: QVEF(IA,JA) ! efficiency of evaporation [no unit]
    real(RP), intent(in) :: EMIT(IA,JA) ! emissivity in long-wave radiation [no unit]
    real(RP), intent(in) :: ALB (IA,JA) ! surface albedo in short-wave radiation [no unit]
    real(RP), intent(in) :: TCS (IA,JA) ! thermal conductivity for soil [W/m/K]
    real(RP), intent(in) :: DZG (IA,JA) ! soil depth [m]
    real(RP), intent(in) :: Z0M (IA,JA) ! roughness length for momemtum [m]
    real(RP), intent(in) :: Z0H (IA,JA) ! roughness length for heat [m]
    real(RP), intent(in) :: Z0E (IA,JA) ! roughness length for vapor [m]

    ! constant
    real(RP), parameter :: dTS    =   1.0E-8_RP ! delta TS
    real(RP), parameter :: U_minM =   0.0_RP    ! minimum U_abs for u,v,w
    real(RP), parameter :: U_minH =   0.0_RP    !                   T
    real(RP), parameter :: U_minE =   0.0_RP    !                   q
    real(RP), parameter :: U_maxM = 100.0_RP    ! maximum U_abs for u,v,w
    real(RP), parameter :: U_maxH = 100.0_RP    !                   T
    real(RP), parameter :: U_maxE = 100.0_RP    !                   q

    ! work
    real(RP) :: Uabs ! absolute velocity at the lowest atmospheric layer [m/s]
    real(RP) :: Cm, Ch, Ce ! bulk transfer coeff. [no unit]
    real(RP) :: dCm, dCh, dCe

    real(RP) :: SQV, dSQV ! saturation water vapor mixing ratio at surface [kg/kg]
    real(RP) :: dLWUFLX, dGHFLX, dSHFLX, dLHFLX

    integer :: i, j
    !---------------------------------------------------------------------------

    ! at (u, y, layer)
    do j = JS, JE
    do i = IS, IE
      Uabs = sqrt( &
             ( 0.5_RP * ( MOMZ(i,j) + MOMZ(i+1,j)                               ) )**2 &
           + ( 2.0_RP *   MOMX(i,j)                                               )**2 &
           + ( 0.5_RP * ( MOMY(i,j-1) + MOMY(i,j) + MOMY(i+1,j-1) + MOMY(i+1,j) ) )**2 &
           ) / ( DENS(i,j) + DENS(i+1,j) )

      call CPL_bulkcoef( &
          Cm, Ch, Ce,                           & ! (out)
          ( ATMP(i,j) + ATMP(i+1,j) ) * 0.5_RP, & ! (in)
          ( TS  (i,j) + TS  (i+1,j) ) * 0.5_RP, & ! (in)
          DZ(i,j), Uabs,                        & ! (in)
          Z0M(i,j), Z0H(i,j), Z0E(i,j)          ) ! (in)

      XMFLX(i,j) = - Cm * min(max(Uabs,U_minM),U_maxM) * MOMX(i,j)
    enddo
    enddo

    ! at (x, v, layer)
    do j = JS, JE
    do i = IS, IE
      Uabs = sqrt( &
             ( 0.5_RP * ( MOMZ(i,j) + MOMZ(i,j+1)                               ) )**2 &
           + ( 0.5_RP * ( MOMX(i-1,j) + MOMX(i,j) + MOMX(i-1,j+1) + MOMX(i,j+1) ) )**2 &
           + ( 2.0_RP *   MOMY(i,j)                                               )**2 &
           ) / ( DENS(i,j) + DENS(i,j+1) )

      call CPL_bulkcoef( &
          Cm, Ch, Ce,                           & ! (out)
          ( ATMP(i,j) + ATMP(i,j+1) ) * 0.5_RP, & ! (in)
          ( TS  (i,j) + TS  (i,j+1) ) * 0.5_RP, & ! (in)
          DZ(i,j), Uabs,                        & ! (in)
          Z0M(i,j), Z0H(i,j), Z0E(i,j)          ) ! (in)

      YMFLX(i,j) = - Cm * min(max(Uabs,U_minM),U_maxM) * MOMY(i,j)
    enddo
    enddo

    ! at cell center
    do j = JS-1, JE+1
    do i = IS-1, IE+1
      Uabs = sqrt( &
             ( MOMZ(i,j)               )**2 &
           + ( MOMX(i-1,j) + MOMX(i,j) )**2 &
           + ( MOMY(i,j-1) + MOMY(i,j) )**2 &
           ) / DENS(i,j) * 0.5_RP

      call CPL_bulkcoef( &
          Cm, Ch, Ce,                  & ! (out)
          ATMP(i,j), TS(i,j),          & ! (in)
          DZ(i,j), Uabs,               & ! (in)
          Z0M(i,j), Z0H(i,j), Z0E(i,j) ) ! (in)

      ZMFLX(i,j) = - Cm * min(max(Uabs,U_minM),U_maxM) * MOMZ(i,j) * 0.5_RP

      ! saturation at the surface
      call qsat( SQV, TS(i,j), PRES(i,j) )

      SHFLX (i,j) = CPdry * min(max(Uabs,U_minH),U_maxH) * RHOS(i,j) * Ch * ( TS(i,j) - ATMP(i,j) )
      LHFLX (i,j) = LH0   * min(max(Uabs,U_minE),U_maxE) * RHOS(i,j) * QVEF(i,j) * Ce * ( SQV - QV(i,j) )
      GHFLX (i,j) = -2.0_RP * TCS(i,j) * ( TS(i,j) - TG(i,j)  ) / DZG(i,j)
      SWUFLX(i,j) = ALB(i,j) * SWD(i,j)
      LWUFLX(i,j) = EMIT(i,j) * STB * TS(i,j)**4

      ! calculation for residual
      RES(i,j) = SWD(i,j) - SWUFLX(i,j) + LWD(i,j) - LWUFLX(i,j) - SHFLX(i,j) - LHFLX(i,j) + GHFLX(i,j)

      call CPL_bulkcoef( &
          dCm, dCh, dCe,               & ! (out)
          ATMP(i,j), TS(i,j)+dTS,      & ! (in)
          DZ(i,j), Uabs,               & ! (in)
          Z0M(i,j), Z0H(i,j), Z0E(i,j) ) ! (in)

      call qsat( dSQV, TS(i,j)+dTS, PRES(i,j) )

      dSHFLX  = CPdry * min(max(Uabs,U_minH),U_maxH) * RHOS(i,j) &
              * ( (dCh-Ch)/dTS * ( TS(i,j) - ATMP(i,j) ) + Ch )
      dLHFLX  = LH0   * min(max(Uabs,U_minE),U_maxE) * RHOS(i,j) * QVEF(i,j) &
              * ( (dCe-Ce)/dTS * ( SQV - QV(i,j) ) + Ce * (dSQV-SQV)/dTS )
      dGHFLX  = -2.0_RP * TCS(i,j) / DZG(i,j)
      dLWUFLX = 4.0_RP * EMIT(i,j) * STB * TS(i,j)**3

      ! calculation for d(residual)/dTS
      DRES(i,j) = - dLWUFLX - dSHFLX - dLHFLX + dGHFLX
    enddo
    enddo

    return
  end subroutine heat_balance

end module mod_cpl_atmos_land
