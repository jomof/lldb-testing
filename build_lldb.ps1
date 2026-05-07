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

# Run CMake
# Python 3.11 is set up by the GitHub Action and is in PATH
& $CMake ../llvm-project/llvm -G Ninja `
  -B $OutDir `
  -DCMAKE_MAKE_PROGRAM="ninja" `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON `
  -DLLVM_ENABLE_PROJECTS="clang;lldb" `
  -DLLDB_ENABLE_PYTHON=ON `
  -DLLDB_ENABLE_LIBEDIT=OFF `
  -DLLDB_ENABLE_CURSES=OFF `
  -DLLVM_ENABLE_LIBXML2=OFF `
  -DLLDB_ENABLE_LIBXML2=OFF `
  -DLLVM_TARGETS_TO_BUILD="X86;AArch64;ARM;RISCV" `
  -DCMAKE_INSTALL_PREFIX=$InstallDir

Push-Location $OutDir

Write-Host "Building and installing specific host tools"
& $Ninja install-lldb-stripped install-lldb-dap-stripped install-lldb-mcp-stripped install-liblldb-stripped

Pop-Location
Pop-Location

Write-Host ""
Write-Host "=============================="
Write-Host ""
