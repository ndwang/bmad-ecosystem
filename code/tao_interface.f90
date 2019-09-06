!+
! Module tao_interface
!
! Module to define the interfaces for the tao routines.
!-

! Note: To overcome a problem with the intel compiler the following routine interfaces
! Have been deleted:
!   tao_command
!   tao_command_end_calc
!   tao_plot_setup

module tao_interface

use tao_struct

!+
! Function tao_pointer_to_universe (...) result (u)
!
! Routine to set a pointer to a universe.
!
! This is an overloaded routine for the:
!  tao_pointer_to_universe_int (ix_uni) result (u)
!  tao_pointer_to_universe_str (string) result (u)
!
! Note: With a string argument, this routine can only handle single universe picks. 
! That is, it cannot handlle something like "[1,3,4]@...". To handle multiple universe picks, use:
!   tao_pick_universe
!
! Input:
!   ix_uni      -- Integer: Index to the s%u(:) array
!                    If ix_uni is -1 or -2 then u(s%com%default_universe) will be used.
!   string      -- character(*): String in the form "<ix_uni>@..." or, if 
!                    no "@" is present, u will point to the default universe.
!
! Output:
!   string -- character(*): String with universe prefix stripped off.
!   u      -- Tao_universe_struct, pointer: Universe pointer.
!               u will be nullified if there is an error and an error message will be printed.
!-

interface tao_pointer_to_universe
  module procedure tao_pointer_to_universe_int
  module procedure tao_pointer_to_universe_str
end interface

private tao_pointer_to_universe_int, tao_pointer_to_universe_str

interface

subroutine tao_alias_cmd (alias, string)
  implicit none
  character(*) :: alias
  character(*) :: string
end subroutine

function tao_beam_emit_calc (plane, emit_type, ele, bunch_params) result (emit)
  import
  implicit none
  integer plane, emit_type
  type (ele_struct) ele
  type (bunch_params_struct) bunch_params
  real(rp) emit
end function

function tao_beam_sigma_calc_needed (data_type, data_source) result (do_beam_sigma)
  import
  implicit none
  character(*) data_type, data_source
  logical do_beam_sigma
end function
 
function tao_bmad_parameter_value (dat_name, ele, orbit, err_flag) result (value)
  import
  implicit none
  type (ele_struct) ele
  type (coord_struct) orbit
  real(rp) value
  character(*) dat_name
  logical err_flag
end function

subroutine tao_call_cmd (file_name, cmd_arg)
  implicit none
  character(*) :: file_name
  character(*), optional :: cmd_arg(:)
end subroutine

function tao_chrom_calc_needed (data_type, data_source) result (do_chrom)
  import
  implicit none
  character(*) data_type, data_source
  logical do_chrom
end function
 
subroutine tao_clip_cmd (gang, where, value1, value2)
  import
  implicit none
  logical gang
  character(*) :: where
  real(rp) value1, value2
end subroutine

subroutine tao_control_tree_list (ele, tree)
  import
  implicit none
  type (ele_struct) ele
  type (ele_pointer_struct), allocatable :: tree(:)
end subroutine

function tao_constraint_type_name(datum) result (datum_name)
  import
  implicit none
  type (tao_data_struct) datum
  character(200) datum_name
end function

subroutine tao_count_strings (string, pattern, num)
  import
  implicit none
  character(*) string, pattern
  integer num
end subroutine

function tao_curve_component (curve, graph) result (component)
  import
  implicit none
  type (tao_curve_struct) curve
  type (tao_graph_struct) graph
  character(60) component
end function

function tao_curve_ix_uni (curve) result (ix_uni)
  import
  implicit none
  type (tao_curve_struct) curve
  integer ix_uni
end function

function tao_curve_name(curve, use_region) result (curve_name)
  import
  implicit none
  type (tao_curve_struct) curve
  character(60) curve_name
  logical, optional :: use_region
end function

function tao_d2_d1_name(d1, show_universe) result (d2_d1_name)
  import
  implicit none
  type (tao_d1_data_struct) d1
  character(60) d2_d1_name
  logical, optional :: show_universe
end function

subroutine tao_data_check (err)
  import
  implicit none
  logical err
end subroutine

