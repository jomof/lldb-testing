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
$PythonExe = (Get-Command python).Source
$PythonPrefix = python -c "import sys; print(sys.prefix)"

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
    "-DCMAKE_INSTALL_PREFIX=$XzInstallDir" `
    -DBUILD_SHARED_LIBS=OFF
  if ($LASTEXITCODE -ne 0) { throw "CMake for XZ failed" }
  
  nmake install
  if ($LASTEXITCODE -ne 0) { throw "NMake install for XZ failed" }
  
  Pop-Location
  
  if (!(Test-Path (Join-Path $XzInstallDir "lib\liblzma.lib"))) { throw "liblzma.lib not found after install" }
  
  # Cleanup
  Remove-Item -Recurse -Force $XzBuildDir
}

$LibXmlVersion = "2.9.12"
$LibXmlSha256 = "98bfa7a9a5e2a75638422050740448ee9f02bf4dc2075c9822d7747d5ff9e617"
$LibXmlDir = Join-Path $BuildDir "libxml2"
$LibXmlLibrary = Join-Path $LibXmlDir "lib\libxml2s.lib"
if (!(Test-Path $LibXmlLibrary)) {
  Write-Host "Building pinned static libxml2..."

  $LibXmlArchive = Join-Path $BuildDir "libxml2-v$LibXmlVersion.tar.gz"
  $LibXmlSourceDir = Join-Path $BuildDir "libxml2-v$LibXmlVersion"
  $LibXmlBuildDir = Join-Path $BuildDir "libxml2-build"
  Invoke-WebRequest `
    -Uri "https://gitlab.gnome.org/GNOME/libxml2/-/archive/v$LibXmlVersion/libxml2-v$LibXmlVersion.tar.gz" `
    -OutFile $LibXmlArchive
  $ActualHash = (Get-FileHash -Algorithm SHA256 $LibXmlArchive).Hash.ToLowerInvariant()
  if ($ActualHash -ne $LibXmlSha256) {
    throw "Unexpected libxml2 archive checksum: $ActualHash"
  }

  tar -xzf $LibXmlArchive -C $BuildDir
  if ($LASTEXITCODE -ne 0) { throw "Failed to extract libxml2" }

  & $CMake $LibXmlSourceDir -G "NMake Makefiles" `
    -B $LibXmlBuildDir `
    -DCMAKE_BUILD_TYPE=Release `
    "-DCMAKE_INSTALL_PREFIX=$LibXmlDir" `
    -DBUILD_SHARED_LIBS=OFF `
    -DLIBXML2_WITH_C14N=OFF `
    -DLIBXML2_WITH_CATALOG=OFF `
    -DLIBXML2_WITH_DEBUG=OFF `
    -DLIBXML2_WITH_DOCB=OFF `
    -DLIBXML2_WITH_FTP=OFF `
    -DLIBXML2_WITH_HTML=OFF `
    -DLIBXML2_WITH_HTTP=OFF `
    -DLIBXML2_WITH_ICONV=OFF `
    -DLIBXML2_WITH_ICU=OFF `
    -DLIBXML2_WITH_ISO8859X=OFF `
    -DLIBXML2_WITH_LEGACY=OFF `
    -DLIBXML2_WITH_LZMA=OFF `
    -DLIBXML2_WITH_MODULES=OFF `
    -DLIBXML2_WITH_OUTPUT=ON `
    -DLIBXML2_WITH_PATTERN=OFF `
    -DLIBXML2_WITH_PROGRAMS=OFF `
    -DLIBXML2_WITH_PUSH=OFF `
    -DLIBXML2_WITH_PYTHON=OFF `
    -DLIBXML2_WITH_READER=OFF `
    -DLIBXML2_WITH_REGEXPS=OFF `
    -DLIBXML2_WITH_SAX1=ON `
    -DLIBXML2_WITH_SCHEMAS=OFF `
    -DLIBXML2_WITH_SCHEMATRON=OFF `
    -DLIBXML2_WITH_TESTS=OFF `
    -DLIBXML2_WITH_THREADS=ON `
    -DLIBXML2_WITH_TREE=ON `
    -DLIBXML2_WITH_VALID=OFF `
    -DLIBXML2_WITH_WRITER=OFF `
    -DLIBXML2_WITH_XINCLUDE=OFF `
    -DLIBXML2_WITH_XPATH=OFF `
    -DLIBXML2_WITH_XPTR=OFF `
    -DLIBXML2_WITH_ZLIB=OFF
  if ($LASTEXITCODE -ne 0) { throw "CMake for libxml2 failed" }

  Push-Location $LibXmlBuildDir
  nmake /NOLOGO /S install
  if ($LASTEXITCODE -ne 0) { throw "Building libxml2 failed" }
  Pop-Location
  if (!(Test-Path $LibXmlLibrary)) { throw "libxml2s.lib not found after install" }

  Remove-Item -Recurse -Force $LibXmlBuildDir, $LibXmlSourceDir
  Remove-Item -Force $LibXmlArchive
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
  -DLLDB_ENABLE_LUA=OFF `
  -DLLDB_ENABLE_TREESITTER=OFF `
  "-DPython3_EXECUTABLE=$PythonExe" `
  "-DPython3_ROOT_DIR=$PythonPrefix" `
  -DPython3_FIND_REGISTRY=NEVER `
  -DLLDB_ENABLE_LIBEDIT=OFF `
  -DLLDB_ENABLE_CURSES=OFF `
  -DLLVM_ENABLE_LIBXML2=ON `
  -DLLDB_ENABLE_LIBXML2=ON `
  "-DLIBXML2_INCLUDE_DIR=$LibXmlDir\include\libxml2" `
  "-DLIBXML2_LIBRARY=$LibXmlLibrary" `
  "-DLIBXML2_LIBRARIES=$LibXmlLibrary" `
  -DLLVM_ENABLE_ZSTD=OFF `
  -DLLDB_INCLUDE_TESTS=OFF `
  -DLLVM_TARGETS_TO_BUILD="X86;AArch64;ARM;RISCV" `
  -DLLDB_ENABLE_LZMA=ON `
  -DLIBLZMA_INCLUDE_DIR="$XzDir/include" `
  -DLIBLZMA_LIBRARY="$XzDir/lib/liblzma.lib" `
  "-DCMAKE_C_FLAGS=-DLZMA_API_STATIC -DLIBXML_STATIC" `
  "-DCMAKE_CXX_FLAGS=-DLZMA_API_STATIC -DLIBXML_STATIC" `
  -DCMAKE_INSTALL_PREFIX="$InstallDir" `
  -DLLDB_PYTHON_RELATIVE_PATH="Lib/site-packages"

