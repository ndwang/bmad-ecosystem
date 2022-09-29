# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 3.18

# Delete rule output on recipe failure.
.DELETE_ON_ERROR:


#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:


# Disable VCS-based implicit rules.
% : %,v


# Disable VCS-based implicit rules.
% : RCS/%


# Disable VCS-based implicit rules.
% : RCS/%,v


# Disable VCS-based implicit rules.
% : SCCS/s.%


# Disable VCS-based implicit rules.
% : s.%


.SUFFIXES: .hpux_make_needs_suffix_list


# Command-line flag to silence nested $(MAKE).
$(VERBOSE)MAKESILENT = -s

#Suppress display of executed commands.
$(VERBOSE).SILENT:

# A target that is always out of date.
cmake_force:

.PHONY : cmake_force

#=============================================================================
# Set environment variables for the build.

# The shell in which to execute make rules.
SHELL = /bin/sh

# The CMake executable.
CMAKE_COMMAND = /nfs/acc/libs/Linux_x86_64_intel/extra/cmake-3.18.4_17nov20/bin/cmake

# The command to remove a file.
RM = /nfs/acc/libs/Linux_x86_64_intel/extra/cmake-3.18.4_17nov20/bin/cmake -E rm -f

# Escaping for special characters.
EQUALS = =

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = /home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/examples

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = /home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/examples/debug

# Include any dependencies generated for this target.
include CMakeFiles/construct_taylor_map-exe.dir/depend.make

# Include the progress variables for this target.
include CMakeFiles/construct_taylor_map-exe.dir/progress.make

# Include the compile flags for this target's objects.
include CMakeFiles/construct_taylor_map-exe.dir/flags.make

CMakeFiles/construct_taylor_map-exe.dir/construct_taylor_map/construct_taylor_map.f90.o: CMakeFiles/construct_taylor_map-exe.dir/flags.make
CMakeFiles/construct_taylor_map-exe.dir/construct_taylor_map/construct_taylor_map.f90.o: ../construct_taylor_map/construct_taylor_map.f90
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/examples/debug/CMakeFiles --progress-num=$(CMAKE_PROGRESS_1) "Building Fortran object CMakeFiles/construct_taylor_map-exe.dir/construct_taylor_map/construct_taylor_map.f90.o"
	/home/dcs16/dcs16/bmad_distribution/bmad_dist/production/bin/mpifort $(Fortran_DEFINES) $(Fortran_INCLUDES) $(Fortran_FLAGS) -Df2cFortran -DCESR_UNIX -DCESR_LINUX -u -traceback -cpp -fno-range-check -fdollar-ok -fbacktrace -Bstatic -ffree-line-length-none -fopenmp -DCESR_PLPLOT -DACC_MPI -I/home/dcs16/dcs16/bmad_distribution/bmad_dist/production/include -pthread -I/home/dcs16/dcs16/bmad_distribution/bmad_dist/production/lib -fPIC -O0 -fno-range-check -fbounds-check -Wuninitialized  -c /home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/examples/construct_taylor_map/construct_taylor_map.f90 -o CMakeFiles/construct_taylor_map-exe.dir/construct_taylor_map/construct_taylor_map.f90.o

CMakeFiles/construct_taylor_map-exe.dir/construct_taylor_map/construct_taylor_map.f90.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing Fortran source to CMakeFiles/construct_taylor_map-exe.dir/construct_taylor_map/construct_taylor_map.f90.i"
	/home/dcs16/dcs16/bmad_distribution/bmad_dist/production/bin/mpifort $(Fortran_DEFINES) $(Fortran_INCLUDES) $(Fortran_FLAGS) -Df2cFortran -DCESR_UNIX -DCESR_LINUX -u -traceback -cpp -fno-range-check -fdollar-ok -fbacktrace -Bstatic -ffree-line-length-none -fopenmp -DCESR_PLPLOT -DACC_MPI -I/home/dcs16/dcs16/bmad_distribution/bmad_dist/production/include -pthread -I/home/dcs16/dcs16/bmad_distribution/bmad_dist/production/lib -fPIC -O0 -fno-range-check -fbounds-check -Wuninitialized  -E /home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/examples/construct_taylor_map/construct_taylor_map.f90 > CMakeFiles/construct_taylor_map-exe.dir/construct_taylor_map/construct_taylor_map.f90.i

