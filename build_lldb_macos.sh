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

  $CMAKE "${XZ_SRC_DIR}" -G "Unix Makefiles" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${XZ_DIR}" \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_OSX_ARCHITECTURES="${MACOS_ARCH}"

  make install
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
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DLLDB_PYTHON_RELATIVE_PATH="lib/python$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')/site-packages"

pushd "${OUT_DIR}"
echo "Building and installing specific host tools"
time "${NINJA}" install-lldb-stripped install-lldb-dap-stripped install-lldb-mcp-stripped install-lldb-server-stripped install-liblldb-stripped install-lldb-python-scripts

popd
popd

# Bundle Python runtime into the install directory so the package is self-contained.
echo "Bundling Python runtime..."
PYTHON_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PYTHON_PREFIX=$(python3 -c "import sys; print(sys.prefix)")
PYTHON_STDLIB=$(python3 -c "import sysconfig; print(sysconfig.get_path('stdlib'))")
PYTHON_PLATSTDLIB=$(python3 -c "import sysconfig; print(sysconfig.get_path('platstdlib'))")

# Copy Python shared library
mkdir -p "${INSTALL_DIR}/lib"
PYTHON_LIBDIR=$(python3 -c "import sysconfig; print(sysconfig.get_config_var('LIBDIR'))")
for f in "${PYTHON_LIBDIR}"/libpython${PYTHON_VER}*.dylib; do
  if [ -f "$f" ]; then
    cp -L "$f" "${INSTALL_DIR}/lib/"
  fi
done

# Copy Python stdlib
mkdir -p "${INSTALL_DIR}/lib/python${PYTHON_VER}"
cp -rn "${PYTHON_STDLIB}/"* "${INSTALL_DIR}/lib/python${PYTHON_VER}/" 2>/dev/null || true
# Copy lib-dynload (platform-specific .so modules)
if [ -d "${PYTHON_PLATSTDLIB}/lib-dynload" ]; then
  cp -rn "${PYTHON_PLATSTDLIB}/lib-dynload" "${INSTALL_DIR}/lib/python${PYTHON_VER}/" 2>/dev/null || true
fi

# Copy Python binary
cp -L "$(which python3)" "${INSTALL_DIR}/bin/python3"
ln -sf python3 "${INSTALL_DIR}/bin/python${PYTHON_VER}"
echo "Python runtime bundled successfully."

# Fix library paths so the package is relocatable.
# liblldb.dylib links against the absolute build-time Python path (e.g.
# /opt/homebrew/.../Python.framework/.../Python). Rewrite it to use
# @loader_path so it finds our bundled libpython instead.
echo "Fixing library install names..."
PYTHON_LIBNAME="libpython${PYTHON_VER}.dylib"
OLD_PYTHON_PATH=$(otool -L "${INSTALL_DIR}/lib/liblldb.dylib" | grep -i python | awk '{print $1}')
if [ -n "${OLD_PYTHON_PATH}" ]; then
  install_name_tool -change "${OLD_PYTHON_PATH}" "@loader_path/${PYTHON_LIBNAME}" "${INSTALL_DIR}/lib/liblldb.dylib"
fi
install_name_tool -id "@loader_path/${PYTHON_LIBNAME}" "${INSTALL_DIR}/lib/${PYTHON_LIBNAME}"

# Re-codesign everything. macOS kills binaries with invalid signatures,
# and install_name_tool / strip both invalidate them.
echo "Re-signing binaries..."
codesign --force --sign - "${INSTALL_DIR}"/bin/lldb "${INSTALL_DIR}"/bin/lldb-dap "${INSTALL_DIR}"/bin/lldb-mcp "${INSTALL_DIR}"/bin/lldb-server "${INSTALL_DIR}"/bin/python3
codesign --force --sign - "${INSTALL_DIR}"/lib/liblldb*.dylib "${INSTALL_DIR}"/lib/${PYTHON_LIBNAME}
echo "Done."

echo ""
echo "=============================="
echo ""
