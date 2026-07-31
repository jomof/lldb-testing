#!/bin/bash

set -ex

echo ""
echo "=============================="
echo "Downloading dependencies..."
echo "=============================="
echo ""


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

PREBUILTS_DIR="${SCRIPT_DIR}/prebuilts"
mkdir -p "${PREBUILTS_DIR}"
pushd "${PREBUILTS_DIR}"

CMAKE_DIR="${PREBUILTS_DIR}/cmake/3.22.1"
if [[ ! -d "${CMAKE_DIR}" ]]; then
  wget --progress=dot:giga https://dl.google.com/android/repository/cmake-3.22.1-linux.zip
  mkdir -p "${CMAKE_DIR}"
  unzip -q cmake-3.22.1-linux.zip -d "${CMAKE_DIR}"
  rm cmake-3.22.1-linux.zip
fi

NDK_DIR="${PREBUILTS_DIR}/ndk"
if [[ ! -d "${NDK_DIR}" ]]; then
  wget --progress=dot:giga https://dl.google.com/android/repository/android-ndk-r28c-linux.zip
  mkdir -p "${NDK_DIR}"
  unzip -q android-ndk-r28c-linux.zip -d "${NDK_DIR}"
  rm android-ndk-r28c-linux.zip
fi

JDK_DIR="${PREBUILTS_DIR}/jdk"
if [[ ! -d "${JDK_DIR}" ]]; then
  # Download and extract
  curl -L "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse?project=jdk" -o jdk.tar.gz
  mkdir -p "${JDK_DIR}"
  tar -xzf jdk.tar.gz -C "${JDK_DIR}" --strip-components=1
  rm jdk.tar.gz
fi

# 1. Download GCC glibc 2.17 sysroot & toolchain
if [[ ! -d "${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8" ]]; then
  echo "Cloning GCC glibc 2.17 sysroot..."
  git clone --depth 1 https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8 "${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8"
  rm -rf "${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8/.git"
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
  rm -rf "${PREBUILTS_DIR}/clang/.git"
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

  make -j"$(nproc)"
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

  make -j"$(nproc)"
  make install
  popd
  rm -rf libedit-20221030-3.1.tar.gz libedit-20221030-3.1
fi

# Build a pinned static libxml2 for the glibc 2.17 host package. Using the
# runner's copy would make dependency availability and glibc compatibility
# depend on the current GitHub runner image.
LIBXML2_VERSION="2.9.12"
LIBXML2_SHA256="98bfa7a9a5e2a75638422050740448ee9f02bf4dc2075c9822d7747d5ff9e617"
LIBXML2_DIR="${PREBUILTS_DIR}/libxml2"
if [[ ! -f "${LIBXML2_DIR}/lib/libxml2.a" ]]; then
  echo "Downloading and building static libxml2..."
  LIBXML2_ARCHIVE="libxml2-v${LIBXML2_VERSION}.tar.gz"
  wget --progress=dot:giga \
    "https://gitlab.gnome.org/GNOME/libxml2/-/archive/v${LIBXML2_VERSION}/${LIBXML2_ARCHIVE}"
  echo "${LIBXML2_SHA256}  ${LIBXML2_ARCHIVE}" | sha256sum --check
  tar -xzf "${LIBXML2_ARCHIVE}"

  LIBXML2_BUILD_DIR="${PREBUILTS_DIR}/libxml2-build"
  "${CMAKE_DIR}/bin/cmake" "libxml2-v${LIBXML2_VERSION}" \
    -G "Unix Makefiles" \
    -B "${LIBXML2_BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="${LIBXML2_DIR}" \
    -DCMAKE_C_COMPILER="${PREBUILTS_DIR}/clang/clang-r536225/bin/clang" \
    -DCMAKE_C_FLAGS="--target=x86_64-linux -fPIC --sysroot=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8/sysroot --gcc-toolchain=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8" \
    -DCMAKE_EXE_LINKER_FLAGS="--target=x86_64-linux --sysroot=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8/sysroot --gcc-toolchain=${PREBUILTS_DIR}/gcc/x86_64-linux-glibc2.17-4.8" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DLIBXML2_WITH_C14N=OFF \
    -DLIBXML2_WITH_CATALOG=OFF \
    -DLIBXML2_WITH_DEBUG=OFF \
    -DLIBXML2_WITH_DOCB=OFF \
    -DLIBXML2_WITH_FTP=OFF \
    -DLIBXML2_WITH_HTML=OFF \
    -DLIBXML2_WITH_HTTP=OFF \
    -DLIBXML2_WITH_ICONV=OFF \
    -DLIBXML2_WITH_ICU=OFF \
    -DLIBXML2_WITH_ISO8859X=OFF \
    -DLIBXML2_WITH_LEGACY=OFF \
    -DLIBXML2_WITH_LZMA=OFF \
    -DLIBXML2_WITH_MODULES=OFF \
    -DLIBXML2_WITH_OUTPUT=ON \
    -DLIBXML2_WITH_PATTERN=OFF \
    -DLIBXML2_WITH_PROGRAMS=OFF \
    -DLIBXML2_WITH_PUSH=OFF \
    -DLIBXML2_WITH_PYTHON=OFF \
    -DLIBXML2_WITH_READER=OFF \
    -DLIBXML2_WITH_REGEXPS=OFF \
    -DLIBXML2_WITH_SAX1=ON \
    -DLIBXML2_WITH_SCHEMAS=OFF \
    -DLIBXML2_WITH_SCHEMATRON=OFF \
    -DLIBXML2_WITH_TESTS=OFF \
    -DLIBXML2_WITH_THREADS=ON \
    -DLIBXML2_WITH_TREE=ON \
    -DLIBXML2_WITH_VALID=OFF \
    -DLIBXML2_WITH_WRITER=OFF \
    -DLIBXML2_WITH_XINCLUDE=OFF \
    -DLIBXML2_WITH_XPATH=OFF \
    -DLIBXML2_WITH_XPTR=OFF \
    -DLIBXML2_WITH_ZLIB=OFF

  make -C "${LIBXML2_BUILD_DIR}" -j"$(nproc)" install
  rm -rf "${LIBXML2_BUILD_DIR}" "libxml2-v${LIBXML2_VERSION}" \
    "${LIBXML2_ARCHIVE}"
fi

popd
