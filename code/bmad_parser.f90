!+
! Subroutine bmad_parser (lat_file, lat, make_mats6, digested_read_ok, use_line)
!
! Subroutine to parse a BMAD input file and put the information in lat.
!
! Because of the time it takes to parse a file BMAD_PARSER will save 
! LAT in a "digested" file with the name:
!               'digested_' // lat_file   ! for single precision BMAD version
!               'digested8_' // lat_file  ! for double precision BMAD version
! For subsequent calls to the same lat_file, BMAD_PARSER will just read in the
! digested file. BMAD_PARSER will always check to see that the digested file
! is up-to-date and if not the digested file will not be used.
!
! Modules needed:
!   use bmad
!
! Input:
!   lat_file   -- Character(*): Name of the input file.
!   make_mats6 -- Logical, optional: Compute the 6x6 transport matrices for the
!                   Elements? Default is True.
!   use_line   -- Character(*), optional: If present then override the use 
!                   statement in the lattice file and use use_line instead.
!
! Output:
!   lat -- lat_struct: Lat structure. See bmad_struct.f90 for more details.
!     %ele(:)%mat6  -- This is computed assuming an on-axis orbit 
!     %ele(:)%s     -- This is also computed.
!   digested_read_ok -- Logical, optional: Set True if the digested file was
!                        successfully read. False otherwise.
!   bmad_status      -- Bmad status common block.
!     %ok              -- Set True if parsing is successful. False otherwise.
!         
! Defaults:
!   lat%param%particle          = positron$
!   lat%param%lattice_type      = circular_lattice$
!   lat%param%aperture_limit_on = .true.
!-

#include "CESR_platform.inc"

subroutine bmad_parser (lat_file, lat, make_mats6, digested_read_ok, use_line)

  use bmad_parser_mod, except => bmad_parser
  use cesr_utils
  use multipole_mod
  use random_mod

  implicit none

  type (lat_struct), target :: lat, in_lat
  type (ele_struct) this_ele
  type (seq_struct), save, target :: sequence(1000)
  type (seq_struct), pointer :: seq, seq2
  type (ele_struct), pointer :: beam_ele, param_ele, beam_start_ele
  type (seq_ele_struct), target :: dummy_seq_ele
  type (seq_ele_struct), pointer :: s_ele, this_seq_ele
  type (parser_lat_struct) plat
  type (seq_stack_struct) stack(40)
  type (ele_struct), save, pointer :: ele
  type (ele_struct), allocatable, save :: old_ele(:) 
  type (used_seq_struct), allocatable, save ::  used_line(:), used2(:)

  integer, allocatable :: ix_lat(:)
  integer, allocatable :: seq_indexx(:), in_indexx(:)
  character(40), allocatable ::  in_name(:), seq_name(:)

  integer ix_word, i_use, i, j, k, n, ix, i_lev, ixm(100)
  integer n_ele_use, digested_version, key, n0_multi, loop_counter
  integer ix1, ix2, iseq_tot, ix_multipass, n_ele_max, n_multi
  integer, pointer :: n_max

  character(*) lat_file
  character(*), optional :: use_line

  character(1) delim
  character(40) word_2, name, multipass_line
  character(16) :: r_name = 'bmad_parser'
  character(40) this_name, word_1
  character(200) full_lat_file_name, digested_file
  character(280) parse_line_save

  real(rp) energy_beam, energy_param, energy_0

  logical, optional :: make_mats6, digested_read_ok
  logical parsing, delim_found, arg_list_found, doit
  logical file_end, found, err_flag, finished, exit_on_error
  logical detected_expand_lattice_cmd, multipass, write_digested

! see if digested file is open and current. If so read in and return.
! Note: The name of the digested file depends upon the real precision.

  bp_com%parser_name = 'BMAD_PARSER'  ! Used for error messages.
  write_digested = .true.

  call form_digested_bmad_file_name (lat_file, digested_file, full_lat_file_name)
  call read_digested_bmad_file (digested_file, lat, digested_version)

  ! Must make sure that if use_line is present the digested file has used the 
  ! correct line

  if (present(use_line)) then
    call str_upcase (name, use_line)
    if (name /= lat%name) bmad_status%ok = .false.
  endif

  if (bmad_status%ok) then
    call set_taylor_order (lat%input_taylor_order, .false.)
    call set_ptc (lat%E_TOT, lat%param%particle)
    if (lat%input_taylor_order == bmad_com%taylor_order) then
      if (present(digested_read_ok)) digested_read_ok = .true.
      return
    else
      if (bmad_status%type_out) then
         call out_io (s_info$, r_name, 'Taylor_order has changed.', &
             'Taylor_order in digested file: \i4\ ', &
             'Taylor_order now:              \i4\ ', &
             i_array = (/ lat%input_taylor_order, bmad_com%taylor_order /) )
      endif
      if (lat%input_taylor_order > bmad_com%taylor_order) &
                                           write_digested = .false.
    endif
  endif

  if (present(digested_read_ok)) digested_read_ok = .false.

! save all elements that have a taylor series

  call save_taylor_elements (lat, old_ele)

