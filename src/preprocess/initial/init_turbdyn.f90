!-------------------------------------------------------------------------------
!> Program Dynamically Forced Turbulence Test for SCALE-LES ver.3
!!
!! @par Description
!!          SCALE: Scalable Computing by Advanced Library and Environment
!!          Numerical model for LES-scale weather
!!
!! @author H.Tomita and SCALE developpers
!!
!! @par History
!! @li      2012-01-31 (Y.Miyamoto) [new] for Kelvin Helmholtz waves
!!
!!
!<
!-------------------------------------------------------------------------------
program turbdyn
  !-----------------------------------------------------------------------------
  !
  !++ used modules
  !
  use mod_stdio, only: &
     IO_setup
  use mod_process, only: &
     PRC_setup,    &
     PRC_MPIstart, &
     PRC_MPIstop
  use mod_const, only: &
     CONST_setup
  use mod_time, only: &
     TIME_setup,    &
     TIME_rapstart, &
     TIME_rapend,   &
     TIME_rapreport
  use mod_grid, only: &
     GRID_setup
  use mod_comm, only: &
     COMM_setup
  use mod_fileio, only: &
     FIO_setup, &
     FIO_finalize
  use mod_atmos_vars, only: &
     ATMOS_vars_setup, &
     ATMOS_vars_restart_write
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

  ! setup constants
  call CONST_setup

  ! setup time
  call TIME_setup

  ! setup file I/O
  call FIO_setup

  ! setup horisontal/veritical grid system
  call GRID_setup

  ! setup mpi communication
  call COMM_setup

  ! setup atmosphere
  call ATMOS_vars_setup


  !########## main ##########

  call TIME_rapstart('Main')

  ! make initial state (restart)
  call MKEXP_turbdyn

  ! output restart
  call ATMOS_vars_restart_write

  call TIME_rapend('Main')


  !########## Finalize ##########
  call TIME_rapreport

  call FIO_finalize
  ! stop MPI
  call PRC_MPIstop

  stop
  !=============================================================================
