!........................................................................
!+
! subroutine :  beambeam_scan(ring, scan_params, phi_x, phi_y)
!
! Arguments  :
!
! Description:
!
! Mod/Commons:
!
! Calls      :
!
! Author     : 
!
! Modified   :
!-
!........................................................................
!
! $Id$
!
! $Log$
! Revision 1.5  2007/01/30 16:14:31  dcs
! merged with branch_bmad_1.
!
! Revision 1.4.2.1  2006/12/22 20:30:42  dcs
! conversion compiles.
!
! Revision 1.4  2006/02/21 21:33:55  ajl59
! Fixed use of MPI causing error on turn 20500
!
! Revision 1.3  2005/09/21 20:59:07  dcs
! more changes to get around compiler bug.
!
! Revision 1.2  2005/07/11 14:56:55  sni2
! added damping control to infile
!
! Revision 1.1.1.1  2005/06/14 14:59:02  cesrulib
! Beam Simulation Code
!
!
!........................................................................
!
#include "CESR_platform.h"

subroutine beambeam_scan(ring, scan_params, phi_x, phi_y) 
  
  use bmad_struct
  use bmad_interface
  use bmadz_mod
  use bmadz_interface
  use bsim_interface
  use scan_parameters
  use beambeam_interface 
  
  implicit none

#if defined(CESR_LINUX) || defined(CESR_WINCVF)
#include "mpif.h"
  double precision MPI_WTIME_
  external MPI_WTIME_
#endif


  type (lat_struct) ring
  type (lat_struct), save :: ring_in, ring_out
  type (coord_struct), allocatable, save ::  start_coord(:), end_coord(:)
  type (coord_struct), allocatable, save :: co(:), orb(:)
  type (coord_struct), allocatable, save :: start(:), end(:)
  type (coord_struct) delta_ip
  type (normal_modes_struct) mode
  type (ele_struct) beambeam_ele
  type (scan_params_struct) scan_params
  
  real(rp) current
  real(rp) Qx, Qy
  real(rp) rgamma, den, xi_v, xi_h
  real(rp) r_0/2.81794092e-15/
  real(rp) charge
  real(rp) phi_x, phi_y
  real(rp), allocatable :: dk1(:)
  real(rp) x_offset, y_offset

  integer i, j
  integer ix
  integer ios
  integer particle, i_train, j_car, n_trains_tot, n_cars
  integer slices
  integer n_ok
  integer i_dim
  integer ix_ip
  integer n_typeout/500/
!  integer pturns/2048/
!  integer dist_file/0/

  character date*10, time*10
  character*80 in_file

  logical ok
  logical rec_taylor

!SIBREN added these
  integer, allocatable :: list(:)    !array to hold whether a part. has been processed on a given turn
                                     !0 = unprocessed particle, 1 = particle being processed, 
                                     !2 = particle that is done
                                     !3 = particle that is a round ahead
  integer size, rank, ierr, mpi_type, request, tempreq
  integer idnum,num_rpt
  integer sib_i, sib_j, d_unit, l 
#if defined(CESR_LINUX) || defined(CESR_WINCVF)
  integer status(MPI_STATUS_SIZE)
#endif
  integer, parameter :: go = 5298
  logical, dimension(2) :: transmit  !changed to a two demensianal array to simplify update of strong beam
                                     !transmit(1) acts like the original transmit, transmit(2) says whether
                                     !strong beam size has been updated
  logical round_flag,found_flag
  real(rp), dimension(7) :: onepart,recvpart,partstart
  type (coord_struct), allocatable :: sib_co(:)
  character name*12 

!ANDREW added these
  real(rp) :: param_sum, param_mean(1:3),A(1:3), variances(1:3)
  real(rp), allocatable :: past_params(:,:), parameters(:,:), past_lums(:)
  real(rp) :: t1, t2, t3, t4, t5, t6, t_wait, t_send
  real(rp) :: max_lum,min_lum 
  real(rp) :: Qx_in , Qy_in
  real(rp), parameter :: j_print_dist=10000
  integer :: t_count, k, p_unit, e_unit, ti_unit, t_unit, g_unit
  integer :: damping
  integer :: mem_mean
  character*5 fit
  logical :: fit_sig, fit_var
  character*80 params_file, times_file, turns_file, ends_file, dist_file, final_pos_file
  character*20 wordx, wordy
  type(coord_struct) :: final_pos_out
  
!######################
  allocate(parameters(1:3,1:3))
  allocate(past_params(1:scan_params%n_turn/n_typeout,1:3))
  allocate(past_lums(1:scan_params%n_turn/n_typeout))
  parameters(:,:) = 0.0
  past_params(:,:) = 0.0
  past_lums(:) = 0.0
  param_mean(:) = 0.0
  t_wait = 0.0
  t_send = 0.0
  t_count = 0
  damping = scan_params%damping
