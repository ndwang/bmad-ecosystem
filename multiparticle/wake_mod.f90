module wake_mod

use multipole_mod
use random_mod

contains

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine randomize_lr_wake_frequencies (ele, set_done)
! 
! Routine to randomize the frequencies of the lr wake HOMs according to:
!   freq = freq_in * (1 + lr_freq_spread) * rr)
! where rr is a Gaussian distributed random number with unit variance.
!
! Modules needed:
!   use wake_mod
!
! Input:
!   ele -- ele_struct: Element with wake. If no wake then nothing is done.
!      %value(freq_in$)        -- Frequency.
!
! Output:
!   ele      -- ele_struct: Element with wake frequencies set.
!     %wake%lr_mode(:)%freq -- Set frequency.
!   set_done -- Logical, optional: Set True if there where lr wakes to be set.
!                 False otherwise.
!-

subroutine randomize_lr_wake_frequencies (ele, set_done)

implicit none

type (ele_struct) ele
logical, optional :: set_done
integer n
real(rp) rr

!

if (present(set_done)) set_done = .false.
if (ele%wake%lr_freq_spread == 0 .or. .not. associated(ele%wake)) return

do n = 1, size(ele%wake%lr_mode)
  call ran_gauss (rr)
  if (ele%wake%lr_mode(n)%freq_in < 0) cycle
  ele%wake%lr_mode(n)%freq = ele%wake%lr_mode(n)%freq_in * (1 + ele%wake%lr_freq_spread * rr)
  if (present(set_done)) set_done = .true.
enddo

end subroutine randomize_lr_wake_frequencies

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine zero_lr_wakes_in_lat (lat)
!
! Routine to zero the long range wake amplitudes for the elements that have
! long range wakes in a lattice.
!
! Modules needed:
!   use wake_mod
!
! Input:
!   lat -- Lat_struct: Lattice
!
! Output:
!   lat -- Lat_struct: Lattice
!     %ele(:) -- Lattice elements
!       %wake%lr_mode(:)%b_sin -> Set to zero
!       %wake%lr_mode(:)%b_cos -> Set to zero
!       %wake%lr_mode(:)%a_sin -> Set to zero
!       %wake%lr_mode(:)%a_cos -> Set to zero
!-       

subroutine zero_lr_wakes_in_lat (lat)

implicit none

type (lat_struct) lat
integer i

!

do i = 1, lat%n_ele_max
  if (.not. associated(lat%ele(i)%wake)) cycle
  lat%ele(i)%wake%lr_mode%b_sin = 0; lat%ele(i)%wake%lr_mode%b_cos = 0
  lat%ele(i)%wake%lr_mode%a_sin = 0; lat%ele(i)%wake%lr_mode%a_cos = 0
  lat%ele(i)%wake%lr_mode%t_ref = 0
enddo

end subroutine zero_lr_wakes_in_lat

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine track1_lr_wake (bunch, ele)
!
! Subroutine to put in the long-range wakes for particle tracking.
!
! Modules needed:
!   use wake_mod
!
! Input:
!   ele         -- ele_struct: Element with wakes.
!   bunch       -- bunch_struct: Bunch to track.
!
! Output:
!   ele         -- Ele_struct: Element with updated wake amplitudes.
!   bunch       -- bunch_struct: Kicked bunch.
!+

subroutine track1_lr_wake (bunch, ele)

implicit none

type (bunch_struct), target :: bunch
type (ele_struct) ele
type (coord_struct), pointer :: particle
type (wake_lr_mode_struct), pointer :: lr

real(rp) t0, dt, dt_phase, kx0, ky0, ff0, w_norm, w_skew
real(rp) omega, f_exp, ff, c_dt, s_dt, kx, ky, kick_self, vec(6)
real(rp) c_a, s_a, kxx, exp_shift, a_sin, b_sin, charge, t_cut
real(rp) da_sin, da_cos, db_sin, db_cos

integer n_mode, i, j, k, i0, n

! Check to see if we need to do any calc

