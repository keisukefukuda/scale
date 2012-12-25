!-------------------------------------------------------------------------------
!> module Thermodynamics
!!
!! @par Description
!!          Thermodynamics module
!!
!! @author H.Tomita and SCALE developpers
!!
!! @par History
!! @li      2011-10-24 (T.Seiki)     [new] Import from NICAM
!! @li      2012-02-10 (H.Yashiro)   [mod] Reconstruction
!! @li      2012-03-23 (H.Yashiro)   [mod] Explicit index parameter inclusion
!! @li      2012-12-22 (S.Nishizawa) [mod] Use thermodyn macro set
!!
!<
!-------------------------------------------------------------------------------
#include "macro_thermodyn.h"
module mod_atmos_thermodyn
  !-----------------------------------------------------------------------------
  !
  !++ used modules
  !
  use mod_stdio, only: &
     IO_FID_LOG, &
     IO_L
  use mod_const, only : &
     Rdry  => CONST_Rdry,  &
     CPdry => CONST_CPdry, &
     CVdry => CONST_CVdry, &
     Rvap  => CONST_Rvap,  &
     CPvap => CONST_CPvap, &
     CVvap => CONST_CVvap, &
     CL    => CONST_CL,    &
     CI    => CONST_CI,    &
     PRE00 => CONST_PRE00
  !-----------------------------------------------------------------------------
  implicit none
  private
  !-----------------------------------------------------------------------------
  !
  !++ Public procedure
  !
  public :: ATMOS_THERMODYN_setup

  public :: ATMOS_THERMODYN_qd
  public :: ATMOS_THERMODYN_cv
  public :: ATMOS_THERMODYN_cp
  public :: ATMOS_THERMODYN_tempre
  public :: ATMOS_THERMODYN_tempre2

  public :: ATMOS_THERMODYN_rhoe
  public :: ATMOS_THERMODYN_rhot
  public :: ATMOS_THERMODYN_temp_pres

  interface ATMOS_THERMODYN_qd
     module procedure ATMOS_THERMODYN_qd_0D
     module procedure ATMOS_THERMODYN_qd_3D
  end interface ATMOS_THERMODYN_qd

  interface ATMOS_THERMODYN_cp
     module procedure ATMOS_THERMODYN_cp_0D
     module procedure ATMOS_THERMODYN_cp_3D
  end interface ATMOS_THERMODYN_cp

  interface ATMOS_THERMODYN_cv
     module procedure ATMOS_THERMODYN_cv_0D
     module procedure ATMOS_THERMODYN_cv_3D
  end interface ATMOS_THERMODYN_cv

  interface ATMOS_THERMODYN_rhoe
     module procedure ATMOS_THERMODYN_rhoe_0D
     module procedure ATMOS_THERMODYN_rhoe_3D
  end interface ATMOS_THERMODYN_rhoe

  interface ATMOS_THERMODYN_rhot
     module procedure ATMOS_THERMODYN_rhot_0D
     module procedure ATMOS_THERMODYN_rhot_3D
  end interface ATMOS_THERMODYN_rhot

  interface ATMOS_THERMODYN_temp_pres
     module procedure ATMOS_THERMODYN_temp_pres_0D
     module procedure ATMOS_THERMODYN_temp_pres_3D
  end interface ATMOS_THERMODYN_temp_pres

  !-----------------------------------------------------------------------------
  !
  !++ included parameters
  !
  include "inc_precision.h"
  include 'inc_index.h'
  include 'inc_tracer.h'

  !-----------------------------------------------------------------------------
  !
  !++ Public parameters & variables
  !
  real(RP), public,      save :: AQ_CP(QQA) ! CP for each hydrometeors
  real(RP), public,      save :: AQ_CV(QQA) ! CV for each hydrometeors

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
  subroutine ATMOS_THERMODYN_setup
    implicit none
  
    integer :: n
    !---------------------------------------------------------------------------

    AQ_CP(I_QV) = CPvap
    AQ_CV(I_QV) = CVvap

    if( QWS /= 0 ) then
     do n = QWS, QWE
       AQ_CP(n) = CL
       AQ_CV(n) = CL
     enddo
    endif

    if( QIS /= 0 ) then
     do n = QIS, QIE
       AQ_CP(n) = CI
       AQ_CV(n) = CI
     enddo
    endif

    return
  end subroutine ATMOS_THERMODYN_setup

  !-----------------------------------------------------------------------------
  subroutine ATMOS_THERMODYN_qd_0D( &
       qdry, &
       q     )
    implicit none

    real(RP), intent(out) :: qdry  ! dry mass concentration
    real(RP), intent(in)  :: q(QA) ! mass concentration

    integer :: iqw
    !-----------------------------------------------------------------------------

    qdry = 1.0_RP
    do iqw = QQS, QQE
       qdry = qdry - q(iqw)
    enddo

    return
  end subroutine ATMOS_THERMODYN_qd_0D

  !-----------------------------------------------------------------------------
  subroutine ATMOS_THERMODYN_qd_3D( &
       qdry, &
       q     )
    implicit none

    real(RP), intent(out) :: qdry(KA,IA,JA)    ! dry mass concentration
    real(RP), intent(in)  :: q   (KA,IA,JA,QA) ! mass concentration

    integer :: k, i, j, iqw
    !-----------------------------------------------------------------------------

    do j = 1, JA
    do i = 1, IA
    do k = 1, KA

