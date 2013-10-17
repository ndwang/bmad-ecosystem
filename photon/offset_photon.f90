!+
! Subroutine offset_photon (ele, orbit, set, offset_position_only)
!
! Routine to effectively offset an element by instead offsetting
! the photon position and field to correspond to the local element coordinates.
!
! Modules Needed:
!   use bmad
!
! Input:
!   ele       -- Ele_struct: Element
!   orbit     -- Coord_struct: Coordinates of the particle.
!   set       -- Logical: 
!                   T (= set$)   -> Translate from lab coords to local 
!                                     element coords.
!                   F (= unset$) -> Translate from outgoing local coords to lab coords.
!   offset_position_only
!           -- Logical, optional: If present and True, only offset the position coordinates.
!
! Output:
!     orbit -- Coord_struct: Coordinates of particle.
!-

subroutine offset_photon (ele, orbit, set, offset_position_only)

use track1_mod, dummy => offset_photon

implicit none

type (ele_struct), target :: ele
type (coord_struct), target :: orbit

real(rp) graze2, offset(6), tilt, r(3), rot_angle, sin_g, cos_g, cos_t, sin_t
real(rp) off(3), rot(3), project(3,3), rot_mat(3,3), s, vec6_0
real(rp), pointer :: p(:), vec(:)

complex(rp) field(2)

logical :: set
logical, optional :: offset_position_only
logical is_reflective_element

character(*), parameter :: r_name = 'offset_photon'

!

select case (ele%key)
case (crystal$, mirror$, multilayer_mirror$)
  is_reflective_element = .true.
case default
  is_reflective_element = .false.
end select

p   => ele%value  ! parameter
vec => orbit%vec

!----------------------------------------------------------------
! Set...

if (set) then

  vec6_0 = vec(6)

  ! Set: Offsets

  vec(1) = vec(1) - p(x_offset_tot$)
  vec(3) = vec(3) - p(y_offset_tot$)
  vec(5) = vec(5) - p(z_offset_tot$)

  ! Set: pitch

  if (p(x_pitch_tot$) /= 0 .or. p(y_pitch_tot$) /= 0) then
    call floor_angles_to_w_mat(p(x_pitch_tot$), p(y_pitch_tot$), 0.0_rp, w_mat_inv = rot_mat)
    r = [vec(1), vec(3), vec(5) - ele%value(l$)/2]
    vec(1:5:2) = matmul(rot_mat, r)
    vec(5) = vec(5) + ele%value(l$)/2
    vec(2:6:2) = matmul(rot_mat, vec(2:6:2))
  endif

  ! Set: tilt

  tilt = p(tilt_tot$)
  if (ele%key == crystal$) tilt = tilt + p(tilt_corr$)
  call tilt_coords (tilt, vec)

  ! Set: intensity and phase rotation due to the tilt

  if (.not. logic_option(.false., offset_position_only)) then

    field = [orbit%field(1) * cmplx(cos(orbit%phase(1)), sin(orbit%phase(1))), &
             orbit%field(2) * cmplx(cos(orbit%phase(2)), sin(orbit%phase(2)))]

    field = [cos(tilt) * field(1) + sin(tilt)*field(2), &
            -sin(tilt) * field(1) + cos(tilt)*field(2)]

    orbit%field(1) = abs(field(1))
    orbit%phase(1) = atan2(aimag(field(1)), real(field(1)))

    orbit%field(2) = abs(field(2))
    orbit%phase(2) = atan2(aimag(field(2)), real(field(2)))
  endif

  ! Set: Rotate to ele coords. 

  select case (ele%key)
  case (crystal$)
    rot_angle = p(bragg_angle_in$) 
    if (p(b_param$) < 0) rot_angle = rot_angle - pi/2  ! Bragg
  case (mirror$, multilayer_mirror$)
    rot_angle = p(graze_angle$) - pi/2
  case default
    rot_angle = 0
  end select

  if (rot_angle /= 0) then
    sin_g = sin(rot_angle)
    cos_g = cos(rot_angle)

    if (p(ref_tilt_tot$) == 0) then
      orbit%vec(2:6:2) = [cos_g * orbit%vec(2) + sin_g * orbit%vec(6), orbit%vec(4), &
                         -sin_g * orbit%vec(2) + cos_g * orbit%vec(6)]
      orbit%vec(1:5:2) = [cos_g * orbit%vec(1) + sin_g * orbit%vec(5), orbit%vec(3), &
                         -sin_g * orbit%vec(1) + cos_g * orbit%vec(5)]
    else
      cos_t = cos(p(ref_tilt_tot$)); sin_t = sin(p(ref_tilt_tot$))
      rot_mat(1,:) = [cos_g * cos_t**2 + sin_t**2, (cos_g - 1) * cos_t * sin_t, cos_t * sin_g]
      rot_mat(2,:) = [(cos_g - 1) * cos_t * sin_t, cos_g * sin_t**2 + cos_t**2, sin_g * sin_t]
      rot_mat(3,:) = [-cos_t * sin_g, -sin_g * sin_t, cos_g]
      orbit%vec(2:6:2) = matmul(rot_mat, orbit%vec(2:6:2))
      orbit%vec(1:5:2) = matmul(rot_mat, orbit%vec(1:5:2))
    endif
  endif

  ! Transport to z = 0.
  ! Track_a_drift_photon assumes particle is in lab coords so need to correct s-position

  if (.not. logic_option(.false., offset_position_only)) then
    if (orbit%vec(5) /= 0) then
      s = orbit%s - orbit%vec(5) * vec6_0 / vec(6)
      call track_a_drift_photon (orbit, -orbit%vec(5))
      if (orbit%state /= alive$) return
      orbit%s = s
    endif
  endif

