!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! subroutine get_initial_pt (ray, wall, ix_wall, ring)
!
! subroutine to
!  
!
! Modules needed:
!   use sr_mod
!
! Input:
!   ray    -- ray_struct:
!   wall   -- wall_struct: inside wall with outline ready
!   ix_wall -- integer:
!   ring   -- ring_struct with twiss propagated and mat6s made
!
! Output:
!                         
!-

subroutine get_initial_pt (ray, wall, ix_wall, ring)

  use sr_struct
  use sr_interface

  implicit none

  type (ray_struct) ray
  type (wall_struct) wall
  type (ring_struct) ring

  integer ix_wall, ix, ix0, ix1, ix2


  if (wall%n_pt_tot == 0) then
    print *, 'There are no points in the wall!'
    print *, 'You should check the wall first with check_wall!'
    call err_exit
  endif


! point ix_wall is at or just downstream of ray%now%vec(5).

! edge cases

  if (ray%now%vec(5) == ring%param%total_length) then
    if (ray%direction == 1) then
      ix_wall = 0
      wall%ix_pt = 0
    else
      ix_wall = wall%n_pt_tot
      wall%ix_pt = wall%n_pt_tot
    endif
    return
  endif

  if (ray%now%vec(5) == 0) then
    if (ray%direction == 1) then
      ix_wall = wall%n_pt_tot
      wall%ix_pt = wall%n_pt_tot
    else
      ix_wall = 0
      wall%ix_pt = 0
    endif
    return
  endif

! normal case. divide and conquer.

  ix0 = 0
  ix2 = wall%n_pt_tot

  do
    ix1 = (ix2 + ix0) / 2
    ix = wall%pt(ix1)%ix_pt
    if (wall%pt(ix)%s < ray%now%vec(5)) then
      ix0 = ix1
    elseif (wall%pt(ix)%s > ray%now%vec(5)) then
      ix2 = ix1
    elseif (ray%direction == 1) then   ! here wall%pt(ix)%s == ray%now%vec(5)
      ix2 = ix1
    else
      ix0 = ix1
    endif
    if (ix2 - ix0 == 1) then
      if (ray%direction == 1) then
        ix_wall = wall%pt(ix2)%ix_pt
        wall%ix_pt = ix2
      else
        ix_wall = wall%pt(ix0)%ix_pt
        wall%ix_pt = ix0
      endif
      return
    endif
  enddo

end subroutine
