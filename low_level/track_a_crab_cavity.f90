!+
! Subroutine track_a_rfcavity (orbit, ele, param, mat6, make_matrix)
!
! Bmad_standard tracking through an crab_cavity element.
!
! Input:
!   orbit       -- Coord_struct: Starting position.
!   ele         -- ele_struct: crab_cavity element.
!   param       -- lat_param_struct: Lattice parameters.
!   make_matrix -- logical, optional: Propagate the transfer matrix? Default is false.
!
! Output:
!   orbit      -- coord_struct: End position.
!   mat6(6,6)  -- real(rp), optional: Transfer matrix through the element.
!-

subroutine track_a_crab_cavity (orbit, ele, param, mat6, make_matrix)

use fringe_mod, except_dummy => track_a_crab_cavity

implicit none

type (coord_struct) :: orbit
type (ele_struct), target :: ele
type (lat_param_struct) :: param

real(rp), optional :: mat6(6,6)
real(rp) voltage, phase0, phase, t0, length, charge_dir, dt_ref, beta_ref
real(rp) k_rf, dl

integer i, n_slice, orientation

logical, optional :: make_matrix

!

call offset_particle (ele, param, set$, orbit, mat6 = mat6, make_matrix = make_matrix)

length = ele%value(l$)
!n_slice = max(1, nint(length / ele%value(ds_step$))) 
n_slice = 1
dl = length / n_slice
charge_dir = rel_tracking_charge_to_mass(orbit, param) * ele%orientation
voltage = e_accel_field(ele, voltage$) * charge_dir / (ele%value(p0c$) * n_slice)
beta_ref = ele%value(p0c$) / ele%value(e_tot$)
dt_ref = length / (c_light * beta_ref)
k_rf = twopi * ele%value(rf_frequency$) / c_light

!call rf_coupler_kick (ele, param, first_track_edge$, phase, orbit, mat6, make_matrix)

! Track through slices.

call track_this_drift(orbit, dl/2, ele, phase, mat6, make_matrix)

do i = 1, n_slice

  phase0 = twopi * (ele%value(phi0$) + ele%value(phi0_multipass$) + ele%value(phi0_autoscale$) - &
          (particle_rf_time (orbit, ele, .false.) - rf_ref_time_offset(ele)) * ele%value(rf_frequency$))
  if (ele%orientation == -1) phase0 = phase0 + twopi * ele%value(rf_frequency$) * dt_ref
  phase = phase0

  if (logic_option(.false., make_matrix)) then
    mat6(2,:) = mat6(2,:) + voltage * k_rf * cos(phase) * mat6(5,:)
    mat6(6,:) = mat6(6,:) + voltage * k_rf * (cos(phase) * mat6(1,:) - &
                                                  sin(phase) * k_rf * orbit%vec(1) * mat6(5,:))
  endif

  orbit%vec(2) = orbit%vec(2) + voltage * sin(phase)
  orbit%vec(6) = orbit%vec(6) + voltage * cos(phase) * k_rf * orbit%vec(1)

  if (i == n_slice) exit
  call track_this_drift(orbit, dl, ele, phase, mat6, make_matrix)

enddo

call track_this_drift(orbit, dl/2, ele, phase, mat6, make_matrix)

! coupler kick, multipoles, back to lab coords.

!call rf_coupler_kick (ele, param, second_track_edge$, phase, orbit, mat6, make_matrix)

call offset_particle (ele, param, unset$, orbit, mat6 = mat6, make_matrix = make_matrix)

!-------------------------
contains

subroutine track_this_drift (orbit, dl, ele, phase, mat6, make_matrix)

type (coord_struct) orbit
type (ele_struct) ele
real(rp) mat6(6,6)
real(rp) z, dl, phase
logical make_matrix

!

z = orbit%vec(5)
call track_a_drift (orbit, dl, mat6, make_matrix)
!! phase = phase + twopi * ele%value(rf_frequency$) * (orbit%vec(5) - z) / (c_light * orbit%beta)

end subroutine track_this_drift

end subroutine