!######################

  call reallocate_coord(sib_co,ring%n_ele_max)

  call reallocate_coord(co,ring%n_ele_max)
  call reallocate_coord(orb, ring%n_ele_max)
  call reallocate_coord(start_coord, scan_params%n_part)
  call reallocate_coord(end_coord, scan_params%n_part)
  call reallocate_coord(start, scan_params%n_part)
  call reallocate_coord(end, scan_params%n_part)

  call setup_radiation_tracking(ring, co, .false., .false.)
  call set_on_off (rfcavity$, ring, off$)

  ring%param%particle = positron$

  call twiss_at_start(ring)
  co(0)%vec = 0.
  call closed_orbit_calc(ring, co, 4)
  call lat_make_mat6(ring,-1,co)
  call twiss_at_start(ring)
  call twiss_propagate_all(ring)  
  rank=0

#if defined(CESR_LINUX) || defined(CESR_WINCVF)
  if(scan_params%parallel)then
     call MPI_COMM_RANK_(MPI_COMM_WORLD,rank,ierr)
  end if
#endif

!only rank 0 needs to talk to the outside world
  if(rank.eq.0) then
     type *
     type *,' BEAMBEAM_SCAN: Initially '
     type *,'    Qx = ',ring%a%tune/twopi,'    Qy = ',ring%b%tune/twopi
     type '(a15,4e12.4)','  Closed orbit ', co(0)%vec(1:4)
  endif

  particle = scan_params%particle
  i_train = scan_params%i_train
  j_car = scan_params%j_car
  n_trains_tot = scan_params%n_trains_tot
  n_cars = scan_params%n_cars
  current = scan_params%current
  rec_taylor = scan_params%rec_taylor
  slices = scan_params%slices
  fit = scan_params%fit
     fit_sig = .false.
     fit_var = .false.
     if(trim(fit)=='sig') fit_sig = .true.
     if(trim(fit)=='var') fit_var = .true.

  ! IF LRBBI = .TRUE. adjust ring accordingly
  if(scan_params%lrbbi)then
     ring_in = ring
     call lrbbi_setup ( ring_in, ring_out, particle, i_train, j_car, n_trains_tot, n_cars, current, rec_taylor)
     ring = ring_out
     
     call twiss_at_start(ring)
     co(0)%vec = 0.
     call closed_orbit_calc(ring, co, 4)
     call lat_make_mat6(ring,-1, co)
     call twiss_at_start(ring)
     
!only 0 talks to the world
     if(rank.eq.0) then
        type *
        type '(a51,f4.1,a8)', &
             ' BEAMBEAM_SCAN: After parasitic interactions added ', current,'mA/bunch' 
        type *,'    Qx = ',ring%a%tune/twopi,'    Qy = ',ring%b%tune/twopi
        type '(a15,4e12.4)','  Closed orbit ', co(0)%vec(1:4)
     endif
  endif
  
  ! set Q-tunes, save initial tunes to be read into .ends file later
  Qx = ring%a%tune/twopi
  Qx_in = Qx
  Qy = ring%b%tune/twopi
  Qy_in = Qy
  ring%z%tune = scan_params%Q_z * twopi
  
  ! IF BEAMBEAM_IP = .TRUE.
  if(scan_params%beambeam_ip)then
     call beambeam_setup(ring, particle, current, scan_params, slices)
     
     call twiss_at_start(ring)
     co(0)%vec = 0.
     call closed_orbit_calc(ring, co, 4)
!only 0 talks to the world
     if(rank.eq.0) then
        type '(a15,4e12.4)','  Closed orbit ', co(0)%vec(1:4)
     endif
     call lat_make_mat6(ring, -1, co)
     call twiss_at_start(ring)

