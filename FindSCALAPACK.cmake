set(_SCALAPACK_PATHS)
set(_SCALAPACK_EXPLICIT_ROOT FALSE)

if(SCALAPACK_ROOT OR DEFINED ENV{SCALAPACK_ROOT})
  # User explicitly told us where to look → trust them
  list(APPEND _SCALAPACK_PATHS
       ${SCALAPACK_ROOT}
       $ENV{SCALAPACK_ROOT}
  )
  set(_SCALAPACK_DEFAULT_PATH_SWITCH NO_DEFAULT_PATH)
  set(_SCALAPACK_EXPLICIT_ROOT TRUE)
elseif(DEFINED ENV{EBROOTSCALAPACK} OR DEFINED ENV{AMDSCALAPACK_ROOT} OR DEFINED ENV{NLC_ROOT})
  # roots exported by EasyBuild, AOCL and NEC NLC modules
  list(APPEND _SCALAPACK_PATHS
       $ENV{EBROOTSCALAPACK}
       $ENV{AMDSCALAPACK_ROOT}
       $ENV{NLC_ROOT}
  )
  set(_SCALAPACK_DEFAULT_PATH_SWITCH NO_DEFAULT_PATH)
  set(_SCALAPACK_EXPLICIT_ROOT TRUE)
else()
  # No explicit root → allow MPI-based discovery
  list(APPEND _SCALAPACK_PATHS ${_MPI_LIBDIRS})
endif()

# Optional NVPL ScaLAPACK (aarch64). This is an opt-in feature controlled by
# VASP_USE_NVPL from the top-level CMakeLists.txt. Only prefer NVPL when the
# user did not explicitly point to another ScaLAPACK installation.
set(_VASP_NVPL_SCALAPACK_HINTS)
set(_VASP_NVPL_MODE "${VASP_USE_NVPL}")
string(TOUPPER "${_VASP_NVPL_MODE}" _VASP_NVPL_MODE)

set(_VASP_IS_AARCH64 FALSE)
if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
  set(_VASP_IS_AARCH64 TRUE)
endif()

set(_VASP_TRY_NVPL_SCALAPACK FALSE)
if(_VASP_NVPL_MODE STREQUAL "ON")
  set(_VASP_TRY_NVPL_SCALAPACK TRUE)
elseif(_VASP_NVPL_MODE STREQUAL "AUTO" AND _VASP_IS_AARCH64)
  set(_VASP_TRY_NVPL_SCALAPACK TRUE)
endif()

if(_VASP_TRY_NVPL_SCALAPACK AND NOT _SCALAPACK_EXPLICIT_ROOT)
  if(DEFINED ENV{NVPL_ROOT} AND NOT "$ENV{NVPL_ROOT}" STREQUAL "")
    list(APPEND _VASP_NVPL_SCALAPACK_HINTS "$ENV{NVPL_ROOT}")
  endif()
  foreach(_var NVHPC NVHPC_ROOT)
    if(DEFINED ENV{${_var}} AND NOT "$ENV{${_var}}" STREQUAL "")
      list(APPEND _VASP_NVPL_SCALAPACK_HINTS "$ENV{${_var}}/math_libs/nvpl")
    endif()
  endforeach()
  if(EXISTS "/opt/nvidia/hpc_sdk")
    file(GLOB _VASP_NVPL_SCALAPACK_GLOB LIST_DIRECTORIES true "/opt/nvidia/hpc_sdk/Linux_*/*/math_libs/nvpl")
    list(APPEND _VASP_NVPL_SCALAPACK_HINTS ${_VASP_NVPL_SCALAPACK_GLOB})
  endif()
  list(REMOVE_DUPLICATES _VASP_NVPL_SCALAPACK_HINTS)

  if(_VASP_NVPL_SCALAPACK_HINTS)
    # Prepend NVPL hints so it wins over MPI libdir scanning.
    list(PREPEND _SCALAPACK_PATHS ${_VASP_NVPL_SCALAPACK_HINTS})
  endif()
endif()

