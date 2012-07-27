set (EXENAME tune_plane_res_plot)
set (SRC_FILES
  tune_plane_res_plot/tune_plane_res_plot.f90
  tune_plane_res_plot/tune_plane_res_mod.f90
)

set (INC_DIRS
  include
)

set (LINK_LIBS
  bsim
  bmadz
  cesr_utils
  bmad
  sim_utils
  recipes_f-90_LEPP
  forest
  pgplot
  xsif
)