#.rst:
# FindDFTD4
# -----------
#
# This module tries to find the DFTD4 library (https://github.com/dftd4/dftd4).
#
# The library ships its own CMake package config, which is preferred because it
# knows the compiler specific Fortran module directory
# (include/dftd4/<CompilerId>-<Version>) and pulls in the mctc-lib / multicharge
# dependencies. If no config package is found we fall back to a plain library +
# module directory search based on DFTD4_ROOT.
#
# The following variables are set
#
# ::
#
#   DFTD4_FOUND           - True if dftd4 is found
#   DFTD4_LIBRARIES       - The required libraries
#   DFTD4_INCLUDE_DIRS    - The required include / Fortran module directories
#   DFTD4_API_V3          - True if the installed dftd4 provides the old v3 API
#                           (no D4S model). This is the only API this VASP
#                           version can be compiled against: dftd4 >= 4.0
#                           changed the model constructors, and the adaptation
#                           only exists from VASP.6.6.0 on. A v4 installation is
#                           therefore rejected below rather than silently
#                           miscompiled.
#
# The following import target is created
#
# ::
#
#   DFTD4::dftd4

# set paths to look for library from ROOT variables. If new policy is set, find_library() automatically uses them.
set(_DFTD4_PATHS ${DFTD4_ROOT} $ENV{DFTD4_ROOT} ${dftd4_ROOT} $ENV{dftd4_ROOT})

set(DFTD4_LIBRARIES)
set(DFTD4_INCLUDE_DIRS)
set(_DFTD4_LINK_TARGET)

# ---------------------------------------------------------------------------
# 1) preferred: the CMake package config shipped with dftd4 (>= 3.5)
#    CONFIG mode only, so this never recurses back into this find module
# ---------------------------------------------------------------------------
if(NOT TARGET dftd4::dftd4)
  find_package(dftd4 CONFIG QUIET)
endif()

if(TARGET dftd4::dftd4)
  set(_DFTD4_LINK_TARGET dftd4::dftd4)
  if(dftd4_INCLUDE_DIRS)
    set(DFTD4_INCLUDE_DIRS ${dftd4_INCLUDE_DIRS})
  else()
    # older configs only carry the dirs on the library target
    if(TARGET dftd4::dftd4-lib)
      get_target_property(_d4_incs dftd4::dftd4-lib INTERFACE_INCLUDE_DIRECTORIES)
    else()
      get_target_property(_d4_incs dftd4::dftd4 INTERFACE_INCLUDE_DIRECTORIES)
    endif()
    if(_d4_incs)
      set(DFTD4_INCLUDE_DIRS ${_d4_incs})
    endif()
  endif()
  # the actual library file, for reporting and for the RPATH of the binaries
  if(TARGET dftd4::dftd4-lib)
    foreach(_p IMPORTED_LOCATION IMPORTED_LOCATION_RELEASE
               IMPORTED_LOCATION_RELWITHDEBINFO IMPORTED_LOCATION_NOCONFIG)
      get_target_property(_d4_loc dftd4::dftd4-lib ${_p})
      if(_d4_loc AND NOT DFTD4_LIBRARIES)
        set(DFTD4_LIBRARIES "${_d4_loc}")
      endif()
    endforeach()
  endif()
  if(NOT DFTD4_LIBRARIES)
    set(DFTD4_LIBRARIES dftd4::dftd4)
  endif()
