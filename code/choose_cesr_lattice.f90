!+
! Subroutine CHOOSE_CESR_LATTICE (LATTICE, LAT_FILE, CURRENT_LAT, RING, CHOICE)
!
! Subroutine to let the user choose a lattice. The subroutine will present a
! list to choose from.
!                                                               
! Modules Needed:
!   use bmad_struct
!   use bmad_interface
!
! Input:
!   CURRENT_LAT -- Character*40: Name of current lattice (will be stared in
!                       the list presented to the user).
!                       Use CALL GETLAT (CURRENT_LAT) to get the current name.
!                       Set CURRENT_LAT = ' ' if you do not want to use this
!                       feature.
!                       NOTE: You must be connected to the mpm to use GETLAT.
!   CHOICE      -- Character*(*): [Optional] If present then this will be
!                       used as input instead of querying the user.
!
! Output:
!   LATTICE  -- Character*40: Lattice name choisen. If a file name is given
!                    and RING is not present then LATTICE = ""
!   LAT_FILE -- Character*(*): Name of the lattice file. Typically:
!                    lat_file = 'U:[CESR.BMAD.LAT]BMAD_' // lattice
!   RING     -- Ring_struct: OPTIONAL. If present then BMAD_PARSER is called
!               to load the RING structure.
!-
               
subroutine choose_cesr_lattice (lattice, lat_file, current_lat, ring, choice)

  use bmad_struct
  use bmad_interface

  implicit none

  type (ring_struct), optional :: ring

  character(len=*), optional :: choice
  character*(*) lat_file
  character*40 lattice, current_lat, lat_list(100)
  character*80 line
   
  integer i, num_lats, i_lat, ix, ios

  logical is_there, ask_for_lat, default

!                   

  call get_lattice_list (lat_list, num_lats, 'u:[cesr.bmad.lat]')

  ask_for_lat = .true.

  if (present(choice)) then
    line = choice
    call string_trim (line, line, ix)
    if (ix /= 0) ask_for_lat = .false.
  endif

! loop until we have a valid choice

  do

    if (ask_for_lat) then
      type *
      i_lat = 0
      do i = 1, num_lats
        if (lat_list(i) == current_lat) then
          type '(1x, a, i2, 3a)', '**', i, ') ', trim(lat_list(i)), &
                                           '   ! Current lattice in Data Base'
          i_lat = i
        else
          type '(i5, 2a)', i, ') ', lat_list(i)
        endif
      enddo
  
      type *, ' [Note: To be in this list a lattice file must have a name ]'
      type *, ' [      of the form: U:[CESR.BMAD.LAT]BMAD_<lattice_name>  ]'

      type *
      type *, 'You can enter a Lattice number or a full file name.'
      if (i_lat == 0) then
        type '(a, $)', ' Choice: '
      else
        type '(a, i3, a, $)', ' Choice: <CR =', i_lat, '> '
      endif
      accept '(a)', line
    endif

    call string_trim (line, line, ix)
    line = line(:ix)

    if (ix == 0 .or. (ix == 1 .and. line == '*')) then
      default = .true.
    else
      default = .false.
      read (line, *, iostat = ios) i_lat
    endif

    if (default .or. (ios == 0 .and. index('0123456789', line(1:1)) /= 0)) then
      if (i_lat < 1 .or. i_lat > num_lats) then
        type *, 'ERROR: WHICH LATTICE? TRY AGAIN...'
        ask_for_lat = .true.
        cycle  ! try again
      endif
      lattice = lat_list(i_lat)
      lat_file = 'U:[CESR.BMAD.LAT]BMAD_' // lattice
    else
      lattice = ""
      lat_file = line
      inquire (file = lat_file, exist = is_there, name = lat_file)
      if (.not. is_there) then
        lat_file = 'U:[CESR.BMAD.LAT]BMAD_' // line
        inquire (file = lat_file, exist = is_there, name = lat_file)
        if (.not. is_there) then
          type *, 'READ ERROR OR FILE DOES NOT EXIST. TRY AGAIN...'
          ask_for_lat = .true.
          cycle
        endif
      endif
      ix = index(lat_file, ';')
      if (ix /= 0) lat_file = lat_file(:ix-1)
    endif
    exit

  enddo

! load ring if present

  if (present (ring)) then
    call bmad_parser (lat_file, ring)
    lattice = ring%lattice
  endif

end subroutine
