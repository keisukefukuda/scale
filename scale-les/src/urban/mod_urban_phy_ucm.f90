!-------------------------------------------------------------------------------
!> module URBAN / Physics Urban Canopy Model (UCM)
!!
!! @par Description
!!          Urban physics module
!!          based on Urban Canopy Model (Kusaka et al. 2000)
!!
!! @author Team SCALE
!<
!-------------------------------------------------------------------------------
module mod_urban_phy_ucm
  !-----------------------------------------------------------------------------
  !
  !++ used modules
  !
  use scale_precision
  use scale_stdio
  use scale_prof
  use scale_grid_index
  use scale_urban_grid_index
  !-----------------------------------------------------------------------------
  implicit none
  private
  !-----------------------------------------------------------------------------
  !
  !++ Public procedure
  !
  public :: URBAN_PHY_driver_setup
  public :: URBAN_PHY_driver_first
  public :: URBAN_PHY_driver_final

  !-----------------------------------------------------------------------------
  !
  !++ Public parameters & variables
  !
  !-----------------------------------------------------------------------------
  !
  !++ Private procedure
  !
  private :: urban
  private :: canopy_wind
  private :: mos
  private :: multi_layer
  private :: urban_param_setup

  !-----------------------------------------------------------------------------
  !
  !++ Private parameters & variables
  !
  !-----------------------------------------------------------------------------
  ! from namelist
  real(RP), private, save :: ZR         = 10.0       ! roof level ( building height) [m]
  real(RP), private, save :: roof_width =  9.0       ! roof level ( building height) [m]
  real(RP), private, save :: road_width = 11.0       ! roof level ( building height) [m]
  real(RP), private, save :: SIGMA_ZED  =  1.0       ! Standard deviation of roof height [m]
  real(RP), private, save :: AH         = 17.5       ! Sensible Anthropogenic heat [W/m^2]
  real(RP), private, save :: ALH        = 0.         ! Latent Anthropogenic heat [W/m^2]
  real(RP), private, save :: BETR       = 0.0        ! Evaporation efficiency of roof [-]
  real(RP), private, save :: BETB       = 0.0        !                        of building [-]
  real(RP), private, save :: BETG       = 0.0        !                        of ground [-]
  real(RP), private, save :: CAPR       = 1.2E6      ! heat capacity of roof
  real(RP), private, save :: CAPB       = 1.2E6      !  ( units converted in code
  real(RP), private, save :: CAPG       = 1.2E6      !            to [ cal cm{-3} deg{-1} ] )
  real(RP), private, save :: AKSR       = 2.28       ! thermal conductivity of roof, wall, and ground
  real(RP), private, save :: AKSB       = 2.28       !  ( units converted in code
  real(RP), private, save :: AKSG       = 2.28       !            to [ cal cm{-1} s{-1} deg{-1} ] )
  real(RP), private, save :: ALBR       = 0.2        ! surface albedo of roof
  real(RP), private, save :: ALBB       = 0.2        ! surface albedo of wall
  real(RP), private, save :: ALBG       = 0.2        ! surface albedo of ground
  real(RP), private, save :: EPSR       = 0.90       ! Surface emissivity of roof
  real(RP), private, save :: EPSB       = 0.90       ! Surface emissivity of wall
  real(RP), private, save :: EPSG       = 0.90       ! Surface emissivity of ground
  real(RP), private, save :: Z0R        = 0.01       ! roughness length for momentum of building roof
  real(RP), private, save :: Z0B        = 0.0001     ! roughness length for momentum of building wall
  real(RP), private, save :: Z0G        = 0.01       ! roughness length for momentum of ground
  real(RP), private, save :: TRLEND     = 293.00     ! lower boundary condition of roof temperature [K]
  real(RP), private, save :: TBLEND     = 293.00     ! lower boundary condition of wall temperature [K]
  real(RP), private, save :: TGLEND     = 293.00     ! lower boundary condition of ground temperature [K]
  integer , private, save :: BOUND      = 1          ! Boundary Condition for Roof, Wall, Ground Layer Temp
                                                     !       [1: Zero-Flux, 2: T = Constant]
  ! calculate in subroutine urban_param_set
  real(RP), private, save :: R                       ! Normalized roof wight (eq. building coverage ratio)
  real(RP), private, save :: RW                      ! (= 1 - R)
  real(RP), private, save :: HGT                     ! Normalized building height
  real(RP), private, save :: Z0HR                    ! roughness length for heat of roof
  real(RP), private, save :: Z0HB                    ! roughness length for heat of building wall
  real(RP), private, save :: Z0HG                    ! roughness length for heat of ground
  real(RP), private, save :: Z0C                     ! Roughness length above canyon for momentum [m]
  real(RP), private, save :: Z0HC                    ! Roughness length above canyon for heat [m]
  real(RP), private, save :: ZDC                     ! Displacement height [m]
  real(RP), private, save :: SVF                     ! Sky view factor [-]

  real(RP), private, save :: ahdiurnal(1:24)         ! AH diurnal profile

  real(RP), private, save, allocatable :: DZR(:)     ! thickness of each roof layer [m]
  real(RP), private, save, allocatable :: DZB(:)     ! thickness of each building layer [m]
  real(RP), private, save, allocatable :: DZG(:)     ! thickness of each road layer [m]
                                                                  ! ( units converted in code to [cm] )
  ! tentative
  real(RP), private, save, allocatable :: SWUFLX_URB(:,:) ! upward shortwave flux at the surface [W/m2]
  real(RP), private, save, allocatable :: LWUFLX_URB(:,:) ! upward longwave flux at the surface [W/m2]
  real(RP), private, save, allocatable :: SHFLX_URB (:,:) ! sensible heat flux at the surface [W/m2]
  real(RP), private, save, allocatable :: LHFLX_URB (:,:) ! latent heat flux at the surface [W/m2]
  real(RP), private, save, allocatable :: GHFLX_URB (:,:) ! ground heat flux at the surface [W/m2]
  real(RP), private, save, allocatable :: TS_URB    (:,:) ! diagnostic surface temperature [K]

  !-----------------------------------------------------------------------------
