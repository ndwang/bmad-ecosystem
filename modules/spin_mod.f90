module spin_mod

use bmad_struct
use bmad_interface

! right now, just for electrons (and positrons)
real(rp), parameter :: g_factor = 0.001159657

! This includes the phase of the spinor
type spin_polar_struct
  real(rp) :: theta = 0
  real(rp) :: phi   = 0
  real(rp) :: xi    = 0
end type

! Pauli Matrices
type pauli_struct
  complex(rp) sigma(2,2)
end type

! tracking maps are taylor series
type spin_map_struct
  type (taylor_term_struct), pointer :: gamma1(:) => null() ! quaternion four-vector (gamma1)
  type (taylor_term_struct), pointer :: gamma2(:) => null() ! quaternion four-vector (gamma2)
  type (taylor_term_struct), pointer :: gamma3(:) => null() ! quaternion four-vector (gamma3)
  type (taylor_term_struct), pointer :: kappa(:)  => null() ! quaternion four-vector (kappa) 
end type

type (pauli_struct) pauli(3)

logical :: init_pauli_vector = .true. ! Does pauli vector needs to be set up?
logical :: do_print = .true.

! taylor maps for elements
! Keeping map allocationg between calls should speed things up
! So, a map for each element is required

type (spin_map_struct), save, target :: maps(n_key)

private initialize_pauli_vector

real(rp), parameter :: g_factor_of(-2:2) = [g_factor_proton, g_factor_electron, 0.0_rp, &
                                            g_factor_electron, g_factor_proton]

 contains

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine Initialize_pauli_vector ()
!
! This subroutine is not intended for public use.
!
! initialize pauli vector, if needed.
!
! If init_pauli_vector = T then pauli vector will be set up.
!-

subroutine initialize_pauli_vector ()

implicit none

!

if (.not. init_pauli_vector) return

pauli(1)%sigma(1,1) = ( 0.0,  0.0)
pauli(1)%sigma(2,1) = ( 1.0,  0.0)
pauli(1)%sigma(1,2) = ( 1.0,  0.0)
pauli(1)%sigma(2,2) = ( 0.0,  0.0)

pauli(2)%sigma(1,1) = ( 0.0,  0.0)
pauli(2)%sigma(2,1) = ( 0.0,  1.0)
pauli(2)%sigma(1,2) = ( 0.0, -1.0)
pauli(2)%sigma(2,2) = ( 0.0,  0.0)

pauli(3)%sigma(1,1) = ( 1.0,  0.0)
pauli(3)%sigma(2,1) = ( 0.0,  0.0)
pauli(3)%sigma(1,2) = ( 0.0,  0.0)
pauli(3)%sigma(2,2) = (-1.0,  0.0)

init_pauli_vector = .false.

end subroutine initialize_pauli_vector

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine spinor_to_polar (coord, polar)
!
! Converts a spinor into a spin polar vector of unit length
!
! Modules needed:
!   use spin_mod
!
! Input:
!   coord%spin(2) -- coord_struct: The particle
!
! Output:
!   polar         -- Spin_polar_struct: The resultant Unitary Vector in polar coordinates
!-

subroutine spinor_to_polar (coord, polar)

implicit none

type (coord_struct) :: coord
type (spin_polar_struct) ::  polar

real(rp) phi(2), val

character(20) :: r_name = "spinor_to_polar"

!

phi(1) = atan2 (imag(coord%spin(1)), real(coord%spin(1)))
phi(2) = atan2 (imag(coord%spin(2)), real(coord%spin(2)))

polar%xi = phi(1)
polar%phi = phi(2) - phi(1)

polar%theta = 2 * atan2(abs(coord%spin(2)), abs(coord%spin(1))) 

end subroutine spinor_to_polar

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine polar_to_vec (polar, vec)
!
! Comverts a spinor in polar coordinates to a spin vector. This will ignore the
! spinor phase.
!
! Modules needed:
!   use spin_mod
!
! Input:
!   polar         -- Spin_polar_struct
!
! Output:
!   vec(3)        -- Real(3)
!-

subroutine polar_to_vec (polar, vec)

implicit none

type (spin_polar_struct) polar

real(rp) vec(3)

vec(1) = sin(polar%theta) * cos(polar%phi)
vec(2) = sin(polar%theta) * sin(polar%phi)
vec(3) = cos(polar%theta)

end subroutine polar_to_vec

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine polar_to_spinor (polar, coord)
!
! Converts a spin vector in polar coordinates to a spinor
!
! Modules needed:
!   use spin_mod
!
! Input: 
!   polar          -- spin_polar_struct: includes polar phase
!
! Output:
!   coord%spin(2)   -- coord_struct: the particle spin
!-

subroutine polar_to_spinor (polar, coord)

implicit none

type (spin_polar_struct) polar
type (coord_struct) coord

!

 coord%spin(1) = Exp(i_imaginary * polar%xi) * cos(polar%theta / 2.0d0)
 coord%spin(2) = Exp(i_imaginary * (polar%xi+polar%phi)) * sin(polar%theta / 2.0d0)

end subroutine polar_to_spinor

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine vec_to_polar (vec, polar, phase)
!
! Converts a spin vector to a spin polar
!
! Modules needed:
!   use spin_mod
!
! Input: 
!   vec(3)   -- real(rp): unitary spin vector
!   phase    -- real(rp)(Optional): Phase of the spinor, if not given then 
!                                   set to zero
! 
! Output:
!   polar    -- spin_polar_struct:
!-

subroutine vec_to_polar (vec, polar, phase)

implicit none

type (spin_polar_struct) :: polar

real(rp) vec(3)
real(rp), optional :: phase

!

polar%xi = real_option (0.0d0, phase)

if (vec(3) .eq. 0.0) then
  polar%theta = pi/2.0
else
  polar%theta = atan(sqrt(vec(1)**2 + vec(2)**2) / abs(vec(3)))
  ! get hemisphere correct
  if (vec(3) .lt. 0.0) polar%theta = pi - polar%theta