set(MKLROOT $ENV{MKLROOT})
set(_SCALAPACK_INCLUDE_PATHS)
set(_SCALAPACK_DEFAULT_PATH_SWITCH)

# First try to see if the user has its own build scalapack library and prioritize it 
if(_SCALAPACK_PATHS)
  # disable default paths if ROOT is set
  set(_SCALAPACK_DEFAULT_PATH_SWITCH NO_DEFAULT_PATH)
else()
  # try to detect location with pkgconfig
  find_package(PkgConfig QUIET)
  if(PKG_CONFIG_FOUND)
    pkg_check_modules(PKG_SCALAPACK QUIET "scalapack")
  endif()
  set(_SCALAPACK_PATHS ${PKG_SCALAPACK_LIBRARY_DIRS})
  set(_SCALAPACK_INCLUDE_PATHS ${PKG_SCALAPACK_INCLUDE_DIRS})
endif()

if(SCALAPACK_LIBRARIES)
  # already set elsewhere (e.g., NVPL selection)
elseif(_VASP_TRY_NVPL_SCALAPACK AND NOT _SCALAPACK_EXPLICIT_ROOT)
  # NVPL provides multiple ScaLAPACK variants depending on MPI interface.
  # Prefer the generic name first; if not found, try common MPI-specific ones.
  find_library(
    SCALAPACK_LIBRARIES
    NAMES
      nvpl_scalapack_lp64
      scalapack scalapack-mpich scalapack-openmpi
    HINTS ${_SCALAPACK_PATHS}
    PATH_SUFFIXES "lib" "lib64"
    ${_SCALAPACK_DEFAULT_PATH_SWITCH}
  )
else()
  find_library(
    SCALAPACK_LIBRARIES
    NAMES scalapack scalapack-mpich scalapack-openmpi
    HINTS ${_SCALAPACK_PATHS}
    PATH_SUFFIXES "lib" "lib64"
    ${_SCALAPACK_DEFAULT_PATH_SWITCH}
  )
endif()

# NVPL ScaLAPACK may require an explicit BLACS library depending on packaging.
# If available alongside the ScaLAPACK library, add it to the link line.
if(SCALAPACK_LIBRARIES AND SCALAPACK_LIBRARIES MATCHES "nvpl_scalapack")
  get_filename_component(_VASP_NVPL_SCALAPACK_DIR "${SCALAPACK_LIBRARIES}" DIRECTORY)
  find_library(
    _VASP_NVPL_BLACS
    NAMES
      nvpl_blacs_lp64_openmpi5
      nvpl_blacs_lp64_openmpi4
      nvpl_blacs_lp64_openmpi3
      nvpl_blacs_lp64_mpich
    HINTS "${_VASP_NVPL_SCALAPACK_DIR}"
    NO_DEFAULT_PATH
  )
  if(_VASP_NVPL_BLACS)
    set(SCALAPACK_LIBRARIES "${SCALAPACK_LIBRARIES};${_VASP_NVPL_BLACS}")
  endif()
endif()

# If NVPL ScaLAPACK was explicitly requested, fail if it wasn't found.
if(_VASP_NVPL_MODE STREQUAL "ON" AND _VASP_IS_AARCH64 AND NOT _SCALAPACK_EXPLICIT_ROOT)
  if(NOT SCALAPACK_LIBRARIES OR NOT SCALAPACK_LIBRARIES MATCHES "nvpl_scalapack")
    message(FATAL_ERROR "VASP_USE_NVPL=ON requested but NVPL ScaLAPACK was not found. Set SCALAPACK_ROOT or NVPL_ROOT, or disable NVPL (VASP_USE_NVPL=OFF).")
  endif()
endif()

