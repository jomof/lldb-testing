#!/bin/bash

MACOS_ARCH=${MACOS_ARCH:-arm64}

echo ""
echo "=============================="
echo "Building LLDB for darwin-${MACOS_ARCH}"
echo "=============================="
echo ""

set -ex

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# We assume cmake and ninja are in PATH on the macOS runner
CMAKE="cmake"
NINJA="ninja"

CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"

BUILD_DIR="${SCRIPT_DIR}/build-macos-${MACOS_ARCH}"
OUT_DIR="${BUILD_DIR}/out"
INSTALL_DIR="${BUILD_DIR}/install"
mkdir -p "${BUILD_DIR}"
mkdir -p "${OUT_DIR}"
mkdir -p "${INSTALL_DIR}"

XZ_DIR="${BUILD_DIR}/xz"
XZ_SRC_DIR="${SCRIPT_DIR}/xz"
if [[ ! -d "${XZ_DIR}/lib" ]]; then
  echo "Building static xz from submodule for macOS..."
  mkdir -p "${BUILD_DIR}/xz-build"
  pushd "${BUILD_DIR}/xz-build"

  $CMAKE "${XZ_SRC_DIR}" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${XZ_DIR}" \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_OSX_ARCHITECTURES="${MACOS_ARCH}"

  $NINJA install
  popd
  rm -rf "${BUILD_DIR}/xz-build"
fi

pushd "${BUILD_DIR}"
$CMAKE ../llvm-project/llvm -G Ninja \
  -B "${OUT_DIR}" \
  -DCMAKE_MAKE_PROGRAM="${NINJA}" \
  -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON \
  -DLLVM_ENABLE_PROJECTS="clang;lldb" \
  -DLLDB_ENABLE_PYTHON=ON \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLDB_ENABLE_LIBXML2=OFF \
  -DLLDB_INCLUDE_TESTS=OFF \
  -DLLDB_ENABLE_LZMA=ON \
  -DLIBLZMA_INCLUDE_DIR="${XZ_DIR}/include" \
  -DLIBLZMA_LIBRARY="${XZ_DIR}/lib/liblzma.a" \
  -DLIBLZMA_INCLUDE_DIRS="${XZ_DIR}/include" \
  -DLIBLZMA_LIBRARIES="${XZ_DIR}/lib/liblzma.a" \
  -DLLVM_TARGETS_TO_BUILD="X86;AArch64;ARM;RISCV" \
  -DCMAKE_OSX_ARCHITECTURES="${MACOS_ARCH}" \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"

pushd "${OUT_DIR}"
echo "Building and installing specific host tools"
time "${NINJA}" install-lldb-stripped install-lldb-dap-stripped install-lldb-mcp-stripped install-liblldb-stripped

popd
popd

echo ""
echo "=============================="
echo ""
