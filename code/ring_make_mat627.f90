!+
! Subroutine RING_MAKE_MAT627 (RING, IX_ELE, DIRECTION, MATS627)
!
! Subroutine to make the 6x27 2nd order matrices for long term tracking. 
! Used by, for example, TRACK_LONG.
!
! Modules Needed:
!   use bmad_struct
!   use bmad_interface
!
! Input:
!   RING        -- Ring_struct: Ring containing the element.
!   IX_ELE      -- Integer: Index of the element. if < 0 then entire
!                    ring will be made. In this case group elements will
!                    be made up last.
!   DIRECTION   -- Integer: Transport Direction. 
!                   = +1  -> For Forward (normal) particle tracking.
!                   = -1  -> For Backward particle tracking.
!
! Output:
!   MATS627(n_ele_maxx) -- Mat627_struct: Array of 6x27 matrices.
!     %M(6,27)            -- 6x27 matrix.
!-

recursive subroutine ring_make_mat627 (ring, ix_ele, direction, mats627)

  use bmad_struct

  implicit none

  type (ring_struct)  ring
  type (ele_struct)  ele
  type (mat627_struct) mats627(*)

  integer direction
  integer i, ix_ele, i1, i2, i3, ix1, ix2, ix3

! make entire ring if ix_ele < 0

  if (ix_ele < 0) then

    do i = ring%n_ele_ring+1, ring%n_ele_max
      if (ring%ele_(i)%control_type /= group_lord$)  &
                                 call control_bookkeeper (ring, i)
    enddo

    do i = ring%n_ele_ring+1, ring%n_ele_max
      if (ring%ele_(i)%control_type == group_lord$)  &
                                 call control_bookkeeper (ring, i)
    enddo

    do i = 1, ring%n_ele_use
      if (ring%ele_(i)%key /= hybrid$)  &
         call make_mat627(ring%ele_(i), ring%param, direction, mats627(i))
    enddo

    return

  endif

!-----------------------------------------------------------
! otherwise make a single element

  ele = ring%ele_(ix_ele)
  call control_bookkeeper (ring, ix_ele)

! for a regular element

  if (ele%key == hybrid$) return

  if (ix_ele <= ring%n_ele_ring) then
    call make_mat627(ring%ele_(ix_ele), ring%param, direction, mats627(ix_ele))
  endif                        

! for a control element

  do i1 = ring%ele_(ix_ele)%ix1_slave, ring%ele_(ix_ele)%ix2_slave
    i = ring%control_(i1)%ix_slave
    call ring_make_mat627 (ring, i, direction, mats627)
  enddo

  return
  end