endif

polar%phi = atan2(vec(2), vec(1))

end subroutine vec_to_polar

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine spinor_to_vec (coord, vec)
!
! Converts a spinor to a spin cartesian vector
!
! Modules needed:
!   use spin_mod
!
! Input:
!   coord  -- coord_struct: the particle
!
! Output
!   vec(3) -- Real(rp): spin vector in cartesian coordinates
!-
 
subroutine spinor_to_vec (coord, vec)

implicit none

type (coord_struct) coord
! type (spin_polar_struct) polar

real(rp) vec(3)

!

! call spinor_to_polar (coord, polar)
! call polar_to_vec (polar, vec)

! vec = conjg(coord%spin) * pauli(i)%sigma * coord%spin done explicitly
vec(1) = 2.*( real(coord%spin(1))*real(coord%spin(2))+aimag(coord%spin(1))*aimag(coord%spin(2)) )
vec(2) = 2.*( real(coord%spin(1))*aimag(coord%spin(2))-aimag(coord%spin(1))*real(coord%spin(2)) )
vec(3) = real(coord%spin(1))**2+aimag(coord%spin(1))**2-real(coord%spin(2))**2-aimag(coord%spin(2))**2

end subroutine spinor_to_vec

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine vec_to_spinor (vec, coord, phase)
! 
! Converts a spin cartesian vector to a spinor.
!
! Modules needed:
!   use spin_mod
!
! Input:
!   vec(3)   -- Real(rp): spin vector in cartesian coordinates
!   phase    -- real(rp)(Optional): Phase of the spinor, if not given then 
!                                   set to zero
!
! Output:
!   spinor   -- Coord_struct: the particle
!-

subroutine vec_to_spinor (vec, coord, phase)

implicit none

type (coord_struct) coord
type (spin_polar_struct) :: polar

real(rp) vec(3)
real(rp), optional :: phase

real(rp) set_phase

!

set_phase = real_option (0.0d0, phase)

call vec_to_polar (vec, polar, set_phase)
call polar_to_spinor (polar, coord)

end subroutine vec_to_spinor

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! function angle_between_polars (polar1, polar2) result (angle)
!
! Finds the angle between two polar vectors
!
! Modules needed:
!   use spin_mod
!
! Input:
!   polar1    -- (spin_polar_struct)
!   polar2    -- (spin_polar_struct)
! 
! Output:
!   angle     -- Real(rp): Angle between the polar vectors
!-

function angle_between_polars (polar1, polar2) result (angle)

implicit none

type (spin_polar_struct), intent(in) :: polar1, polar2

real(rp) :: angle
real(rp) :: vec1(3), vec2(3)

!

call polar_to_vec (polar1, vec1)
call polar_to_vec (polar2, vec2)

angle = acos(dot_product(vec1,vec2) / (sqrt(dot_product(vec1, vec1)) * sqrt(dot_product(vec2,vec2))))

end function angle_between_polars

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine quaternion_track (a, spin)
!
! Transports a spinor through the quaternion a
!
! Modules needed:
!   use spin_mod
!
! Input:
!   a(4)       -- Real(rp): Euler four-vector (Quaternion)
!   spin(2)    -- complex(rp): Incoming spinor
!
! Output:
!   spin(2)    -- complex(rp): Resultant spinor
!-

subroutine quaternion_track (a, spin)

implicit none

complex(rp), intent(inout) :: spin(2)

real(rp), intent(in) :: a(4)

complex(rp) a_quat(2,2) ! The quaternion from the Euler parameters

!

call initialize_pauli_vector

a_quat(1,:) = [(1.0d0, 0.0d0), (0.0d0, 0.0d0)]
a_quat(2,:) = [(0.0d0, 0.0d0), (1.0d0, 0.0d0)]

a_quat = a(4) * a_quat

a_quat = a_quat - i_imaginary * &
          (a(1) * pauli(1)%sigma + a(2) * pauli(2)%sigma + a(3) * pauli(3)%sigma)

spin = matmul (a_quat, spin)

end subroutine quaternion_track

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine calc_rotation_quaternion (x, y, z, angle, a)
!
! Calculates the quaternion for a rotation of the spin vector by angle about (x,y,z)
! (x,y,z) has to be a unit vector, i.e. x*x+y*y+z*z=1
!
! Modules needed:
!   use spin_mod
!
! Input:
!   x, y, z    -- Real(rp): Rotation axis (unit vector)
!   angle      -- Real(rp): Rotation angle
!
! Output:
!   a(4)       -- Real(rp): Resultant quaternion
!-

subroutine calc_rotation_quaternion (x, y, z, angle, a)

real(rp) , intent(in) :: x, y, z, angle
real(rp) , intent(out) :: a(4)

real(rp) half_angle, s

half_angle = angle/2.
s = -sin(half_angle)

a = [x*s, y*s, z*s, cos(half_angle)]

end subroutine calc_rotation_quaternion

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! subroutine track1_spin (start_orb, ele, param, end_orb)
!
! Particle spin tracking through a single element.
!
! Uses Nonlinear Spin Transfer Maps from C. Weissbaecker and G. H. Hoffstaetter
!
! For now just does first order transport. The kappa term is determined from the
! unitarity condition.
!
! Modules needed:
!   use spin_mod
!
! Input :
!   start_orb  -- Coord_struct: Starting coords.
!   ele        -- Ele_struct: Element to track through.
!   param      -- lat_param_struct: Beam parameters.
!     %particle     -- Type of particle used
!
! Output:
!   end_orb    -- Coord_struct: Ending coords. (contains already ending %vec,
!                                               %vec may not be changed)
!      %spin(2)   -- complex(rp): Ending spinor
!-

subroutine track1_spin (start_orb, ele, param, end_orb)

implicit none

type (coord_struct), intent(in) :: start_orb
type (coord_struct) :: temp_start, temp_middle, temp_end, end_orb
type (ele_struct), intent(in) :: ele
type (lat_param_struct), intent(in) :: param
type (spin_map_struct), pointer :: map