contains

  !-----------------------------------------------------------------------------
  !> Make initial state for cold bubble experiment
  !-----------------------------------------------------------------------------
  subroutine MKEXP_turbdyn
    use mod_stdio, only: &
       IO_FID_CONF, &
       IO_FID_LOG,  &
       IO_L
    use mod_process, only: &
       PRC_MPIstop
    use mod_const, only : &
       GRAV   => CONST_GRAV,   &
       Rdry   => CONST_Rdry,   &
       CPdry  => CONST_CPdry,  &
       CVdry  => CONST_CVdry,  &
       CPovR  => CONST_CPovR,  &
       RovCP  => CONST_RovCP,  &
       CVovCP => CONST_CVovCP, &
       EPSvap => CONST_EPSvap, &
       Pstd   => CONST_Pstd
    use mod_grid, only : &
       IA => GRID_IA, &
       JA => GRID_JA, &
       KA => GRID_KA, &
       IS => GRID_IS, &
       IE => GRID_IE, &
       JS => GRID_JS, &
       JE => GRID_JE, &
       KS => GRID_KS, &
       KE => GRID_KE, &
       GRID_CX, &
       GRID_CY, &
       GRID_CZ
    use mod_atmos_vars, only: &
       QA => A_QA,     &
       I_QV,           &
       ATMOS_vars_get, &
       ATMOS_vars_put
    implicit none

    real(8) :: ENV_THETA  = 300.D0 ! Potential Temperature of environment [K]
    real(8) :: ENV_DTHETA =   5.D0 ! Potential Temperature of environment [K]
    real(8) :: ENV_RH     = 50.D0  ! Relative Humidity of environment [%]
    real(8) :: ENV_XVEL2  = 10.D0  ! environment x-velocity in layer 2 [m s-1]
    real(8) :: ENV_XVEL1  =  0.D0  ! environment x-velocity in layer 1 [m s-1]
    real(8) :: LEV_XVEL2  = 1.7D3  ! level at which x-velocity changes [m]
    real(8) :: LEV_XVEL1  = 1.3D3  ! level at which x-velocity changes [m]
    real(8) :: ENV_YVEL2  =  0.D0  ! environment y-velocity in layer 2 [m s-1]
    real(8) :: ENV_YVEL1  =  0.D0  ! environment y-velocity in layer 1 [m s-1]
    real(8) :: LEV_YVEL2  =  0.D0  ! level at which y-velocity changes [m]
    real(8) :: LEV_YVEL1  =  0.D0  ! level at which y-velocity changes [m]

    NAMELIST / PARAM_MKEXP_TURBDYN / &
       ENV_THETA,  &
       ENV_DTHETA, &
       ENV_RH,     &
       ENV_XVEL1,  &
       ENV_XVEL2,  &
       LEV_XVEL1,  &
       LEV_XVEL2,  &
       ENV_YVEL1,  &
       ENV_YVEL2,  &
       LEV_YVEL1,  &
       LEV_YVEL2

    real(8) :: dens(KA,IA,JA)      ! density     [kg/m3]
    real(8) :: momx(KA,IA,JA)      ! momentum(x) [kg/m3 * m/s]
    real(8) :: momy(KA,IA,JA)      ! momentum(y) [kg/m3 * m/s]
    real(8) :: momz(KA,IA,JA)      ! momentum(z) [kg/m3 * m/s]
    real(8) :: rhot(KA,IA,JA)      ! rho * theta [kg/m3 * K]
    real(8) :: qtrc(KA,IA,JA,QA)   ! tracer mixing ratio [kg/kg],[1/m3]

    real(8) :: pres(KA,IA,JA)    ! pressure [Pa]
    real(8) :: temp(KA,IA,JA)    ! temperature [K]
    real(8) :: pott(KA,IA,JA)    ! potential temperature [K]

    real(8) :: rh(KA,IA,JA)
    real(8) :: rndm(KA,IA,JA)
    real(8) :: psat, qsat, dz, dzz, RovP
    real(8) :: dist, dhyd, dgrd, tt, pp, dd, d1, d2, DENS_Z0, ri

    integer :: i, j, k, n, im, jm
    integer :: ierr
    !---------------------------------------------------------------------------

    if( IO_L ) write(IO_FID_LOG,*)
    if( IO_L ) write(IO_FID_LOG,*) '++++++ START MAKING INITIAL DATA ++++++'
    if( IO_L ) write(IO_FID_LOG,*)
    if( IO_L ) write(IO_FID_LOG,*) '+++ Module[TURBDYN]/Categ[INIT]'

    !--- read namelist
    rewind(IO_FID_CONF)
    read(IO_FID_CONF,nml=PARAM_MKEXP_turbdyn,iostat=ierr)

    if( ierr < 0 ) then !--- missing
       if( IO_L ) write(IO_FID_LOG,*) '*** Not found namelist. Default used.'
    elseif( ierr > 0 ) then !--- fatal error
       write(*,*) 'xxx Not appropriate names in namelist PARAM_MKEXP_turbdyn. Check!'
       call PRC_MPIstop
    endif
    if( IO_L ) write(IO_FID_LOG,nml=PARAM_MKEXP_turbdyn)

    call ATMOS_vars_get( dens, momx, momy, momz, rhot, qtrc )

    pott(:,:,:)   = ENV_THETA
    dens(:,:,:)   = DENS_Z0
    rh  (:,:,:)   = ENV_RH
    momz(:,:,:)   = 0.D0
    qtrc(:,:,:,:) = 0.D0
    RovP = Rdry / (Pstd)**CPovR
    tt = ENV_THETA - GRAV / CPdry * GRID_CZ(KS)
    pp = Pstd * ( tt/ENV_THETA )**CPovR
    DENS_Z0 = Pstd / Rdry / ENV_THETA * ( pp/Pstd )**CVovCP

    do j = JS, JE
    do i = IS, IE
    do k = KS, KE

       if ( GRID_CZ(k) < LEV_XVEL1 ) then
          pott(k,i,j) = ENV_THETA
       else if ( GRID_CZ(k) > LEV_XVEL2 ) then
          pott(k,i,j) = ENV_THETA + ENV_DTHETA
       else
          pott(k,i,j) = ENV_THETA + ENV_DTHETA * ( GRID_CZ(k) - LEV_XVEL1 )/( LEV_XVEL2 - LEV_XVEL1 ) 
       end if

    enddo
    enddo
    enddo

    do j = JS, JE
    do i = IS, IE
    do k = KS, KE

       if ( k == KS ) then
          dens(k,i,j) = DENS_Z0
       else
          dz = GRID_CZ(k) - GRID_CZ(k-1)
          dhyd = 0.D0
          d1 = 0.D0
          d2 = dens(k-1,i,j)
          n = 0
          do while ( dabs(d2-d1) > 1.D-10 )
             n = n + 1
             d1 = d2
             dhyd = - ( Pstd**( -RovCP )*Rdry*pott(k  ,i,j)*d1            )**( CPdry/CVdry ) / dz - 0.5D0*GRAV*d1 &
                    + ( Pstd**( -RovCP )*Rdry*pott(k-1,i,j)*dens(k-1,i,j) )**( CPdry/CVdry ) / dz - 0.5D0*GRAV*dens(k-1,i,j)
             dgrd = - ( Pstd**( -RovCP )*Rdry*pott(k,i,j) )**( CPdry/CVdry ) *CPdry/CVdry/dz * d1**( Rdry/CVdry ) - 0.5D0*GRAV
             d2 = d1 - dhyd / dgrd
          end do
          dens(k,i,j) = d2
          if ( n < 100 ) write(IO_FID_LOG,*) 'iteration converged',n,dhyd,d2,d1
       end if

       pres(k,i,j) = ( dens(k,i,j) * Rdry * pott(k,i,j) )**( CPdry/CVdry ) * ( Pstd )**( -Rdry/CVdry )
       temp(k,i,j) = pres(k,i,j) / dens(k,i,j) * Rdry
       rhot(k,i,j) = dens(k,i,j) * pott(k,i,j)

       if ( GRID_CZ(k) < LEV_XVEL1 ) then
          momx(k,i,j) = ENV_XVEL1 * dens(k,i,j)
       else if ( GRID_CZ(k) > LEV_XVEL2 ) then
          momx(k,i,j) = ENV_XVEL2 * dens(k,i,j)
       else
          momx(k,i,j) = ( ENV_XVEL1 + ( ENV_XVEL2 - ENV_XVEL1 ) * ( GRID_CZ(k) - LEV_XVEL1 )/( LEV_XVEL2 - LEV_XVEL1 ) ) * dens(k,i,j)
       end if

       if ( GRID_CZ(k) <= LEV_YVEL1 ) then
          momy(k,i,j) = ENV_YVEL1 * dens(k,i,j)
       else if ( GRID_CZ(k) > LEV_YVEL2 ) then
          momy(k,i,j) = ENV_YVEL2 * dens(k,i,j)
       else
          momy(k,i,j) = ( ENV_YVEL1 + ( ENV_YVEL2 - ENV_YVEL1 ) * ( GRID_CZ(k) - LEV_YVEL1 )/( LEV_YVEL2 - LEV_YVEL1 ) ) * dens(k,i,j)
       end if

    enddo
    enddo
    enddo

    call random_number(rndm)

    do j = JS, JE
    do i = IS, IE
    do k = KS, KE
