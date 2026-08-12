#.rst:
# FindFFTW
# -----------
#
# This module looks for the fftw3 library.
#
# The following variables are set each compnent, where COMPNENT is SERIAL, OMP or THREADS.
#
# ::
#
#   FFTW_FOUND           - True if double precision fftw library is found
#   FFTW_${COMPONENT}_LIBRARIES       - The required libraries
#   FFTW_${COMPONENT}_INCLUDE_DIRS    - The required include directory
#
# The following import target is created
#
# ::
#
#   FFTW::FFTW_${COMPONENT}

# check if FFTW can be provided by BLAS libraries like MKL and ArmPL
if(NOT TARGET BLAS::BLAS)
    find_package(BLAS MODULE QUIET)
endif()

# NVIDIA NVPL provides an FFTW-compatible interface via libnvpl_fftw.so.
# NVPL is typically shipped with the NVIDIA HPC SDK under:
#   <NVHPC{,_ROOT}>/math_libs/nvpl
# or installed system-wide, e.g.:
#   /opt/nvidia/hpc_sdk/Linux_*/<version>/math_libs/nvpl
set(_VASP_NVPL_PATHS)
if(DEFINED ENV{NVPL_ROOT} AND NOT "$ENV{NVPL_ROOT}" STREQUAL "")
    list(APPEND _VASP_NVPL_PATHS "$ENV{NVPL_ROOT}")
endif()
foreach(_var NVHPC NVHPC_ROOT)
    if(DEFINED ENV{${_var}} AND NOT "$ENV{${_var}}" STREQUAL "")
        list(APPEND _VASP_NVPL_PATHS "$ENV{${_var}}/math_libs/nvpl")
    endif()
endforeach()
if(EXISTS "/opt/nvidia/hpc_sdk")
    file(GLOB _VASP_NVPL_GLOB LIST_DIRECTORIES true "/opt/nvidia/hpc_sdk/Linux_*/*/math_libs/nvpl")
    list(APPEND _VASP_NVPL_PATHS ${_VASP_NVPL_GLOB})
endif()
list(REMOVE_DUPLICATES _VASP_NVPL_PATHS)

macro(find_ffftw_component name lib_name lib_symbol)
    # set paths to look for library
    if(DEFINED ENV{FFTW_${name}_ROOT} AND NOT "$ENV{FFTW_${name}_ROOT}" STREQUAL "")
      set(_FFTW_${name}_PATHS $ENV{FFTW_${name}_ROOT})
    elseif(DEFINED ENV{FFTW_ROOT} AND NOT "$ENV{FFTW_ROOT}" STREQUAL "")
      # Check for FFTW_ROOT environment variable
      set(_FFTW_${name}_PATHS $ENV{FFTW_ROOT})
    elseif(DEFINED ENV{EBROOTFFTW} AND NOT "$ENV{EBROOTFFTW}" STREQUAL "")
      # Check for EasyBuild FFTW root
      set(_FFTW_${name}_PATHS $ENV{EBROOTFFTW})
    endif()
    set(_FFTW_${name}_DEFAULT_PATH_SWITCH)

    # check if FFTW is contained in BLAS library
    if(TARGET BLAS::BLAS)
        set(CMAKE_REQUIRED_LIBRARIES BLAS::BLAS)

        include(CheckFunctionExists)
        unset(FFTW_${name}_BLAS_SYMBOL CACHE) # Result is cached, so change of library will not lead to a new check automatically
        set(CMAKE_REQUIRED_QUIET TRUE)
        CHECK_FUNCTION_EXISTS(${lib_symbol} FFTW_${name}_BLAS_SYMBOL)

        if(FFTW_${name}_BLAS_SYMBOL)
            set(_FFTW_${name}_DEFAULT_PATH_SWITCH NO_DEFAULT_PATH)
            set(FFTW_${name}_LIBRARIES "BLAS::BLAS" CACHE STRING "" FORCE)
            foreach(blas_lib IN LISTS BLAS_LIBRARIES)
                cmake_path(GET blas_lib PARENT_PATH blas_lib_dir)
                cmake_path(GET blas_lib_dir PARENT_PATH blas_parent_lib_dir)
                list(APPEND _FFTW_${name}_PATHS ${blas_lib_dir} ${blas_parent_lib_dir})
            endforeach()
        endif()
    endif()

    # also add MKLROOT if it is defined:
    if(DEFINED ENV{MKLROOT})
        list(APPEND _FFTW_${name}_PATHS $ENV{MKLROOT})
    endif()

    # also add NVPL paths (FFTW-compatible interface)
    if(_VASP_NVPL_PATHS)
        list(APPEND _FFTW_${name}_PATHS ${_VASP_NVPL_PATHS})
    endif()

    if(_FFTW_${name}_PATHS)
        # disable default paths if ROOT is set
        set(_FFTW_${name}_DEFAULT_PATH_SWITCH NO_DEFAULT_PATH)
    else()
        # try to detect location with pkgconfig
        find_package(PkgConfig QUIET)
        if(PKG_CONFIG_FOUND)
          pkg_check_modules(PKG_FFTW_${name} QUIET "fftw3")
        endif()
        set(_FFTW_${name}_PATHS ${PKG_FFTW_${name}_LIBRARY_DIRS})
        set(_FFTW_${name}_INCLUDE_PATHS ${PKG_FFTW_${name}_INCLUDE_DIRS})
    endif()

    if(NOT FFTW_${name}_LIBRARIES)
        find_library(
            FFTW_${name}_LIBRARIES
            NAMES ${lib_name}
            HINTS ${_FFTW_${name}_PATHS}
            PATH_SUFFIXES "lib" "lib64" "lib/x86_64-linux-gnu"
            ${_FFTW_${name}_DEFAULT_PATH_SWITCH}
        )
    endif()

    # NVPL FFT ships FFTW headers under include/nvpl_fftw (fftw3.h), and also
    # provides nvpl_fftw.h. Support both layouts.
    find_path(FFTW_${name}_INCLUDE_DIRS
        NAMES "fftw3.h" "nvpl_fftw.h"
        HINTS ${_FFTW_${name}_PATHS} ${_FFTW_${name}_INCLUDE_PATHS}
        PATH_SUFFIXES
          "include_mp" "include" "include_mp/fftw" "include/fftw"
          "include/nvpl_fftw" "include/nvpl_fftw/fftw"
        ${_FFTW_${name}_DEFAULT_PATH_SWITCH}
    )

    # add target to link against
    if(FFTW_${name}_LIBRARIES AND FFTW_${name}_INCLUDE_DIRS)
        if(NOT FFTW_MESSAGE_SHOWN)
          if(VASP_OPENMP)
            message(STATUS "Using OpenMP enabled FFTW")
          endif()
          if("${FFTW_${name}_LIBRARIES}" STREQUAL "BLAS::BLAS")
            message(STATUS "Found FFTW library: ${FFTW_${name}_LIBRARIES} (contained in BLAS)")
          else()
            message(STATUS "Found FFTW library: ${FFTW_${name}_LIBRARIES}")
          endif()
        endif()
        if(NOT TARGET FFTW::FFTW_${name})
            add_library(FFTW::FFTW_${name} INTERFACE IMPORTED)
        endif()
        set_property(TARGET FFTW::FFTW_${name} PROPERTY INTERFACE_LINK_LIBRARIES ${FFTW_${name}_LIBRARIES})
        set_property(TARGET FFTW::FFTW_${name} PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${FFTW_${name}_INCLUDE_DIRS})
        set(FFTW_MESSAGE_SHOWN TRUE CACHE INTERNAL "Message shown flag")
        # add to rpath
        foreach(lib ${FFTW_${name}_LIBRARIES})
          get_filename_component(lib_dir ${lib} DIRECTORY)
          list(APPEND VASP_EXTERNAL_LIB_DIRS ${lib_dir})
        endforeach()
    endif()

    # prevent clutter in cache
    MARK_AS_ADVANCED(FFTW_${name}_LIBRARIES FFTW_${name}_INCLUDE_DIRS pkgcfg_lib_PKG_FFTW_${name}_fftw3)
