$ErrorActionPreference = "Stop"

$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
    throw "adb.exe not found at $adb"
}

Write-Host "Setting adb reverse tcp:8080 -> tcp:80..."
& $adb reverse tcp:8080 tcp:80 | Out-Host
& $adb reverse --list | Out-Host

$baseUrl = "http://localhost:8080/jarwinn-monitoring/api"
$checks = @(
    "$baseUrl/health.php",
    "$baseUrl/plants.php",
    "$baseUrl/alarms.php",
    "$baseUrl/huawei/plants.php",
    "$baseUrl/growatt/plants.php"
)

foreach ($url in $checks) {
    Write-Host "Checking $url"
    & $adb shell "curl -s --max-time 5 '$url' | head -c 120"
    Write-Host ""
}

Write-Host "Mobile debug tunnel is ready. Run the Flutter app again after changing app.env."
