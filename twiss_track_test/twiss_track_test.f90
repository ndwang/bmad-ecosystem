program twiss_track_test

use bmad
use z_tune_mod

implicit none

type (lat_struct), target :: lat, lat2
type (ele_struct) ele, ele0, ele1
type (coord_struct), allocatable :: orb(:), orb2(:)
type (coord_struct) orb0, orb1
type (normal_modes_struct) mode
type (rad_int_all_ele_struct) rad_int, rad_int2

real(rp) chrom_x, chrom_y, delta_e
real(rp) m6(6,6)

integer i, j, n, n_lines, version, ix_cache, n_track

character(40) lattice
character(200) lat_file
character(200), allocatable :: lines(:)

!---------------------------------------------------------

open (2, file = 'output.now', recl = 200)

bmad_com%auto_bookkeeper = .false.

lat_file = "bmad_L9A18A000-_MOVEREC.lat"
call bmad_parser (lat_file, lat2)
call write_digested_bmad_file ('digested.file', lat2, 0)
call read_digested_bmad_file ('digested.file', lat2, version)
lat = lat2

allocate (orb(0:lat%n_ele_max))     

bmad_com%rel_tol_tracking = 1e-7
bmad_com%abs_tol_tracking = 1e-10

orb(0)%vec = 0
call twiss_at_start (lat)
call closed_orbit_calc (lat, orb, 6)
call lat_make_mat6 (lat, -1, orb)
call twiss_at_start (lat)
call twiss_propagate_all (lat)

!

allocate (lat%ele(96)%descrip)
lat%ele(96)%descrip = 'First'

ele = lat%ele(96)
ele%descrip = 'Second'

write (2, '(3a)') '"First Descrip"      STR  "', trim(lat%ele(96)%descrip), '"'
write (2, '(3a)') '"Second Descrip"     STR  "', trim(ele%descrip), '"'

delta_e = 0.0
call chrom_calc (lat, delta_e, chrom_x, chrom_y)

!

call mat_make_unit (m6)
open (1, file = 'twiss.out')
do n = 1, lat%n_ele_track
  write (1, *) '!------------------------------------'
  write (1, *) 'Index:', n
  call type2_ele (lat%ele(n), lines, n_lines, .false., 0, .false., 0, .false., lat)  
  do i = 1, n_lines
    write (1, '(a)') lines(i)
  enddo
  m6 = matmul (lat%ele(n)%mat6, m6)
  do i = 1, 6
    write (1, '(6f11.5)') (m6(i, j), j = 1, 6)
  enddo
enddo

ix_cache = 0
call radiation_integrals (lat, orb, mode, ix_cache, 0, rad_int2)
call ri_out('rad_int_no_wig_cache.dat', rad_int2)

call radiation_integrals (lat, orb, mode, rad_int_by_ele = rad_int)
call ri_out('rad_int_no_wig_no_cache.dat', rad_int)

call ri_diff

!

ele0 = lat%ele(0)
ele1 = lat%ele(lat%n_ele_track)
orb0 = orb(0)
orb1 = orb(lat%n_ele_track)

call data_out (orb1%vec(1) - orb0%vec(1), 1.0d-7, 'Dif:Orb(1)')
call data_out (orb1%vec(2) - orb0%vec(2), 1.0d-7, 'Dif:Orb(2)')
call data_out (orb1%vec(3) - orb0%vec(3), 1.0d-7, 'Dif:Orb(3)')
call data_out (orb1%vec(4) - orb0%vec(4), 1.0d-7, 'Dif:Orb(4)')
call data_out (orb1%vec(5) - orb0%vec(5), 1.0d-7, 'Dif:Orb(5)')
call data_out (orb1%vec(6) - orb0%vec(6), 1.0d-7, 'Dif:Orb(6)')
call data_out (ele1%a%beta - ele0%a%beta, 1.0d-7, 'Dif:Beta_X')
call data_out (ele1%b%beta - ele0%b%beta, 1.0d-7, 'Dif:Beta_Y')
call data_out (ele1%a%alpha - ele0%a%alpha, 1.0d-7, 'Dif:Alpha_X')
call data_out (ele1%b%alpha - ele0%b%alpha, 1.0d-7, 'Dif:Alpha_Y')
call data_out (ele1%a%eta - ele0%a%eta, 1.0d-7, 'Dif:Eta_X ')
call data_out (ele1%b%eta - ele0%b%eta, 1.0d-7, 'Dif:Eta_Y ')
call data_out (ele1%a%etap - ele0%a%etap, 1.0d-6, 'Dif:Etap_X')
call data_out (ele1%b%etap - ele0%b%etap, 1.0d-6, 'Dif:Etap_Y')

!----------------------------------------------------
! Error check.

!! print *
!! print *, 'Non-wiggler lattice check...'