! here if not OK bmad_status. So we have to do everything from scratch...
! init variables.

  nullify (plat%ele)
  call init_lat (in_lat, 1000)
  call init_lat (lat, 1)
  call allocate_plat (in_lat, plat)

  bmad_status%ok = .true.
  if (bmad_status%type_out) &
       call out_io (s_info$, r_name, 'Creating new digested file...')

  bp_com%error_flag = .false.                 ! set to true on an error
  call file_stack('push', lat_file, finished)  ! open file on stack
  if (.not. bmad_status%ok) return
  iseq_tot = 0                            ! number of sequences encountered

  bp_com%input_line_meaningful = .true.
  bp_com%ran_function_was_called = .false.

  call init_ele (in_lat%ele(0))
  in_lat%ele(0)%name = 'BEGINNING'     ! Beginning element
  in_lat%ele(0)%key = init_ele$

  call mat_make_unit (in_lat%ele(0)%mat6)
  call clear_lat_1turn_mats (in_lat)

  beam_ele => in_lat%ele(1)
  call init_ele (beam_ele)
  beam_ele%name = 'BEAM'                 ! fake beam element
  beam_ele%key = def_beam$               ! "definition of beam"
  beam_ele%value(particle$) = positron$  ! default

  param_ele => in_lat%ele(2)
  call init_ele (param_ele)
  param_ele%name = 'PARAMETER'           ! For parameters 
  param_ele%key = def_parameter$
  param_ele%value(lattice_type$) = circular_lattice$  ! Default

  beam_start_ele => in_lat%ele(3)
  call init_ele (beam_start_ele)
  beam_start_ele%name = 'BEAM_START'           ! For parameters 
  beam_start_ele%key = def_beam_start$

  n_max => in_lat%n_ele_max
  n_max = 3                              ! Number of elements encountered

  lat%n_control_max = 0
  detected_expand_lattice_cmd = .false.

!-----------------------------------------------------------
! main parsing loop

  loop_counter = 0  ! Used for debugging
  parsing_loop: do 

    loop_counter = loop_counter + 1

! get a line from the input file and parse out the first word

    call load_parse_line ('normal', 1, file_end)  ! load an input line
    call get_next_word (word_1, ix_word, '[:](,)= ', delim, delim_found, .true.)
    if (file_end) then
      word_1 = 'END_FILE'
      ix_word = 8
    else
      call verify_valid_name(word_1, ix_word)
    endif

! PARSER_DEBUG

    if (word_1(:ix_word) == 'PARSER_DEBUG') then
      bp_com%parser_debug = .true.
      bp_com%debug_line = bp_com%parse_line
      call str_upcase (bp_com%debug_line, bp_com%debug_line)
      call out_io (s_info$, r_name, 'FOUND IN FILE: "PARSER_DEBUG". DEBUG IS NOW ON')
      cycle parsing_loop
    endif

! NO_DIGESTED

    if (word_1(:ix_word) == 'NO_DIGESTED') then
      write_digested = .false.
      call out_io (s_info$, r_name, 'FOUND IN FILE: "NO_DIGESTED". NO DIGESTED FILE WILL BE CREATED')
      cycle parsing_loop
    endif

! DEBUG_MARKER is used to be able to easily set a break within the debugger

    if (word_1(:ix_word) == 'DEBUG_MARKER') then
      word_1 = 'ABC'          ! An executable line to set a break on
      cycle parsing_loop
    endif

! USE command...

    if (word_1(:ix_word) == 'USE') then
      if (delim /= ',') call warning ('"USE" NOT FOLLOWED BY COMMA')
      call get_next_word(word_2, ix_word, ':(=,)', delim, delim_found, .true.)
      if (ix_word == 0) call error_exit  &
                                ('NO BEAM LINE SPECIFIED WITH "USE"', ' ')
      call verify_valid_name(word_2, ix_word)
      lat%name = word_2
      cycle parsing_loop
    endif

! TITLE command

    if (word_1(:ix_word) == 'TITLE') then
      if (delim_found) then
        if (delim /= " " .and. delim /= ",") call warning &
                            ('BAD DELIMITOR IN "TITLE" COMMAND')
        call type_get (this_ele, descrip$, delim, delim_found)
        lat%title = this_ele%descrip
        deallocate (this_ele%descrip)
      else
        read (bp_com%current_file%f_unit, '(a)') lat%title
        bp_com%current_file%i_line = bp_com%current_file%i_line + 1
      endif
      cycle parsing_loop
    endif

! CALL command

    if (word_1(:ix_word) == 'CALL') then
      call get_called_file(delim)
      if (.not. bmad_status%ok) return
      cycle parsing_loop
    endif

! BEAM command

    if (word_1(:ix_word) == 'BEAM') then
      if (delim /= ',') call warning ('"BEAM" NOT FOLLOWED BY COMMA')
      parsing = .true.
      do while (parsing)
        if (.not. delim_found) then
          parsing = .false.
        elseif (delim /= ',') then
          call warning ('EXPECTING: "," BUT GOT: ' // delim,  &
                                                     'FOR "BEAM" COMMAND')
          parsing = .false.
        else
          call get_attribute (def$, beam_ele, &
                                 in_lat, plat, delim, delim_found, err_flag)
        endif
      enddo
      cycle parsing_loop
    endif
                   
! LATTICE command

    if (word_1(:ix_word) == 'LATTICE') then
      if (delim /= ':' .and. delim /= '=') then
        call warning ('"LATTICE" NOT FOLLOWED BY ":"')
      else
        if (delim == ':' .and. bp_com%parse_line(1:1) == '=') &
                      bp_com%parse_line = bp_com%parse_line(2:)  ! trim off '='
        call get_next_word (lat%lattice, ix_word, ',', &
                                                   delim, delim_found, .true.)
      endif
      cycle parsing_loop
    endif

! EXPAND_LATTICE command

    if (word_1(:ix_word) == 'EXPAND_LATTICE') then
      detected_expand_lattice_cmd = .true.
      exit parsing_loop
    endif

