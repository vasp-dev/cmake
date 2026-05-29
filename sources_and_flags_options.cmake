set(_VASP_OFLAG_DEFAULT -O2)
set(_VASP_OFLAG_DEB -g)
set(_VASP_OFLAG_O1 -O1)
set(_VASP_OFLAG_O2 -O2)
set(_VASP_OFLAG_O3 -O3)
set(_VASP_OFLAG_MAIN -O0)
set(_VASP_OFLAG_C_LIB -O)
set(_VASP_SOURCES_DEB)
set(_VASP_SOURCES_O1)
set(_VASP_SOURCES_O2)
set(_VASP_SOURCES_O3)
set(_VASP_SOURCES_IN)

# get target cpu optimization flag from terminal if not set already
if(NOT VASP_TARGET_CPU)
  if(DEFINED ENV{VASP_TARGET_CPU})
    set(VASP_TARGET_CPU $ENV{VASP_TARGET_CPU})
  endif()
endif()

# Strip flag prefix if user already included it in VASP_TARGET_CPU
# e.g., if user sets VASP_TARGET_CPU="-march=haswell", extract just "haswell"
if(VASP_TARGET_CPU)
  string(REGEX REPLACE "^-march=" "" VASP_TARGET_CPU "${VASP_TARGET_CPU}")
  string(REGEX REPLACE "^-tp=" "" VASP_TARGET_CPU "${VASP_TARGET_CPU}")
  string(REGEX REPLACE "^-mcpu=" "" VASP_TARGET_CPU "${VASP_TARGET_CPU}")
  string(REGEX REPLACE "^-h cpu=" "" VASP_TARGET_CPU "${VASP_TARGET_CPU}")
  # Strip leading and trailing whitespace
  string(STRIP "${VASP_TARGET_CPU}" VASP_TARGET_CPU)
  message(STATUS "Target CPU architecture: ${VASP_TARGET_CPU}")
endif()

# read here all required source files from the .objects file
file(READ "${PROJECT_SOURCE_DIR}/src/.objects" VASP_OBJECTS_CONTENT)

# convert a string containing object file names to a list of fortran files with ".F" suffix
function(objects_to_fortran_files objects_string out_var_name)
  string(REGEX MATCHALL "[a-zA-Z_0-9-]+\.o" objects ${objects_string})
  set(_files)
  foreach(obj IN LISTS objects)
    string(REGEX REPLACE "\\.[^.]*$" "" file_name ${obj})
    list(APPEND _files ${file_name}.F)
  endforeach()
  set(${out_var_name}  ${_files} PARENT_SCOPE)
endfunction()

string(REGEX MATCH ".*SOURCE_O1" _VASP_OBJECTS ${VASP_OBJECTS_CONTENT})
string(REGEX MATCH "SOURCE_O1.*SOURCE_O2" _VASP_OBJECTS_O1 ${VASP_OBJECTS_CONTENT})
string(REGEX MATCH "SOURCE_O2.*SOURCE_IN" _VASP_OBJECTS_O2 ${VASP_OBJECTS_CONTENT})
string(REGEX MATCH "SOURCE_IN.*" _VASP_OBJECTS_IN ${VASP_OBJECTS_CONTENT})
objects_to_fortran_files(${_VASP_OBJECTS} _VASP_SOURCES_DEFAULT)
objects_to_fortran_files(${_VASP_OBJECTS_O1} _VASP_SOURCES_O1)
objects_to_fortran_files(${_VASP_OBJECTS_O2} _VASP_SOURCES_O2)
objects_to_fortran_files(${_VASP_OBJECTS_IN} _VASP_SOURCES_IN)

set(_VASP_SOURCES "")


#################################
# Compiler specific modifications
#################################

# IMPORTANT: if the compiler is not identified, the precompiler falls back to gcc

# Languages must be enabled to check compiler id
enable_language(C CXX Fortran)

# now we specify compiler specific options and importantly
# specify how the preprocessor should be called
separate_arguments(FORTRAN_FLAGS_LIST NATIVE_COMMAND "${CMAKE_Fortran_FLAGS}")
# note: free and fixed format flags are set through target properties
if(CMAKE_Fortran_COMPILER_ID STREQUAL "GNU")
  set(FPP_COMMAND ${CMAKE_Fortran_COMPILER} -E -C -w)
  list(APPEND VASP_FORTRAN_FLAGS -ffree-line-length-none -w -ffpe-summary=none -fallow-argument-mismatch)
  # GCC >= 14.2 dropped legacy C/Fortran formatted string support; -std=legacy restores it
  if(CMAKE_Fortran_COMPILER_VERSION VERSION_GREATER_EQUAL "14.2")
    list(APPEND VASP_FORTRAN_FLAGS -std=legacy)
  endif()
  if(VASP_TARGET_CPU)
    list(APPEND VASP_FORTRAN_FLAGS -march=${VASP_TARGET_CPU})
  else()
    list(APPEND VASP_FORTRAN_FLAGS -march=native)
  endif()
  set(_VASP_OFLAG_DEFAULT -O2)
  set(_VASP_OFLAG_DEB -g -Wall -Wextra -Wconversion -fbacktrace -ffree-line-length-0 -ffpe-trap=invalid,zero,overflow,underflow)
