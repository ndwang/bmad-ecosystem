module lux_module

use random_mod
use photon_init_mod
use photon_target_mod
use track1_photon_mod
use em_field_mod
use bmad

!

type lux_bend_slice_struct
  type (ele_struct) ele
  type (em_field_struct) field
  type (coord_struct) orbit
  real(rp) integrated_emit_prob    ! Probability of photon emission from element start to slice end
  real(rp) emit_prob               ! Probability of photon emission withing slice
  real(rp) g_x, g_y
  logical good_emit                ! Only generate photons in slices with %good_emit = True. Photons generated 
                                   !   in slices with good_emit = False will not make it through the aperture
end type

! %bend_slice(i) are the emission parameters at the end of the i^th slice

type photon_init_struct
  character(16) :: energy_distribution = 'GAUSSIAN'    ! 'UNIFORM' or 'GAUSSIAN'
  character(16) :: spatial_distribution = 'GAUSSIAN'   ! 'UNIFORM' or 'GAUSSIAN'
  character(16) :: velocity_distribution = 'GAUSSIAN'  ! 'SPHERICAL', 'UNIFORM' or 'GAUSSIAN'
  real(rp) :: sigma_cut = 3                            ! Cutoff for transverse Gaussion distribution.
  real(rp) :: sig_x = 0, sig_y = 0, sig_z = 0
  real(rp) :: sig_vx = 0, sig_vy = 0
  real(rp) :: sig_E = 0, dE_center = 0
  real(rp) :: e_field_x = 0, e_field_y = 0
  real(rp) :: ds_slice = 0.01                    ! Slice width for instertion devices.
  logical :: dE_relative_to_ref = .true.
  logical :: scale_initial_field_to_1 = .true.
end type

type lux_params_struct
  character(40) :: source_element = ''            ! element name
  character(40) :: detector_element = ''          ! element name
  character(40) :: photon1_element = ''           ! element name
  real(rp) :: intensity_min_det_pixel_cutoff = 1e-6
  real(rp) :: intensity_min_photon1_cutoff = 1e-6
  real(rp) :: stop_total_intensity = 10           ! stop intensity per energy
  real(rp) :: window_width = 800.0_rp, window_height = 400.0_rp  ! For plotting
  real(rp) :: intensity_normalization_coef = 1e6
  integer :: n_energy_bin_pts = 40
  integer :: stop_num_photons = 0                  ! stop number per energy
  logical :: debug = .false.     ! For debugging
  logical :: reject_dead_at_det_photon1 = .false.
end type

type lux_photon_struct
  integer n_photon_generated
  type (coord_struct), allocatable :: orb(:)
end type

type lux_common_struct
  type (lat_struct), pointer :: lat
  type (branch_struct), pointer :: s_branch, d_branch
  type (ele_struct), pointer :: source_ele, fork_ele, det_ele, photon1_ele
  integer n_bend_slice                                       ! Number of slices
  type (lux_bend_slice_struct), allocatable :: bend_slice(:) ! Size: (0:n_bend_slice)
  type (surface_grid_pt_struct), allocatable :: energy_bin(:)
  real(rp) dE_bin
  real(rp) E_min, E_max                                      ! Photon energy range 
  logical verbose
end type

type (lux_common_struct), save, target :: lux_com

contains

!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!+
! Subroutine lux_generate_photon (photon, lat, photon_init, ix_energy, lux_param)
!
! Routine to generate the starting photon coordinates
!
! Input:
!   lat           -- lat_struct: Lattice.
!   photon_init   -- photon_init_struct: 
!   ix_energy     -- Integer: Energy slice index.
!
! Ouput:
!   photon     -- lux_photon_struct: Initialized starting coords.
!-

subroutine lux_generate_photon (photon, lat, photon_init, ix_energy, lux_param)

use nr

implicit none

type (lat_struct) lat
type (lux_photon_struct), target :: photon
type (photon_init_struct) photon_init
type (coord_struct) charged_orb
type (coord_struct), pointer :: orb
type (lux_params_struct) lux_param
type (lux_bend_slice_struct), pointer :: sl(:)
type (ele_struct) ele
type (ele_struct), pointer :: source_ele

real(rp) x, y, phi, r(3), dir(2), ds, rr, r_emit(5), prob, f
real(rp) v_mat(4,4), v_inv_mat(4,4), vec(4), dE, e(3), b(3), sig_vec(6)
real(rp) g_bend(3), gamma_electron

