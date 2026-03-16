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

