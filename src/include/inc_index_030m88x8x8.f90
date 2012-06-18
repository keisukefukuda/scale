
  !-----------------------------------------------------------------------------
  !
  !++ scale3 grid parameters
  !
  !-----------------------------------------------------------------------------
  integer, private, parameter :: KHALO =   2 ! # of halo cells: z
  integer, private, parameter :: IHALO =   2 ! # of halo cells: x
  integer, private, parameter :: JHALO =   2 ! # of halo cells: y

  real(8), private, parameter :: DXYZ  =  30 ! length in the main region [m]: x,y,z

  real(8), private, parameter :: BUFFER_DZ = 2.0D3 ! thickness of buffer region [m]: z
  real(8), private, parameter :: BUFFER_DX = 0.0D0 ! thickness of buffer region [m]: x
  real(8), private, parameter :: BUFFER_DY = 0.0D0 ! thickness of buffer region [m]: y
  real(8), private, parameter :: BUFFFACT  = 1.1D0 ! strech factor for dx/dy/dz of buffer region

  integer, private, parameter :: KMAX  =  88 ! # of computational cells: z
  integer, private, parameter :: IMAX  =   8 ! # of computational cells: x
  integer, private, parameter :: JMAX  =   8 ! # of computational cells: y

  integer, private, parameter :: KA    =  92 ! # of z whole cells (local, with HALO)
  integer, private, parameter :: IA    =  12 ! # of x whole cells (local, with HALO)
  integer, private, parameter :: JA    =  12 ! # of y whole cells (local, with HALO)

  integer, private, parameter :: KS    =   3 ! start point of inner domain: z, local
  integer, private, parameter :: KE    =  90 ! end   point of inner domain: z, local
  integer, private, parameter :: IS    =   3 ! start point of inner domain: x, local
  integer, private, parameter :: IE    =  10 ! end   point of inner domain: x, local
  integer, private, parameter :: JS    =   3 ! start point of inner domain: y, local
  integer, private, parameter :: JE    =  10 ! end   point of inner domain: y, local

  integer, private, parameter :: IJA   =   64 ! # merged inner region(tentative usage)
  integer, private, parameter :: IJS   =    1 !
  integer, private, parameter :: IJE   =   64 !

  integer, private, parameter :: IBLOCK = 8 !
  integer, private, parameter :: JBLOCK = 8 !