elseif(CMAKE_Fortran_COMPILER_ID MATCHES "Intel" OR CMAKE_Fortran_COMPILER_ID MATCHES "IntelLLVM")
  set(FPP_COMMAND fpp -f_com=no -free -w0)
  list(APPEND VASP_FORTRAN_FLAGS -w0 -names lowercase -assume byterecl -w)
  if(VASP_TARGET_CPU)
    list(APPEND VASP_FORTRAN_FLAGS -march=${VASP_TARGET_CPU})
  else()
    list(APPEND VASP_FORTRAN_FLAGS -march=native)
  endif()
  set(_VASP_OFLAG_DEFAULT -O2)
  set(_VASP_OFLAG_DEB -g -check all -fpe0 -warn -traceback -debug extended)
elseif(CMAKE_Fortran_COMPILER_ID STREQUAL "NVHPC")
  # in case one needs to set --gcc-toolchain this has to be also to be appended to the pp command!
  set(FPP_COMMAND ${CMAKE_Fortran_COMPILER} ${FORTRAN_FLAGS_LIST} -Mpreprocess -Mfree -Mextend -E)
  list(APPEND VASP_FORTRAN_FLAGS -Mbackslash -Mlarge_arrays)
  if(VASP_TARGET_CPU)
    list(APPEND VASP_FORTRAN_FLAGS -tp=${VASP_TARGET_CPU})
  else()
    list(APPEND VASP_FORTRAN_FLAGS -tp=host)
  endif()
  if(CMAKE_Fortran_COMPILER_VERSION VERSION_GREATER "25.1")
    message(STATUS "adding -gpu=tripcount:host workaround for NVHPC compiler version > 25.1")
    list(APPEND VASP_FORTRAN_FLAGS -gpu=tripcount:host)
  endif()
  list(APPEND VASP_FORTRAN_LINKER_FLAGS -c++libs)
  set(_VASP_OFLAG_DEFAULT -fast)
  set(_VASP_OFLAG_MAIN -O0 -traceback)
  set(_VASP_SOURCES_O1 pade_fit.F minimax_dependence.F wave_window.F)
  set(_VASP_SOURCES_O2 pead.F)
  set(_VASP_OFLAG_DEB -Minfo=all -g -traceback)
elseif(CMAKE_Fortran_COMPILER_ID STREQUAL "Flang")
  set(FPP_COMMAND ${CMAKE_Fortran_COMPILER} -E -ffree-form -C -w)
  set(_VASP_OFLAG_DEFAULT -O2)
  list(APPEND VASP_FORTRAN_FLAGS -ffree-form -ffree-line-length-none -w -fno-fortran-main -Mbackslash)
  if(VASP_TARGET_CPU)
    list(APPEND VASP_FORTRAN_FLAGS -march=${VASP_TARGET_CPU})
  else()
    list(APPEND VASP_FORTRAN_FLAGS -march=native)
  endif()
  set(_VASP_OFLAG_DEB -g)
elseif(CMAKE_Fortran_COMPILER_ID STREQUAL "Cray")
  set(FPP_COMMAND cpp --traditional -E -P -Wno-endif-labels)
  set(_VASP_OFLAG_DEFAULT -O1)
  list(APPEND VASP_FORTRAN_FLAGS -m 4 -dC -rmo -emEb)
  if(VASP_TARGET_CPU)
    list(APPEND VASP_FORTRAN_FLAGS -h cpu=${VASP_TARGET_CPU})
  endif()
  list(APPEND _VASP_SOURCES_O1 reader.F incar_reader.F reader_base.F)
