#!/usr/bin/env bash
#
# build-install.sh
#
# Builds LLDB host binaries for linux-x86_64 locally (matching CI in .github/workflows/build.yml),
# packages the release archive, and installs it into studio-main prebuilts using install-prebuilts.sh.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "${SCRIPT_DIR}"

echo "=========================================================="
echo "Step 1: Checking and downloading build dependencies..."
echo "=========================================================="
./download_dependencies.sh
find prebuilts/ -type f -path "*/bin/*" -exec chmod +x {} + 2>/dev/null || true

echo "=========================================================="
echo "Step 2: Building LLDB host binaries for linux-x86_64..."
echo "=========================================================="
chmod +x build_lldb_linux.sh
./build_lldb_linux.sh

echo "=========================================================="
echo "Step 3: Creating release archive llvm-linux-x86_64.zip..."
echo "=========================================================="
rm -f llvm-linux-x86_64.zip
(cd build-linux-x86_64/install && zip -r -q -y ../../llvm-linux-x86_64.zip .)

echo "=========================================================="
echo "Step 4: Installing local release archive into prebuilts..."
echo "=========================================================="
./install-prebuilts.sh --local "${SCRIPT_DIR}"

echo "=========================================================="
echo "Successfully built and installed local linux-x86_64 prebuilts!"
echo "=========================================================="