real(rp) a(4) ! quaternion four-vector
real(rp) omega1, omega_el, xi, gamma0, gammaf, v, x, u
real(rp) alpha, phase, cos_phi, gradient, pc_start, pc_end, k_el, k_el_tilde
real(rp) e_start, e_end, g_ratio, edge_length, beta_start, beta_end
real(rp) g_factor, m_particle

integer key

logical isTreatedHere, isKicker

! Boris tracking does it's own spin tracking
if (ele%tracking_method .eq. boris$ .or. &
    ele%tracking_method .eq. adaptive_boris$) return

m_particle = mass_of(param%particle)
g_factor = g_factor_of(param%particle)

end_orb%spin = start_orb%spin     ! transfer start to end

temp_start = start_orb
temp_end   = end_orb

key = ele%key
if (.not. ele%is_on .and. key /= lcavity$) key = drift$

select case (key)
case (quadrupole$, sbend$, solenoid$, lcavity$)
  isTreatedHere = .true.
  isKicker = .false.
case (kicker$, hkicker$, vkicker$) !elseparator$
  isTreatedHere = .false.
  isKicker = .true.
case default
  isTreatedHere = .false.
  isKicker = .false.
end select

! offset particle coordinates at entrance of element
call offset_particle (ele, param, temp_start, set$, .false., .true., .false., .false.)
! offset particle coordinates at exit of element
call offset_particle (ele, param, temp_end,   set$, .false., .true., .false., .false.)

call offset_spin (ele, param, temp_start, set$, (isTreatedHere .or. isKicker))

temp_middle%spin = temp_start%spin

if(isTreatedHere) then

  ! rough estimate of particle coordinates in the element
  temp_middle%vec = (temp_start%vec + temp_end%vec)/2.

  select case (key)

  !-----------------------------------------------
  ! drift: no change to spin

!   case (drift$, rcollimator$, ecollimator$, monitor$, instrument$, pipe$) 
!
!     return

  !-----------------------------------------------
  ! kicker, separator
  ! note: these are taken into account in offset_spin

!     case (elseparator$, kicker$, hkicker$, vkicker$)
!
!     return

  !-----------------------------------------------
  ! sextupole, octupole, multipole
  ! note: these are taken into account in multipole_spin_precession,
  !       which is called in offset_spin

!     case (sextupole$, octupole$, multipole$)
!
!     return

  !-----------------------------------------------
  ! quadrupole

  case (quadrupole$)

    ! initial:
    omega1 = sqrt(abs(ele%value(k1$)))
    u = omega1*ele%value(l$)

    xi = 1 + g_factor * &
          ((1+temp_middle%vec(6)) * ele%value(E_TOT$)) / m_particle

    map => maps(quadrupole$)

    call allocate_map (map, 2, 2, 0, 0)

    map%gamma1(1)%expn(:) = [0, 0, 1, 0, 0, 0]
    map%gamma1(1)%coef   = -(1.0/2.0) * xi * omega1 * sinh(u)
    ! take into account sign of quadrupole (focusing or defocusing)
    map%gamma1(1)%coef   = sign(1.0_rp, ele%value(k1$)) * map%gamma1(1)%coef
    map%gamma1(2)%expn(:) = [0, 0, 0, 1, 0, 0]
    map%gamma1(2)%coef   = -xi * (sinh (u / 2.0))**2

    map%gamma2(1)%expn(:) = [1, 0, 0, 0, 0, 0]
    map%gamma2(1)%coef   = -(1.0/2.0) * xi * omega1 * sin(u)
    ! take into account sign of quadrupole (focusing or defocusing)
    map%gamma2(1)%coef   = sign(1.0_rp, ele%value(k1$)) * map%gamma2(1)%coef
    map%gamma2(2)%expn(:) = [0, 1, 0, 0, 0, 0]
    map%gamma2(2)%coef   = -xi * (sin (u / 2.0))**2

    ! no gamma3 terms

  !   map%kappa(1)%expn(:)  = [0, 0, 0, 0, 0, 0]
  !   map%kappa(1)%coef    = 1.0

  !-----------------------------------------------
  ! sbend
  ! does not take k1, k2 (quadrupole and sextupole terms) into account

  case (sbend$)

    gamma0 = ((1+temp_middle%vec(6)) * ele%value(E_TOT$)) / m_particle
    xi = 1 + g_factor * &
          ((1+temp_middle%vec(6)) * ele%value(E_TOT$)) / m_particle
    v = ele%value(g$)*ele%value(l$)
    x = g_factor*gamma0*v

    map => maps(sbend$)

    call allocate_map (map, 0, 4, 1, 0)

    ! No first order gamma1

    map%gamma2(1)%expn(:) = [0, 0, 0, 0, 0, 0]
    map%gamma2(1)%coef   = -sin(x / 2.0d0)
    map%gamma2(2)%expn(:) = [1, 0, 0, 0, 0, 0]
    map%gamma2(2)%coef   = -(1.0d0/2.0d0) * xi * ele%value(g$) * sin(v) * cos(x / 2.0d0)
    map%gamma2(3)%expn(:) = [0, 1, 0, 0, 0, 0]
    map%gamma2(3)%coef   = -xi * cos(x / 2.0d0) * (sin(v / 2.0d0))**2
    map%gamma2(4)%expn(:) = [0, 0, 0, 0, 0, 1]
    map%gamma2(4)%coef = ((xi * gamma0 * sin(v) - g_factor * (1+gamma0) * (gamma0-1) * v) / &
        (2.0d0 * (1+gamma0))) * cos(x / 2.0d0)

    map%gamma3(1)%expn(:) = [0, 0, 0, 1, 0, 0]
    map%gamma3(1)%coef   = (gamma0-1)/gamma0 * sin(x / 2.0d0)

  !   map%kappa(1)%expn(:) = [0, 0, 0, 0, 0, 0]
  !   map%kappa(1)%coef   = cos(x / 2.0d0)
  !   map%kappa(2)%expn(:) = [1, 0, 0, 0, 0, 0]
  !   map%kappa(2)%coef   = -(1.0/2.0) * xi * ele%value(g$) * sin(v) *  sin(x / 2.0d0)
  !   map%kappa(3)%expn(:) = [0, 1, 0, 0, 0, 0]
  !   map%kappa(3)%coef   =  -xi * (sin(v / 2.0d0))**2 * sin( x / 2.0d0)
  !   map%kappa(4)%expn(:) = [0, 0, 0, 0, 0, 1]
  !   map%kappa(4)%coef   = ((xi * gamma0 * sin(v) - g_factor * (1+gamma0) * (gamma0-1) * v) / &
  !        (2.0d0 * (1+gamma0))) * sin(x / 2.0d0)


  !-----------------------------------------------
  ! solenoid

  case (solenoid$)

    ! This is a simple zeroeth order transfer matrix

    ! rotation angle
    alpha = - (1-g_factor)*ele%value(bs_field$)*ele%value(l$) / (ele%value(p0c$)/c_light)

    map => maps(solenoid$)

    call allocate_map (map, 0, 0, 1, 0)

    map%gamma3(1)%expn(:) = [0, 0, 0, 0, 0, 0]
    map%gamma3(1)%coef   = sin(alpha/2.0)

  !   map%kappa(1)%expn(:)  = [0, 0, 0, 0, 0, 0]
  !   map%kappa(1)%coef    = cos(alpha/2.0)

  !-----------------------------------------------
  ! LCavity
  !
  ! Simulates the cavity edge field kicks as electrostatic quadrupoles
  ! since the quaternions for these have already been found.
  !
  ! Uses the fringe field as calculated by Hartman and Rosenzweig

  case (lcavity$)

    ! For now, just set to one
    g_ratio = 1

    gamma0 = ((1+temp_middle%vec(6)) * ele%value(E_TOT$)) / m_particle

    if (ele%value(E_TOT_START$) == 0) then
      print *, 'ERROR IN TRACK1_BMAD: E_TOT_START IS 0 FOR A LCAVITY!'
      call err_exit
    endif

    phase = twopi * (ele%value(phi0$) + ele%value(dphi0$) + ele%value(phi0_err$) - &
                        temp_end%vec(5) * ele%value(rf_frequency$) / c_light)
    cos_phi = cos(phase)
    gradient = (ele%value(gradient$) + ele%value(gradient_err$)) * cos_phi 
    if (.not. ele%is_on) gradient = 0

    if (bmad_com%sr_wakes_on) then
      if (bmad_com%grad_loss_sr_wake /= 0) then  
        ! use grad_loss_sr_wake and ignore e_loss
        gradient = gradient - bmad_com%grad_loss_sr_wake
      else
        gradient = gradient - ele%value(e_loss$) * param%n_part * &
                                                    e_charge / ele%value(l$)
      endif
    endif