!things written need be done but once
     if(rank.eq.0) then
        type *
        type *,' BEAMBEAM_SCAN: After beambeam added '
        type '(a37,f4.1,a8)', &
             ' BEAMBEAM_SCAN: After beambeam added ', current,'mA/bunch' 
        type *,'    Qx = ',ring%a%tune/twopi,'    Qy = ',ring%b%tune/twopi
        type '(a15,4e12.4)','  Closed orbit ', co(0)%vec(1:4)
        write(23, *)
        write(23, '(a37,f4.1,a8)') &
             ' BEAMBEAM_SCAN: After beambeam added ', current,'mA/bunch' 
     endif
     beambeam_ele = ring%ele(1)
     if(rank.eq.0) then
        write(23,  '(1x,a14)') ' Strong beam: '
        write(23,  '(1x,a12,e12.4)') '  sigma_x = ',beambeam_ele%value(sig_x$)
        write(23,  '(1x,a12,e12.4)') '  sigma_y = ',beambeam_ele%value(sig_y$)
        write(23,  '(1x,a12,e12.4)') '  sigma_z = ',beambeam_ele%value(sig_z$)
        write(23,  '(1x,a14,e12.4,a4,e12.4)') '  Pitch  : x= ',beambeam_ele%value(x_pitch$), &
             ' y= ',beambeam_ele%value(y_pitch$)
        write(23, '(1x,a14,e12.4,a4,e12.4)') '  Offset : x= ',beambeam_ele%value(x_offset$), &
             ' y= ',beambeam_ele%value(y_offset$)
        write(23, '(1x,a9,e12.4)') '  Tilt = ', beambeam_ele%value(tilt$)
     endif
  endif ! end if(scan_params%beambeam_ip) 

  call set_on_off (rfcavity$, ring, on$)
  call set_z_tune(ring)

  i_dim = 6
  
  ! IF CLOSE_PRETZ = .TRUE.
  if(scan_params%close_pretz)then
     call close_pretzel (ring, i_dim, scan_params%final_pos_in, final_pos_out) 
     call twiss_at_start(ring)
     call closed_orbit_calc(ring, co, i_dim)
     call lat_make_mat6(ring, -1, co)
     call twiss_at_start(ring)
     if(rank.eq.0) then
        type*,' after close pretzel but before close vertical: '
        type '(1x,3(a9,f12.4))','    Qx = ',ring%a%tune/twopi,'    Qy = ',ring%b%tune/twopi,'   Qz = ',ring%z%tune/twopi
     endif
  endif

  if(scan_params%close_vert) call close_vertical(ring,i_dim,scan_params%final_pos_in,final_pos_out)
  
  call twiss_at_start(ring)
  
  forall( i=0:ring%n_ele_track) co(i)%vec = 0.
  call closed_orbit_calc(ring, co, i_dim)
  call lat_make_mat6(ring, -1, co)
  call twiss_at_start(ring)
  call twiss_propagate_all(ring)
  
  if(rank.eq.0)then
     type *
     type *,' After CLOSE VERTICAL ' 
     type '(1x,3(a9,f12.4))','    Qx = ',ring%a%tune/twopi,'    Qy = ',ring%b%tune/twopi,'   Qz = ', ring%z%tune/twopi
     type '(a15,4e12.4)','  Closed orbit ', co(0)%vec(1:4)
     write(23,'(a36,f6.4,a12,f6.4)')' Beam beam tune shifts:  Delta Qx = ', ring%a%tune/twopi - Qx, &
          '  Delta Qy =',ring%b%tune/twopi-Qy
  endif

  ! set rgamma, den, xi_v, and xi_h; print these values to file
  rgamma = ring%ele(0)%value(E_TOT$)
  den = twopi*rgamma*beambeam_ele%value(sig_x$)+beambeam_ele%value(sig_y$)
  xi_v = r_0*ring%param%n_part*ring%ele(0)%b%beta/beambeam_ele%value(sig_y$)/den
  xi_h = r_0*ring%param%n_part*ring%ele(0)%a%beta/beambeam_ele%value(sig_x$)/den
  if(rank.eq.0) then
     write(23,'(2(a10,f7.4))')'   xi_v = ', xi_v,'   xi_h = ',xi_h
  endif
  
  ! find beambeam at IP and turn it off
  do i=0,ring%n_ele_max
     if(ring%ele(i)%name == 'IP_COLLISION')then
        ix_ip = i
        charge = ring%ele(i)%value(charge$)
        ring%ele(i)%value(charge$) = 0
        exit
     endif
  end do
  if(rank.eq.0) then
     type *,' BEAMBEAM: turn off beam beam at IP'
  endif

  ! Qtune
  allocate(dk1(ring%n_ele_max))
  call choose_quads(ring, dk1)
  call custom_set_tune (phi_x, phi_y, dk1, ring, co, ok)
  deallocate(dk1)
  
  ! IF CLOSE_PRETZ
  if(scan_params%close_pretz)then
     call close_pretzel (ring,i_dim, scan_params%final_pos_in, final_pos_out)
!        call twiss_at_start(ring)
     call closed_orbit_calc(ring, co, i_dim)
     call lat_make_mat6(ring, -1, co)
     call twiss_at_start(ring)
     if(rank.eq.0) then
        type *,' beam beam at IP is off'
        type*,' after qtune and after close pretzel but before close vertical: '
        type '(1x,3(a9,f12.4))','    Qx = ',ring%a%tune/twopi,'    Qy = ',ring%b%tune/twopi,'   Qz = ',ring%z%tune/twopi
     endif
  endif
  ! IF CLOSE_VERT
  if(scan_params%close_vert)then
     call close_vertical(ring,i_dim,scan_params%final_pos_in,final_pos_out)
