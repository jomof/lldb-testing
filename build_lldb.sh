#!/bin/bash

echo ""
echo "=============================="
echo "Building LLDB for linux-x86_64"
echo "=============================="
echo ""

set -ex

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

PREBUILTS_DIR="${SCRIPT_DIR}/prebuilts"

CMAKE="${PREBUILTS_DIR}/cmake/3.22.1/bin/cmake"
NINJA="${PREBUILTS_DIR}/cmake/3.22.1/bin/ninja"
ANDROID_NDK_HOME="${PREBUILTS_DIR}/ndk/android-ndk-r28c"
PYTHON_DIR="${SCRIPT_DIR}/python3.11"

CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"

BUILD_DIR="${SCRIPT_DIR}/build-linux-x86_64"
OUT_DIR="${BUILD_DIR}/out"
INSTALL_DIR="${BUILD_DIR}/install"
mkdir -p "${BUILD_DIR}"
mkdir -p "${OUT_DIR}"
mkdir -p "${INSTALL_DIR}"

# Note: Python requires swig. We assume it's installed on the local machine.

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
  -DPython3_LIBRARIES="${PYTHON_DIR}/lib/libpython3.11.so" \
  -DPython3_INCLUDE_DIRS="${PYTHON_DIR}/include/python3.11" \
  -DPython3_EXECUTABLE="${PYTHON_DIR}/bin/python3" \
  -DLLDB_ENABLE_LIBEDIT=ON \
  -DLibEdit_INCLUDE_DIRS="${PREBUILTS_DIR}/libedit/include" \
  -DLibEdit_LIBRARIES="${PREBUILTS_DIR}/libedit/lib/libedit.a" \
  -DLLDB_ENABLE_CURSES=ON \
  -DCURSES_INCLUDE_DIRS="${PREBUILTS_DIR}/ncurses/include;${PREBUILTS_DIR}/ncurses/include/ncursesw" \
  -DCURSES_LIBRARIES="${PREBUILTS_DIR}/ncurses/lib/libncursesw.a" \
  -DPANEL_LIBRARIES="${PREBUILTS_DIR}/ncurses/lib/libpanelw.a" \
  -DLLDB_ENABLE_LZMA=ON \
  -DLIBLZMA_INCLUDE_DIR="${PREBUILTS_DIR}/xz/include" \
  -DLIBLZMA_LIBRARY="${PREBUILTS_DIR}/xz/lib/liblzma.a" \
  -DLIBLZMA_INCLUDE_DIRS="${PREBUILTS_DIR}/xz/include" \
  -DLIBLZMA_LIBRARIES="${PREBUILTS_DIR}/xz/lib/liblzma.a" \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLDB_ENABLE_LIBXML2=OFF \
  -DLLDB_INCLUDE_TESTS=OFF \
  -DLLVM_TARGETS_TO_BUILD="X86;AArch64;ARM;RISCV" \
  -DLLVM_HOST_TRIPLE="x86_64-unknown-linux-gnu" \
  -DCMAKE_SYSROOT="${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8/sysroot" \
  -DCMAKE_C_COMPILER="${PREBUILTS_DIR}/clang/clang-r536225/bin/clang" \
  -DCMAKE_CXX_COMPILER="${PREBUILTS_DIR}/clang/clang-r536225/bin/clang++" \
  -DLLVM_ENABLE_LIBCXX=ON \
  -DLLVM_STATIC_LINK_CXX_STDLIB=ON \
  -DCMAKE_C_FLAGS="--target=x86_64-linux --gcc-toolchain=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8" \
  -DCMAKE_CXX_FLAGS="--target=x86_64-linux --gcc-toolchain=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8 -stdlib=libc++" \
  -DCMAKE_EXE_LINKER_FLAGS="--target=x86_64-linux --gcc-toolchain=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8 -stdlib=libc++ -L${PREBUILTS_DIR}/clang/clang-r536225/lib ${PREBUILTS_DIR}/ncurses/lib/libtinfow.a" \
  -DCMAKE_SHARED_LINKER_FLAGS="--target=x86_64-linux --gcc-toolchain=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8 -stdlib=libc++ -L${PREBUILTS_DIR}/clang/clang-r536225/lib ${PREBUILTS_DIR}/ncurses/lib/libtinfow.a" \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"

pushd "${OUT_DIR}"
echo "Building and installing specific host tools"
time "${NINJA}" install-lldb-stripped install-lldb-dap-stripped install-lldb-mcp-stripped install-liblldb-stripped

echo ""
echo "=============================="
echo ""