!     if (gradient == 0) then
!       return
!     endif

    if (gradient /= 0) then
      pc_start = ele%value(p0c_start$) * (1+temp_middle%vec(6))
      call convert_pc_to (pc_start, param%particle, &
                                      E_tot = e_start, beta = beta_start)
      e_end = e_start + gradient * ele%value(l$)
      gammaf = gamma0 * (e_end / e_start)

      ! entrance kick is a focusing kick

      k_el = gradient / (2 * pc_start)
      omega_el = sqrt(k_el)

      k_el_tilde = (e_charge * k_el * (1 + g_factor + (g_factor*gamma0))) / &
                    (omega_el * e_mass * c_light**2 * (1 + gamma0))
      ! The edge field length of a cavity is about 1 quarter wavelength
      edge_length = (c_light * beta_start / ele%value(rf_frequency$)) / 4.0

      map => maps(lcavity$)

      call allocate_map (map, 2, 2, 0, 0)

      map%gamma1(1)%expn(:) = [0, 0, 1, 0, 0, 0]
      map%gamma1(1)%coef   = - (k_el_tilde/2.0) * sin (omega_el * edge_length)
      map%gamma1(2)%expn(:) = [0, 0, 0, 1, 0, 0]
      map%gamma1(2)%coef   = - (k_el_tilde/omega_el) * (sin (omega_el * edge_length / 2.0))**2

      map%gamma2(1)%expn(:) = [0, 0, 1, 0, 0, 0]
      map%gamma2(1)%coef   = - (k_el_tilde/2.0) * sin (omega_el * edge_length)
      map%gamma2(2)%expn(:) = [0, 0, 0, 1, 0, 0]
      map%gamma2(2)%coef   = - (k_el_tilde/omega_el) * (sin (omega_el * edge_length / 2.0))**2

      ! exit kick is a defocusing kick (just add to the entrance kick)

      call convert_total_energy_to (e_end, param%particle, &
                                            pc = pc_end, beta = beta_end)
      k_el = gradient / (2 * pc_end)
      omega_el = sqrt(k_el)
      k_el_tilde = (e_charge * k_el * (1 + g_factor + (g_factor*gammaf))) / &
                  (omega_el * e_mass * c_light**2 * (1 + gammaf))

      ! map%gamma1(1)%expn(:) = [0, 0, 1, 0, 0, 0]
      map%gamma1(1)%coef   = map%gamma1(1)%coef + (k_el_tilde/2.0) * sinh (omega_el * edge_length)
      ! map%gamma1(2)%expn(:) = [0, 0, 0, 1, 0, 0]
      map%gamma1(2)%coef   = map%gamma1(2)%coef + &
                                  (k_el_tilde/omega_el) * (sinh (omega_el * edge_length / 2.0))**2

      ! map%gamma2(1)%expn(:) = [0, 0, 1, 0, 0, 0]
      map%gamma2(1)%coef   = map%gamma2(1)%coef + (k_el_tilde/2.0) * sinh (omega_el * edge_length)
      ! map%gamma2(2)%expn(:) = [0, 0, 0, 1, 0, 0]
      map%gamma2(2)%coef   = map%gamma2(2)%coef + &
                                  (k_el_tilde/omega_el) * (sinh (omega_el * edge_length / 2.0))**2
    endif

  !-----------------------------------------------
  ! everything else, just use a drift
  ! This should be fixed!!!!

