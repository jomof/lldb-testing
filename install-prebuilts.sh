export REMOTE_ROOT=https://github.com/jomof/lldb-testing/releases/download/build-10f9417/
STUDIO_PREBUILTS_DIR="$HOME/projects/studio-main/prebuilts/tools"

rm -rf download/*
mkdir -p download
cd download

wget $REMOTE_ROOT/llvm-linux-x86_64.zip
wget $REMOTE_ROOT/llvm-windows-x86_64.zip
wget $REMOTE_ROOT/llvm-darwin-arm64.zip

mkdir -p "$STUDIO_PREBUILTS_DIR/linux-x86_64/lldb-extras"
unzip -q -o llvm-linux-x86_64.zip -d "$STUDIO_PREBUILTS_DIR/linux-x86_64/lldb-extras"

mkdir -p "$STUDIO_PREBUILTS_DIR/darwin-arm64/lldb-extras"
unzip -q -o llvm-darwin-arm64.zip -d "$STUDIO_PREBUILTS_DIR/darwin-arm64/lldb-extras"

mkdir -p "$STUDIO_PREBUILTS_DIR/windows-x86_64/lldb-extras"
unzip -q -o llvm-windows-x86_64.zip -d "$STUDIO_PREBUILTS_DIR/windows-x86_64/lldb-extras"

rm llvm-linux-x86_64.zip
rm llvm-windows-x86_64.zip
rm llvm-darwin-arm64.zip





