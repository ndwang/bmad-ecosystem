module lat_ele_loc_mod

use bmad_struct
use bmad_interface

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_ele
!
! Function to return a pointer to an element in a lattice.
!
! Overloaded function for:
!   Function pointer_to_ele1 (lat, loc) result (ele_ptr)
!   Function pointer_to_ele2 (lat, ix_ele, ix_branch) result (ele_ptr)
!
! Modules Needed:
!   use lat_ele_loc_mod
!
! Input:
!   lat       -- Lat_struct: Lattice.
!   loc       -- lat_ele_loc_struct: Location of element.
!   ix_ele    -- Integer: element index in the branch.
!   ix_branch -- Integer: Branch index.
!
! Output:
!   ele_ptr -- Ele_struct, pointer: Pointer to the element. 
!              If input location is out of range then ele_ptr will be nullified.
!-

interface pointer_to_ele
  module procedure pointer_to_ele1
  module procedure pointer_to_ele2
end interface

contains

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine lat_ele_locator (loc_str, lat, locs, n_loc, err)
!
! Routine to locate all the elements of a certain key 
! and certain name. loc_str is of the form:
!   <key>:<name> 
! or 
!   <name>
! or
!   <indexes>
! Where
!   <key>     = key name ("quadrupole", "sbend", etc.)
!   <name>    = Name of element. May contain the wild cards "*" and "%".
!   <indexes> = List of indexes in the lat%ele list.
! Example:
!   "quad:q*"    All quadrupoles whose name begins with "q"
!   "3,5:7"      Elements with index 3, 5, 6, and 7 in branch 0.
!   "1.45:51"    Elements 45 through 51 of branch 1.
! 
! Modules Needed:
!   use lat_ele_loc_mod
!
! Input:
!   loc_str  -- Character(*): Element name.
!   lat      -- lat_struct: Lattice to search through.
!
! Output:
!   locs(:) -- Lat_ele_loc_struct, allocatable: Array of matching element locations.
!              Note: This routine does not try to deallocate locs.
!               It is up to you to deallocate locs if needed.
!   n_loc   -- Integer: Number of locations found.
!                Set to zero if no elements are found.
!   err     -- Logical: Set True if there is a decode error.
!-

subroutine lat_ele_locator (loc_str, lat, locs, n_loc, err)

implicit none

type (lat_struct) lat

character(*) loc_str
character(40) name
type (lat_ele_loc_struct), allocatable :: locs(:)
integer i, j, k, ix, key, n_loc
logical err, do_match_wild

! index array

err = .true.

if (is_integer(loc_str(1:1))) then
  call lat_location_decode (loc_str, lat, locs, err)
  return
endif

! key:name construct

ix = index(loc_str, ':')
if (ix == 0) then
  key = 0
  call str_upcase (name, loc_str)
else
  key = key_name_to_key_index (loc_str(:ix-1), .true.)
  if (key < 1) return
  call str_upcase (name, loc_str(ix+1:))
endif

! Save time by deciding if we need to call match_wild or not.

do_match_wild = .false.  
if (index(loc_str, "*") /= 0 .or. index(loc_str, "%") /= 0) do_match_wild = .true.

! search for matches

n_loc = 0
do k = lbound(lat%branch, 1), ubound(lat%branch, 1)
  do i = 0, lat%branch(k)%n_ele_max
    if (key /= 0 .and. lat%branch(k)%ele(i)%key /= key) cycle
    if (do_match_wild) then
      if (.not. match_wild(lat%branch(k)%ele(i)%name, name)) cycle
    else
      if (lat%branch(k)%ele(i)%name /= name) cycle
    endif
    n_loc = n_loc + 1
    if (.not. allocated(locs)) call re_allocate_locs (locs, 1, .true.)
    if (size(locs) < n_loc) call re_allocate_locs (locs, 2*n_loc, .true.)
    locs(n_loc) = lat_ele_loc_struct(i, k)
  enddo
enddo

err = .false.

end subroutine lat_ele_locator

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine lat_location_decode (loc_str, lat, locs, err)
!
! Routine to parse a numeric list of element locations.
!
! Input:
!   loc_str  -- Character*(*): Array of locations.
!                     "," or a space delimits location numbers 
!                     A ":" is used for a range of locations. 
!                     A second ":" specifies a step increment.
!   lat      -- lat_struct: Lattice to search through.
!
! Modules Needed:
!   use lat_ele_loc_mod
!
! Output:
!   locs(:) -- Lat_ele_loc_struct: Array of matching locations.
!   err     -- Logical: Set True if location does not correspond to a physical element.
!
! Example:
!     string = '3:37 98, 101:115:2'
! Then:
!     call location_decode (string, locs, err)
! Gives:
!     locs(:) points to 3 to 37, 98, and odd numbers between 101 to 115
!-

subroutine lat_location_decode(loc_str, lat, locs, err)

implicit none

type (lat_struct) lat
type (lat_ele_loc_struct), allocatable :: locs(:)

integer i, j, k
integer n_loc, ios, ix_next, ix_branch, step,start_loc, end_loc, ix_word
integer ix_ele, ixp

character(*) loc_str
character(1) delim
character(len(loc_str)) str
character :: r_name = 'lat_location_decode'

logical err
logical range_found, step_found

! initialize locs

str = loc_str