integer ix, n_slice, ix_energy

! Init

orb => photon%orb(0)
source_ele => lux_com%source_ele

! Field

x = photon_init%e_field_x; y = photon_init%e_field_y
if (x == 0 .and. y == 0) then
  call ran_uniform(rr)
  orb%field(1) = cos(twopi * rr)
  orb%field(2) = sin(twopi * rr)
else
  if (photon_init%scale_initial_field_to_1) then
    orb%field(1) = x / sqrt(x**2 + y**2)
    orb%field(2) = y / sqrt(x**2 + y**2)
  else
    orb%field(1) = x
    orb%field(2) = y
  endif
endif

!-----------------------------------------------------
! x_ray_init source

select case (lux_com%source_ele%key)
case (x_ray_init$)

  ! Set position

  if (photon_init%spatial_distribution == 'UNIFORM') then
    call ran_uniform(r)
    r = (2 * r - 1) / 2.0
  elseif (photon_init%spatial_distribution == 'GAUSSIAN') then
    call ran_gauss(r)
  else
    print *, 'BAD PHOTON_INIT%SPATIAL_DISTRIBUTION: ', photon_init%spatial_distribution
    call err_exit
  endif

  orb%vec(1:5:2) = lat%beam_start%vec(1:5:2) + &
                    [photon_init%sig_x * r(1), photon_init%sig_y * r(2), photon_init%sig_z * r(3)]


  ! Set direction

  select case (photon_init%velocity_distribution)
  case ('SPHERICAL')
    call isotropic_photon_emission (source_ele, lat%param, orb, +1, twopi)

  case ('UNIFORM')
    call ran_uniform(dir)
    dir = 2 * dir - 1
    orb%vec(2:4:2) = lat%beam_start%vec(2:4:2) + dir * [photon_init%sig_vx, photon_init%sig_vy]
    orb%vec(6) = sqrt(1 - orb%vec(2)**2 - orb%vec(4)**2)

  case ('GAUSSIAN')
    call ran_gauss(dir)
    orb%vec(2:4:2) = lat%beam_start%vec(2:4:2) + dir * [photon_init%sig_vx, photon_init%sig_vy]
    orb%vec(6) = sqrt(1 - orb%vec(2)**2 - orb%vec(4)**2)

  end select

  ! Set energy

  if (lux_com%lat%photon_type == coherent$ .and. ix_energy > 0) then
    if (photon_init%energy_distribution == 'UNIFORM') then
      !!! rr = (ix_energy - 0.5_rp) / lux_param%n_energy_pts
    else if (photon_init%energy_distribution == 'GAUSSIAN') then
      !! rr = sqrt_2 * erfc((ix_energy - 0.5_rp) / lux_param%n_energy_pts) 
    else
      print *, 'BAD PHOTON_INIT%ENERGY_DISTRIBUTION SETTING: ', photon_init%energy_distribution 
    endif

  else
    if (photon_init%energy_distribution == 'UNIFORM') then
      call ran_uniform(rr)
      rr = (2 * rr - 1) / 2.0
    else if (photon_init%energy_distribution == 'GAUSSIAN') then
      call ran_gauss(rr)
    else
      print *, 'BAD PHOTON_INIT%ENERGY_DISTRIBUTION SETTING: ', photon_init%energy_distribution 
    endif

  endif

  orb%p0c = photon_init%sig_E * rr + photon_init%dE_center
  if (photon_init%dE_relative_to_ref) orb%p0c = orb%p0c + lux_com%source_ele%value(p0c$) 

  call init_coord (orb, orb%vec, lux_com%source_ele, upstream_end$, photon$, 1, orb%p0c) 
  orb%s = orb%vec(5) + orb%s + lux_com%source_ele%value(z_offset_tot$)
  orb%t = 0

  ! Translate from element to lab coordinates
  ! and track to entrance end of lux_com%source_ele

  call offset_photon (lux_com%source_ele, orb, unset$)

  call track_a_drift_photon (orb, -orb%s, .true.)

  return

!-----------------------------------------------------
! bend, wiggler, undulator source