CMakeFiles/construct_taylor_map-exe.dir/construct_taylor_map/construct_taylor_map.f90.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling Fortran source to assembly CMakeFiles/construct_taylor_map-exe.dir/construct_taylor_map/construct_taylor_map.f90.s"
	/home/dcs16/dcs16/bmad_distribution/bmad_dist/production/bin/mpifort $(Fortran_DEFINES) $(Fortran_INCLUDES) $(Fortran_FLAGS) -Df2cFortran -DCESR_UNIX -DCESR_LINUX -u -traceback -cpp -fno-range-check -fdollar-ok -fbacktrace -Bstatic -ffree-line-length-none -fopenmp -DCESR_PLPLOT -DACC_MPI -I/home/dcs16/dcs16/bmad_distribution/bmad_dist/production/include -pthread -I/home/dcs16/dcs16/bmad_distribution/bmad_dist/production/lib -fPIC -O0 -fno-range-check -fbounds-check -Wuninitialized  -S /home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/examples/construct_taylor_map/construct_taylor_map.f90 -o CMakeFiles/construct_taylor_map-exe.dir/construct_taylor_map/construct_taylor_map.f90.s

# Object files for target construct_taylor_map-exe
construct_taylor_map__exe_OBJECTS = \
"CMakeFiles/construct_taylor_map-exe.dir/construct_taylor_map/construct_taylor_map.f90.o"

# External object files for target construct_taylor_map-exe
construct_taylor_map__exe_EXTERNAL_OBJECTS =

/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: CMakeFiles/construct_taylor_map-exe.dir/construct_taylor_map/construct_taylor_map.f90.o
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: CMakeFiles/construct_taylor_map-exe.dir/build.make
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: ../../debug/lib/libbmad.a
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: ../../debug/lib/libsim_utils.a
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: ../../debug/lib/libxrlf03.a
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: ../../debug/lib/libxrl.a
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: ../../debug/lib/libforest.a
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: ../../debug/lib/libfgsl.a
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: ../../debug/lib/libgsl.a
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: ../../debug/lib/libgslcblas.a
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: ../../debug/lib/liblapack95.a
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: ../../debug/lib/libhdf5hl_fortran.a
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: ../../debug/lib/libhdf5_hl.a
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: ../../debug/lib/libhdf5_fortran.a
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: ../../debug/lib/libhdf5.a
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: ../../debug/lib/libfftw3.a
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: ../../debug/lib/libfftw3_omp.a
/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map: CMakeFiles/construct_taylor_map-exe.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --bold --progress-dir=/home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/examples/debug/CMakeFiles --progress-num=$(CMAKE_PROGRESS_2) "Linking Fortran executable /home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map"
	$(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/construct_taylor_map-exe.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
CMakeFiles/construct_taylor_map-exe.dir/build: /home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/debug/bin/construct_taylor_map

.PHONY : CMakeFiles/construct_taylor_map-exe.dir/build

CMakeFiles/construct_taylor_map-exe.dir/clean:
	$(CMAKE_COMMAND) -P CMakeFiles/construct_taylor_map-exe.dir/cmake_clean.cmake
.PHONY : CMakeFiles/construct_taylor_map-exe.dir/clean

CMakeFiles/construct_taylor_map-exe.dir/depend:
	cd /home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/examples/debug && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/examples /home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/examples /home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/examples/debug /home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/examples/debug /home/dcs16/dcs16/bmad_distribution/bmad_dist_gfortran_mpi_openmp_shared/examples/debug/CMakeFiles/construct_taylor_map-exe.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : CMakeFiles/construct_taylor_map-exe.dir/depend