err = .true.
range_found = .false.
step_found = .false.
ix_next = 1
ix_branch = 0
n_loc = 0
step = 1

do k = lbound(lat%branch, 1), ubound(lat%branch, 1)
  lat%branch(k)%ele(:)%bmad_logic = .false.
enddo

!

do

  call string_trim2 (str(ix_next:), ':,', str, ix_word, delim, ix_next)

  if (ix_word == 0) exit

  ! Look for a name match

  ix_ele = 0

  ! If there is no name match then assume it is a number

  if (ix_ele == 0) then
    ixp = index(str(:ix_word), '.')
    if (ixp /= 0 .and. ixp <= ix_word) then
      read (str(1:ixp), *, iostat = ios) ix_branch
      if (ios /= 0) then
        call out_io (s_error$, r_name, 'ERROR: BAD LOCATION: ' // str(:ix_word))
        return
      endif
      str = str(ixp+1:)
      ix_word = ix_word - ixp
    endif
    read (str(:ix_word), *, iostat = ios) ix_ele
    if (ios /= 0) then
      call out_io (s_error$, r_name, 'ERROR: BAD LOCATION: ' // str(:ix_word))
      return
    endif
  endif

  if (step_found) step = ix_ele
    
  if (delim == ':') then
    if (range_found) then
      if (step_found) then
        call out_io (s_error$, r_name, 'ERROR: BAD RANGE ' // str(1:20))
        return
      else
        step_found = .true.
        end_loc = ix_ele
      endif
    else
      range_found = .true.
      start_loc = ix_ele
    endif
  else
    if (range_found) then
      lat%branch(ix_branch)%ele(start_loc:end_loc:step)%bmad_logic = .true.
      n_loc = n_loc + (end_loc - start_loc) / step
      range_found = .false.
      step_found = .false.
      step = 1
    else
      lat%branch(ix_branch)%ele(ix_ele)%bmad_logic = .true.
      n_loc = n_loc + 1
    endif
  endif

  if (ix_next == 0) exit

enddo

!--------

if (range_found) then
  call out_io (s_error$, r_name, 'ERROR IN LOCATION_DECODE: OPEN RANGE')
  return
endif

! count number of elements in arrray

call re_allocate_locs (locs, n_loc)
j = 0
do k = lbound(lat%branch, 1), ubound(lat%branch, 1)
  do i = 0, lat%branch(k)%n_ele_max
    if (.not. lat%branch(k)%ele(i)%bmad_logic) cycle
    j = j + 1
    locs(j) = lat_ele_loc_struct(i, k)
  enddo
enddo

err = .false.

end subroutine lat_location_decode

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine re_allocate_locs (locs, n, save)
!
! Routine to allocate an array of lat_ele_loc_structs.
!
! Modules Needed:
!   use lat_ele_loc_mod
!
! Input:
!   n -- Integer: Array size to set.
!   save -- Logical, optional: If present and True then save the old data.
!
! Output:
!   locs(:) -- lat_ele_loc_struct, allocatable: Array of locations.
!     %ix_branch -- Initalized to zero were needed.
!-

subroutine re_allocate_locs (locs, n, save)

implicit none

type (lat_ele_loc_struct), allocatable :: locs(:)
type (lat_ele_loc_struct), allocatable :: l_temp(:)
integer n, n_old
logical, optional :: save

!

if (.not. allocated(locs)) then
  allocate (locs(n))
  return
endif

if  (size(locs) == n) return

if (logic_option (.false., save)) then
  n_old = min(size(locs), n)
  allocate (l_temp(n_old))
  l_temp = locs(1:n_old)
endif

deallocate (locs)
allocate (locs(n))

if (logic_option (.false., save)) then
  locs(1:n_old) = l_temp
  deallocate (l_temp)
  locs(n_old+1:)%ix_branch = 0
else
  locs%ix_branch = 0
endif

end subroutine

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_ele1 (lat, loc) result (ele_ptr)
!
! Function to return a pointer to an element in a lattice.
! See pointer_to_ele for more details.
!-

function pointer_to_ele1 (lat, loc) result (ele_ptr)

type (lat_struct), target :: lat
type (ele_struct), pointer :: ele_ptr
type (lat_ele_loc_struct) loc

!

ele_ptr => null()

if (loc%ix_branch < 0 .or. loc%ix_branch > ubound(lat%branch, 1)) return
if (loc%ix_ele < 0 .or. loc%ix_ele > lat%branch(loc%ix_branch)%n_ele_max) return

ele_ptr => lat%branch(loc%ix_branch)%ele(loc%ix_ele)

end function

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_ele2 (lat, ix_ele, ix_branch) result (ele_ptr)
!
! Function to return a pointer to an element in a lattice.
! See pointer_to_ele for more details.
!-

function pointer_to_ele2 (lat, ix_ele, ix_branch) result (ele_ptr)

type (lat_struct), target :: lat
type (ele_struct), pointer :: ele_ptr

integer ix_branch, ix_ele

!

ele_ptr => null()

if (ix_branch < 0 .or. ix_branch > ubound(lat%branch, 1)) return
if (ix_ele < 0 .or. ix_ele > lat%branch(ix_branch)%n_ele_max) return

ele_ptr => lat%branch(ix_branch)%ele(ix_ele)

end function

end module
