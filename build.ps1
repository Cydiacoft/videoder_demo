# Build from any checkout; Flutter and Visual Studio C++ tools must be installed.
param([switch]$Clean)
$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath $PSScriptRoot
try {
    if ($Clean) {
        flutter clean
        if ($LASTEXITCODE -ne 0) { throw 'flutter clean failed' }
    }
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'Windows build failed' }
    Write-Host 'Built: build/windows/x64/runner/Release/'
} finally {
    Pop-Location
}