!       if ( GRID_CZ(k) >= LEV_XVEL1 .and. GRID_CZ(k) <= LEV_XVEL2 ) then
          momx(k,i,j) = momx(k,i,j) + ( ENV_XVEL2 + ENV_XVEL1 ) / 100.0D0 * rndm(k,i,j)
          rhot(k,i,j) = rhot(k,i,j) + dens(k,i,j) * ENV_THETA   / 100.0D0 * rndm(k,i,j)
!       end if
    end do
    end do
    end do

    write(IO_FID_LOG,*) 'layer, x-velocity, Richardson number'
    do k = KS+1, KE
       im = nint( dble(IE-IS)/2 )
       jm = nint( dble(JE-JS)/2 )
       dz = GRID_CZ(k) - GRID_CZ(k-1)
       ri = dz * GRAV / ENV_THETA * ( pott(k,im,jm) - pott(k-1,im,jm) ) &
          / ( momx(k,im,jm)/dens(k,im,jm) - momx(k-1,im,jm)/dens(k-1,im,jm) )**2
       write(IO_FID_LOG,*) k,momx(k,im,jm)/dens(k,im,jm),ri
    end do

    call ATMOS_vars_put( dens, momx, momy, momz, rhot, qtrc  )

    if( IO_L ) write(IO_FID_LOG,*) '++++++ END MAKING INITIAL DATA ++++++'
    if( IO_L ) write(IO_FID_LOG,*) 

    return
  end subroutine MKEXP_turbdyn

  subroutine moist_psat_water0( t, psat )
    ! psat : Clasius-Clapeyron: based on CPV, CPL constant
    use mod_const, only : &
       Rvap  => CONST_Rvap,  &
       CPvap => CONST_CPvap, &
       CL    => CONST_CL,    &
       LH0   => CONST_LH00,  &
       PSAT0 => CONST_PSAT0, &
       T00   => CONST_TEM00
    implicit none

    real(8), intent(in)  :: t
    real(8), intent(out) :: psat

    real(8)              :: Tmin = 10.D0
    !---------------------------------------------------------------------------

    psat = PSAT0 * ( max(t,Tmin)/T00 ) ** ( ( CPvap-CL )/Rvap ) &
         * exp ( LH0/Rvap * ( 1.0D0/T00 - 1.0D0/max(t,Tmin) ) )

    return
  end subroutine moist_psat_water0

end program turbdyn