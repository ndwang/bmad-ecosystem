!+
! Subroutine track_a_foil (orbit, ele, param, mat6, make_matrix)
!
! Bmad_standard tracking through an foil element.
!
! From Eq. (6) in 
!   Approximations to Multiple Coulomb Scattering
!   Gerald R. Lynch and Orin Dahl
!   Nuclear Insturments and methods in Physics Research B58 (7991) 6-10.
!
! Input:
!   orbit       -- Coord_struct: Starting position.
!   ele         -- ele_struct: foil element.
!   param       -- lat_param_struct: Lattice parameters.
!   make_matrix -- logical, optional: Propagate the transfer matrix? Default is False.
!
! Output:
!   orbit      -- coord_struct: End position.
!   mat6(6,6)  -- real(rp), optional: Transfer matrix through the element.
!-

subroutine track_a_foil (orbit, ele, param, mat6, make_matrix)

use bmad_interface, except_dummy => track_a_foil
use xraylib, dummy => r_e
use random_mod

implicit none

type (coord_struct) :: orbit, orb0
type (ele_struct), target :: ele
type (lat_param_struct) :: param

real(rp), optional :: mat6(6,6)
real(rp) x0, xx0, sigma, rnd(2), density, I_excite, mass_material, dE_dx, E0, E1, pc, p2, elec_density
real(rp), parameter :: S2 = 13.6e6_dp, epsilon = 0.088 ! Factor of 1e6 is due to original formula using MeV/c for momentum

integer i, n, material, z_material, z_part, n_step

logical, optional :: make_matrix

character(*), parameter :: r_name = 'track_a_foil'

!

material = species_id(ele%component_name)
x0 = x0_radiation_length(material)   ! kg/m^2
if (x0 == real_garbage$) then
  call out_io(s_error$, r_name, 'CANNOT HANDLE NON-ATOMIC MATERIAL_TYPE: ' // species_name(material))
  orbit%state = lost$
  return
endif

z_material = atomic_number(material)
density = ElementDensity(z_material) * 1e3_rp  ! From xraylib. Convert to kg/m^3

! Angle scatter

z_part = atomic_number(orbit%species)
xx0 = ele%value(thickness$) / (x0 / density)
sigma = S2 * z_part * sqrt(xx0) / (orbit%p0c * orbit%beta) * (1.0_rp + epsilon * log10(xx0*z_part**2/orbit%beta**2))

call ran_gauss(rnd)
orbit%vec(2) = orbit%vec(2) + rnd(1) * sigma
orbit%vec(4) = orbit%vec(4) + rnd(2) * sigma

! Energy loss

I_excite = mean_excitation_energy_over_z(z_material) * z_material
mass_material = mass_of(material) / atomic_mass_unit
elec_density = N_avogadro * density * z_material / (1.0e-3_rp * mass_material)   ! number_electrons / m^3

n_step = nint(ele%value(num_steps$))
do i = 1, n_step
  p2 = (orbit%p0c * (1.0_rp + orbit%vec(6)) / mass_of(orbit%species))**2  ! beta^2 / (1 - beta^2) term
  dE_dx = -fourpi * mass_of(electron$) * elec_density * (z_part * r_e / orbit%beta)**2 * &
              (log(2 * mass_of(electron$) * p2 / I_excite) - orbit%beta**2)
  E0 = orbit%p0c * (1.0_rp + orbit%vec(6)) / orbit%beta
  E1 = E0 + dE_dx * ele%value(thickness$) / n_step
  call convert_total_energy_to(E1, orbit%species, beta = orbit%beta, pc = pc)
  orbit%vec(6) = (pc - orbit%p0c) / orbit%p0c
enddo

! Charge

n = nint(ele%value(final_charge$))
orbit%species = set_species_charge(orbit%species, n)

!

if (logic_option(.false., make_matrix)) then
  call mat_make_unit(mat6)
endif

end subroutine track_a_foil
