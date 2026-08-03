#!/usr/bin/env bash
#
# install-prebuilts.sh
#
# Downloads and installs LLDB host prebuilts from the jomof/lldb-testing GitHub repository
# into the studio-main prebuilts directory.
#
# Usage:
#   ./install-prebuilts.sh [TAG_NAME]
#
# If TAG_NAME is omitted, downloads directly from the latest release permalink.

set -euo pipefail

REPO="jomof/lldb-testing"
STUDIO_PREBUILTS_DIR="${STUDIO_PREBUILTS_DIR:-$HOME/projects/studio-main/prebuilts/tools}"

# 1. Determine download root: use tag if specified, otherwise use GitHub's latest release permalink
TAG_NAME="${1:-${RELEASE_TAG:-}}"
if [[ -n "${TAG_NAME}" ]]; then
  REMOTE_ROOT="https://github.com/${REPO}/releases/download/${TAG_NAME}"
  echo "Installing prebuilts for release tag: ${TAG_NAME}"
else
  REMOTE_ROOT="https://github.com/${REPO}/releases/latest/download"
  echo "Installing prebuilts from latest GitHub release permalink"
fi

echo "=========================================================="
echo "Remote URL root:            ${REMOTE_ROOT}"
echo "Target prebuilts directory: ${STUDIO_PREBUILTS_DIR}"
echo "=========================================================="

# 2. Stage downloads in a temporary directory to ensure atomic failure handling
TMP_DL_DIR=$(mktemp -d)
cleanup() {
  rm -rf "${TMP_DL_DIR}"
}
trap cleanup EXIT

# Mapping of platform name -> zip filename
PLATFORMS=(
  "linux-x86_64:llvm-linux-x86_64.zip"
  "darwin-arm64:llvm-darwin-arm64.zip"
  "windows-x86_64:llvm-windows-x86_64.zip"
)

# 3. Download all archives first before touching existing prebuilts
echo "--> Downloading release archives into staging directory..."
for entry in "${PLATFORMS[@]}"; do
  archive="${entry#*:}"
  url="${REMOTE_ROOT}/${archive}"
  echo "    Downloading ${archive}..."
  if command -v curl >/dev/null 2>&1; then
    curl -fSL -o "${TMP_DL_DIR}/${archive}" "${url}"
  elif command -v wget >/dev/null 2>&1; then
    wget -q --show-progress -O "${TMP_DL_DIR}/${archive}" "${url}"
  else
    echo "Error: neither curl nor wget is installed." >&2
    exit 1
  fi
done

# 4. Clean replacement: remove existing target directory before unzipping
# This ensures stale files from previous releases are deleted.
echo "--> Replacing prebuilts..."
for entry in "${PLATFORMS[@]}"; do
  platform="${entry%%:*}"
  archive="${entry#*:}"
  target_dir="${STUDIO_PREBUILTS_DIR}/${platform}/lldb-extras"

  echo "    Updating ${target_dir}..."
  rm -rf "${target_dir}"
  mkdir -p "${target_dir}"
  unzip -q "${TMP_DL_DIR}/${archive}" -d "${target_dir}"
done

echo "=========================================================="
echo "Successfully updated prebuilts in ${STUDIO_PREBUILTS_DIR}!"
echo "=========================================================="
