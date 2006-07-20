!+
! Subroutine tao_show_cmd (what, stuff)
!
! Show information on variable, parameters, elements, etc.
!
! Input:
!   what  -- Character(*): What to show.
!   stuff -- Character(*): ParticularStuff to show.
!-

module tao_show_mod

contains

!--------------------------------------------------------------------

recursive subroutine tao_show_cmd (what, stuff)

use tao_mod
use tao_top10_mod
use tao_command_mod, only: tao_cmd_split

implicit none

type (tao_universe_struct), pointer :: u
type (tao_d1_data_struct), pointer :: d1_ptr
type (tao_d2_data_struct), pointer :: d2_ptr
type (tao_data_struct), pointer :: d_ptr
type (tao_v1_var_struct), pointer :: v1_ptr
type (tao_var_struct), pointer :: v_ptr
type (tao_var_array_struct), allocatable, save, target :: v_array(:)
type (tao_plot_array_struct), allocatable, save :: plot(:)
type (tao_graph_array_struct), allocatable, save :: graph(:)
type (tao_curve_array_struct), allocatable, save :: curve(:)
type (tao_plot_struct), pointer :: p
type (tao_graph_struct), pointer :: g
type (tao_curve_struct), pointer :: c
type (tao_plot_region_struct), pointer :: region
type (tao_data_array_struct), allocatable, save :: d_array(:)

type (lr_wake_struct), pointer :: lr
type (ele_struct), pointer :: ele
type (coord_struct) orb
type (ele_struct) ele3

real(rp) f_phi, s_pos, l_lat
real(rp) :: delta_e = 0

character(*) :: what, stuff
character(24) :: var_name
character(24)  :: plane, imt, lmt, amt, rmt, irmt, iimt
character(80) :: word(2), fmt, fmt2, fmt3
character(8) :: r_name = "tao_show_cmd"
character(24) show_name, show2_name
character(100), pointer :: ptr_lines(:)
character(100) file_name
character(40) ele_name, name, sub_name
character(60) nam

character(16) :: show_names(14) = (/ &
   'data        ', 'var         ', 'global      ', 'alias       ', 'top10       ', &
   'optimizer   ', 'ele         ', 'lattice     ', 'constraints ', 'plot        ', &
   'write       ', 'hom         ', 'opt_vars    ', 'universe    ' /)

character(200), allocatable, save :: lines(:)
character(200) line1, line2, line3
character(9) angle

integer :: data_number, ix_plane
integer nl, loc, ixl, iu, nc, n_size, ix_u, ios
integer ix, ix1, ix2, ix_s2, i, j, k, n, show_index, ju
integer num_locations
integer, allocatable, save :: ix_ele(:)

logical err, found, at_ends
logical show_all, name_found
logical, automatic :: picked(size(s%u))
logical, allocatable :: show_here(:)

!

call reallocate_integer (ix_ele,1)
call re_allocate (lines, 200, 500)

err = .false.

lines = " "
nl = 0

rmt  = '(a, 9es16.8)'
irmt = '(a, i0, a, es16.8)'
imt  = '(a, 9i8)'
iimt = '(a, i0, a, i8)'
lmt  = '(a, 9l)'
amt  = '(9a)'

u => s%u(s%global%u_view)

if (s%global%phase_units == radians$) f_phi = 1
if (s%global%phase_units == degrees$) f_phi = 180 / pi
if (s%global%phase_units == cycles$)  f_phi = 1 / twopi

! find what to show

if (what == ' ') then
  call out_io (s_error$, r_name, 'SHOW WHAT?')
  return
endif

