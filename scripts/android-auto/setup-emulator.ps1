# One-time setup for testing Android Auto on an EMULATOR (no physical phone).
#
# What it does:
#   1. Installs the required SDK packages (platform-tools, emulator,
#      an API 33 Google Play system image and the DHU itself).
#   2. Creates a ready-made AVD named "CarGuard_Auto".
#   3. Optionally (-Boot) boots the AVD and waits for it to finish booting.
#   4. Optionally (-AaApk FILE) sideloads the Android Auto companion APK
#      (an x86_64 build is required - see docs/android_auto.md).
#
# Usage:
#   .\scripts\android-auto\setup-emulator.ps1
#   .\scripts\android-auto\setup-emulator.ps1 -Boot
#   .\scripts\android-auto\setup-emulator.ps1 -Boot -AaApk android-auto.apk
#
param(
  [switch]$Boot,
  [string]$AaApk = ""
)

$ErrorActionPreference = "Stop"

$Image = "system-images;android-33;google_apis_playstore;x86_64"
$AvdName = "CarGuard_Auto"

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

# ---------------------------------------------------------------------------
# 2. Locate sdkmanager / avdmanager / adb
# ---------------------------------------------------------------------------
$SdkManager = $null
$AvdManager = $null
foreach ($sub in @("cmdline-tools\latest", "cmdline-tools\newest", "tools")) {
  if (-not $SdkManager -and (Test-Path "$Sdk\$sub\bin\sdkmanager.bat")) {
    $SdkManager = "$Sdk\$sub\bin\sdkmanager.bat"
    $AvdManager = "$Sdk\$sub\bin\avdmanager.bat"
  }
}

if (-not $SdkManager) {
  Write-Error @"
sdkmanager not found under: $Sdk
Android Studio -> Settings -> Languages & Frameworks -> Android SDK ->
SDK Tools -> tick 'Android SDK Command-line Tools (latest)'.
"@
  exit 1
}

$Adb = Join-Path $Sdk "platform-tools\adb.exe"

# ---------------------------------------------------------------------------
# 3. Install the needed SDK packages
# ---------------------------------------------------------------------------
Write-Host "Installing SDK packages (this can take a few minutes)..."
Write-Host "  * platform-tools  * emulator  * $Image  * extras;google;auto (DHU)"
& $SdkManager --install "platform-tools" "emulator" $Image "extras;google;auto"

Write-Host "SDK packages installed."

# ---------------------------------------------------------------------------
# 4. Create the AVD (idempotent)
# ---------------------------------------------------------------------------
$existing = & $AvdManager list avd 2>$null | Select-String "Name: $AvdName$"
if ($existing) {
  Write-Host "AVD '$AvdName' already exists - skipping creation."
}
else {
  Write-Host "Creating AVD '$AvdName'..."
  "no" | & $AvdManager create avd --force --name $AvdName --package $Image --device pixel_5
  if ($LASTEXITCODE -ne 0) {
    "no" | & $AvdManager create avd --force --name $AvdName --package $Image
  }
}

# ---------------------------------------------------------------------------
# 5. Optionally sideload the Android Auto companion APK
# ---------------------------------------------------------------------------
if ($AaApk) {
  if (-not (Test-Path $AaApk)) {
    Write-Error "APK not found: $AaApk"
    exit 1
  }
  $state = & $Adb get-state 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "No device/emulator running yet - start the emulator first, then run:"
    Write-Warning "  adb install -r `"$AaApk`""
  }
  else {
    Write-Host "Installing Android Auto APK..."
    & $Adb install -r $AaApk
    if ($LASTEXITCODE -ne 0) {
      Write-Error @"

Install failed. Make sure you downloaded an x86_64 variant of the Android
Auto APK (see docs/android_auto.md, emulator-only flow).
"@
      exit 1
    }
    Write-Host "Android Auto app installed."
  }
}

# ---------------------------------------------------------------------------
# 6. Optionally boot the emulator and wait for it
# ---------------------------------------------------------------------------
if ($Boot) {
  Write-Host "Booting the emulator (first boot takes a few minutes)..."
  $emu = Join-Path $Sdk "emulator\emulator.exe"
  Start-Process -FilePath $emu -ArgumentList "-avd", $AvdName
  & $Adb wait-for-device
  do {
    Start-Sleep -Seconds 3
    $booted = (& $Adb shell getprop sys.boot.completed 2>$null) -replace "`r", ""
  } while ($booted.Trim() -ne "1")
  Write-Host "Emulator booted."
}

Write-Host ""
Write-Host "Done! Next steps:"
Write-Host "  1. flutter run                          # install Car Guard on the emulator"
if (-not $Boot) {
  Write-Host "     (or boot it now:  .\setup-emulator.ps1 -Boot)"
}
Write-Host "  2. .\scripts\android-auto\run-dhu.ps1   # start the car simulator"
