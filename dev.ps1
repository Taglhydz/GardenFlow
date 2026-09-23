# Starts the whole dev environment in one command :
#   1. USB port forwarding phone -> PC (adb reverse), so the app can use http://localhost:3000/api
#   2. the backend, in a new window
#   3. the Flutter app, on the connected phone
#
# Usage (from the project root) :  .\dev        (or double-click dev.cmd)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
# same port as the backend (PORT in backend/.env, 3000 by default)
$portLine = Get-Content "$root\backend\.env" -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\s*PORT\s*=\s*(\d+)' } | Select-Object -First 1
$port = if ($portLine -match '(\d+)') { $Matches[1] } else { 3000 }

# the app must call the same port
$apiLine = Get-Content "$root\frontend\.env" -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\s*API_BASE_URL\s*=' } | Select-Object -First 1
if ($apiLine -and $apiLine -notmatch ":$port/") {
    Write-Host "[!] frontend/.env ($($apiLine.Trim())) does not use port $port of backend/.env" -ForegroundColor Yellow
}

# ---- 1. Phone + port forwarding ----
$device = $null
if (Get-Command adb -ErrorAction SilentlyContinue) {
    # lines look like "R5CT12345AB`tdevice" ; "unauthorized" means the prompt was not accepted on the phone
    $lines = adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\S' }
    $device = $lines | Where-Object { $_ -match "`tdevice$" } | ForEach-Object { ($_ -split "`t")[0] } | Select-Object -First 1

    if ($device) {
        adb -s $device reverse "tcp:$port" "tcp:$port" | Out-Null
        Write-Host "[OK] Phone $device : port $port forwarded to the PC" -ForegroundColor Green
    } elseif ($lines | Where-Object { $_ -match 'unauthorized' }) {
        Write-Host "[!] Phone detected but not authorized : unlock it and accept 'Allow USB debugging', then run .\dev again" -ForegroundColor Yellow
    } else {
        Write-Host "[!] No phone detected over USB (check the cable and USB debugging)" -ForegroundColor Yellow
    }
} else {
    Write-Host "[!] adb not found in PATH : port forwarding skipped" -ForegroundColor Yellow
}

# ---- 2. Backend in a new window ----
# -NoExit : if the backend fails at startup (port already used...), the error stays readable
$backend = Start-Process powershell -PassThru -ArgumentList '-NoExit', '-Command', "Set-Location '$root\backend'; npm run dev"
Write-Host "[OK] Backend starting in a new window (it closes when you quit the app)" -ForegroundColor Green

# ---- 3. Flutter app ----
try {
    Set-Location "$root\frontend"
    if ($device) {
        flutter run -d $device
    } else {
        # no phone : Flutter asks which device to use (Chrome, emulator...)
        flutter run
    }
} finally {
    # quitting the app ('q' or Ctrl+C) also stops the backend : /T kills the whole tree (npm, nodemon, node)
    if (-not $backend.HasExited) {
        taskkill /PID $backend.Id /T /F | Out-Null
        Write-Host "[OK] Backend stopped" -ForegroundColor Green
    }
}
