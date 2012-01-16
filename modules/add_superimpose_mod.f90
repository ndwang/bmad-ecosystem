module add_superimpose_mod

use bmad_struct
use bmad_interface
use lat_ele_loc_mod
use bookkeeper_mod

private delete_underscore, adjust_super_slave_names, adjust_drift_names

contains

!-----------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------
!+
! Subroutine add_superimpose (lat, super_ele_in, ix_branch, err_flag, super_ele_out, 
!                                                       save_null_drift, create_em_field_slave)
!
! Routine to superimpose an element. If the element can be inserted
! into the lat without making a super_lord element then this will be done.
!
! Note: This routine, since it handles only one superposition, is not sufficient for
!   superposition in a multipass region. For historical reasons, the extra code needed 
!   is buried in the bmad_parser code. If you need to do multipass superpositions 
!   please contact David Sagan and this situation will be rectified.
!
! Note: Transfer matrices for split elements and super_slave elements are
!   *not* recomputed.
!
! Modules Needed:
!   use bmad
!
! Input:
!   lat              -- lat_struct: Lat to modify.
!   super_ele_in     -- Ele_struct: Element to superimpose.
!         %s            -- Position of end of element.
!                          Negative distances mean distance from the end.
!   ix_branch        -- Integer: Branch index to put element.
!   save_null_drift  -- Logical, optional: Save a copy of a drift to be split as a null_ele?
!                         This is useful if further superpositions might use this drift as a 
!                         reference element. After all superpositions are done, 
!                         remove_eles_from_lat can be called to remove all null_eles.
!                         Default is False.
!   create_em_field_slave
!                   -- Logical, optional: Default is False. If True then super_slaves
!                       that are created that have super_ele_in as their super_lord are
!                       em_field elements.
!
! Output:
!   lat           -- lat_struct: Modified lat.
!   err_flag      -- Logical :: Set True if there is an error. False otherwise
!   super_ele_out -- Ele_struct, pointer, optional :: Pointer to the super element in the lattice.
!-

subroutine add_superimpose (lat, super_ele_in, ix_branch, err_flag, super_ele_out, &
                                                            save_null_drift, create_em_field_slave)

implicit none

type (lat_struct), target :: lat
type (ele_struct)  super_ele_in
type (ele_struct), pointer, optional ::  super_ele_out
type (ele_struct), save :: super_saved, slave_saved, drift, null_ele
type (ele_struct), pointer :: slave, lord
type (control_struct)  sup_con(100)
type (branch_struct), pointer :: branch

real(rp) s1, s2, length, s1_lat, s2_lat, s1_lat_fudge, s2_lat_fudge

integer i, j, jj, k, ix, n, i2, ic, n_con, ixs, ix_branch
integer ix1_split, ix2_split, ix_super, ix_super_con
integer ix_slave, ixn, ixc, ix_1lord, ix_lord_max_old

logical, optional :: save_null_drift, create_em_field_slave
logical err_flag, setup_lord, split1_done, split2_done, all_drift

character(100) name
character(20) fmt
character(20) :: r_name = "add_superimpose"

!-------------------------------------------------------------------------
! Check for negative length

err_flag = .true.

if (super_ele_in%value(l$) < 0) then
  call out_io (s_abort$, r_name, &
                  'Superposition of element with negative length not allowed!', &
                  'Element: ' // super_ele_in%name, &
                  'Length: \es10.2\ ', r_array = [super_ele_in%value(l$)] )
  if (bmad_status%exit_on_error) call err_exit
  return
endif

! We need a copy of super_ele_in since the actual argument may be in the lat
! and split_lat can then overwrite it.

call init_ele (super_saved)
call init_ele (slave_saved)
call init_ele (drift)
drift%key = drift$

super_saved = super_ele_in
branch => lat%branch(ix_branch)

! s1 is the left edge of the superimpose.
! s2 is the right edge of the superimpose.
! For a lat a superimpose can wrap around the ends of the lattice.

ix_lord_max_old = lat%n_ele_max

s1_lat = branch%ele(0)%s                 ! normally this is zero.
s1_lat_fudge = s1_lat - bmad_com%significant_length

s2_lat = branch%ele(branch%n_ele_track)%s
s2_lat_fudge = s2_lat + bmad_com%significant_length

s1 = super_saved%s - super_saved%value(l$)
s2 = super_saved%s                 

