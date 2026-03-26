$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-FlutterCommand {
  if ($env:FLUTTER_BIN -and (Test-Path $env:FLUTTER_BIN)) {
    return $env:FLUTTER_BIN
  }

  $candidate = "C:\flutter\bin\flutter.bat"
  if (Test-Path $candidate) { return $candidate }

  $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
  if ($flutterCmd) { return $flutterCmd.Source }

  throw "Flutter not found. Install Flutter, add it to PATH, or set FLUTTER_BIN to the full flutter executable path."
}

function Get-AppVersion {
  $pubspecPath = Join-Path $repoRoot "pubspec.yaml"
  if (-not (Test-Path $pubspecPath)) {
    throw "pubspec.yaml not found at $pubspecPath"
  }

  $versionLine = Get-Content $pubspecPath | Where-Object { $_ -match '^version\s*:\s*' } | Select-Object -First 1
  if (-not $versionLine) {
    throw "Could not find version in pubspec.yaml"
  }

  $fullVersion = ($versionLine -split ':', 2)[1].Trim()
  $appVersion = ($fullVersion -split '\+', 2)[0].Trim()
  if ([string]::IsNullOrWhiteSpace($appVersion)) {
    throw "Invalid version value in pubspec.yaml: $fullVersion"
  }

  return $appVersion
}

$flutterExe = Get-FlutterCommand
$appVersion = Get-AppVersion
$apkSource = Join-Path $repoRoot "build\app\outputs\flutter-apk\app-release.apk"
$apkOutput = Join-Path $repoRoot "Moonfin_Android_v$appVersion.apk"

Push-Location $repoRoot
try {
  Write-Host "Moonfin version: $appVersion"

  Write-Host "Cleaning previous Flutter outputs..."
  & $flutterExe clean
  if ($LASTEXITCODE -ne 0) {
    throw "flutter clean failed with exit code $LASTEXITCODE"
  }

  Write-Host "Resolving Dart and Flutter packages..."
  & $flutterExe pub get
  if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get failed with exit code $LASTEXITCODE"
  }

  Write-Host "Building Android release APK..."
  & $flutterExe build apk --release --target-platform android-arm64,android-arm
  if ($LASTEXITCODE -ne 0) {
    throw "flutter build apk failed with exit code $LASTEXITCODE"
  }

  if (-not (Test-Path $apkSource)) {
    throw "APK not found at expected path: $apkSource"
  }

  Copy-Item -Path $apkSource -Destination $apkOutput -Force

  Write-Host ""
  Write-Host "APK created:" $apkSource
  Write-Host "APK copied to root:" $apkOutput
}
finally {
  Pop-Location
}