case default
  sl => lux_com%bend_slice
  n_slice = ubound(sl, 1)

  ! Find where photon emitted

  call ran_uniform(rr)  ! longitudinal position
  call bracket_index (sl%integrated_emit_prob, 0, n_slice, rr, ix)
  ix = ix + 1
  if (ix == n_slice) ix = n_slice - 1
  f = (rr - sl(ix-1)%integrated_emit_prob) / (sl(ix)%integrated_emit_prob - sl(ix-1)%integrated_emit_prob)

  ! Calculate electron average position

  charged_orb = sl(ix)%orbit
  charged_orb%vec = (1-f) * sl(ix)%orbit%vec + f * sl(ix+1)%orbit%vec

  ele%a = average_twiss(1-f, sl(ix)%ele%a, sl(ix+1)%ele%a)
  ele%b = average_twiss(1-f, sl(ix)%ele%b, sl(ix+1)%ele%b)
  ele%c_mat   = (1-f) * sl(ix)%ele%c_mat   + f * sl(ix+1)%ele%c_mat
  ele%gamma_c = (1-f) * sl(ix)%ele%gamma_c + f * sl(ix+1)%ele%gamma_c
  call make_v_mats (ele, v_mat, v_inv_mat)

  ! Add offsets due to finite bunch size to the electron position.
  ! To do this must transform to the normal mode coords

  call ran_gauss(r_emit)  ! electron momentum offset.
  dE = r_emit(5) * photon_init%sig_E / lux_com%source_ele%value(p0c$)
  charged_orb%vec(6) = charged_orb%vec(6) + dE

  vec = matmul (v_inv_mat, charged_orb%vec(1:4))
  vec(1:2) = vec(1:2) + charged_orb%vec(1:2) + [ele%a%eta, ele%a%etap] * dE
  vec(3:4) = vec(3:4) + charged_orb%vec(1:2) + [ele%b%eta, ele%b%etap] * dE

  vec(1) = vec(1) + sqrt(lux_com%s_branch%a%emit * ele%a%beta) * r_emit(1)
  vec(2) = vec(2) + sqrt(lux_com%s_branch%a%emit / ele%a%beta) * (r_emit(2) - ele%a%alpha * r_emit(1))

  vec(3) = vec(3) + sqrt(lux_com%s_branch%b%emit * ele%b%beta) * r_emit(3)
  vec(4) = vec(4) + sqrt(lux_com%s_branch%b%emit / ele%b%beta) * (r_emit(4) - ele%b%alpha * r_emit(3))

  charged_orb%vec(1:4) = matmul(v_mat, vec)

  ! Calculate bending strength

  B = (1-f) * sl(ix)%field%b + f * sl(ix+1)%field%b
  E = 0
  g_bend = g_bend_from_em_field (B, E, charged_orb)
  
  ! Init photon

  gamma_electron = source_ele%value(p0c$) * (1 + sl(ix)%orbit%vec(6)) / sl(ix)%orbit%beta / mass_of(sl(ix)%orbit%species)
  if (lux_com%lat%photon_type == coherent$ .and. ix_energy > 0) then
    !!! rr = (ix_energy - 0.5_rp) / lux_param%n_energy_pts
    call bend_photon_init (g_bend(1), g_bend(2), gamma_electron, orb, E_integ_prob = rr)
  else
    call bend_photon_init (g_bend(1), g_bend(2), gamma_electron, orb, lux_com%E_min, lux_com%E_max)
  endif
  call absolute_photon_position (charged_orb, orb)

  orb%s = sl(ix-1)%ele%s + f * sl(ix)%ele%value(l$)

  ! Track to fork element.

  ds = lux_com%fork_ele%s - orb%s  

  if (source_ele%key == sbend$) then
    call track_a_bend_photon (orb, ele, ds)
  else
    call track_a_drift_photon (orb, ds, .true.)
  endif

  return
end select

end subroutine lux_generate_photon

!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!+
! Subroutine lux_setup (photon, lat, photon_init, lux_param)
!
! Routine 
!
! Input:
!   photon        -- lux_photon_struct
!   lat           -- lat_struct
!   photon_init   -- photon_init_struct: 
!   lux_param     -- lux_params_struct
!
! Output:
!   lux_com       -- Lux common block.
!-

subroutine lux_setup (photon, lat, photon_init, lux_param)

implicit none

