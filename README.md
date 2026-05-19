![VASP](.assets/vasp-logo.png)

This repository contains the CMake build system files for VASP.

After you downloaded an official VASP source tarball you can clone this repository and follow the steps outlined below to use cmake to build VASP.

Branching follows VASP major releases: for each major release there is a matching
branch named `6.5.x`, `6.6.x`, etc.

Build steps using cmake:

* Get the VASP version from the portal and untar it
* Clone the repository, and directly specify the VASP version, into the root directory of your VASP distribution:
  ```
  cd /your/vasp/directory
  git clone -b 6.5.x git@github.com:vasp-dev/cmake.git cmake
  ```

* Run the setup script (creating `CMakeLists.txt` symlinks in the VASP tree):
  ```
  bash cmake/setup.sh
  ```

* Create a build directory and run cmake:
  ```
  mkdir -p your-build-dir
  cd your-build-dir

  # Configure (example): point CMake to the VASP source root and pass options
  cmake /your/vasp/directory \
    -DVASP_OPENMP=ON \
    -DVASP_HDF5=ON

  # Optional: use Ninja instead of Make
  # cmake /your/vasp/directory -G Ninja -DVASP_OPENMP=ON
  ```

* And build VASP (in the ``your-build-dir`` directory):
  ```
  make -j all
  ```