endmacro()

set(FFTW_COMP SERIAL) # default
if(FFTW_FIND_COMPONENTS)
    set(FFTW_COMP ${FFTW_FIND_COMPONENTS})
endif()

set(FFTW_REQUIRED_VARS)

find_ffftw_component(SERIAL "nvpl_fftw;fftw3" fftw_plan_dft)
list(APPEND FFTW_REQUIRED_VARS FFTW_SERIAL_INCLUDE_DIRS FFTW_SERIAL_LIBRARIES)

foreach(comp IN LISTS FFTW_COMP)
    if(${comp} STREQUAL "OMP")
        # NVPL uses a single library (libnvpl_fftw.so) for both serial and threaded execution.
        find_ffftw_component(OMP "nvpl_fftw;fftw3_omp" fftw_init_threads)
        if(TARGET FFTW::FFTW_OMP AND TARGET FFTW::FFTW_SERIAL)
            target_link_libraries(FFTW::FFTW_OMP INTERFACE FFTW::FFTW_SERIAL)
        endif()
        list(APPEND FFTW_REQUIRED_VARS FFTW_OMP_INCLUDE_DIRS FFTW_OMP_LIBRARIES)
    elseif(${comp} STREQUAL "THREADS")
        # NVPL uses a single library (libnvpl_fftw.so) for both serial and threaded execution.
        find_ffftw_component(THREADS "nvpl_fftw;fftw3_threads" fftw_init_threads)
        list(APPEND FFTW_REQUIRED_VARS FFTW_THREADS_INCLUDE_DIRS FFTW_THREADS_LIBRARIES)
        if(TARGET FFTW::FFTW_THREADS AND TARGET FFTW::FFTW_SERIAL)
            target_link_libraries(FFTW::FFTW_THREADS INTERFACE FFTW::FFTW_SERIAL)
        endif()
    elseif(NOT ${comp} STREQUAL "SERIAL")
        message(FATAL_ERROR "FindFFTW: Illegal component \"${comp}\"")
    endif()
endforeach()

# check if found
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(FFTW
                                  REQUIRED_VARS ${FFTW_REQUIRED_VARS}
                                  FAIL_MESSAGE "Could not find FFTW libraries, please specify FFTW_ROOT or set as environment variable")
MARK_AS_ADVANCED(FFTW_FOUND)