elseif(CMAKE_Fortran_COMPILER_ID STREQUAL "Fujitsu")
  set(FPP_COMMAND ${CMAKE_Fortran_COMPILER} -Ccpp -E)
  set(_VASP_OFLAG_DEFAULT --Kfast)
  list(APPEND VASP_FORTRAN_FLAGS -Ksimd_nouse_multiple_structures -X03)
  if(VASP_TARGET_CPU)
    list(APPEND VASP_FORTRAN_FLAGS -mcpu=${VASP_TARGET_CPU})
  endif()
  list(APPEND VASP_FORTRAN_LINKER_FLAGS -Kfz,simd_nouse_multiple_structures)
  set(_VASP_SOURCES_O1 elphon_common.F minimax_dependence.F)
  set(_VASP_SOURCES_O2 nonl.F vdw_nl.F)
elseif(CMAKE_Fortran_COMPILER_ID STREQUAL "NFORT")
  set(FPP_COMMAND gcc -E -C -w)
  list(APPEND VASP_FORTRAN_FLAGS -no-ftrace -finline-functions -finline-file=random.f90 -fdiag-parallel=0 -fdiag-vector=0 -fdiag-inline=0 -w)
  if(VASP_TARGET_CPU)
    list(APPEND VASP_FORTRAN_FLAGS -march=${VASP_TARGET_CPU})
  endif()
  list(APPEND VASP_FORTRAN_LINKER_FLAGS -cxxlib)
  set(_VASP_OFLAG_DEFAULT -O3)
  endif()

  # Apply user override if VASP_OFLAG is set
  if(VASP_OFLAG)
    message(STATUS "Using user-specified optimization flag: ${VASP_OFLAG}")
    set(_VASP_OFLAG_DEFAULT ${VASP_OFLAG})
  endif()

  if(NOT _VASP_OFLAG_IN)
    set(_VASP_OFLAG_IN ${_VASP_OFLAG_DEFAULT})
  endif()
  if(NOT _VASP_OFLAG_LIB)
    set(_VASP_OFLAG_LIB ${_VASP_OFLAG_O1})
  endif()


  #########################
  # Set user facing options
  #########################

  # Set lib and linpack specific flags (including target CPU flags)
  set(VASP_LIB_FORTRAN_FLAGS "${VASP_FORTRAN_FLAGS}" CACHE STRING "Fortran flags for lib")
  set(VASP_LINPACK_FORTRAN_FLAGS "${VASP_FORTRAN_FLAGS}" CACHE STRING "Fortran flags for linpack")

  # set default optimization flags.
  # NOTE: these are DERIVED from _VASP_OFLAG_DEFAULT (itself derived from the
  # VASP_OFLAG override) and must be recomputed on every (re)configure.
  # Without FORCE, a non-FORCE cache write is a no-op when the entry already
  # exists, so changing -DVASP_OFLAG=... on a re-configure was silently ignored
  # (stale -fast persisted). FORCE makes the override actually take effect.
  set(VASP_OFLAG_DEFAULT "${_VASP_OFLAG_DEFAULT}" CACHE STRING "Default optimization flag" FORCE)
  set(VASP_OFLAG_DEB "${_VASP_OFLAG_DEB}" CACHE STRING "" FORCE)
  set(VASP_OFLAG_O1 "${_VASP_OFLAG_O1}" CACHE STRING "" FORCE)
  set(VASP_OFLAG_O2 "${_VASP_OFLAG_O2}" CACHE STRING "" FORCE)
  set(VASP_OFLAG_O3 "${_VASP_OFLAG_O3}" CACHE STRING "" FORCE)
  set(VASP_OFLAG_LIB "${_VASP_OFLAG_LIB}" CACHE STRING "" FORCE)
  set(VASP_OFLAG_C_LIB "${_VASP_OFLAG_C_LIB}" CACHE STRING "" FORCE)
  set(VASP_OFLAG_IN "${_VASP_OFLAG_IN}" CACHE STRING "" FORCE)
  set(VASP_OFLAG_MAIN "${_VASP_OFLAG_MAIN}" CACHE STRING "" FORCE)
  set(VASP_SOURCES_DEB "${_VASP_SOURCES_DEB}" CACHE STRING "")
  set(VASP_SOURCES_O1 "${_VASP_SOURCES_O1}" CACHE STRING "")
  set(VASP_SOURCES_O2 "${_VASP_SOURCES_O2}" CACHE STRING "")
  set(VASP_SOURCES_O3 "${_VASP_SOURCES_O3}" CACHE STRING "")
  set(VASP_SOURCES_IN "${_VASP_SOURCES_IN}" CACHE STRING "")
  set(VASP_SOURCES "${_VASP_SOURCES}" CACHE STRING "Additional files to build")
  set(VASP_SOURCES_DEFAULT "${_VASP_SOURCES_DEFAULT}" CACHE STRING "List of default sources to build")
  mark_as_advanced(VASP_SOURCES_DEFAULT) # long list, hide by default in gui