function tao_data_sanity_check (datum, print_err) result (is_valid)
  import
  type (tao_data_struct) datum
  logical print_err, is_valid
end function

subroutine tao_data_show_use (d2_data, lines, nl)
  import
  implicit none
  type (tao_d2_data_struct) :: d2_data
  character(*), optional, allocatable :: lines(:)
  integer, optional :: nl
end subroutine

function tao_datum_has_associated_ele (data_type, branch_geometry) result (has_associated_ele)
  implicit none
  character(*) data_type
  integer has_associated_ele
  integer, optional :: branch_geometry
end function

function tao_datum_name(datum, show_universe) result (datum_name)
  import
  implicit none
  type (tao_data_struct) datum
  character(60) datum_name
  logical, optional :: show_universe
end function

subroutine tao_de_optimizer (abort)
  implicit none
  logical abort
end subroutine

subroutine tao_ele_shape_info (ix_uni, ele, ele_shapes, e_shape, label_name, y1, y2, ix_shape_min)
  import
  implicit none
  type (ele_struct) ele
  type (tao_ele_shape_struct) ele_shapes(:)
  type (tao_ele_shape_struct), pointer :: e_shape
  real(rp) y1, y2
  integer ix_uni
  integer, optional :: ix_shape_min
  character(*) label_name
end subroutine

subroutine tao_ele_to_ele_track (ix_universe, ix_branch, ix_ele, ix_ele_track)
  import
  implicit none
  integer ix_universe, ix_branch, ix_ele, ix_ele_track
end subroutine

subroutine tao_evaluate_element_parameters (err, param_name, values, print_err, dflt_source, dflt_component, dflt_uni)
  import
  implicit none
  character(*) param_name
  character(*) dflt_source
  character(*), optional :: dflt_component
  real(rp), allocatable :: values(:)
  integer, optional :: dflt_uni
  logical err
  logical :: print_err
end subroutine


subroutine tao_find_data (err, data_name, d2_array, d1_array, d_array, re_array, &
                           log_array, str_array, int_array, ix_uni, dflt_index, print_err, component)
  import
  implicit none
  type (tao_d2_data_array_struct), allocatable, optional :: d2_array(:)
  type (tao_d1_data_array_struct), allocatable, optional :: d1_array(:)
  type (tao_data_array_struct), allocatable, optional    :: d_array(:)
  type (tao_real_pointer_struct), allocatable, optional    :: re_array(:)
  type (tao_integer_array_struct), allocatable, optional :: int_array(:)
  type (tao_logical_array_struct), allocatable, optional :: log_array(:)
  type (tao_string_array_struct), allocatable, optional  :: str_array(:)
  character(*) :: data_name
  character(*), optional :: component
  character(*), optional :: dflt_index
  integer, optional :: ix_uni
  logical err
  logical, optional :: print_err
end subroutine


subroutine tao_find_var (err, var_name, v1_array, v_array, re_array, log_array, &
                                               str_array, print_err, component, dflt_var_index)
  import
  implicit none
  type (tao_v1_var_array_struct), allocatable, optional  :: v1_array(:)
  type (tao_var_array_struct), allocatable, optional     :: v_array(:)
  type (tao_real_pointer_struct), allocatable, optional  :: re_array(:)
  type (tao_logical_array_struct), allocatable, optional :: log_array(:)
  type (tao_string_array_struct), allocatable, optional  :: str_array(:)
  character(*) :: var_name
  character(*), optional :: component, dflt_var_index
  logical, optional :: print_err
  logical err, print_error
end subroutine

subroutine tao_find_plot_region (err, where, region, print_flag)
  import
  implicit none
  type (tao_plot_region_struct), pointer :: region
  character(*) where
  logical, optional :: print_flag
  logical err
end subroutine

subroutine tao_find_plots (err, name, where, plot, graph, curve, print_flag, blank_means_all)
  import
  implicit none
  type (tao_plot_array_struct), allocatable, optional :: plot(:)
  type (tao_graph_array_struct), allocatable, optional :: graph(:)
  type (tao_curve_array_struct), allocatable, optional :: curve(:)
  character(*) name, where
  logical, optional :: print_flag, blank_means_all
  logical err
end subroutine
 
