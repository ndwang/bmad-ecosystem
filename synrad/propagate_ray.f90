!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------

subroutine propagate_ray (ray, s_end, ring)

  use sr_struct
  use sr_interface

  implicit none

  type (ring_struct), target :: ring
  type (ray_struct), target :: ray

  real(rp) s_end, s_next, del_s, s_target
  real(rp) rho, new_x, theta0, theta1, c_t0, c_t1

! find the target

  s_target = s_end

  if ((s_target - ray%now%vec(5)) * ray%direction < 0) s_target = &
          s_target + ray%direction * ring%param%total_length

  if (abs(s_target - ray%now%vec(5)) > 200) then
    type *, ' ERROR IN PROPAGATE_RAY: TRYING TO PROPAGATE TOO FAR.'
    type *, '      ', ray%now%vec(5), s_end, s_target
    call err_exit
  endif

! update old (but only if we have moved or gone thorough the IP)

  if (s_target == ray%now%vec(5) .and. &
            abs(s_end - ray%now%vec(5)) /= ring%param%total_length) return

  ray%old = ray%now

! propagate the ray until we get to s_end

  propagation_loop: do

! If we are crossing over to a new element then update ray%ix_ele.
! Additionally, if we cross the ring end we need to reset ray%now%vec(5) and ray%ix_ele.
! Note: Since we can be going "backwards" to find a shadow then ray%crossed_end
! can toggle from true to false.

    if (ray%direction == 1) then
      do
        if (ray%now%vec(5) .ge. ring%ele_(ray%ix_ele)%s) then
          ray%ix_ele = ray%ix_ele + 1
          if (ray%ix_ele > ring%n_ele_ring) then
            ray%ix_ele = 1
            ray%now%vec(5) = ray%now%vec(5) - ring%param%total_length
            s_target = s_target - ring%param%total_length
            ray%crossed_end = .not. ray%crossed_end
          endif
        elseif (ray%now%vec(5) .lt. ring%ele_(ray%ix_ele-1)%s) then
          ray%ix_ele = ray%ix_ele - 1
          if (ray%ix_ele == 0) then
            type *, 'ERROR IN PROPAGATE_RAY: INTERNAL + ERROR'
            call err_exit
          endif
        else
          exit
        endif
      enddo

    else   ! direction = -1
      do
        if (ray%now%vec(5) .le. ring%ele_(ray%ix_ele-1)%s) then
          ray%ix_ele = ray%ix_ele - 1
          if (ray%ix_ele .le. 0) then
            ray%ix_ele = ring%n_ele_ring
            ray%now%vec(5) = ray%now%vec(5) + ring%param%total_length
            s_target = s_target + ring%param%total_length
            ray%crossed_end = .not. ray%crossed_end
          endif
        elseif (ray%now%vec(5) .gt. ring%ele_(ray%ix_ele)%s) then
          ray%ix_ele = ray%ix_ele + 1
          if (ray%ix_ele == ring%n_ele_ring+1) then
            type *, 'ERROR IN PROPAGATE_RAY: INTERNAL - ERROR'
            call err_exit
          endif
        else
          exit
        endif
      enddo
    endif

    if (ray%direction == 1) then
      s_next = min (s_target, ring%ele_(ray%ix_ele)%s)
    else
      s_next = max (s_target, ring%ele_(ray%ix_ele-1)%s)
    endif

    del_s = s_next - ray%now%vec(5)

! In a bend: Exact formula is:
! new_x = (rho * (cos(theta0) - cos(theta1)) + ray%now%vec(1) * cos(theta0)) /
!                                                              cos(theta1)

    if (ring%ele_(ray%ix_ele)%key == sbend$) then
      rho = ring%ele_(ray%ix_ele)%value(rho$)
      theta0 = ray%now%vec(2)
      theta1 = ray%now%vec(2) + del_s / rho
      c_t0 = -(theta0**2)/2 + theta0**4/24
      c_t1 = -(theta1**2)/2 + theta1**4/24
      new_x = (rho * (c_t0 - c_t1) + ray%now%vec(1) * cos(theta0)) / cos(theta1)
      ray%now%vec(1) = new_x
      ray%now%vec(2) = theta1
    else
      ray%now%vec(1) = ray%now%vec(1) + del_s * tan(ray%now%vec(2))
    endif

    ray%now%vec(3) = ray%now%vec(3) + del_s * tan(ray%now%vec(4))

    ray%track_len = ray%track_len + abs(del_s)
    ray%now%vec(5) = s_next

    if (s_next == s_target) return

  enddo propagation_loop

end subroutine