!  case default

  end select

  if ( (key /= lcavity$) .or. (gradient /= 0) ) then
    call compute_quaternion (map%gamma1, a(1))
    call compute_quaternion (map%gamma2, a(2))
    call compute_quaternion (map%gamma3, a(3))
    ! call compute_quaternion (map%kappa, a(4))

    a(4) = sqrt(1.0 - (a(1)**2 + a(2)**2 + a(3)**2))

    call quaternion_track (a, temp_middle%spin)
  endif
endif

temp_end%spin = temp_middle%spin

call offset_spin (ele, param, temp_end, unset$, (isTreatedHere .or. isKicker))

end_orb%spin = temp_end%spin

 contains

!-------------------------------------------------------------------------
subroutine allocate_map (map, n_gamma1, n_gamma2, n_gamma3, n_kappa)

implicit none

type (spin_map_struct) map
integer n_gamma1, n_gamma2, n_gamma3, n_kappa

!

if (n_gamma1 .eq. 0) then
  if (associated (map%gamma1)) deallocate (map%gamma1)
else
  if (.not. associated (map%gamma1)) then
    allocate(map%gamma1(n_gamma1))
  elseif (size(map%gamma1) .ne. n_gamma1) then
    deallocate(map%gamma1)
    allocate(map%gamma1(n_gamma1))
  endif
endif

if (n_gamma2 .eq. 0) then
  if (associated (map%gamma2)) deallocate (map%gamma2)
else
  if (.not. associated (map%gamma2)) then
    allocate(map%gamma2(n_gamma2))
  elseif (size(map%gamma2) .ne. n_gamma2) then
    deallocate(map%gamma2)
    allocate(map%gamma2(n_gamma2))
  endif
endif

if (n_gamma3 .eq. 0) then
  if (associated (map%gamma3)) deallocate (map%gamma3)
else
  if (.not. associated (map%gamma3)) then
    allocate(map%gamma3(n_gamma3))
  elseif (size(map%gamma3) .ne. n_gamma3) then
    deallocate(map%gamma3)
    allocate(map%gamma3(n_gamma3))
  endif
endif

if (n_kappa .eq. 0) then
  if (associated (map%kappa)) deallocate (map%kappa)
else
  if (.not. associated (map%kappa)) then
    allocate(map%kappa(n_kappa))
  elseif (size(map%kappa) .ne. n_kappa) then
    deallocate(map%kappa)
    allocate(map%kappa(n_kappa))
  endif
endif

end subroutine allocate_map

!-------------------------------------------------------------------------
subroutine compute_quaternion (map, a)

implicit none

type (taylor_term_struct), pointer :: map(:)

real(rp) a, a_part

integer i, j

!

a = 0.0
if (.not. associated(map)) return
do i = 1, size(map)
  a_part = 1.0
  do j = 1, 6
    a_part = a_part * temp_middle%vec(j)**map(i)%expn(j)
  enddo
  a_part = map(i)%coef * a_part
  a = a + a_part
enddo

end subroutine compute_quaternion

end subroutine track1_spin

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Function spin_omega_at (field, coord, ele, param), result (omega)
!
! Return the modified T-BMT spin omega vector.
!
! Omega = - Omega_TBMT / v_z
!
! Modules needed:
!   use spin_mod
!   use em_field_mod
!
! Input :
!   field      -- em_field_struct: E and B fields
!   coord      -- coord_struct: particle momentum
!   ele        -- ele_struct: element evauluated in
!      %value(E_TOT$) -- reaL(rp): needed to find momentum
!   param      -- lat_param_struct: Beam parameters.
!     %particle     -- Type of particle used
!   omega(3)   -- Real(rp): Omega in cartesian coordinates
!   s          -- Real(rp): evaluate at position s in element
!-

function spin_omega_at (field, coord, ele, param, s) result (omega)

implicit none

type (em_field_struct) :: field
type (coord_struct) :: coord
type (ele_struct) :: ele
type (lat_param_struct) :: param

real(rp) omega(3),  p_vec(3)
real(rp) g_factor, charge, m_particle, p_z, gamma0
real(rp) s, e_particle, pc, phase, cos_phi, gradient

!

call initialize_pauli_vector

! FIX_ME!!!
! get e_particle and pc at position in element
if (ele%key .eq. lcavity$) then
  phase = twopi * (ele%value(phi0$) + ele%value(dphi0$) + ele%value(phi0_err$) - &
                      coord%vec(5) * ele%value(rf_frequency$) / c_light)
  cos_phi = cos(phase)
  gradient = (ele%value(gradient$) + ele%value(gradient_err$)) * cos_phi 
  if (.not. ele%is_on) gradient = 0
  if (bmad_com%sr_wakes_on) then
    if (bmad_com%grad_loss_sr_wake /= 0) then  
      ! use grad_loss_sr_wake and ignore e_loss
      gradient = gradient - bmad_com%grad_loss_sr_wake
    else
      gradient = gradient - ele%value(e_loss$) * param%n_part * &
                                                  e_charge / ele%value(l$)
    endif
  endif
  pc = ele%value(p0c_start$) * (1 + coord%vec(6))
  call convert_pc_to (pc, param%particle, E_tot = e_particle)
  e_particle = e_particle + gradient*s
else
  pc = ele%value(p0c$) * (1 + coord%vec(6))
  call convert_pc_to (pc, param%particle, E_tot = e_particle)
endif

! want everything in units of Ev
g_factor = g_factor_of (param%particle)
charge = charge_of(param%particle)
m_particle = mass_of(param%particle)
gamma0 = e_particle / m_particle
p_z = (ele%value(p0c$)/c_light)*&
                   sqrt((1 + coord%vec(6))**2 - coord%vec(2)**2 - coord%vec(4)**2)