call match_word (what, show_names, ix)
if (ix == 0) then
  call out_io (s_error$, r_name, 'SHOW WHAT? WORD NOT RECOGNIZED: ' // what)
  return
endif

if (ix < 0) then
  call out_io (s_error$, r_name, 'SHOW WHAT? AMBIGUOUS: ' // what)
  return
endif

call tao_cmd_split (stuff, 2, word, .false., err)


select case (show_names(ix))

!----------------------------------------------------------------------
! optimized_vars

case ('opt_vars')

  call tao_var_write (' ')

!----------------------------------------------------------------------
! hom

case ('hom')

  nl=nl+1; lines(nl) = &
        '       #        Freq         R/Q           Q   m  Polarization_Angle'
  do i = 1, size(u%model%lat%ele_)
    ele => u%model%lat%ele_(i)
    if (ele%key /= lcavity$) cycle
    if (ele%control_type == multipass_slave$) cycle
    nl=nl+1; write (lines(nl), '(a, i6)') ele%name, i
    do j = 1, size(ele%wake%lr)
      lr => ele%wake%lr(j)
      angle = '-'
      if (lr%polarized) write (angle, '(f9.4)') lr%angle
      nl=nl+1; write (lines(nl), '(i8, 3es12.4, i4, a)') j, &
                  lr%freq, lr%R_over_Q, lr%Q, lr%m, angle
    enddo
    nl=nl+1; lines(nl) = ' '
  enddo
  nl=nl+1; lines(nl) = '       #        Freq         R/Q           Q   m  Polarization_Angle'

  call out_io (s_blank$, r_name, lines(1:nl))

!----------------------------------------------------------------------
! write

case ('write')

  iu = lunget()
  file_name = s%global%write_file
  ix = index(file_name, '*')
  if (ix /= 0) then
    s%global%n_write_file = s%global%n_write_file + 1
    write (file_name, '(a, i3.3, a)') file_name(1:ix-1), &
                      s%global%n_write_file, trim(file_name(ix+1:))
  endif

  open (iu, file = file_name, position = 'APPEND', status = 'UNKNOWN')
  call output_direct (iu)  ! tell out_io to write to a file

  call out_io (s_blank$, r_name, ' ', 'Tao> show ' // stuff, ' ')
  call tao_show_cmd (word(1), word(2))  ! recursive

  call output_direct (0)  ! reset to not write to a file
  close (iu)
  call out_io (s_blank$, r_name, 'Written to file: ' // file_name)

  return

!----------------------------------------------------------------------
! alias

case ('alias')

  call re_allocate (lines, len(lines(1)), tao_com%n_alias+10)
  lines(1) = 'Aliases:'
  nl = 1
  do i = 1, tao_com%n_alias
    nl=nl+1; lines(nl) = trim(tao_com%alias(i)%name) // ' = "' // &
                                    trim(tao_com%alias(i)%string) // '"'
  enddo
  
  call out_io (s_blank$, r_name, lines(1:nl))

!----------------------------------------------------------------------
! constraints

case ('constraints')

  call tao_show_constraints (0, 'ALL')
  call tao_show_constraints (0, 'TOP10')

!----------------------------------------------------------------------
! data

case ('data')


! If just "show data" then show all names

  call tao_pick_universe (word(1), line1, picked, err)
  if (err) return

  if (line1 == ' ') then  ! just specified a universe

    do iu = 1, size(s%u)

      if (.not. picked(iu)) cycle

      u => s%u(s%global%u_view)

      nl=nl+1; write(lines(nl), *) ' '
      if (size(s%u) > 1) then
        nl=nl+1; write(lines(nl), '(a, i4)') 'Universe:', iu
      endif

      do i = 1, size(u%d2_data)
        d2_ptr => u%d2_data(i)
        if (d2_ptr%name == ' ') cycle
        nl=nl+1; lines(nl) = ' '
        do j = lbound(d2_ptr%d1, 1), ubound(d2_ptr%d1, 1)
          d1_ptr => d2_ptr%d1(j)
          nl=nl+1; write (lines(nl), '(i5, 2x, 4a, i0, a, i0, a)') j, &
                      trim(d2_ptr%name), '.', trim(d1_ptr%name), &
                      '[', lbound(d1_ptr%d, 1), ':', ubound(d1_ptr%d, 1), ']'
        enddo
      enddo
    enddo

    call out_io (s_blank$, r_name, lines(1:nl))
    return
  endif

! get pointers to the data

  call tao_find_data (err, word(1), d2_ptr, d1_ptr, d_array)
  if (err) return

  n_size = 0
  if (allocated(d_array)) n_size = size(d_array)

! If d_ptr points to something then show the datum info.

  if (n_size == 1) then
    d_ptr => d_array(1)%d
    nl=nl+1; write(lines(nl), *) ' '
    if (size(s%u) > 1) then
      nl=nl+1; write(lines(nl), '(a, i4)') 'Universe:', d_ptr%d1%d2%ix_uni
    endif
    nl=nl+1; write(lines(nl), amt)  '%Name:              ', d_ptr%name
    nl=nl+1; write(lines(nl), amt)  '%Ele0_name:         ', d_ptr%ele0_name
    nl=nl+1; write(lines(nl), amt)  '%Ele_name:          ', d_ptr%ele_name
    nl=nl+1; write(lines(nl), amt)  '%Data_type:         ', d_ptr%data_type
    nl=nl+1; write(lines(nl), imt)  '%Ix_ele0:           ', d_ptr%ix_ele0
    nl=nl+1; write(lines(nl), imt)  '%Ix_ele:            ', d_ptr%ix_ele
    nl=nl+1; write(lines(nl), imt)  '%Ix_ele_merit:      ', d_ptr%ix_ele_merit
    nl=nl+1; write(lines(nl), imt)  '%Ix_dModel:         ', d_ptr%ix_dModel
    nl=nl+1; write(lines(nl), imt)  '%Ix_d1:             ', d_ptr%ix_d1
    nl=nl+1; write(lines(nl), imt)  '%Ix_data:           ', d_ptr%ix_data
    nl=nl+1; write(lines(nl), rmt)  '%meas_value:        ', d_ptr%meas_value
    nl=nl+1; write(lines(nl), rmt)  '%Ref_value:         ', d_ptr%ref_value
    nl=nl+1; write(lines(nl), rmt)  '%Model_value:       ', d_ptr%model_value
    nl=nl+1; write(lines(nl), rmt)  '%base_value:        ', d_ptr%base_value
    nl=nl+1; write(lines(nl), rmt)  '%delta_merit:       ', d_ptr%delta_merit
    nl=nl+1; write(lines(nl), rmt)  '%Design_value:      ', d_ptr%design_value
    nl=nl+1; write(lines(nl), rmt)  '%Old_value:         ', d_ptr%old_value
    nl=nl+1; write(lines(nl), rmt)  '%Fit_value:         ', d_ptr%fit_value
    nl=nl+1; write(lines(nl), rmt)  '%Merit:             ', d_ptr%merit
    nl=nl+1; write(lines(nl), rmt)  '%Conversion_factor: ', d_ptr%conversion_factor
    nl=nl+1; write(lines(nl), rmt)  '%S:                 ', d_ptr%s
    nl=nl+1; write(lines(nl), rmt)  '%Weight:            ', d_ptr%weight
    nl=nl+1; write(lines(nl), amt)  '%Merit_type:        ', d_ptr%merit_type
    nl=nl+1; write(lines(nl), lmt)  '%Exists:            ', d_ptr%exists
    nl=nl+1; write(lines(nl), lmt)  '%Good_meas:         ', d_ptr%good_meas
    nl=nl+1; write(lines(nl), lmt)  '%Good_ref:          ', d_ptr%good_ref
    nl=nl+1; write(lines(nl), lmt)  '%Good_user:         ', d_ptr%good_user
    nl=nl+1; write(lines(nl), lmt)  '%Good_opt:          ', d_ptr%good_opt
    nl=nl+1; write(lines(nl), lmt)  '%Good_plot:         ', d_ptr%good_plot
    nl=nl+1; write(lines(nl), lmt)  '%Useit_plot:        ', d_ptr%useit_plot
    nl=nl+1; write(lines(nl), lmt)  '%Useit_opt:         ', d_ptr%useit_opt

! Else show the d1_data info.

  elseif (associated(d1_ptr)) then

    if (size(s%u) > 1) then
      nl=nl+1; write(lines(nl), '(a, i4)') 'Universe:', d1_ptr%d2%ix_uni
    endif
    
    nl=nl+1; write(lines(nl), '(2a)') 'Data name: ', trim(d2_ptr%name) // '.' // d1_ptr%name

    line1 = '                                                                      |   Useit'
    line2 = '     Name                         Meas         Model        Design    | Opt  Plot'
    nl=nl+1; lines(nl) = line1
    nl=nl+1; lines(nl) = line2

! if a range is specified, show the data range   

    call re_allocate (lines, len(lines(1)), nl+100+size(d1_ptr%d))

    do i = 1, size(d_array)
      d_ptr => d_array(i)%d
      if (.not. d_ptr%exists) cycle
      if (size(lines) > nl + 50) call re_allocate (lines, len(lines(1)), nl+100)
      nl=nl+1; write(lines(nl), '(i5, 2x, a20, 3es14.4, 2l6)') d_ptr%ix_d1, &
                     d_ptr%name, d_ptr%meas_value, d_ptr%model_value, &
                     d_ptr%design_value, d_ptr%useit_opt, d_ptr%useit_plot
    enddo

    nl=nl+1; lines(nl) = line2
    nl=nl+1; lines(nl) = line1

! else we must have a valid d2_ptr.

  elseif (associated(d2_ptr)) then

    call re_allocate (lines, len(lines(1)), nl+100+size(d2_ptr%d1))

    if (size(s%u) > 1) then
      nl=nl+1; write(lines(nl), '(a, i4)') 'Universe:', d2_ptr%ix_uni
    endif
    nl=nl+1; write(lines(nl), '(2a)') 'D2_Data type:    ', d2_ptr%name
    nl=nl+1; write(lines(nl), '(5x, a)') '                   Bounds'
    nl=nl+1; write(lines(nl), '(5x, a)') 'D1_Data name    lower: Upper' 

    do i = 1, size(d2_ptr%d1)
      if (size(lines) > nl + 50) call re_allocate (lines, len(lines(1)), nl+100)
      nl=nl+1; write(lines(nl), '(5x, a, i5, a, i5)') d2_ptr%d1(i)%name, &
                  lbound(d2_ptr%d1(i)%d, 1), '.', ubound(d2_ptr%d1(i)%d, 1)
    enddo

    if (any(d2_ptr%descrip /= ' ')) then
      call re_allocate (lines, len(lines(1)), nl+100+size(d2_ptr%descrip))
      nl=nl+1; write (lines(nl), *)
      nl=nl+1; write (lines(nl), '(a)') 'Descrip:'
      do i = 1, size(d2_ptr%descrip)
        if (d2_ptr%descrip(i) /= ' ') then
          nl=nl+1; write (lines(nl), '(i4, 2a)') i, ': ', d2_ptr%descrip(i)
        endif
      enddo
    endif

! error

  else
    lines(1) = 'TRY BEING MORE SPECIFIC.'
    nl = 1
  endif

  call out_io (s_blank$, r_name, lines(1:nl))

!----------------------------------------------------------------------
! ele

case ('ele')

  call str_upcase (ele_name, word(1))

  if (index(ele_name, '*') /= 0 .or. index(ele_name, '%') /= 0) then
    write (lines(1), *) 'Matches to name:'
    nl = 1
    do loc = 1, u%model%lat%n_ele_max
      if (.not. match_wild(u%model%lat%ele_(loc)%name, ele_name)) cycle
      if (size(lines) < nl+100) call re_allocate (lines, len(lines(1)), nl+200)
      nl=nl+1; write (lines(nl), '(i8, 2x, a)') loc, u%model%lat%ele_(loc)%name
      name_found = .true.
    enddo
    if (.not. name_found) then
      nl=nl+1; write (lines(nl), *) '   *** No Matches to Name Found ***'
    endif

! else no wild cards

  else  

    call tao_locate_element (ele_name, s%global%u_view, ix_ele)
    loc = ix_ele(1)
    if (loc < 0) return

    write (lines(nl+1), *) 'Element #', loc
    nl = nl + 1

    ! Show the element info
    call type2_ele (u%model%lat%ele_(loc), ptr_lines, n, .true., 6, .false., &
                                        s%global%phase_units, .true., u%model%lat)
    if (size(lines) < nl+n+100) call re_allocate (lines, len(lines(1)), nl+n+100)
    lines(nl+1:nl+n) = ptr_lines(1:n)
    nl = nl + n
    deallocate (ptr_lines)

    orb = u%model%orb(loc)
    fmt = '(2x, a, 3p2f11.4)'
    write (lines(nl+1), *) ' '
    write (lines(nl+2), *)   'Orbit: [mm, mrad]'
    write (lines(nl+3), fmt) "X  X':", orb%vec(1:2)
    write (lines(nl+4), fmt) "Y  Y':", orb%vec(3:4)
    write (lines(nl+5), fmt) "Z  Z':", orb%vec(5:6)
    nl = nl + 5

    ! Show data associated with this element
    call show_ele_data (u, loc, lines, nl)

    found = .false.
    do i = loc + 1, u%model%lat%n_ele_max
      if (u%model%lat%ele_(i)%name /= ele_name) cycle
      if (size(lines) < nl+100) call re_allocate (lines, len(lines(1)), nl+200)
      if (found) then
        nl=nl+1; write (lines(nl), *)
        found = .true.
      endif 
      nl=nl+1;  write (lines(nl), *) &
                'Note: Found another element with same name at:', i
    enddo

  endif

  call out_io (s_blank$, r_name, lines(1:nl))

!----------------------------------------------------------------------
! global

case ('global')

  nl=nl+1; write (lines(nl), imt) 'n_universes:       ', size(s%u)
  nl=nl+1; write (lines(nl), imt) 'u_view:            ', s%global%u_view
  nl=nl+1; write (lines(nl), imt) 'phase_units:       ', s%global%phase_units
  nl=nl+1; write (lines(nl), imt) 'n_opti_cycles:     ', s%global%n_opti_cycles
  nl=nl+1; write (lines(nl), amt) 'track_type:        ', s%global%track_type
  if (s%global%track_type .eq. 'macro') &
  nl=nl+1; write (lines(nl), imt) 'bunch_to_plot::    ', s%global%bunch_to_plot
  nl=nl+1; write (lines(nl), amt) 'optimizer:         ', s%global%optimizer
  nl=nl+1; write (lines(nl), amt) 'prompt_string:     ', s%global%prompt_string
  nl=nl+1; write (lines(nl), amt) 'var_out_file:      ', s%global%var_out_file
  nl=nl+1; write (lines(nl), amt) 'opt_var_out_file:  ', s%global%opt_var_out_file
  nl=nl+1; write (lines(nl), amt) 'print_command:     ', s%global%print_command
  nl=nl+1; write (lines(nl), amt) 'current_init_file: ',s%global%current_init_file
  nl=nl+1; write (lines(nl), lmt) 'var_limits_on:     ', s%global%var_limits_on
  nl=nl+1; write (lines(nl), lmt) 'opt_with_ref:      ', s%global%opt_with_ref 
  nl=nl+1; write (lines(nl), lmt) 'opt_with_base:     ', s%global%opt_with_base
  nl=nl+1; write (lines(nl), lmt) 'plot_on:           ', s%global%plot_on
  nl=nl+1; write (lines(nl), lmt) 'var_limits_on:     ', s%global%var_limits_on
  nl=nl+1; write (lines(nl), amt) 'curren_init_file:  ', s%global%current_init_file

  call out_io (s_blank$, r_name, lines(1:nl))

!----------------------------------------------------------------------
! lattice

case ('lattice')
  
  if (word(1) .eq. ' ') then
    nl=nl+1; write (lines(nl), '(a, i3)') 'Universe: ', s%global%u_view
    nl=nl+1; write (lines(nl), '(a, i5, a, i5)') 'Regular elements:', &
                                          1, '  through', u%model%lat%n_ele_use
    if (u%model%lat%n_ele_max .gt. u%model%lat%n_ele_use) then
      nl=nl+1; write (lines(nl), '(a, i5, a, i5)') 'Lord elements:   ', &
                        u%model%lat%n_ele_use+1, '  through', u%model%lat%n_ele_max
    else
      nl=nl+1; write (lines(nl), '(a)') "there are NO Lord elements"
    endif
    if (u%is_on) then
      nl=nl+1; write (lines(nl), '(a)') 'This universe is turned ON'
    else
      nl=nl+1; write (lines(nl), '(a)') 'This universe is turned OFF'
    endif

    if (.not. u%model%lat%param%stable .or. .not. u%model%lat%param%stable) then
      nl=nl+1; write (lines(nl), '(a, l)') 'Model lattice stability: ', &
                                                            u%model%lat%param%stable
      nl=nl+1; write (lines(nl), '(a, l)') 'Design lattice stability:', &
                                                            u%design%lat%param%stable
      call out_io (s_blank$, r_name, lines(1:nl))
      return
    endif
 
    call radiation_integrals (u%model%lat, &
                                  u%model%orb, u%model%modes, u%ix_rad_int_cache)
    call radiation_integrals (u%design%lat, &
                                  u%design%orb, u%design%modes, u%ix_rad_int_cache)
    if (u%model%lat%param%lattice_type .eq. circular_lattice$) then
      call chrom_calc (u%model%lat, delta_e, &
                          u%model%a%chrom, u%model%b%chrom, exit_on_error = .false.)
      call chrom_calc (u%design%lat, delta_e, &
                          u%design%a%chrom, u%design%b%chrom, exit_on_error = .false.)
    endif

    write (lines(nl+1), *)
    write (lines(nl+2), '(17x, a)') '       X          |            Y'
    write (lines(nl+3), '(17x, a)') 'Model     Design  |     Model     Design'
    fmt = '(1x, a10, 1p 2e11.3, 2x, 2e11.3, 2x, a)'
    fmt2 = '(1x, a10, 2f11.3, 2x, 2f11.3, 2x, a)'
    fmt3 = '(1x, a10, 2f11.4, 2x, 2f11.4, 2x, a)'
    f_phi = 1 / twopi
    l_lat = u%model%lat%param%total_length
    n = u%model%lat%n_ele_use
    write (lines(nl+4), fmt2) 'Q', f_phi*u%model%lat%ele_(n)%x%phi, &
            f_phi*u%design%lat%ele_(n)%x%phi, f_phi*u%model%lat%ele_(n)%y%phi, &
            f_phi*u%design%lat%ele_(n)%y%phi,  '! Tune'
    write (lines(nl+5), fmt2) 'Chrom', u%model%a%chrom, & 
            u%design%a%chrom, u%model%b%chrom, u%design%b%chrom, '! dQ/(dE/E)'
    write (lines(nl+6), fmt2) 'J_damp', u%model%modes%a%j_damp, &
          u%design%modes%a%j_damp, u%model%modes%b%j_damp, &
          u%design%modes%b%j_damp, '! Damping Partition #'
    write (lines(nl+7), fmt) 'Emittance', u%model%modes%a%emittance, &
          u%design%modes%a%emittance, u%model%modes%b%emittance, &
          u%design%modes%b%emittance, '! Meters'
    write (lines(nl+8), fmt) 'Alpha_damp', u%model%modes%a%alpha_damp, &
          u%design%modes%a%alpha_damp, u%model%modes%b%alpha_damp, &
          u%design%modes%b%alpha_damp, '! Damping per turn'
    write (lines(nl+9), fmt) 'I4', u%model%modes%a%synch_int(4), &
          u%design%modes%a%synch_int(4), u%model%modes%b%synch_int(4), &
          u%design%modes%b%synch_int(4), '! Radiation Integral'
    write (lines(nl+10), fmt) 'I5', u%model%modes%a%synch_int(5), &
          u%design%modes%a%synch_int(5), u%model%modes%b%synch_int(5), &
          u%design%modes%b%synch_int(5), '! Radiation Integral'
    nl = nl + 10

    write (lines(nl+1), *)
    write (lines(nl+2), '(19x, a)') 'Model     Design'
    fmt = '(1x, a12, 1p2e11.3, 3x, a)'
    write (lines(nl+3), fmt) 'Sig_E/E:', u%model%modes%sigE_E, &
              u%design%modes%sigE_E
    write (lines(nl+4), fmt) 'Energy Loss:', u%model%modes%e_loss, &
              u%design%modes%e_loss, '! Energy_Loss (eV / Turn)'
    write (lines(nl+5), fmt) 'J_damp:', u%model%modes%z%j_damp, &
          u%design%modes%z%j_damp, '! Longitudinal Damping Partition #'
    write (lines(nl+6), fmt) 'Alpha_damp:', u%model%modes%z%alpha_damp, &
          u%design%modes%z%alpha_damp, '! Longitudinal Damping per turn'
    write (lines(nl+7), fmt) 'Alpha_p:', u%model%modes%synch_int(1)/l_lat, &
                 u%design%modes%synch_int(1)/l_lat, '! Momentum Compaction'
    write (lines(nl+8), fmt) 'I1:', u%model%modes%synch_int(1), &
                 u%design%modes%synch_int(1), '! Radiation Integral'
    write (lines(nl+9), fmt) 'I2:', u%model%modes%synch_int(2), &
                 u%design%modes%synch_int(2), '! Radiation Integral'
    write (lines(nl+10), fmt) 'I3:', u%model%modes%synch_int(3), &
                 u%design%modes%synch_int(3), '! Radiation Integral'
    nl = nl + 10

    call out_io (s_blank$, r_name, lines(1:nl))
    return
  endif

  if (index('middle', trim(word(1))) == 1) then
    at_ends = .false.
    word(1) = word(2)
    word(2) = ' '
    if (word(1) == ' ') word(1) = 'all'
  else
    at_ends = .true.
  endif
  
  allocate (show_here(0:u%model%lat%n_ele_use))
  if (word(1) == 'all') then
    show_here = .true.
  else
    word(2) = trim(word(1)) // ' ' // trim(word(2))
    call location_decode (word(2), show_here, 0, num_locations)
    if (num_locations .eq. -1) then
      call out_io (s_error$, r_name, "Syntax error in range list!")
      deallocate(show_here)
      return
    endif
  endif

  if (at_ends) then
    at_ends = .true.
    write (line1, '(6x, a)') 'Model values at End of Element:'
  else
    at_ends = .false.
    write (line1, '(6x, a)') 'Model values at Center of Element:'
  endif


  write (line2, '(29x, 22x, a)') &
                     '|              X           |             Y        '
  write (line3, '(6x, a, 16x, a)') ' Name                     key', &
                  '   S    |  Beta   Phi   Eta  Orb   | Beta    Phi    Eta   Orb'

  lines(nl+1) = line1
  lines(nl+2) = line2
  lines(nl+3) = line3
  nl=nl+3

  do ix = lbound(show_here,1), ubound(show_here,1)
    if (.not. show_here(ix)) cycle
    if (size(lines) < nl+100) call re_allocate (lines, len(lines(1)), nl+200)
    ele => u%model%lat%ele_(ix)
    if (ix == 0 .or. at_ends) then
      ele3 = ele
      orb = u%model%orb(ix)
      s_pos = ele3%s
    else
      call twiss_and_track_partial (u%model%lat%ele_(ix-1), ele, &
                u%model%lat%param, ele%value(l$)/2, ele3, u%model%orb(ix-1), orb)
      s_pos = ele%s-ele%value(l$)/2
    endif
    nl=nl+1
    write (lines(nl), '(i6, 1x, a24, 1x, a16, f10.3, 2(f7.2, f8.3, f5.1, f8.3))') &
          ix, ele%name, key_name(ele%key), s_pos, &
          ele3%x%beta, f_phi*ele3%x%phi, ele3%x%eta, 1000*orb%vec(1), &
          ele3%y%beta, f_phi*ele3%y%phi, ele3%y%eta, 1000*orb%vec(3)
  enddo

  lines(nl+1) = line3
  lines(nl+2) = line2
  lines(nl+3) = line1
  nl=nl+3
  
  call out_io (s_blank$, r_name, lines(1:nl))

  deallocate(show_here)

!----------------------------------------------------------------------
! optimizer

case ('optimizer')

  do i = 1, size(s%u)
    u => s%u(i)
    call out_io (s_blank$, r_name, ' ', 'Data Used:')
    write (lines(1), '(a, i4)') 'Universe: ', i
    if (size(s%u) > 1) call out_io (s_blank$, r_name, lines(1))
    do j = 1, size(u%d2_data)
      if (u%d2_data(j)%name == ' ') cycle
      call tao_data_show_use (u%d2_data(j))
    enddo
  enddo

  call out_io (s_blank$, r_name, ' ', 'Variables Used:')
  do j = 1, size(s%v1_var)
    if (s%v1_var(j)%name == ' ') cycle
    call tao_var_show_use (s%v1_var(j))
  enddo

  nl=nl+1; lines(nl) = ' '
  nl=nl+1; write (lines(nl), amt) 'optimizer:        ', s%global%optimizer
  call out_io (s_blank$, r_name, lines(1:nl))

!----------------------------------------------------------------------
! plots

case ('plot')

! word(1) is blank => print overall info

  if (word(1) == ' ') then

    nl=nl+1; lines(nl) = ' '
    nl=nl+1; lines(nl) = 'Templates:        Plot.Graph'
    nl=nl+1; lines(nl) = '             --------- ----------'
    do i = 1, size(s%template_plot)
      p => s%template_plot(i)
      if (p%name == ' ') cycle
      ix = 21 - len_trim(p%name)
      name = ' '
      name(ix:) = trim(p%name)
      if (associated(p%graph)) then
        do j = 1, size(p%graph)
          nl=nl+1; write (lines(nl), '(2x, 3a)') name(1:20), '.', p%graph(j)%name
          name = ' '
        enddo
      else
        nl=nl+1; write (lines(nl), '(2x, 2a)') name(1:20), '.'
      endif
      nl=nl+1; lines(nl) = ' '
    enddo

    nl=nl+1; lines(nl) = ' '
    nl=nl+1; lines(nl) = '[Visible]     Plot Region         <-->  Template' 
    nl=nl+1; lines(nl) = '---------     -----------               ------------'
    do i = 1, size(s%plot_page%region)
      region => s%plot_page%region(i)
      nl=nl+1; write (lines(nl), '(3x l1, 10x, a20, 2a)') region%visible, &
                                    region%name, '<-->  ', region%plot%name
    enddo

    call out_io (s_blank$, r_name, lines(1:nl))
    return
  endif

! Find particular plot

  call tao_find_plots (err, word(1), 'BOTH', plot, graph, curve, print_flag = .false.)
  if (err) return

! print info on particular plot, graph, or curve

  if (allocated(curve)) then
    c => curve(1)%c
    g => c%g
    p => g%p
    if (associated(p%r)) then
      nl=nl+1; lines(nl) = 'Region.Graph.Curve: ' // trim(p%r%name) // '.' // &
                                                  trim(g%name) // '.' // c%name
    endif
    nl=nl+1; lines(nl) = 'Plot.Graph.Curve:   ' // trim(p%name) // '.' // &
                                                  trim(g%name) // '.' // c%name
    nl=nl+1; write (lines(nl), amt) 'name:                    ', c%name
    nl=nl+1; write (lines(nl), amt) 'data_source:             ', c%data_source
    nl=nl+1; write (lines(nl), amt) 'data_type:               ', c%data_type
    nl=nl+1; write (lines(nl), amt) 'ele_ref_name:            ', c%ele_ref_name
    nl=nl+1; write (lines(nl), imt) 'ix_ele_ref:              ', c%ix_ele_ref
    nl=nl+1; write (lines(nl), imt) 'ix_universe:             ', c%ix_universe
    nl=nl+1; write (lines(nl), imt) 'symbol_every:            ', c%symbol_every
    nl=nl+1; write (lines(nl), rmt) 'x_axis_scale_factor:     ', c%x_axis_scale_factor
    nl=nl+1; write (lines(nl), rmt) 'y_axis_scale_factor:     ', c%y_axis_scale_factor
    nl=nl+1; write (lines(nl), lmt) 'use_y2:                  ', c%use_y2
    nl=nl+1; write (lines(nl), lmt) 'draw_line:               ', c%draw_line
    nl=nl+1; write (lines(nl), lmt) 'draw_symbols:            ', c%draw_symbols
    nl=nl+1; write (lines(nl), lmt) 'limited:                 ', c%limited
    nl=nl+1; write (lines(nl), lmt) 'convert:                 ', c%convert
    nl=nl+1; write (lines(nl), lmt) 'draw_interpolated_curve: ', c%draw_interpolated_curve
    

  elseif (allocated(graph)) then
    g => graph(1)%g
    p => g%p
    if (associated(p%r)) then
      nl=nl+1; lines(nl) = 'Region.Graph: ' // trim(p%r%name) // '.' // trim(g%name)
    endif
    nl=nl+1; lines(nl) = 'Plot.Graph:   ' // trim(p%name) // '.' // trim(g%name)
    nl=nl+1; write (lines(nl), amt) 'name:                  ', g%name
    nl=nl+1; write (lines(nl), amt) 'type:                  ', g%type
    nl=nl+1; write (lines(nl), amt) 'title:                 ', g%title
    nl=nl+1; write (lines(nl), amt) 'title_suffix:          ', g%title_suffix
    nl=nl+1; write (lines(nl), imt) 'box:                   ', g%box
    nl=nl+1; write (lines(nl), imt) 'ix_universe:           ', g%ix_universe
    nl=nl+1; write (lines(nl), imt) 'box:                   ', g%box
    nl=nl+1; write (lines(nl), lmt) 'valid:                 ', g%valid
    nl=nl+1; write (lines(nl), lmt) 'y2_mirrors_y:          ', g%y2_mirrors_y
    nl=nl+1; lines(nl) = 'Curves:'
    do i = 1, size(g%curve)
      nl=nl+1; write (lines(nl), amt) '   ', g%curve(i)%name
    enddo

  elseif (allocated(plot)) then
    p => plot(1)%p
    if (associated(p%r)) then
      nl=nl+1; lines(nl) = 'Region:  ' // trim(p%r%name)
    endif
    nl=nl+1; lines(nl) = 'Plot:  ' // p%name
    nl=nl+1; write (lines(nl), amt) 'x_axis_type:          ', p%x_axis_type
    nl=nl+1; write (lines(nl), rmt) 'x_divisions:          ', p%x_divisions
    nl=nl+1; write (lines(nl), lmt) 'independent_graphs:   ', p%independent_graphs
    
    nl=nl+1; write (lines(nl), *) 'Graphs:'
    do i = 1, size(p%graph)
      nl=nl+1; write (lines(nl), amt) '   ', p%graph(i)%name
    enddo

  else
    call out_io (s_error$, r_name, 'This is not a graph')
    return
  endif

  call out_io (s_blank$, r_name, lines(1:nl))

!----------------------------------------------------------------------
! top10

case ('top10')

  call tao_top10_print ()

!----------------------------------------------------------------------
! universe
    
case ('universe')

  if (word(1) == ' ') then
    ix_u = s%global%u_view
  else
    read (word(1), *, iostat = ios) ix_u
    if (ios /= 0) then
      call out_io (s_error$, r_name, 'BAD UNIVERSE NUMBER')
      return
    endif
    if (ix_u < 1 .or. ix_u > size(s%u)) then
      call out_io (s_error$, r_name, 'UNIVERSE NUMBER OUT OF RANGE')
      return
    endif
  endif

  u => s%u(ix_u)

  nl = 0
  nl=nl+1; write(lines(nl), imt) '%ix_uni:                ', u%ix_uni
  nl=nl+1; write(lines(nl), imt) '%n_d2_data_used:        ', u%n_d2_data_used
  nl=nl+1; write(lines(nl), imt) '%n_data_used:           ', u%n_data_used
  nl=nl+1; write(lines(nl), lmt) '%do_synch_rad_int_calc: ', u%do_synch_rad_int_calc
  nl=nl+1; write(lines(nl), lmt) '%do_chrom_calc:         ', u%do_chrom_calc
  nl=nl+1; write(lines(nl), lmt) '%is_on:                 ', u%is_on

  call out_io (s_blank$, r_name, lines(1:nl)) 

!----------------------------------------------------------------------
! variable
    
case ('var')

  if (.not. associated (s%v1_var)) then
    call out_io (s_error$, r_name, 'NO VARIABLES HAVE BEEN DEFINED IN THE INPUT FILES!')
    return 
  endif

! If 'n@' is present then write out stuff for universe n

  ix = index(word(1), '@')
  if (ix /= 0) then
    if (ix == 1) then
      ix_u = s%global%u_view
    else
      read (word(1)(:ix-1), *, iostat = ios) ix_u
      if (ios /= 0) then
        call out_io (s_error$, r_name, 'BAD UNIVERSE NUMBER')
        return
      endif
      if (ix_u == 0) ix_u = s%global%u_view
      if (ix_u < 1 .or. ix_u > size(s%u)) then
        call out_io (s_error$, r_name, 'UNIVERSE NUMBER OUT OF RANGE')
        return
      endif
    endif
    write (lines(1), '(a, i4)') 'Variables controlling universe:', ix_u
    write (lines(2), '(5x, a)') '                    '
    write (lines(3), '(5x, a)') 'Name                '
    nl = 3
    do i = 1, size(s%var)
      if (.not. s%var(i)%exists) cycle
      found = .false.
      do j = 1, size(s%var(i)%this)
        if (s%var(i)%this(j)%ix_uni == ix_u) found = .true.
      enddo
      if (.not. found) cycle
      nam = tao_var1_name(s%var(i))
      nl=nl+1; write(lines(nl), '(5x, a, a40)') nam(1:25), s%var(i)%name
    enddo
    call out_io (s_blank$, r_name, lines(1:nl))
    return
  endif

! If just "show var" then show all namees

  if (word(1) == '*') then
    call tao_var_write (' ')
    return
  endif

  if (word(1) == ' ') then
    write (lines(1), '(5x, a)') '                      Bounds'
    write (lines(2), '(5x, a)') 'Name                Lower  Upper'
    nl = 2
    do i = 1, size(s%v1_var)
      v1_ptr => s%v1_var(i)
      if (v1_ptr%name == ' ') cycle
      if (size(lines) < nl+100) call re_allocate (lines, len(lines(1)), nl+200)
      nl=nl+1; write(lines(nl), '(5x, a20, i5, i7)') v1_ptr%name, &
                                       lbound(v1_ptr%v, 1), ubound(v1_ptr%v, 1)
    enddo
    call out_io (s_blank$, r_name, lines(1:nl))
    return
  endif

! get pointers to the variables

  call string_trim (word(2), word(2), ix)
! are we looking at a range of locations?

  call tao_find_var(err, word(1), v1_ptr, v_array) 
  if (err) return
  n_size = 0
  if (allocated(v_array)) n_size = size(v_array)

! v_ptr is valid then show the variable info.

  if (n_size == 1) then

    v_ptr => v_array(1)%v

    nl=nl+1; write(lines(nl), amt)  'Name:          ', v_ptr%name        
    nl=nl+1; write(lines(nl), amt)  'Alias:         ', v_ptr%alias       
    nl=nl+1; write(lines(nl), amt)  'Ele_name:      ', v_ptr%ele_name    
    nl=nl+1; write(lines(nl), amt)  'Attrib_name:   ', v_ptr%attrib_name 
    nl=nl+1; write(lines(nl), imt)  'Ix_var:        ', v_ptr%ix_var
    nl=nl+1; write(lines(nl), imt)  'Ix_dvar:       ', v_ptr%ix_dvar           
    nl=nl+1; write(lines(nl), imt)  'Ix_v1:         ', v_ptr%ix_v1
    nl=nl+1; write(lines(nl), rmt)  'Model_value:   ', v_ptr%model_value
    nl=nl+1; write(lines(nl), rmt)  'Base_value:    ', v_ptr%base_value

    if (.not. associated (v_ptr%this)) then
      nl=nl+1; write(lines(nl), imt)  'this(:) -- Not associated!'
    else
      do i = 1, size(v_ptr%this)
        nl=nl+1; write(lines(nl), iimt)  '%this(', i, ')%Ix_uni:        ', &
                                                            v_ptr%this(i)%ix_uni
        nl=nl+1; write(lines(nl), iimt)  '%this(', i, ')%Ix_ele:        ', v_ptr%this(i)%ix_ele
        if (associated (v_ptr%this(i)%model_ptr)) then
          nl=nl+1; write(lines(nl), irmt)  '%this(', i, ')%Model_ptr:   ', &
                                                            v_ptr%this(i)%model_ptr
        else
          nl=nl+1; write(lines(nl), irmt)  '%this(', i, ')%Model_ptr:   <not associated>'
        endif
        if (associated (v_ptr%this(i)%base_ptr)) then
          nl=nl+1; write(lines(nl), irmt)  '%this(', i, ')%Base_ptr:    ', &
                                                            v_ptr%this(i)%base_ptr
        else
          nl=nl+1; write(lines(nl), irmt)  '%this(', i, ')%Base_ptr:    <not associated>'
        endif
      enddo
    endif

    nl=nl+1; write(lines(nl), rmt)  '%Design_value:    ', v_ptr%design_value
    nl=nl+1; write(lines(nl), rmt)  '%Old_value:       ', v_ptr%old_value
    nl=nl+1; write(lines(nl), rmt)  '%Meas_value:      ', v_ptr%meas_value
    nl=nl+1; write(lines(nl), rmt)  '%Ref_value:       ', v_ptr%ref_value
    nl=nl+1; write(lines(nl), rmt)  '%Correction_value:', v_ptr%correction_value
    nl=nl+1; write(lines(nl), rmt)  '%High_lim:        ', v_ptr%high_lim
    nl=nl+1; write(lines(nl), rmt)  '%Low_lim:         ', v_ptr%low_lim
    nl=nl+1; write(lines(nl), rmt)  '%Step:            ', v_ptr%step
    nl=nl+1; write(lines(nl), rmt)  '%Weight:          ', v_ptr%weight
    nl=nl+1; write(lines(nl), rmt)  '%delta_merit:     ', v_ptr%delta_merit
    nl=nl+1; write(lines(nl), amt)  '%Merit_type:      ', v_ptr%merit_type
    nl=nl+1; write(lines(nl), rmt)  '%Merit:           ', v_ptr%merit
    nl=nl+1; write(lines(nl), rmt)  '%dMerit_dVar:     ', v_ptr%dMerit_dVar
    nl=nl+1; write(lines(nl), lmt)  '%Exists:          ', v_ptr%exists
    nl=nl+1; write(lines(nl), lmt)  '%Good_var:        ', v_ptr%good_var
    nl=nl+1; write(lines(nl), lmt)  '%Good_user:       ', v_ptr%good_user
    nl=nl+1; write(lines(nl), lmt)  '%Good_opt:        ', v_ptr%good_opt
    nl=nl+1; write(lines(nl), lmt)  '%Useit_opt:       ', v_ptr%useit_opt
    nl=nl+1; write(lines(nl), lmt)  '%Useit_plot:      ', v_ptr%useit_plot

! check if there is a variable number
! if no variable number requested, show a range

  elseif (associated(v1_ptr)) then

    nc = 0
    do i = 1, size(v_array)
      v_ptr => v_array(i)%v
      if (.not. v_ptr%exists) cycle
      nc = max(nc, len_trim(v_ptr%name))
    enddo

    write(lines(1), '(2a)') 'Variable name:   ', v1_ptr%name
    lines(2) = ' '
    line1 = '       Name'
    line1(nc+17:) = 'Meas         Model        Design  Useit_opt'
    write (lines(3), *) line1
    nl = 3
    ! if a range is specified, show the variable range   
    do i = 1, size(v_array)
      v_ptr => v_array(i)%v
      if (.not. v_ptr%exists) cycle
      if (size(lines) < nl+100) call re_allocate (lines, len(lines(1)), nl+200)
      nl=nl+1
      write(lines(nl), '(i6, 2x, a)') v_ptr%ix_v1, v_ptr%name
      write(lines(nl)(nc+9:), '(3es14.4, 7x, l)') v_ptr%meas_value, &
                 v_ptr%model_value, v_ptr%design_value, v_ptr%useit_opt
    enddo
    nl=nl+1
    write (lines(nl), *) line1

  else
    lines(1) = '???'
    nl = 1
  endif

! print out results

  call out_io (s_blank$, r_name, lines(1:nl))


!----------------------------------------------------------------------

case default

  call out_io (s_error$, r_name, "INTERNAL ERROR, SHOULDN'T BE HERE!")
  return

end select

!----------------------------------------------------------------------
!----------------------------------------------------------------------
contains

subroutine show_ele_data (u, i_ele, lines, nl)

implicit none

type (tao_universe_struct), target :: u
type (tao_data_struct), pointer :: datum
character(*) :: lines(:)
integer i_ele, nl, i

character(30) :: dmt = "(a20, 3(1x, es15.5)) "

logical :: found_one = .false.

  nl=nl+1; write (lines(nl), '(a)') "  "
  nl=nl+1; write (lines(nl), '(a)') &
        "   Data Type          |  Model Value  |  Design Value |  Base Value"

  do i = 1, size(u%data)
    if (u%data(i)%ix_ele .eq. i_ele) then
      found_one = .true.
      datum => u%data(i)
      nl = nl + 1
      write (lines(nl), dmt) datum%data_type, datum%model_value, &
                             datum%design_value, datum%base_value 
    endif
  enddo

  if (.not. found_one) then
    nl = nl +1 
    write (lines(nl), '(a)') "No data types associated with this element."
  endif

  nl=nl+1; write (lines(nl), '(a)') "  "
  nl=nl+1; write (lines(nl), '(a)') &
        "   Data Type          |  Model Value  |  Design Value |  Base Value"


end subroutine show_ele_data

end subroutine tao_show_cmd

end module
