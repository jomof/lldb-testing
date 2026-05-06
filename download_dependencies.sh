#!/bin/bash

set -ex

echo ""
echo "=============================="
echo "Downloading dependencies..."
echo "=============================="
echo ""


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

CMAKE_DIR="${SCRIPT_DIR}/cmake/3.22.1"
if [[ ! -d "${CMAKE_DIR}" ]]; then
  wget --progress=dot:giga https://dl.google.com/android/repository/cmake-3.22.1-linux.zip
  mkdir -p "${CMAKE_DIR}"
  unzip -q cmake-3.22.1-linux.zip -d "${CMAKE_DIR}"
  rm cmake-3.22.1-linux.zip
fi

NDK_DIR=ndk
if [[ ! -d "${NDK_DIR}" ]]; then
  wget --progress=dot:giga https://dl.google.com/android/repository/android-ndk-r28c-linux.zip
  mkdir -p "${NDK_DIR}"
  unzip -q android-ndk-r28c-linux.zip -d "${NDK_DIR}"
  rm android-ndk-r28c-linux.zip
fi

JDK_DIR=jdk
if [[ ! -d "${JDK_DIR}" ]]; then
  # Download and extract
  curl -L "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse?project=jdk" -o jdk.tar.gz
  mkdir -p ${JDK_DIR}
  tar -xzf jdk.tar.gz -C ${JDK_DIR} --strip-components=1
  rm jdk.tar.gz
fi

PREBUILTS_DIR="${SCRIPT_DIR}/prebuilts"
mkdir -p "${PREBUILTS_DIR}"

# 1. Download GCC glibc 2.17 sysroot & toolchain
if [[ ! -d "${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8" ]]; then
  echo "Cloning GCC glibc 2.17 sysroot..."
  git clone --depth 1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8 "${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8"
fi

# 2. Download Clang compiler prebuilt (clang-r536225) via sparse checkout
if [[ ! -d "${PREBUILTS_DIR}/clang/clang-r536225" ]]; then
  echo "Downloading Clang r536225 prebuilt..."
  mkdir -p "${PREBUILTS_DIR}/clang"
  pushd "${PREBUILTS_DIR}/clang"
  git init
  git remote add origin https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86
  git config core.sparseCheckout true
  echo "clang-r536225/*" >> .git/info/sparse-checkout
  git pull --depth 1 origin master
  popd
fi

# 3. Download and build static ncurses (ncursesw) compiled for glibc 2.17 with -fPIC
NCURSES_DIR="${PREBUILTS_DIR}/ncurses"
if [[ ! -d "${NCURSES_DIR}/lib" ]]; then
  echo "Downloading and building static ncursesw..."
  wget --progress=dot:giga https://ftp.gnu.org/pub/gnu/ncurses/ncurses-6.4.tar.gz
  tar -xzf ncurses-6.4.tar.gz
  pushd ncurses-6.4

  # Configure with our glibc 2.17 sysroot & prebuilt clang compiler
  CC="${PREBUILTS_DIR}/clang/clang-r536225/bin/clang" \
  CXX="${PREBUILTS_DIR}/clang/clang-r536225/bin/clang++" \
  CFLAGS="--target=x86_64-linux -fPIC --sysroot=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8/sysroot --gcc-toolchain=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8" \
  CXXFLAGS="--target=x86_64-linux -fPIC --sysroot=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8/sysroot --gcc-toolchain=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8 -stdlib=libc++" \
  LDFLAGS="--target=x86_64-linux -fPIC --sysroot=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8/sysroot --gcc-toolchain=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8 -stdlib=libc++ -L${PREBUILTS_DIR}/clang/clang-r536225/lib" \
  ./configure --host=x86_64-linux --prefix="${NCURSES_DIR}" \
    --enable-static --disable-shared --with-shared=no --with-normal=yes \
    --without-progs --without-tests --with-termlib --enable-widec --with-ticlib

  make -j$(nproc)
  make install
  popd
  rm -rf ncurses-6.4.tar.gz ncurses-6.4
fi

# 4. Download and build static libedit compiled for glibc 2.17 with -fPIC
LIBEDIT_DIR="${PREBUILTS_DIR}/libedit"
if [[ ! -d "${LIBEDIT_DIR}/lib" ]]; then
  echo "Downloading and building static libedit..."
  wget --progress=dot:giga https://sources.buildroot.net/libedit/libedit-20221030-3.1.tar.gz
  tar -xzf libedit-20221030-3.1.tar.gz
  pushd libedit-20221030-3.1

  # Configure pointing to our compiled ncurses library for termcap symbols
  CC="${PREBUILTS_DIR}/clang/clang-r536225/bin/clang" \
  CXX="${PREBUILTS_DIR}/clang/clang-r536225/bin/clang++" \
  CFLAGS="--target=x86_64-linux -fPIC --sysroot=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8/sysroot --gcc-toolchain=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8 -I${NCURSES_DIR}/include -I${NCURSES_DIR}/include/ncursesw" \
  CXXFLAGS="--target=x86_64-linux -fPIC --sysroot=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8/sysroot --gcc-toolchain=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8 -stdlib=libc++ -I${NCURSES_DIR}/include -I${NCURSES_DIR}/include/ncursesw" \
  LDFLAGS="--target=x86_64-linux -fPIC --sysroot=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8/sysroot --gcc-toolchain=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8 -stdlib=libc++ -L${PREBUILTS_DIR}/clang/clang-r536225/lib -L${NCURSES_DIR}/lib" \
  ./configure --host=x86_64-linux --prefix="${LIBEDIT_DIR}" --enable-static --disable-shared

  make -j$(nproc)
  make install
  popd
  rm -rf libedit-20221030-3.1.tar.gz libedit-20221030-3.1
fi


