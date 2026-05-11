$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=============================="
Write-Host "Building LLDB for windows-x86_64"
Write-Host "=============================="
Write-Host ""

$ScriptDir = $PSScriptRoot

$BuildDir = Join-Path $ScriptDir "build-windows-x86_64"
$OutDir = Join-Path $BuildDir "out"
$InstallDir = Join-Path $BuildDir "install"

if (!(Test-Path $BuildDir)) { New-Item -ItemType Directory -Path $BuildDir }
if (!(Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir }
if (!(Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir }

# We assume cmake and ninja are in PATH on the Windows runner
$CMake = "cmake"
$Ninja = "ninja"

Push-Location $BuildDir

$XzDir = Join-Path $BuildDir "xz"
$XzSrcDir = Join-Path $ScriptDir "xz"
if (!(Test-Path $XzDir)) {
  Write-Host "Building static xz from submodule..."
  
  $XzBuildDir = Join-Path $BuildDir "xz-build"
  $XzInstallDir = $XzDir
  
  New-Item -ItemType Directory -Path $XzBuildDir -Force
  
  Push-Location $XzBuildDir
  & $CMake $XzSrcDir -G "NMake Makefiles" `
    -B $XzBuildDir `
    -DCMAKE_BUILD_TYPE=Release `
    -DCMAKE_INSTALL_PREFIX=$XzInstallDir `
    -DBUILD_SHARED_LIBS=OFF
  
  nmake install
  Pop-Location
  
  # Cleanup
  Remove-Item -Recurse -Force $XzBuildDir
}

# Run CMake
# Python 3.11 is set up by the GitHub Action and is in PATH
& $CMake ../llvm-project/llvm -G Ninja `
  -B $OutDir `
  -DCMAKE_MAKE_PROGRAM="ninja" `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_C_COMPILER_LAUNCHER=ccache `
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache `
  -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON `
  -DLLVM_ENABLE_PROJECTS="clang;lldb" `
  -DLLDB_ENABLE_PYTHON=ON `
  -DLLDB_ENABLE_LIBEDIT=OFF `
  -DLLDB_ENABLE_CURSES=OFF `
  -DLLVM_ENABLE_LIBXML2=OFF `
  -DLLDB_ENABLE_LIBXML2=OFF `
  -DLLDB_INCLUDE_TESTS=OFF `
  -DLLVM_TARGETS_TO_BUILD="X86;AArch64;ARM;RISCV" `
  -DLLDB_ENABLE_LZMA=ON `
  -DLIBLZMA_INCLUDE_DIR="$XzDir/include" `
  -DLIBLZMA_LIBRARY="$XzDir/lib/liblzma.lib" `
  -DCMAKE_INSTALL_PREFIX="$InstallDir"

Push-Location $OutDir

Write-Host "Building and installing specific host tools"
& $Ninja install-lldb install-lldb-dap install-lldb-mcp install-liblldb
if ($LASTEXITCODE -ne 0) { throw "Ninja failed with exit code $LASTEXITCODE" }

Pop-Location
Pop-Location

Write-Host ""
Write-Host "=============================="
Write-Host ""