For more information please visit the [VASP wiki](https://www.vasp.at/wiki/cmake).

## Supported Compilers

Compiler handling is implemented in `cmake/sources_and_flags_options.cmake` via CMake's
`CMAKE_Fortran_COMPILER_ID`. The following Fortran compiler IDs are explicitly handled:

- `GNU` (gfortran)
- `Intel` / `IntelLLVM` (ifort / ifx)
- `NVHPC` (nvfortran) with GPU support via OpenACC
- `Flang` (LLVM flang)
- `Cray` (crayftn)
- `Fujitsu` (Fujitsu Fortran compiler)
- `NFORT` (NEC nfort)

If one of these compilers is not correctly detected please set the environment variable `FC`, `CC`, and `CXX` accordingly.

## CMake Options (VASP_*)

All options are passed to CMake as `-D<name>=<value>`. These options cover most available pre-compiler options in VASP and will also search for libraries accordingly if needed. Other pre-compiler flags not listed here can of course be passed as well via: `-DVASP_PP_EXTRA=<options>`.

Library and package configuration for options that need extra libraries, e.g. HDF5 or LibXC, are searched for. If they are not found consider setting `<package>_ROOT` before calling cmake.

BLAS and LAPACK are mandatory and are detected via the default cmake packages. Set the environment variable `BLA_VENDOR` to steer the selection. See the [cmake documentation](https://cmake.org/cmake/help/latest/module/FindBLAS.html#) for more details.

### General build features

- `-DVASP_OPENMP=ON|OFF`: enable OpenMP (default: OFF)
- `-DVASP_FFTLIB=ON|OFF`: enable internal FFTLIB (default: OFF)
- `-DVASP_TESTSUITE=ON|OFF`: enable testsuite in build directory (default: ON)

### Optimization / CPU tuning

- `-DVASP_OFLAG=<flag>`: override the default optimization flag (e.g. `-O2`, `-Ofast`) (default: according to arch/makefile.include default)
- `-DVASP_TARGET_CPU=<arch>`: target CPU architecture (e.g. `native`, `skylake`, `zen3`) (default: empty or read from `${VASP_TARGET_CPU}`)

### MPI / runtime-related toggles

- `-DVASP_COLLECTIVE=ON|OFF`: enable MPI collectives (default: ON)
- `-DVASP_MPI_INPLACE=ON|OFF`: use MPI inplace (default: ON)
- `-DVASP_MPI_BLOCK=<n>`: MPI block size (default: `8000`)
- `-DVASP_CACHE_SIZE=<n>`: cache size (default: `4000`)

### Memory / algorithmic toggles

- `-DVASP_AVOIDALLOC=ON|OFF`: avoid automatic allocation (default: ON)
- `-DVASP_SHMEM=ON|OFF`: enable shared memory for reduced memory usage (default: OFF)
- `-DVASP_SYSV=ON|OFF`: enable shared-memory for ipcs and System-V (default: OFF)

### VASP feature switches

- `-DVASP_PLUGINS=ON|OFF`: enable VASP plugin support (default: OFF)
- `-DVASP_VASPML=ON|OFF`: enable VASPml machine learning library (experimental). Builds `libvaspml`, links it into the VASP executables, and compiles standalone VASPml tools. Requires MPI CXX and a CBLAS provider (OpenBLAS, MKL, etc.). When using MKL with a non-Intel compiler, `VASPML_USE_MKL` is set automatically. (default: OFF)
- `-DVASP_QD_EMULATE=ON|OFF`: use QD library for quadruple precision types (default: OFF)
- `-DVASP_PROFILING=ON|OFF`: enable profiling (default: OFF)

### External library support

- `-DVASP_SCALAPACK=ON|OFF`: enable ScaLAPACK, highly recommended (default: ON)
- `-DVASP_HDF5=ON|OFF`: enable HDF5 support (default: ON)
- `-DVASP_LIBXC=ON|OFF`: enable Libxc support (default: OFF)
- `-DVASP_LIBBEEF=ON|OFF`: enable libbeef (van-der-Waals functionals) (default: OFF)
- `-DVASP_DFTD4=ON|OFF`: enable DFTD4 (default: OFF)
- `-DVASP_WANNIER90=ON|OFF`: enable Wannier90 (default: OFF)
- `-DVASP_USE_NVPL=AUTO|ON|OFF`: Use NVIDIA NVPL BLAS/LAPACK/ScaLAPACK  (default:AUTO)
- `-DVASP_VECLIBFORT=ON|OFF`: Use VecLibFort for BLAS/LAPACK on Mac OS to use the Accelerate framework (default:OFF)

### GPU support (NVIDIA OpenACC)

GPU offloading for NVIDIA GPUs is automatically attempted as soon as a nhvpc compiler is detected. By default it will build for GPUs present on the host system. To cross compile for other architectures use `-DCMAKE_CUDA_ARCHITECTURES` (see below and the official cmake doc [here](https://cmake.org/cmake/help/latest/variable/CMAKE_CUDA_ARCHITECTURES.html)). If `MKLROOT` is set nvhpc will automatically link these for host side blas/lapack calls.

To enable GPU offloading for Intel or AMD GPUs you have to use either the Intel OneApi ifx compiler for Intel GPUs or crayftn for AMD GPUs and pass `-DVASP_OMP_OFFLOAD=ON`.All other options will be automatically set.

Read the cmake output of the section `GPU support detection` carefully if all options are set correctly.

- `-DVASP_CUDA=ON|OFF`: enable CUDA acceleration (default: OFF)
- `-DVASP_CUDA_VERSION=<ver>`: CUDA version passed to NVHPC (example: `-DVASP_CUDA_VERSION=12.6`) (default: `Default`)
- `-DCMAKE_CUDA_ARCHITECTURES=<cc-versions list>`: list of nvidia compute capability / architectures. Just pass the numbers. Example `-DCMAKE_CUDA_ARCHITECTURES=100` for adding `-gpu=cc100` .
- `-DVASP_USE_NCCL=ON|OFF`: enable NCCL support (default: ON)
- `-DVASP_CUSOLVERMP=ON|OFF`: enable cuSOLVERmp/cublasmp (requires ScaLAPACK) (default: ON)

See also [GPU ports of VASP](http://vasp.at/wiki/GPU_ports_of_VASP) for more details.

### Licensing

- `-DVASP_LICENSE=<key>`: VASP license key (default: empty)
- `-DVASP_REVOKED_KEYS_PATH=<path>`: path to revoked license keys file (default: empty)

### Misc

- `-DVASP_PP_EXTRA=<flags>`: extra preprocessor flags not covered by options above (default: empty)
- `-DVASP_HOST_NAME=<name>`: host system name (default: `CMAKE_SYSTEM_NAME`)
- `-DVASP_SOURCES_DEB=<files>`: files to compile with debug flags