subroutine tao_floor_to_screen (graph, r_floor, x_screen, y_screen)
  import
  implicit none
  type (tao_graph_struct) graph
  real(rp) r_floor(3), x_screen, y_screen 
end subroutine

subroutine tao_floor_to_screen_coords (graph, floor, screen)
  import
  implicit none
  type (tao_graph_struct) graph
  type (floor_position_struct) floor, screen
end subroutine

subroutine tao_has_been_created ()
end subroutine
 
subroutine tao_help (what1, what2, lines, n_lines)
  implicit none
  character(*) what1, what2
  character(*), optional, allocatable :: lines(:)
  integer, optional :: n_lines
end subroutine

subroutine tao_hook_branch_calc (u, tao_lat, branch)
  import
  implicit none
  type (tao_universe_struct), target :: u
  type (tao_lattice_struct), target :: tao_lat
  type (branch_struct), target :: branch
end subroutine
 
subroutine tao_hook_command (command_line, found)
  implicit none
  character(*) command_line
  logical found
end subroutine
 
subroutine tao_hook_draw_floor_plan (plot, graph)
  import
  implicit none
  type (tao_plot_struct) plot
  type (tao_graph_struct) graph
end subroutine
 
subroutine tao_hook_draw_graph (plot, graph, found)
  import
  implicit none
  type (tao_plot_struct) plot
  type (tao_graph_struct) graph
  logical found
end subroutine

subroutine tao_hook_evaluate_a_datum (found, datum, u, tao_lat, datum_value, valid_value, why_invalid)
  import
  implicit none
  type (tao_data_struct) datum
  type (tao_universe_struct) u
  type (tao_lattice_struct) tao_lat
  real(rp) datum_value
  logical found, valid_value
  character(*), optional :: why_invalid
end subroutine

subroutine tao_hook_graph_postsetup (plot, graph)
  import
  implicit none
  type (tao_plot_struct) plot
  type (tao_graph_struct) graph
end subroutine
 
subroutine tao_hook_graph_setup (plot, graph, found)
  import
  implicit none
  type (tao_plot_struct) plot
  type (tao_graph_struct) graph
  logical found
end subroutine
 
subroutine tao_hook_init_beam ()
  implicit none
end subroutine

subroutine tao_hook_init_data ()
  implicit none
end subroutine

subroutine tao_hook_init_global (init_file, global)
  import
  implicit none
  type (tao_global_struct) global
  character(*) init_file
end subroutine
 
subroutine tao_hook_init_lattice_post_parse (u)
  import
  implicit none
  type (tao_universe_struct) u
end subroutine

subroutine tao_hook_init_plotting ()
  import
  implicit none
end subroutine

subroutine tao_hook_init_read_lattice_info (lat_file)
  implicit none
  character(*) lat_file
end subroutine

subroutine tao_hook_init1 (init_file_name)
  implicit none
  character(*) init_file_name
end subroutine

subroutine tao_hook_init2 ()
  implicit none
end subroutine

subroutine tao_hook_init_var()
  implicit none
end subroutine

subroutine tao_hook_lattice_calc (calc_ok)
  implicit none
  logical calc_ok
end subroutine

subroutine tao_hook_merit_data (i_uni, j_data, data, valid_value_set)
  import
  implicit none
  type (tao_data_struct) data
  integer i_uni, j_data
  logical valid_value_set
end subroutine

subroutine tao_hook_merit_var (i_uni, j_var, var)
  import
  implicit none
  type (tao_var_struct) var
  integer i_uni, j_var
end subroutine

subroutine tao_hook_optimizer (abort)
  implicit none
  logical abort
end subroutine
 
subroutine tao_hook_parse_command_args()
  implicit none
end subroutine

subroutine tao_hook_plot_setup()
  import
  implicit none
end subroutine

subroutine tao_hook_post_process_data ()
  implicit none
end subroutine
 
subroutine tao_hook_show_cmd (what, result_id, lines, nl)
  implicit none
  character(*) what, result_id
  character(*), allocatable :: lines(:)
  integer nl
end subroutine

subroutine tao_init (err_flag)
  implicit none
  logical :: err_flag
end subroutine

subroutine tao_init_find_elements (u, search_string, eles, attribute, found_one)
  import
  implicit none
  type (tao_universe_struct), target :: u
  type (ele_pointer_struct), allocatable :: eles(:)
  character(*) search_string
  character(*), optional :: attribute
  logical, optional :: found_one