type (lat_struct), target :: lat
type (lux_params_struct) lux_param
type (photon_init_struct) photon_init
type (lux_photon_struct), target :: photon
type (floor_position_struct) floor
type (ele_struct) twiss_ele
type (ele_struct), pointer :: ele, fork_ele
type (lux_bend_slice_struct), pointer :: sl(:)
type (coord_struct) orb
type (coord_struct), pointer :: orbit
type (branch_struct), pointer :: branch

type coord4_struct
  real(rp) vec(4)
end type
type (coord4_struct) p_coord(4)

real(rp) vz, rho, x, f
real(rp) phi, y, ds, s_now, prob1, prob2, g_bend(3), g_abs
real(rp) gamma, v_mat(4,4)

integer i, j, k, n, n_phi, n_y, ip, iy, iz, ie, iz2
integer track_state, iy0, iy1, ip0, ip1, iz0, iz1
integer n_slice, n_z, ix

logical err, hit_below_top, hit_above_bottom, hit_right_of_left_edge, hit_left_of_right_edge
logical old_hit_below_top, old_hit_above_bottom, old_hit_right_of_left_edge, old_hit_left_of_right_edge

!-------------------------------------------------------------
! Lattice has sample element.

branch => lux_com%d_branch

do ie = 1, branch%n_ele_track
  ele => branch%ele(ie)
  select case (ele%key)
  case (sample$, diffraction_plate$) 
    call photon_target_setup (ele)
  end select
enddo

!-------------------------------------------------------------
! x_ray_init source

select case (lux_com%source_ele%key)
case (x_ray_init$)
  call photon_target_setup (lux_com%source_ele)

  if (photon_init%energy_distribution == 'UNIFORM') then
    f = 1
  else
    f = 3
  endif
  lux_com%E_min = photon_init%dE_center - f * photon_init%sig_E
  lux_com%E_max = photon_init%dE_center + f * photon_init%sig_E
  if (.not. photon_init%dE_relative_to_ref) then
    lux_com%E_min = lux_com%E_min - lux_com%source_ele%value(p0c$) 
    lux_com%E_max = lux_com%E_max - lux_com%source_ele%value(p0c$) 
  endif

!-------------------------------------------------------------
! Sbend or wiggler source