! RETURN or END_FILE command

    if (word_1(:ix_word) == 'RETURN' .or.  &
                                    word_1(:ix_word) == 'END_FILE') then
      call file_stack ('pop', ' ', finished)
      if (.not. bmad_status%ok) return
      if (finished) exit parsing_loop ! break loop
      cycle parsing_loop
    endif

! variable definition or element redef...

! if an element attribute redef

    found = .false.
    if (delim == '[') then

      call get_next_word (word_2, ix_word, ']', delim, delim_found, .true.)
      if (.not. delim_found) then
        call warning ('OPENING "[" FOUND WITHOUT MATCHING "]"')
        cycle parsing_loop
      endif

      call get_next_word (this_name, ix_word, ':=', delim, delim_found, .true.)
      if (.not. delim_found .or. ix_word /= 0) then
        call warning ('MALFORMED ELEMENT ATTRIBUTE REDEFINITION')
        cycle parsing_loop
      endif

      ! If delim is ':' then this is an error since get_next_word treats
      ! a ':=' construction as a '=' 

      if (delim == ':') then
        call warning ('MALFORMED ELEMENT ATTRIBUTE REDEF')
        cycle parsing_loop
      endif

      ! find associated element and evaluate the attribute value

      do i = 0, n_max

        ele => in_lat%ele(i)

        if (ele%name == word_1 .or. key_name(ele%key) == word_1) then
          bp_com%parse_line = trim(word_2) // ' = ' // bp_com%parse_line 
          if (found) then   ! if not first time
            bp_com%parse_line = parse_line_save
          else
            parse_line_save = bp_com%parse_line
          endif
          call get_attribute (redef$, ele, in_lat, plat, &
                                             delim, delim_found, err_flag)
          if (delim_found) call warning ('BAD DELIMITER: ' // delim)
          found = .true.
        endif

      enddo

      if (.not. found) call warning ('ELEMENT NOT FOUND: ' // word_1)
      cycle parsing_loop

! else must be a variable

    elseif (delim == '=') then

      call parser_add_variable (word_1, in_lat)
      cycle parsing_loop

    endif

! if a "(" delimitor then we are looking at a replacement line.

    if (delim == '(') then
      call get_sequence_args (word_1, sequence(iseq_tot+1)%dummy_arg, &
                                                       delim, err_flag)
      ix = size(sequence(iseq_tot+1)%dummy_arg)
      allocate (sequence(iseq_tot+1)%corresponding_actual_arg(ix))
      if (err_flag) cycle parsing_loop
      arg_list_found = .true.
      call get_next_word (word_2, ix_word, '(): =,', &
                                                 delim, delim_found, .true.)
      if (word_2 /= ' ') call warning &
                  ('":" NOT FOUND AFTER REPLACEMENT LINE ARGUMENT LIST. ' // &
                  'FOUND: ' // word_2, 'FOR LINE: ' // word_1)
    else
      arg_list_found = .false.
    endif

! must have a ":" delimiter now

    if (delim /= ':') then
      call warning ('1ST DELIMITER IS NOT ":". IT IS: ' // delim,  &
                                                       'FOR: ' // word_1)
      cycle parsing_loop
    endif

! only possibilities left are: element, list, or line
! to decide which look at 2nd word

    call get_next_word(word_2, ix_word, ':=,', delim, delim_found, .true.)
    if (ix_word == 0) call error_exit ('NO NAME FOUND AFTER: ' // word_1, ' ')

    if (word_2 == 'LINE[MULTIPASS]') then
      word_2 = 'LINE'
      ix_word = 4
      multipass = .true.
    else
      multipass = .false.
    endif

    call verify_valid_name(word_2, ix_word)

! arg lists are only used with lines

    if (word_2(:ix_word) /= 'LINE' .and. arg_list_found) then
      call warning ('ARGUMENTS "XYZ(...):" ARE ONLY USED WITH REPLACEMENT LINES.', &
                                                        'FOR: ' // word_1)
      cycle parsing_loop
    endif

! if line or list

    if (word_2(:ix_word) == 'LINE' .or. word_2(:ix_word) == 'LIST') then
      iseq_tot = iseq_tot + 1
      if (iseq_tot > size(sequence)-1) then
        print *, 'ERROR IN BMAD_PARSER: NEED TO INCREASE LINE ARRAY!'
        call err_exit
      endif

      sequence(iseq_tot)%name = word_1
      sequence(iseq_tot)%multipass = multipass

      if (delim /= '=') call warning ('EXPECTING: "=" BUT GOT: ' // delim)
      if (word_2(:ix_word) == 'LINE') then
        sequence(iseq_tot)%type = line$
        if (arg_list_found) sequence(iseq_tot)%type = replacement_line$
      else
        sequence(iseq_tot)%type = list$
      endif
      call seq_expand1 (sequence, iseq_tot, in_lat, .true.)

! if not line or list then must be an element

    else

      if (word_1 == 'BEGINNING' .or. word_1 == 'BEAM' .or. word_1 == 'BEAM_START') then
        call warning ('ELEMENT NAME CORRESPONDS TO A RESERVED WORD: ' // word_1)
        cycle parsing_loop
      endif

      n_max = n_max + 1
      if (n_max > ubound(in_lat%ele, 1)) then
        call allocate_lat_ele (in_lat)
        beam_ele => in_lat%ele(1)
        param_ele => in_lat%ele(2)
        beam_start_ele => in_lat%ele(3)
        call allocate_plat (in_lat, plat)
      endif

      call init_ele (in_lat%ele(n_max))
      in_lat%ele(n_max)%name = word_1

! Check for valid element key name or if element is part of a element key.
! If none of the above then we have an error.

      found = .false.  ! found a match?

      in_lat%ele(n_max)%key = key_name_to_key_index(word_2, .true.)
      if (in_lat%ele(n_max)%key > 0) then
        call preparse_element_init (in_lat%ele(n_max))
        found = .true.
      endif

      if (.not. found) then
        do i = 1, n_max-1
          if (word_2 == in_lat%ele(i)%name) then
            in_lat%ele(n_max) = in_lat%ele(i)
            in_lat%ele(n_max)%name = word_1
            found = .true.
            exit
          endif
        enddo
      endif

      if (.not. found) then
        call warning ('KEY NAME NOT RECOGNIZED: ' // word_2,  &
                       'FOR ELEMENT: ' // in_lat%ele(n_max)%name)
        cycle parsing_loop
      endif

! Element definition...
! First: set defaults.

      call parser_set_ele_defaults (in_lat%ele(n_max))

      key = in_lat%ele(n_max)%key
      if (key == overlay$ .or. key == group$ .or. key == i_beam$) then
        if (delim /= '=') then
          call warning ('EXPECTING: "=" BUT GOT: ' // delim,  &
                      'FOR ELEMENT: ' // in_lat%ele(n_max)%name)
          cycle parsing_loop        
        endif

        if (key == overlay$) in_lat%ele(n_max)%control_type = overlay_lord$
        if (key == group$)   in_lat%ele(n_max)%control_type = group_lord$
        if (key == i_beam$)  in_lat%ele(n_max)%control_type = i_beam_lord$

        call get_overlay_group_names(in_lat%ele(n_max), in_lat, &
                                                    plat, delim, delim_found)

        if (key /= i_beam$ .and. .not. delim_found) then
          call warning ('NO CONTROL ATTRIBUTE GIVEN AFTER CLOSING "}"',  &
                        'FOR ELEMENT: ' // in_lat%ele(n_max)%name)
          cycle parsing_loop
        endif

      endif

! Second: We need to get the attribute values for the element.

      parsing = .true.
      do while (parsing)
        if (.not. delim_found) then          ! if nothing more
          parsing = .false.
        elseif (delim /= ',') then
          call warning ('EXPECTING: "," BUT GOT: ' // delim,  &
                        'FOR ELEMENT: ' // in_lat%ele(n_max)%name)
          cycle parsing_loop
        else
          call get_attribute (def$, in_lat%ele(n_max), &
                                  in_lat, plat, delim, delim_found, err_flag)
          if (err_flag) cycle parsing_loop
        endif
      enddo

    endif

  enddo parsing_loop       ! main parsing loop

!---------------------------------------------------------------------------
! we now have read in everything. 

  bp_com%input_line_meaningful = .false.

! sort elements and lists and check for duplicates
! seq_name(:) and in_name(:) arrays speed up the calls to find_indexx since
! the compiler does not have to repack the memory.

  allocate (seq_indexx(iseq_tot), seq_name(iseq_tot))
  seq_name = sequence(1:iseq_tot)%name
  call indexx (seq_name, seq_indexx(1:iseq_tot))

  allocate (in_indexx(n_max), in_name(n_max))
  in_name = in_lat%ele(1:n_max)%name
  call indexx (in_name, in_indexx(1:n_max))

  do i = 1, iseq_tot-1
    ix1 = seq_indexx(i)
    ix2 = seq_indexx(i+1)
    if (sequence(ix1)%name == sequence(ix2)%name) call warning  &
                      ('DUPLICATE LINE NAME ' // sequence(ix1)%name)
  enddo

  do i = 1, n_max-1
    ix1 = in_indexx(i)
    ix2 = in_indexx(i+1)
    if (in_lat%ele(ix1)%name == in_lat%ele(ix2)%name) call warning &
                    ('DUPLICATE ELEMENT NAME ' // in_lat%ele(ix1)%name)
  enddo

  i = 1; j = 1
  do
    if (i > iseq_tot) exit
    if (j > n_max) exit
    ix1 = seq_indexx(i)
    ix2 = in_indexx(j)
    if (sequence(ix1)%name == in_lat%ele(ix2)%name) call warning  &
          ('LINE AND ELEMENT HAVE THE SAME NAME: ' // sequence(ix1)%name)
    if (sequence(ix1)%name < in_lat%ele(ix2)%name) then
      i = i + 1
    else
      j = j + 1
    endif
  enddo

! find line corresponding to the "use" statement.

  if (present (use_line)) call str_upcase (lat%name, use_line)
  if (lat%name == blank) call error_exit &
            ('NO "USE" STATEMENT FOUND.', 'I DO NOT KNOW WHAT LINE TO USE!')

  call find_indexx (lat%name, seq_name, seq_indexx, iseq_tot, i_use)
  if (i_use == 0) call error_exit &
      ('CANNOT FIND DEFINITION OF LINE IN "USE" STATEMENT: ' // lat%name, ' ')

  if (sequence(i_use)%type /= line$) call error_exit  &
                      ('NAME IN "USE" STATEMENT IS NOT A LINE!', ' ')

! Now to expand the lines and lists to find the elements to use.
! First go through the lines and lists and index everything.

  do k = 1, iseq_tot
    do i = 1, size(sequence(k)%ele(:))

      s_ele => sequence(k)%ele(i)
      name = s_ele%name

!      ix = index(name, '\')   ! ' 
!      if (ix /= 0) name = name(:ix-1) ! strip off everything after \
  
      if (s_ele%ix_arg > 0) then   ! dummy arg
        s_ele%type = element$
        cycle
      endif

      call find_indexx (name, in_name, in_indexx, n_max, j)
      if (j == 0) then  ! if not an element it must be a sequence
        call find_indexx (name, seq_name, seq_indexx, iseq_tot, j)
        if (j == 0) then  ! if not a sequence then I don't know what it is
          s_ele%ix_ele = -1
          s_ele%type = element$
        else
          s_ele%ix_ele = j
          s_ele%type = sequence(j)%type
        endif
        if (s_ele%type == list$ .and. s_ele%reflect) call warning ( &
                          'A REFLECTION WITH A LIST IS NOT ALLOWED IN: '  &
                          // sequence(k)%name, 'FOR LIST: ' // s_ele%name, &
                          seq = sequence(k))
        if (sequence(k)%type == list$) &
                call warning ('A REPLACEMENT LIST: ' // sequence(k)%name, &
                'HAS A NON-ELEMENT MEMBER: ' // s_ele%name)
 
      else    ! if an element...
        s_ele%ix_ele = j
        s_ele%type = element$
      endif

    enddo
  enddo

! to expand the "used" line we use a stack for nested sublines.
! IX_LAT is the expanded array of elements in the lat.
! init stack

  i_lev = 1                          ! level on the stack
  seq => sequence(i_use)

  stack(1)%ix_seq    = i_use           ! which sequence to use for the lat
  stack(1)%ix_ele    =  1              ! we start at the beginning
  stack(1)%direction = +1              ! and move forward
  stack(1)%rep_count = seq%ele(1)%rep_count
  stack(1)%multipass = .false.
  stack(1)%tag = ''

  n_ele_use = 0
           
  allocate (used_line(ubound(in_lat%ele, 1)))
  allocate (ix_lat(ubound(in_lat%ele, 1)))
  ix_lat = -1
  sequence(:)%ix = 1  ! Init. Used for replacement list index

! Expand "used" line...

  parsing = .true.
  line_expansion: do while (parsing)

    ! if rep_count is zero then change %ix_ele index by +/- 1 and reset the rep_count.
    ! if we have got to the end of the current line then pop the stack back to
    ! the next lower level.
    ! Also check if we have gotten to level 0 which says that we are done.
    ! If we have stepped out of a multipass line which has been trasversed in reverse
    !   then we need to do some bookkeeping to keep the elements straight.

    if (stack(i_lev)%rep_count == 0) then      ! goto next element in the sequence
      stack(i_lev)%ix_ele = stack(i_lev)%ix_ele + stack(i_lev)%direction 
      ix = stack(i_lev)%ix_ele

      if (ix > 0 .and. ix <= size(seq%ele)) then
        stack(i_lev)%rep_count = seq%ele(ix)%rep_count
      else
        i_lev = i_lev - 1
        if (i_lev == 0) exit line_expansion
        seq => sequence(stack(i_lev)%ix_seq)
        if (.not. stack(i_lev)%multipass .and. stack(i_lev+1)%multipass) then
          if (stack(i_lev+1)%direction == -1) then
            used_line(n0_multi:n_ele_use)%ix_multipass = &
                          used_line(n_ele_use:n0_multi:-1)%ix_multipass
          endif
        endif
        cycle
      endif

    endif

    ! 

    s_ele => seq%ele(stack(i_lev)%ix_ele)  ! next element, line, or list
    stack(i_lev)%rep_count = stack(i_lev)%rep_count - 1

    ! if s_ele is a dummy arg then get corresponding actual arg.

    ix = s_ele%ix_arg
    if (ix /= 0) then  ! it is a dummy argument.
      name = seq%corresponding_actual_arg(ix)
      s_ele => dummy_seq_ele
      s_ele%name = name
      call find_indexx (name, in_name, in_indexx, n_max, j)
      if (j == 0) then  ! if not an element it must be a sequence
        call find_indexx (name, seq_name, seq_indexx, iseq_tot, j)
        if (j == 0) then  ! if not a sequence then I don't know what it is
          call warning ('CANNOT FIND DEFINITION FOR: ' // name, &
                          'IN LINE: ' // seq%name, seq = seq)
          call err_exit
        endif
        s_ele%ix_ele = j
        s_ele%type = sequence(j)%type
      else
        s_ele%ix_ele = j 
        s_ele%type = element$
      endif
      
    endif

! if an element

    select case (s_ele%type)

    case (element$, list$) 

      if (s_ele%type == list$) then
        seq2 => sequence(s_ele%ix_ele)
        j = seq2%ix
        this_seq_ele => seq2%ele(j)
        seq2%ix = seq2%ix + 1
        if (seq2%ix > size(seq2%ele(:))) seq2%ix = 1
      else
        if (s_ele%tag /= '') then
          call warning ('ELEMENTS IN A LINE OR LIST ARE NOT ALLOWED TO HAVE A TAG.', &
                        'FOUND ILLEGAL TAG FOR ELEMENT: ' // s_ele%name, &
                        'IN THE LINE/LIST: ' // seq%name, seq)
        endif
        this_seq_ele => s_ele
      endif

      if (this_seq_ele%ix_ele < 1) call warning('NOT A DEFINED ELEMENT: ' // &
                          s_ele%name, 'IN THE LINE/LIST: ' // seq%name, seq = seq)


      if (n_ele_use+1 > size(ix_lat)) then
        n = 1.5*n_ele_use
        call re_allocate (ix_lat, n)
        ix = size(used_line) 
        allocate (used2(ix))
        used2(1:ix) = used_line(1:ix)
        deallocate (used_line)
        allocate (used_line(1:n))
        used_line(1:ix) = used2(1:ix)
        deallocate (used2)
      endif

      call pushit (ix_lat, n_ele_use, this_seq_ele%ix_ele)

      used_line(n_ele_use)%name = this_seq_ele%name

      if (stack(i_lev)%tag /= '' .and. s_ele%tag /= '') then
        used_line(n_ele_use)%tag =  trim(stack(i_lev)%tag) // '.' // s_ele%tag
      elseif (s_ele%tag /= '') then
        used_line(n_ele_use)%tag = s_ele%tag
      else
        used_line(n_ele_use)%tag =  stack(i_lev)%tag
      endif

      if (stack(i_lev)%multipass) then
        ix_multipass = ix_multipass + 1
        used_line(n_ele_use)%ix_multipass = ix_multipass
        used_line(n_ele_use)%multipass_line = multipass_line
      else
        used_line(n_ele_use)%ix_multipass = 0
      endif


! if a line:
!     a) move pointer on current level past line element
!     b) go to the next higher level
!     c) initialize pointers for the higher level to use the line

    case (line$, replacement_line$)
      i_lev = i_lev + 1
      if (i_lev > size(stack)) then
        call warning ('NESTED LINES EXCEED STACK DEPTH!')
        call err_exit
      endif
      if (s_ele%type == replacement_line$) then
        seq2 => sequence(s_ele%ix_ele)
        if (size(seq2%dummy_arg) /= size(s_ele%actual_arg)) then
          call warning ('WRONG NUMBER OF ARGUMENTS FORREPLACEMENT LINE: ' // &
              s_ele%name, 'WHEN USED IN LINE: ' // seq%name, seq = seq)
          call err_exit
        endif
        arg_loop: do i = 1, size(seq2%dummy_arg)
          seq2%corresponding_actual_arg(i) = s_ele%actual_arg(i)
          if (associated(seq%dummy_arg)) then
            do j = 1, size(seq%dummy_arg)
              if (seq2%corresponding_actual_arg(i) == seq%dummy_arg(j)) then
                seq2%corresponding_actual_arg(i) = seq%corresponding_actual_arg(j)
                cycle arg_loop
              endif
            enddo
          endif
          name = seq2%corresponding_actual_arg(i)
        enddo arg_loop
      endif

      seq => sequence(s_ele%ix_ele)
      stack(i_lev)%ix_seq = s_ele%ix_ele
      stack(i_lev)%direction = stack(i_lev-1)%direction
      stack(i_lev)%multipass = (stack(i_lev-1)%multipass .or. seq%multipass)
      if (stack(i_lev-1)%tag /= '' .and. s_ele%tag /= '') then
         stack(i_lev)%tag = trim(stack(i_lev-1)%tag) // '.' // s_ele%tag
      elseif (stack(i_lev-1)%tag /= '') then
         stack(i_lev)%tag = trim(stack(i_lev-1)%tag)
      else
         stack(i_lev)%tag = s_ele%tag
      endif
      if (s_ele%reflect) stack(i_lev)%direction = -stack(i_lev)%direction

      if (stack(i_lev)%direction == 1) then
        ix = 1
      else
        ix = size(seq%ele(:))
      endif

      stack(i_lev)%ix_ele = ix
      stack(i_lev)%rep_count = seq%ele(ix)%rep_count

      if (stack(i_lev)%multipass .and. .not. stack(i_lev-1)%multipass) then
        ix_multipass = 1
        n0_multi = n_ele_use + 1
        multipass_line = sequence(stack(i_lev)%ix_seq)%name
      endif

    case default
      call warning ('INTERNAL SEQUENCE ERROR!')

    end select

  enddo line_expansion

!---------------------------------------------------------------
! we now have the line to use in constructing the lat.
! now to put the elements in LAT in the correct order.
! superimpose, overlays, and groups are handled later.
! first load beam parameters.

  call allocate_lat_ele(lat, n_ele_use+100)

  lat%version            = bmad_inc_version$
  lat%input_file_name    = full_lat_file_name             ! save input file
  lat%param%particle     = nint(beam_ele%value(particle$))
  lat%n_ele_track        = n_ele_use
  lat%n_ele_max          = n_ele_use
  lat%n_ic_max           = 0                     
  lat%n_control_max      = 0    
  lat%param%growth_rate  = 0
  lat%param%stable            = .true.
  lat%param%aperture_limit_on = .true.

  lat%ele(0)     = in_lat%ele(0)    ! Beginning element
  lat%beam_start = in_lat%beam_start
  lat%a          = in_lat%a
  lat%b          = in_lat%b
  lat%z          = in_lat%z

  if (beam_ele%value(n_part$) /= 0 .and. param_ele%value(n_part$) /= 0) then
    call warning ('BOTH "PARAMETER[N_PART]" AND "BEAM, N_PART" SET.')
  elseif (beam_ele%value(n_part$) /= 0) then
    lat%param%n_part = beam_ele%value(n_part$)
  else
    lat%param%n_part = param_ele%value(n_part$)
  endif

! The lattice name from a "parameter[lattice] = ..." line is 
! stored the param_ele%descrip string

  if (associated(param_ele%descrip)) then
    lat%lattice = param_ele%descrip
    deallocate (param_ele%descrip)
  endif

! New way of doing things

  lat%param%lattice_type = nint(param_ele%value(lattice_type$))

  if (nint(param_ele%value(taylor_order$)) /= 0) &
            lat%input_taylor_order = nint(param_ele%value(taylor_order$))

! old way of doing things

  do i = 1, bp_com%ivar_tot
    if (bp_com%var_name(i) == 'LATTICE_TYPE')  &
                          lat%param%lattice_type = nint(bp_com%var_value(i))
    if (bp_com%var_name(i) == 'TAYLOR_ORDER') &
                          lat%input_taylor_order = nint(bp_com%var_value(i))
  enddo

! Set taylor order and lattice_type

  if (lat%input_taylor_order /= 0) &
       call set_taylor_order (lat%input_taylor_order, .false.)

  if (any(in_lat%ele(:)%key == lcavity$) .and. &
                          lat%param%lattice_type /= linear_lattice$) then
    print *, 'Note in BMAD_PARSER: This lattice has a LCAVITY.'
    print *, '     Setting the LATTICE_TYPE to LINEAR_LATTICE.'
    lat%param%lattice_type = linear_lattice$
  endif

! Do bookkeeping for settable dependent variables.

  do i = 1, n_max
    ele => in_lat%ele(i)
    call settable_dep_var_bookkeeping (ele)
  enddo

! Transfer the ele information from the in_lat to lat

  do i = 1, n_ele_use
    ele => lat%ele(i)
    ele = in_lat%ele(ix_lat(i)) 
    ele%name = used_line(i)%name
    if (used_line(i)%tag /= '') ele%name = trim(used_line(i)%tag) // '.' // ele%name
  enddo

! First work on multipass before overlays, groups, and usuperimpose. 
! This is important since the elements in the lattice get
! renamed and if not done first would confuse any overlays, i_beams, etc.
! Multipass elements are paired by multipass index and multipass line name

  n_ele_max = lat%n_ele_max
  do i = 1, n_ele_max
    if (used_line(i)%ix_multipass /= 0) then 
      n_multi = 0  ! number of elements to slave together
      ix_multipass = used_line(i)%ix_multipass
      do j = i, n_ele_max
        if (used_line(j)%ix_multipass == ix_multipass .and. &
            used_line(j)%multipass_line == used_line(i)%multipass_line) then
          n_multi = n_multi + 1
          ixm(n_multi) = j
          used_line(j)%ix_multipass = 0  ! mark as taken care of
        endif
      enddo
      call add_this_multipass (lat, ixm(1:n_multi))
    endif
  enddo

!-------------------------------------------------------------------------
! energy bookkeeping.

  energy_beam  = 1d9 * beam_ele%value(energy_gev$)  
  energy_param = param_ele%value(E_TOT$)
  energy_0     = lat%ele(0)%value(E_TOT$) 

  if (energy_beam == 0 .and. energy_param == 0 .and. energy_0 == 0) then
    call out_io (s_warn$, r_name, 'E_TOT IS 0!')
  elseif (energy_beam /= 0 .and. energy_param == 0 .and. energy_0 == 0) then
    lat%ele(0)%value(E_TOT$) = energy_beam
  elseif (energy_beam == 0 .and. energy_param /= 0 .and. energy_0 == 0) then
    lat%ele(0)%value(E_TOT$) = energy_param
  elseif (energy_beam == 0 .and. energy_param == 0 .and. energy_0 /= 0) then
    lat%ele(0)%value(E_TOT$) = energy_0
  else
    call warning ('BEAM ENERGY SET MULTIPLE TIMES ')
  endif

  call convert_total_energy_to (lat%E_TOT, lat%param%particle, &
                                             pc = lat%ele(0)%value(p0c$))

  call set_ptc (lat%E_TOT, lat%param%particle)

! Go through the IN_LAT elements and put in the superpositions, groups, etc.
! First put in the superpositions and remove the null_ele elements

  call s_calc (lat)              ! calc longitudinal distances
  do i = 1, n_max
    if (in_lat%ele(i)%control_type /= super_lord$) cycle
    call add_all_superimpose (lat, in_lat%ele(i), plat%ele(i))
  enddo

  call remove_all_null_ele_elements (lat)

! Now put in the overlay_lord, i_beam, and group elements

  call parser_add_lord (in_lat, n_max, plat, lat)

! global computations
! Reuse the old taylor series if they exist
! and the old taylor series has the same attributes.

  call lattice_bookkeeper (lat)
  lat%input_taylor_order = bmad_com%taylor_order

  call reuse_taylor_elements (lat, old_ele)

! make matrices for entire lat

  doit = .true.
  if (present(make_mats6)) doit = make_mats6
  if (doit) then
    call lat_make_mat6(lat)      ! make 6x6 transport matrices
  endif

! store the random number seed used for this lattice

  call ran_seed_get (lat%param%ran_seed)

  if (detected_expand_lattice_cmd) then
    exit_on_error = bmad_status%exit_on_error
    bmad_status%exit_on_error = .false.
    bp_com%bmad_parser_calling = .true.
    bp_com%old_lat => in_lat
    call bmad_parser2 ('FROM: BMAD_PARSER', lat)
    bp_com%bmad_parser_calling = .false.
    bmad_status%exit_on_error = exit_on_error
  endif

!-------------------------------------------------------------------------
! write out if debug is on

  if (bp_com%parser_debug) then
    
    if (index(bp_com%debug_line, 'VAR') /= 0) then
      print *
      print *, '----------------------------------------'
      print *, 'Number of Defined Variables:', &
                                      bp_com%ivar_tot - bp_com%ivar_init
      do i = bp_com%ivar_init+1, bp_com%ivar_tot
        print *
        print *, 'Var #', i
        print *, 'Name: ', bp_com%var_name(i)
        print *, 'Value:', bp_com%var_value(i)
      enddo
    endif

    if (index(bp_com%debug_line, 'SEQ') /= 0) then
      print *
      print *, '----------------------------------------'
      print *, 'Number of Lines/Lists defined:', iseq_tot
      do i = 1, iseq_tot
        print *
        print *, 'Sequence #', i
        print *, 'Name: ', sequence(i)%name
        print *, 'Type:', sequence(i)%type
        print *, 'Number of elements:', size(sequence(i)%ele)
        print *, 'List:'
        do j = 1, size(sequence(i)%ele(:))
          print '(4x, a, l3, 2i3)', sequence(i)%ele(j)%name, &
              sequence(i)%ele(j)%reflect, sequence(i)%ele(j)%rep_count, &
              sequence(i)%ele(j)%ix_arg
        enddo
      enddo
    endif

    if (index(bp_com%debug_line, 'SLAVE') /= 0) then
      print *
      print *, '----------------------------------------'
      print *, 'Number of Elements in Tracking Lattice:', lat%n_ele_track
      do i = 1, lat%n_ele_track
        print *, '-------------'
        print *, 'Ele #', i
        call type_ele (lat%ele(i), .false., 0, .false., 0, .true., lat)
      enddo
    endif

    if (index(bp_com%debug_line, 'LORD') /= 0) then
      print *
      print *, '----------------------------------------'
      print *, 'LORD elements: ', lat%n_ele_max - lat%n_ele_track
      do i = lat%n_ele_track+1, lat%n_ele_max
        print *, '-------------'
        print *, 'Ele #', i
        call type_ele (lat%ele(i), .false., 0, .false., 0, .true., lat)
      enddo
    endif

    if (index(bp_com%debug_line, 'LATTICE') /= 0) then  
      print *
      print *, '----------------------------------------'
      print *, 'Lattice Used: ', lat%name
      print *, 'Number of lattice elements:', lat%n_ele_track
      print *, 'List:                                 Key                 Length         S'
      do i = 1, lat%n_ele_track
        print '(i4, 2a, 3x, a, 2f10.2)', i, ') ', lat%ele(i)%name(1:30),  &
          key_name(lat%ele(i)%key), lat%ele(i)%value(l$), lat%ele(i)%s
      enddo
      print *, '---- Lord Elements ----'
      do i = lat%n_ele_track+1, lat%n_ele_max
        print '(2x, i4, 2a, 3x, a, 2f10.2)', i, ') ', lat%ele(i)%name(1:30),  &
          key_name(lat%ele(i)%key), lat%ele(i)%value(l$), lat%ele(i)%s
      enddo
    endif

    ix = index(bp_com%debug_line, 'ELE')
    if (ix /= 0) then
      print *
      print *, '----------------------------------------'
      call string_trim (bp_com%debug_line(ix+3:), bp_com%debug_line, ix)
      do
        if (ix == 0) exit
        read (bp_com%debug_line, *) i
        print *
        print *, '----------------------------------------'
        print *, 'Element #', i
        call type_ele (lat%ele(i), .false., 0, .true., 0, .true., lat)
        call string_trim (bp_com%debug_line(ix+1:), bp_com%debug_line, ix)
      enddo
    endif

    if (index(bp_com%debug_line, 'BEAM_START') /= 0) then
      print *
      print *, '----------------------------------------'
      print *, 'beam_start:'
      print '(3x, 6es13.4)', lat%beam_start%vec      
    endif

  endif

!-----------------------------------------------------------------------------
! deallocate pointers

  do i = lbound(plat%ele, 1) , ubound(plat%ele, 1)
    if (associated (plat%ele(i)%name)) then
      deallocate(plat%ele(i)%name)
      deallocate(plat%ele(i)%attrib_name)
      deallocate(plat%ele(i)%coef)
    endif
  enddo

  do i = 1, size(sequence(:))
    if (associated (sequence(i)%dummy_arg)) &
              deallocate(sequence(i)%dummy_arg, sequence(i)%corresponding_actual_arg)
    if (associated (sequence(i)%ele)) then
      do j = 1, size(sequence(i)%ele)
        if (associated (sequence(i)%ele(j)%actual_arg)) &
                              deallocate(sequence(i)%ele(j)%actual_arg)
      enddo
      deallocate(sequence(i)%ele)
    endif
  enddo

  if (associated (in_lat%ele))     call deallocate_lat_pointers (in_lat)
  if (associated (plat%ele))        deallocate (plat%ele)
  if (allocated (ix_lat))           deallocate (ix_lat)
  if (allocated (seq_indexx))        deallocate (seq_indexx, seq_name)
  if (allocated (in_indexx))         deallocate (in_indexx, in_name)
  if (allocated (used_line))         deallocate (used_line)
  if (associated (in_lat%control)) deallocate (in_lat%control)
  if (associated (in_lat%ic))      deallocate (in_lat%ic)

! error check

  if (bp_com%error_flag) then
    if (bmad_status%exit_on_error) then
       call out_io (s_fatal$, r_name, 'BMAD_PARSER FINISHED. EXITING ON ERRORS')
      stop
    else
      bmad_status%ok = .false.
      return
    endif
  endif
              
  call check_lat_controls (lat, .true.)

! write to digested file

  if (write_digested .and. .not. bp_com%parser_debug .and. &
      digested_version <= bmad_inc_version$) call write_digested_bmad_file  &
             (digested_file, lat, bp_com%num_lat_files, bp_com%lat_file_names)

end subroutine