if (s1 < s1_lat_fudge) then
  if (branch%param%lattice_type == linear_lattice$) call out_io (s_warn$, &
         r_name, 'Superimpose is being wrapped around linear lattice for: ' // super_saved%name)
  s1 = s1 + branch%param%total_length
endif

if (s2 > s2_lat_fudge) then
  if (branch%param%lattice_type == linear_lattice$) call out_io (s_warn$, &
         r_name, 'Superimpose is being wrapped around linear lattice for: ' // super_saved%name)
  s2 = s2 - branch%param%total_length
endif

if (s1 < s1_lat_fudge .or. s2 < s1_lat_fudge .or. s1 > s2_lat_fudge .or. s2 > s2_lat_fudge) then
  call out_io (s_abort$, r_name, &
    'SUPERIMPOSE POSITION BEYOUND END OF LATTICE FOR ELEMENT: ' // super_saved%name, &
    'LEFT EDGE: \F10.1\ ', &
    'RIGHT EDGE:\F10.1\ ', r_array = [s1, s2])
  if (bmad_status%exit_on_error) call err_exit
  return
endif
 
!-------------------------------------------------------------------------
! If element has zero length then just insert it in the tracking part 
! of the lattice list.

! Note: Important to set super_saved%lord_status before calling insert_element since
! this affects the status flag setting.

if (super_saved%value(l$) == 0) then
  super_saved%lord_status  = not_a_lord$ 
  super_saved%slave_status = free$
  call split_lat (lat, s1, ix_branch, ix1_split, split1_done, &
                                check_controls = .false., save_null_drift = save_null_drift)
  call insert_element (lat, super_saved, ix1_split+1, ix_branch)
  ix_super = ix1_split + 1
  if (present(super_ele_out)) super_ele_out => branch%ele(ix_super)
  call adjust_super_slave_names (lat, ix_lord_max_old+1, branch%n_ele_max)
  call adjust_drift_names (lat, branch%ele(ix1_split))
  err_flag = .false.
  return
endif

!-------------------------------------------------------------------------
! Split lat at begining and end of the superimpose.
! The correct order of splitting is important since we are creating elements
! so that the numbering of the elments after the split changes.

! Also the splits may not be done exactly at s1 and s2 since split_lat avoids
! making very small "runt" elements. We thus readjust the lord length to
! keep everything consistant. 

! if superimpose wraps around 0 ...
if (s2 < s1) then     
  call split_lat (lat, s2, ix_branch, ix2_split, split2_done, .false., .false., save_null_drift)
  call split_lat (lat, s1, ix_branch, ix1_split, split1_done, .false., .false., save_null_drift)
  super_saved%value(l$) = (s2_lat - branch%ele(ix1_split)%s) + (branch%ele(ix2_split)%s - s1_lat)

! no wrap case...
else                  
  call split_lat (lat, s1, ix_branch, ix1_split, split1_done, .false., .false., save_null_drift)
  call split_lat (lat, s2, ix_branch, ix2_split, split2_done, .false., .false., save_null_drift)
  super_saved%value(l$) = branch%ele(ix2_split)%s - branch%ele(ix1_split)%s
endif

! Get rid of duplicate saved drifts if present

n = lat%n_ele_max
if (lat%ele(n)%key == null_ele$ .and. lat%ele(n-1)%key == null_ele$ .and. &
        lat%ele(n)%s == lat%ele(n-1)%s .and. lat%ele(n)%name == lat%ele(n-1)%name) then
  lat%ele(n)%key = -1
  call remove_eles_from_lat (lat, .false.)
endif


! zero length elements at the edges of the superimpose region can be excluded
! from the region

do 
  if (branch%ele(ix1_split+1)%value(l$) /= 0) exit
  ix1_split = ix1_split + 1
  if (ix1_split > branch%n_ele_track) ix1_split = 0
enddo

do
  if (branch%ele(ix2_split)%value(l$) /= 0) exit
  ix2_split = ix2_split - 1
  if (ix2_split == -1) ix2_split = branch%n_ele_track
enddo

! If there are null_ele elements in the superimpose region then just move them
! out of the way to the lord section of the branch. This prevents unnecessary
! splitting.

i = ix1_split
do
  i = i + 1
  if (i > branch%n_ele_track) i = 0
  if (branch%ele(i)%key == null_ele$) then

    branch%n_ele_max = branch%n_ele_max + 1
    ix = branch%n_ele_max
    if (ix > ubound(branch%ele, 1))  call allocate_lat_ele_array (lat, ix_branch = ix_branch)

    branch%ele(ix) = branch%ele(i)       ! copy null_ele
    do ic = branch%ele(i)%ic1_lord, branch%ele(i)%ic2_lord
      j = lat%ic(ic)
      lat%control(j)%ix_slave = ix ! point to new null_ele.
    enddo
    branch%ele(i)%key = -1  ! Mark old null_ele for deletion
    call remove_eles_from_lat (lat)
    i = i - 1
    if (ix2_split > i) ix2_split = ix2_split - 1
    if (ix1_split > i) ix1_split = ix1_split - 1
  endif
  if (i == ix2_split) exit
enddo

! If element overlays only drifts then just 
! insert it in the tracking part of the lat list.

all_drift = (ix2_split > ix1_split)
do i = ix1_split+1, ix2_split
  if (branch%ele(i)%key /= drift$) all_drift = .false.
  if (branch%ele(i)%slave_status /= free$) all_drift = .false.
  if (.not. all_drift) exit
enddo

if (all_drift) then  
  do i = ix1_split+2, ix2_split    ! remove all drifts but one
    branch%ele(i)%key = -1    ! mark for deletion
  enddo
  call remove_eles_from_lat(lat)    ! And delete
  ix_super = ix1_split + 1
  branch%ele(ix_super) = super_saved
  branch%ele(ix_super)%lord_status  = not_a_lord$
  branch%ele(ix_super)%slave_status = free$
  call set_flags_for_changed_attribute (lat, branch%ele(ix_super))
  if (present(super_ele_out)) super_ele_out => branch%ele(ix_super)
  ! If a single drift was split: give the runt drifts on either end 
  ! names by adding "#" suffix to signify the split
  if (split1_done .and. split2_done) then
    if (branch%ele(ix_super-1)%name == branch%ele(ix_super+1)%name .and. &
                                  branch%ele(ix_super-1)%key == drift$) then
      n = len_trim(branch%ele(ix_super-1)%name)
      if (n == len(branch%ele(ix_super-1)%name)) n = n - 1
      branch%ele(ix_super-1)%name = branch%ele(ix_super-1)%name(1:n) // '#'
      branch%ele(ix_super+1)%name = branch%ele(ix_super+1)%name(1:n) // '#'
    endif
  endif
  call adjust_drift_names (lat, branch%ele(ix_super-1))
  err_flag = .false.
  return
endif

! Only possibility left means we have to set up a super_lord element 
! representing the superimposed element for the superposition...

! First: It is not legal for an element to be simultaneously a multipass_slave and a super_slave.
! Thus if the elements to be superimposed upon are multipass_slaves,
! we need to make them super_slaves and create a corresponding super_lord.

do i = ix1_split+1, ix2_split
  slave => branch%ele(i)
  if (slave%slave_status == multipass_slave$) then
    ! Create a lord for this multipass_slave
    call new_control(lat, ixs)
    slave => branch%ele(i) ! need this if branch%ele was reallocated
    lord => lat%ele(ixs)
    lord = slave
    lord%lord_status = super_lord$
    ! Point control info to this new lord
    do j = 1, lat%n_control_max
      if (lat%control(j)%ix_slave == i) lat%control(j)%ix_slave = ixs
    enddo
    ! Now put in the info to make the original element a super_slave
    lord%n_slave = 1
    call add_lattice_control_structs (lat, lord)
    ix = lord%ix1_slave
    lat%control(ix)%ix_slave = i
    lat%control(ix)%ix_branch = ix_branch
    slave%slave_status = super_slave$
    slave%name = trim(slave%name) // '#1'
    slave%n_lord = 1
    slave%ic1_lord = 0   ! So add_lattice_control_structs does the right thing
    slave%ic2_lord = -1  ! So add_lattice_control_structs does the right thing
    call add_lattice_control_structs (lat, slave)
    ic = slave%ic1_lord
    lat%ic(ic) = ix
  endif
enddo

! Now to create the superimposed element super_lord.

ix_super = lat%n_ele_max + 1
lat%n_ele_max = ix_super
if (lat%n_ele_max > ubound(lat%ele, 1)) call allocate_lat_ele_array(lat)
lat%ele(ix_super) = super_saved
lat%ele(ix_super)%lord_status = super_lord$
call set_flags_for_changed_attribute (lat, lat%ele(ix_super))
if (present(super_ele_out)) super_ele_out => lat%ele(ix_super)

ix_super_con = 0
length = super_saved%value(l$)

! Go through the list of elements being superimposed upon.
! Zero length elements (markers and multipoles) do not get involved here.

ix_slave = ix1_split

do 

  ix_slave = ix_slave + 1
  if (ix_slave == ix2_split + 1) exit
  if (ix_slave == branch%n_ele_track + 1) ix_slave = 1

  slave => branch%ele(ix_slave)
  slave_saved = slave
  if (slave_saved%value(l$) == 0) cycle

  ! Do we need to set up a super lord to control this slave element?

  select case (slave%slave_status)
  case (super_slave$) 
    setup_lord = .false.
  case (multipass_slave$, overlay_slave$, group_slave$)
    setup_lord = .true.
  case default
    if (slave%key == drift$) then
      setup_lord = .false.
    else
      setup_lord = .true.
    endif
  end select

  ! if yes then create the super lord element

  if (setup_lord) then
    call new_control (lat, ixn)
    lat%ele(ixn) = slave_saved
    lat%ele(ixn)%lord_status = super_lord$
    ixc = lat%n_control_max + 1
    if (ixc > size(lat%control)) call reallocate_control(lat, ixc+100)
    lat%ele(ixn)%ix1_slave = ixc
    lat%ele(ixn)%ix2_slave = ixc
    lat%ele(ixn)%n_slave = 1
    lat%control(ixc)%ix_lord = ixn
    lat%control(ixc)%ix_slave = ix_slave
    lat%control(ixc)%ix_branch = ix_branch
    lat%control(ixc)%coef = 1.0
    lat%n_control_max = ixc

    do j = lat%ele(ixn)%ic1_lord, lat%ele(ixn)%ic2_lord
      jj = lat%ic(j)
      lat%control(jj)%ix_slave = ixn
    enddo

    ic = lat%n_ic_max + 1
    slave%ic1_lord = ic
    slave%ic2_lord = ic + 1
    slave%n_lord = 2
    lat%n_ic_max = ic + 1
    lat%ic(ic) = ixc 

  else
    slave%n_lord = slave_saved%n_lord + 1
    call add_lattice_control_structs (lat, slave)
  endif

  slave%slave_status = super_slave$

  ! add control info for main super lord to list

  ix_super_con = ix_super_con + 1
  sup_con(ix_super_con)%ix_slave = ix_slave
  sup_con(ix_super_con)%ix_branch = ix_branch
  sup_con(ix_super_con)%ix_lord = ix_super
  sup_con(ix_super_con)%coef = slave_saved%value(l$) / length
  sup_con(ix_super_con)%ix_attrib = 0

  ! change the element key

  call calc_superimpose_key(slave_saved, super_saved, slave)
  if (slave%key <= 0) then
    call out_io (s_abort$, r_name, [ &
            'ELEMENT: ' // trim(super_saved%name), &
            'OF TYPE: ' // key_name(super_saved%key), &
            'IS TO BE SUPERIMPOSED UPON: ' // trim(slave_saved%name), &
            'OF TYPE: ' // key_name(slave_saved%key), &
            'I DO NOT KNOW HOW TO DO THIS!'] )
    if (bmad_status%exit_on_error) call err_exit 
    return                   
  endif

  call set_flags_for_changed_attribute (lat, lat%ele(ix_super))

enddo

! Special case where elements on either side of the superimpose have the same
! name

if (split1_done .and. split2_done .and. &
              branch%ele(ix1_split)%name == branch%ele(ix2_split+1)%name) then
  branch%ele(ix1_split)%name = trim(branch%ele(ix1_split)%name) // '#1'
  branch%ele(ix2_split+1)%name = trim(branch%ele(ix2_split+1)%name) // '#2'
  call delete_underscore (branch%ele(ix1_split))
  call delete_underscore (branch%ele(ix2_split+1))
endif

! transfer control info from sup_con array

ixc = lat%n_control_max + 1
n_con = ixc + ix_super_con - 1
if (n_con > size(lat%control)) call reallocate_control(lat, n_con+500) 
lat%ele(ix_super)%ix1_slave = ixc
lat%ele(ix_super)%ix2_slave = n_con
lat%ele(ix_super)%n_slave = ix_super_con
if (present(super_ele_out)) super_ele_out => lat%ele(ix_super)

do k = 1, ix_super_con
  lat%control(k+ixc-1) = sup_con(k)
  ix_slave = lat%control(k+ixc-1)%ix_slave
  i2 = branch%ele(ix_slave)%ic2_lord
  lat%ic(i2) = k+ixc-1
enddo

lat%n_control_max = n_con

! order slave elements in the super_lord list to be in the correct order

call s_calc (lat)  ! just in case superimpose extended before beginning of lattice.
call order_super_lord_slaves (lat, ix_super)
call adjust_super_slave_names (lat, ix_lord_max_old+1, lat%n_ele_max)
call adjust_drift_names (lat, branch%ele(ix1_split))
call adjust_drift_names (lat, branch%ele(ix2_split+1))

err_flag = .false.

end subroutine

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
! Modify: "#\" -> "\"
!         "##" -> "#"

subroutine delete_underscore(ele)

use bmad_struct

implicit none

type (ele_struct) ele
integer ix

!

ix = index(ele%name, '#\')  ! '
if (ix /= 0) ele%name = ele%name(1:ix-1) // ele%name(ix+1:)

ix = index(ele%name, '##')
if (ix /= 0) ele%name = ele%name(1:ix-1) // ele%name(ix+1:)

end subroutine delete_underscore

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine adjust_super_slave_names (lat, ix1_lord, ix2_lord, first_time)
!
! Routine to adjust the names of the slaves.
! This routine is used by add_superimpose and is not meant for general use.
!-

recursive subroutine adjust_super_slave_names (lat, ix1_lord, ix2_lord, first_time)

implicit none

type (lat_struct), target :: lat
type (ele_struct), pointer :: lord, slave, lord2
integer ix1_lord, ix2_lord
integer i, j, k, ix, ix_1lord
character(40) name
logical, optional :: first_time

! First time through...
! The idea is to prevent an infinite circle by making sure that an element is not
! touched more than once. So initially mark all elements as not touched.

if (.not. present(first_time)) then
  do i = 0, ubound(lat%branch, 1)
    lat%branch(i)%ele%bmad_logic = .false.  ! Have adjusted?
  enddo
endif

!

do i = ix1_lord, ix2_lord
  lord => lat%ele(i)
  if (lord%lord_status /= super_lord$) cycle
  if (lord%bmad_logic) cycle
  lord%bmad_logic = .true.
  ix_1lord = 0
  do j = 1, lord%n_slave
    slave => pointer_to_slave(lord, j)
    if (slave%bmad_logic) cycle
    slave%bmad_logic = .true.

    if (slave%n_lord == 1) then
      ix_1lord = ix_1lord + 1
      write (slave%name, '(2a, i0)') trim(lord%name), '#', ix_1lord
    else
      name = ''
      do k = 1, slave%n_lord
        lord2 => pointer_to_lord(slave, k)
        if (.not. lord2%bmad_logic) call adjust_super_slave_names (lat, lord2%ix_ele, lord2%ix_ele, .false.)
        name = trim(name) //  '\' // lord2%name     !'
      enddo
      slave%name = name(2:len(slave%name))
    endif

  enddo
enddo

end subroutine adjust_super_slave_names

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
!+
! Subroutine adjust_drift_names (lat, drift_ele)
!
! If drifts have been split due to superimpose then the split drifts
! can have some very convoluted names. Also multipass lord drifts. Here we do some cleanup.
! Collect all free elements with the same name before the '#' and renumber.
!-

subroutine adjust_drift_names (lat, drift_ele)

implicit none

type (lat_struct), target :: lat
type (ele_struct) drift_ele
type (ele_struct), pointer :: ele, slave
type (branch_struct), pointer :: branch

integer i, ib, k, ixh, ixh2, ixx

character(40) d_name

!

if (drift_ele%key /= drift$) return

ixh = index(drift_ele%name, '#')
if (ixh == 0) return

d_name = drift_ele%name(1:ixh)

!

ixx = 0
do ib = 0, ubound(lat%branch, 1)

  branch => lat%branch(ib)
  do i = 1, branch%n_ele_max

    ele => branch%ele(i)
    if (ele%slave_status /= free$ .and. ele%lord_status /= multipass_lord$) cycle

    ixh2 = index(ele%name, '#')
    if (ixh2 /= ixh) cycle
    if (ele%name(1:ixh) /= d_name(1:ixh)) cycle

    ixx = ixx + 1
    write (ele%name, '(a, i0)') d_name(1:ixh), ixx

    if (ele%lord_status == multipass_lord$) then
      do k = 1, ele%n_slave
        slave => pointer_to_slave(ele, k)
        write (slave%name, '(2a, i0)') trim(ele%name), '\', k  ! '
      enddo
    endif

  enddo
enddo 

end subroutine adjust_drift_names

end module
