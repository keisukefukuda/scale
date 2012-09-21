!-------------------------------------------------------------------------------
!> module Atmosphere / reference state
!!
!! @par Description
!!          Reference state of Atmosphere
!!
!! @author H.Tomita and SCALE developpers
!!
!! @par History
!! @li      2011-12-11 (H.Yashiro)  [new]
!! @li      2012-03-23 (H.Yashiro)  [mod] Explicit index parameter inclusion
!!
!<
!-------------------------------------------------------------------------------
module mod_atmos_refstate
  !-----------------------------------------------------------------------------
  !
  !++ used modules
  !
  use mod_stdio, only: &
     IO_FID_LOG, &
     IO_L,       &
     IO_SYSCHR,  &
     IO_FILECHR
  !-----------------------------------------------------------------------------
  implicit none
  private
  !-----------------------------------------------------------------------------
  !
  !++ Public procedure
  !
  public :: ATMOS_REFSTATE_setup
  public :: ATMOS_REFSTATE_read
  public :: ATMOS_REFSTATE_write
  public :: ATMOS_REFSTATE_generate

  !-----------------------------------------------------------------------------
  !
  !++ included parameters
  !
  include 'inc_index.h'

  !-----------------------------------------------------------------------------
  !
  !++ Public parameters & variables
  !
  real(8), public, save :: ATMOS_REFSTATE_dens(KA) ! refernce density [kg/m3]
  real(8), public, save :: ATMOS_REFSTATE_pott(KA) ! refernce potential temperature [K]

  !-----------------------------------------------------------------------------
  !
  !++ Private procedure
  !
  !-----------------------------------------------------------------------------
  !
  !++ Private parameters & variables
  !
  character(len=IO_FILECHR), private :: ATMOS_REFSTATE_IN_BASENAME  = ''
  character(len=IO_FILECHR), private :: ATMOS_REFSTATE_OUT_BASENAME = ''
  character(len=IO_SYSCHR),  private :: ATMOS_REFSTATE_TYPE         = 'ISA'
  real(8),                   private :: ATMOS_REFSTATE_TEMP_SFC     = 300.D0 ! surface temperature
  real(8),                   private :: ATMOS_REFSTATE_POTT_UNIFORM = 300.D0 ! uniform potential temperature

  !-----------------------------------------------------------------------------
