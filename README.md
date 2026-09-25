![VASP](.assets/vasp-logo.png)

This repository contains the CMake build system files for VASP.

After you downloaded an official VASP source tarball you can clone this repository and follow the steps outlined below to use cmake to build VASP.

Branching follows VASP major releases: for each major release there is a matching
branch named `6.5.x`, `6.6.x`, etc. Those branches roll: bug fixes and improvements to
the build system land there continuously, so cloning a branch is the recommended way to
build VASP and what the instructions below assume.

Revisions of a branch are tagged `<series>-r<n>`, for example `6.5.x-r2`: revision *n*
of the build system for the VASP 6.5 series. The counter belongs to this repository, not
to VASP — it is bumped when the build system changes, not when VASP is released. So any
`6.5.x-r*` tag builds any VASP `6.5.*`, and a fix made after `6.5.x-r1` simply becomes
`6.5.x-r2`. Tags are never moved.

Each tag has a matching [GitHub release](https://github.com/vasp-dev/cmake/releases)
carrying a `cmake-<tag>.tar.gz` asset and its SHA256, for packaging systems such as
Spack or EasyBuild that pin a fixed source and verify a checksum. Pin a tag when you
need reproducibility; follow the branch when you want the fixes.

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
- `-DCMAKE_BUILD_TYPE=Release|Debug|RelWithDebInfo`: standard CMake build type, forced to
  `Release` when left unset. `Debug` compiles *every* source with `VASP_OFLAG_DEB` and with
  the target-wide warning suppression removed, which also bypasses all per-file lists in
  [Per-file compilation flags](#per-file-compilation-flags) (including `VASP_OFLAG_MAIN`
  for `main.F`) (default: `Release`)

### Optimization / CPU tuning

- `-DVASP_OFLAG=<flag>`: override the default optimization flag (e.g. `-O2`, `-Ofast`) (default: according to arch/makefile.include default)
- `-DVASP_TARGET_CPU=<arch>`: target CPU architecture (e.g. `native`, `skylake`, `zen3`) (default: empty or read from `${VASP_TARGET_CPU}`). A flag prefix is stripped, so `-march=haswell`, `-tp=zen3` etc. are accepted as well

### Per-file compilation flags

Every source is compiled with `VASP_OFLAG_DEFAULT` unless it is named in one of the lists
below. All lists accept `;`- or space-separated file names, e.g.
`-DVASP_SOURCES_O1="pead.F rot.F"`. When a file appears in more than one list the later
entry in this table wins (`VASP_SOURCES_DEB` beats everything):

- `-DVASP_SOURCES_O3=<files>`: compile with `VASP_OFLAG_O3`
- `-DVASP_SOURCES_O2=<files>`: compile with `VASP_OFLAG_O2`
- `-DVASP_SOURCES_O1=<files>`: compile with `VASP_OFLAG_O1`
- `-DVASP_SOURCES_IN=<files>`: compile with `VASP_OFLAG_IN` (the `SOURCE_IN` group of
  `src/.objects`, prefilled from that file)
- `-DVASP_SOURCES_DEB=<files>`: files to compile with `VASP_OFLAG_DEB` instead of their
  normal optimization flags (example: `-DVASP_SOURCES_DEB="reader.F;electron.F"`). These
  files are also the only ones compiled without the target-wide warning suppression, so the
  warning flags in `VASP_OFLAG_DEB` take effect. Marking `main.F` keeps `VASP_OFLAG_MAIN`
  appended so it stays at `-O0`; it is the only way to make gfortran's `-ffpe-trap` active,
  since that code is only emitted in the main program unit

The `VASP_SOURCES_O1`/`O2`/`O3` defaults are compiler-dependent — some compilers need selected
files at a lower level — so *append* to them rather than overwriting if you only want to add
a file. Two more source lists exist:

- `-DVASP_SOURCES=<files>`: additional files to build on top of `VASP_SOURCES_DEFAULT` (default: empty)
- `VASP_SOURCES_DEFAULT`: the full default source list, read from `src/.objects`. Advanced, do not set by hand

The `VASP_OFLAG_*` values referenced above are compiler-specific and derived on every
configure; they cannot be set with `-D`. The general level is changed with
`-DVASP_OFLAG=<flag>`, and the effective flags are printed in the options summary at the end
of the configure run.

### MPI / runtime-related toggles

- `-DVASP_COLLECTIVE=ON|OFF`: enable MPI collectives (default: ON)
- `-DVASP_MPI_INPLACE=ON|OFF`: use MPI inplace (default: ON)
- `-DVASP_MPI_BLOCK=<n>`: MPI block size (default: `8000`)
- `-DVASP_CACHE_SIZE=<n>`: cache size (default: `4000`)

### Memory / algorithmic toggles

- `-DVASP_AVOIDALLOC=ON|OFF`: avoid automatic allocation (default: ON)
- `-DVASP_SHMEM=ON|OFF`: enable shared memory for reduced memory usage (default: OFF)
- `-DVASP_SHMEM_BCAST=ON|OFF`: use a shared-memory buffer for MPI bcast (default: OFF).
  Experimental, best left at the default
- `-DVASP_SHMEM_RPROJ=ON|OFF`: use shared memory for the real-space PAW projectors (default: OFF).
  Experimental, best left at the default
- `-DVASP_SYSV=ON|OFF`: enable shared-memory for ipcs and System-V (default: OFF)
- `-DVASP_FOCK_DBLBUF=ON|OFF`: double buffering for the exchange potential (default: ON).
  On by default for a long time; there is no reason to turn it off

### VASP feature switches

- `-DVASP_PLUGINS=ON|OFF`: enable VASP plugin support (default: OFF)
- `-DVASP_VASPML=ON|OFF`: enable VASPml machine learning library (experimental). Builds `libvaspml`, links it into the VASP executables, and compiles standalone VASPml tools. Requires MPI CXX and a CBLAS provider (OpenBLAS, MKL, etc.). When using MKL with a non-Intel compiler, `VASPML_USE_MKL` is set automatically. (default: OFF)
- `-DVASP_QD_EMULATE=ON|OFF`: use QD library for quadruple precision types (default: OFF).
  Enabled automatically for compilers without native quadruple precision
- `-DVASP_PROFILING=ON|OFF`: enable profiling (default: OFF)

### External library support

- `-DVASP_SCALAPACK=ON|OFF`: enable ScaLAPACK, highly recommended (default: ON)
- `-DVASP_HDF5=ON|OFF`: enable HDF5 support (default: ON)
- `-DVASP_LIBXC=ON|OFF`: enable Libxc support (default: OFF)
- `-DVASP_LIBBEEF=ON|OFF`: enable libbeef (van-der-Waals functionals), not supported yet (default: OFF)
- `-DVASP_DFTD4=ON|OFF`: enable DFTD4 (default: OFF). Found via the CMake package config shipped with dftd4, otherwise via `DFTD4_ROOT`. Requires dftd4 3.7.0 or older: dftd4 4.0 changed the API and the adaptation is part of VASP.6.6.0, so a newer installation is rejected at configure time
- `-DVASP_WANNIER90=ON|OFF`: enable Wannier90 (default: OFF)
- `-DVASP_LIBMBD=ON|OFF`: enable libMBD many-body dispersion (default: OFF). Found via the CMake package config shipped with libmbd (package `Mbd`), otherwise via `LIBMBD_ROOT`
- `-DVASP_USE_NVPL=AUTO|ON|OFF`: Use NVIDIA NVPL BLAS/LAPACK/ScaLAPACK  (default:AUTO)
- `-DVASP_VECLIBFORT=ON|OFF`: Use VecLibFort for BLAS/LAPACK on Mac OS to use the Accelerate framework (default:OFF)
- `-DVASP_VECLIBFORT_ROOT=<path>`: root of the vecLibFort installation, e.g. a Homebrew Cellar path (default: `/opt/homebrew`)

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
- `-DVASP_HOST_NAME=<name>`: host system name, ends up in the `HOST` string printed by VASP (default: `CMAKE_SYSTEM_NAME`)

Per-source optimization flags are documented under
[Per-file compilation flags](#per-file-compilation-flags).
