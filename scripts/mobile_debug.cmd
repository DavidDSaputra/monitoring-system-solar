@echo off
setlocal

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB%" (
  echo adb.exe not found at "%ADB%"
  exit /b 1
)

echo Setting adb reverse tcp:8080 -^> tcp:80...
"%ADB%" reverse tcp:8080 tcp:80
"%ADB%" reverse --list

set "BASE_URL=http://localhost:8080/jarwinn-monitoring/api"

call :check "%BASE_URL%/health.php"
call :check "%BASE_URL%/plants.php"
call :check "%BASE_URL%/alarms.php"
call :check "%BASE_URL%/huawei/plants.php"
call :check "%BASE_URL%/growatt/plants.php"

echo.
echo Mobile debug tunnel is ready. Stop and run the Flutter app again if app.env changed.
exit /b 0

:check
echo.
echo Checking %~1
"%ADB%" shell "curl -s --max-time 5 '%~1' | head -c 120"
echo.
exit /b 0