!----------------------------------------------------------------
! Unset... 

else

  ! reflective element...

  if (is_reflective_element) then

    select case (ele%key)
    case (crystal$)
      rot_angle = p(bragg_angle_out$)
      if (p(b_param$) < 0) rot_angle = rot_angle + pi/2  ! Bragg
    case (mirror$, multilayer_mirror$)
      rot_angle = p(graze_angle$) + pi/2
    end select

    sin_g = sin(rot_angle)
    cos_g = cos(rot_angle)

    ! Translate momentum to laboratory exit coords
    ! and compute position, backpropagating the ray.

    if (p(ref_tilt_tot$) == 0) then
      orbit%vec(2:6:2) = [cos_g * orbit%vec(2) + sin_g * orbit%vec(6), orbit%vec(4), &
                         -sin_g * orbit%vec(2) + cos_g * orbit%vec(6)]

      orbit%vec(1:5:2) = [cos_g * orbit%vec(1) + sin_g * orbit%vec(5), orbit%vec(3), &
                         -sin_g * orbit%vec(1) + cos_g * orbit%vec(5)]
    else
      cos_t = cos(p(ref_tilt_tot$)); sin_t = sin(p(ref_tilt_tot$))
      rot_mat(1,:) = [cos_g * cos_t**2 + sin_t**2, (cos_g - 1) * cos_t * sin_t, cos_t * sin_g]
      rot_mat(2,:) = [(cos_g - 1) * cos_t * sin_t, cos_g * sin_t**2 + cos_t**2, sin_g * sin_t]
      rot_mat(3,:) = [-cos_t * sin_g, -sin_g * sin_t, cos_g]
      orbit%vec(2:6:2) = matmul(rot_mat, orbit%vec(2:6:2))
      orbit%vec(1:5:2) = matmul(rot_mat, orbit%vec(1:5:2))
    endif

    if (.not. logic_option(.false., offset_position_only)) then
      orbit%vec(1:5:2) = orbit%vec(1:5:2) - orbit%vec(2:6:2) * (orbit%vec(5) / orbit%vec(6))
    endif

    ! Unset: tilt_tot
    ! The difference between ref_tilt_tot and tilt_tot is that ref_tilt_tot also rotates the output 
    ! laboratory coords but tilt_tot does not. 
    ! The difference between tilt_tot with Set vs Unset is that the tilt_tot is 
    ! expressed in terms of the input lab coords.

    select case (ele%key)
    case (mirror$, multilayer_mirror$)
      graze2 = 2*p(graze_angle$)
      tilt = p(tilt_tot$)
    case (crystal$)
      graze2 = p(bragg_angle_in$)+p(bragg_angle_out$)
      tilt = p(tilt_tot$) + p(tilt_corr$)
    end select

    ! project is the entrance coords in terms of the exit coords.
    ! EG: project(1,:) is the entrance x-axis in the exit coords.

    rot = [sin(p(ref_tilt_tot$)), -cos(p(ref_tilt_tot$)), 0.0_rp]
    call axis_angle_to_w_mat (rot, graze2, project)

    if (tilt /= 0) then
      call axis_angle_to_w_mat (project(3,:), tilt, rot_mat)
      vec(1:5:2) = matmul(rot_mat, vec(1:5:2))
      vec(2:6:2) = matmul(rot_mat, vec(2:6:2))
    endif

    ! Unset: pitch
    ! Since the pitches are with respect to the lab input coord system, we have
    ! to translate to the local output coords.

    if (p(y_pitch_tot$) /= 0) then
      call axis_angle_to_w_mat (-project(1,:), p(y_pitch_tot$), rot_mat)
      vec(1:5:2) = matmul(rot_mat, vec(1:5:2))
      vec(2:6:2) = matmul(rot_mat, vec(2:6:2))
    endif

    if (p(x_pitch_tot$) /= 0) then
      call axis_angle_to_w_mat (project(2,:), p(x_pitch_tot$), rot_mat)
      vec(1:5:2) = matmul(rot_mat, vec(1:5:2))
      vec(2:6:2) = matmul(rot_mat, vec(2:6:2))
    endif

    ! Unset: offset
    ! Translate offsets to the local output coords.

    off = project(1,:) * p(x_offset_tot$) + project(2,:) * p(y_offset_tot$) + &
          project(3,:) * p(z_offset_tot$)

    vec(1:5:2) = vec(1:5:2) + off

  ! non-reflective element

  else

    ! Unset: tilt

    tilt = p(tilt_tot$)
    call tilt_coords (-tilt, vec)
    rot = 0

    ! Unset: Pitch

    if (p(x_pitch_tot$) /= 0 .or. p(y_pitch_tot$) /= 0) then
      call floor_angles_to_w_mat(p(x_pitch_tot$), p(y_pitch_tot$), 0.0_rp, w_mat = rot_mat)
      r = [vec(1), vec(3), vec(5) - ele%value(l$)/2]
      vec(1:5:2) = matmul(rot_mat, r)
      vec(5) = vec(5) + ele%value(l$)/2
      vec(2:6:2) = matmul(rot_mat, vec(2:6:2))
    endif

    ! Unset: X and Y Offsets

    vec(1) = vec(1) + p(x_offset_tot$)
    vec(3) = vec(3) + p(y_offset_tot$)
    vec(5) = vec(5) + p(z_offset_tot$)

  endif

  ! Unset: Transport to element nominal end.
  ! The s-position calc breaks down for reflective elements in track_a_drift_photon so 
  ! simply set orbit%s to what it should be.

  if (logic_option(.false., offset_position_only)) return

  if (vec(5) /= ele%value(l$)) then
    call track_a_drift_photon (orbit, ele%value(l$) - vec(5))
    if (orbit%state /= alive$) return
    orbit%s = ele%s
  endif

  ! Unset: intensities

  field = [cmplx(orbit%field(1)*cos(orbit%phase(1)), orbit%field(1)*sin(orbit%phase(1))), &
           cmplx(orbit%field(2)*cos(orbit%phase(2)), orbit%field(2)*sin(orbit%phase(2)))]

  tilt = tilt + rot(3)
  field = [cos(tilt) * field(1) - sin(tilt)*field(2), &
           sin(tilt) * field(1) + cos(tilt)*field(2)]

  orbit%field(1) = abs(field(1))
  orbit%phase(1) = atan2(aimag(field(1)),real(field(1)))

  orbit%field(2) = abs(field(2))
  orbit%phase(2) = atan2(aimag(field(2)),real(field(2)))

endif

end subroutine
                          

