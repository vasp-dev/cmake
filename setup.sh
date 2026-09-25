#!/usr/bin/env bash
set -euo pipefail

# Creates relative CMakeLists.txt symlinks pointing into cmake/CMakeLists/.

usage() {
  cat >&2 <<'EOF'
usage: cmake/setup.sh [<vasp-root>]

When <vasp-root> is omitted, the script assumes it lives in <vasp-root>/cmake/
and must be executed from either:
  - <vasp-root>
  - <vasp-root>/cmake (or a subdirectory)

When <vasp-root> is provided, the script may be executed from any directory.
EOF
}

if [[ $# -gt 1 ]]; then
  usage
  exit 2
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_VASPROOT="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd -P)"
PWD_REAL="$(pwd -P)"

if [[ $# -eq 1 ]]; then
  VASPROOT="$(CDPATH= cd -- "$1" && pwd -P)"
else
  VASPROOT="${DEFAULT_VASPROOT}"
fi

is_under_dir() {
  # $1: parent dir (absolute)
  # $2: path (absolute)
  case "$2" in
    "$1"|"$1"/*) return 0 ;;
    *) return 1 ;;
  esac
}

if [[ $# -eq 0 ]]; then
  # Allow running from:
  # - the repository root
  # - anywhere inside the cmake/ submodule directory
  if [[ "${PWD_REAL}" != "${VASPROOT}" ]] && ! is_under_dir "${SCRIPT_DIR}" "${PWD_REAL}"; then
    echo "error: run this from either:" >&2
    echo "       - ${VASPROOT}" >&2
    echo "       - ${SCRIPT_DIR} (or a subdirectory)" >&2
    echo "       (current directory: ${PWD_REAL})" >&2
    echo "hint: or pass an explicit root: cmake/setup.sh ${VASPROOT}" >&2
    exit 1
  fi
fi

if [[ ! -d "${VASPROOT}/cmake/CMakeLists" ]]; then
  echo "error: not a VASP source tree (missing ${VASPROOT}/cmake/CMakeLists)" >&2
  exit 1
fi

link_cmakelists() {
  # $1: directory relative to VASPROOT
  # $2: relative symlink target (relative to the link location)
  local rel_dir="$1"
  local rel_target="$2"
  local dst_dir="${VASPROOT}/${rel_dir}"
  local dst_link="${dst_dir}/CMakeLists.txt"

  if [[ ! -d "${dst_dir}" ]]; then
    echo "error: directory not found: ${dst_dir}" >&2
    exit 1
  fi

  ln -sfn "${rel_target}" "${dst_link}"
}

link_cmakelists "."           "cmake/CMakeLists/CMakeLists_root.txt"
link_cmakelists "src"         "../cmake/CMakeLists/CMakeLists_src.txt"
link_cmakelists "src/fftlib"  "../../cmake/CMakeLists/CMakeLists_fftlib.txt"
link_cmakelists "src/lib"     "../../cmake/CMakeLists/CMakeLists_lib.txt"
link_cmakelists "src/parser"  "../../cmake/CMakeLists/CMakeLists_parser.txt"
link_cmakelists "src/vaspml" "../../cmake/CMakeLists/CMakeLists_vaspml.txt"
link_cmakelists "testsuite"   "../cmake/CMakeLists/CMakeLists_testsuite.txt"
