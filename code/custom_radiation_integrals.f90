!+
! Subroutine custom_radiation_integrals
!
! Dummy routine for custom elements. Will generate an error if called.
!-

subroutine custom_radiation_integrals

  print *, 'ERROR IN CUSTOM_RADIATION_INTEGRALS: THIS DUMMY ROUTINE SHOULD NOT' 
  print *, '      HAVE BEEN CALLED IN THE FIRST PLACE.'
  call err_exit

end subroutine