ele = lat%ele(96)

call data_out (ele%a%beta,           1.0D-06, 'Lat1:Beta_a')
call data_out (ele%a%alpha,          1.0D-06, 'Lat1:Alpha_a')
call data_out (ele%a%eta,            1.0D-06, 'Lat1:Eta_a')
call data_out (ele%a%etap,           1.0D-06, 'Lat1:Etap_a')
call data_out (ele%x%eta,            1.0D-06, 'Lat1:Eta_x')
call data_out (ele%x%etap,           1.0D-06, 'Lat1:Etap_x')
call data_out (ele%a%phi,            1.0D-06, 'Lat1:Phi_a')
call data_out (ele%b%beta,           1.0D-06, 'Lat1:Beta_b')
call data_out (ele%b%alpha,          1.0D-06, 'Lat1:Alpha_y')
call data_out (ele%b%eta,            1.0D-06, 'Lat1:Eta_b')
call data_out (ele%b%etap,           1.0D-06, 'Lat1:Etap_y')
call data_out (ele%y%eta,            1.0D-06, 'Lat1:Eta_y')
call data_out (ele%y%etap,           1.0D-06, 'Lat1:Etap_y')
call data_out (ele%b%phi,            1.0D-06, 'Lat1:Phi_y')
call data_out (orb(96)%vec(1),       1.0D-10, 'Lat1:Orb X')
call data_out (orb(96)%vec(2),       1.0D-10, 'Lat1:Orb P_X')
call data_out (orb(96)%vec(3),       1.0D-10, 'Lat1:Orb Y')
call data_out (orb(96)%vec(4),       1.0D-10, 'Lat1:Orb P_Y')
call data_out (orb(96)%vec(5),       1.0D-10, 'Lat1:Orb Z')
call data_out (orb(96)%vec(6),       1.0D-10, 'Lat1:Orb P_Z')
call data_out (chrom_x,              1.0D-05, 'Lat1:Chrom_x')
call data_out (chrom_y,              1.0D-05, 'Lat1:Chrom_y')
call data_out (mode%synch_int(1),    1.0D-06, 'Lat1:Synch_int(1)')
call data_out (mode%synch_int(2),    1.0D-06, 'Lat1:Synch_int(2)')
call data_out (mode%synch_int(3),    1.0D-06, 'Lat1:Synch_int(3)')
call data_out (mode%sige_e,          1.0D-10, 'Lat1:Sige_e')
call data_out (mode%sig_z,           1.0D-08, 'Lat1:Sig_z')
call data_out (mode%e_loss,          1.0D-01, 'Lat1:E_loss')
call data_out (mode%a%emittance,     1.0D-12, 'Lat1:A%Emittance')
call data_out (mode%b%emittance,     1.0D-14, 'Lat1:B%Emittance')
call data_out (mode%z%emittance,     1.0D-11, 'Lat1:Z%Emittance')
call data_out (mode%a%synch_int(4),  1.0D-07, 'Lat1:A%Synch_int(4)')
call data_out (mode%a%synch_int(5),  1.0D-07, 'Lat1:A%Synch_int(5)')
call data_out (mode%b%synch_int(4),  1.0D-07, 'Lat1:B%Synch_int(4)')
call data_out (mode%b%synch_int(5),  1.0D-11, 'Lat1:B%Synch_int(5)')
call data_out (mode%z%synch_int(4),  1.0D-08, 'Lat1:Z%Synch_int(4)')
 
call set_z_tune (lat, -0.05 * twopi)

!--------------------------------

write (2, *)

call bmad_parser ('bmad_12wig_20050626.lat', lat)
call set_on_off (rfcavity$, lat, off$)

orb(0)%vec = 0
call twiss_at_start (lat)
call closed_orbit_calc (lat, orb, 4)
call track_all (lat, orb)
call lat_make_mat6 (lat, -1, orb)
call twiss_at_start (lat)
call twiss_propagate_all (lat)

ix_cache = 0
call set_on_off (rfcavity$, lat, on$)
call radiation_integrals (lat, orb, mode, ix_cache, 0, rad_int2)
call ri_out('rad_int_wig_cache.dat', rad_int2)

call radiation_integrals (lat, orb, mode, rad_int_by_ele = rad_int)
call ri_out('rad_int_wig_no_cache.dat', rad_int)

call ri_diff

call chrom_calc (lat, delta_e, chrom_x, chrom_y)

ele = lat%ele(96)
 