if (.not. bmad_com%lr_wakes_on) return
if (.not. associated(ele%wake)) return
if (bunch%n_live == 0) return

if (.not. associated(ele%wake)) return
if (ele%wake%wake_amp_scale == 0) return

!

n_mode = size(ele%wake%lr_mode)
if (n_mode == 0) return  

! To prevent floating point overflow, the %a and %b factors are shifted 
! to be with respect to lr%t_ref which is the wake reference time.

i0 = bunch%ix_z(1)
t0 = bunch%particle(i0)%t   ! Time of particle at head of bunch.

do i = 1, size(ele%wake%lr_mode)
  lr => ele%wake%lr_mode(i)

  omega = twopi * lr%freq
  f_exp = lr%damp
  dt = ele%wake%wake_time_scale * (t0 - lr%t_ref)
  exp_shift = exp(-dt * f_exp)

  lr%t_ref = t0
  lr%b_sin = exp_shift * lr%b_sin
  lr%b_cos = exp_shift * lr%b_cos
  lr%a_sin = exp_shift * lr%a_sin
  lr%a_cos = exp_shift * lr%a_cos

  ! Need to shift a_sin, etc, since particle z is with respect to the bunch center.
  if (lr%freq_in >= 0) then  ! If not fundamental mode
    c_dt = cos (dt * omega)
    s_dt = sin (dt * omega)
    b_sin = lr%b_sin
    lr%b_sin =  c_dt * b_sin + s_dt * lr%b_cos
    lr%b_cos = -s_dt * b_sin + c_dt * lr%b_cos
    a_sin = lr%a_sin
    lr%a_sin =  c_dt * a_sin + s_dt * lr%a_cos
    lr%a_cos = -s_dt * a_sin + c_dt * lr%a_cos
  endif
enddo

! Loop over all modes: kick particles and update wakes.

do i = 1, size(ele%wake%lr_mode)

  lr => ele%wake%lr_mode(i)

  omega = twopi * lr%freq
  f_exp = lr%damp

  if (lr%polarized) then
    c_a = cos(twopi*lr%angle)
    s_a = sin(twopi*lr%angle)
  endif

  !

  kick_self = 0
  da_sin = 0; da_cos = 0; db_sin = 0; db_cos = 0

  do k = 1, size(bunch%particle)
    particle => bunch%particle(k)
    if (particle%state /= alive$) cycle

    dt = ele%wake%wake_time_scale * (particle%t - lr%t_ref)
    ff0 = ele%wake%wake_amp_scale * abs(particle%charge) * lr%r_over_q

    dt_phase = dt
    if (lr%freq_in < 0) dt_phase = dt_phase + ele%value(phi0_multipass$) / omega ! Fundamental mode phase shift

    c_dt =  cos (dt_phase * omega + twopi * lr%phi)
    s_dt = -sin (dt_phase * omega + twopi * lr%phi)

    ! The spatial variation of the normal and skew
    ! components is the same as the spatial variation of a multipole kick.

    call ab_multipole_kick (0.0_rp, 1.0_rp, lr%m, particle%species, +1, particle, kx0, ky0)

    ! Accumulate longitudinal self-wake

    if (ele%wake%lr_self_wake_on) then
      ff = ff0 * omega / (2 * ele%value(p0c$))

      kx = ff * kx0
      ky = ff * ky0

      if (lr%polarized) then
        w_norm = -(kx * c_a * c_a + ky * s_a * c_a)
        w_skew = -(kx * c_a * s_a + ky * s_a * s_a)
      else
        w_norm = -kx
        w_skew = -ky
      endif

      kick_self = kick_self + (w_norm * kx0 + w_skew * ky0) * cos(twopi * lr%phi)
    endif

    ! Longitudinal non-self-wake kick

    ff = exp(-dt * f_exp) / ele%value(p0c$)

    w_norm = (lr%b_sin * ff * (f_exp * s_dt + omega * c_dt) + lr%b_cos * ff * (f_exp * c_dt - omega * s_dt)) / c_light
    w_skew = (lr%a_sin * ff * (f_exp * s_dt + omega * c_dt) + lr%a_cos * ff * (f_exp * c_dt - omega * s_dt)) / c_light

    particle%vec(6) = particle%vec(6) + w_norm * kx0 + w_skew * ky0

    ! Transverse wake kick (Note: Transverse has no self-wake kick)

    if (lr%m /= 0) then
      w_norm = lr%b_sin * ff * s_dt + lr%b_cos * ff * c_dt
      w_skew = lr%a_sin * ff * s_dt + lr%a_cos * ff * c_dt

      call ab_multipole_kick (w_skew, w_norm, lr%m-1, particle%species, +1, particle, kx, ky)

      particle%vec(2) = particle%vec(2) + lr%m * kx
      particle%vec(4) = particle%vec(4) + lr%m * ky
    endif

    ! Update wake amplitudes

    ff = ff0 * c_light * exp(dt * f_exp) 

    if (lr%polarized) then
      kx = ff * (kx0 * c_a * c_a + ky0 * s_a * c_a)
      ky = ff * (kx0 * c_a * s_a + ky0 * s_a * s_a)
    else
      kx = ff * kx0 
      ky = ff * ky0
    endif

    db_sin = db_sin - kx * c_dt
    db_cos = db_cos + kx * s_dt
    da_sin = da_sin - ky * c_dt
    da_cos = da_cos + ky * s_dt

  enddo  ! Particles

  ! Add to wake mode.

  lr%b_sin = lr%b_sin + db_sin
  lr%b_cos = lr%b_cos + db_cos
  lr%a_sin = lr%a_sin + da_sin
  lr%a_cos = lr%a_cos + da_cos

  ! Longitudinal self-wake kick. 

  if (ele%wake%lr_self_wake_on) then
    do k = 1, size(bunch%particle)
      particle => bunch%particle(k)
      particle%vec(6) = particle%vec(6) + kick_self
    enddo
  endif