end subroutine

subroutine tao_init_lattice (lat_file)
  implicit none
  character(*) lat_file
end subroutine

subroutine tao_init_plotting (plot_file)
  implicit none
  character(*) plot_file
end subroutine

subroutine tao_init_single_mode (single_mode_file)
  implicit none
  character(*) single_mode_file
end subroutine

subroutine tao_json_cmd (input_str)
  import
  implicit none
  character(*) input_str
end subroutine

subroutine tao_key_info_to_str (ix_key, ix_min_key, ix_max_key, key_str, header_str)
  import
  implicit none
  integer ix_key, ix_min_key, ix_max_key
  character(*) key_str
  character(*) header_str
end subroutine

subroutine tao_lat_bookkeeper (u, tao_lat)
  import
  implicit none
  type (tao_universe_struct), target :: u
  type (tao_lattice_struct) :: tao_lat
end subroutine

function tao_lat_emit_calc (plane, emit_type, ele, modes) result (emit)
  import
  implicit none
  integer plane, emit_type
  type (ele_struct) ele
  type (normal_modes_struct) modes
  real(rp) emit
end function
 
subroutine tao_limit_calc (limited)
  implicit none
  logical limited
end subroutine

subroutine tao_lmdif_optimizer (abort)
  implicit none
  logical abort
end subroutine

subroutine tao_locate_all_elements (ele_list, eles, err, ignore_blank)
  import
  implicit none
  type (ele_pointer_struct), allocatable :: eles(:)
  character(*) ele_list
  logical err
  logical, optional :: ignore_blank
end subroutine

subroutine tao_locate_elements (ele_list, ix_universe, eles, err, lat_type, ignore_blank, &
                                       print_err, above_ubound_is_err, ix_dflt_branch, multiple_eles_is_err)
  import
  implicit none
  character(*) ele_list
  integer ix_universe
  type (ele_pointer_struct), allocatable :: eles(:)
  logical err
  integer, optional :: lat_type, ix_dflt_branch
  logical, optional :: ignore_blank, print_err, above_ubound_is_err, multiple_eles_is_err
end subroutine


subroutine tao_mark_lattice_ele (lat)
  import
  implicit none
  type (lat_struct), target :: lat
end subroutine

function tao_merit (calc_ok) result (this_merit)
  import
  implicit none
  real(rp) this_merit
  logical, optional :: calc_ok
end function

subroutine tao_open_file (file, iunit, file_name, error_severity, binary)
  implicit none
  character(*) file
  character(*) file_name
  integer iunit, error_severity
  logical, optional :: binary
end subroutine

Function tao_open_scratch_file (err) result (iu)
  implicit none
  integer iu
  logical err
end function

function tao_optimization_status (datum) result (why_str)
  import
  implicit none
  type (tao_data_struct) :: datum
  character(60) why_str
end function

subroutine tao_orbit_value (component, orbit, value, err)
  import
  implicit none
  character(*) component
  type (coord_struct) orbit
  real(rp) value
  logical err
end subroutine
 
function tao_pointer_to_datum (d1, ele_name) result (datum_ptr)
  import
  implicit none
  type (tao_d1_data_struct), target :: d1
  type (tao_data_struct), pointer :: datum_ptr
  character(*) ele_name
end function

subroutine tao_parse_command_args (error, cmd_line)
  import
  implicit none
  character(*), optional :: cmd_line
  logical error
end subroutine

subroutine tao_pause_cmd (time)
  import
  implicit none
  real(rp) time
end subroutine

subroutine tao_pick_universe (name_in, name_out, picked, err, ix_uni, explicit_uni, dflt_uni)
  import
  implicit none
  character(*) name_in, name_out
  integer, optional :: ix_uni, dflt_uni
  logical, allocatable :: picked(:)
  logical err
  logical, optional :: explicit_uni
end subroutine
 
subroutine tao_place_cmd (where, who, no_buffer)
  implicit none
  character(*) who
  character(*) where
  logical, optional :: no_buffer
end subroutine
 
subroutine tao_plot_cmd (where, component)
  implicit none
  character(*) :: where
  character(*) :: component
end subroutine
 