call data_out (ele%a%beta,           1.0D-05, 'Lat2:Beta_a')
call data_out (ele%a%alpha,          1.0D-05, 'Lat2:Alpha_a')
call data_out (ele%a%eta,            1.0D-05, 'Lat2:Eta_a')
call data_out (ele%a%etap,           1.0D-05, 'Lat2:Etap_a')
call data_out (ele%x%eta,            1.0D-05, 'Lat2:Eta_x')
call data_out (ele%x%etap,           1.0D-05, 'Lat2:Etap_x')
call data_out (ele%a%phi,            1.0D-05, 'Lat2:Phi_a')
call data_out (ele%b%beta,           1.0D-05, 'Lat2:Beta_b')
call data_out (ele%b%alpha,          1.0D-05, 'Lat2:Alpha_b')
call data_out (ele%b%eta,            1.0D-05, 'Lat2:Eta_b')
call data_out (ele%b%etap,           1.0D-05, 'Lat2:Etap_b')
call data_out (ele%y%eta,            1.0D-05, 'Lat2:Eta_y')
call data_out (ele%y%etap,           1.0D-05, 'Lat2:Etap_y')
call data_out (ele%b%phi,            1.0D-05, 'Lat2:Phi_b')
call data_out (orb(96)%vec(1),       1.0D-07, 'Lat2:Orb X')
call data_out (orb(96)%vec(2),       1.0D-07, 'Lat2:Orb P_X')
call data_out (orb(96)%vec(3),       1.0D-07, 'Lat2:Orb Y')
call data_out (orb(96)%vec(4),       1.0D-07, 'Lat2:Orb P_Y')
call data_out (orb(96)%vec(5),       1.0D-07, 'Lat2:Orb Z')
call data_out (orb(96)%vec(6),       1.0D-07, 'Lat2:Orb P_Z')
call data_out (chrom_x,              1.0D-04, 'Lat2:Chrom_x')
call data_out (chrom_y,              1.0D-04, 'Lat2:Chrom_y')
call data_out (mode%synch_int(1),    1.0D-06, 'Lat2:Synch_int(1)')
call data_out (mode%synch_int(2),    1.0D-06, 'Lat2:Synch_int(2)')
call data_out (mode%synch_int(3),    1.0D-06, 'Lat2:Synch_int(3)')
call data_out (mode%sige_e,          1.0D-10, 'Lat2:Sige_e')
call data_out (mode%sig_z,           1.0D-08, 'Lat2:Sig_z')
call data_out (mode%e_loss,          1.0D-01, 'Lat2:E_loss')
call data_out (mode%a%emittance,     1.0D-12, 'Lat2:A%Emittance')
call data_out (mode%b%emittance,     1.0D-14, 'Lat2:B%Emittance')
call data_out (mode%z%emittance,     1.0D-11, 'Lat2:Z%Emittance')
call data_out (mode%a%synch_int(4),  1.0D-07, 'Lat2:A%Synch_int(4)')
call data_out (mode%a%synch_int(5),  1.0D-07, 'Lat2:A%Synch_int(5)')
call data_out (mode%b%synch_int(4),  1.0D-07, 'Lat2:B%Synch_int(4)')
call data_out (mode%b%synch_int(5),  1.0D-11, 'Lat2:B%Synch_int(5)')
call data_out (mode%z%synch_int(4),  1.0D-08, 'Lat2:Z%Synch_int(4)')

write (2, '(a, l1, a)') '"Lat2:Lat"      STR  "', associated(lat2%ele(100)%branch, lat2%branch(0)), '"'

!--------------------------------------------------------------------
! Reverse

call set_on_off (rfcavity$, lat, off$)
call lat_reverse (lat, lat2)
call closed_orbit_calc (lat2, orb2, 4)
call lat_make_mat6(lat2, -1, orb2)
call twiss_at_start (lat2)
call twiss_propagate_all (lat2)

n_track = lat%n_ele_track
write (2, *)
call data_out (orb2(0)%vec(1)-orb(0)%vec(1), 1d-8, 'Reverse:dvec(1)')
call data_out (orb2(0)%vec(2)+orb(0)%vec(2), 1d-8, 'Reverse:dvec(2)')
call data_out (orb2(0)%vec(3)-orb(0)%vec(3), 1d-8, 'Reverse:dvec(3)')
call data_out (orb2(0)%vec(4)+orb(0)%vec(4), 1d-8, 'Reverse:dvec(4)')

write (2, *)
call data_out (lat2%ele(0)%a%beta - lat%ele(0)%a%beta, 2d-5, 'Reverse:dbeta_a')
call data_out (lat2%ele(0)%a%alpha + lat%ele(0)%a%alpha, 1d-4, 'Reverse:dalpha_a')
call data_out (lat2%ele(n_track)%a%phi - lat%ele(n_track)%a%phi, 2d-5, 'Reverse:dphi_a')
call data_out (lat2%ele(0)%a%eta - lat%ele(0)%a%eta, 1d-5, 'Reverse:deta_a')
call data_out (lat2%ele(0)%a%etap + lat%ele(0)%a%etap, 1d-5, 'Reverse:detap_a')