enddo  ! Wake modes

end subroutine track1_lr_wake

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine sr_long_wake_particle (ele, orbit)
!
! Routine to apply the short-range wake longitudinal component kick to a particle and then add 
! to the existing longitudinal wake the contribution from the particle.
!
! Modules needed:
!   use wake_mod
!
! Input:
!   ele     -- Ele_struct: Element with wakes.
!   orbit   -- Coord_struct: Particle coords.
!
! Output:
!   ele     -- Ele_struct: Element with wakes.
!   orbit   -- Coord_struct: coords after the kick.
!+

subroutine sr_long_wake_particle (ele, orbit)

type (ele_struct), target :: ele
type (wake_sr_mode_struct), pointer :: mode
type (coord_struct) orbit

integer i
real(rp) arg, ff, c, s, dz, exp_factor, w_norm

!

if (ele%wake%wake_amp_scale == 0) return
dz = ele%wake%wake_time_scale * (orbit%vec(5) - ele%wake%sr_long%z_ref) ! Should be negative
ele%wake%sr_long%z_ref = orbit%vec(5)

! Check if we have to do any calculations

do i = 1, size(ele%wake%sr_long%mode)

  mode => ele%wake%sr_long%mode(i)

  ! Kick particle

  exp_factor = exp(dz * mode%damp)

  arg = ele%wake%wake_time_scale * orbit%vec(5) * mode%k
  c = cos (arg)
  s = sin (arg)

  if (ele%wake%sr_wake_scale_with_length) then
    ff = ele%wake%wake_amp_scale * abs(orbit%charge) * mode%amp * ele%value(l$) / ele%value(p0c$)
  else
    ff = ele%wake%wake_amp_scale * abs(orbit%charge) * mode%amp / ele%value(p0c$)
  endif

  w_norm = mode%b_sin * exp_factor * s + mode%b_cos * exp_factor * c

  select case (mode%transverse_dependence)
  case (none$, linear_leading$)
    orbit%vec(6) = orbit%vec(6) - w_norm
  case default  ! linear_trailing$
    if (mode%polarization == x_polarization$) then
      orbit%vec(6) = orbit%vec(6) - w_norm * orbit%vec(1)
    else  ! y_axis
      orbit%vec(6) = orbit%vec(6) - w_norm * orbit%vec(3)
    endif
  end select

  ! Self kick

  select case (mode%transverse_dependence)
  case (none$)
    orbit%vec(6) = orbit%vec(6) - ff * sin(mode%phi) / 2
  case default  ! linear_leading or linear_trailing
    if (mode%polarization == x_polarization$) then
      orbit%vec(6) = orbit%vec(6) - orbit%vec(1) * ff * sin(mode%phi) / 2
    else  ! y_axis
      orbit%vec(6) = orbit%vec(6) - orbit%vec(3) * ff * sin(mode%phi) / 2
    endif
  end select

  ! Add to wake

  arg = mode%phi - ele%wake%wake_time_scale * orbit%vec(5) * mode%k
  c = cos (arg)
  s = sin (arg)

  ! The monopole wake does not have any skew components.

  select case (mode%transverse_dependence)
  case (none$, linear_trailing$)
    mode%b_sin = mode%b_sin * exp_factor + ff * c
    mode%b_cos = mode%b_cos * exp_factor + ff * s
  case default
    if (mode%polarization == x_polarization$) then
      mode%b_sin = mode%b_sin * exp_factor + orbit%vec(1) * ff * c
      mode%b_cos = mode%b_cos * exp_factor + orbit%vec(1) * ff * s
    else  ! y_axis
      mode%b_sin = mode%b_sin * exp_factor + orbit%vec(3) * ff * c
      mode%b_cos = mode%b_cos * exp_factor + orbit%vec(3) * ff * s
    endif
  end select

