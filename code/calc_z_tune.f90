!+
! Subroutine calc_z_tune (RING)
!
! Subroutine to calculate the synchrotron tune from the full 6X6 1 turn matrix
!
! Modules Needed:
!   use bmad_struct
!   use bmad_interface
!
! Input:
!    RING  -- Ring_struct: Ring
!
! Output:
!    RING : ring%z%tune  synchrotron tune (radians)
!-


subroutine calc_z_tune ( ring)

  use bmad_struct
  use bmad_interface
  use nrtype
  use nr

  implicit none

  type (ring_struct) ring

  real a(6,6), wr(6), wi(6), cos_z

  integer i
!

  call one_turn_matrix (ring, a)
  cos_z = (a(5,5) + a(6,6)) / (2 * (a(5,5)*a(6,6) - a(5,6)*a(6,5)))

  call balanc(a)
  call elmhes(a)
  call hqr(a,wr,wi)

! we need to find which eigen-value is closest to the z_tune

  i = minloc(abs(wr-cos_z), 1)
  ring%z%tune = -abs(atan2(wi(i),wr(i)))

end subroutine
