!+
! Subroutine twiss_at_start (ring)
!
! Subroutine to calculate the twiss parameters at the start of the ring
! Note: This subroutine calculates ring%ele%mat6 under the condition that
! the RF is off. That is, that the longitudinal motion is "decoupled"
! from the transverse.
!
! Modules needed:
!   use bmad
!
! Input:
!   ring   -- Ring_struct: Ring
!   bmad_status -- BMAD Common block status structure
!     %type_out  -- Logical: If .true. then will type a message for
!                       non ok$ STATUS
!
! Output:
!   ring
!     %param%t1_mat4  --  Note: Only the linear part is computed.
!                          Matrix Type           ring%param%symmetry
!                          --------              -----------
!                          1-turn   (see note)   none$
!                          1/2-turn (see note)   ew_anti_symmetric$
!     %ele_(0)%x     -- X Twiss parameters at the start of the ring.
!     %ele_(0)%y     -- Y Twiss parameters at the start of the ring.
!     %ele_(0)%c_mat -- Coupling matrix.
!     %x%tune        -- Fractional part of the tune in radians
!     %y%tune        -- Fractional part of the tune in radians
!     %param%stable  -- Set true or false.
!     %param%growth_rate -- unstable growth rate (= 0 if stable)
! 
!   bmad_status  -- BMAD Common block status structure
!     %ok            -- Logical: .True. if everything is OK, False otherwise.
!     %status        -- Integer: Calculation status.
!                        See MAT_SYMP_DECOUPLE for for more info
!-

#include "CESR_platform.inc"

subroutine twiss_at_start (ring)

  use bmad_struct
  use bmad_interface

  implicit none

  type (ring_struct)  ring

  real(rp) eta_vec(4), t0_4(4,4), mat6(6,6)
  real(rp), save :: flip_mat(4,4), t_e(4,4), t_w_inv(4,4)

  integer i, j, n

  logical :: debug = .false. 
  logical :: init_needed = .true. 

! init

  bmad_status%ok = .false.             ! assume the worst

  if (init_needed) then
    call mat_make_unit(flip_mat)
    flip_mat(1,1) = -1
    flip_mat(4,4) = -1
    init_needed = .false.
  endif

! init one turn. T0 is the transverse part of the matrix

  call mat_make_unit (t0_4)       ! form unit matrix
  eta_vec = 0

! propagate around ring

  do n = 1, ring%n_ele_use
    eta_vec = matmul (ring%ele_(n)%mat6(1:4,1:4), eta_vec)
    eta_vec = eta_vec + ring%ele_(n)%mat6(1:4,6)
    t0_4 = matmul (ring%ele_(n)%mat6(1:4,1:4), t0_4)
    if (debug) then
      print *, '!------------------------------------', n
      call type_ele (ring%ele_(n), .false., 0, .false., 0, .false., ring)
      do i = 1, 4
        print '(4f11.4, 5x, f11.4)', (t0_4(i, j), j = 1, 4), eta_vec(i)
      enddo
    endif
  enddo

! put 1-turn matrix into ring%param%t1_mat4

  ring%param%t1_mat4 = t0_4
  call mat_make_unit (mat6)
  mat6(1:4,1:4) = t0_4

  call mat6_dispersion (mat6, eta_vec) ! dispersion to %mat6

! if symmetry then propagate through the east side

  if (ring%param%symmetry == ew_antisymmetry$) then
    call mat_symp_conj (t0_4, t_w_inv, 4, 4)
    t_e = matmul (matmul (flip_mat, t_w_inv), flip_mat)
    mat6(1:4,1:4) = matmul (t_e, t0_4)
    eta_vec = (/ 0.0_rp, 2*eta_vec(2), 0.0_rp, 2*eta_vec(4) /)
    mat6(1:4, 6) = matmul(t_e, eta_vec)
  endif

! compute twiss parameters

  call twiss_from_mat6 (mat6, ring%ele_(0), &
                                  ring%param%stable, ring%param%growth_rate)
  ring%x%tune = ring%ele_(0)%x%phi
  ring%y%tune = ring%ele_(0)%y%phi

end subroutine