else()
  # -------------------------------------------------------------------------
  # 2) fallback: search library and Fortran module directory by hand
  # -------------------------------------------------------------------------
  find_library(
      DFTD4_LIBRARY
      NAMES dftd4
      HINTS ${_DFTD4_PATHS}
      PATH_SUFFIXES "lib" "lib64" "dftd4/lib" "dftd4/lib64"
  )

  # the Fortran modules usually live in a compiler specific subdirectory,
  # e.g. include/dftd4/IntelLLVM-2026.0.0 - collect candidates by globbing
  set(_DFTD4_MODULE_HINTS)
  foreach(_prefix IN LISTS _DFTD4_PATHS)
    file(GLOB _d4_mod_files
      "${_prefix}/include/dftd4.mod"
      "${_prefix}/include/*/dftd4.mod"
      "${_prefix}/include/dftd4/*/dftd4.mod"
      "${_prefix}/lib/*/dftd4.mod"
      "${_prefix}/lib64/*/dftd4.mod"
      "${_prefix}/modules/dftd4.mod"
    )
    foreach(_d4_mod_file IN LISTS _d4_mod_files)
      get_filename_component(_d4_mod_dir "${_d4_mod_file}" DIRECTORY)
      list(APPEND _DFTD4_MODULE_HINTS "${_d4_mod_dir}")
    endforeach()
  endforeach()

  find_path(
      DFTD4_MODULE_DIR
      NAMES dftd4.mod
      HINTS ${_DFTD4_MODULE_HINTS} ${_DFTD4_PATHS}
      PATH_SUFFIXES "include" "include/dftd4" "modules" "inc"
  )

  # dftd4 exposes error_type from mctc-lib, so VASP needs its modules as well
  set(_MCTC_MODULE_HINTS)
  foreach(_prefix IN ITEMS ${_DFTD4_PATHS} $ENV{MCTC_LIB_ROOT} ${MCTC_LIB_ROOT})
    file(GLOB _mctc_mod_files
      "${_prefix}/include/mctc_env.mod"
      "${_prefix}/include/*/mctc_env.mod"
      "${_prefix}/include/mctc-lib/*/mctc_env.mod"
    )
    foreach(_mctc_mod_file IN LISTS _mctc_mod_files)
      get_filename_component(_mctc_mod_dir "${_mctc_mod_file}" DIRECTORY)
      list(APPEND _MCTC_MODULE_HINTS "${_mctc_mod_dir}")
    endforeach()
  endforeach()
  find_path(
      MCTC_LIB_MODULE_DIR
      NAMES mctc_env.mod
      HINTS ${_MCTC_MODULE_HINTS}
      PATH_SUFFIXES "include" "modules"
  )

  # only needed for a static dftd4, harmless otherwise
  find_library(MULTICHARGE_LIBRARY NAMES multicharge HINTS ${_DFTD4_PATHS} PATH_SUFFIXES "lib" "lib64")
  find_library(MCTC_LIB_LIBRARY NAMES mctc-lib HINTS ${_DFTD4_PATHS} PATH_SUFFIXES "lib" "lib64")

  set(DFTD4_LIBRARIES ${DFTD4_LIBRARY})
  if(MULTICHARGE_LIBRARY)
    list(APPEND DFTD4_LIBRARIES ${MULTICHARGE_LIBRARY})
  endif()
  if(MCTC_LIB_LIBRARY)
    list(APPEND DFTD4_LIBRARIES ${MCTC_LIB_LIBRARY})
  endif()

  set(DFTD4_INCLUDE_DIRS ${DFTD4_MODULE_DIR})
  if(MCTC_LIB_MODULE_DIR)
    list(APPEND DFTD4_INCLUDE_DIRS ${MCTC_LIB_MODULE_DIR})
  endif()

  mark_as_advanced(DFTD4_LIBRARY DFTD4_MODULE_DIR MCTC_LIB_MODULE_DIR
                   MULTICHARGE_LIBRARY MCTC_LIB_LIBRARY)
endif()

# check if found
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(DFTD4
                                  REQUIRED_VARS DFTD4_INCLUDE_DIRS DFTD4_LIBRARIES
                                  FAIL_MESSAGE "Could not find DFTD4 library, please specify DFTD4_ROOT or set as environment variable")

# ---------------------------------------------------------------------------
# API check: dftd4 4.x added the D4S model (dftd4_model_d4s.mod) and takes an
# allocatable error argument in its model constructors. src/subdftd4.F of this
# VASP version implements the pre-4.0 API only, so a 4.x installation cannot be
# used here - refuse it with a clear message instead of letting the compiler
# report four argument mismatches that look like a source bug.
# ---------------------------------------------------------------------------
if(DFTD4_FOUND)
  set(DFTD4_API_V3 TRUE)
  foreach(_d4_inc IN LISTS DFTD4_INCLUDE_DIRS)
    if(EXISTS "${_d4_inc}/dftd4_model_d4s.mod")
      set(DFTD4_API_V3 FALSE)
    endif()
  endforeach()
  # trust an explicit version if the config package provided one
  if(dftd4_VERSION)
    if(dftd4_VERSION VERSION_LESS 4)
      set(DFTD4_API_V3 TRUE)
    else()
      set(DFTD4_API_V3 FALSE)
    endif()
  endif()

  if(NOT DFTD4_API_V3)
    message(FATAL_ERROR "Found dftd4 ${dftd4_VERSION} at ${DFTD4_LIBRARIES}, which provides the "
                        "API introduced with dftd4 4.0. This VASP version implements the older API "
                        "only (see src/subdftd4.F); the adaptation to the new one is part of "
                        "VASP.6.6.0. Please use dftd4 3.7.0 or older here, or build DFTD4 support "
                        "with VASP.6.6.0 or newer.")
  endif()
endif()

# add target to link against
if(DFTD4_FOUND)
  if(NOT DFTD4_MESSAGE_SHOWN)
    message(STATUS "Found DFTD4 library: ${DFTD4_LIBRARIES}")
    message(STATUS "DFTD4 module directories: ${DFTD4_INCLUDE_DIRS}")
    message(STATUS "DFTD4 provides the pre-4.0 API - compiling with -DDFTD4")
  endif()
  set(DFTD4_MESSAGE_SHOWN TRUE CACHE INTERNAL "Message shown flag")
  if(NOT TARGET DFTD4::dftd4)
      add_library(DFTD4::dftd4 INTERFACE IMPORTED)
  endif()
  if(_DFTD4_LINK_TARGET)
    # link through the config target, it carries the transitive dependencies
    set_property(TARGET DFTD4::dftd4 PROPERTY INTERFACE_LINK_LIBRARIES ${_DFTD4_LINK_TARGET})
  else()
    set_property(TARGET DFTD4::dftd4 PROPERTY INTERFACE_LINK_LIBRARIES ${DFTD4_LIBRARIES})
  endif()
  set_property(TARGET DFTD4::dftd4 PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${DFTD4_INCLUDE_DIRS})
endif()

# prevent clutter in cache
MARK_AS_ADVANCED(DFTD4_FOUND DFTD4_LIBRARIES DFTD4_INCLUDE_DIRS DFTD4_API_V3)