case default
  call photon_target_setup (lux_com%fork_ele)
  
  n_slice = max(1, nint(lux_com%source_ele%value(l$) / photon_init%ds_slice))
  lux_com%n_bend_slice = n_slice
  allocate (lux_com%bend_slice(0:n_slice))

  lux_com%E_min = photon_init%dE_center - photon_init%sig_E
  if (photon_init%dE_relative_to_ref) lux_com%E_min = lux_com%E_min + lux_com%det_ele%value(p0c$) 
  if (photon_init%sig_E == 0) then
    lux_com%E_max = lux_com%E_min + 1d-10  ! Need some small offset for the calculation
  else
    lux_com%E_max = lux_com%E_min + 2 * photon_init%sig_E
  endif

  ! Track through source ele and gather data

  call init_coord (orb, lat%beam_start, lux_com%source_ele, upstream_end$)
  twiss_ele = pointer_to_next_ele (lux_com%source_ele, -1)
  ds = lux_com%source_ele%value(l$) / n_slice
  s_now = 0
  gamma = (orb%p0c / orb%beta) / mass_of(orb%species)
  sl => lux_com%bend_slice

  old_hit_below_top          = .false.
  old_hit_above_bottom       = .false.
  old_hit_left_of_right_edge = .false.
  old_hit_right_of_left_edge = .false.

  do i = 0, n_slice

    call transfer_ele (twiss_ele, sl(i)%ele)
    sl(i)%orbit   = orb
    call em_field_calc (lux_com%source_ele, lat%param, s_now, 0.0_rp, orb, .false., sl(i)%field)

    g_bend = g_bend_from_em_field (sl(i)%field%b, sl(i)%field%e, orb)
    g_abs = norm2(g_bend)
    prob1 = bend_photon_energy_integ_prob (lux_com%E_min, g_abs, gamma)  ! Probability per radian of bend
    prob2 = bend_photon_energy_integ_prob (lux_com%E_max, g_abs, gamma)
    sl(i)%emit_prob = g_abs * ds * (prob2 - prob1)      ! Probability per slice

    ! See if any photons will make it hit inside the aperture. If so, set %good_emit = True.
    ! Orientation: +x = left, +y = up

    hit_below_top = .false.
    hit_above_bottom = .false.
    hit_right_of_left_edge = .false.
    hit_left_of_right_edge = .false.

    call make_v_mats (twiss_ele, v_mat)
    p_coord(1)%vec = matmul(v_mat, [1.0_rp, -twiss_ele%a%alpha, 0.0_rp, 0.0_rp]) * sqrt(lux_com%s_branch%a%emit * twiss_ele%a%beta) * photon_init%sigma_cut
    p_coord(2)%vec = matmul(v_mat, [0.0_rp, 1.0_rp, 0.0_rp, 0.0_rp]) * sqrt(lux_com%s_branch%a%emit / twiss_ele%a%beta) * photon_init%sigma_cut
    p_coord(3)%vec = matmul(v_mat, [0.0_rp, 0.0_rp, 1.0_rp, -twiss_ele%b%alpha]) * sqrt(lux_com%s_branch%b%emit * twiss_ele%b%beta) * photon_init%sigma_cut
    p_coord(4)%vec = matmul(v_mat, [0.0_rp, 0.0_rp, 0.0_rp, 1.0_rp]) * sqrt(lux_com%s_branch%b%emit / twiss_ele%b%beta) * photon_init%sigma_cut

    fork_ele => lux_com%fork_ele
    do k = 1, fork_ele%photon%target%n_corner
      floor = coords_relative_to_floor (fork_ele%floor, fork_ele%photon%target%corner(k)%r)
      floor = coords_floor_to_relative (twiss_ele%floor, floor, .false.)
      do j = 1, 4
        x = p_coord(j)%vec(1) + p_coord(j)%vec(2) * floor%r(3)
        if ( x > floor%r(1)) hit_left_of_right_edge = .true.
        if (-x < floor%r(1)) hit_right_of_left_edge = .true.
        y = p_coord(j)%vec(3) + p_coord(j)%vec(4) * floor%r(3)
        if ( y > floor%r(2)) hit_above_bottom = .true.
        if (-y < floor%r(2)) hit_below_top    = .true.
      enddo
    enddo 

    sl(i)%good_emit = ((old_hit_below_top .or. hit_below_top) .and. (old_hit_above_bottom .or. hit_above_bottom) .and. &
                       (old_hit_left_of_right_edge .or. hit_left_of_right_edge) .and. (old_hit_right_of_left_edge .or. hit_right_of_left_edge))

    old_hit_below_top          = hit_below_top
    old_hit_above_bottom       = hit_above_bottom
    old_hit_left_of_right_edge = hit_left_of_right_edge
    old_hit_right_of_left_edge = hit_right_of_left_edge

    !

    call twiss_and_track_intra_ele (lux_com%source_ele, lat%param, s_now, s_now+ds, &
                                      .true., .true., orb, orb, twiss_ele, twiss_ele, err, .true.)
    if (err) call err_exit
    s_now = s_now + ds

  enddo

  sl(0)%integrated_emit_prob = 0
  do i = 1, n_slice
    if (sl(i)%good_emit) then
      sl(i)%integrated_emit_prob = sl(i)%emit_prob + sl(i-1)%integrated_emit_prob
    else
      sl(i)%integrated_emit_prob = sl(i-1)%integrated_emit_prob
    endif
  enddo
  sl%integrated_emit_prob = sl%integrated_emit_prob / sl(n_slice)%integrated_emit_prob

  if (lux_com%verbose) print '(a, i4)', &
            'Number of slices of source element to be used for photon generation:', count(sl%good_emit) 

end select

! Setup energy binning

if (lux_param%n_energy_bin_pts == 0) lux_param%n_energy_bin_pts = 1
allocate (lux_com%energy_bin(lux_param%n_energy_bin_pts))

lux_com%dE_bin = (lux_com%E_max - lux_com%E_min) / lux_param%n_energy_bin_pts
if (lux_com%dE_bin == 0) lux_com%de_bin = 1e-5

do i = 1, lux_param%n_energy_bin_pts
  lux_com%energy_bin(i)%energy_ave = lux_com%E_min + lux_com%dE_bin * (i - 0.5)
enddo
if (photon_init%dE_relative_to_ref) lux_com%energy_bin%energy_ave = lux_com%energy_bin%energy_ave - lux_com%det_ele%value(p0c$) 

end subroutine lux_setup 

end module