!        call twiss_at_start(ring)
     call closed_orbit_calc(ring, co, i_dim)
     call lat_make_mat6(ring, -1, co)
     call twiss_at_start(ring)
     if(rank.eq.0) then
        type*,' after qtune with pretzel and vert closed but beam beam at IP off: '
        type '(1x,3(a9,f12.4))','    Qx = ',ring%a%tune/twopi,'    Qy = ',ring%b%tune/twopi,'   Qz = ', ring%z%tune/twopi
     endif
  endif

! PRINT OUT FINAL_POS_IN AND FINAL_POS_OUT IN FILE beambeam.final_pos
  if(rank.eq.0) then
     call file_suffixer (scan_params%file_name, final_pos_file, '.final_pos', .true.)
     open(unit=17,file=final_pos_file)
     write(17,*) 'final_pos_in: ', scan_params%final_pos_in%vec(1:4)
     write(17,*) 'final_pos_out: ', final_pos_out%vec(1:4)
     close(17)
  end if


  ! Turn beambeam back on
  ring%ele(ix_ip)%value(charge$) = charge
  call twiss_at_start(ring)
  call closed_orbit_calc(ring, co, i_dim)
  call lat_make_mat6(ring, -1, co)
  call twiss_at_start(ring)
  call beambeam_separation(ring, delta_ip, i_dim)
  if(rank.eq.0) then
     type *,' Turn Beambeam on'
     type *,'    Qx = ',ring%a%tune/twopi,'    Qy = ',ring%b%tune/twopi
     type '(a22,4f8.4)', ' dx,dxp,dy,dyp (mm) = ', delta_ip%vec(1:4)*1000.
  endif
  beambeam_ele = ring%ele(1)
  if(rank.eq.0) then
     write(23,*)
     write(23,  '(1x,a14)') ' Strong beam: after closing pretzel '
     write(23,  '(1x,a12,e12.4)') '  sigma_x = ',beambeam_ele%value(sig_x$)
     write(23,  '(1x,a12,e12.4)') '  sigma_y = ',beambeam_ele%value(sig_y$)
     write(23,  '(1x,a12,e12.4)') '  sigma_z = ',beambeam_ele%value(sig_z$)
     write(23,  '(1x,a14,e12.4,a4,e12.4)') '  Pitch  : x= ',beambeam_ele%value(x_pitch$), &
          ' y= ',beambeam_ele%value(y_pitch$)
     write(23, '(1x,a14,e12.4,a4,e12.4)') '  Offset : x= ',beambeam_ele%value(x_offset$), &
          ' y= ',beambeam_ele%value(y_offset$)
     write(23, '(1x,a9,e12.4)') '  Tilt = ', beambeam_ele%value(tilt$)
  endif
  call set_on_off (rfcavity$, ring, on$)
  call set_z_tune(ring)
  if(scan_params%radiation)then
     call setup_radiation_tracking(ring, co, .true., .true.)
     if(rank.eq.0) then
        type *,' radiation fluctuations and damping are on'
     endif
  endif
  forall(i=0:ring%n_ele_track) orb(i)%vec = co(i)%vec
  call radiation_integrals (ring, orb, mode)
  call longitudinal_beta( ring, mode)

  ! generate initial gaussian dist for weak beam & calculate its size
  if(rank.eq.0) then
     call gaussian_dist(ring%ele(0), mode, scan_params%coupling_wb, scan_params%min_sig, start_coord) 
     call file_suffixer (scan_params%file_name, in_file, '.beg', .true.)
     call histogram(ring%ele(0), start_coord,in_file, scan_params%sig_in,A)

!>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
     if(fit_sig) then
        ! ANDREW'S CODE
        ! fit parameters to start_coord_ data; write the parameters to beambeam.beg.
        ! We use the amplitudes from histogram as initial guesses, but in subsequent turns
        ! gfit3d uses the previous turn's amplitude as an initial guess
        parameters(1,1:3) = A(1:3)

        g_unit = 16
        open(unit=g_unit,file="gfit3d.chisq",action="write",access="append")
        write(g_unit,'(i8)',ADVANCE='NO') 0
        close(g_unit)

        call gfit3d(start_coord(1:scan_params%n_part),parameters)
        scan_params%sig_in(:) = parameters(3,:)
        call file_suffixer (scan_params%file_name, in_file, '.beg', .true.)
        call writefile(in_file,parameters)
     end if

