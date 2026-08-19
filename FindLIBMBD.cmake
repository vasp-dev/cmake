#.rst:
# FindLIBMBD
# -----------
#
# This module tries to find the libMBD many-body dispersion library
# (https://github.com/libmbd/libmbd).
#
# The library ships its own CMake package config (package name "Mbd"), which is
# preferred because it knows the Fortran module directory. If no config package
# is found we fall back to a plain library + module directory search based on
# LIBMBD_ROOT / MBD_ROOT.
#
# No minimum version is enforced on this branch: src/libmbd.F here does not pass
# a communicator to libmbd at all, so the libmbd >= 0.14.0 requirement that
# master carries does not apply. The detected version is only reported.
#
# The following variables are set
#
# ::
#
#   LIBMBD_FOUND          - True if libmbd is found
#   LIBMBD_LIBRARIES      - The required libraries
#   LIBMBD_INCLUDE_DIRS   - The required Fortran module directory
#   LIBMBD_VERSION        - Version of the library, if it could be determined
#
# The following import target is created
#
# ::
#
#   LIBMBD::libmbd

# set paths to look for library from ROOT variables. If new policy is set, find_library() automatically uses them.
set(_LIBMBD_PATHS ${LIBMBD_ROOT} $ENV{LIBMBD_ROOT} ${MBD_ROOT} $ENV{MBD_ROOT})

set(LIBMBD_LIBRARIES)
set(LIBMBD_INCLUDE_DIRS)
set(LIBMBD_VERSION)
set(_LIBMBD_LINK_TARGET)

# ---------------------------------------------------------------------------
# 1) preferred: the CMake package config shipped with libmbd (package "Mbd")
#    CONFIG mode only, so this never recurses back into this find module.
#    No version is requested here: libmbd installs no ConfigVersion file, so
#    asking for one would fail the whole find. The version is checked below.
# ---------------------------------------------------------------------------
if(NOT TARGET Mbd::mbd)
  find_package(Mbd CONFIG QUIET)
endif()

if(TARGET Mbd::mbd)
  set(_LIBMBD_LINK_TARGET Mbd::mbd)
  get_target_property(_mbd_incs Mbd::mbd INTERFACE_INCLUDE_DIRECTORIES)
  if(_mbd_incs)
    list(REMOVE_DUPLICATES _mbd_incs)
    set(LIBMBD_INCLUDE_DIRS ${_mbd_incs})
  endif()
  foreach(_p IMPORTED_LOCATION IMPORTED_LOCATION_RELEASE
             IMPORTED_LOCATION_RELWITHDEBINFO IMPORTED_LOCATION_NOCONFIG)
    get_target_property(_mbd_loc Mbd::mbd ${_p})
    if(_mbd_loc AND NOT LIBMBD_LIBRARIES)
      set(LIBMBD_LIBRARIES "${_mbd_loc}")
    endif()
  endforeach()
  if(NOT LIBMBD_LIBRARIES)
    set(LIBMBD_LIBRARIES Mbd::mbd)
  endif()
else()
  # -------------------------------------------------------------------------
  # 2) fallback: search library and Fortran module directory by hand
  # -------------------------------------------------------------------------
  find_library(
      LIBMBD_LIBRARY
      NAMES mbd
      HINTS ${_LIBMBD_PATHS}
      PATH_SUFFIXES "lib" "lib64" "mbd/lib" "mbd/lib64"
  )
  find_path(
      LIBMBD_MODULE_DIR
      NAMES mbd.mod
      HINTS ${_LIBMBD_PATHS}
      PATH_SUFFIXES "include/mbd" "include" "modules" "mbd" "inc"
  )
  set(LIBMBD_LIBRARIES ${LIBMBD_LIBRARY})
  set(LIBMBD_INCLUDE_DIRS ${LIBMBD_MODULE_DIR})
  mark_as_advanced(LIBMBD_LIBRARY LIBMBD_MODULE_DIR)
endif()

# ---------------------------------------------------------------------------
# version: taken from the soname of the resolved library file, since libmbd
# installs no CMake ConfigVersion file
# ---------------------------------------------------------------------------
foreach(_mbd_lib IN LISTS LIBMBD_LIBRARIES)
  if(EXISTS "${_mbd_lib}" AND NOT LIBMBD_VERSION)
    get_filename_component(_mbd_real "${_mbd_lib}" REALPATH)
    if("${_mbd_real}" MATCHES "libmbd\\.(so|dylib)[.]?([0-9]+\\.[0-9]+\\.[0-9]+)")
      set(LIBMBD_VERSION "${CMAKE_MATCH_2}")
    elseif("${_mbd_lib}" MATCHES "libmbd\\.(so|dylib)[.]?([0-9]+\\.[0-9]+\\.[0-9]+)")
      set(LIBMBD_VERSION "${CMAKE_MATCH_2}")
    endif()
  endif()
endforeach()

# check if found
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LIBMBD
                                  REQUIRED_VARS LIBMBD_INCLUDE_DIRS LIBMBD_LIBRARIES
                                  VERSION_VAR LIBMBD_VERSION
                                  FAIL_MESSAGE "Could not find libMBD library, please specify LIBMBD_ROOT or set as environment variable")

# add target to link against
if(LIBMBD_FOUND)
  if(NOT LIBMBD_MESSAGE_SHOWN)
    message(STATUS "Found libMBD library: ${LIBMBD_LIBRARIES}")
    message(STATUS "libMBD module directory: ${LIBMBD_INCLUDE_DIRS}")
    if(LIBMBD_VERSION)
      message(STATUS "libMBD version: ${LIBMBD_VERSION}")
    endif()
  endif()
  set(LIBMBD_MESSAGE_SHOWN TRUE CACHE INTERNAL "Message shown flag")
  if(NOT TARGET LIBMBD::libmbd)
      add_library(LIBMBD::libmbd INTERFACE IMPORTED)
  endif()
  if(_LIBMBD_LINK_TARGET)
    # link through the config target, it carries the transitive dependencies
    set_property(TARGET LIBMBD::libmbd PROPERTY INTERFACE_LINK_LIBRARIES ${_LIBMBD_LINK_TARGET})
  else()
    set_property(TARGET LIBMBD::libmbd PROPERTY INTERFACE_LINK_LIBRARIES ${LIBMBD_LIBRARIES})
  endif()
  set_property(TARGET LIBMBD::libmbd PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${LIBMBD_INCLUDE_DIRS})
endif()

# prevent clutter in cache
MARK_AS_ADVANCED(LIBMBD_FOUND LIBMBD_LIBRARIES LIBMBD_INCLUDE_DIRS LIBMBD_VERSION)
