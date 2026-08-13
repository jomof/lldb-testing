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
PYTHON_EXECUTABLE="$(command -v python3)"
PYTHON_PREFIX="$("${PYTHON_EXECUTABLE}" -c 'import sys; print(sys.prefix)')"
PYTHON_LIBDIR="$("${PYTHON_EXECUTABLE}" -c 'import sysconfig; print(sysconfig.get_config_var("LIBDIR"))')"
MACOS_SDK="$(xcrun --show-sdk-path)"
LIBXML2_INCLUDE_DIR="${MACOS_SDK}/usr/include/libxml2"
LIBXML2_LIBRARY="${MACOS_SDK}/usr/lib/libxml2.tbd"

CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"

BUILD_DIR="${SCRIPT_DIR}/build-macos-${MACOS_ARCH}"
OUT_DIR="${BUILD_DIR}/out"
INSTALL_DIR="${BUILD_DIR}/install"
mkdir -p "${BUILD_DIR}"
mkdir -p "${OUT_DIR}"
rm -rf "${INSTALL_DIR}"
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

ZSTD_VERSION="1.5.7"
ZSTD_SHA256="eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3"
ZSTD_DIR="${BUILD_DIR}/zstd"
if [[ ! -d "${ZSTD_DIR}/lib" ]]; then
  echo "Building static zstd for macOS..."
  mkdir -p "${BUILD_DIR}/zstd-build"
  ZSTD_ARCHIVE="${BUILD_DIR}/zstd-${ZSTD_VERSION}.tar.gz"
  curl -sSL "https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz" -o "${ZSTD_ARCHIVE}"
  if command -v shasum >/dev/null 2>&1; then
    echo "${ZSTD_SHA256}  ${ZSTD_ARCHIVE}" | shasum -a 256 --check
  else
    echo "${ZSTD_SHA256}  ${ZSTD_ARCHIVE}" | sha256sum --check
  fi
  tar -xzf "${ZSTD_ARCHIVE}" -C "${BUILD_DIR}"

  $CMAKE "${BUILD_DIR}/zstd-${ZSTD_VERSION}/build/cmake" -G "Unix Makefiles" \
    -B "${BUILD_DIR}/zstd-build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${ZSTD_DIR}" \
    -DZSTD_BUILD_SHARED=OFF \
    -DZSTD_BUILD_STATIC=ON \
    -DZSTD_BUILD_PROGRAMS=OFF \
    -DZSTD_BUILD_TESTS=OFF \
    -DCMAKE_OSX_ARCHITECTURES="${MACOS_ARCH}"

  make -C "${BUILD_DIR}/zstd-build" install
  rm -rf "${BUILD_DIR}/zstd-build" "${BUILD_DIR}/zstd-${ZSTD_VERSION}" "${ZSTD_ARCHIVE}"
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
  -DPython3_EXECUTABLE="${PYTHON_EXECUTABLE}" \
  -DPython3_ROOT_DIR="${PYTHON_PREFIX}" \
  -DPython3_FIND_FRAMEWORK=LAST \
  -DLLDB_EMBED_PYTHON_HOME=OFF \
  -DLLVM_ENABLE_LIBXML2=ON \
  -DLLDB_ENABLE_LIBXML2=ON \
  -DLIBXML2_INCLUDE_DIR="${LIBXML2_INCLUDE_DIR}" \
  -DLIBXML2_LIBRARY="${LIBXML2_LIBRARY}" \
  -DLIBXML2_LIBRARIES="${LIBXML2_LIBRARY}" \
  -DLLVM_ENABLE_ZSTD=ON \
  -DLLVM_USE_STATIC_ZSTD=ON \
  -Dzstd_INCLUDE_DIR="${ZSTD_DIR}/include" \
  -Dzstd_LIBRARY="${ZSTD_DIR}/lib/libzstd.a" \
  -Dzstd_STATIC_LIBRARY="${ZSTD_DIR}/lib/libzstd.a" \
  -DLLDB_INCLUDE_TESTS=OFF \
  -DLLDB_ENABLE_LZMA=ON \
  -DLIBLZMA_INCLUDE_DIR="${XZ_DIR}/include" \
  -DLIBLZMA_LIBRARY="${XZ_DIR}/lib/liblzma.a" \
  -DLIBLZMA_INCLUDE_DIRS="${XZ_DIR}/include" \
  -DLIBLZMA_LIBRARIES="${XZ_DIR}/lib/liblzma.a" \
  -DLLVM_TARGETS_TO_BUILD="X86;AArch64;ARM;RISCV" \
  -DCMAKE_OSX_ARCHITECTURES="${MACOS_ARCH}" \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DLLDB_PYTHON_RELATIVE_PATH="lib/python"

pushd "${OUT_DIR}"
echo "Building and installing specific host tools"
time "${NINJA}" install-lldb-stripped install-lldb-dap-stripped install-lldb-mcp-stripped install-lldb-server-stripped install-liblldb-stripped install-lldbPluginScriptInterpreterPython-stripped install-lldb-python-scripts

popd
popd

# Re-codesign everything. macOS kills binaries with invalid signatures,
# and stripping invalidates them.
echo "Re-signing binaries..."
codesign --force --sign - "${INSTALL_DIR}"/bin/lldb "${INSTALL_DIR}"/bin/lldb-dap "${INSTALL_DIR}"/bin/lldb-mcp "${INSTALL_DIR}"/bin/lldb-server
codesign --force --sign - "${INSTALL_DIR}"/lib/liblldb*.dylib

VERSION_OUTPUT=$( \
  PYTHONHOME="${PYTHON_PREFIX}" \
  DYLD_LIBRARY_PATH="${PYTHON_LIBDIR}" \
  "${INSTALL_DIR}/bin/lldb" -b \
    -o "version --verbose" \
    -o "script import lldb; print(lldb.SBDebugger.GetVersionString())" \
)
echo "${VERSION_OUTPUT}"
grep -q "xml: yes" <<<"${VERSION_OUTPUT}"
test ! -e "${INSTALL_DIR}/bin/python3"
test ! -e "${INSTALL_DIR}/lib/libpython3.11.dylib"
echo "Done."

echo ""
echo "=============================="
echo ""