!write(wordx,'(f0.2)')current
!dist_file = './dists/dist.calc_' // trim(wordx) // '_000000'
!open(unit=18,file=dist_file)
!do i=1,scan_params%n_part
!write(18,'(6e12.4)')start_coord(i)%vec(:)
!end do
!close(18)
!
  ! tilt the beam onto the orbit axis for tracking
  open(unit=14)
  do i = 1, scan_params%n_part
     x_offset = orb(0)%vec(2) * start_coord(i)%vec(5)
     y_offset = orb(0)%vec(4) * start_coord(i)%vec(5)
     co(0)%vec(:) = orb(0)%vec(:) + start_coord(i)%vec(:)
     co(0)%vec(1) = co(0)%vec(1) + x_offset
     co(0)%vec(3) = co(0)%vec(3) + y_offset
     write(14,'(6e12.4)')start_coord(i)%vec
     start(i) = co(0)
  end do
  close(14)

!write(wordx,'(f0.2)')current
!dist_file = './dists/dist.track_' // trim(wordx) // '_000000'
!open(unit=17,file=dist_file)
!do i=1,scan_params%n_part
!write(17,'(6e12.4)')start(i)%vec(:)
!end do
!close(17)
!!<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
  end if ! end if(rank.eq.0) then 


!as long as transmit is true, the processes can send data, otherwise, they quit
!set transmit(2) such that strong beamsize is NOT updated
  transmit(1) = .true.
  transmit(2) = .false.
  
!MPI requires that mpi types be given in send and receive commands
!but since the size of the reals we use varies, we need to tell it which MPI to pick
#if defined(CESR_LINUX) || defined(CESR_WINCVF)
  if(rp.eq.4) mpi_type = MPI_REAL
  if(rp.eq.8) mpi_type = MPI_DOUBLE_PRECISION
#endif


  if(scan_params%parallel)then
#if defined(CESR_LINUX) || defined(CESR_WINCVF)
  if(rank.eq.0) then

!rank 0 will be in charge or keeping track of all particles as well as luminocity calculations

     call MPI_COMM_SIZE_(MPI_COMM_WORLD,size,ierr)
     size=size-1
     allocate(list(scan_params%n_part))
     do sib_i=1,scan_params%n_part
        list(sib_i)=0
     enddo
     if(size.le.scan_params%n_part) then
        !we have more particles than nodes, so send a particle to each node
        do sib_i=1,size
           onepart(1:6)=start(sib_i)%vec
           onepart(7)=0
           call MPI_SEND_(transmit,2,MPI_LOGICAL,sib_i,go,MPI_COMM_WORLD,ierr)
           call MPI_SEND_(onepart,7,mpi_type,sib_i,sib_i,MPI_COMM_WORLD,ierr)
           list(sib_i)=1
        enddo
     else
        !we have more nodes than particles so send out all particles
        do sib_i=1,scan_params%n_part
           onepart(1:6)=start(sib_i)%vec
           onepart(7)=0
           call MPI_SEND_(onepart,7,mpi_type,sib_i,sib_i,MPI_COMM_WORLD,ierr)
           call MPI_SEND_(transmit,2,MPI_LOGICAL,sib_i,go,MPI_COMM_WORLD,ierr)
           list(sib_i)=1
        enddo
        transmit(1) = .false.
        !the rest of the nodes are not needed
        do sib_i=scan_params%n_part+1,size
           call MPI_SEND_(onepart,7,mpi_type,sib_i,sib_i,MPI_COMM_WORLD,ierr)
           call MPI_SEND_(transmit,2,MPI_LOGICAL,sib_i,go,MPI_COMM_WORLD,ierr)
        enddo
        transmit(1) =.true.
        size = scan_params%n_part
     endif
     
     call MPI_IRECV_(recvpart,7,mpi_type,MPI_ANY_SOURCE,MPI_ANY_TAG,MPI_COMM_WORLD,request,ierr)
     
! Main Loop:  cycle over total number of turns
     if(fit_sig) print *, "Adjusting strong beam size using gaussian-fitted weak beam sizes"
     if(fit_var) print *, "Adjusting strong beam size using statistically calculated weak beam sizes"
     if( (.not. fit_sig) .and. (.not. fit_var) ) print *, "Not adjusting strong beam size"
     num_rpt = scan_params%n_turn / n_typeout
     do sib_j=1,num_rpt
        if (sib_j==1) then
           t_wait = 0
           t_send = 0
        end if
        
        round_flag = .true.
        t3 = MPI_Wtime_()
        t_count = 0
        do while(round_flag)
           
