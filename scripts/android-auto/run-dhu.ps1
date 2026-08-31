# Starts the Android Auto Desktop Head Unit (DHU) simulator against a
# connected phone or emulator running the Android Auto app.
#
# Usage (PowerShell):
#   .\scripts\android-auto\run-dhu.ps1
#   .\scripts\android-auto\run-dhu.ps1 -i rotary   # rotary controller mode
#
# Docs: https://developer.android.com/training/cars/testing/dhu
#
$ErrorActionPreference = "Stop"

$Port = if ($env:DHU_PORT) { $env:DHU_PORT } else { "5277" }

# ---------------------------------------------------------------------------
# 1. Locate the Android SDK
# ---------------------------------------------------------------------------
$Sdk = $null
foreach ($candidate in @(
    $env:ANDROID_HOME,
    $env:ANDROID_SDK_ROOT,
    "$env:LOCALAPPDATA\Android\Sdk")) {
  if ($candidate -and (Test-Path $candidate)) {
    $Sdk = $candidate
    break
  }
}

if (-not $Sdk) {
  Write-Error "Android SDK not found. Install Android Studio or set ANDROID_HOME."
  exit 1
}

$Adb = Join-Path $Sdk "platform-tools\adb.exe"
$DhuDir = Join-Path $Sdk "extras\google\auto"
$Dhu = Join-Path $DhuDir "desktop-head-unit.exe"

if (-not (Test-Path $Adb)) {
  Write-Error "adb not found at: $Adb (install 'platform-tools')."
  exit 1
}

# ---------------------------------------------------------------------------
# 2. Make sure the DHU package is installed (extras;google;auto)
# ---------------------------------------------------------------------------
if (-not (Test-Path $Dhu)) {
  Write-Host "DHU not installed - trying to install it via sdkmanager..." 
  $SdkManager = $null
  foreach ($candidate in @(
      "$Sdk\cmdline-tools\latest\bin\sdkmanager.bat",
      "$Sdk\cmdline-tools\newest\bin\sdkmanager.bat",
      "$Sdk\tools\bin\sdkmanager.bat")) {
    if (Test-Path $candidate) {
      $SdkManager = $candidate
      break
    }
  }

  if (-not $SdkManager) {
    Write-Error @"

sdkmanager not found.
Open Android Studio -> Settings -> Languages & Frameworks -> Android SDK ->
SDK Tools -> tick 'Android Auto Desktop Head Unit emulator', then re-run.
"@
    exit 1
  }

  & $SdkManager --install "extras;google;auto"
}

# ---------------------------------------------------------------------------
# 3. Make sure a device/emulator is connected
# ---------------------------------------------------------------------------
$deviceLines = & $Adb devices | Select-Object -Skip 1 | Where-Object { $_ -match "\sdevice$" }
if (-not $deviceLines) {
  Write-Error "No device connected. Plug in a phone with USB debugging, or start an emulator."
  exit 1
}

# ---------------------------------------------------------------------------
# 4. Tunnel + launch
# ---------------------------------------------------------------------------
# Best effort: try to start the head unit server on the phone/emulator
# without the manual "tap the version 10 times" dance.
$gearhead = & $Adb shell pm list packages 2>$null | Select-String "com.google.android.projection.gearhead"
if ($gearhead) {
  Write-Host "Trying to start the Android Auto head unit server via adb..."
  & $Adb shell am startservice -W "com.google.android.projection.gearhead/com.google.android.projection.gearhead.companion.DeveloperHeadUnitNetworkService" 2>$null
  if ($LASTEXITCODE -ne 0) {
    & $Adb shell am start-foreground-service "com.google.android.projection.gearhead/com.google.android.projection.gearhead.companion.DeveloperHeadUnitNetworkService" 2>$null
  }
}
else {
  Write-Host "Android Auto app not found on the device."
  Write-Host "  * Physical phone: install it from Google Play, or"
  Write-Host "  * Emulator: see 'emulator-only flow' in docs/android_auto.md."
}

Write-Host "Forwarding tcp:$Port -> device tcp:$Port ..."
& $Adb forward "tcp:$Port" "tcp:$Port" | Out-Null

Write-Host ""
Write-Host "Starting the Desktop Head Unit (close its window to quit)..."
Write-Host "Remember on the phone: Android Auto app -> Developer settings -> 'Start head unit server'."
Write-Host ""
Set-Location $DhuDir
& ".\desktop-head-unit.exe" "--adb=localhost:$Port" @args
