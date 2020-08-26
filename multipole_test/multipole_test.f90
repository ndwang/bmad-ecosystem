program multipole_test

use multipole_mod

implicit none

type (lat_struct), target :: lat
type (ele_struct), pointer :: ele, slave

real(rp) am1(0:n_pole_maxx), am2(0:n_pole_maxx), bm1(0:n_pole_maxx), bm2(0:n_pole_maxx)
real(rp) ae1(0:n_pole_maxx), ae2(0:n_pole_maxx), be1(0:n_pole_maxx), be2(0:n_pole_maxx)
real(rp) km1(0:n_pole_maxx), tm1(0:n_pole_maxx), km2(0:n_pole_maxx), tm2(0:n_pole_maxx)
real(rp) ke1(0:n_pole_maxx), te1(0:n_pole_maxx), ke2(0:n_pole_maxx), te2(0:n_pole_maxx)
real(rp) dtm, dte, fn, tilt

integer i, ie, iu, ik, ix_pole_max, include_kicks
integer, parameter :: inc_kick(3) = [no$, include_kicks$, include_kicks_except_k1$]

logical use_ele_tilt
character(3) str

! Init

open (1, file = 'output.now')
call bmad_parser ('multipole.bmad', lat)
bmad_com%auto_bookkeeper = .false.

!

do ie = 1, lat%n_ele_max
  ele => lat%ele(ie)

  do iu = 1, 2
  do ik = 1, 3
    use_ele_tilt = (iu == 2)
    include_kicks = inc_kick(ik)
    str = int_str(iu) // int_str(ik) // '-'

    if (allocated(ele%multipole_cache)) deallocate(ele%multipole_cache)

    call multipole_ele_to_ab (ele, use_ele_tilt, ix_pole_max, am1, bm1, magnetic$, include_kicks)
    call multipole_ele_to_ab (ele, use_ele_tilt, ix_pole_max, ae1, be1, electric$, include_kicks)

    call multipole_ele_to_ab (ele, use_ele_tilt, ix_pole_max, am2, bm2, magnetic$, include_kicks)
    call multipole_ele_to_ab (ele, use_ele_tilt, ix_pole_max, ae2, be2, electric$, include_kicks)

    write (1, '(a, 6es12.4, i3)') '"MULT-' // str // trim(ele%name) // '"   ABS 0', am1(1:5:2), bm1(2:6:2), ix_pole_max
    write (1, '(a, 6es12.4)') '"DEL-' // str // trim(ele%name) // '"   ABS 0', maxval(abs(am1-am2)), maxval(abs(bm1-bm2)), &
                                                                       maxval(abs(ae1-ae2)), maxval(abs(be1-be2))

    call multipole_ele_to_ab (ele, .not. use_ele_tilt, ix_pole_max, am2, bm2, magnetic$, include_kicks)
    call multipole_ele_to_ab (ele, .not. use_ele_tilt, ix_pole_max, ae2, be2, electric$, include_kicks)
    
    call multipole_ab_to_kt (am1, bm1, km1, tm1)
    call multipole_ab_to_kt (am2, bm2, km2, tm2)
    call multipole_ab_to_kt (ae1, be1, ke1, te1)
    call multipole_ab_to_kt (ae2, be2, ke2, te2)

    dtm = 0
    dte = 0
    do i = 0, n_pole_maxx
      fn = 2.0_rp * real(i+1, rp)
      call flip_it(i, km1(i), tm1(i));  call flip_it(i, km2(i), tm2(i))
      call flip_it(i, ke1(i), te1(i));  call flip_it(i, ke2(i), te2(i))
      if (ele%key == sbend$) then
        tilt = ele%value(ref_tilt$) / twopi
      else
        tilt = ele%value(tilt$) / twopi
      endif
      if (use_ele_tilt) then
        if (km1(i) /= 0) dtm = max(dtm, modulo2(tm1(i)-tm2(i)-tilt, 1.0_rp/fn))
        if (ke1(i) /= 0) dte = max(dte, modulo2(te1(i)-te2(i)-tilt, 1.0_rp/fn))
      else
        if (km1(i) /= 0) dtm = max(dtm, modulo2(tm1(i)-tm2(i)+tilt, 1.0_rp/fn))
        if (ke1(i) /= 0) dte = max(dte, modulo2(te1(i)-te2(i)+tilt, 1.0_rp/fn))
      endif
    enddo

    write (1, '(a, 6es12.4)') '"KT-' // str // trim(ele%name) // '"   ABS 1E-12', maxval(abs(km1-km2)), maxval(abs(ke1-ke2)), dtm, dte

    !

    slave => pointer_to_slave(ele, 1)
    if (.not. associated(slave)) cycle

    call multipole_ele_to_ab (slave, use_ele_tilt, ix_pole_max, am2, bm2, magnetic$, include_kicks)
    call multipole_ele_to_ab (slave, use_ele_tilt, ix_pole_max, ae2, be2, electric$, include_kicks)

    fn = slave%value(l$) / ele%value(l$)
    write (1, '(a, 4es12.4)') '"SLAVE-' // str // trim(ele%name) // '"  ABS 1E-14', maxval(abs(am2-am1*fn)), maxval(abs(bm2-bm1*fn)), &
                                                                          maxval(abs(ae2-ae1)), maxval(abs(be2-be1))


  enddo
  enddo
enddo

! And close

close (1)

!-------------------------------------------------
contains

subroutine flip_it (n, k, t)
real(rp) k, t, fn
integer n
!
t = t / twopi
if (k < 0) then
  fn = 2.0_rp * real(n+1, rp)
  k = -k
  t = modulo2(t-1.0_rp/fn, 1.0_rp/fn)
endif

end subroutine flip_it

end program
