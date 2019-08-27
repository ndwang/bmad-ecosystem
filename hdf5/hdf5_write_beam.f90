!+
! Subroutine hdf5_write_beam (file_name, bunches, append, error, lat)
!
! Routine to write particle positions of a beam to an HDF5 binary file.
! See also hdf5_read_beam.
!
! Input:
!   file_name     -- character(*): Name of the file to create.
!   bunches(:)    -- bunch_struct: Array of bunches. 
!                       Use "[bunch]" if you have a single bunch.
!                       use "beam%bunch" if you have beam_struct instance.
!   append        -- logical: If True then append if the file already exists.
!   lat           -- lat_struct, optional: If present, lattice info will be saved in file.
!
! Output:
!   error         -- logical: Set True if there is an error. False otherwise.
!-

subroutine hdf5_write_beam (file_name, bunches, append, error, lat)

use bmad_interface, dummy => hdf5_write_beam
use iso_fortran_env
use hdf5_openpmd_mod

implicit none

type (bunch_struct), target :: bunches(:)
type (bunch_struct), pointer :: bunch
type (coord_struct), pointer :: p(:)
type (lat_struct), optional :: lat

real(rp), allocatable :: rvec(:), p0c(:)

integer(HID_T) f_id, g_id, z_id, z2_id, r_id, b_id, b2_id
integer i, n, ib, ix, h5_err, h_err
integer, allocatable :: ivec(:)

character(*) file_name
character(20) date_time, root_path, bunch_path, particle_path, fmt
character(100) this_path
character(*), parameter :: r_name = 'hdf5_write_beam'

logical append, error, err

! Open a new file using default properties.

error = .true.
call hdf5_open_file (file_name, 'WRITE', f_id, err);  if (err) return

! Write some header stuff

call date_and_time_stamp (date_time, .true., .true.)
root_path = '/data/'
bunch_path = '%T/'
particle_path = 'particles/'

