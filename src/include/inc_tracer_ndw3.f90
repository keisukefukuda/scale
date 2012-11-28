
  !-----------------------------------------------------------------------------
  !
  !++ scale3 grid parameters
  !
  !-----------------------------------------------------------------------------
  integer, private, parameter :: QA = 5

  integer, private, parameter :: I_QV =  1
  integer, private, parameter :: I_QC =  2
  integer, private, parameter :: I_QR =  3
  integer, private, parameter :: I_NC =  4
  integer, private, parameter :: I_NR =  5

  integer, private, parameter :: QQA =  3 ! mass tracer (water)
  integer, private, parameter :: QQS =  1 ! start index for mass tracer
  integer, private, parameter :: QQE =  3 ! end   index for mass tracer

  integer, private, parameter :: QWS =  2 ! start index for water tracer
  integer, private, parameter :: QWE =  3 ! end   index for water tracer
  integer, private, parameter :: QIS =  0 ! start index for ice tracer
  integer, private, parameter :: QIE =  0 ! end   index for ice tracer

  character(len=16), private, save :: AQ_NAME(QA)
  character(len=64), private, save :: AQ_DESC(QA)
  character(len=16), private, save :: AQ_UNIT(QA)

  data AQ_NAME / 'QV', &
                 'QC', &
                 'QR', &
                 'NC', &
                 'NR'  /

  data AQ_DESC / 'Water Vapor mixing ratio',   &
                 'Cloud Water mixing ratio',   &
                 'Rain Water mixing ratio',    &
                 'Cloud Water Number Density', &
                 'Rain Water Number Density'   /

  data AQ_UNIT / 'kg/kg',  &
                 'kg/kg',  &
                 'kg/kg',  &
                 'num/kg', &
                 'num/kg'  /