!wait for a particle to come in on the non-blocking recieve, notice that the tag of a send is used to keep track
!of the particle number in the list. The particle is immediatly stored and another non-blocking recv is started

           t_count = t_count + 1
           t5 = MPI_Wtime_()
           call MPI_WAIT_(request,status,ierr)
           t6 = MPI_Wtime_()
           ! record the mean time spent waiting to receive a particle
           t_wait = (t_wait*(t_count-1)+(t6-t5))/t_count
           
           end(status(MPI_TAG))%vec = recvpart(1:6)
           start(status(MPI_TAG))%vec = end(status(MPI_TAG))%vec
           list(status(MPI_TAG)) = 2

           call  MPI_IRECV_(recvpart,7,mpi_type,MPI_ANY_SOURCE,MPI_ANY_TAG,MPI_COMM_WORLD,request,ierr)
           sib_i=0
           found_flag=.false.
!we scan through the list of particles, if one is not processed(i.e. list(particle number) == 0), we send it out
           do while(sib_i.lt.(scan_params%n_part))
              sib_i = sib_i + 1
              if(list(sib_i)==0) then
                 onepart(1:6) = start(sib_i)%vec
                 onepart(7) = sib_j - 1
                 t1 = MPI_Wtime_()
                 call MPI_SEND_(transmit,2,MPI_LOGICAL,status(MPI_SOURCE),go,MPI_COMM_WORLD,ierr)
                 call MPI_SEND_(onepart,7,mpi_type,status(MPI_SOURCE),sib_i,MPI_COMM_WORLD,ierr)
                 t2 = MPI_Wtime_()
                 t_send = (t_send*(sib_i-1)+(t2-t1))/sib_i
                 list(sib_i) = 1
                 found_flag = .true.
                 exit
              endif
           enddo
           
!if we didn't find any particles, then just send out the same one again to save on processing time for the next round
!note that the seventh slot have sib_j rather than sib_j - 1, this is because we are now working on the next round
!also note that there is only one send, that is because when this one finishes, we may not be ready to recive the data, so
!we wait on sending the message with the 'go' tag
           if(.not.found_flag) then
              onepart(1:6) = start(status(MPI_TAG))%vec
              onepart(7) = sib_j
              call MPI_SEND_(onepart,7,mpi_tag,status(MPI_SOURCE),status(MPI_TAG),MPI_COMM_WORLD,ierr)
              list(status(MPI_TAG))=3
           endif

!check if all particles have been processed
           round_flag = list(1).lt.2
           do sib_i=2,scan_params%n_part
              round_flag = round_flag.or.(list(sib_i).lt.2)
           enddo
        enddo
        t4 = MPI_Wtime_()

        ! write .times file
        ti_unit=lunget()
        call file_suffixer (scan_params%file_name, times_file, '.times', .true.)
        open(unit=ti_unit,file=times_file,access="append")
           write(ti_unit,'(i5,i10,3e12.4)') size,sib_j*n_typeout,t_send,t4-t3,t_wait
        close(ti_unit)

!as long as the particle is not lost, we want to reduce it's value in the list by two
!this way we don't bother sending out lost particles and if it has been process it goes to 0 (not processed)
!and if it was sent for a second round it goes to 1(being processed)
     do sib_i=1,scan_params%n_part
        if(start(sib_i)%vec(1) /= 999.)list(sib_i) = list(sib_i) - 2
     enddo

     call size_beam(ring, end, scan_params, transmit, sib_j, n_typeout, orb, phi_x, phi_y, past_params, past_lums, parameters)

!tell all of the processes that they can transmit if they have been holding or that they can quit if it is the end

     do sib_i=1,size
        call MPI_ISEND_(transmit,2,MPI_LOGICAL,sib_i,go,MPI_COMM_WORLD,tempreq,ierr)
     enddo

!check is the strong beam size was updated. 
     if(transmit(2)) then
        call MPI_BCAST_(ring%ele(1)%value(sig_x$),1,mpi_type,0,MPI_COMM_WORLD,ierr)
        call MPI_BCAST_(ring%ele(1)%value(sig_y$),1,mpi_type,0,MPI_COMM_WORLD,ierr)
        call MPI_BCAST_(ring%ele(1)%value(sig_z$),1,mpi_type,0,MPI_COMM_WORLD,ierr)
!transmit(2) should always be false at this point
        transmit(2)=.false.
        do sib_i=1,size
           call MPI_ISEND_(transmit,2,MPI_LOGICAL,sib_i,go,MPI_COMM_WORLD,tempreq,ierr)
        enddo
     end if

!if we are done, send  final message to yourself so clear the non-blocking recv and then exit
     if(.not.transmit(1)) then
        call MPI_ISEND_(onepart,7,mpi_type,0,0,MPI_COMM_WORLD,tempreq,ierr)
        exit
     endif
  end do ! matches do sib_j=1,num_rpt

!>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
! ANDREW CODE     
  deallocate(list)
  deallocate(parameters,past_params,past_lums)
!<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<




else
!we are not rank 0, only need recieve and process particles
     do