p_vec(1:2) = (ele%value(p0c$)/c_light)* [coord%vec(2), coord%vec(4)]
p_vec(3) = p_z

omega = (1 + g_factor*gamma0) * field%B

omega = omega - ( g_factor*dot_product(p_vec,field%B)   /&
                  ((gamma0+1)*(m_particle**2/c_light**2))  )*p_vec

omega = omega - (1/m_particle) * (g_factor + 1/(1+gamma0))*&
                   cross_product(p_vec,field%E)

omega = (charge/p_z)*omega

end function spin_omega_at

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Function normalized_quaternion (quat)
!
! Returns the normalized quaternion (preserves the spin unitarity)
!
! Modules needed:
!   use spin_mod
!
! Output :
!   quat(2,2)       -- complex(rp): the quaternion to normalize
!-

function normalized_quaternion (quat) result (quat_norm)

implicit none

complex(rp) quat(2,2), q11, q21, q12, q22, quat_norm(2,2)

real(rp) a(0:4) ! Euler four-vector

!

q11 = quat(1,1)
q21 = quat(2,1)
q12 = quat(1,2)
q22 = quat(2,2)

a(0) = (0.0, 0.0)
a(1) = (i_imaginary/2) *  (q12 + q21)
a(2) = (1/2) * (q21 - q12)
a(3) = (i_imaginary/2) * (q11 - q22)

a(0) = sqrt(1.0 - (a(1)**2 + a(2)**2 + a(3)**2))

quat_norm(1,1) = a(0) - i_imaginary * a(3)
quat_norm(2,1) = - i_imaginary * a(1) + a(2)
quat_norm(1,2) = - i_imaginary * a(1) - a(2)
quat_norm(2,2) = a(0) + i_imaginary * a(3)

end function normalized_quaternion

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine offset_spin (ele, param, coord, set, set_tilt,
!                               set_multipoles, set_hvkicks)
! Subroutine to effectively offset an element by instead offsetting
! the spin vectors to correspond to the local element coordinates.
!
! set = set$ assumes the particle is at the entrance end of the element.
! set = unset$ assumes the particle is at the exit end of the element.
!
! Options:
!   Using the element tilt in the offset.
!   Using the HV kicks.
!   [Using the multipoles.]
!
! Modules Needed:
!   use bmad
!
! Input:
!   ele       -- Ele_struct: Element
!     %value(x_pitch$)  -- Horizontal roll of element.
!     %value(y_pitch$)  -- Vertical roll of element.
!     %value(tilt$)     -- Tilt of element.
!     %value(roll$)     -- Roll of dipole.
!   coord     -- Coord_struct: Coordinates of the particle.
!     %spin(2)          -- Particle spin
!   param     -- lat_param_struct:
!     %particle   -- What kind of particle (for elseparator elements).
!   set       -- Logical:
!                   T (= set$)   -> Translate from lab coords to the local 
!                                     element coords.
!                   F (= unset$) -> Translate back to lab coords.
!   set_tilt       -- Logical, optional: Default is True.
!                   T -> Rotate using ele%value(tilt$) and 
!                            ele%value(roll$) for sbends.
!                   F -> Do not rotate
!   set_multipoles -- Logical, optional: Default is True.
!                   T -> 1/2 of the multipole is applied.
!   set_hvkicks    -- Logical, optional: Default is True.
!                   T -> Apply 1/2 any hkick or vkick.
!
! Output:
!     coord -- Coord_struct: Coordinates of particle.
!
! Currently not implemented: elseparators
!-

subroutine offset_spin (ele, param, coord, set, set_tilt, &
                              set_multipoles, set_hvkicks)

use bmad_interface

implicit none

type (ele_struct), intent(in) :: ele
type (lat_param_struct), intent(in) :: param
type (coord_struct), intent(inout) :: coord

real(rp), save :: old_angle = 0, old_roll = 0
real(rp), save :: del_x_vel = 0, del_y_vel = 0
real(rp) angle, a_gamma_plus, a(4)

logical, intent(in) :: set
logical, optional, intent(in) :: set_tilt, set_multipoles
logical, optional, intent(in) :: set_hvkicks
logical set_multi, set_hv, set_t, set_hv1, set_hv2

!---------------------------------------------------------------

set_multi = logic_option (.true., set_multipoles) .and. (associated(ele%a_pole) .or. ele%key==sextupole$ .or. ele%key==octupole$)
set_hv    = logic_option (.true., set_hvkicks) .and. ele%is_on .and. &
                   (has_kick_attributes(ele%key) .or. has_hkick_attributes(ele%key))
set_t     = logic_option (.true., set_tilt)  .and. has_orientation_attributes(ele%key)


! return if there is nothing to do
if ( (x_pitch_tot$==0.) .and. (y_pitch_tot$==0.) .and. (.not. set_multi) &
                        .and. (.not. set_hv) .and. (.not. set_t) ) then
  return
endif

if (set_hv) then
  select case (ele%key)
  case (elseparator$, kicker$, hkicker$, vkicker$)
    set_hv1 = .false.
    set_hv2 = .true.
  case default
    set_hv1 = .true.
    set_hv2 = .false.
  end select
else
  set_hv1 = .false.
  set_hv2 = .false.
endif

if (set_t .and. ele%key == sbend$) then
  angle = ele%value(l$) * ele%value(g$)
  if (angle /= old_angle .or. ele%value(roll$) /= old_roll) then
    if (ele%value(roll$) == 0) then
      del_x_vel = 0
      del_y_vel = 0
    else if (abs(ele%value(roll$)) < 0.001) then
      del_x_vel = angle * ele%value(roll$)**2 / 4
      del_y_vel = -angle * sin(ele%value(roll$)) / 2
    else
      del_x_vel = angle * (1 - cos(ele%value(roll$))) / 2
      del_y_vel = -angle * sin(ele%value(roll$)) / 2
    endif
    old_angle = angle
    old_roll = ele%value(roll$)
  endif
endif