contains

  !-----------------------------------------------------------------------------
  !> Initialize Reference state
  !-----------------------------------------------------------------------------
  subroutine ATMOS_REFSTATE_setup
    use mod_stdio, only: &
       IO_FID_CONF
    use mod_process, only: &
       PRC_MPIstop
    implicit none

    NAMELIST / PARAM_ATMOS_REFSTATE / &
       ATMOS_REFSTATE_IN_BASENAME,  &
       ATMOS_REFSTATE_OUT_BASENAME, &
       ATMOS_REFSTATE_TYPE,         &
       ATMOS_REFSTATE_POTT_UNIFORM, &
       ATMOS_REFSTATE_TEMP_SFC

    integer :: ierr
    !---------------------------------------------------------------------------

    if( IO_L ) write(IO_FID_LOG,*)
    if( IO_L ) write(IO_FID_LOG,*) '+++ Module[REFSTATE]/Categ[ATMOS]'

    !--- read namelist
    rewind(IO_FID_CONF)
    read(IO_FID_CONF,nml=PARAM_ATMOS_REFSTATE,iostat=ierr)

    if( ierr < 0 ) then !--- missing
       if( IO_L ) write(IO_FID_LOG,*) '*** Not found namelist. Default used.'
    elseif( ierr > 0 ) then !--- fatal error
       write(*,*) 'xxx Not appropriate names in namelist PARAM_ATMOS_REFSTATE. Check!'
       call PRC_MPIstop
    endif
    if( IO_L ) write(IO_FID_LOG,nml=PARAM_ATMOS_REFSTATE)

    if ( ATMOS_REFSTATE_IN_BASENAME /= '' ) then
       call ATMOS_REFSTATE_read
    else
       if( IO_L ) write(IO_FID_LOG,*) '*** Not found reference state file. Generate!'

       if ( trim(ATMOS_REFSTATE_TYPE) == 'ISA' ) then
          if( IO_L ) write(IO_FID_LOG,*) '*** Reference type: ISA'
       elseif ( trim(ATMOS_REFSTATE_TYPE) == 'UNIFORM' ) then
          if( IO_L ) write(IO_FID_LOG,*) '*** Reference type: UNIFORM POTT'
       else
          write(*,*) 'xxx ATMOS_REFSTATE_TYPE must be "ISA" or "UNIFORM". Check!', trim(ATMOS_REFSTATE_TYPE)
          call PRC_MPIstop
       endif
    
       call ATMOS_REFSTATE_generate
    endif

    if ( ATMOS_REFSTATE_OUT_BASENAME /= '' ) then
       call ATMOS_REFSTATE_write
    endif

    return
  end subroutine ATMOS_REFSTATE_setup

  !-----------------------------------------------------------------------------
  !> Read Reference state
  !-----------------------------------------------------------------------------
  subroutine ATMOS_REFSTATE_read
    use mod_fileio, only: &
       FIO_input_1D
    implicit none

    character(len=IO_FILECHR) :: bname
    !---------------------------------------------------------------------------

    if( IO_L ) write(IO_FID_LOG,*)
    if( IO_L ) write(IO_FID_LOG,*) '*** Input Refstate file ***'

    write(bname,'(A,A,F15.3)') trim(ATMOS_REFSTATE_IN_BASENAME)

    call FIO_input_1D( ATMOS_REFSTATE_dens(:), bname, 'DENS', 'Z1D', 1, KA, 1, .true. )
    call FIO_input_1D( ATMOS_REFSTATE_pott(:), bname, 'POTT', 'Z1D', 1, KA, 1, .true. )

    return
  end subroutine ATMOS_REFSTATE_read

  !-----------------------------------------------------------------------------
  !> Write Reference state
  !-----------------------------------------------------------------------------
  subroutine ATMOS_REFSTATE_write
    use mod_process, only: &
       PRC_myrank, &
       PRC_master
    use mod_fileio_h, only: &
       FIO_HMID, &
       FIO_REAL8
    use mod_fileio, only: &
       FIO_output_1D
    implicit none

    character(len=IO_FILECHR) :: bname
    character(len=FIO_HMID)   :: desc
    !---------------------------------------------------------------------------

    if( IO_L ) write(IO_FID_LOG,*)
    if( IO_L ) write(IO_FID_LOG,*) '*** Output grid file ***'
    if( IO_L ) write(IO_FID_LOG,*) '*** Only at Master node ***'

    if ( PRC_myrank == PRC_master ) then
       write(bname,'(A,A,F15.3)') trim(ATMOS_REFSTATE_OUT_BASENAME)
       desc  = 'SCALE3 Refstate'

       call FIO_output_1D( ATMOS_REFSTATE_dens(:), bname, desc, '',       &
                          'DENS', 'Reference state of rho', '', 'kg/m3', &
                          FIO_REAL8, 'Z1D', 1, KA, 1, 0.D0, 0.D0, .true. )
       call FIO_output_1D( ATMOS_REFSTATE_pott(:), bname, desc, '',       &
                          'POTT', 'Reference state of theta', '', 'K',   &
                          FIO_REAL8, 'Z1D', 1, KA, 1, 0.D0, 0.D0, .true. )
    endif

    return
  end subroutine ATMOS_REFSTATE_write

  !-----------------------------------------------------------------------------
  !> Generate Reference state (International Standard Atmosphere)
  !-----------------------------------------------------------------------------
  subroutine ATMOS_REFSTATE_generate
    use mod_const, only : &
       GRAV   => CONST_GRAV,  &
       Rdry   => CONST_Rdry,  &
       RovCP  => CONST_RovCP, &
       Pstd   => CONST_Pstd,  &
       P00    => CONST_PRE00
    use mod_grid, only : &
       CZ   => GRID_CZ
    use mod_atmos_hydrostatic, only: &
       hydro_buildrho_1d => ATMOS_HYDRO_buildrho_1d
    implicit none

    integer, parameter :: nref = 8
    real(8), parameter :: CZ_isa(nref) = (/     0.0D0,  &
                                            11000.0D0,  &
                                            20000.0D0,  &
                                            32000.0D0,  &
                                            47000.0D0,  &
                                            51000.0D0,  &
                                            71000.0D0,  &
                                            84852.0D0   /)
    real(8), parameter :: GAMMA(nref)  = (/    -6.5D-3, &
                                                0.0D0 , &
                                                1.0D-3, &
                                                2.8D-3, &
                                                0.0D-3, &
                                               -2.8D-3, &
                                               -2.0D-3, &
                                                0.0D0   /)
    real(8) :: temp_isa(nref)
    real(8) :: pres_isa(nref)

    real(8) :: temp(KA)
    real(8) :: pres(KA)
    real(8) :: dens(KA)
    real(8) :: pott(KA)

    real(8) :: qv(KA) = 0.D0
    real(8) :: qc(KA) = 0.D0
    real(8) :: temp_sfc
    real(8) :: qv_sfc = 0.D0
    real(8) :: qc_sfc = 0.D0

    real(8) :: gmr !! grav / Rdry
    integer :: i, k
    !---------------------------------------------------------------------------

    gmr      = GRAV / Rdry

    !--- ISA profile
    temp_isa(1) = ATMOS_REFSTATE_TEMP_SFC
    pres_isa(1) = Pstd

    do i = 2, nref
       temp_isa(i) = temp_isa(i-1) + GAMMA(i-1) * ( CZ_isa(i)-CZ_isa(i-1) )

       if ( GAMMA(i-1) == 0.D0 ) then
          pres_isa(i) = pres_isa(i-1) * exp( -gmr / temp_isa(i) * ( CZ_isa(i)-CZ_isa(i-1) ) )
       else
          pres_isa(i) = pres_isa(i-1) * ( temp_isa(i)/temp_isa(i-1) ) ** ( -gmr/GAMMA(i-1) )
       endif
    enddo

    if( IO_L ) write(IO_FID_LOG,*)
    if( IO_L ) write(IO_FID_LOG,*) '###### ICAO International Standard Atmosphere ######'
    if( IO_L ) write(IO_FID_LOG,*) '      height:  lapse rate:    pressure: temperature'
    do i = 1, nref
       if( IO_L ) write(IO_FID_LOG,'(4(f13.5))') CZ_isa(i), GAMMA(i), pres_isa(i), temp_isa(i)
    enddo
    if( IO_L ) write(IO_FID_LOG,*) '####################################################'

    !--- make reference state
    do k = KS, KE
       do i = 2, nref
          if ( CZ(k) > CZ_isa(i-1) .AND. CZ(k) <= CZ_isa(i) ) then

             temp(k) = temp_isa(i-1) + GAMMA(i-1) * ( CZ(k)-CZ_isa(i-1) )
             if ( GAMMA(i-1) == 0.D0 ) then
                pres(k) = pres_isa(i-1) * exp( -gmr/temp_isa(i-1) * ( CZ(k)-CZ_isa(i-1) ) )
             else
                pres(k) = pres_isa(i-1) * ( temp(k)/temp_isa(i-1) ) ** ( -gmr/GAMMA(i-1) )
             endif

          elseif ( CZ(k) <= CZ_isa(1)    ) then

             temp(k) = temp_isa(1) + GAMMA(1) * ( CZ(k)-CZ_isa(1) )
             pres(k) = pres_isa(1) * ( temp(k)/temp_isa(1) ) ** ( -gmr/GAMMA(1) )

          elseif ( CZ(k)  > CZ_isa(nref) ) then

             temp(k) = temp(k-1)
             pres(k) = pres_isa(i-1) * exp( -gmr/temp_isa(i-1) * ( CZ(k)-CZ_isa(i-1) ) )

          endif
       enddo