!check to see what kind of message we have and recieve accordingly
        call MPI_PROBE_(0,MPI_ANY_TAG,MPI_COMM_WORLD,status,ierr)
        if(status(MPI_TAG).eq.go) then 
           round_flag = .true.
           call MPI_RECV_(transmit,2,MPI_LOGICAL,0,go,MPI_COMM_WORLD,status,ierr)
           if (.not.transmit(1)) exit
           call MPI_RECV_(recvpart,7,mpi_type,0,MPI_ANY_TAG,MPI_COMM_WORLD,status,ierr)
        else 
           round_flag = .false.
           call MPI_RECV_(recvpart,7,mpi_type,0,MPI_ANY_TAG,MPI_COMM_WORLD,status,ierr)
           call MPI_IRECV_(transmit,2,MPI_LOGICAL,0,go,MPI_COMM_WORLD,request,ierr)
        endif
        deallocate(sib_co)
        call reallocate_coord(sib_co,ring%n_ele_max)
        
!if we got the same particle back, we already have the data, just grab it again, this reduces transmission errors
        if(status(MPI_TAG).eq.idnum) then
           recvpart=onepart
           recvpart(7) = onepart(7) + 1
        endif
        onepart(7) = recvpart(7)
        idnum = status(MPI_TAG)
        partstart=recvpart
!this is the old function lum tracker
!if node receives a lost particle, don't track it
308     if(recvpart(1).ne.999.) then
           do sib_j=1,n_typeout
!if a particle is lost during tracking, stop tracking it
              if(recvpart(1).ne.999.) then              
                 sib_co(0)%vec = recvpart(1:6)
                 call track_all(ring, sib_co)
                 onepart(1:6) = sib_co(ring%n_ele_track)%vec
!since we can no longer save p turns, just print out the line number when it gets lost
                 if(ring%param%lost)then      
!                    write(wordx,'(i3.3)') idnum
!                    name = 'lost.'//wordx
!                    d_unit = lunget()
!                    open(unit = d_unit , file=name, status='replace')
!                    write(d_unit ,'(a12,i5,a15,i6)')' Particle # ',idnum, '  lost in turn ',int(sib_j+n_typeout*onepart(7))
!                    close(unit =d_unit)
                    onepart(1:6)=999.
                 endif
              end if
              recvpart = onepart
           enddo
        else
           onepart = recvpart
        end if
!wait to get the recieve and if it says not to transmit, leave, otherwise, keep on going
        if(.not.round_flag) call MPI_WAIT_(request,status,ierr)
        if(transmit(2))then
           call MPI_BCAST_(ring%ele(1)%value(sig_x$),1,mpi_type,0,MPI_COMM_WORLD,ierr)
           call MPI_BCAST_(ring%ele(1)%value(sig_y$),1,mpi_type,0,MPI_COMM_WORLD,ierr)
           call MPI_BCAST_(ring%ele(1)%value(sig_z$),1,mpi_type,0,MPI_COMM_WORLD,ierr)           
           call MPI_IRECV_(transmit,2,MPI_LOGICAL,0,go,MPI_COMM_WORLD,request,ierr)
           recvpart=partstart
! I hate go to statements but as written this is the easiest way to do it
           go to 308
        end if
        if(.not.transmit(1)) exit
        call MPI_SEND_(onepart,7,mpi_type,0,idnum,MPI_COMM_WORLD,ierr)
        
     enddo
  endif
  return
#endif

!Following lines executed if compiled on a non-MPI system
write (*,*) "Parallel operation not an option on this operating system"
return

else !not parallel

   do j=1,scan_params%n_turn
      call lum_tracker(ring, scan_params%n_part, start, end) 
      start(1:scan_params%n_part) = end(1:scan_params%n_part)
      
      if(mod(j,n_typeout) /= 0 .and. j /= scan_params%n_turn)cycle
      sib_j=j/n_typeout

      call size_beam(ring, end, scan_params, transmit, sib_j, n_typeout, orb, phi_x, phi_y, past_params, past_lums, parameters)

  end do
  deallocate(parameters,past_params,past_lums)

  return
end if



end subroutine beambeam_scan

    subroutine lum_tracker(ring,n_part, start, end)

    use bmad_struct
    use bmad_interface

    implicit none
  

    type(lat_struct) ring
    type(coord_struct) start(:),end(:)
    type(coord_struct), allocatable, save :: co(:)

    integer n_part, i, j

    call reallocate_coord(co,ring%n_ele_max)
  
   do i = 1,n_part
      if(start(i)%vec(1) == 999.)cycle
      co(0) = start(i)
      call track_all(ring, co)
      co(0)%vec = co(ring%n_ele_track)%vec
      end(i) = co(0)
      if(ring%param%lost)end(i)%vec(1:6)=999.
  end do

  return
end subroutine lum_tracker