subroutine tao_plot_struct_transfer (plot_in, plot_out)
  import
  implicit none
  type (tao_plot_struct) plot_in
  type (tao_plot_struct) plot_out
end subroutine

function tao_pointer_to_ele_shape (ix_uni, ele, ele_shape, dat_var_name, dat_var_value, ix_shape_min) result (e_shape)
  import
  implicit none
  integer ix_uni
  type (ele_struct) ele
  type (tao_ele_shape_struct), target :: ele_shape(:)
  character(*), optional :: dat_var_name
  real(rp), optional :: dat_var_value
  integer, optional :: ix_shape_min
  type (tao_ele_shape_struct), pointer :: e_shape
end function

function tao_pointer_to_tao_lat (u, lat_type) result (tao_lat)
  import
  implicit none
  type (tao_universe_struct), target :: u
  type (tao_lattice_struct), pointer :: tao_lat
  integer, optional :: lat_type
end function

subroutine tao_print_command_line_info
  import
  implicit none
end subroutine

subroutine tao_python_cmd (input_str)
  import
  implicit none
  character(*) input_str
end subroutine

subroutine tao_re_allocate_expression_info (info, n, exact)
  import
  implicit none
  type (tao_expression_info_struct), allocatable :: info(:)
  integer, intent(in) :: n
  logical, optional :: exact
end subroutine

function tao_rad_int_calc_needed (data_type, data_source) result (do_rad_int)
  import
  implicit none
  character(*) data_type, data_source
  logical do_rad_int
end function

function tao_srdt_calc_needed (data_type, data_source) result (do_srdt)
  import
  implicit none
  character(*) data_type, data_source
  integer do_srdt
end function

subroutine tao_read_cmd (which, file)
  implicit none
  character(*) which, file
end subroutine

function tao_read_phase_space_index (name, ixc, print_err) result (ix_ps)
  import
  implicit none
  character(*) name
  integer ix_ps, ixc
  logical, optional :: print_err
end function
 
subroutine tao_run_cmd (which, abort)
  implicit none
  character(*) which
  logical abort
end subroutine

subroutine tao_scale_ping_data (u)
  import
  implicit none
  type (tao_universe_struct) u
end subroutine

subroutine tao_set_data_useit_opt (data)
  import
  implicit none
  type (tao_data_struct), optional :: data(:)
end subroutine

subroutine tao_set_flags_for_changed_attribute (u, ele_name, ele_ptr, val_ptr)
  import
  implicit none
  type (tao_universe_struct) u
  type (ele_struct), pointer, optional :: ele_ptr
  real(rp), pointer, optional :: val_ptr
  character(*) ele_name
end subroutine

subroutine tao_set_var_model_value (var, value, print_limit_warning)
  import
  implicit none
  type (tao_var_struct), target :: var
  real(rp) value
  logical, optional :: print_limit_warning
end subroutine

subroutine tao_set_var_useit_opt ()
end subroutine

subroutine tao_setup_key_table ()
  import
  implicit none
end subroutine

subroutine tao_silent_run_set (set)
  import
  implicit none
  logical set
end subroutine

subroutine tao_single_mode (char)
  implicit none
  character(1) :: char
end subroutine

subroutine tao_split_component (comp_str, comp, err)
  import
  implicit none
  character(*) comp_str
  type (tao_data_var_component_struct), allocatable :: comp(:)
  logical err
end subroutine

subroutine tao_spin_g_matrix_calc (datum, u, ix_ref, ix_ele, spin_map, valid_value, why_invalid)
  import
  implicit none
  type (tao_data_struct) datum
  type (tao_universe_struct) u
  type (tao_spin_map_struct), pointer :: spin_map
  integer ix_ref, ix_ele
  logical valid_value
character(*) why_invalid
end subroutine

subroutine tao_spin_polarization_calc (branch, orbit, spin_pol)
  import
  implicit none
  type (branch_struct), target :: branch
  type (coord_struct) :: orbit(0:)
  type (tao_spin_polarization_struct) spin_pol
end subroutine

function tao_spin_matrices_calc_needed (data_type, data_source) result (do_calc)
  import
  implicit none
  character(*) data_type, data_source
  logical do_calc
end function