enddo

end subroutine sr_long_wake_particle

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine sr_trans_wake_particle (ele, orbit)
!
! Subroutine to apply the short-range wake transverse component of the kick to a particle and then add 
! to the existing transverse wale the contribution from the particle.
!
! Modules needed:
!   use wake_mod
!
! Input:
!   ele     -- Ele_struct: Element with wakes.
!   orbit   -- Coord_struct: Starting particle coords.
!
! Output:
!   ele     -- Ele_struct: Element with wakes.
!   orbit   -- Coord_struct: Ending particle coords.
!+

subroutine sr_trans_wake_particle (ele, orbit)

type (ele_struct), target :: ele
type (wake_sr_mode_struct), pointer :: mode
type (coord_struct) orbit

integer i
real(rp) arg, ff, c, s, dz, exp_factor, w_norm, w_skew

!

if (ele%wake%wake_amp_scale == 0) return
dz = ele%wake%wake_time_scale * (orbit%vec(5) - ele%wake%sr_trans%z_ref) ! Should be negative
ele%wake%sr_trans%z_ref = orbit%vec(5)

! Add to wake

do i = 1, size(ele%wake%sr_trans%mode)

  mode => ele%wake%sr_trans%mode(i)

  ! Kick particle...

  exp_factor = exp(dz * mode%damp)

  arg = ele%wake%wake_time_scale * orbit%vec(5) * mode%k
  c = cos (arg)
  s = sin (arg)

  ! X-axis kick

  if (mode%polarization /= y_polarization$) then
    w_norm = mode%b_sin * exp_factor * s + mode%b_cos * exp_factor * c
    if (mode%transverse_dependence == linear_trailing$) then
      orbit%vec(2) = orbit%vec(2) - w_norm * orbit%vec(1)
    else
      orbit%vec(2) = orbit%vec(2) - w_norm
    endif
  endif

  ! Y-axis kick

  if (mode%polarization /= x_polarization$) then
    w_skew = mode%a_sin * exp_factor * s + mode%a_cos * exp_factor * c
    if (mode%transverse_dependence == linear_trailing$) then
      orbit%vec(4) = orbit%vec(4) - w_skew * orbit%vec(3)
    else
      orbit%vec(4) = orbit%vec(4) - w_skew
    endif
  endif

  ! Add to wake...

  if (ele%wake%sr_wake_scale_with_length) then
    ff = ele%wake%wake_amp_scale * abs(orbit%charge) * mode%amp * ele%value(l$) / ele%value(p0c$)
  else
    ff = ele%wake%wake_amp_scale * abs(orbit%charge) * mode%amp / ele%value(p0c$)
  endif

  arg =  mode%phi - ele%wake%wake_time_scale * orbit%vec(5) * mode%k
  c = cos (arg)
  s = sin (arg)

  ! Add to x-axis wake (b_sin, b_cos)

  if (mode%polarization /= y_polarization$) then
    if (mode%transverse_dependence == linear_leading$) then
      mode%b_sin = mode%b_sin * exp_factor + ff * c * orbit%vec(1)
      mode%b_cos = mode%b_cos * exp_factor + ff * s * orbit%vec(1)
    else
      mode%b_sin = mode%b_sin * exp_factor + ff * c
      mode%b_cos = mode%b_cos * exp_factor + ff * s
    endif
  endif

  ! Add to y-axis wake (a_sin, a_cos)

  if (mode%polarization /= x_polarization$) then
    if (mode%transverse_dependence == linear_leading$) then
      mode%a_sin = mode%a_sin * exp_factor + ff * c * orbit%vec(3)
      mode%a_cos = mode%a_cos * exp_factor + ff * s * orbit%vec(3)
    else
      mode%a_sin = mode%a_sin * exp_factor + ff * c
      mode%a_cos = mode%a_cos * exp_factor + ff * s
    endif
  endif