call hdf5_write_attribute_string(f_id, 'dataType', 'openPMD', err)
call hdf5_write_attribute_string(f_id, 'openPMD', '2.0.0', err)
call hdf5_write_attribute_string(f_id, 'openPMDextension', 'BeamPhysics;SpeciesType', err)
call hdf5_write_attribute_string(f_id, 'basePath', trim(root_path) // trim(bunch_path), err)
call hdf5_write_attribute_string(f_id, 'particlesPath', trim(particle_path), err)
call hdf5_write_attribute_string(f_id, 'software', 'Bmad', err)
call hdf5_write_attribute_string(f_id, 'softwareVersion', '1.0', err)
call hdf5_write_attribute_string(f_id, 'date', date_time, err)
if (present(lat)) then
  call hdf5_write_attribute_string(f_id, 'latticeFile', lat%input_file_name, err)
  if (lat%lattice /= '') then
    call hdf5_write_attribute_string(f_id, 'latticeName', lat%lattice, err)
  endif
endif

! Loop over bunches

call h5gcreate_f(f_id, trim(root_path), r_id, h5_err) ! Not actually needed if root_path = '/'

n = log10(1.000001 * size(bunches)) + 1
write (fmt, '(3(a, i0))') '(a, i', n, '.', n, ', 2a)'    ! EG get 'i2.2' if size(bunches) = 16

do ib = 1, size(bunches)
  bunch => bunches(ib)
  p => bunch%particle

  call re_allocate (p0c, size(p))
  call re_allocate (rvec, size(p))
  call re_allocate (ivec, size(p))

  p0c = p%p0c

  ! Write bunch particle info.
  ix = index(bunch_path, '%T')
  write (this_path, fmt) bunch_path(1:ix-1), ib, trim(bunch_path(ix+2:))
  call h5gcreate_f(r_id, trim(this_path), b_id, h5_err)
  call h5gcreate_f(b_id, particle_path, b2_id, h5_err)

  call hdf5_write_attribute_string(b2_id, 'speciesType', openpmd_species_name(p(1)%species), err)
  call hdf5_write_attribute_real(b2_id, 'totalCharge', bunch%charge_tot, err)
  call hdf5_write_attribute_real(b2_id, 'chargeLive', bunch%charge_live, err)
  call hdf5_write_attribute_real(b2_id, 'chargeUnitSI', 1.0_rp, err)
  call hdf5_write_attribute_int(b2_id, 'numParticles', size(bunch%particle), err)
  
  do i = 1, size(p)
    if (p0c(i) == 0) p0c(i) = -1   ! Zero causes problem so use default of -1 instead.
  enddo

  !-----------------
  ! Photons...

  if (p(1)%species == photon$) then
    ! Photon polarization
    call h5gcreate_f(b2_id, 'photonPolarizationAmplitude', z_id, h5_err)
    call pmd_write_real_to_dataset(z_id, 'x', 'x', unit_1, p(:)%field(1), err)
    call pmd_write_real_to_dataset(z_id, 'y', 'y', unit_1, p(:)%field(2), err)
    call h5gclose_f(z_id, h5_err)

    call h5gcreate_f(b2_id, 'photonPolarizationPhase', z_id, h5_err)
    call pmd_write_real_to_dataset(z_id, 'x', 'x', unit_1, p(:)%phase(1), err)
    call pmd_write_real_to_dataset(z_id, 'y', 'y', unit_1, p(:)%phase(2), err)
    call h5gclose_f(z_id, h5_err)

    ! Velocity

    call h5gcreate_f(b2_id, 'velocity', z_id, h5_err)
    call pmd_write_real_to_dataset(z_id, 'x', 'Vx', unit_c_light, p(:)%vec(2), err)
    call pmd_write_real_to_dataset(z_id, 'y', 'Vy', unit_c_light, p(:)%vec(4), err)
    call pmd_write_real_to_dataset(z_id, 'z', 'Vz', unit_c_light, p(:)%vec(6), err)
    call h5gclose_f(z_id, h5_err)

    !

    call pmd_write_real_to_dataset(b2_id, 'pathLength', 'Path Length', unit_m, p(:)%path_len, err)
    call pmd_write_real_to_dataset (b2_id, 'totalMomentumOffset', 'p0c', unit_eV_per_c, p0c, err)

  ! Non-photons...

  else
    ! Momentum

    call h5gcreate_f(b2_id, 'momentum', z_id, h5_err)
    call pmd_write_real_to_dataset(z_id, 'x', 'px * p0c', unit_ev_per_c, p(:)%vec(2) * p0c, err)
    call pmd_write_real_to_dataset(z_id, 'y', 'py * p0c', unit_ev_per_c, p(:)%vec(4) * p0c, err)
    rvec = p(:)%direction * (sqrt((1 + p(:)%vec(6))**2 - p(:)%vec(2)**2 - p(:)%vec(4)**2) * p0c)
    call pmd_write_real_to_dataset(z_id, 'z', 'ps * p0c', unit_ev_per_c, rvec, err)
    call h5gclose_f(z_id, h5_err)

    call pmd_write_real_to_dataset (b2_id, 'totalMomentumOffset', 'p0c', unit_eV_per_c, p0c, err)
    call pmd_write_real_to_dataset (b2_id, 'totalMomentum', 'pz * p0c', unit_eV_per_c, p(:)%vec(6)*p0c, err)

    ! Spin

    call h5gcreate_f(b2_id, 'spin', z_id, h5_err)
    call pmd_write_real_to_dataset(z_id, 'x', 'Sx', unit_1, p(:)%spin(1), err)
    call pmd_write_real_to_dataset(z_id, 'y', 'Sy', unit_1, p(:)%spin(2), err)
    call pmd_write_real_to_dataset(z_id, 'z', 'Sz', unit_1, p(:)%spin(3), err)
    call h5gclose_f(z_id, h5_err)

    if (.not. is_fundamental_species(p(1)%species)) then
      do i = 1, size(p)
        ivec = charge_of(p(i)%species)
      enddo
      call pmd_write_int_to_dataset(b2_id, 'chargeState', 'particle charge', unit_1, ivec, err)
    endif
  endif

  ! Time

  if (p(1)%species == photon$) then
    rvec = 0
  else
    rvec = -p(:)%vec(5) / (p(:)%beta * c_light)  ! t - t_ref
  endif
  call pmd_write_real_to_dataset(b2_id, 'time', 't - t_ref', unit_sec, rvec, err)
  call pmd_write_real_to_dataset(b2_id, 'timeOffset', 't_ref', unit_sec, p(:)%t - rvec, err)

  !-----------------
  ! Position. 

  call h5gcreate_f(b2_id, 'position', z_id, h5_err)

  call pmd_write_real_to_dataset(z_id, 'x', 'x', unit_m, p(:)%vec(1), err)
  call pmd_write_real_to_dataset(z_id, 'y', 'y', unit_m, p(:)%vec(3), err)

  ! For charged particles: The z-position (as opposed to z-cononical = %vec(5)) is always zero by construction.
  if (p(1)%species == photon$) then
    call pmd_write_real_to_dataset(z_id, 'z', 'z', unit_m, p(:)%vec(5), err)
  else
    call pmd_write_real_to_pseudo_dataset(z_id, 'z', 'z', unit_m, 0.0_rp, [size(p)], err)
  endif

  call h5gclose_f(z_id, h5_err)

  !

  call pmd_write_real_to_dataset(b2_id, 'sPosition', 's', unit_m, p(:)%s, err)
  call pmd_write_real_to_dataset(b2_id, 'weight', 'macro-charge', unit_1, p(:)%charge, err)
  call pmd_write_int_to_dataset(b2_id, 'particleStatus', 'state', unit_1, p(:)%state, err)
  call pmd_write_int_to_dataset(b2_id, 'branchIndex', 'ix_branch', unit_1, p(:)%ix_branch, err)
  call pmd_write_int_to_dataset(b2_id, 'elementIndex', 'ix_ele', unit_1, p(:)%ix_ele, err)

  do i = 1, size(p)
    select case (p(i)%location)
    case (upstream_end$);   ivec(i) = -1
    case (inside$);         ivec(i) =  0
    case (downstream_end$); ivec(i) =  1
    end select
  enddo
  call pmd_write_int_to_dataset(b2_id, 'locationInElement', 'location', unit_1, ivec, err)

  call h5gclose_f(b2_id, h5_err)
  call h5gclose_f(b_id, h5_err)
enddo

call h5gclose_f(r_id, h5_err)
call h5fclose_f(f_id, h5_err)
error = .false.

end subroutine hdf5_write_beam 