!       dens(k) = pres(k) / ( temp(k) * Rdry )
       pott(k) = temp(k) * ( P00/pres(k) )**RovCP
    enddo

!    dens(   1:KS-1) = dens(KS)
!    dens(KE+1:KA  ) = dens(KE)
    pott(   1:KS-1) = pott(KS)
    pott(KE+1:KA  ) = pott(KE)

    if ( trim(ATMOS_REFSTATE_TYPE) == 'UNIFORM' ) then
       if( IO_L ) write(IO_FID_LOG,*)
       if( IO_L ) write(IO_FID_LOG,*) '*** pot.temp. is overwrited by uniform value:', ATMOS_REFSTATE_POTT_UNIFORM
       pott(:) = ATMOS_REFSTATE_POTT_UNIFORM
    endif

    ! make density & pressure profile 
    call hydro_buildrho_1d( dens    (:), & ! [OUT]
                            temp    (:), & ! [OUT]
                            pres    (:), & ! [OUT]
                            pott    (:), &
                            qv      (:), &
                            qc      (:), &
                            temp_sfc,    & ! [OUT]
                            pres_isa(1), &
                            temp_isa(1), &
                            qv_sfc,      &
                            qc_sfc       )

    if( IO_L ) write(IO_FID_LOG,*)
    if( IO_L ) write(IO_FID_LOG,*) '###### Generated Reference State of Atmosphere ######'
    if( IO_L ) write(IO_FID_LOG,*) '      height:    pressure: temperature:     density:   pot.temp.'
    do k = KS, KE
       if( IO_L ) write(IO_FID_LOG,'(5(f13.5))') CZ(k), pres(k), temp(k), dens(k), pott(k)
    enddo
    if( IO_L ) write(IO_FID_LOG,*) '####################################################'

    ATMOS_REFSTATE_dens(:) = dens(:)
    ATMOS_REFSTATE_pott(:) = pott(:)

    return
  end subroutine ATMOS_REFSTATE_generate

end module mod_atmos_refstate
