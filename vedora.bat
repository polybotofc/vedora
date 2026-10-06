@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

title Vedora - 2021 Revival

echo ==========================================================
echo   Vedora - 2021 revival
echo   One-click launcher
echo ==========================================================
echo.

rem ---------------------------------------------------------------
rem 0. Repository layout
rem ---------------------------------------------------------------
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "ROBLOX_DIR=%ROOT%\Roblox"
set "ARBITER_PROJECT=%ROBLOX_DIR%\Vedora.RccServiceArbiter\Vedora.RccServiceArbiter.csproj"
set "ARBITER_URLS=http://127.0.0.1:3521"
rem The arbiter is launched with `dotnet run` so it uses appsettings.json, which
rem only loads for the Development environment.
set "ASPNETCORE_ENVIRONMENT=Development"
set "RCC_ROOT=%ROOT%\RCCService"
set "RCC2021=%RCC_ROOT%\RCCService2021"
set "PUBLIC_BASE_URL=https://vedora.xyz"

rem ---------------------------------------------------------------
rem 0b. Arguments: "down" / "stop" stops the Docker stack
rem ---------------------------------------------------------------
if /i "%~1"=="down" goto :shutdown
if /i "%~1"=="stop" goto :shutdown

rem ---------------------------------------------------------------
rem 1. Required tools
rem ---------------------------------------------------------------
where docker >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Docker was not found in PATH.
    echo         Install Docker Desktop and make sure it is running, then retry.
    goto :fail
)

where dotnet >nul 2>nul
if errorlevel 1 (
    echo [ERROR] The .NET SDK was not found in PATH.
    echo         Install the .NET 10 SDK from https://dotnet.microsoft.com/download
    goto :fail
)

rem ---------------------------------------------------------------
rem 2. RCCService2021
rem ---------------------------------------------------------------
if not exist "%RCC2021%\RCCService.exe" (
    echo [ERROR] RCCService2021 was not found at:
    echo         %RCC2021%\RCCService.exe
    echo         Add the RCCService2021 build before starting Vedora.
    goto :fail
)
echo [ok] RCCService2021 found.

rem ---------------------------------------------------------------
rem 3. Quilkin proxy (game server traffic)
rem ---------------------------------------------------------------
if not exist "%RCC_ROOT%\quilkin.exe" (
    echo [..] quilkin.exe not found. Downloading the proxy...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$ErrorActionPreference='Stop';" ^
        "$zip=Join-Path $env:TEMP 'quilkin.zip';" ^
        "$dst=Join-Path $env:TEMP 'quilkin-extract';" ^
        "Invoke-WebRequest -Uri 'https://github.com/EmbarkStudios/quilkin/releases/download/v0.9.0/quilkin-0.9.0.zip' -OutFile $zip;" ^
        "if (Test-Path $dst) { Remove-Item $dst -Recurse -Force };" ^
        "Expand-Archive -Path $zip -DestinationPath $dst -Force;" ^
        "Copy-Item (Join-Path $dst 'x86_64-pc-windows-gnu\release\quilkin.exe') '%RCC_ROOT%\quilkin.exe' -Force;"
    if errorlevel 1 (
        echo [ERROR] Could not download quilkin.exe.
        echo         Download the Windows build manually and place it at:
        echo         %RCC_ROOT%\quilkin.exe
        goto :fail
    )
    echo [ok] quilkin.exe installed.
) else (
    echo [ok] quilkin.exe found.
)

rem ---------------------------------------------------------------
rem 4. Docker stack (Postgres, Redis, migrations, .NET services,
rem    frontend, admin, asset validation)
rem ---------------------------------------------------------------
echo.
echo [..] Starting the Docker stack (this can take a few minutes on the first run)...
docker compose -f "%ROOT%\docker-compose.yml" up -d --build
if errorlevel 1 (
    echo [ERROR] docker compose failed to start the stack.
    goto :fail
)

echo [..] Waiting for the API proxy to accept connections...
set "API_READY="
for /l %%i in (1,1,60) do (
    if not defined API_READY (
        powershell -NoProfile -Command ^
            "try { $c = New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1',5200); $c.Close(); exit 0 } catch { exit 1 }" >nul 2>nul
        if not errorlevel 1 set "API_READY=1"
        if not defined API_READY timeout /t 3 /nobreak >nul
    )
)
if not defined API_READY (
    echo [WARN] The API proxy did not become ready in time.
    echo        Check the logs with: docker compose logs api-proxy
)

rem ---------------------------------------------------------------
rem 5. RCC arbiter (game servers + thumbnails/renders)
rem ---------------------------------------------------------------
echo.
echo [..] Building and starting the Vedora RCC arbiter...
rem Run from the repository root so the relative RCCService paths in
rem appsettings.json resolve to <root>\RCCService.
start "Vedora RCC Arbiter" cmd /k "cd /d "%ROOT%" ^&^& dotnet run --project "%ARBITER_PROJECT%" --configuration Release --urls %ARBITER_URLS%"

echo.
echo ==========================================================
echo   Vedora is starting.
echo.
echo   Website   : %PUBLIC_BASE_URL%
echo   Local API : http://localhost:5200
echo   Arbiter   : %ARBITER_URLS%
echo.
echo   The arbiter runs in its own window. Close it to stop
echo   game servers and renders.
echo   Run "vedora.bat down" to stop the Docker stack.
echo ==========================================================
goto :eof

:shutdown
echo [..] Stopping the Vedora Docker stack...
docker compose -f "%ROOT%\docker-compose.yml" down
echo [ok] Docker stack stopped. Close the "Vedora RCC Arbiter" window to stop the arbiter.
goto :eof

:fail
echo.
echo Startup aborted.
pause
exit /b 1