write (2, *)
call data_out (lat2%ele(0)%b%beta - lat%ele(0)%b%beta, 1d-6, 'Reverse:dbeta_b')
call data_out (lat2%ele(0)%b%alpha + lat%ele(0)%b%alpha, 1d-6, 'Reverse:dalpha_b')
call data_out (lat2%ele(n_track)%b%phi - lat%ele(n_track)%b%phi, 1d-5, 'Reverse:dphi_b')
call data_out (lat2%ele(0)%b%eta - lat%ele(0)%b%eta, 1d-8, 'Reverse:deta_b')
call data_out (lat2%ele(0)%b%etap + lat%ele(0)%b%etap, 1d-6, 'Reverse:detap_b')

write (2, *)
call data_out (lat2%ele(n_track)%floor%x, 1d-8, 'Reverse:floor%x')
call data_out (lat2%ele(n_track)%floor%z, 1d-8, 'Reverse:floor%z')
call data_out (lat2%ele(n_track)%floor%theta, 1d-8, 'Reverse:floor%theta')
call data_out (lat2%ele(n_track)%s -lat%ele(n_track)%s, 1d-6, 'Reverse:s')
call data_out (lat2%ele(n_track)%ref_time-lat%ele(n_track)%ref_time, 1d-14, 'Reverse:ref_time')
write (2, '(a, l1, a)') '"Reverse:Lat"      STR  "', associated(lat2%ele(100)%branch, lat2%branch(0)), '"'


!--------------------------------------------------------------------
contains

subroutine data_out (now, err_tol, what)

implicit none

real(rp) now, theory, err_tol
integer ix
character(*) what
character(200) line

!

write (2, '(3a, t30, a, es10.1, es25.14)') '"', what, '" ', 'ABS', err_tol, now

end subroutine

!--------------------------------------------------------------------
! contains

subroutine ri_out (file_name, rad_int)

type (rad_int_all_ele_struct) rad_int
character(*) file_name
integer i

!

open (1, file = file_name)

write (1, '(a)') '             I1          I2          I3          I4a         I4b         I5a         I5b'
do i = 1, lat%n_ele_track
  if (all([rad_int%ele%i1, rad_int%ele%i2, rad_int%ele%i3, &
                        rad_int%ele(i)%i4a, rad_int%ele(i)%i4b, rad_int%ele(i)%i5a, rad_int%ele(i)%i5b] == 0)) cycle
  write (1, '(i4, 7es12.3)') i, rad_int%ele(i)%i1, rad_int%ele(i)%i2, rad_int%ele(i)%i3, &
                        rad_int%ele(i)%i4a, rad_int%ele(i)%i4b, rad_int%ele(i)%i5a, rad_int%ele(i)%i5b
enddo
write (1, '(a)') '             I1          I2          I3          I4a         I4b         I5a         I5b'

close (1)

end subroutine

!--------------------------------------------------------------------
! contains

subroutine ri_diff

return
print *, 'Max radiation integral diffs between caching and no caching:'
call ri_diff1('I1 ', rad_int%ele%i1,  rad_int2%ele%i1)
call ri_diff1('I2 ', rad_int%ele%i2,  rad_int2%ele%i2)
call ri_diff1('I3 ', rad_int%ele%i3,  rad_int2%ele%i3)
call ri_diff1('I4a', rad_int%ele%i4a, rad_int2%ele%i4a)
call ri_diff1('I4b', rad_int%ele%i4b, rad_int2%ele%i4b)
call ri_diff1('I5a', rad_int%ele%i5a, rad_int2%ele%i5a)
call ri_diff1('I5b', rad_int%ele%i5b, rad_int2%ele%i5b)

end subroutine

!--------------------------------------------------------------------
! contains

subroutine ri_diff1 (str, vec1, vec2)

character(*) str
real(rp) vec1(0:), vec2(0:), mdiff, mrdiff
real(rp) dvec, vmax
integer i, im, imr

!

vmax = maxval(abs(vec1))
mdiff = 0
mrdiff = 0

do i = 0, ubound(vec1, 1)
  if (vec1(i) == 0 .and. vec2(i) == 0) cycle
  if (abs(vec1(i)) < 1e-10*vmax .and. abs(vec2(i)) < 1e-10*vmax) cycle

  dvec = abs(vec1(i) - vec2(i))
  if (dvec > mdiff) then
    mdiff = dvec
    im = i
  endif

  dvec = 2 * dvec / (abs(vec1(i)) + abs(vec2(i)))
  if (dvec > mrdiff) then
    mrdiff = dvec
    imr = i
  endif
enddo

print '(a, i6, es12.3, i6, f8.4)', str, im, mdiff/vmax, imr, mrdiff

end subroutine

end program


