!-------------------------------------------------------------------------------
!> module COUPLER Variables
!!
!! @par Description
!!          Container for coupler variables
!!
!! @author Team SCALE
!! @li      2013-08-31 (T.Yamaura)  [new]
!!
!<
!-------------------------------------------------------------------------------
module mod_cpl_vars
  !-----------------------------------------------------------------------------
  !
  !++ used modules
  !
  use scale_precision
  use scale_stdio
  use scale_prof
  use scale_debug
  use scale_grid_index
  use scale_tracer

  use scale_const, only: &
     I_SW  => CONST_I_SW, &
     I_LW  => CONST_I_LW
  !-----------------------------------------------------------------------------
  implicit none
  private
  !-----------------------------------------------------------------------------
  !
  !++ Public procedure
  !
  public :: CPL_vars_setup
  public :: CPL_vars_merge

  public :: CPL_putAtm_setup
  public :: CPL_putOcn_setup
  public :: CPL_putLnd_setup
  public :: CPL_putUrb_setup
  public :: CPL_putAtm
  public :: CPL_putOcn
  public :: CPL_putLnd
  public :: CPL_putUrb
  public :: CPL_getAtm
  public :: CPL_getAtm_RD
  public :: CPL_getOcn
  public :: CPL_getLnd
  public :: CPL_getUrb
  public :: CPL_getOcn_restart
  public :: CPL_getLnd_restart
  public :: CPL_getUrb_restart

  !-----------------------------------------------------------------------------
  !
  !++ Public parameters & variables
  !

  !##### INPUT: Submodel->Coupler (flux is upward(Surface submodel->Atmosphere) positive) #####

  ! Input form atmosphere model
  real(RP), public, allocatable :: CPL_fromAtm_ATM_DENS  (:,:) ! density     at the lowermost atmosphere layer [kg/m3]
  real(RP), public, allocatable :: CPL_fromAtm_ATM_U     (:,:) ! velocity u  at the lowermost atmosphere layer [m/s]
  real(RP), public, allocatable :: CPL_fromAtm_ATM_V     (:,:) ! velocity v  at the lowermost atmosphere layer [m/s]
  real(RP), public, allocatable :: CPL_fromAtm_ATM_W     (:,:) ! velocity w  at the lowermost atmosphere layer [m/s]
  real(RP), public, allocatable :: CPL_fromAtm_ATM_TEMP  (:,:) ! temperature at the lowermost atmosphere layer [K]
  real(RP), public, allocatable :: CPL_fromAtm_ATM_PRES  (:,:) ! pressure    at the lowermost atmosphere layer [Pa]
  real(RP), public, allocatable :: CPL_fromAtm_ATM_QV    (:,:) ! water vapor at the lowermost atmosphere layer [kg/kg]
  real(RP), public, allocatable :: CPL_fromAtm_SFC_PRES  (:,:) ! pressure    at the surface                    [Pa]
  real(RP), public, allocatable :: CPL_fromAtm_FLX_precip(:,:) ! liquid water                 flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_fromAtm_FLX_SW_dn (:,:) ! downward shortwave radiation flux [J/m2/s]
  real(RP), public, allocatable :: CPL_fromAtm_FLX_LW_dn (:,:) ! downward longwave  radiation flux [J/m2/s]
  real(RP), public, allocatable :: CPL_fromATM_ATM_Z1    (:,:) ! height of lowermost atmosphere layer (cell center) [m]

  ! Input form ocean model
  real(RP), public, allocatable :: CPL_fromOcn_SFC_TEMP  (:,:)   ! (first time only) surface skin temperature [K]
  real(RP), public, allocatable :: CPL_fromOcn_SFC_albedo(:,:,:) ! (first time only) surface albedo           [0-1]
  real(RP), public, allocatable :: CPL_fromOcn_SFC_Z0    (:,:)   ! roughness length for momemtum [m]
  real(RP), public, allocatable :: CPL_fromOcn_OCN_TEMP  (:,:)   ! temperature at the uppermost ocean layer [K]

  ! Input form land model
  real(RP), public, allocatable :: CPL_fromLnd_SFC_TEMP  (:,:)   ! (first time only) surface skin temperature [K]
  real(RP), public, allocatable :: CPL_fromLnd_SFC_albedo(:,:,:) ! (first time only) surface albedo           [0-1]
  real(RP), public, allocatable :: CPL_fromLnd_LND_TCS   (:,:)   ! (first time only) thermal conductivity for soil [W/m/K]
  real(RP), public, allocatable :: CPL_fromLnd_LND_DZ    (:,:)   ! (first time only) soil depth [m]
  real(RP), public, allocatable :: CPL_fromLnd_SFC_Z0M   (:,:)   ! (first time only) roughness length for momemtum [m]
  real(RP), public, allocatable :: CPL_fromLnd_SFC_Z0H   (:,:)   ! (first time only) roughness length for heat     [m]
  real(RP), public, allocatable :: CPL_fromLnd_SFC_Z0E   (:,:)   ! (first time only) roughness length for vapor    [m]
  real(RP), public, allocatable :: CPL_fromLnd_LND_TEMP  (:,:)   ! temperature at the uppermost land layer [K]
  real(RP), public, allocatable :: CPL_fromLnd_LND_BETA  (:,:)   ! efficiency of evaporation [0-1]

  ! Input form urban model
  real(RP), public, allocatable :: CPL_fromUrb_SFC_TEMP  (:,:)   ! (first time only) surface skin temperature [K]
  real(RP), public, allocatable :: CPL_fromUrb_SFC_albedo(:,:,:) ! (first time only) surface albedo           [0-1]

  !##### OUTPUT: Coupler->Submodel (flux is upward(Surface submodel->Atmosphere) positive) #####

  ! Output for atmosphere model (merged)
  real(RP), public, allocatable :: CPL_Merged_SFC_TEMP  (:,:)   ! Merged surface skin temperature [K]
  real(RP), public, allocatable :: CPL_Merged_SFC_albedo(:,:,:) ! Merged surface albedo           [0-1]
  real(RP), public, allocatable :: CPL_Merged_FLX_MU    (:,:)   ! Merged w-momentum    flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_Merged_FLX_MV    (:,:)   ! Merged u-momentum    flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_Merged_FLX_MW    (:,:)   ! Merged v-momentum    flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_Merged_FLX_SH    (:,:)   ! Merged sensible heat flux [J/m2/s]
  real(RP), public, allocatable :: CPL_Merged_FLX_LH    (:,:)   ! Merged latent heat   flux [J/m2/s]
  real(RP), public, allocatable :: CPL_Merged_FLX_QV    (:,:)   ! Merged water vapor   flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_Merged_U10       (:,:)   ! Merged velocity u at 10m  [m/s]
  real(RP), public, allocatable :: CPL_Merged_V10       (:,:)   ! Merged velocity v at 10m  [m/s]
  real(RP), public, allocatable :: CPL_Merged_T2        (:,:)   ! Merged temperature at 2m  [K]
  real(RP), public, allocatable :: CPL_Merged_Q2        (:,:)   ! Merged water vapor at 2m  [kg/kg]

  ! Atmosphere-Ocean coupler: Output for atmosphere model
  real(RP), public, allocatable :: CPL_AtmOcn_ATM_FLX_MW    (:,:) ! w-momentum    flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_AtmOcn_ATM_FLX_MU    (:,:) ! u-momentum    flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_AtmOcn_ATM_FLX_MV    (:,:) ! v-momentum    flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_AtmOcn_ATM_FLX_SH    (:,:) ! sensible heat flux [J/m2/s]
  real(RP), public, allocatable :: CPL_AtmOcn_ATM_FLX_LH    (:,:) ! latent heat   flux [J/m2/s]
  real(RP), public, allocatable :: CPL_AtmOcn_ATM_FLX_evap  (:,:) ! water vapor   flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_AtmOcn_ATM_U10       (:,:) ! velocity u at 10m  [m/s]
  real(RP), public, allocatable :: CPL_AtmOcn_ATM_V10       (:,:) ! velocity v at 10m  [m/s]
  real(RP), public, allocatable :: CPL_AtmOcn_ATM_T2        (:,:) ! temperature at 2m  [K]
  real(RP), public, allocatable :: CPL_AtmOcn_ATM_Q2        (:,:) ! water vapor at 2m  [kg/kg]
  !  Atmosphere-Ocean coupler: Output for ocean model
  real(RP), public, allocatable :: CPL_AtmOcn_OCN_FLX_heat  (:,:) ! heat         flux  [J/m2/s]
  real(RP), public, allocatable :: CPL_AtmOcn_OCN_FLX_precip(:,:) ! liquid water flux  [kg/m2/s]
  real(RP), public, allocatable :: CPL_AtmOcn_OCN_FLX_evap  (:,:) ! water vapor  flux  [kg/m2/s]

  ! Atmosphere-Land coupler: Output for atmosphere model
  real(RP), public, allocatable :: CPL_AtmLnd_ATM_FLX_MW    (:,:) ! w-momentum    flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_AtmLnd_ATM_FLX_MU    (:,:) ! u-momentum    flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_AtmLnd_ATM_FLX_MV    (:,:) ! v-momentum    flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_AtmLnd_ATM_FLX_SH    (:,:) ! sensible heat flux [J/m2/s]
  real(RP), public, allocatable :: CPL_AtmLnd_ATM_FLX_LH    (:,:) ! latent heat   flux [J/m2/s]
  real(RP), public, allocatable :: CPL_AtmLnd_ATM_FLX_evap  (:,:) ! water vapor   flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_AtmLnd_ATM_U10       (:,:) ! velocity u at 10m  [m/s]
  real(RP), public, allocatable :: CPL_AtmLnd_ATM_V10       (:,:) ! velocity v at 10m  [m/s]
  real(RP), public, allocatable :: CPL_AtmLnd_ATM_T2        (:,:) ! temperature at 2m  [K]
  real(RP), public, allocatable :: CPL_AtmLnd_ATM_Q2        (:,:) ! water vapor at 2m  [kg/kg]
  ! Atmosphere-Land coupler: Output for land model
  real(RP), public, allocatable :: CPL_AtmLnd_LND_FLX_heat  (:,:) ! heat         flux  [J/m2/s]
  real(RP), public, allocatable :: CPL_AtmLnd_LND_FLX_precip(:,:) ! liquid water flux  [kg/m2/s]
  real(RP), public, allocatable :: CPL_AtmLnd_LND_FLX_evap  (:,:) ! water vapor  flux  [kg/m2/s]

  ! Atmosphere-Urban coupler: Output for atmosphere model
  real(RP), public, allocatable :: CPL_AtmUrb_ATM_FLX_MW    (:,:) ! w-momentum    flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_AtmUrb_ATM_FLX_MU    (:,:) ! u-momentum    flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_AtmUrb_ATM_FLX_MV    (:,:) ! v-momentum    flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_AtmUrb_ATM_FLX_SH    (:,:) ! sensible heat flux [J/m2/s]
  real(RP), public, allocatable :: CPL_AtmUrb_ATM_FLX_LH    (:,:) ! latent heat   flux [J/m2/s]
  real(RP), public, allocatable :: CPL_AtmUrb_ATM_FLX_evap  (:,:) ! water vapor   flux [kg/m2/s]
  real(RP), public, allocatable :: CPL_AtmUrb_ATM_U10       (:,:) ! velocity u at 10m  [m/s]
  real(RP), public, allocatable :: CPL_AtmUrb_ATM_V10       (:,:) ! velocity v at 10m  [m/s]
  real(RP), public, allocatable :: CPL_AtmUrb_ATM_T2        (:,:) ! temperature at 2m  [K]
  real(RP), public, allocatable :: CPL_AtmUrb_ATM_Q2        (:,:) ! water vapor at 2m  [kg/kg]
  ! Atmosphere-Urban coupler: Output for urban model
  real(RP), public, allocatable :: CPL_AtmUrb_URB_FLX_heat  (:,:) ! heat         flux  [J/m2/s]
  real(RP), public, allocatable :: CPL_AtmUrb_URB_FLX_precip(:,:) ! liquid water flux  [kg/m2/s]
  real(RP), public, allocatable :: CPL_AtmUrb_URB_FLX_evap  (:,:) ! water vapor  flux  [kg/m2/s]

  ! counter
  real(RP), public :: CNT_AtmLnd ! counter for atmos flux by land
  real(RP), public :: CNT_AtmUrb ! counter for atmos flux by urban
  real(RP), public :: CNT_AtmOcn ! counter for atmos flux by ocean
  real(RP), public :: CNT_Lnd    ! counter for land flux
  real(RP), public :: CNT_Urb    ! counter for urban flux
  real(RP), public :: CNT_Ocn    ! counter for ocean flux

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
  !> Setup
  subroutine CPL_vars_setup
    use scale_process, only: &
       PRC_MPIstop
    use scale_const, only: &
       UNDEF => CONST_UNDEF
    implicit none

    integer :: ierr
    integer :: ip
    !---------------------------------------------------------------------------

    if( IO_L ) write(IO_FID_LOG,*)
    if( IO_L ) write(IO_FID_LOG,*) '++++++ Module[VARS] / Categ[CPL] / Origin[SCALE-LES]'

    allocate( CPL_fromAtm_ATM_DENS  (IA,JA) )
    allocate( CPL_fromAtm_ATM_U     (IA,JA) )
    allocate( CPL_fromAtm_ATM_V     (IA,JA) )
    allocate( CPL_fromAtm_ATM_W     (IA,JA) )
    allocate( CPL_fromAtm_ATM_TEMP  (IA,JA) )
    allocate( CPL_fromAtm_ATM_PRES  (IA,JA) )
    allocate( CPL_fromAtm_ATM_QV    (IA,JA) )
    allocate( CPL_fromAtm_SFC_PRES  (IA,JA) )
    allocate( CPL_fromAtm_FLX_precip(IA,JA) )
    allocate( CPL_fromAtm_FLX_SW_dn (IA,JA) )
    allocate( CPL_fromAtm_FLX_LW_dn (IA,JA) )

    allocate( CPL_fromOcn_SFC_TEMP  (IA,JA) )
    allocate( CPL_fromOcn_SFC_albedo(IA,JA,2) )
    allocate( CPL_fromOcn_SFC_Z0    (IA,JA) )
    allocate( CPL_fromOcn_OCN_TEMP  (IA,JA) )

    allocate( CPL_fromLnd_SFC_TEMP  (IA,JA) )
    allocate( CPL_fromLnd_SFC_albedo(IA,JA,2) )
    allocate( CPL_fromLnd_LND_TCS   (IA,JA) )
    allocate( CPL_fromLnd_LND_DZ    (IA,JA) )
    allocate( CPL_fromLnd_SFC_Z0M   (IA,JA) )
    allocate( CPL_fromLnd_SFC_Z0H   (IA,JA) )
    allocate( CPL_fromLnd_SFC_Z0E   (IA,JA) )
    allocate( CPL_fromLnd_LND_TEMP  (IA,JA) )
    allocate( CPL_fromLnd_LND_BETA  (IA,JA) )

    allocate( CPL_fromUrb_SFC_TEMP  (IA,JA) )
    allocate( CPL_fromUrb_SFC_albedo(IA,JA,2) )

    allocate( CPL_Merged_SFC_TEMP  (IA,JA) )
    allocate( CPL_Merged_SFC_albedo(IA,JA,2) )
    allocate( CPL_Merged_FLX_MU    (IA,JA) )
    allocate( CPL_Merged_FLX_MV    (IA,JA) )
    allocate( CPL_Merged_FLX_MW    (IA,JA) )
    allocate( CPL_Merged_FLX_SH    (IA,JA) )
    allocate( CPL_Merged_FLX_LH    (IA,JA) )
    allocate( CPL_Merged_FLX_QV    (IA,JA) )
    allocate( CPL_Merged_U10       (IA,JA) )
    allocate( CPL_Merged_V10       (IA,JA) )
    allocate( CPL_Merged_T2        (IA,JA) )
    allocate( CPL_Merged_Q2        (IA,JA) )

    allocate( CPL_AtmOcn_ATM_FLX_MU    (IA,JA) )
    allocate( CPL_AtmOcn_ATM_FLX_MV    (IA,JA) )
    allocate( CPL_AtmOcn_ATM_FLX_MW    (IA,JA) )
    allocate( CPL_AtmOcn_ATM_FLX_SH    (IA,JA) )
    allocate( CPL_AtmOcn_ATM_FLX_LH    (IA,JA) )
    allocate( CPL_AtmOcn_ATM_FLX_evap  (IA,JA) )
    allocate( CPL_AtmOcn_ATM_U10       (IA,JA) )
    allocate( CPL_AtmOcn_ATM_V10       (IA,JA) )
    allocate( CPL_AtmOcn_ATM_T2        (IA,JA) )
    allocate( CPL_AtmOcn_ATM_Q2        (IA,JA) )
    allocate( CPL_AtmOcn_OCN_FLX_heat  (IA,JA) )
    allocate( CPL_AtmOcn_OCN_FLX_precip(IA,JA) )
    allocate( CPL_AtmOcn_OCN_FLX_evap  (IA,JA) )

    allocate( CPL_AtmLnd_ATM_FLX_MU    (IA,JA) )
    allocate( CPL_AtmLnd_ATM_FLX_MV    (IA,JA) )
    allocate( CPL_AtmLnd_ATM_FLX_MW    (IA,JA) )
    allocate( CPL_AtmLnd_ATM_FLX_SH    (IA,JA) )
    allocate( CPL_AtmLnd_ATM_FLX_LH    (IA,JA) )
    allocate( CPL_AtmLnd_ATM_FLX_evap  (IA,JA) )
    allocate( CPL_AtmLnd_ATM_U10       (IA,JA) )
    allocate( CPL_AtmLnd_ATM_V10       (IA,JA) )
    allocate( CPL_AtmLnd_ATM_T2        (IA,JA) )
    allocate( CPL_AtmLnd_ATM_Q2        (IA,JA) )
    allocate( CPL_AtmLnd_LND_FLX_heat  (IA,JA) )
    allocate( CPL_AtmLnd_LND_FLX_precip(IA,JA) )
    allocate( CPL_AtmLnd_LND_FLX_evap  (IA,JA) )

    allocate( CPL_AtmUrb_ATM_FLX_MU    (IA,JA) )
    allocate( CPL_AtmUrb_ATM_FLX_MV    (IA,JA) )
    allocate( CPL_AtmUrb_ATM_FLX_MW    (IA,JA) )
    allocate( CPL_AtmUrb_ATM_FLX_SH    (IA,JA) )
    allocate( CPL_AtmUrb_ATM_FLX_LH    (IA,JA) )
    allocate( CPL_AtmUrb_ATM_FLX_evap  (IA,JA) )
    allocate( CPL_AtmUrb_ATM_U10       (IA,JA) )
    allocate( CPL_AtmUrb_ATM_V10       (IA,JA) )
    allocate( CPL_AtmUrb_ATM_T2        (IA,JA) )
    allocate( CPL_AtmUrb_ATM_Q2        (IA,JA) )
    allocate( CPL_AtmUrb_URB_FLX_heat  (IA,JA) )
    allocate( CPL_AtmUrb_URB_FLX_precip(IA,JA) )
    allocate( CPL_AtmUrb_URB_FLX_evap  (IA,JA) )

    CNT_AtmOcn = 0.0_RP
    CNT_AtmLnd = 0.0_RP
    CNT_AtmUrb = 0.0_RP
    CNT_Ocn    = 0.0_RP
    CNT_Lnd    = 0.0_RP
    CNT_Urb    = 0.0_RP

    return
  end subroutine CPL_vars_setup

  !-----------------------------------------------------------------------------
  subroutine CPL_vars_merge
    use scale_landuse, only: &
      frac_land  => LANDUSE_frac_land,  &
      frac_lake  => LANDUSE_frac_lake,  &
      frac_urban => LANDUSE_frac_urban, &
      frac_PFT   => LANDUSE_frac_PFT
    implicit none

    real(RP) :: factOcn(IA,JA)
    real(RP) :: factLnd(IA,JA)
    real(RP) :: factUrb(IA,JA)
    !---------------------------------------------------------------------------

    factOcn(:,:) = ( 1.0_RP - frac_land(:,:) )
    factLnd(:,:) = (          frac_land(:,:) ) * ( 1.0_RP - frac_urban(:,:) )
    factUrb(:,:) = (          frac_land(:,:) ) * (          frac_urban(:,:) )

    CPL_Merged_SFC_TEMP(:,:)     = factOcn(:,:) * CPL_fromOcn_SFC_TEMP  (:,:) &
                                 + factLnd(:,:) * CPL_fromLnd_SFC_TEMP  (:,:) &
                                 + factUrb(:,:) * CPL_fromUrb_SFC_TEMP  (:,:)

    CPL_Merged_SFC_albedo(:,:,I_LW) = factOcn(:,:) * CPL_fromOcn_SFC_albedo(:,:,I_LW) &
                                    + factLnd(:,:) * CPL_fromLnd_SFC_albedo(:,:,I_LW) &
                                    + factUrb(:,:) * CPL_fromUrb_SFC_albedo(:,:,I_LW)

    CPL_Merged_SFC_albedo(:,:,I_SW) = factOcn(:,:) * CPL_fromOcn_SFC_albedo(:,:,I_SW) &
                                    + factLnd(:,:) * CPL_fromLnd_SFC_albedo(:,:,I_SW) &
                                    + factUrb(:,:) * CPL_fromUrb_SFC_albedo(:,:,I_SW)

    CPL_Merged_FLX_MW(:,:) = factOcn(:,:) * CPL_AtmOcn_ATM_FLX_MW  (:,:) &
                           + factLnd(:,:) * CPL_AtmLnd_ATM_FLX_MW  (:,:) &
                           + factUrb(:,:) * CPL_AtmUrb_ATM_FLX_MW  (:,:)

    CPL_Merged_FLX_MU(:,:) = factOcn(:,:) * CPL_AtmOcn_ATM_FLX_MU  (:,:) &
                           + factLnd(:,:) * CPL_AtmLnd_ATM_FLX_MU  (:,:) &
                           + factUrb(:,:) * CPL_AtmUrb_ATM_FLX_MU  (:,:)

    CPL_Merged_FLX_MV(:,:) = factOcn(:,:) * CPL_AtmOcn_ATM_FLX_MV  (:,:) &
                           + factLnd(:,:) * CPL_AtmLnd_ATM_FLX_MV  (:,:) &
                           + factUrb(:,:) * CPL_AtmUrb_ATM_FLX_MV  (:,:)

    CPL_Merged_FLX_SH(:,:) = factOcn(:,:) * CPL_AtmOcn_ATM_FLX_SH  (:,:) &
                           + factLnd(:,:) * CPL_AtmLnd_ATM_FLX_SH  (:,:) &
                           + factUrb(:,:) * CPL_AtmUrb_ATM_FLX_SH  (:,:)

    CPL_Merged_FLX_LH(:,:) = factOcn(:,:) * CPL_AtmOcn_ATM_FLX_LH  (:,:) &
                           + factLnd(:,:) * CPL_AtmLnd_ATM_FLX_LH  (:,:) &
                           + factUrb(:,:) * CPL_AtmUrb_ATM_FLX_LH  (:,:)

    CPL_Merged_FLX_QV(:,:) = factOcn(:,:) * CPL_AtmOcn_ATM_FLX_evap(:,:) &
                           + factLnd(:,:) * CPL_AtmLnd_ATM_FLX_evap(:,:) &
                           + factUrb(:,:) * CPL_AtmUrb_ATM_FLX_evap(:,:)

    CPL_Merged_U10   (:,:) = factOcn(:,:) * CPL_AtmOcn_ATM_U10     (:,:) &
                           + factLnd(:,:) * CPL_AtmLnd_ATM_U10     (:,:) &
                           + factUrb(:,:) * CPL_AtmUrb_ATM_U10     (:,:)

    CPL_Merged_V10   (:,:) = factOcn(:,:) * CPL_AtmOcn_ATM_V10     (:,:) &
                           + factLnd(:,:) * CPL_AtmLnd_ATM_V10     (:,:) &
                           + factUrb(:,:) * CPL_AtmUrb_ATM_V10     (:,:)

    CPL_Merged_T2    (:,:) = factOcn(:,:) * CPL_AtmOcn_ATM_T2      (:,:) &
                           + factLnd(:,:) * CPL_AtmLnd_ATM_T2      (:,:) &
                           + factUrb(:,:) * CPL_AtmUrb_ATM_T2      (:,:)

    CPL_Merged_Q2    (:,:) = factOcn(:,:) * CPL_AtmOcn_ATM_Q2      (:,:) &
                           + factLnd(:,:) * CPL_AtmLnd_ATM_Q2      (:,:) &
                           + factUrb(:,:) * CPL_AtmUrb_ATM_Q2      (:,:)

    return
  end subroutine CPL_vars_merge

  !-----------------------------------------------------------------------------
  subroutine CPL_putAtm_setup( &
       ATM_Z1 )
    implicit none

    real(RP), intent(in) :: ATM_Z1(IA,JA)
    !---------------------------------------------------------------------------

    CPL_fromATM_ATM_Z1(:,:) = ATM_Z1(:,:)

    return
  end subroutine CPL_putAtm_setup

  !-----------------------------------------------------------------------------
  subroutine CPL_putOcn_setup( &
       SFC_TEMP,   &
       SFC_albedo, &
       SFC_Z0      )
    implicit none

    real(RP), intent(in) :: SFC_TEMP  (IA,JA)
    real(RP), intent(in) :: SFC_albedo(IA,JA,2)
    real(RP), intent(in) :: SFC_Z0    (IA,JA)
    !---------------------------------------------------------------------------

    CPL_fromOcn_SFC_TEMP  (:,:)   = SFC_TEMP  (:,:)
    CPL_fromOcn_SFC_albedo(:,:,:) = SFC_albedo(:,:,:)
    CPL_fromOcn_SFC_Z0    (:,:)   = SFC_Z0    (:,:)

    return
  end subroutine CPL_putOcn_setup

  !-----------------------------------------------------------------------------
  subroutine CPL_putLnd_setup( &
       SFC_TEMP,   &
       SFC_albedo, &
       LND_TCS,    &
       LND_DZ,     &
       SFC_Z0M,    &
       SFC_Z0H,    &
       SFC_Z0E     )
    implicit none

    real(RP), intent(in) :: SFC_TEMP  (IA,JA)
    real(RP), intent(in) :: SFC_albedo(IA,JA,2)
    real(RP), intent(in) :: LND_TCS   (IA,JA)
    real(RP), intent(in) :: LND_DZ    (IA,JA)
    real(RP), intent(in) :: SFC_Z0M   (IA,JA)
    real(RP), intent(in) :: SFC_Z0H   (IA,JA)
    real(RP), intent(in) :: SFC_Z0E   (IA,JA)
    !---------------------------------------------------------------------------

    CPL_fromLnd_SFC_TEMP  (:,:)   = SFC_TEMP  (:,:)
    CPL_fromLnd_SFC_albedo(:,:,:) = SFC_albedo(:,:,:)
    CPL_fromLnd_LND_TCS   (:,:)   = LND_TCS   (:,:)
    CPL_fromLnd_LND_DZ    (:,:)   = LND_DZ    (:,:)
    CPL_fromLnd_SFC_Z0M   (:,:)   = SFC_Z0M   (:,:)
    CPL_fromLnd_SFC_Z0H   (:,:)   = SFC_Z0H   (:,:)
    CPL_fromLnd_SFC_Z0E   (:,:)   = SFC_Z0E   (:,:)

    return
  end subroutine CPL_putLnd_setup

  !-----------------------------------------------------------------------------
  subroutine CPL_putUrb_setup( &
       SFC_TEMP,  &
       SFC_albedo )
    implicit none

    real(RP), intent(in) :: SFC_TEMP  (IA,JA)
    real(RP), intent(in) :: SFC_albedo(IA,JA,2)
    !---------------------------------------------------------------------------

    CPL_fromUrb_SFC_TEMP  (:,:)   = SFC_TEMP  (:,:)
    CPL_fromUrb_SFC_albedo(:,:,:) = SFC_albedo(:,:,:)

    return
  end subroutine CPL_putUrb_setup

  !-----------------------------------------------------------------------------
  subroutine CPL_putAtm( &
       ATM_TEMP,   &
       ATM_PRES,   &
       ATM_W,      &
       ATM_U,      &
       ATM_V,      &
       ATM_DENS,   &
       ATM_QTRC,   &
       SFC_PRES,   &
       SFLX_LW_dn, &
       SFLX_SW_dn, &
       SFLX_rain,  &
       SFLX_snow   )
    implicit none

    real(RP), intent(in) :: ATM_TEMP  (IA,JA)
    real(RP), intent(in) :: ATM_PRES  (IA,JA)
    real(RP), intent(in) :: ATM_W     (IA,JA)
    real(RP), intent(in) :: ATM_U     (IA,JA)
    real(RP), intent(in) :: ATM_V     (IA,JA)
    real(RP), intent(in) :: ATM_DENS  (IA,JA)
    real(RP), intent(in) :: ATM_QTRC  (IA,JA,QA)
    real(RP), intent(in) :: SFC_PRES  (IA,JA)
    real(RP), intent(in) :: SFLX_LW_dn(IA,JA)
    real(RP), intent(in) :: SFLX_SW_dn(IA,JA)
    real(RP), intent(in) :: SFLX_rain (IA,JA)
    real(RP), intent(in) :: SFLX_snow (IA,JA)
    !---------------------------------------------------------------------------

    CPL_fromAtm_ATM_TEMP  (:,:) = ATM_TEMP  (:,:)
    CPL_fromAtm_ATM_PRES  (:,:) = ATM_PRES  (:,:)
    CPL_fromAtm_ATM_W     (:,:) = ATM_W     (:,:)
    CPL_fromAtm_ATM_U     (:,:) = ATM_U     (:,:)
    CPL_fromAtm_ATM_V     (:,:) = ATM_V     (:,:)
    CPL_fromAtm_ATM_DENS  (:,:) = ATM_DENS  (:,:)
    CPL_fromAtm_ATM_QV    (:,:) = ATM_QTRC  (:,:,1)
    CPL_fromAtm_SFC_PRES  (:,:) = SFC_PRES  (:,:)
    CPL_fromAtm_FLX_LW_dn (:,:) = SFLX_LW_dn(:,:)
    CPL_fromAtm_FLX_SW_dn (:,:) = SFLX_SW_dn(:,:)
    CPL_fromAtm_FLX_precip(:,:) = SFLX_rain (:,:) &
                                + SFLX_snow (:,:)

    return
  end subroutine CPL_putAtm

  !-----------------------------------------------------------------------------
  subroutine CPL_putOcn( &
       OCN_TEMP )
    implicit none

    real(RP), intent(in) :: OCN_TEMP(IA,JA)
    !---------------------------------------------------------------------------

    CPL_fromOcn_OCN_TEMP(:,:) = OCN_TEMP(:,:)

    return
  end subroutine CPL_putOcn

  !-----------------------------------------------------------------------------
  subroutine CPL_putLnd( &
       LND_TEMP, &
       LND_BETA  )
    implicit none

    real(RP), intent(in) :: LND_TEMP(IA,JA)
    real(RP), intent(in) :: LND_BETA(IA,JA)
    !---------------------------------------------------------------------------

    CPL_fromLnd_LND_TEMP(:,:) = LND_TEMP(:,:)
    CPL_fromLnd_LND_BETA(:,:) = LND_BETA(:,:)

    return
  end subroutine CPL_putLnd

  !-----------------------------------------------------------------------------
  subroutine CPL_putUrb
    implicit none
    !---------------------------------------------------------------------------

    return
  end subroutine CPL_putUrb

  !-----------------------------------------------------------------------------
  subroutine CPL_getAtm( &
       SFC_Z0,    &
       SFLX_MW,   &
       SFLX_MU,   &
       SFLX_MV,   &
       SFLX_SH,   &
       SFLX_LH,   &
       SFLX_QTRC, &
       Uabs10,    &
       U10,       &
       V10,       &
       T2,        &
       Q2         )
    implicit none

    real(RP), intent(out) :: SFC_Z0   (IA,JA)
    real(RP), intent(out) :: SFLX_MW  (IA,JA)
    real(RP), intent(out) :: SFLX_MU  (IA,JA)
    real(RP), intent(out) :: SFLX_MV  (IA,JA)
    real(RP), intent(out) :: SFLX_SH  (IA,JA)
    real(RP), intent(out) :: SFLX_LH  (IA,JA)
    real(RP), intent(out) :: SFLX_QTRC(IA,JA,QA)
    real(RP), intent(out) :: Uabs10   (IA,JA)
    real(RP), intent(out) :: U10      (IA,JA)
    real(RP), intent(out) :: V10      (IA,JA)
    real(RP), intent(out) :: T2       (IA,JA)
    real(RP), intent(out) :: Q2       (IA,JA)
    !---------------------------------------------------------------------------

    SFC_Z0   (:,:)   = 0.0_RP                ! tentative
    SFLX_MW  (:,:)   = CPL_Merged_FLX_MW(:,:)
    SFLX_MU  (:,:)   = CPL_Merged_FLX_MU(:,:)
    SFLX_MV  (:,:)   = CPL_Merged_FLX_MV(:,:)
    SFLX_SH  (:,:)   = CPL_Merged_FLX_SH(:,:)
    SFLX_LH  (:,:)   = CPL_Merged_FLX_LH(:,:)
    SFLX_QTRC(:,:,:) = 0.0_RP                ! tentative
    SFLX_QTRC(:,:,1) = CPL_Merged_FLX_QV(:,:) ! tentative

    Uabs10   (:,:)   = sqrt( CPL_Merged_U10(:,:)*CPL_Merged_U10(:,:) &
                           + CPL_Merged_V10(:,:)*CPL_Merged_V10(:,:) )
    U10      (:,:)   = CPL_Merged_U10   (:,:)
    V10      (:,:)   = CPL_Merged_V10   (:,:)
    T2       (:,:)   = CPL_Merged_T2    (:,:)
    Q2       (:,:)   = CPL_Merged_Q2    (:,:)

    CNT_AtmLnd = 0.0_RP
    CNT_AtmUrb = 0.0_RP
    CNT_AtmOcn = 0.0_RP

    return
  end subroutine CPL_getAtm

  !-----------------------------------------------------------------------------
  subroutine CPL_getAtm_RD( &
       SFC_TEMP,  &
       SFC_albedo )
    implicit none

    real(RP), intent(out) :: SFC_TEMP  (IA,JA)
    real(RP), intent(out) :: SFC_albedo(IA,JA,2)
    !---------------------------------------------------------------------------

    SFC_TEMP  (:,:)   = CPL_Merged_SFC_TEMP  (:,:)
    SFC_albedo(:,:,:) = CPL_Merged_SFC_albedo(:,:,:)

    return
  end subroutine CPL_getAtm_RD

  !-----------------------------------------------------------------------------
  subroutine CPL_getOcn( &
       OCN_FLX_heat,   & ! (out)
       OCN_FLX_precip, & ! (out)
       OCN_FLX_evap    ) ! (out)
    implicit none

    real(RP), intent(out) :: OCN_FLX_heat  (IA,JA)
    real(RP), intent(out) :: OCN_FLX_precip(IA,JA)
    real(RP), intent(out) :: OCN_FLX_evap  (IA,JA)
    !---------------------------------------------------------------------------

    OCN_FLX_heat  (:,:) = CPL_AtmOcn_OCN_FLX_heat  (:,:)
    OCN_FLX_precip(:,:) = CPL_AtmOcn_OCN_FLX_precip(:,:)
    OCN_FLX_evap  (:,:) = CPL_AtmOcn_OCN_FLX_evap  (:,:)

    CNT_Ocn = 0.0_RP

    return
  end subroutine CPL_getOcn

  !-----------------------------------------------------------------------------
  subroutine CPL_getLnd( &
      LND_FLX_heat,   & ! (out)
      LND_FLX_precip, & ! (out)
      LND_FLX_evap    ) ! (out)
    implicit none

    real(RP), intent(out) :: LND_FLX_heat  (IA,JA)
    real(RP), intent(out) :: LND_FLX_precip(IA,JA)
    real(RP), intent(out) :: LND_FLX_evap  (IA,JA)
    !---------------------------------------------------------------------------

    LND_FLX_heat  (:,:) = CPL_AtmLnd_LND_FLX_heat  (:,:)
    LND_FLX_precip(:,:) = CPL_AtmLnd_LND_FLX_precip(:,:)
    LND_FLX_evap  (:,:) = CPL_AtmLnd_LND_FLX_evap  (:,:)

    CNT_Lnd = 0.0_RP

    return
  end subroutine CPL_getLnd

  !-----------------------------------------------------------------------------
  subroutine CPL_getUrb( &
      URB_FLX_heat,   & ! (out)
      URB_FLX_precip, & ! (out)
      URB_FLX_evap    ) ! (out)
    implicit none

    real(RP), intent(out) :: URB_FLX_heat  (IA,JA)
    real(RP), intent(out) :: URB_FLX_precip(IA,JA)
    real(RP), intent(out) :: URB_FLX_evap  (IA,JA)
    !---------------------------------------------------------------------------

    URB_FLX_heat  (:,:) = CPL_AtmUrb_URB_FLX_heat  (:,:)
    URB_FLX_precip(:,:) = CPL_AtmUrb_URB_FLX_precip(:,:)
    URB_FLX_evap  (:,:) = CPL_AtmUrb_URB_FLX_evap  (:,:)

    CNT_Urb = 0.0_RP

    return
  end subroutine CPL_getUrb

  !-----------------------------------------------------------------------------
  subroutine CPL_getOcn_restart( &
       SFC_TEMP,   &
       SFC_albedo, &
       SFC_Z0      )
    implicit none

    real(RP), intent(out) :: SFC_TEMP  (IA,JA)
    real(RP), intent(out) :: SFC_albedo(IA,JA,2)
    real(RP), intent(out) :: SFC_Z0    (IA,JA)
    !---------------------------------------------------------------------------

    SFC_TEMP  (:,:)   = CPL_fromOcn_SFC_TEMP  (:,:)
    SFC_albedo(:,:,:) = CPL_fromOcn_SFC_albedo(:,:,:)
    SFC_Z0    (:,:)   = CPL_fromOcn_SFC_Z0    (:,:)

    return
  end subroutine CPL_getOcn_restart

  !-----------------------------------------------------------------------------
  subroutine CPL_getLnd_restart( &
       SFC_TEMP,   &
       SFC_albedo  )
    implicit none

    real(RP), intent(out) :: SFC_TEMP  (IA,JA)
    real(RP), intent(out) :: SFC_albedo(IA,JA,2)
    !---------------------------------------------------------------------------

    SFC_TEMP  (:,:)   = CPL_fromLnd_SFC_TEMP  (:,:)
    SFC_albedo(:,:,:) = CPL_fromLnd_SFC_albedo(:,:,:)

    return
  end subroutine CPL_getLnd_restart

  !-----------------------------------------------------------------------------
  subroutine CPL_getUrb_restart( &
       SFC_TEMP,  &
       SFC_albedo )
    implicit none

    real(RP), intent(out) :: SFC_TEMP  (IA,JA)
    real(RP), intent(out) :: SFC_albedo(IA,JA,2)
    !---------------------------------------------------------------------------

   SFC_TEMP  (:,:)   = CPL_fromUrb_SFC_TEMP  (:,:)
   SFC_albedo(:,:,:) = CPL_fromUrb_SFC_albedo(:,:,:)

    return
  end subroutine CPL_getUrb_restart

end module mod_CPL_vars