# if we did not find it yet and LAPACK is provided by Intel MKL try this
if(NOT SCALAPACK_LIBRARIES AND LAPACK_LIBRARIES MATCHES "mkl")

  # check first if we are using openmpi
  set (MPI_IS_OMPI FALSE)
  execute_process(COMMAND grep -i "OMPI_MPI" ${MPI_Fortran_F77_HEADER_DIR}/mpi.h
    RESULT_VARIABLE MPI_GREP_RESULT
    OUTPUT_QUIET
    ERROR_QUIET)

  if(MPI_GREP_RESULT EQUAL 0)
    set(MPI_MODE openmpi)
  else()
    set(MPI_MODE intelmpi)
  endif()

  # now check if lapack is lp or ilp and use scalapack from mkl
  if(LAPACK_LIBRARIES MATCHES "ilp64")
     set(MKL_SCALAPACK_NAMES mkl_scalapack_ilp64)
    set(MKL_BLACS_MPI_NAMES mkl_blacs_${MPI_MODE}_ilp64)
  else()
    set(MKL_SCALAPACK_NAMES mkl_scalapack_lp64)
    set(MKL_BLACS_MPI_NAMES mkl_blacs_${MPI_MODE}_lp64)
  endif()

  find_library(
    MKL_SCALAPACK_LIBRARY
    NAMES ${MKL_SCALAPACK_NAMES}
    HINTS ${_SCALAPACK_PATHS} ${MKLROOT}
    PATH_SUFFIXES "lib" "lib64" "lib/intel64"
  )

  find_library(
    MKL_BLACS_LIBRARY
    NAMES ${MKL_BLACS_MPI_NAMES}
    HINTS ${_SCALAPACK_PATHS} ${MKLROOT}
    PATH_SUFFIXES "lib" "lib64" "lib/intel64"
  )

  if(MKL_SCALAPACK_LIBRARY AND MKL_BLACS_LIBRARY)
    if(NOT SCALAPACK_MESSAGE_SHOWN)
      message(STATUS "Found ScaLAPACK provided via Intel MKL")
    endif()
    set(SCALAPACK_LIBRARIES ${MKL_SCALAPACK_LIBRARY} ${MKL_BLACS_LIBRARY})
  else()
    message(STATUS "Could not find Intel MKL Scalapack or BLACS libraries")
  endif()
endif()

# if we did not find it yet we are maybe on a cray machine?
if(NOT SCALAPACK_LIBRARIES AND DEFINED ENV{CRAYPE_VERSION})
  message(STATUS "Found Cray environment: attempt to link against libsci")
  set(_SCALAPACK_PATHS ${SCALAPACK_ROOT} $ENV{CRAY_LIBSCI_PREFIX_DIR})
  find_library(
  SCALAPACK_LIBRARIES
  NAMES sci_gnu_mpi sci_cray_mpi
  HINTS ${_SCALAPACK_PATHS}
  PATH_SUFFIXES "lib" "lib64"
  ${_SCALAPACK_DEFAULT_PATH_SWITCH}
  )
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(SCALAPACK
                                  REQUIRED_VARS SCALAPACK_LIBRARIES
                                  FAIL_MESSAGE "Could not find ScaLAPACK, please specify SCALAPACK_ROOT or set as environment variable")

# add target to link against
if(SCALAPACK_FOUND)
  if(NOT TARGET SCALAPACK::SCALAPACK)
    add_library(SCALAPACK::SCALAPACK INTERFACE IMPORTED)
  endif()
  set_property(TARGET SCALAPACK::SCALAPACK PROPERTY INTERFACE_LINK_LIBRARIES ${SCALAPACK_LIBRARIES})
  if(_VASP_TRY_NVPL_SCALAPACK AND SCALAPACK_LIBRARIES MATCHES "nvpl_scalapack")
    if(NOT SCALAPACK_MESSAGE_SHOWN)
      message(STATUS "Using NVIDIA NVPL ScaLAPACK: disable with -DVASP_USE_NVPL=OFF if undesired")
    endif()
  endif()
  set(SCALAPACK_MESSAGE_SHOWN TRUE CACHE INTERNAL "Message shown flag")
endif()

# prevent clutter in cache
mark_as_advanced(SCALAPACK_FOUND SCALAPACK_LIBRARIES SCALAPACK_INCLUDE_DIRS pkgcfg_lib_PKG_SCALAPACK_scalapack )
