program abs_time_test

use bmad
use autoscale_mod

implicit none

type (lat_struct) lat
type (coord_struct), allocatable :: orb1(:), orb2(:)

logical err_flag

!

call bmad_parser ('abs_time_test.bmad', lat)

call reallocate_coord (orb1, lat%n_ele_max)
call init_coord (orb1(0), lat%beam_start, lat%ele(0), downstream_end$)
call track_all (lat, orb1)

lat%absolute_time_tracking = .true.
!!call autoscale_phase_and_amp (lat%ele(2), lat%param, err_flag)
call lattice_bookkeeper (lat)

call reallocate_coord (orb2, lat%n_ele_max)
call init_coord (orb2(0), lat%beam_start, lat%ele(0), downstream_end$)
call track_all (lat, orb2)

!

open (1, file = 'output.now')

write (1, '(a, es22.12)') '"vec(1)" REL  1E-10', orb1(2)%vec(1)
write (1, '(a, es22.12)') '"vec(2)" REL  1E-10', orb1(2)%vec(2)
write (1, '(a, es22.12)') '"vec(3)" REL  1E-10', orb1(2)%vec(3)
write (1, '(a, es22.12)') '"vec(4)" REL  1E-10', orb1(2)%vec(4)
write (1, '(a, es22.12)') '"vec(5)" REL  1E-10', orb1(2)%vec(5)
write (1, '(a, es22.12)') '"vec(6)" REL  1E-10', orb1(2)%vec(6)
write (1, '(a, es22.12)') '"t"      REL  1E-10', orb1(2)%t

write (1, *)
write (1, '(a, es22.12)') '"dvec(1)" ABS  2E-19', orb2(2)%vec(1) - orb1(2)%vec(1)
write (1, '(a, es22.12)') '"dvec(2)" ABS  1E-19', orb2(2)%vec(2) - orb1(2)%vec(2)
write (1, '(a, es22.12)') '"dvec(3)" ABS  2E-19', orb2(2)%vec(3) - orb1(2)%vec(3)
write (1, '(a, es22.12)') '"dvec(4)" ABS  1E-19', orb2(2)%vec(4) - orb1(2)%vec(4)
write (1, '(a, es22.12)') '"dvec(5)" ABS  2E-15', orb2(2)%vec(5) - orb1(2)%vec(5)
write (1, '(a, es22.12)') '"dvec(6)" ABS  5E-15', orb2(2)%vec(6) - orb1(2)%vec(6)
write (1, '(a, es22.12)') '"c*dt"    ABS  1E-15', c_light * (orb2(2)%t - orb1(2)%t)

close (1)


end program 