!       qdry(k,i,j) = 1.0_RP
!       do iqw = QQS, QQE
!          qdry(k,i,j) = qdry(k,i,j) - q(k,i,j,iqw)
!       enddo
       CALC_QDRY( qdry(k,i,j), q, k, i, j, iqw )

    enddo
    enddo
    enddo

    return
  end subroutine ATMOS_THERMODYN_qd_3D

  !-----------------------------------------------------------------------------
  subroutine ATMOS_THERMODYN_cp_0D( &
       CPtot, &
       q,     &
       qdry   )
    implicit none

    real(RP), intent(out) :: CPtot ! total specific heat
    real(RP), intent(in)  :: q(QA) ! mass concentration
    real(RP), intent(in)  :: qdry  ! dry mass concentration

    integer :: iqw
    !---------------------------------------------------------------------------

    CPtot = qdry * CPdry
    do iqw = QQS, QQE
       CPtot = CPtot + q(iqw) * AQ_CP(iqw)
    enddo

    return
  end subroutine ATMOS_THERMODYN_cp_0D

  !-----------------------------------------------------------------------------
  subroutine ATMOS_THERMODYN_cp_3D( &
       CPtot, &
       q,     &
       qdry   )
    implicit none

    real(RP), intent(out) :: CPtot(KA,IA,JA)    ! total specific heat
    real(RP), intent(in)  :: q    (KA,IA,JA,QA) ! mass concentration
    real(RP), intent(in)  :: qdry (KA,IA,JA)    ! dry mass concentration

    integer :: k, i, j, iqw
    !---------------------------------------------------------------------------

    do j = 1, JA
    do i = 1, IA
    do k = 1, KA

!       CPtot(k,i,j) = qdry(k,i,j) * CPdry
!       do iqw = QQS, QQE
!          CPtot(k,i,j) = CPtot(k,i,j) + q(k,i,j,iqw) * AQ_CP(iqw)
!       enddo

       CALC_CP(cptot(k,i,j), qdry(k,i,j), q, k, i, j, iqw, CPdry, AQ_CP)

    enddo
    enddo
    enddo

    return
  end subroutine ATMOS_THERMODYN_cp_3D

  !-----------------------------------------------------------------------------
  subroutine ATMOS_THERMODYN_cv_0D( &
       CVtot, &
       q,     &
       qdry   )
    implicit none

    real(RP), intent(out) :: CVtot ! total specific heat
    real(RP), intent(in)  :: q(QA) ! mass concentration
    real(RP), intent(in)  :: qdry  ! dry mass concentration

    integer :: iqw
    !---------------------------------------------------------------------------

    CVtot = qdry * CVdry
    do iqw = QQS, QQE
       CVtot = CVtot + q(iqw) * AQ_CV(iqw)
    enddo

    return
  end subroutine ATMOS_THERMODYN_cv_0D

  !-----------------------------------------------------------------------------
  subroutine ATMOS_THERMODYN_cv_3D( &
       CVtot, &
       q,     &
       qdry   )
    implicit none

    real(RP), intent(out) :: CVtot(KA,IA,JA)    ! total specific heat
    real(RP), intent(in)  :: q    (KA,IA,JA,QA) ! mass concentration
    real(RP), intent(in)  :: qdry (KA,IA,JA)    ! dry mass concentration

    integer :: k, i, j, iqw
    !---------------------------------------------------------------------------

    do j = 1, JA
    do i = 1, IA
    do k = 1, KA