Push-Location $OutDir

Write-Host "Building and installing specific host tools"
& $Ninja install-lldb install-lldb-dap install-lldb-mcp install-lldb-server install-liblldb install-lldb-python-scripts
if ($LASTEXITCODE -ne 0) { throw "Ninja failed with exit code $LASTEXITCODE" }

Pop-Location
Pop-Location

# Bundle Python runtime into the install directory so the package is self-contained.
Write-Host "Bundling Python runtime..."
$PythonStdlib = python -c "import sysconfig; print(sysconfig.get_path('stdlib'))"
$PythonDLLs = python -c "import os, sys; print(os.path.join(sys.prefix, 'DLLs'))"
$PythonVerNoDot = python -c "import sys; print(f'{sys.version_info.major}{sys.version_info.minor}')"

# Copy Python DLLs to bin directory (where lldb.exe and liblldb.dll live)
Copy-Item "$PythonPrefix\python$PythonVerNoDot.dll" "$InstallDir\bin\" -ErrorAction SilentlyContinue
Copy-Item "$PythonPrefix\python3.dll" "$InstallDir\bin\" -ErrorAction SilentlyContinue
Copy-Item $PythonExe "$InstallDir\bin\python.exe" -ErrorAction SilentlyContinue

# Copy Python stdlib
if (Test-Path $PythonStdlib) {
  $DestLib = "$InstallDir\Lib"
  if (!(Test-Path $DestLib)) { New-Item -ItemType Directory -Path $DestLib -Force }
  # Copy stdlib files that don't already exist (preserve the lldb site-packages installed by CMake)
  Copy-Item "$PythonStdlib\*" $DestLib -Recurse -Force -ErrorAction SilentlyContinue
}

# Copy DLLs directory (platform-specific .pyd modules)
if (Test-Path $PythonDLLs) {
  $DestDLLs = "$InstallDir\DLLs"
  if (!(Test-Path $DestDLLs)) { New-Item -ItemType Directory -Path $DestDLLs -Force }
  Copy-Item "$PythonDLLs\*" $DestDLLs -Recurse -Force -ErrorAction SilentlyContinue
}

$VersionOutput = & "$InstallDir\bin\lldb.exe" -b -o "version --verbose" 2>&1
if ($LASTEXITCODE -ne 0) { throw "Installed lldb.exe failed to start" }
$VersionOutput | Write-Host
if (($VersionOutput -join "`n") -notmatch "xml: yes") {
  throw "Installed lldb.exe does not have XML support enabled"
}

Write-Host "Python runtime bundled successfully."

Write-Host ""
Write-Host "=============================="
Write-Host ""
