program moga
  use mpi
  use ifport, ifport_seed=>seed
  use bmad
  use bmad_parser_mod, only: bp_com
  use custom_dynamic_aperture_mod
  use pisa_mod
  use calc_ring_mod
  use dynap_mod
  use linear_aperture_mod
  use namelist_general !general: lat_file, use_hybrid
  use namelist_da !da: tracking_method, n_adts, n_turn, n_angle, track_dims, dE(max_dE), init_len
                  !  adts_x_min, adts_x_max, adts_y_min, adts_y_max
  use namelist_moga ! moga_output_file, set_chrom_x, set_chrom_y, initial_pop, seed, breeder_params, max_gen, co_limit, 
                    ! linear_vec_cutoff, x_fp_min, x_fp_max, y_fp_min, y_fp_max, 
                    ! fp_dE_neg, fp_dE_pos, n_fp_steps, mags_in
 
  implicit none

  type (lat_struct) ring
  type (lat_struct) ring0
  type (lat_struct) ring_use
  type (lat_struct) ring_temp
  type (ele_pointer_struct), allocatable :: eles(:)
  type (custom_aperture_scan_struct) da_config
  type (custom_aperture_scan_struct) da_block_linear
  type (coord_struct), allocatable :: co(:)
  type (coord_struct), allocatable :: orb(:)

  integer i,j,k
  integer n_dE
  integer n_feasible
  integer time_stamp(8)
  integer n_aperture_test

  real(rp) metric
  real(rp) chrom_x, chrom_y
  real(rp) tr_a, tr_b
  real(rp) delta, linear_vec, da_vec
  real(rp) nu_x, nu_y, dist_to_coup
  real(rp) nux_cons, nuy_cons
  real(rp) str_cons
  real(rp) min_dist_to_coup

  logical linear_ok
  logical feasible
  logical err_flag, mat_err
  logical first_loop

  character*60 in_file
  character*100 thin_file
  character*18 var_str
  character*30 set_str
  integer iostat
  type(mag_struct), allocatable :: c_mags(:)
  type(mag_struct), allocatable :: h_mags(:)

  integer n_omega

  real(rp), allocatable :: ApC(:)
  real(rp), allocatable :: Q1(:,:)
  real(rp), allocatable :: Q1t(:,:)
  real(rp), allocatable :: etax_base(:)
  real(rp), allocatable :: etay_base(:)
  real(rp) co_screen, co_screen_x, co_screen_y
  integer status
  
  !pisa vars
  character(20) prefix
  character(10) poll_str
  real poll
  integer polli
  integer gen_num
  integer alpha
  integer curname
  integer lambda
  integer mu
  integer sta
  integer nsel, narc
  integer ix
  integer dim
  integer con
  logical dead
  integer pool_gap

  !pisa statistics
  integer stats_surviving
  integer stats_feasible

  !moga vars
  type(pool_struct), allocatable :: pool(:)
  type(pop_struct), allocatable :: pop(:)
  integer, allocatable :: arc(:)
  integer, allocatable :: last_arc(:)
  integer, allocatable :: sel(:)
  real(rp) omega_bound_lir
  real(rp) omega_bound_uir
  real(rp), allocatable :: K2(:)
  real(rp) r
  logical fp_flag

  !mpi housekeeping
  integer myrank, from_id
  integer n_slave, cluster_size
  integer mpierr
  integer mpistatus(MPI_STATUS_SIZE)
  integer mpistatus_probe(MPI_STATUS_SIZE)
  logical master

  !coarray housekeeping
  real(rp), allocatable :: vars(:)
  real(rp), allocatable :: objs(:)
  real(rp), allocatable :: cons(:)
  real(rp), allocatable :: objscons(:) ! concatenate the two vectors to make MPI easy
  integer worker_id, worker_status
  integer n_harmo, n_mags
  integer n_chrom
  integer n_vars, n_loc
  integer name, pool_ptr, pool_ptr_b, lambda_recv
  integer n_recv, slot_num
  integer, allocatable :: lambda_vec(:)
  integer cr_dim

  logical rf_on
  logical ok, err
  logical lat_unstable, lin_lat_unstable
  logical slaves_done

  ! reduce number of error messages
  call output_direct(do_print=.false.,min_level=-1,max_level=7)

  ! read command line arguments
  call getarg(1,in_file)
  call getarg(2,prefix)
  call getarg(3,poll_str)
  read(poll_str,*) poll
  polli = floor(poll*1000)

  call mpi_init(mpierr)                             ! Introduce yourself to the MPI daemon
  call mpi_comm_rank(MPI_COMM_WORLD,myrank,mpierr)  ! Get your rank number, store in myrank.  Master is rank 0.
  if(myrank .eq. 0) then
    master=.true.
  else
    master=.false.
  endif

  if(master) then
    !Check that cluster has at least two nodes
    call mpi_comm_size(MPI_COMM_WORLD,cluster_size,mpierr)
    n_slave=cluster_size-1
    pool_gap = cluster_size-1
    if(n_slave .eq. 0) then
      write(*,*) "ERROR: no slaves found in cluster.  At least two nodes"
      write(*,*) "must be available to run this program."
      stop
    endif
    !Clear PISA state file
    call write_state(prefix,0)
  endif

  ! parse parameters file and check for necessary initializations.
  use_hybrid = .false.  !default
  generate_feasible_seeds_only = -1
  call set_params_to_bomb()
  open (unit = 10, file = in_file, readonly)
  read (10, nml = general)
  read (10, nml = da)
  read (10, nml = nl_moga)
  close (10)
  if(master) call check_params_bomb()

  ! process parameters
  n_chrom = 0
  n_harmo = 0
  i=0
  do while(.true.)
    i=i+1
    if( mags_in(i)%name == '' ) exit
    if( mags_in(i)%type == 'c' ) n_chrom = n_chrom + 1
    if( mags_in(i)%type == 'h' ) n_harmo = n_harmo + 1
  enddo
  n_mags = n_chrom + n_harmo
  allocate(c_mags(n_chrom))
  allocate(h_mags(n_harmo))

  !- this section of code assumes that the magnet types in mags_in are ordered.
  c_mags(1:n_chrom) = mags_in(1:n_chrom)
  h_mags(1:n_harmo) = mags_in(1+n_chrom:n_harmo+n_chrom)

  cr_dim = 2
  n_omega = n_chrom - cr_dim   !the subspace in chromatic multipole strengths with some chromaticity chi_x, chi_y
  n_vars = n_omega + n_harmo

  do i=1,max_de
    if( de(i) .lt. -998. ) then
      exit
    endif
  enddo
  n_de = i-1

  ! parse shared config params
  call pisa_cfg_parser(prefix, alpha, mu, lambda, dim, con)

  ! check shared parameters meet program limitations
  if ( mu .ne. lambda ) then
    write(*,*) "this program can handle only mu == lambda.", mu, lambda
    error stop
  endif
  if ( mod(mu,2) .ne. 0 ) then
    write(*,*) "this program can handle only even mu."
    error stop
  endif

  if( master ) write(*,*) "preparing lattice..."

  bp_com%always_parse = .true.
  call bmad_parser(lat_file,ring)

  allocate(co(0:ring%n_ele_track))
  allocate(orb(0:ring%n_ele_track))

  call set_on_off(rfcavity$, ring, off$)
  bmad_com%radiation_damping_on = .false.
  bmad_com%radiation_fluctuations_on = .false.
  bmad_com%aperture_limit_on = .true.
  rf_on = .false.

  do i=1,ring%n_ele_track
    if(ring%ele(i)%key == wiggler$) then
      ring%ele(i)%value(x1_limit$) = 1.0
      ring%ele(i)%value(x2_limit$) = 1.0
      ring%ele(i)%value(y1_limit$) = 1.0
      ring%ele(i)%value(y2_limit$) = 1.0
      ring%ele(i)%aperture_type = elliptical$
    endif
  enddo

  n_aperture_test = 0
  do i=1,ring%n_ele_track
    if( ring%ele(i)%value(x1_limit$) .gt. 1e-4 ) n_aperture_test = n_aperture_test + 1
  enddo
  if( (1.0*n_aperture_test)/ring%n_ele_track .lt. 0.5 ) then
    write(*,*) "Less than half the elements do not have a x1 physical aperture."
    write(*,*) "Probably something is wrong.  Check that lattice file defines aperture."
    write(*,*) "Aborting"
    stop
  endif

  if (tracking_method .gt. 0) then
    do i = 1, ring%n_ele_max
      if(ring%ele(i)%key .ne. wiggler$) then
        ring%ele(i)%tracking_method = tracking_method
      endif
    enddo
  endif

  !+ Allocate space in master for storing gene pool
  if( master ) then
    ! allocate memory for storing vector pool
    allocate(pool(alpha+pool_gap))
    pool(:)%name = -1
    do i=1,size(pool)
      allocate(pool(i)%x(n_vars))
    enddo
  endif
  !+ setup chromaticity response matrix and vector
  allocate(ApC(n_chrom)) !coarray
  allocate(Q1(n_chrom,n_omega)) !coarray
  allocate(Q1t(n_omega,n_chrom))

  ! build chromaticity matrices
  if( master ) then
    ring0=ring
    call build_chrom_mat(ring0, set_chrom_x, set_chrom_y, c_mags, ApC, Q1, err_flag)
    if(err_flag) then
      write(*,*) "could not build chromaticity matrices at program start.  aborting."
      stop
    endif
  endif
  call mpi_bcast(ApC, n_chrom, MPI_DOUBLE_PRECISION, 0, MPI_COMM_WORLD, mpierr)
  call mpi_bcast(Q1, n_chrom*n_omega, MPI_DOUBLE_PRECISION, 0, MPI_COMM_WORLD, mpierr)

  ! transform mutator on k2 into mutator on chromatic subspace omega.
  do i=1,n_omega
    Q1t = transpose(Q1)
    breeder_params%mutate_delta(i) = norm2(Q1t(i,:)*c_mags(:)%mutate_delta)  !fortran * is element-wise multiplication
  enddo
  ! mutator on harmonic multipoles are simply copied over
  do i=1, n_harmo 
    breeder_params%mutate_delta(i+n_omega) = h_mags(i)%mutate_delta
  enddo

  !-
  call calc_ring(ring,4,co,err_flag)

  allocate(etax_base(1:ring%n_ele_track))
  etax_base(:) = ring%ele(1:ring%n_ele_track)%a%eta
  allocate(etay_base(1:ring%n_ele_track))
  etay_base(:) = ring%ele(1:ring%n_ele_track)%b%eta

  !- set da configuration structures
  da_config%param%n_turn = n_turn
  da_config%param%accuracy = 0.00001d0
  da_config%param%init_len = init_len
  da_config%param%step_len = 0.0005d0
  da_config%min_angle = 0.2d0
  da_config%max_angle = pi-0.2d0
  da_config%n_angle = n_angle
  da_config%param%adts_x_min = adts_x_min
  da_config%param%adts_x_max = adts_x_max
  da_config%param%adts_y_min = adts_y_min
  da_config%param%adts_y_max = adts_y_max
  allocate(da_config%aperture(1:n_angle))

  da_block_linear%min_angle = da_config%min_angle
  da_block_linear%max_angle = da_config%max_angle
  da_block_linear%n_angle = da_config%n_angle
  allocate(da_block_linear%aperture(1:da_block_linear%n_angle))

  !-
  allocate(k2(n_chrom))
  allocate(vars(n_vars))
  allocate(objs(dim))
  allocate(cons(con))  !zero length arrays are ok in fortran
  allocate(lambda_vec(mu))

  ! alpha is population size
  ! mu is number of parents picked out by selector
  ! lambda is number of children created by breeder

  if( master ) then
    ! manager
    write(*,*) "starting simulation..."
    call random_seed(put=seed)

    ! allocate memory for storing population
    allocate(pop(alpha+lambda))
    pop(:)%name = -1
    do i=1,size(pop)
      allocate(pop(i)%o(dim))
      allocate(pop(i)%x(n_vars))
      allocate(pop(i)%c(con))
    enddo
    allocate(arc(alpha))
    allocate(last_arc(alpha))
    last_arc = 0
    allocate(sel(lambda))

    ! generate or read initial population
    if ( trim(initial_pop) == 'random' ) then
      do i=1,size(pool)
        ! transform bound on k2 into bounds on omega.
        Q1t = transpose(Q1)
        do j=1,n_omega
          omega_bound_lir = 0.0d0
          omega_bound_uir = 0.0d0
          do k=1,n_chrom
            if(Q1t(j,k) < 0.0d0) then
              omega_bound_lir = omega_bound_lir + Q1t(j,k)*c_mags(k)%uir
              omega_bound_uir = omega_bound_uir + Q1t(j,k)*c_mags(k)%lir
            else
              omega_bound_lir = omega_bound_lir + Q1t(j,k)*c_mags(k)%lir
              omega_bound_uir = omega_bound_uir + Q1t(j,k)*c_mags(k)%uir
            endif
          enddo
          call random_number(r)
          pool(i)%x(j) = r*(omega_bound_uir-omega_bound_lir) + omega_bound_lir
        enddo

        ! bounds on harmonic magnets are simply copied over
        do j=1, n_harmo 
          call random_number(r)
          pool(i)%x(j+n_omega) = r*(h_mags(j)%uir-h_mags(j)%lir) + h_mags(j)%lir
        enddo
        pool(i)%name = i
      enddo
    elseif ( trim(initial_pop) .ne. '' ) then
      ring_temp = ring
      call read_initial_population(pool, alpha, n_chrom, n_harmo, initial_pop, ring_temp, set_chrom_x, set_chrom_y, c_mags)
      do i=1,pool_gap
        !pool(alpha+i)%x = pool(i)%x
        pool(alpha+i)%x = 0.0d0
        pool(alpha+i)%name = pool(i)%name + alpha
      enddo
    endif
    pool_ptr_b = alpha+pool_gap

    ! seed each worker with a trial vector
    write(*,*) "seeding generation 1"
    pool_ptr = 0
    do worker_id=1, min(n_slave,alpha)
      call increment_ptr(pool_ptr,size(pool))
      call mpi_send(pool(pool_ptr)%name, 1, MPI_INTEGER, worker_id, 1, MPI_COMM_WORLD, mpierr)
      call mpi_send(pool(pool_ptr)%x(:), n_vars, MPI_DOUBLE_PRECISION, worker_id, 2, MPI_COMM_WORLD, mpierr)
    enddo

    ! receive objectives from workers
    ! refresh worker with new trial vector
    n_recv = 0
    do while (n_recv .lt. alpha)
      call mpi_probe(MPI_ANY_SOURCE, MPI_ANY_TAG, MPI_COMM_WORLD, mpistatus, mpierr)  !blocking
      from_id = mpistatus(MPI_SOURCE)
      call mpi_recv(name, 1, MPI_INTEGER, from_id, 3, MPI_COMM_WORLD, mpistatus, mpierr)
      call find_empty_pop_slot(pop(:),slot_num)
      pop(slot_num)%name = name
      call mpi_recv(pop(slot_num)%x(:), n_vars, MPI_DOUBLE_PRECISION, from_id, 4, MPI_COMM_WORLD, mpistatus, mpierr)
      call mpi_recv(pop(slot_num)%o(:), dim, MPI_DOUBLE_PRECISION, from_id, 5, MPI_COMM_WORLD, mpistatus, mpierr)
      call mpi_recv(pop(slot_num)%c(:), con, MPI_DOUBLE_PRECISION, from_id, 6, MPI_COMM_WORLD, mpistatus, mpierr)

      n_recv = n_recv + 1

      !refresh worker with new trial vector
      call increment_ptr(pool_ptr,size(pool))
      call mpi_send(pool(pool_ptr)%name, 1, MPI_INTEGER, from_id, 1, MPI_COMM_WORLD, mpierr)
      call mpi_send(pool(pool_ptr)%x(:), n_vars, MPI_DOUBLE_PRECISION, from_id, 2, MPI_COMM_WORLD, mpierr)
    enddo

    call write_pop_pisa(pop(1:alpha),trim(prefix)//'ini')
    call write_state(prefix,1)
    call date_and_time(values=time_stamp)
    write(*,'(a,i4,a,3i5)') "generation ", 1, " complete at ", time_stamp(5:7)

    !delete old control_job file if present
    open(unit=21, iostat=iostat, file='control_job_1', status='old')
    if (iostat .eq. 0) then
      write(*,*) "deleting old control_job_1 file."
      close(21, status='delete')
    endif
    close(21)
    open(unit=21, iostat=iostat, file='control_job_2', status='old')
    if (iostat .eq. 0) then
      write(*,*) "deleting old control_job_2 file."
      close(21, status='delete')
    endif
    close(21)

    !delete old output files if present
    call file_suffixer(moga_output_file,thin_file,'.thin',.true.)
    open(unit=21, iostat=iostat, file=moga_output_file, status='old')
    if (iostat .eq. 0) then
      write(*,*) "deleting old output file."
      close(21, status='delete')
    endif
    close(21)
    open(unit=21, iostat=iostat, file=thin_file, status='old')
    if (iostat .eq. 0) then
      write(*,*) "deleting old thin output file."
      close(21, status='delete')
    endif
    close(21)
    open(unit=22, iostat=iostat, file='constraint_report.out', status='old')
    if (iostat .eq. 0) then
      write(*,*) "deleting old constraint file."
      close(22, status='delete')
    endif
    close(22)
    open(unit=22, iostat=iostat, file='objective_report.out', status='old')
    if (iostat .eq. 0) then
      write(*,*) "deleting old objective report file."
      close(22, status='delete')
    endif
    close(22)
    open(unit=22, iostat=iostat, file='offspring_report.out', status='old')
    if (iostat .eq. 0) then
      write(*,*) "deleting old offspring_report.out file."
      close(22, status='delete')
    endif
    close(22)

    !make new output files, write header
    open(unit=21, iostat=iostat, file=moga_output_file, access='append')
    write(21,'(a6,50a19)') '# id', (trim(c_mags(i)%name),i=1,n_chrom), (trim(h_mags(i)%name),i=1,n_harmo), "o1", "o2", "o3", "feasible"
    close(21)
    open(unit=21, iostat=iostat, file=thin_file, access='append')
    write(21,'(a6,50a10)') '# id', (trim(c_mags(i)%name),i=1,n_chrom), (trim(h_mags(i)%name),i=1,n_harmo), "o1", "o2", "o3", "feasible"
    close(21)
    open(unit=22, iostat=iostat, file='constraint_report.out', access='append')
    write(22,'(a6,30a18)') '# id', 'max|k2|', 'eta@+de', 'eta@-de', 'nux@-de', 'nux@+de', 'nuy@-de', 'nuy@+de', 'nux0', 'nuy0'
    close(22)
    open(unit=22, iostat=iostat, file='objective_report.out', access='append')
    write(22,'(a6,10a18)') '# id', 'o1', 'o2', 'o3'
    close(22)
    open(unit=23, iostat=iostat, file='offspring_report.out', access='append')
    write(23,'(a6,30a18)') '# gen', '% surviving', '% feasible'
    if( generate_feasible_seeds_only .gt. 0 ) then
      open(44,file='feasible.log')
    endif
    ! cons(1)  strengths
    ! cons(2)  nonlinear dispersion at -de
    ! cons(3)  nonlinear dispersion at +de
    ! cons(4)  negative chromatic footprint
    ! cons(5)  positive chromatic footprint

    do gen_num = 2, max_gen
      call block_on_pisa_status(polli,prefix)
      call read_pisa_indexes(prefix,'sel',nsel,sel)
      last_arc = arc
      call read_pisa_indexes(prefix,'arc',narc,arc)
      call delete_the_dead(pop(:),arc,narc)
      call write_population(pop, ApC, Q1, generate_feasible_seeds_only, n_chrom, gen_num-1,moga_output_file)
      call write_population(pop, ApC, Q1, generate_feasible_seeds_only, n_chrom, gen_num-1,thin_file, prec=2)
      call write_constraint_report(pop(:),gen_num-1,'constraint_report.out')
      call write_objective_report(pop(:),gen_num-1,'objective_report.out')
      if( generate_feasible_seeds_only .gt. 0 ) then
        call count_feasible_in_pop(pop, n_feasible)
        write(*,'(a,i6,a)') "population contains ", n_feasible, " feasible seeds."
        write(44,'(a,i6,a)') "population contains ", n_feasible, " feasible seeds."
        if(n_feasible .ge. generate_feasible_seeds_only) then
          call write_state(prefix,5) !tell pisa selector to shut down
          error stop
        endif
      endif

      call kangal_breeder(pop(:), sel, pool, pool_ptr_b, breeder_params)

      ! receive objectives from workers
      ! refresh worker with new trial vector
      n_recv = 0
      stats_feasible = 0
      do while (n_recv .lt. mu)
        call mpi_probe(MPI_ANY_SOURCE, MPI_ANY_TAG, MPI_COMM_WORLD, mpistatus, mpierr)  !blocking
        from_id = mpistatus(MPI_SOURCE)
        call find_empty_pop_slot(pop(:),slot_num)
        call mpi_recv(pop(slot_num)%name, 1, MPI_INTEGER, from_id, 3, MPI_COMM_WORLD, mpistatus, mpierr)
        call mpi_recv(pop(slot_num)%x(:), n_vars, MPI_DOUBLE_PRECISION, from_id, 4, MPI_COMM_WORLD, mpistatus, mpierr)
        call mpi_recv(pop(slot_num)%o(:), dim, MPI_DOUBLE_PRECISION, from_id, 5, MPI_COMM_WORLD, mpistatus, mpierr)
        call mpi_recv(pop(slot_num)%c(:), con, MPI_DOUBLE_PRECISION, from_id, 6, MPI_COMM_WORLD, mpistatus, mpierr)


        feasible = all( pop(slot_num)%c(:) .ge. 0.0d0 )
        if(feasible) then
          stats_feasible = stats_feasible + 1
        endif
        n_recv = n_recv + 1
        lambda_vec(n_recv) = slot_num

        !refresh worker with new trial vector
        call increment_ptr(pool_ptr,size(pool))
        call mpi_send(pool(pool_ptr)%name, 1, MPI_INTEGER, from_id, 1, MPI_COMM_WORLD, mpierr)
        call mpi_send(pool(pool_ptr)%x(:), n_vars, MPI_DOUBLE_PRECISION, from_id, 2, MPI_COMM_WORLD, mpierr)
      enddo


      stats_surviving = alpha
      do i=1,alpha
        do j=1,alpha
          if ( last_arc(i) .eq. arc(j) ) then
            stats_surviving = stats_surviving - 1 
            exit
          endif
        enddo
      enddo
      write(23,'(i6,2f18.3)') gen_num, (100.0*stats_surviving)/mu, (100.0*stats_feasible)/mu

      call write_pop_pisa(pop(lambda_vec),trim(prefix)//'var')
      call write_state(prefix,3)
      call date_and_time(values=time_stamp)
      write(*,*) "************************************************************"
      write(*,*) "*"
      write(*,*) "*"
      write(*,*) "*"
      write(*,'(a,i4,a,3i5)') "generation ", gen_num, " complete at ", time_stamp(5:7)
      write(*,*) "*"
      write(*,*) "*"
      write(*,*) "*"
      write(*,*) "************************************************************"
    enddo

    !read final population archive from selector
    call block_on_pisa_status(polli,prefix)
    call read_pisa_indexes(prefix,'arc',narc,arc)
    call delete_the_dead(pop(:),arc,narc)
    call write_population(pop, ApC, Q1, generate_feasible_seeds_only, n_chrom, max_gen, moga_output_file) !write final population to log file
    call write_population(pop, ApC, Q1, generate_feasible_seeds_only, n_chrom, max_gen, thin_file, prec=2) !write final population to log file
    call write_constraint_report(pop(:),max_gen,'constraint_report.out')
    call write_objective_report(pop(:),max_gen,'objective_report.out')
    call write_state(prefix,5) !tell pisa selector to shut down

    !tell workers to shut down
    do i=1,n_slave
      call mpi_send(0, 1, MPI_INTEGER, i, 1, MPI_COMM_WORLD, mpierr)
    enddo
    close(23)
  else
    ! worker
    if(use_hybrid) then
      do i=1,ring%n_ele_track
        if( (ring%ele(i)%key == sbend$) .or. &
            (ring%ele(i)%key == sextupole$) .or. &
            (ring%ele(i)%key == rfcavity$) .or. &
            (ring%ele(i)%key == wiggler$) .or. &
            (ring%ele(i)%key == multipole$) ) then
          ring%ele(i)%select = .true.
        else
          ring%ele(i)%select = .false.
        endif
      enddo
    endif

    ring0 = ring  !stash original, unaltered lattice
    first_loop = .true.
    do while(.true.)
      if( .not. first_loop ) then
        write(*,'(a,i5,a,i8)') "worker ", myrank, " processed name ", name
        call mpi_send(name, 1, MPI_INTEGER, 0, 3, MPI_COMM_WORLD, mpierr)
        call mpi_send(vars, n_vars, MPI_DOUBLE_PRECISION, 0, 4, MPI_COMM_WORLD, mpierr)
        call mpi_send(objs, dim, MPI_DOUBLE_PRECISION, 0, 5, MPI_COMM_WORLD, mpierr)
        call mpi_send(cons, con, MPI_DOUBLE_PRECISION, 0, 6, MPI_COMM_WORLD, mpierr)
      else
        first_loop = .false.
      endif

      ring = ring0

      ! receive magnet strengths from master
      call mpi_recv(name, 1, MPI_INTEGER, 0, 1, MPI_COMM_WORLD, mpistatus, mpierr)
      if( name .eq. 0 ) then
        call mpi_finalize(mpierr)
        exit
      endif
      call mpi_recv(vars, n_vars, MPI_DOUBLE_PRECISION, 0, 2, MPI_COMM_WORLD, mpistatus, mpierr)

      objs(1) = 1.0d0
      objs(2) = 1.0d0
      objs(3) = 1.0d0

      !- apply magnet strengths to lattice
      call omega_to_k2(vars(1:n_omega),ApC,Q1,k2)
      call set_magnet_strengths(c_mags,ring,k2)

      call set_magnet_strengths(h_mags,ring,vars(1+n_omega:n_harmo+n_omega))

      call lattice_bookkeeper(ring)

      !- screen magnet strengths
      cons(1) = -10.0    !sextupole moments
      str_cons = 0.00000001d0
      do i=1, n_chrom
        if(k2(i) .lt. c_mags(i)%lb) then
          str_cons = str_cons + (k2(i) - c_mags(i)%lb)/(abs(c_mags(i)%ub)+abs(c_mags(i)%lb))
        elseif(k2(i) .gt. c_mags(i)%ub) then
          str_cons = str_cons + (c_mags(i)%ub - k2(i))/(abs(c_mags(i)%ub)+abs(c_mags(i)%lb))
        endif
      enddo
      do i=1, n_harmo
        if(vars(i+n_omega) .lt. h_mags(i)%lb) then
          str_cons = str_cons + (vars(i+n_omega) - h_mags(i)%lb)/(abs(h_mags(i)%ub)+abs(h_mags(i)%lb))
        elseif(vars(i+n_omega) .gt. h_mags(i)%ub) then
          str_cons = str_cons + (h_mags(i)%ub - vars(i+n_omega))/(abs(h_mags(i)%ub)+abs(h_mags(i)%lb))
        endif
      enddo
      cons(1) = str_cons

      ! screen closed orbit (assumed flat for i=1, which is assumed to be on-energy)
      cons(2) = -10.0    !nonlinear dispersion at -de
      cons(3) = -10.0    !nonlinear dispersion at +de
      do i=2,3
        co(0)%vec = 0.0d0
        co(0)%vec(6) = de(i)
        call clear_lat_1turn_mats(ring)
        call calc_ring(ring,track_dims,co,lat_unstable,mat_err)

        if(.not. mat_err) then
          co_screen_x = abs(co(1)%vec(1)-etax_base(1)*de(i))
          co_screen_y = abs(co(1)%vec(3)-etay_base(1)*de(i))
          do j=2,ring%n_ele_track
            if( ring%ele(j)%key .ne. wiggler$ ) then
              if( ring%ele(j)%key .ne. marker$ ) then
                co_screen_x = max(co_screen_x,abs(co(j)%vec(1)-etax_base(j)*de(i)))
                co_screen_y = max(co_screen_y,abs(co(j)%vec(3)-etay_base(j)*de(i)))
              endif
            endif
          enddo
          co_screen = max(co_screen_x,co_screen_y)
          cons(i) = (co_limit - co_screen)/co_limit
        endif
      enddo

      cons(4) = -10.0    !x tune at -de or a-mode trace
      cons(5) = -10.0    !x tune at +de or b-mode trace
      if(chrom_mode == 'trace') then
        ! screen matrix traces
        cons(4) = 1.0d0
        cons(5) = 1.0d0
        do i=1,2
          call clear_lat_1turn_mats(ring)
          do j=1,n_fp_steps
            co(0)%vec = 0.0d0
            if(i==1) then !negative, fp_de_neg assumed to be a negative number
              co(0)%vec(6) =  fp_de_neg/n_fp_steps*j
            elseif(i==2) then !positive
              co(0)%vec(6) =  fp_de_pos/n_fp_steps*j
            endif

            call calc_ring(ring,track_dims,co,lat_unstable,mat_err)
            if(.not. mat_err) then
              tr_a = ring%param%t1_no_RF(1,1)+ring%param%t1_no_RF(2,2)
              tr_b = ring%param%t1_no_RF(3,3)+ring%param%t1_no_RF(4,4)
            else
              tr_a = 500.0
              tr_b = 500.0
            endif
            cons(4) = min(tr_a-tr_a_min,cons(4))
            cons(4) = min(tr_a_max-tr_a,cons(4))
            cons(5) = min(tr_b-tr_b_min,cons(5))
            cons(5) = min(tr_b_max-tr_b,cons(5))
          enddo
        enddo
      elseif(chrom_mode == 'tunes') then
        ! screen chromatic tune footprint
        cons(4) = 1.0d0
        cons(5) = 1.0d0
        do i=1,2
          call clear_lat_1turn_mats(ring)
          fp_flag = .false.
          do j=1,n_fp_steps
            co(0)%vec = 0.0d0
            if(i==1) then !negative, fp_de_neg assumed to be a negative number
              co(0)%vec(6) =  fp_de_neg/n_fp_steps*j
            elseif(i==2) then !positive
              co(0)%vec(6) =  fp_de_pos/n_fp_steps*j
            endif

            call calc_ring(ring,track_dims,co,lat_unstable,mat_err)
            if(.not. mat_err) then
              nu_x = ring%ele(ring%n_ele_track)%a%phi/twopi
              nu_y = ring%ele(ring%n_ele_track)%b%phi/twopi
              if(nu_x .gt. x_fp_max) fp_flag = .true.
              if(nu_x .lt. x_fp_min) fp_flag = .true.
              if(nu_y .gt. y_fp_max) fp_flag = .true.
              if(nu_y .lt. y_fp_min) fp_flag = .true.
            else
              fp_flag = .true.
            endif
            if(fp_flag) then
              if(i==1) then !negative chromatic footprint constraint
                cons(4) = -1.0*(1.0 - (j-1.0)/n_fp_steps)
              elseif(i==2) then !positive chromatic footprint constraint
                cons(5) = -1.0*(1.0 - (j-1.0)/n_fp_steps)
              endif
              exit
            endif
          enddo
        enddo
      else
        write(*,*) "FATAL: Unknown chrom_mode."
        error stop
      endif

      ! feasible if all constraints met, otherwise infeasible
      feasible = all( cons(:) .ge. 0.0d0 )

      ! tracking study begins here
      ! if lattice is infeasible, then the optimizer ignores the objectives, so no point in tracking if infeasible.
      if( feasible .and. (generate_feasible_seeds_only .lt. 0) ) then

        do i=1,n_de
          ! calculate linear aperture (dynamic aperture assuming linear optics)
          co(0)%vec = 0.0d0
          co(0)%vec(6) = de(i)
          call clear_lat_1turn_mats(ring)
          call calc_ring(ring,track_dims,co,lin_lat_unstable)

          if(.not. lin_lat_unstable) then
            da_block_linear%param%closed_orbit = co(0)
            if(use_hybrid) then
              call make_hybrid_lat(ring, ring_use)
            else
              ring_use = ring
            endif
            call linear_aperture(ring_use,da_block_linear)

            ! screen for small linear dynamic aperture dimension
            linear_ok = .true.
            do j=1,n_angle
              linear_vec = sqrt( (da_block_linear%aperture(j)%x-co(0)%vec(1))**2 + &
                                 (da_block_linear%aperture(j)%y-co(0)%vec(3))**2)
              if(linear_vec .lt. linear_vec_cutoff) then
                write(*,*) "linear aperture too small: ", linear_vec
                linear_ok = .false.
              endif
            enddo
          else
            linear_ok = .false.
          endif

          if( linear_ok ) then
            !calculate dynamic aperture

            ! only the on-energy adts is constrained
            da_config%param%n_adts = -1
            if(i==1) da_config%param%n_adts = n_adts

            da_config%param%closed_orbit%vec = co(0)%vec
            call custom_dynamic_aperture_scan(ring_use, da_config, .false.)
          endif


          ! total up objective values
          if( .not. linear_ok  ) then
            write(*,*) "linear lattice is not stable."
            metric = 1.0d0
          elseif( lat_unstable ) then
            write(*,*) "lattice is not stable."
            metric = 1.0d0
          else
            metric = 0.0d0
            do j=1,n_angle
              linear_vec = sqrt( (da_block_linear%aperture(j)%x-co(0)%vec(1))**2 + &
                                 (da_block_linear%aperture(j)%y-co(0)%vec(3))**2 )
              da_vec = sqrt( (da_config%aperture(j)%x-co(0)%vec(1))**2 + &
                             (da_config%aperture(j)%y-co(0)%vec(3))**2 )
              delta = (linear_vec - da_vec)/linear_vec/sqrt(1.0d0*n_angle)
              if(delta .lt. 0) then
                delta = 0.0d0  !no contribution from exceeding physical aperture
              endif
              metric = metric + delta**2
            enddo
          endif

          objs(i) = metric
        enddo
      endif
    enddo
  endif

  call mpi_finalize(mpierr)
  write(*,*) "image ", myrank, " made it!"

  contains

    subroutine set_params_to_bomb()
      implicit none
      de(:) = -999.
      set_chrom_x = -999.0
      set_chrom_y = -999.0
      co_limit = -999.0
      linear_vec_cutoff = -999.0
      x_fp_min = -999.0
      x_fp_max = -999.0
      y_fp_min = -999.0
      y_fp_max = -999.0
      adts_x_min = -999.0
      adts_x_max = -999.0
      adts_y_min = -999.0
      adts_y_max = -999.0
      tr_a_min = -999.0
      tr_a_max = -999.0
      tr_b_min = -999.0
      tr_b_max = -999.0
      chrom_mode = 'bomb'
      init_len = -999.0
      fp_de_neg = -999.0
      fp_de_pos = -999.0
      n_fp_steps = -999
      seed(1) = -999
      seed(2) = -999
      max_gen = -999
      n_turn = -999
      n_angle = -999
      tracking_method = -999
      track_dims = -999
      lat_file = 'bomb'
      moga_output_file = 'bomb'
      initial_pop = 'bomb'
      mags_in(:)%name = ''
    end subroutine

    subroutine check_params_bomb()
      implicit none
      logical fail
      fail = .false.
      fail = fail .or. check_bomb(set_chrom_x,'set_chrom_x')
      fail = fail .or. check_bomb(set_chrom_y,'set_chrom_y')
      fail = fail .or. check_bomb(x_fp_min,'x_fp_min')
      fail = fail .or. check_bomb(x_fp_max,'x_fp_max')
      fail = fail .or. check_bomb(y_fp_min,'y_fp_min')
      fail = fail .or. check_bomb(y_fp_max,'y_fp_max')
      fail = fail .or. check_bomb(adts_x_min,'adts_x_min')
      fail = fail .or. check_bomb(adts_x_max,'adts_x_max')
      fail = fail .or. check_bomb(adts_y_min,'adts_y_min')
      fail = fail .or. check_bomb(adts_y_max,'adts_y_max')
      fail = fail .or. check_bomb(tr_a_min,'tr_a_min')
      fail = fail .or. check_bomb(tr_a_max,'tr_a_max')
      fail = fail .or. check_bomb(tr_b_min,'tr_b_min')
      fail = fail .or. check_bomb(tr_b_max,'tr_b_max')
      fail = fail .or. check_bomb(chrom_mode,'chrom_mode')
      fail = fail .or. check_bomb(co_limit,'co_limit')
      fail = fail .or. check_bomb(linear_vec_cutoff,'linear_vec_cutoff')
      fail = fail .or. check_bomb(fp_de_neg,'fp_de_neg')
      fail = fail .or. check_bomb(fp_de_pos,'fp_de_pos')
      fail = fail .or. check_bomb(n_fp_steps,'n_fp_steps')
      fail = fail .or. check_bomb(de(1),'de(1)')
      fail = fail .or. check_bomb(init_len,'init_len')
      fail = fail .or. check_bomb(max_gen,'max_gen')
      fail = fail .or. check_bomb(track_dims,'track_dims')
      fail = fail .or. check_bomb(n_turn,'n_turn')
      fail = fail .or. check_bomb(n_angle,'n_angle')
      fail = fail .or. check_bomb(seed(1),'seed(1)')
      fail = fail .or. check_bomb(seed(2),'seed(2)')
      fail = fail .or. check_bomb(tracking_method,'tracking_method')
      fail = fail .or. check_bomb(lat_file,'lat_file')
      fail = fail .or. check_bomb(moga_output_file,'moga_output_file')
      fail = fail .or. check_bomb(initial_pop,'initial_pop')
      fail = fail .or. check_bomb(mags_in(1)%name,'mags_in(1)%name')
      if(fail) then
        write(*,*) "parameters file does not contain necessary settings."
        write(*,*) "terminating"
        error stop
      endif
    end subroutine

    function check_bomb(var,var_str)
      implicit none
      class(*) :: var
      character(*) var_str
      logical check_bomb

      check_bomb = .false. 
      select type(var)
        type is (real(rp))
          if(var .lt. -900.0) then
            write(*,*) "parameter ", trim(var_str), " is uninitialized."
            check_bomb = .true. 
          endif
        type is (integer)
          if(var .lt. -900) then
            write(*,*) "parameter ", trim(var_str), " is uninitialized."
            check_bomb = .true.
          endif
        type is (character(*))
          if(trim(var) .eq. 'bomb') then
            write(*,*) "parameter ", trim(var_str), " is uninitialized."
            check_bomb = .true.
          endif
          if(trim(var) .eq. '') then
            write(*,*) "parameter ", trim(var_str), " is uninitialized."
            check_bomb = .true.
          endif
      end select
    end function

end program