subroutine tao_string_to_element_id (str, ix_class, ele_name, err, print_err)
  import
  implicit none
  character(*) str, ele_name
  integer ix_class
  logical err
  logical, optional :: print_err
end subroutine

function tao_subin_uni_number (name_in, ix_uni, name_out) result (ok)
  import
  implicit none
  character(*) name_in, name_out
  integer ix_uni
  logical ok
end function

subroutine tao_top_level (command, errcode)
  implicit none
  character(*), optional :: command
  integer, optional :: errcode
end subroutine
 
subroutine tao_turn_on_special_calcs_if_needed_for_plotting ()
  import
  implicit none
end subroutine

function tao_unique_ele_name (ele, nametable) result (unique_name)
  import
  implicit none
  type (ele_struct) ele
  type (lat_nametable_struct) nametable
  character(40) unique_name
end function

function tao_universe_number (i_uni) result (i_this_uni)
  import
  implicit none
  integer i_uni, i_this_uni
end function

subroutine tao_use_data (action, data_name)
  implicit none
  character(*) :: action
  character(*) :: data_name
end subroutine

subroutine tao_use_var (action, var_name)
  implicit none
  character(*) :: action
  character(*) :: var_name
end subroutine

function tao_var1_name(var) result (var1_name)
  import
  implicit none
  type (tao_var_struct) var
  character(60) var1_name
end function

function tao_var_attrib_name(var) result (var_attrib_name)
  import
  implicit none
  type (tao_var_struct) var
  character(60) var_attrib_name
end function
 
subroutine tao_var_repoint ()
end subroutine

subroutine tao_var_show_use (v1_var, lines, nl)
  import
  implicit none
  type (tao_v1_var_struct) :: v1_var
  character(*), optional, allocatable :: lines(:)
  integer, optional :: nl
end subroutine

subroutine tao_var_target_calc ()
  import
  implicit none
end subroutine

subroutine tao_var_useit_plot_calc (graph, var)
  import
  implicit none
  type (tao_graph_struct) graph
  type (tao_var_struct) var(:)
end subroutine

subroutine tao_write_cmd (what)
  implicit none
  character(*) :: what
end subroutine
 
subroutine tao_x_axis_cmd (where, what)
  implicit none
  character(*) where
  character(*) what
end subroutine

end interface

contains

!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
!+
! Function tao_pointer_to_universe_int (ix_uni) result (u)
!
! Overloaded by tao_pointer_to_universe. See this routine for more details.
!-

function tao_pointer_to_universe_int (ix_uni) result(u)

implicit none

type (tao_universe_struct), pointer :: u
integer ix_uni, ix_u
character(*), parameter :: r_name = 'tao_pointer_to_universe_int'

!

ix_u = tao_universe_number(ix_uni)

if (ix_u < lbound(s%u, 1) .or. ix_u > ubound(s%u, 1)) then
  call out_io (s_fatal$, r_name, 'UNIVERSE INDEX OUT OF RANGE: \I0\ ', ix_u)
  nullify (u)
  return
endif

u => s%u(ix_u)

end function tao_pointer_to_universe_int

!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
!-----------------------------------------------------------------------
!+
! Function tao_pointer_to_universe_str (string) result (u)
!
! Overloaded by tao_pointer_to_universe. See this routine for more details.
!-

function tao_pointer_to_universe_str (string) result(u)

implicit none

type (tao_universe_struct), pointer :: u
integer ix, ix_u
character(*) string
character(*), parameter :: r_name = 'tao_pointer_to_universe_str'

!

nullify(u)

ix = index(string, '@')
if (ix == 0) then
  u => s%u(tao_universe_number(-1))
  return
endif

!

if (.not. is_integer(string(1:ix-1))) then
  call out_io (s_fatal$, r_name, 'MALFORMED UNIVERSE STRING')
  return
endif
read (string(1:ix-1), *) ix_u
string = string(ix+1:)

ix_u = tao_universe_number(ix_u)

if (ix_u < lbound(s%u, 1) .or. ix_u > ubound(s%u, 1)) then
  call out_io (s_fatal$, r_name, 'UNIVERSE INDEX OUT OF RANGE: \I0\ ', ix_u)
  return
endif

u => s%u(ix_u)

end function tao_pointer_to_universe_str

end module