a_gamma_plus = g_factor_of(param%particle) * ele%value(e_tot$) * (1 + coord%vec(6)) / mass_of(param%particle) + 1

!----------------------------------------------------------------
! Set...

if (set) then

  ! Setting s_offset done already in offset_particle

  ! Set: (Offset and) pitch
  ! contrary to offset_particle no dependence on E_rel
  call calc_rotation_quaternion (0._rp, -1._rp, 0._rp, ele%value(x_pitch_tot$), a)
  call quaternion_track (a, coord%spin)
  call calc_rotation_quaternion (1._rp, 0._rp, 0._rp, ele%value(y_pitch_tot$), a)
  call quaternion_track (a, coord%spin)

  ! Set: HV kicks for quads, etc. but not hkicker, vkicker, elsep and kicker elements.
  ! HV kicks must come after s_offset but before any tilts are applied.
  ! Note: Since this is applied before tilt_coords, kicks are independent of any tilt.

  if (set_hv1) then
      call calc_rotation_quaternion (0._rp, -1._rp, 0._rp, a_gamma_plus * ele%value(hkick$) / 2, a)
      call quaternion_track (a, coord%spin)
      call calc_rotation_quaternion (1._rp, 0._rp, 0._rp, a_gamma_plus * ele%value(vkick$) / 2, a)
      call quaternion_track (a, coord%spin)
  endif

  ! Set: Multipoles

  if (set_multi) then
    call multipole_spin_precession (ele, param%particle, coord%vec, coord%spin, .true., &
                               .true., (ele%key==multipole$ .or. ele%key==ab_multipole$))
  endif

  ! Set: Tilt
  ! A non-zero roll has a zeroth order effect that must be included

  if (set_t) then

    if (ele%key == sbend$) then
      if (ele%value(roll$) /= 0) then
        call calc_rotation_quaternion (0._rp, -1._rp, 0._rp, -a_gamma_plus * del_x_vel, a)
        call quaternion_track (a, coord%spin)
        call calc_rotation_quaternion (1._rp, 0._rp, 0._rp, -a_gamma_plus * del_y_vel, a)
        call quaternion_track (a, coord%spin)
      endif
      call calc_rotation_quaternion (0._rp, 0._rp, 1._rp, ele%value(tilt_tot$)+ele%value(roll$), a)
      call quaternion_track (a, coord%spin)
    else
      call calc_rotation_quaternion (0._rp, 0._rp, 1._rp, ele%value(tilt_tot$), a)
      call quaternion_track (a, coord%spin)
    endif

  endif

  ! Set: HV kicks for kickers and separators only.
  ! Note: Since this is applied after tilt_coords, kicks are dependent on any tilt.

  if (set_hv2) then
    if (ele%key == elseparator$) then
!     NOT IMPLEMENTED YET
!       if (param%particle < 0) then
!       else
!       endif
    elseif (ele%key == hkicker$) then
      call calc_rotation_quaternion (0._rp, -1._rp, 0._rp, a_gamma_plus * ele%value(kick$) / 2, a)
      call quaternion_track (a, coord%spin)
    elseif (ele%key == vkicker$) then
      call calc_rotation_quaternion (1._rp, 0._rp, 0._rp, a_gamma_plus * ele%value(kick$) / 2, a)
      call quaternion_track (a, coord%spin)
    else ! i.e. elseif (ele%key == kicker$) then
      call calc_rotation_quaternion (0._rp, -1._rp, 0._rp, a_gamma_plus * ele%value(hkick$) / 2, a)
      call quaternion_track (a, coord%spin)
      call calc_rotation_quaternion (1._rp, 0._rp, 0._rp, a_gamma_plus * ele%value(vkick$) / 2, a)
      call quaternion_track (a, coord%spin)
    endif
  endif

!----------------------------------------------------------------
! Unset...

else

  ! Unset: HV kicks for kickers and separators only.

  if (set_hv2) then
    if (ele%key == elseparator$) then
!     NOT IMPLEMENTED YET
!       if (param%particle < 0) then
!       else
!       endif
    elseif (ele%key == hkicker$) then
      call calc_rotation_quaternion (0._rp, -1._rp, 0._rp, a_gamma_plus * ele%value(kick$) / 2, a)
      call quaternion_track (a, coord%spin)
    elseif (ele%key == vkicker$) then
      call calc_rotation_quaternion (1._rp, 0._rp, 0._rp, a_gamma_plus * ele%value(kick$) / 2, a)
      call quaternion_track (a, coord%spin)
    else ! i.e. elseif (ele%key == kicker$) then
      call calc_rotation_quaternion (1._rp, 0._rp, 0._rp, a_gamma_plus * ele%value(vkick$) / 2, a)
      call quaternion_track (a, coord%spin)
      call calc_rotation_quaternion (0._rp, -1._rp, 0._rp, a_gamma_plus * ele%value(hkick$) / 2, a)
      call quaternion_track (a, coord%spin)
    endif
  endif


  ! Unset: Tilt

  if (set_t) then

    if (ele%key == sbend$) then
      call calc_rotation_quaternion (0._rp, 0._rp, 1._rp, -(ele%value(tilt_tot$)+ele%value(roll$)), a)
      call quaternion_track (a, coord%spin)
      if (ele%value(roll$) /= 0) then
        call calc_rotation_quaternion (1._rp, 0._rp, 0._rp, -a_gamma_plus * del_y_vel, a)
        call quaternion_track (a, coord%spin)
        call calc_rotation_quaternion (0._rp, -1._rp, 0._rp, -a_gamma_plus * del_x_vel, a)
        call quaternion_track (a, coord%spin)
      endif
    else
      call calc_rotation_quaternion (0._rp, 0._rp, 1._rp, -ele%value(tilt_tot$), a)
      call quaternion_track (a, coord%spin)
    endif

  endif

  ! Unset: Multipoles
  if (set_multi) then
    call multipole_spin_precession (ele, param%particle, coord%vec, coord%spin, .true., &
                               .true., (ele%key==multipole$ .or. ele%key==ab_multipole$))
  endif

  ! UnSet: HV kicks for quads, etc. but not hkicker, vkicker, elsep and kicker elements.
  ! HV kicks must come after s_offset but before any tilts are applied.

  if (set_hv1) then
      call calc_rotation_quaternion (1._rp, 0._rp, 0._rp, a_gamma_plus * ele%value(vkick$) / 2, a)
      call quaternion_track (a, coord%spin)
      call calc_rotation_quaternion (0._rp, -1._rp, 0._rp, a_gamma_plus * ele%value(hkick$) / 2, a)
      call quaternion_track (a, coord%spin)
  endif

  ! Unset: (Offset and) pitch

  call calc_rotation_quaternion (1._rp, 0._rp, 0._rp, -ele%value(y_pitch_tot$), a)
  call quaternion_track (a, coord%spin)
  call calc_rotation_quaternion (0._rp, -1._rp, 0._rp, -ele%value(x_pitch_tot$), a)
  call quaternion_track (a, coord%spin)