!       CVtot(k,i,j) = qdry(k,i,j) * CVdry
!       do iqw = QQS, QQE
!          CVtot(k,i,j) = CVtot(k,i,j) + q(k,i,j,iqw) * AQ_CV(iqw)
!       enddo

       CALC_CV(cvtot(k,i,j), qdry(k,i,j), q, k, i, j, iqw, CVdry, AQ_CV)

    enddo
    enddo
    enddo

    return
  end subroutine ATMOS_THERMODYN_cv_3D

  !-----------------------------------------------------------------------------
  !> rho * pott -> rho * ein
  !-----------------------------------------------------------------------------
  subroutine ATMOS_THERMODYN_rhoe_0D( &
       rhoe, &
       rhot, &
       q     )
    implicit none

    real(RP), intent(out) :: rhoe  ! density * internal energy
    real(RP), intent(in)  :: rhot  ! density * potential temperature
    real(RP), intent(in)  :: q(QA) ! water concentration 

    real(RP) :: qdry ! dry concentration
    real(RP) :: pres
    real(RP) :: Rtot, CVtot, CPovCV

    integer :: iqw
    !---------------------------------------------------------------------------

    qdry  = 1.0_RP
    CVtot = 0.0_RP
    do iqw = QQS, QQE
       qdry  = qdry  - q(iqw)
       CVtot = CVtot + q(iqw) * AQ_CV(iqw)
    enddo
    CVtot = CVdry * qdry + CVtot
    Rtot  = Rdry  * qdry + Rvap * q(I_QV)

    CPovCV = ( CVtot + Rtot ) / CVtot

    pres = PRE00 * ( rhot * Rtot / PRE00 )**CPovCV

    rhoe = pres / Rtot * CVtot

    return
  end subroutine ATMOS_THERMODYN_rhoe_0D

  !-----------------------------------------------------------------------------
  !> rho * pott -> rho * ein
  !-----------------------------------------------------------------------------
  subroutine ATMOS_THERMODYN_rhoe_3D( &
       rhoe, &
       rhot, &
       q     )
    implicit none

    real(RP), intent(out) :: rhoe(KA,IA,JA)    ! density * internal energy
    real(RP), intent(in)  :: rhot(KA,IA,JA)    ! density * potential temperature
    real(RP), intent(in)  :: q   (KA,IA,JA,QA) ! water concentration 

    real(RP) :: qdry ! dry concentration
    real(RP) :: pres
    real(RP) :: Rtot, CVtot, CPovCV

    integer :: k, i, j, iqw
    !---------------------------------------------------------------------------

    do j = 1, JA
    do i = 1, IA
    do k = 1, KA
       qdry  = 1.0_RP
       CVtot = 0.0_RP
       do iqw = QQS, QQE
          qdry  = qdry  - q(k,i,j,iqw)
          CVtot = CVtot + q(k,i,j,iqw) * AQ_CV(iqw)
       enddo
       CVtot = CVdry * qdry + CVtot
       Rtot  = Rdry  * qdry + Rvap * q(k,i,j,I_QV)

       CPovCV = ( CVtot + Rtot ) / CVtot

       pres = PRE00 * ( rhot(k,i,j) * Rtot / PRE00 )**CPovCV

       rhoe(k,i,j) = pres / Rtot * CVtot
    enddo
    enddo
    enddo

    return
  end subroutine ATMOS_THERMODYN_rhoe_3D

  !-----------------------------------------------------------------------------
  !> rho * ein -> rho * pott
  !-----------------------------------------------------------------------------
  subroutine ATMOS_THERMODYN_rhot_0D( &
       rhot, &
       rhoe, &
       q     )
    implicit none

    real(RP), intent(out) :: rhot  ! density * potential temperature
    real(RP), intent(in)  :: rhoe  ! density * internal energy
    real(RP), intent(in)  :: q(QA) ! water concentration 

    real(RP) :: qdry ! dry concentration
    real(RP) :: pres
    real(RP) :: Rtot, CVtot, RovCP

    integer :: k, i, j, iqw
    !---------------------------------------------------------------------------

    qdry  = 1.0_RP
    CVtot = 0.0_RP
    do iqw = QQS, QQE
       qdry  = qdry  - q(iqw)
       CVtot = CVtot + q(iqw) * AQ_CV(iqw)
    enddo
    CVtot = CVdry * qdry + CVtot
    Rtot  = Rdry  * qdry + Rvap * q(I_QV)

    RovCP  = Rtot / ( CVtot + Rtot )

    pres = rhoe * Rtot / CVtot

    rhot = rhoe / CVtot * ( PRE00 / pres )**RovCP

    return
  end subroutine ATMOS_THERMODYN_rhot_0D

  !-----------------------------------------------------------------------------
  !> rho * ein -> rho * pott
  !-----------------------------------------------------------------------------
  subroutine ATMOS_THERMODYN_rhot_3D( &
       rhot, &
       rhoe, &
       q     )
    implicit none

    real(RP), intent(out) :: rhot(KA,IA,JA)    ! density * potential temperature
    real(RP), intent(in)  :: rhoe(KA,IA,JA)    ! density * internal energy
    real(RP), intent(in)  :: q   (KA,IA,JA,QA) ! water concentration 

    real(RP) :: qdry ! dry concentration
    real(RP) :: pres
    real(RP) :: Rtot, CVtot, RovCP

    integer :: k, i, j, iqw
    !---------------------------------------------------------------------------

    do j = 1, JA
    do i = 1, IA
    do k = 1, KA

       qdry  = 1.0_RP
       CVtot = 0.0_RP
       do iqw = QQS, QQE
          qdry  = qdry  - q(k,i,j,iqw)
          CVtot = CVtot + q(k,i,j,iqw) * AQ_CV(iqw)
       enddo
       CVtot = CVdry * qdry + CVtot
       Rtot  = Rdry  * qdry + Rvap * q(k,i,j,I_QV)

       RovCP  = Rtot / ( CVtot + Rtot )

       pres = rhoe(k,i,j) * Rtot / CVtot

       rhot(k,i,j) = rhoe(k,i,j) / CVtot * ( PRE00 / pres )**RovCP
    enddo
    enddo
    enddo

    return
  end subroutine ATMOS_THERMODYN_rhot_3D

  !-----------------------------------------------------------------------------
  subroutine ATMOS_THERMODYN_temp_pres_0D( &
       temp, &
       pres, &
       dens, &
       rhot, &
       q     )
    implicit none

    real(RP), intent(out) :: temp  ! temperature
    real(RP), intent(out) :: pres  ! pressure
    real(RP), intent(in)  :: dens  ! density
    real(RP), intent(in)  :: rhot  ! density * potential temperature
    real(RP), intent(in)  :: q(QA) ! water concentration 

    real(RP) :: qdry ! dry concentration
    real(RP) :: Rtot, CPtot, CPovCV

    integer :: iqw
    !---------------------------------------------------------------------------

    qdry  = 1.0_RP
    CPtot = 0.0_RP
    do iqw = QQS, QQE
       qdry  = qdry  - q(iqw)
       CPtot = CPtot + q(iqw) * AQ_CP(iqw)
    enddo
    CPtot = CPdry * qdry + CPtot
    Rtot  = Rdry  * qdry + Rvap * q(I_QV)

    CPovCV = CPtot / ( CPtot - Rtot )

    pres = PRE00 * ( rhot * Rtot / PRE00 )**CPovCV
    temp = pres / ( dens * Rtot )

    return
  end subroutine ATMOS_THERMODYN_temp_pres_0D

  !-----------------------------------------------------------------------------
  subroutine ATMOS_THERMODYN_temp_pres_3D( &
       temp, &
       pres, &
       dens, &
       rhot, &
       q     )
    implicit none

    real(RP), intent(out) :: temp(KA,IA,JA)    ! temperature
    real(RP), intent(out) :: pres(KA,IA,JA)    ! pressure
    real(RP), intent(in)  :: dens(KA,IA,JA)    ! density
    real(RP), intent(in)  :: rhot(KA,IA,JA)    ! density * potential temperature
    real(RP), intent(in)  :: q   (KA,IA,JA,QA) ! water concentration 

    real(RP) :: qdry ! dry concentration
    real(RP) :: Rtot, CPtot, CPovCV

    integer :: k, i, j, iqw
    !---------------------------------------------------------------------------

    do j = 1, JA
    do i = 1, IA
    do k = 1, KA
       qdry  = 1.0_RP
       CPtot = 0.0_RP
       do iqw = QQS, QQE
          qdry  = qdry  - q(k,i,j,iqw)
          CPtot = CPtot + q(k,i,j,iqw) * AQ_CP(iqw)
       enddo
       CPtot = CPdry * qdry + CPtot
       Rtot  = Rdry  * qdry + Rvap * q(k,i,j,I_QV)

       CPovCV = CPtot / ( CPtot - Rtot )

       pres(k,i,j) = PRE00 * ( rhot(k,i,j) * Rtot / PRE00 )**CPovCV
       temp(k,i,j) = pres(k,i,j) / ( dens(k,i,j) * Rtot )
    enddo
    enddo
    enddo

    return
  end subroutine ATMOS_THERMODYN_temp_pres_3D

  !-----------------------------------------------------------------------------
  subroutine ATMOS_THERMODYN_tempre( &
      temp, pres,         &
      Ein,  dens, qdry, q )
    implicit none

    real(RP), intent(out) :: temp(KA,IA,JA)    ! temperature
    real(RP), intent(out) :: pres(KA,IA,JA)    ! pressure
    real(RP), intent(in)  :: Ein (KA,IA,JA)    ! internal energy
    real(RP), intent(in)  :: dens(KA,IA,JA)    ! density
    real(RP), intent(in)  :: qdry(KA,IA,JA)    ! dry concentration
    real(RP), intent(in)  :: q   (KA,IA,JA,QA) ! water concentration 

    real(RP) :: cv, Rmoist

    integer :: i, j, k, iqw
    !---------------------------------------------------------------------------

    do j = 1, JA
    do i = 1, IA
    do k = 1, KA

       CALC_CV(cv, qdry(k,i,j), q, k, i, j, iqw, CVdry, AQ_CV)
       CALC_R(Rmoist, q(k,i,j,I_QV), qdry(k,i,j), Rdry, Rvap)

       temp(k,i,j) = Ein(k,i,j) / cv

       pres(k,i,j) = dens(k,i,j) * Rmoist * temp(k,i,j)

    enddo
    enddo
    enddo

    return
  end subroutine ATMOS_THERMODYN_tempre

  !-----------------------------------------------------------------------------
  subroutine ATMOS_THERMODYN_tempre2( &
      temp, pres,         &
      dens, pott, qdry, q )
    use mod_const, only : &
       CONST_RovCP
    implicit none

    real(RP), intent(out) :: temp(KA,IA,JA)    ! temperature
    real(RP), intent(out) :: pres(KA,IA,JA)    ! pressure
    real(RP), intent(in)  :: dens(KA,IA,JA)    ! density
    real(RP), intent(in)  :: pott(KA,IA,JA)    ! potential temperature
    real(RP), intent(in)  :: qdry(KA,IA,JA)    ! dry concentration
    real(RP), intent(in)  :: q   (KA,IA,JA,QA) ! water concentration 

    real(RP) :: Rmoist, cp

    integer :: i, j, k, iqw
    !---------------------------------------------------------------------------

    do j = 1, JA
    do i = 1, IA
    do k = 1, KA

       CALC_CP(cp, qdry(k,i,j), q, k, i, j, iqw, CPdry, AQ_CP)
       CALC_R(Rmoist, q(k,i,j,I_QV), qdry(k,i,j), Rdry, Rvap)
       CALC_PRE(pres(k,i,j), dens(k,i,j), pott(k,i,j), Rmoist, cp, PRE00)

       temp(k,i,j) = pres(k,i,j) / ( dens(k,i,j) * Rmoist )

    enddo
    enddo
    enddo

    return
  end subroutine ATMOS_THERMODYN_tempre2

end module mod_atmos_thermodyn