contains
  !-----------------------------------------------------------------------------
  !> Setup
  subroutine URBAN_PHY_driver_setup
    use scale_const, only: &
       UNDEF => CONST_UNDEF
    use scale_process, only: &
       PRC_MPIstop
    use mod_urban_vars, only: &
       URBAN_TYPE
    implicit none

    real(RP) :: URBAN_UCM_ZR
    real(RP) :: URBAN_UCM_roof_width
    real(RP) :: URBAN_UCM_road_width
    real(RP) :: URBAN_UCM_SIGMA_ZED
    real(RP) :: URBAN_UCM_AH
    real(RP) :: URBAN_UCM_ALH
    real(RP) :: URBAN_UCM_BETR
    real(RP) :: URBAN_UCM_BETB
    real(RP) :: URBAN_UCM_BETG
    real(RP) :: URBAN_UCM_CAPR
    real(RP) :: URBAN_UCM_CAPB
    real(RP) :: URBAN_UCM_CAPG
    real(RP) :: URBAN_UCM_AKSR
    real(RP) :: URBAN_UCM_AKSB
    real(RP) :: URBAN_UCM_AKSG
    real(RP) :: URBAN_UCM_ALBR
    real(RP) :: URBAN_UCM_ALBB
    real(RP) :: URBAN_UCM_ALBG
    real(RP) :: URBAN_UCM_EPSR
    real(RP) :: URBAN_UCM_EPSB
    real(RP) :: URBAN_UCM_EPSG
    real(RP) :: URBAN_UCM_Z0R
    real(RP) :: URBAN_UCM_Z0B
    real(RP) :: URBAN_UCM_Z0G
    real(RP) :: URBAN_UCM_TRLEND
    real(RP) :: URBAN_UCM_TBLEND
    real(RP) :: URBAN_UCM_TGLEND
    integer  :: URBAN_UCM_BOUND

    NAMELIST / PARAM_URBAN_UCM / &
       URBAN_UCM_ZR,         &
       URBAN_UCM_roof_width, &
       URBAN_UCM_road_width, &
       URBAN_UCM_SIGMA_ZED,  &
       URBAN_UCM_AH,         &
       URBAN_UCM_ALH,        &
       URBAN_UCM_BETR,       &
       URBAN_UCM_BETB,       &
       URBAN_UCM_BETG,       &
       URBAN_UCM_CAPR,       &
       URBAN_UCM_CAPB,       &
       URBAN_UCM_CAPG,       &
       URBAN_UCM_AKSR,       &
       URBAN_UCM_AKSB,       &
       URBAN_UCM_AKSG,       &
       URBAN_UCM_ALBR,       &
       URBAN_UCM_ALBB,       &
       URBAN_UCM_ALBG,       &
       URBAN_UCM_EPSR,       &
       URBAN_UCM_EPSB,       &
       URBAN_UCM_EPSG,       &
       URBAN_UCM_Z0R,        &
       URBAN_UCM_Z0B,        &
       URBAN_UCM_Z0G,        &
       URBAN_UCM_TRLEND,     &
       URBAN_UCM_TBLEND,     &
       URBAN_UCM_TGLEND,     &
       URBAN_UCM_BOUND

    integer :: ierr
    !---------------------------------------------------------------------------

    if( IO_L ) write(IO_FID_LOG,*)
    if( IO_L ) write(IO_FID_LOG,*) '+++ Module[UCM]/Categ[URBAN]'

    URBAN_UCM_ZR           = ZR
    URBAN_UCM_roof_width   = roof_width
    URBAN_UCM_road_width   = road_width
    URBAN_UCM_SIGMA_ZED    = SIGMA_ZED
    URBAN_UCM_AH           = AH
    URBAN_UCM_ALH          = ALH
    URBAN_UCM_BETR         = BETR
    URBAN_UCM_BETB         = BETB
    URBAN_UCM_BETG         = BETG
    URBAN_UCM_CAPR         = CAPR
    URBAN_UCM_CAPB         = CAPB
    URBAN_UCM_CAPG         = CAPG
    URBAN_UCM_AKSR         = AKSR
    URBAN_UCM_AKSB         = AKSB
    URBAN_UCM_AKSG         = AKSG
    URBAN_UCM_ALBR         = ALBR
    URBAN_UCM_ALBB         = ALBB
    URBAN_UCM_ALBG         = ALBG
    URBAN_UCM_EPSR         = EPSR
    URBAN_UCM_EPSB         = EPSB
    URBAN_UCM_EPSG         = EPSG
    URBAN_UCM_Z0R          = Z0R
    URBAN_UCM_Z0B          = Z0B
    URBAN_UCM_Z0G          = Z0G
    URBAN_UCM_TRLEND       = TRLEND
    URBAN_UCM_TBLEND       = TBLEND
    URBAN_UCM_TGLEND       = TGLEND
    URBAN_UCM_BOUND        = BOUND

    ! allocate private arrays
    allocate( DZR(UKS:UKE) )
    allocate( DZB(UKS:UKE) )
    allocate( DZG(UKS:UKE) )

    allocate( SWUFLX_URB(IA,JA) )
    allocate( LWUFLX_URB(IA,JA) )
    allocate( SHFLX_URB (IA,JA) )
    allocate( LHFLX_URB (IA,JA) )
    allocate( GHFLX_URB (IA,JA) )
    allocate( TS_URB    (IA,JA) )

    ! initialize
    DZR(:) = UNDEF
    DZB(:) = UNDEF
    DZG(:) = UNDEF

    SWUFLX_URB(:,:) = UNDEF
    LWUFLX_URB(:,:) = UNDEF
    SHFLX_URB (:,:) = UNDEF
    LHFLX_URB (:,:) = UNDEF
    GHFLX_URB (:,:) = UNDEF
    TS_URB    (:,:) = UNDEF

    if ( URBAN_TYPE /= 'UCM' ) then
       if( IO_L ) write(IO_FID_LOG,*) 'xxx URBAN_TYPE is not UCM. Check!'
       call PRC_MPIstop
    endif

    !--- read namelist
    rewind(IO_FID_CONF)
    read(IO_FID_CONF,nml=PARAM_URBAN_UCM,iostat=ierr)

    if( ierr < 0 ) then !--- missing
       if( IO_L ) write(IO_FID_LOG,*) '*** Not found namelist. Default used.'
    elseif( ierr > 0 ) then !--- fatal error
       write(*,*) 'xxx Not appropriate names in namelist PARAM_URBAN_UCM. Check!'
       call PRC_MPIstop
    endif
    if( IO_L ) write(IO_FID_LOG,nml=PARAM_URBAN_UCM)

    ZR           = URBAN_UCM_ZR
    roof_width   = URBAN_UCM_roof_width
    road_width   = URBAN_UCM_road_width
    SIGMA_ZED    = URBAN_UCM_SIGMA_ZED
    AH           = URBAN_UCM_AH
    ALH          = URBAN_UCM_ALH
    BETR         = URBAN_UCM_BETR
    BETB         = URBAN_UCM_BETB
    BETG         = URBAN_UCM_BETG
    CAPR         = URBAN_UCM_CAPR
    CAPB         = URBAN_UCM_CAPB
    CAPG         = URBAN_UCM_CAPG
    AKSR         = URBAN_UCM_AKSR
    AKSB         = URBAN_UCM_AKSB
    AKSG         = URBAN_UCM_AKSG
    ALBR         = URBAN_UCM_ALBR
    ALBB         = URBAN_UCM_ALBB
    ALBG         = URBAN_UCM_ALBG
    EPSR         = URBAN_UCM_EPSR
    EPSB         = URBAN_UCM_EPSB
    EPSG         = URBAN_UCM_EPSG
    Z0R          = URBAN_UCM_Z0R
    Z0B          = URBAN_UCM_Z0B
    Z0G          = URBAN_UCM_Z0G
    TRLEND       = URBAN_UCM_TRLEND
    TBLEND       = URBAN_UCM_TBLEND
    TGLEND       = URBAN_UCM_TGLEND
    BOUND        = URBAN_UCM_BOUND

    ahdiurnal(:) = (/ 0.356, 0.274, 0.232, 0.251, 0.375, 0.647, 0.919, 1.135, 1.249, 1.328, &
                      1.365, 1.363, 1.375, 1.404, 1.457, 1.526, 1.557, 1.521, 1.372, 1.206, &
                      1.017, 0.876, 0.684, 0.512                                            /)

    ! set other urban parameters
    call urban_param_setup

    return
  end subroutine URBAN_PHY_driver_setup

  !-----------------------------------------------------------------------------
  !> Physical processes for urban submodel
  subroutine URBAN_PHY_driver_first
    use scale_time, only: &
       dt => TIME_DTSEC_URBAN
    use scale_grid_real, only: &
       REAL_lon, &
       REAL_lat
    use mod_urban_vars, only: &
       TR_URB,  &
       TG_URB,  &
       TB_URB,  &
       TC_URB,  &
       QC_URB,  &
       UC_URB,  &
       TRL_URB, &
       TGL_URB, &
       TBL_URB
    use mod_cpl_vars, only: &
       CPL_getCPL2Urb
    implicit none

    ! work
    real(RP) :: DZ  (IA,JA) ! height from the surface to the lowest atmospheric layer [m]
    real(RP) :: DENS(IA,JA) ! air density at the lowest atmospheric layer [kg/m3]
    real(RP) :: MOMX(IA,JA) ! momentum x at the lowest atmospheric layer [kg/m2/s]
    real(RP) :: MOMY(IA,JA) ! momentum y at the lowest atmospheric layer [kg/m2/s]
    real(RP) :: MOMZ(IA,JA) ! momentum z at the lowest atmospheric layer [kg/m2/s]

    real(RP) :: TEMP(IA,JA) ! atmospheric air temperature at 1st atmospheric level [K]
    real(RP) :: QV  (IA,JA) ! ratio of water vapor mass to total mass at the lowest atmospheric layer [kg/kg]
    real(RP) :: SWD (IA,JA) ! downward short-wave radiation flux at the surface (upward positive) [W/m2]
    real(RP) :: LWD (IA,JA) ! downward long-wave radiation flux at the surface (upward positive) [W/m2]
    real(RP) :: PREC(IA,JA) ! precipitation [mm/h] ! Please check the unit, before you use.

    logical  :: LSOLAR = .false.    ! logical [true=both, false=SSG only]
    real(RP) :: TA       ! temp at 1st atmospheric level [K]
    real(RP) :: QA       ! mixing ratio at 1st atmospheric level  [kg/kg]
    real(RP) :: UA       ! wind speed at 1st atmospheric level    [m/s]
    real(RP) :: U1       ! u at 1st atmospheric level             [m/s]
    real(RP) :: V1       ! v at 1st atmospheric level             [m/s]
    real(RP) :: ZA       ! height of 1st atmospheric level        [m]
    real(RP) :: SSG      ! downward total short wave radiation    [W/m/m]
    real(RP) :: LLG      ! downward long wave radiation           [W/m/m]
    real(RP) :: RAIN     ! precipitation                          [mm/h] ! check unit
    real(RP) :: RHOO     ! air density                            [kg/m^3]
    real(RP) :: XLON     ! longitude                              [deg]
    real(RP) :: XLAT     ! latitude                               [deg]

    real(RP) :: TR, TB, TG, TC, QC, UC
    real(RP) :: TRL(UKS:UKE)
    real(RP) :: TBL(UKS:UKE)
    real(RP) :: TGL(UKS:UKE)
    real(RP) :: TS                  ! surface temperature    [K]
    real(RP) :: SH                  ! sensible heat flux               [W/m/m]
    real(RP) :: LH                  ! latent heat flux                 [W/m/m]
    real(RP) :: SW                  ! upward short wave radiation flux [W/m/m]
    real(RP) :: LW                  ! upward long wave radiation flux  [W/m/m]
    real(RP) :: G                   ! heat flux into the ground        [W/m/m]

    ! parameters for shadow model
    !XX sinDEC, cosDEC ?
    ! real(RP) :: DECLIN   ! solar declination                    [rad]
    !XX  cosSZA     ?
    ! real(RP) :: COSZ     ! sin(fai)*sin(del)+cos(fai)*cos(del)*cos(omg)
    !XX  hourangle  ?
    ! real(RP) :: OMG      ! solar hour angle                       [rad]

    integer :: k, i, j
    !---------------------------------------------------------------------------

    if( IO_L ) write(IO_FID_LOG,*) '*** Urban step: UCM'

    call CPL_getCPL2Urb( DZ  (:,:), & ! (out)
                         DENS(:,:), & ! (out)
                         MOMX(:,:), & ! (out)
                         MOMY(:,:), & ! (out)
                         MOMZ(:,:), & ! (out)
                         TEMP(:,:), & ! (out)
                         QV  (:,:), & ! (out)
                         SWD (:,:), & ! (out)
                         LWD (:,:), & ! (out)
                         PREC(:,:)  ) ! (out)

    do j = JS-1, JE+1
    do i = IS-1, IE+1

      TA = TEMP(i,j)                  ! temp at 1st atmospheric level         [K]
      QA = QV(i,j)  /(1-QV(i,j))      ! mixing ratio at 1st atmospheric level [kg/kg]
                                      ! QV specific humidity                  [kg/kg]
      UA = sqrt(          &
            ( MOMZ(i,j)               )**2 &
          + ( MOMX(i-1,j) + MOMX(i,j) )**2 &
          + ( MOMY(i,j-1) + MOMY(i,j) )**2 &
          ) / DENS(i,j) * 0.5_RP
                                  ! wind speed at 1st atmospheric level   [m/s]
      U1 = 0.5_RP * ( MOMX(i-1,j) + MOMX(i,j) ) / DENS(i,j)
                                  ! u at 1st atmospheric level            [m/s]
      V1 = 0.5_RP * ( MOMY(i,j-1) + MOMY(i,j) ) / DENS(i,j)
                                  ! v at 1st atmospheric level            [m/s]
      SSG  = SWD(i,j)             ! downward total short wave radiation   [W/m/m]
      LLG  = LWD(i,j)             ! downward long wave radiation          [W/m/m]
      RAIN = PREC(i,j)            ! precipitation                         [mm/h]
      RHOO = DENS(i,j)            ! air density                           [kg/m^3]
      ZA   = DZ(i,j)              ! first atmospheric level               [m]
      XLON = REAL_lon(i,j)        ! longitude                             [deg]
      XLAT = REAL_lat(i,j)        ! latitude                              [deg]

      TR   = TR_URB(i,j)
      TB   = TB_URB(i,j)
      TG   = TG_URB(i,j)
      TC   = TC_URB(i,j)
      QC   = QC_URB(i,j)
      UC   = UC_URB(i,j)

      do k = UKS, UKE
        TRL(k) = TRL_URB(k,i,j)
        TBL(k) = TBL_URB(k,i,j)
        TGL(k) = TGL_URB(k,i,j)
      enddo

      call urban(LSOLAR,                             & ! (in)
                 TA, QA, UA, U1, V1, ZA,             & ! (in)
                 SSG, LLG, RAIN, RHOO, XLON, XLAT,   & ! (in)
                 TR, TB, TG, TC, QC, UC,             & ! (inout)
                 TRL, TBL, TGL,                      & ! (inout)
                 TS, SH, LH, SW, LW, G               ) ! (out)

      do k = UKS, UKE
        TRL_URB(k,i,j) = TRL(k)
        TBL_URB(k,i,j) = TBL(k)
        TGL_URB(k,i,j) = TGL(k)
      enddo

      TR_URB(i,j) = TR
      TB_URB(i,j) = TB
      TG_URB(i,j) = TG
      TC_URB(i,j) = TC
      QC_URB(i,j) = QC
      UC_URB(i,j) = UC
      TS_URB(i,j) = TS

      SHFLX_URB(i,j)  = SH  ! sensible heat flux               [W/m/m]
      LHFLX_URB(i,j)  = LH  ! latent heat flux                 [W/m/m]
      GHFLX_URB(i,j)  = G   ! heat flux into the ground        [W/m/m]
      SWUFLX_URB(i,j) = SW  ! upward short wave radiation flux [W/m/m]
      LWUFLX_URB(i,j) = LW  ! upward long wave radiation flux  [W/m/m]

    end do
    end do

    return
  end subroutine URBAN_PHY_driver_first

  subroutine URBAN_PHY_driver_final
    use mod_cpl_vars, only: &
       CPL_putUrb
    implicit none
    !---------------------------------------------------------------------------

    call CPL_putUrb( SWUFLX_URB(:,:), & ! (in)
                     LWUFLX_URB(:,:), & ! (in)
                     SHFLX_URB (:,:), & ! (in)
                     LHFLX_URB (:,:), & ! (in)
                     GHFLX_URB (:,:), & ! (in)
                     TS_URB    (:,:)  ) ! (in)

    return
  end subroutine URBAN_PHY_driver_final

  !-----------------------------------------------------------------------------
  subroutine urban(LSOLAR,                            & ! (in)
                   TA, QA, UA, U1, V1, ZA,            & ! (in)
                   SSG, LLG, RAIN, RHOO, XLON, XLAT,  & ! (in)
                   TR, TB, TG, TC, QC, UC,            & ! (inout)
                   TRL, TBL, TGL,                     & ! (inout)
                   TS, SH, LH, SW, LW, G              ) ! (out)

    use scale_const, only: &
      KARMAN => CONST_KARMAN,  &    ! AK : kalman constant  [-]
      PI     => CONST_PI,      &    ! PI : pi               [-]
      CPdry  => CONST_CPdry,   &    ! CPP : heat capacity of dry air [J/K/kg]
      LH0    => CONST_LH0,     &    ! ELL : latent heat of vaporization [J/kg]
      GRAV   => CONST_GRAV,    &    !< gravitational constant [m/s2]
      Rdry   => CONST_Rdry,    &    !< specific gas constant (dry) [J/kg/K]
      Rvap   => CONST_Rvap,    &    !< gas constant (water vapor) [J/kg/K]
      STB    => CONST_STB,     &    !< stefan-Boltzman constant [MKS unit]
      TEM00  => CONST_TEM00         !< temperature reference (0 degree C) [K]
    use scale_process, only: &
       PRC_MPIstop
    use scale_time, only:       &
      TIME => TIME_NOWSEC,      &   !< absolute sec
      DELT => TIME_DTSEC_URBAN      !< time interval of urban step [sec]

    implicit none

    !-- parameters
    real(RP), parameter    :: CP  = 0.24_RP     ! heat capacity of dry air  [cgs unit]
    real(RP), parameter    :: EL  = 583.0_RP    ! latent heat of vaporation [cgs unit]
    real(RP), parameter    :: SIG = 8.17E-11_RP ! stefun bolzman constant   [cgs unit]

    real(RP), parameter    :: SRATIO = 0.75_RP  ! ratio between direct/total solar [-]

    !-- configuration variables
    logical, intent(in) :: LSOLAR  ! logical   [true=both, false=SSG only]

    !-- Input variables from Coupler to Urban
    real(RP), intent(in)    :: TA   ! temp at 1st atmospheric level          [K]
    real(RP), intent(in)    :: QA   ! mixing ratio at 1st atmospheric level  [kg/kg]
    real(RP), intent(in)    :: UA   ! wind speed at 1st atmospheric level    [m/s]
    real(RP), intent(in)    :: U1   ! u at 1st atmospheric level             [m/s]
    real(RP), intent(in)    :: V1   ! v at 1st atmospheric level             [m/s]
    real(RP), intent(in)    :: ZA   ! height of 1st atmospheric level        [m]
    real(RP), intent(in)    :: SSG  ! downward total short wave radiation    [W/m/m]
    real(RP), intent(in)    :: LLG  ! downward long wave radiation           [W/m/m]
    real(RP), intent(in)    :: RAIN ! precipitation                          [mm/h]
                                    !   (if you use RAIN, check unit!)
    real(RP), intent(in)    :: RHOO ! air density                            [kg/m^3]
    real(RP), intent(in)    :: XLAT ! latitude                               [deg]
    real(RP), intent(in)    :: XLON ! longitude                              [deg]

    !! for shadow effect model
    !!   real(RP), intent(in)    :: DECLIN ! solar declination
    ![rad]
    !!   real(RP), intent(in)    :: COSZ !
    !sin(fai)*sin(del)+cos(fai)*cos(del)*cos(omg)
    !!   real(RP), intent(in)    :: OMG  ! solar hour angle
    ![rad]

    !-- In/Out variables from/to Coupler to/from Urban
    real(RP), intent(inout) :: TR   ! roof temperature              [K]
    real(RP), intent(inout) :: TB   ! building wall temperature     [K]
    real(RP), intent(inout) :: TG   ! road temperature              [K]
    real(RP), intent(inout) :: TC   ! urban-canopy air temperature  [K]
    real(RP), intent(inout) :: QC   ! urban-canopy air mixing ratio [kg/kg]
    real(RP), intent(inout) :: UC   ! diagnostic canopy wind [m/s]
    real(RP), intent(inout) :: TRL(UKS:UKE)  ! layer temperature [K]
    real(RP), intent(inout) :: TBL(UKS:UKE)  ! layer temperature [K]
    real(RP), intent(inout) :: TGL(UKS:UKE)  ! layer temperature [K]

    !-- Output variables from Urban to Coupler
    real(RP), intent(out) :: TS     ! surface temperature              [K]
    real(RP), intent(out) :: SH     ! sensible heat flux               [W/m/m]
    real(RP), intent(out) :: LH     ! latent heat flux                 [W/m/m]
    real(RP), intent(out) :: SW     ! upward short wave radiation flux [W/m/m]
    real(RP), intent(out) :: LW     ! upward long wave radiation flux  [W/m/m]
    real(RP), intent(out) :: G      ! heat flux into the ground        [W/m/m]

    !-- Local variables
    logical  :: SHADOW = .false.
           ! [true=consider svf and shadow effects, false=consider svf effect
           ! only]

    integer  :: tloc     ! local time (1-24h)
    real(RP) :: AH_t     ! Sensible Anthropogenic heat [W/m^2]
    real(RP) :: ALH_t    ! Latent Anthropogenic heat [W/m^2]

    real(RP) :: SSGD     ! downward direct short wave radiation   [W/m/m]
    real(RP) :: SSGQ     ! downward diffuse short wave radiation  [W/m/m]

    real(RP) :: W, VFGS, VFGW, VFWG, VFWS, VFWW
    real(RP) :: SX, SD, SQ, RX
    real(RP) :: RHO

    real(RP) :: TRP = 350.0_RP   ! TRP: at previous time step [K]
    real(RP) :: TBP = 350.0_RP   ! TBP: at previous time step [K]
    real(RP) :: TGP = 350.0_RP   ! TGP: at previous time step [K]
    real(RP) :: TCP = 350.0_RP   ! TCP: at previous time step [K]
    real(RP) :: QCP = 0.01_RP    ! QCP: at previous time step [kg/kg]
    real(RP) :: UST, TST, QST

    real(RP) :: PS         ! Surface Pressure [hPa]
    real(RP) :: TAV        ! Vertial Temperature [K]
    real(RP) :: ES

    real(RP) :: LNET, SNET, FLXUV, FLXTH, FLXHUM, FLXG
    real(RP) :: RN     ! net radition                     [W/m/m]
    real(RP) :: PSIM   ! similality stability shear function for momentum
    real(RP) :: PSIH   ! similality stability shear function for heat

    ! for shadow effect model
    ! real(RP) :: HOUI1, HOUI2, HOUI3, HOUI4, HOUI5, HOUI6, HOUI7, HOUI8
    ! real(RP) :: SLX, SLX1, SLX2, SLX3, SLX4, SLX5, SLX6, SLX7, SLX8
    ! real(RP) :: THEATAZ    ! Solar Zenith Angle [rad]
    ! real(RP) :: THEATAS    ! = PI/2. - THETAZ
    ! real(RP) :: FAI        ! Latitude [rad]

    real(RP) :: SR, SB, SG, RR, RB, RG
    real(RP) :: SR1, SB1, SB2, SG1, SG2
    real(RP) :: RB1, RB2, RG1, RG2
    real(RP) :: HR, ELER, G0R, FLXTHR, FLXHUMR
    real(RP) :: HB, ELEB, G0B, FLXTHB, FLXHUMB
    real(RP) :: HG, ELEG, G0G, FLXTHG, FLXHUMG

    real(RP) :: Z
    real(RP) :: QS0R, DQS0RDTR, DESDT
    real(RP) :: QS0B, DQS0BDTB
    real(RP) :: QS0G, DQS0GDTG

    real(RP) :: RIBR, XXXR, BHR, ALPHAR, CHR, CDR
    real(RP) :: RIBC, XXXC, BHC
    real(RP) :: ALPHAC, ALPHAB, ALPHAG
    real(RP) :: CHC, CHB, CHG, CDC
    real(RP) :: TC1, TC2, QC1, QC2

    real(RP) :: F
    real(RP) :: DRRDTR, DHRDTR, DELERDTR, DG0RDTR
    real(RP) :: DTR, DFDT

    real(RP) :: FX, FY, GF, GX, GY
    real(RP) :: DTCDTB, DTCDTG
    real(RP) :: DQCDTB, DQCDTG
    real(RP) :: DRBDTB1,  DRBDTG1,  DRBDTB2,  DRBDTG2
    real(RP) :: DRGDTB1,  DRGDTG1,  DRGDTB2,  DRGDTG2
    real(RP) :: DRBDTB,   DRBDTG,   DRGDTB,   DRGDTG
    real(RP) :: DHBDTB,   DHBDTG,   DHGDTB,   DHGDTG
    real(RP) :: DELEBDTB, DELEBDTG, DELEGDTG, DELEGDTB
    real(RP) :: DG0BDTB,  DG0BDTG,  DG0GDTG,  DG0GDTB
    real(RP) :: DTB, DTG, DTC

    real(RP) :: XXX, X, Z0, Z0H, CD, CH
    real(RP) :: PSIX, PSIT, PSIX2, PSIT2, PSIX10, PSIT10

    integer  :: iteration, K

    !-----------------------------------------------------------
    ! Set parameters
    !-----------------------------------------------------------

    ! local time
    ! tloc=mod(int(OMG/PI*180./15.+12.+0.5 ),24)
    tloc = mod( (int(TIME/(60.0_RP*60.0_RP)) + int(XLON/15.0_RP)),24 )
    if(tloc==0) tloc = 24

    ! Calculate AH data at LST
    AH_t  = AH  * ahdiurnal(tloc)
    ALH_t = ALH * ahdiurnal(tloc)

    if( ZDC+Z0C+2.0_RP >= ZA) then
      if( IO_L ) write(IO_FID_LOG,*) 'ZDC + Z0C + 2m is larger than the 1st WRF level' // &
                                     'Stop in subroutine urban - change ZDC and Z0C'
      call PRC_MPIstop
    endif

    !if(.NOT.LSOLAR) then   ! Radiation scheme does not have SSGD and SSGQ.
      SSGD = SRATIO * SSG
      SSGQ = SSG - SSGD
    !endif

    W    = 2.0_RP * 1.0_RP * HGT
    VFGS = SVF
    VFGW = 1.0_RP - SVF
    VFWG = ( 1.0_RP - SVF ) * ( 1.0_RP - R ) / W
    VFWS = VFWG
    VFWW = 1.0_RP - 2.0_RP * VFWG


    !--- Convert unit from MKS to cgs

    SX  = (SSGD+SSGQ) / 697.7_RP / 60.0_RP  ! downward short wave radition [ly/min]
    SD  = SSGD        / 697.7_RP / 60.0_RP  ! downward direct short wave radiation
    SQ  = SSGQ        / 697.7_RP / 60.0_RP  ! downward diffuse short wave radiation
    RX  = LLG         / 697.7_RP / 60.0_RP  ! downward long wave radiation
    RHO = RHOO * 0.001_RP                   ! air density at first atmospheric level

    !--- Renew surface and layer temperatures

    TRP = TR
    TBP = TB
    TGP = TG
    TCP = TC
    QCP = QC

    !--- calculate canopy wind

    call canopy_wind(ZA, UA, UC)


    !-----------------------------------------------------------
    ! Radiation : Net Short Wave Radiation at roof/wall/road
    !-----------------------------------------------------------

    if( SSG > 0.0_RP ) then !  SSG is downward short

      ! currently we use no shadow effect model
      !!     IF(.NOT.SHADOW) THEN              ! no shadow effects model

      SR1  = SX * ( 1.0_RP - ALBR )
      SG1  = SX * VFGS * ( 1.0_RP - ALBG )
      SB1  = SX * VFWS * ( 1.0_RP - ALBB )
      SG2  = SB1 * ALBB / ( 1.0_RP - ALBB ) * VFGW * ( 1.0_RP - ALBG )
      SB2  = SG1 * ALBG / ( 1.0_RP - ALBG ) * VFWG * ( 1.0_RP - ALBB )

      SR   = SR1
      SG   = SG1 + SG2
      SB   = SB1 + SB2
      SNET = R * SR + W * SB + RW * SG

    else

      SR   = 0.0_RP
      SG   = 0.0_RP
      SB   = 0.0_RP
      SNET = 0.0_RP

    end if

    !-----------------------------------------------------------
    ! Energy balance on roof/wall/road surface
    !-----------------------------------------------------------

    !--- Roof

    Z    = ZA - ZDC
    BHR  = LOG(Z0R/Z0HR) / 0.4_RP
    RIBR = ( GRAV * 2.0_RP / (TA+TRP) ) * (TA-TRP) * (Z+Z0R) / (UA*UA)

    call mos(XXXR,ALPHAR,CDR,BHR,RIBR,Z,Z0R,UA,TA,TRP,RHO)

    CHR = ALPHAR / RHO / CP / UA
    ! IF(RAIN > 1.) BETR=0.7

    TAV = TA * ( 1.0_RP + 0.61_RP * QA )
    PS  = RHOO * Rdry * TAV / 100.0_RP ! [hPa]

    ! TR  Solving Non-Linear Equation by Newton-Rapson
    do iteration = 1, 20

      ES       = 6.11_RP * exp( ( LH0/Rvap) * (TRP-TEM00) / (TEM00*TRP) )
      DESDT    = (LH0/Rvap) * ES / (TRP**2)
      QS0R     = 0.622_RP * ES / ( PS - 0.378_RP * ES )
      DQS0RDTR = DESDT * 0.622_RP * PS / ( ( PS - 0.378_RP * ES )**2 )

      RR       = EPSR * ( RX - SIG * (TRP**4) / 60.0_RP )
      HR       = RHO * CP * CHR * UA * (TRP-TA) * 100.0_RP
      ELER     = RHO * EL * CHR * UA * BETR * (QS0R-QA) * 100.0_RP
      G0R      = AKSR * (TRP-TRL(1)) / (DZR(1)/2.0_RP)

      F        = SR + RR - HR - ELER - G0R

      DRRDTR   = ( -4.0_RP * EPSR * SIG * TRP**3 ) / 60.0_RP
      DHRDTR   = RHO * CP * CHR * UA * 100.0_RP
      DELERDTR = RHO * EL * CHR * UA * BETR * DQS0RDTR * 100.0_RP
      DG0RDTR  = 2.0_RP * AKSR / DZR(1)

      DFDT     = DRRDTR - DHRDTR - DELERDTR - DG0RDTR
      DTR      = F / DFDT

      TR       = TRP - DTR
      TRP      = TR

      if( abs(F) < 0.000001_RP .AND. abs(DTR) < 0.000001_RP ) exit

    end do

    FLXTHR  = HR / RHO / CP / 100.0_RP
    FLXHUMR = ELER / RHO / EL / 100.0_RP

    !--- Wall and Road

    Z    = ZA - ZDC
    BHC  = LOG(Z0C/Z0HC) / 0.4_RP
    RIBC = ( GRAV * 2.0_RP / (TA+TCP) ) * (TA-TCP) * (Z+Z0C) / (UA*UA)

    call mos(XXXC,ALPHAC,CDC,BHC,RIBC,Z,Z0C,UA,TA,TCP,RHO)

    ! empirical form
    ALPHAB = RHO * CP * ( 6.15_RP + 4.18_RP * UC ) / 1200.0_RP
    if( UC > 5.0_RP ) ALPHAB = RHO * CP * ( 7.51_RP * UC**0.78_RP ) / 1200.0_RP

    ALPHAG = RHO * CP * ( 6.15_RP + 4.18_RP * UC ) / 1200.0_RP
    if( UC > 5.0_RP ) ALPHAG = RHO * CP * ( 7.51_RP * UC**0.78_RP ) / 1200.0_RP

    CHC = ALPHAC / RHO / CP / UA
    CHB = ALPHAB / RHO / CP / UC
    CHG = ALPHAG / RHO / CP / UC
    !   BETB=0.0
    !   IF(RAIN > 1.) BETG=0.7


    ! TB,TG  Solving Non-Linear Simultaneous Equation by Newton-Rapson
    do iteration = 1, 20

      ES       = 6.11_RP * exp( (LH0/Rvap) * (TBP-TEM00) / (TEM00*TBP) )
      DESDT    = (LH0/Rvap) * ES / (TBP**2)
      QS0B     = 0.622_RP * ES / ( PS - 0.378_RP * ES )
      DQS0BDTB = DESDT * 0.622_RP * PS / ( ( PS - 0.378_RP * ES )**2 )

      ES       = 6.11_RP * exp( (LH0/Rvap) * (TGP-TEM00) / (TEM00*TGP) )
      DESDT    = (LH0/Rvap) * ES / (TGP**2)
      QS0G     = 0.622_RP * ES / ( PS - 0.378_RP * ES )
      DQS0GDTG = DESDT * 0.22_RP * PS / ( ( PS - 0.378_RP * ES )**2 ) ! bug: 0.22 => 0.622 ?

      RG1      = EPSG * ( RX * VFGS                             &
                        + EPSB * VFGW * SIG * TBP**4 / 60.0_RP  &
                        - SIG * TGP**4 / 60.0_RP                )

      RB1      = EPSB * ( RX * VFWS         &
                        + EPSG * VFWG * SIG * TGP**4 / 60.0_RP &
                        + EPSB * VFWW * SIG * TBP**4 / 60.0_RP &
                        - SIG * TBP**4 / 60.0_RP               )

      RG2      = EPSG * ( (1.0_RP-EPSB) * (1.0_RP-SVF) * VFWS * RX                                            &
                        + (1.0_RP-EPSB) * (1.0_RP-SVF) * VFWG * EPSG * SIG * TGP**4 /60.0_RP                  &
                        + EPSB * (1.0_RP-EPSB) * (1.0_RP-SVF) * (1.0_RP-2.0_RP*VFWS) * SIG * TBP**4 / 60.0_RP )

      RB2      = EPSB * ( (1.0_RP-EPSG) * VFWG * VFGS * RX                                                            &
                        + (1.0_RP-EPSG) * EPSB * VFGW * VFWG * SIG * (TBP**4) / 60.0_RP                               &
                        + (1.0_RP-EPSB) * VFWS * (1.0_RP-2.0_RP*VFWS) * RX                                            &
                        + (1.0_RP-EPSB) * VFWG * (1.0_RP-2.0_RP*VFWS) * EPSG * SIG * EPSG * TGP**4 / 60.0_RP          &
                        + EPSB * (1.0_RP-EPSB) * (1.0_RP-2.0_RP*VFWS) * (1.0_RP-2.0_RP*VFWS) * SIG * TBP**4 / 60.0_RP )

      RG       = RG1 + RG2
      RB       = RB1 + RB2

      DRBDTB1  = EPSB * ( 4.0_RP * EPSB * SIG * TB**3 * VFWW - 4.0_RP * SIG * TB**3 ) / 60.0_RP
      DRBDTG1  = EPSB * ( 4.0_RP * EPSG * SIG * TG**3 * VFWG ) / 60.0_RP
      DRBDTB2  = EPSB * ( 4.0_RP * (1.0_RP-EPSG) * EPSB * SIG * TB**3 * VFGW * VFWG &
                        + 4.0_RP * EPSB * (1.0_RP-EPSB) * SIG * TB**3 * VFWW * VFWW ) / 60.0_RP
      DRBDTG2  = EPSB * ( 4.0_RP * (1.0_RP-EPSB) * EPSG * SIG * TG**3 * VFWG * VFWW ) / 60.0_RP

      DRGDTB1  = EPSG * ( 4.0_RP * EPSB * SIG * TB**3 * VFGW ) / 60.0_RP
      DRGDTG1  = EPSG * ( -4.0_RP * SIG * TG**3 ) / 60.0_RP
      DRGDTB2  = EPSG * ( 4.0_RP * EPSB * (1.0_RP-EPSB) * SIG * TB**3 * VFWW * VFGW ) / 60.0_RP
      DRGDTG2  = EPSG * ( 4.0_RP * (1.0_RP-EPSB) * EPSG * SIG * TG**3 * VFWG * VFGW ) / 60.0_RP

      DRBDTB   = DRBDTB1 + DRBDTB2
      DRBDTG   = DRBDTG1 + DRBDTG2
      DRGDTB   = DRGDTB1 + DRGDTB2
      DRGDTG   = DRGDTG1 + DRGDTG2

      HB       = RHO * CP * CHB * UC * (TBP-TCP) * 100.0_RP
      HG       = RHO * CP * CHG * UC * (TGP-TCP) * 100.0_RP

      DTCDTB   = W  * ALPHAB / ( RW*ALPHAC + RW*ALPHAG + W*ALPHAB )
      DTCDTG   = RW * ALPHAG / ( RW*ALPHAC + RW*ALPHAG + W*ALPHAB )

      DHBDTB   = RHO * CP * CHB * UC * (1.0_RP-DTCDTB) * 100.0_RP
      DHBDTG   = RHO * CP * CHB * UC * (0.0_RP-DTCDTG) * 100.0_RP
      DHGDTG   = RHO * CP * CHG * UC * (1.0_RP-DTCDTG) * 100.0_RP
      DHGDTB   = RHO * CP * CHG * UC * (0.0_RP-DTCDTB) * 100.0_RP

      ELEB     = RHO * EL * CHB * UC * BETB * (QS0B-QCP) * 100.0_RP
      ELEG     = RHO * EL * CHG * UC * BETG * (QS0G-QCP) * 100.0_RP

      DQCDTB   = W  * ALPHAB * BETB * DQS0BDTB / ( RW*ALPHAC + RW*ALPHAG*BETG + W*ALPHAB*BETB )
      DQCDTG   = RW * ALPHAG * BETG * DQS0GDTG / ( RW*ALPHAC + RW*ALPHAG*BETG + W*ALPHAB*BETB )

      DELEBDTB = RHO * EL * CHB * UC * BETB * (DQS0BDTB-DQCDTB) * 100.0_RP
      DELEBDTG = RHO * EL * CHB * UC * BETB * (0.0_RP-DQCDTG) * 100.0_RP
      DELEGDTG = RHO * EL * CHG * UC * BETG * (DQS0GDTG-DQCDTG) * 100.0_RP
      DELEGDTB = RHO * EL * CHG * UC * BETG * (0.0_RP-DQCDTB) * 100.0_RP

      G0B      = AKSB * (TBP-TBL(1)) / (DZB(1)/2.0_RP)
      G0G      = AKSG * (TGP-TGL(1)) / (DZG(1)/2.0_RP)

      DG0BDTB  = 2.0_RP * AKSB / DZB(1)
      DG0BDTG  = 0.0_RP
      DG0GDTG  = 2.0_RP * AKSG / DZG(1)
      DG0GDTB  = 0.0_RP

      F        = SB + RB - HB - ELEB - G0B
      FX       = DRBDTB - DHBDTB - DELEBDTB - DG0BDTB
      FY       = DRBDTG - DHBDTG - DELEBDTG - DG0BDTG

      GF       = SG + RG - HG - ELEG - G0G
      GX       = DRGDTB - DHGDTB - DELEGDTB - DG0GDTB
      GY       = DRGDTG - DHGDTG - DELEGDTG - DG0GDTG

      DTB      = ( GF*FY - F*GY ) / ( FX*GY - GX*FY )
      DTG      = -( GF + GX*DTB ) / GY

      TB       = TBP + DTB
      TG       = TGP + DTG

      TBP      = TB
      TGP      = TG

      TC1      = RW*ALPHAC + RW*ALPHAG + W*ALPHAB
      TC2      = RW*ALPHAC*TA + RW*ALPHAG*TGP + W*ALPHAB*TBP
      TC       = TC2 / TC1

      QC1      = RW*ALPHAC + RW*ALPHAG*BETG + W*ALPHAB*BETB
      QC2      = RW*ALPHAC*QA + RW*ALPHAG*BETG*QS0G + W*ALPHAB*BETB*QS0B
      QC       = QC2 / QC1

      DTC      = TCP - TC
      TCP      = TC
      QCP      = QC

      if( abs(F)   < 0.000001_RP .and. &
          abs(DTB) < 0.000001_RP .and. &
          abs(GF)  < 0.000001_RP .and. &
          abs(DTG) < 0.000001_RP .and. &
          abs(DTC) < 0.000001_RP       ) exit

    end do

    FLXTHB  = HB / RHO / CP / 100.0_RP
    FLXHUMB = ELEB / RHO / EL / 100.0_RP
    FLXTHG  = HG / RHO / CP / 100.0_RP
    FLXHUMG = ELEG / RHO / EL / 100.0_RP

    !-----------------------------------------------------------
    ! Total Fluxes from Urban Canopy
    !-----------------------------------------------------------

    FLXUV  = ( R*CDR + RW*CDC ) * UA * UA
    FLXTH  = ( R*FLXTHR  + W*FLXTHB  + RW*FLXTHG ) + AH_t/RHOO/CPdry
    FLXHUM = ( R*FLXHUMR + W*FLXHUMB + RW*FLXHUMG ) + ALH_t/RHOO/LH0
    FLXG   = ( R*G0R + W*G0B + RW*G0G )
    LNET   = R*RR + W*RB + RW*RG

    !-----------------------------------------------------------
    ! Convert Unit: FLUXES and u* T* q*  [cgs] --> [MKS]
    !-----------------------------------------------------------

    SH = FLXTH  * RHOO * CPdry               ! Sensible heat flux          [W/m/m]
    LH = FLXHUM * RHOO * LH0                 ! Latent heat flux            [W/m/m]
    LW = LLG - ( LNET * 697.7_RP * 60.0_RP ) ! Upward longwave radiation   [W/m/m]
    SW = SSG - ( SNET * 697.7_RP * 60.0_RP ) ! Upward shortwave radiation  [W/m/m]

    G  = -FLXG * 697.7_RP * 60.0_RP          ! [W/m/m]
    RN = (SNET+LNET) * 697.7_RP * 60.0_RP    ! Net radiation [W/m/m]

    UST = sqrt( FLXUV )                      ! u* [m/s]
    TST = -FLXTH / UST                       ! T* [K]
    QST = -FLXHUM / UST                      ! q* [-]

    !-----------------------------------------------------------
    !  calculate temperature in building/road
    !  multi-layer heat equation model
    !  Solving Heat Equation by Tri Diagonal Matrix Algorithm
    !-----------------------------------------------------------

    call multi_layer(UKE,BOUND,G0R,CAPR,AKSR,TRL,DZR,DELT,TRLEND)
    call multi_layer(UKE,BOUND,G0B,CAPB,AKSB,TBL,DZB,DELT,TBLEND)
    call multi_layer(UKE,BOUND,G0G,CAPG,AKSG,TGL,DZG,DELT,TGLEND)

    !-----------------------------------------------------------
    !  diagnostic GRID AVERAGED TS
    !-----------------------------------------------------------

    Z0  = Z0C
    Z0H = Z0HC
    Z   = ZA - ZDC

    XXX = KARMAN * GRAV * Z * TST / TA / UST / UST ! M-O theory (z/L)

    if( XXX >=  1.0_RP ) XXX =  1.0_RP
    if( XXX <= -5.0_RP ) XXX = -5.0_RP

    if( XXX > 0.0_RP ) then
      PSIM = -5.0_RP * XXX
      PSIH = -5.0_RP * XXX
    else
      X    = ( 1.0_RP - 16.0_RP * XXX )**0.25_RP
      PSIM = 2.0_RP * log((1.0_RP+X)/2.0_RP) + log((1.0_RP+X*X)/2.0_RP) - 2.0_RP*atan(X) + PI/2.0_RP
      PSIH = 2.0_RP * log((1.0_RP+X*X)/2.0_RP)
    end if

    CD = KARMAN**2.0_RP / ( LOG(Z/Z0) - PSIM )**2

    CH = 0.4_RP**2 / ( LOG(Z/Z0) - PSIM ) / ( LOG(Z/Z0H) - PSIH )
    TS = TA + FLXTH / CH / UA ! surface potential temp (flux temp)

    !m   CHS = 0.4*UST/(LOG(Z/Z0H)-PSIH)
    !m   QS = QA + FLXHUM/CH/UA   ! surface humidity
    !
    !   TS = TA + FLXTH/CHS    ! surface potential temp (flux temp)
    !   QS = QA + FLXHUM/CHS   ! surface humidity
    !   TS = (LW/STB/0.88)**0.25       ! Radiative temperature [K]

    return
  end subroutine urban

  !-----------------------------------------------------------------------------
  subroutine canopy_wind(ZA, UA, UC)
    implicit none

    real(RP), intent(in)  :: ZA   ! height at 1st atmospheric level [m]
    real(RP), intent(in)  :: UA   ! wind speed at 1st atmospheric level [m/s]
    real(RP), intent(out) :: UC   ! wind speed at 1st atmospheric level [m/s]

    real(RP) :: UR,ZC,XLB,BB

    if( ZR + 2.0_RP < ZA ) then
      UR  = UA * log((ZR-ZDC)/Z0C) / log((ZA-ZDC)/Z0C)
      ZC  = 0.7_RP * ZR
      XLB = 0.4_RP * (ZR-ZDC)
      ! BB formulation from Inoue (1963)
      BB  = 0.4_RP * ZR / ( XLB * log((ZR-ZDC)/Z0C) )
      UC  = UR * exp( -BB * (1.0_RP-ZC/ZR) )
    else
      ! PRINT *, 'Warning ZR + 2m  is larger than the 1st WRF level'
      ZC  = ZA / 2.0_RP
      UC  = UA / 2.0_RP
    endif

    return
  end subroutine canopy_wind

  !-----------------------------------------------------------------------------
  subroutine mos(XXX,ALPHA,CD,B1,RIB,Z,Z0,UA,TA,TSF,RHO)

    !  XXX:   z/L (requires iteration by Newton-Rapson method)
    !  B1:    Stanton number
    !  PSIM:  = PSIX of LSM
    !  PSIH:  = PSIT of LSM

    implicit none

    real(RP), parameter     :: CP = 0.24_RP
    real(RP), intent(in)    :: B1, Z, Z0, UA, TA, TSF, RHO
    real(RP), intent(out)   :: ALPHA, CD
    real(RP), intent(inout) :: XXX, RIB
    real(RP)                :: XXX0, X, X0, FAIH, DPSIM, DPSIH
    real(RP)                :: F, DF, XXXP, US, TS, AL, XKB, DD, PSIM, PSIH
    integer                 :: NEWT
    integer, parameter      :: NEWT_END = 10

    if( RIB <= -15.0_RP ) RIB = -15.0_RP

    if( RIB < 0.0_RP ) then

      do NEWT = 1, NEWT_END

        if( XXX >= 0.0_RP ) XXX = -1.0e-3_RP

        XXX0  = XXX * Z0/(Z+Z0)

        X     = (1.0_RP-16.0_RP*XXX)**0.25
        X0    = (1.0_RP-16.0_RP*XXX0)**0.25

        PSIM  = log( (Z+Z0)/Z0 ) &
              - log( (X+1.0_RP)**2 * (X**2+1.0_RP) ) &
              + 2.0_RP * atan(X) &
              + log( (X+1.0_RP)**2 * (X0**2+1.0_RP) ) &
              - 2.0_RP * atan(X0)
        FAIH  = 1.0_RP / sqrt( 1.0_RP - 16.0_RP*XXX )
        PSIH  = log( (Z+Z0)/Z0 ) + 0.4_RP*B1 &
              - 2.0_RP * log( sqrt( 1.0_RP - 16.0_RP*XXX ) + 1.0_RP ) &
              + 2.0_RP * log( sqrt( 1.0_RP - 16.0_RP*XXX0 ) + 1.0_RP )

        DPSIM = ( 1.0_RP - 16.0_RP*XXX )**(-0.25) / XXX &
              - ( 1.0_RP - 16.0_RP*XXX0 )**(-0.25) / XXX
        DPSIH = 1.0_RP / sqrt( 1.0_RP - 16.0_RP*XXX ) / XXX &
              - 1.0_RP / sqrt( 1.0_RP - 16.0_RP*XXX0 ) / XXX

        F     = RIB * PSIM**2 / PSIH - XXX

        DF    = RIB * ( 2.0_RP*DPSIM*PSIM*PSIH - DPSIH*PSIM**2 ) &
              / PSIH**2 - 1.0_RP

        XXXP  = XXX
        XXX   = XXXP - F / DF

        if( XXX <= -10.0_RP ) XXX = -10.0_RP

      end do

    else if( RIB >= 0.142857_RP ) then

      XXX  = 0.714_RP
      PSIM = log( (Z+Z0)/Z0 ) + 7.0_RP * XXX
      PSIH = PSIM + 0.4_RP * B1

    else

      AL   = LOG( (Z+Z0)/Z0 )
      XKB  = 0.4_RP * B1
      DD   = -4.0_RP * RIB * 7.0_RP * XKB * AL + (AL+XKB)**2
      if( DD <= 0.0_RP ) DD = 0.0_RP

      XXX  = ( AL + XKB - 2.0_RP*RIB*7.0_RP*AL - sqrt(DD) ) / ( 2.0_RP * ( RIB*7.0_RP**2 - 7.0_RP ) )
      PSIM = log( (Z+Z0)/Z0 ) + 7.0_RP * min( XXX, 0.714_RP )
      PSIH = PSIM + 0.4_RP * B1

    endif

    US = 0.4_RP * UA / PSIM             ! u*
    if( US <= 0.01_RP ) US = 0.01_RP
    TS = 0.4_RP * (TA-TSF) / PSIH       ! T*

    CD    = US * US / UA**2                 ! CD
    ALPHA = RHO * CP * 0.4_RP * US / PSIH   ! RHO*CP*CH*U

    return
  end subroutine mos

  !-----------------------------------------------------------------------------
  subroutine multi_layer(KM,BOUND,G0,CAP,AKS,TSL,DZ,DELT,TSLEND)
    implicit none

    real(RP), intent(in)    :: G0
    real(RP), intent(in)    :: CAP
    real(RP), intent(in)    :: AKS
    real(RP), intent(in)    :: DELT      ! Time step [ s ]
    real(RP), intent(in)    :: TSLEND
    integer,  intent(in)    :: KM
    integer,  intent(in)    :: BOUND
    real(RP), intent(in)    :: DZ(KM)
    real(RP), intent(inout) :: TSL(KM)
    real(RP)                :: A(KM), B(KM), C(KM), D(KM), X(KM), P(KM), Q(KM)
    real(RP)                :: DZEND
    integer                 :: K

    DZEND = DZ(KM)

    A(1)  = 0.0_RP

    B(1)  = CAP * DZ(1) / DELT &
          + 2.0_RP * AKS / (DZ(1)+DZ(2))
    C(1)  = -2.0_RP * AKS / (DZ(1)+DZ(2))
    D(1)  = CAP * DZ(1) / DELT * TSL(1) + G0

    do K = 2, KM-1
      A(K) = -2.0_RP * AKS / (DZ(K-1)+DZ(K))
      B(K) = CAP * DZ(K) / DELT + 2.0_RP * AKS / (DZ(K-1)+DZ(K)) + 2.0_RP * AKS / (DZ(K)+DZ(K+1))
      C(K) = -2.0_RP * AKS / (DZ(K)+DZ(K+1))
      D(K) = CAP * DZ(K) / DELT * TSL(K)
    end do

    if( BOUND == 1 ) then ! Flux=0
      A(KM) = -2.0_RP * AKS / (DZ(KM-1)+DZ(KM))
      B(KM) = CAP * DZ(KM) / DELT + 2.0_RP * AKS / (DZ(KM-1)+DZ(KM))
      C(KM) = 0.0_RP
      D(KM) = CAP * DZ(KM) / DELT * TSL(KM)
    else ! T=constant
      A(KM) = -2.0_RP * AKS / (DZ(KM-1)+DZ(KM))
      B(KM) = CAP * DZ(KM) / DELT + 2.0_RP * AKS / (DZ(KM-1)+DZ(KM)) + 2.0_RP * AKS / (DZ(KM)+DZEND)
      C(KM) = 0.0_RP
      D(KM) = CAP * DZ(KM) / DELT * TSL(KM) + 2.0_RP * AKS * TSLEND / (DZ(KM)+DZEND)
    end if

    P(1) = -C(1) / B(1)
    Q(1) =  D(1) / B(1)

    do K = 2, KM
      P(K) = -C(K) / ( A(K) * P(K-1) + B(K) )
      Q(K) = ( -A(K) * Q(K-1) + D(K) ) / ( A(K) * P(K-1) + B(K) )
    end do

    X(KM) = Q(KM)

    do K = KM-1, 1, -1
      X(K) = P(K) * X(K+1) + Q(K)
    end do

    do K = 1, KM
      TSL(K) = X(K)
    enddo

    return
  end subroutine multi_layer

  !-----------------------------------------------------------------------------
  subroutine urban_param_setup
    implicit none

    real(RP) :: DHGT,VFWS,VFGS
    integer  :: k

    ! initialize
    R    = 0.0_RP
    RW   = 0.0_RP
    HGT  = 0.0_RP
    Z0HR = 0.0_RP
    Z0HB = 0.0_RP
    Z0HG = 0.0_RP
    Z0C  = 0.0_RP
    Z0HC = 0.0_RP
    ZDC  = 0.0_RP
    SVF  = 0.0_RP

    ! Thickness of roof, building wall, ground layers
    DZR(UKS:UKE) = 0.05 ! [m]
    DZB(UKS:UKE) = 0.05 ! [m]
    DZG(1)       = 0.05 ! [m]
    DZG(2)       = 0.25 ! [m]
    DZG(3)       = 0.50 ! [m]
    DZG(4)       = 0.75 ! [m]

    ! convert unit
    DZR(UKS:UKE) = DZR(UKS:UKE) * 100.0_RP ! [m]-->[cm]
    DZB(UKS:UKE) = DZB(UKS:UKE) * 100.0_RP ! [m]-->[cm]
    DZG(UKS:UKE) = DZG(UKS:UKE) * 100.0_RP ! [m]-->[cm]

    CAPR = CAPR * ( 1.0_RP / 4.1868_RP ) * 1.E-6_RP   ! [J/m^3/K] --> [cal/cm^3/deg]
    CAPB = CAPB * ( 1.0_RP / 4.1868_RP ) * 1.E-6_RP   ! [J/m^3/K] --> [cal/cm^3/deg]
    CAPG = CAPG * ( 1.0_RP / 4.1868_RP ) * 1.E-6_RP   ! [J/m^3/K] --> [cal/cm^3/deg]
    AKSR = AKSR * ( 1.0_RP / 4.1868_RP ) * 1.E-2_RP   ! [J/m/s/K] --> [cal/cm/s/deg]
    AKSB = AKSB * ( 1.0_RP / 4.1868_RP ) * 1.E-2_RP   ! [J/m/s/K] --> [cal/cm/s/deg]
    AKSG = AKSG * ( 1.0_RP / 4.1868_RP ) * 1.E-2_RP   ! [J/m/s/K] --> [cal/cm/s/deg]

    ! set up other urban parameters
    Z0HR = 0.1_RP * Z0R
    Z0HB = 0.1_RP * Z0B
    Z0HG = 0.1_RP * Z0G
    ZDC  = ZR * 0.3_RP
    Z0C  = ZR * 0.15_RP
    Z0HC = 0.1_RP * Z0C

    ! HGT:  Normalized height
    HGT  = ZR / ( ROAD_WIDTH + ROOF_WIDTH )

    ! R:  Normalized Roof Width (a.k.a. "building coverage ratio")
    R    = ROOF_WIDTH / ( ROAD_WIDTH + ROOF_WIDTH )
    RW   = 1.0_RP - R

    ! Calculate Sky View Factor:
    DHGT = HGT / 100.0_RP
    HGT  = 0.0_RP
    VFWS = 0.0_RP
    HGT  = HGT - DHGT / 2.0_RP
    do k = 1, 99
      HGT  = HGT - DHGT
      VFWS = VFWS + 0.25_RP * ( 1.0_RP - HGT / sqrt( HGT**2 + RW**2 ) )
    end do

    VFWS = VFWS / 99.0_RP
    VFWS = VFWS * 2.0_RP
    VFGS = 1.0_RP - 2.0_RP * VFWS * HGT / RW
    SVF  = VFGS

    return
  end subroutine urban_param_setup

end module mod_urban_phy_ucm