endif

end subroutine offset_spin


!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine multipole_spin_precession (ele, particle, vec, spin, do_half_prec, &
!                                       include_sextupole_octupole, ref_orb_offset)
!
! Subroutine to track the spins in a multipole field
!
! Modules Needed:
!   use multipole_mod, only: multipole_ele_to_ab
!
! Input:
!   ele              -- Ele_struct: Element
!     %value(x_pitch$)        -- Horizontal roll of element.
!     %value(y_pitch$)        -- Vertical roll of element.
!     %value(tilt$)           -- Tilt of element.
!     %value(roll$)           -- Roll of dipole.
!   particle         -- Integer: What kind of particle.
!   vec              -- Real(rp): Coordinates of the particle.
!   spin(2)          -- Complex(rp): Incoming spinor
!   do_half_prec     -- Logical, optional: Default is False.
!                          Apply half multipole effect only (for kick-drift-kick model)
!   include_sextupole_octupole  -- Logical, optional: Default is False.
!                          Include the effects of sextupoles and octupoles
!                          (since there are currently not implemented in track1_spin)
!   ref_orb_offset   -- Logical, optional: Default is False.
!                          Rotate the local coordinate system according to the
!                          the dipole component of the multipole
!
! Output:
!   spin(2)          -- Complex(rp): Resultant spinor
!-

subroutine multipole_spin_precession (ele, particle, vec, spin, do_half_prec, &
                                      include_sextupole_octupole, ref_orb_offset)

use multipole_mod, only: multipole_ele_to_ab

implicit none

type (ele_struct), intent(in) :: ele

logical, optional, intent(in) :: do_half_prec, include_sextupole_octupole, ref_orb_offset
logical half_prec, sext_oct, ref_orb

complex(rp), intent(inout) :: spin(2)

real(rp), intent(in) :: vec(6)
real(rp) an(0:n_pole_maxx), bn(0:n_pole_maxx), kick_angle, Bx, By, knl, a_coord(4), a_field(4)

complex(rp) kick, pos

integer, intent(in) :: particle
integer n

!

half_prec = logic_option (.false., do_half_prec)
sext_oct  = logic_option (.false., include_sextupole_octupole)
ref_orb   = logic_option (.false., ref_orb_offset)

call multipole_ele_to_ab(ele, particle, an, bn, .true.)

select case (ele%key)
  case (sextupole$)
    knl = ele%value(k2$)*ele%value(l$)
  case (octupole$)
    knl = ele%value(k3$)*ele%value(l$)
  case default
    knl = 0.
end select

if (half_prec) then
  an  = an/2.
  bn  = bn/2.
  knl = knl/2.
endif

if (sext_oct) then
  ! add half effect of element to take sextupoles/octupoles into account (kick-drift-kick model)
  select case (ele%key)
  case (sextupole$)
    bn(2) = bn(2) + knl*cos(3.*ele%value(tilt_tot$))/2.
    an(2) = an(2) - knl*sin(3.*ele%value(tilt_tot$))/2.
  case (octupole$)
    bn(3) = bn(3) + knl*cos(4.*ele%value(tilt_tot$))/6.
    an(3) = an(3) - knl*sin(4.*ele%value(tilt_tot$))/6.
  end select
endif

! calculate kick_angle (for particle) and unit vector (Bx, By) parallel to B-field
! according to bmad manual, chapter "physics", section "Magnetic Fields"
! kick = qL/P_0*(B_y+i*Bx) = \sum_n (b_n+i*a_n)*(x+i*y)^n
kick = bn(0)+i_imaginary*an(0)

if (ref_orb) then
  ! calculate rotation of local coordinate system due to dipole component
  kick_angle = abs(kick)
  if ( kick_angle == 0. ) then
    ref_orb = .false.
  else
    Bx = aimag(kick / kick_angle)
    By = real (kick / kick_angle)
    call calc_rotation_quaternion(Bx, By, 0._rp, -kick_angle, a_coord)
  endif
endif

pos = vec(1)+i_imaginary*vec(3)
if (pos /= 0.) then
  kick = kick + (bn(1)+i_imaginary*an(1))*pos
  do n = 2, n_pole_maxx
    pos = pos * (vec(1)+i_imaginary*vec(3))
    kick = kick + (bn(n)+i_imaginary*an(n))*pos
  enddo
endif

kick_angle = abs(kick)
if ( kick_angle /= 0. ) then
  kick = kick / kick_angle
  Bx = aimag(kick)
  By = real(kick)
  ! precession_angle = kick_angle*(a*gamma+1)
  kick_angle = kick_angle * (g_factor_of(particle) * ele%value(e_tot$) * &
                        (1 + vec(6)) / mass_of(particle) + 1)
  call calc_rotation_quaternion(Bx, By, 0._rp, kick_angle, a_field)
  call quaternion_track (a_field, spin)
endif

if (ref_orb) then
  call quaternion_track (a_coord, spin)
endif

end subroutine multipole_spin_precession

end module spin_mod


