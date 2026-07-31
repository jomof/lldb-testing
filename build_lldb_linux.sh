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
PYTHON_DIR="${SCRIPT_DIR}/python3.11"

CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"

BUILD_DIR="${SCRIPT_DIR}/build-linux-x86_64"
OUT_DIR="${BUILD_DIR}/out"
INSTALL_DIR="${BUILD_DIR}/install"
mkdir -p "${BUILD_DIR}"
mkdir -p "${OUT_DIR}"
mkdir -p "${INSTALL_DIR}"

# Note: Python requires swig. We assume it's installed on the local machine.

# Build static xz from submodule compiled for glibc 2.17 with -fPIC
XZ_DIR="${PREBUILTS_DIR}/xz"
XZ_SRC_DIR="${SCRIPT_DIR}/xz"
LIBXML2_DIR="${PREBUILTS_DIR}/libxml2"
if [[ ! -d "${XZ_DIR}/lib" ]]; then
  echo "Building static xz from submodule..."
  mkdir -p xz-build
  pushd xz-build

  CC="${PREBUILTS_DIR}/clang/clang-r536225/bin/clang" \
  CXX="${PREBUILTS_DIR}/clang/clang-r536225/bin/clang++" \
  CFLAGS="--target=x86_64-linux -fPIC --sysroot=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8/sysroot --gcc-toolchain=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8" \
  CXXFLAGS="--target=x86_64-linux -fPIC --sysroot=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8/sysroot --gcc-toolchain=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8 -stdlib=libc++" \
  LDFLAGS="--target=x86_64-linux -fPIC --sysroot=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8/sysroot --gcc-toolchain=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8 -stdlib=libc++ -L${PREBUILTS_DIR}/clang/clang-r536225/lib" \
  "${CMAKE}" "${XZ_SRC_DIR}" -G "Unix Makefiles" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${XZ_DIR}" \
    -DBUILD_SHARED_LIBS=OFF

  make install
  popd
  rm -rf xz-build
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
  -DLLDB_ENABLE_LUA=OFF \
  -DLLDB_ENABLE_TREESITTER=OFF \
  -DPython3_LIBRARIES="${PYTHON_DIR}/lib/libpython3.11.so" \
  -DPython3_INCLUDE_DIRS="${PYTHON_DIR}/include/python3.11" \
  -DPython3_EXECUTABLE="${PYTHON_DIR}/bin/python3" \
  -DLLDB_EMBED_PYTHON_HOME=ON \
  -DLLDB_PYTHON_HOME=.. \
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
  -DLLVM_ENABLE_LIBXML2=ON \
  -DLLDB_ENABLE_LIBXML2=ON \
  -DLIBXML2_INCLUDE_DIR="${LIBXML2_DIR}/include/libxml2" \
  -DLIBXML2_LIBRARY="${LIBXML2_DIR}/lib/libxml2.a" \
  -DLIBXML2_LIBRARIES="${LIBXML2_DIR}/lib/libxml2.a" \
  -DLLVM_ENABLE_ZSTD=OFF \
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
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DLLDB_PYTHON_RELATIVE_PATH="lib/python3.11/site-packages"

pushd "${OUT_DIR}"
echo "Building and installing specific host tools"
time "${NINJA}" install-lldb-stripped install-lldb-dap-stripped install-lldb-mcp-stripped install-lldb-server-stripped install-liblldb-stripped install-lldb-python-scripts

popd
popd

# Bundle Python runtime into the install directory so the package is self-contained.
# This allows lldb-dap and lldb to use Python scripting without requiring a system Python.
echo "Bundling Python runtime..."
cp "${PYTHON_DIR}/lib/libpython3.11.so.1.0" "${INSTALL_DIR}/lib/"
ln -sf libpython3.11.so.1.0 "${INSTALL_DIR}/lib/libpython3.11.so"
cp -r "${PYTHON_DIR}/lib/python3.11" "${INSTALL_DIR}/lib/python3.11.bundled"
# Merge: copy stdlib into the install python3.11 dir without overwriting the lldb module
cp -rn "${INSTALL_DIR}/lib/python3.11.bundled/"* "${INSTALL_DIR}/lib/python3.11/" 2>/dev/null || true
rm -rf "${INSTALL_DIR}/lib/python3.11.bundled"
cp "${PYTHON_DIR}/bin/python3" "${INSTALL_DIR}/bin/python3"
ln -sf python3 "${INSTALL_DIR}/bin/python3.11"

VERSION_OUTPUT=$("${INSTALL_DIR}/bin/lldb" -b -o "version --verbose")
echo "${VERSION_OUTPUT}"
grep -q "xml: yes" <<<"${VERSION_OUTPUT}"
echo "Python runtime bundled successfully."

echo ""
echo "=============================="
echo ""
