module synrad3d_struct

use bmad_struct
use bmad_interface
use twiss_and_track_mod
use photon_reflection_mod
use wall3d_mod

type sr3d_photon_wall_hit_struct
  type (coord_struct) before_reflect    ! Coords before reflection.
  type (coord_struct) after_reflect     ! Coords after reflection.
  real(rp) dw_perp(3)                   ! Wall perpendicular vector
  real(rp) cos_perp_in                  ! Cosine of incoming ray and hit angle
  real(rp) cos_perp_out                 ! Cosine of hit angle
  real(rp) reflectivity                 ! Reflectivity probability
end type

type sr3d_coord_struct
  type (coord_struct) orb
  integer :: ix_wall_section = not_set$      ! Wall section index.
  integer :: ix_wall3d = 1                   ! branch%wall3d(:) index where photon is within.             
end type  

! This structure defines the full track of the photon from start to finish
! %start           -- Starting position.
! %old             -- Used by the tracking code. Not useful otherwise.
! %now             -- Present position. At the end of tracking, %now will be the final position.
! %wall_hit(:)     -- Records the positions at which the photon hit the wall
!                       including the final position. The array bounds are: %hit(1:%n_hit) 
! %crossed_lat_end -- Did the photon cross from the end of the lattice to the beginning
!                       or vice versa?
! %ix_photon       -- Unfiltered photon index. 
! %ix_photon_generated -- The first photon generated has index 1, etc.
! %n_wall_hit      -- Number of wall hits.

type sr3d_photon_track_struct
  type (sr3d_coord_struct) start, old, now  ! positions
  logical :: crossed_lat_end = .false.      ! Photon crossed through the lattice beginning or end?
  integer :: ix_photon                      ! Photon index.
  integer :: ix_photon_generated
  integer :: n_wall_hit = 0                 ! Number of wall hits
  integer :: status                         ! is_through_wall$, at_wall_end$, or inside_the_wall$
end type

!------------------------------------------------------------------------
! Some parameters that can be set. 

type sr3d_params_struct
  type (random_state_struct) ran_state
  real(rp) :: ds_track_step_max = 3     ! Maximum longitudinal distance in one photon "step".
  real(rp) :: dr_track_step_max = 0.1   ! Maximum tranverse distance in one photon "step".
  real(rp) :: significant_length = 1d-10
  logical :: allow_reflections = .true. ! If False, terminate tracking when photon hits the wall.
  logical :: allow_absorption = .true.  ! If False, do not allow photon to be adsorbed.
  logical :: specular_reflection_only = .false.
  logical :: debug_on = .false.
  integer ix_generated_warn             ! For debug use
end type

type (sr3d_params_struct), save :: sr3d_params

! Some parameters that cannot be set

type sr3d_walls_struct
  integer, allocatable :: ix_wall3d(:)
end type

type sr3d_common_struct
  type (sr3d_walls_struct), allocatable :: fast(:) 
end type

type (sr3d_common_struct), target, save :: sr3d_com

! Misc

integer, parameter :: is_through_wall$ = 0, at_wall_end$ = 1, inside_the_wall$ = 2, at_transverse_wall$ = 4

type sr3d_plot_param_struct
  real(rp) :: window_width = 800.0_rp, window_height = 400.0_rp
  integer :: n_pt = 1000
end type

end module