!everything that follows is old code

!   do j=1,scan_params%n_turn
!    call lum_tracker(ring, scan_params%n_part, start, end) 
!    start(1:scan_params%n_part) = end(1:scan_params%n_part)
!
!    call save_last_pturns(pturns, end, scan_params%n_part, j)
!
!    if(mod(j,n_typeout) /= 0 .and. j /= scan_params%n_turn)cycle
!
!    n_ok = 0
!    do i = 1, scan_params%n_part
!      if(end(i)%vec(1) == 999.)cycle
!       n_ok = n_ok +1
!       end_coord(n_ok)%vec = end(i)%vec - orb(0)%vec
!      write(16,'(6e12.4)')end_coord(n_ok)%vec
!      type *,' Finished tracking particle ',n_ok,'  of', scan_params%n_part
!    enddo
!
!    scan_params%n_part_out = n_ok
!
!    if(j == scan_params%n_turn)then
!      call file_suffixer (scan_params%file_name, in_file, '.end', .true.)
!      call histogram(ring%ele(0),end_coord(1:n_ok), in_file, scan_params%sig_out,A)
!     else
!      call histogram(ring%ele(0),end_coord(1:n_ok), 'junk', scan_params%sig_out,A)
!    endif
!
!    if(ring%ele(1)%key == beambeam$)call luminosity_calc (ring%ele(1), &
!                      end_coord, ring%param, n_ok, &
!                      scan_params%lum)
!
!       open(unit=15, file= turns_file, status='unknown', access='append' )
!       write(15,'(2f10.5,2x,2f10.5,3e12.4,2x,3e12.4,2x,i5,2x,e12.4,2x,i5)')phi_x/twopi, phi_y/twopi, &
!            ring%a%tune/twopi, ring%b%tune/twopi, &
!                     scan_params%sig_in(1:3), &
!                                    scan_params%sig_out(1:3), j, scan_params%lum, scan_params%n_part_out
!       close(unit=15)
!       print *, j, scan_params%lum,scan_params%n_part_out
!  end do 

!    subroutine lum_tracker(ring,n_part, start, end)
!
!    use bmad_struct
!    use bmad_interface
!
!    implicit none
!  
!
!    type(lat_struct) ring
!    type(coord_struct) start(:),end(:)
!    type(coord_struct), allocatable, save :: co(:)
!
!    integer n_part, i, j
!
!    call reallocate_coord(co,ring%n_ele_max)
!  
!   do i = 1,n_part
!      if(start(i)%vec(1) == 999.)cycle
!      co(0) = start(i)
!      call track_all(ring, co)
!      co(0)%vec = co(ring%n_ele_track)%vec
!      end(i) = co(0)
!      if(ring%param%lost)end(i)%vec(1:6)=999.
!  end do
!
!  return
!  end


!    subroutine save_last_pturns(pturns, end, n_part, turn)
!    use bmad
!    implicit none
!
!    type turnsave_struct
!      type (coord_struct) coord(2048)
!    end type
!
!    type (coord_struct)  end(1:)
!    type (turnsave_struct), allocatable, save :: turnsave(:)
!    integer i, n_part, pturns, nlost/0/, turn
!    integer d_unit,k
!    integer j/0/
!
!    logical, allocatable, save :: write(:)
!
!    character wordx*3, name*12
!
!      if(.not. allocated(turnsave))allocate(turnsave(pturns))
!      if(.not. allocated(write))then
!         allocate(write(n_part))
!         write(1:n_part)=.false.
!      endif
!      if(pturns > 2048)then
!        type *,' Space for only 2048 particles in SAVE_LAST_PTURNS'
!        stop
!      endif
!
!       if(j < pturns)then
!          j = j+1
!          turnsave(j)%coord(1:n_part) = end(1:n_part)
!       endif
!       if(j == pturns)then 
!         do i =1,j-1
!           turnsave(i)%coord(1:n_part) = turnsave(i+1)%coord(1:n_part)
!         end do
!         turnsave(j)%coord(1:n_part) = end(1:n_part)
!       endif
!
!       do i = 1, n_part
!        if(write(i))cycle
!        if(end(i)%vec(1) == 999.)then !dump
!          write(i) = .true.
!          write(wordx,'(i3.3)')i
!          name = 'lost.'//wordx
!          d_unit = lunget()
!          open(unit = d_unit , file=name, status='new')
!           write(d_unit ,'(a12,i5,a15,i5,a6,i5,a6)')' Particle # ',i, '  lost in turn ',turn, ' last ',j,' turns'
!           do k=1,j
!             write(d_unit, '(6e12.4)')turnsave(k)%coord(i)%vec(1:6)
!           end do
!          close(unit =d_unit)
!        endif
!      end do 
!
!    return
!    end