enddo

end subroutine sr_trans_wake_particle

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine order_particles_in_z (bunch)
!
! Routine to order the particles longitudinally in terms of decreasing %vec(5).
! That is from large z (head of bunch) to small z.
! Only live particles are ordered.
!
! Modules needed:
!   use beam_mod
!
! Input:
!   bunch     -- Bunch_struct: collection of particles.
!     %particle(j)%vec(5) -- Longitudinal position of j^th particle.
!
! Output:
!   bunch     -- bunch_struct: collection of particles.
!     %ix_z(:)   -- Index for the ordering. 
!                   Order is from large z (head of bunch) to small z.
!                   That is: %bunch%ix_z(1) is the particle at the bunch head.
!                   Only live particles are ordered so if particle with index %bunch%ix_z(i)
!                     is dead, all particles with index %bunch%ix_z(j) with j > i are dead.
!-

Subroutine order_particles_in_z (bunch)

use nr, only: indexx

implicit none

type (bunch_struct), target :: bunch
type (coord_struct), pointer :: particle(:)
type (coord_struct) temp
integer ix, k, nm, i0, i1, n_max, kk
real(rp) z1, z2

! Init if needed. 

particle => bunch%particle
n_max = size(particle)
nm = n_max

! If first time through

if (bunch%ix_z(1) < 1) then
  call indexx (bunch%particle%vec(5), bunch%ix_z)
  bunch%ix_z(1:nm) = bunch%ix_z(nm:1:-1)
endif

! Order is from large z (head of bunch) to small z.
! This ordering calc is efficient when the particles are already more-or-less ordered to start with.  

ix = 1
do
  if (ix > nm) exit
  i0 = bunch%ix_z(ix)

  if (particle(i0)%state /= alive$) then
    bunch%ix_z(ix:nm) = [bunch%ix_z(ix+1:nm), i0]
    nm = nm - 1
    cycle
  endif

  if (ix >= nm) exit
  i1 = bunch%ix_z(ix+1)

  if (particle(i1)%state /= alive$) then
    bunch%ix_z(ix+1:nm) = [bunch%ix_z(ix+2:nm), i1]
    nm = nm - 1
    cycle
  endif

  if (particle(i0)%vec(5) < particle(i1)%vec(5)) then
    do k = ix-1, 1, -1
      kk = bunch%ix_z(k)
      if (particle(kk)%vec(5) >= particle(i1)%vec(5)) exit
    enddo
  
    bunch%ix_z(k+1:ix+1) = [bunch%ix_z(ix+1), bunch%ix_z(k+1:ix)]
  endif

  ix = ix + 1
enddo

bunch%n_live = nm

end subroutine order_particles_in_z

end module
