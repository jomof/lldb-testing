#!/bin/bash

ANDROID_ABI=${ANDROID_ABI:-arm64-v8a}

echo ""
echo "=============================="
echo "Building lldb-server for ${ANDROID_ABI}"
echo "=============================="
echo ""

set -x

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Cross compiling
PREBUILTS_DIR="${SCRIPT_DIR}/prebuilts"

CMAKE="${PREBUILTS_DIR}/cmake/3.22.1/bin/cmake"
NINJA="${PREBUILTS_DIR}/cmake/3.22.1/bin/ninja"
ANDROID_NDK_HOME="${PREBUILTS_DIR}/ndk/android-ndk-r28c"

ANDROID_PLATFORM=android-24

if [[ "$ANDROID_ABI" == "arm64-v8a" ]]; then
  LLVM_HOST_TRIPLE=aarch64-unknown-linux-android
elif [[ "$ANDROID_ABI" == "armeabi-v7a" ]]; then
  LLVM_HOST_TRIPLE=arm-unknown-linux-androideabi
elif [[ "$ANDROID_ABI" == "x86_64" ]]; then
  LLVM_HOST_TRIPLE=x86_64-unknown-linux-android
else
  echo "Invalid ANDROID_ABI=$ANDROID_ABI"
  exit 1
fi


CMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}"

BUILD_DIR="${SCRIPT_DIR}/build-${ANDROID_ABI}"
OUT_DIR="${BUILD_DIR}/out"
mkdir -p "${BUILD_DIR}"
mkdir -p "${OUT_DIR}"

pushd "${BUILD_DIR}"
$CMAKE ../llvm-project/llvm -G Ninja \
  -B "${OUT_DIR}" \
  -DCMAKE_MAKE_PROGRAM="${NINJA}" \
  -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE}" \
  -DLLVM_ENABLE_PROJECTS="clang;lldb" \
  -DLLDB_ENABLE_PYTHON=0 \
  -DLLDB_ENABLE_LIBEDIT=0 \
  -DLLDB_ENABLE_CURSES=0 \
  -DCMAKE_TOOLCHAIN_FILE="${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI="${ANDROID_ABI}" \
  -DANDROID_PLATFORM="${ANDROID_PLATFORM}" \
  -DANDROID_ALLOW_UNDEFINED_SYMBOLS=On \
  -DLLVM_HOST_TRIPLE="${LLVM_HOST_TRIPLE}" \
  -DCROSS_TOOLCHAIN_FLAGS_NATIVE='-DCMAKE_C_COMPILER=cc;-DCMAKE_CXX_COMPILER=c++'

pushd "${OUT_DIR}"
time "${NINJA}" lldb-server

echo "Stripping lldb-server binary to reduce size"
"${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" bin/lldb-server

echo ""
echo "=============================="
echo ""
