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
    echo         Install Docker Desktop, start it, then close and reopen this
    echo         window so PATH is refreshed. If Docker is installed but not
    echo         running, start Docker Desktop and retry.
    goto :fail
)

rem ---------------------------------------------------------------
rem 1b. .NET SDK
rem  Resolve `dotnet` from PATH first, then from the standard install
rem  locations, so a freshly installed SDK is picked up even when the
rem  current shell has a stale PATH (or was installed per-user).
rem  `PF86` is captured up front because `%ProgramFiles(x86)%` breaks
rem  parenthesized blocks in batch.
rem ---------------------------------------------------------------
set "PF86=%ProgramFiles(x86)%"
set "DOTNET_EXE="
for /f "delims=" %%d in ('where dotnet 2^>nul ^| findstr /i "dotnet.exe"') do if not defined DOTNET_EXE set "DOTNET_EXE=%%d"
if not defined DOTNET_EXE if exist "%ProgramFiles%\dotnet\dotnet.exe" set "DOTNET_EXE=%ProgramFiles%\dotnet\dotnet.exe"
if not defined DOTNET_EXE if exist "%ProgramW6432%\dotnet\dotnet.exe" set "DOTNET_EXE=%ProgramW6432%\dotnet\dotnet.exe"
if not defined DOTNET_EXE if exist "%PF86%\dotnet\dotnet.exe" set "DOTNET_EXE=%PF86%\dotnet\dotnet.exe"
if not defined DOTNET_EXE if exist "%LOCALAPPDATA%\Microsoft\dotnet\dotnet.exe" set "DOTNET_EXE=%LOCALAPPDATA%\Microsoft\dotnet\dotnet.exe"
if not defined DOTNET_EXE (
    echo [ERROR] The .NET SDK was not found.
    echo         Install the .NET 10 SDK from https://dotnet.microsoft.com/download
    echo         then close and reopen this window (or reboot) so PATH is refreshed.
    goto :fail
)

rem The runtime alone cannot build or run the arbiter, and Vedora targets
rem net10.0 (Roblox/global.json), so require a 10.x SDK.
set "DOTNET_SDK10="
for /f "tokens=1 delims=. " %%v in ('"%DOTNET_EXE%" --list-sdks 2^>nul') do if "%%v"=="10" set "DOTNET_SDK10=1"
if not defined DOTNET_SDK10 (
    echo [ERROR] `dotnet` was found at "%DOTNET_EXE%" but no .NET 10 SDK is installed.
    echo         Vedora targets net10.0; the .NET Runtime or an older SDK is not
    echo         enough. Install the .NET 10 SDK from
    echo         https://dotnet.microsoft.com/download
    goto :fail
)
for %%d in ("%DOTNET_EXE%") do set "PATH=%%~dpd;%PATH%"

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
rem Port 3521 is reserved for the arbiter. If something is already bound to
rem it, a previous arbiter is still running; starting a second one crashes
rem this window with AddressInUseException and tears down the RCC warm pool.
call :find_port_pid 3521 ARBITER_PID
if defined ARBITER_PID (
    echo [..] %ARBITER_URLS% is already in use ^(PID !ARBITER_PID!^).
    echo      An RCC arbiter is already running, so a second one is not started.
    echo      Run "vedora.bat down" first to restart it with the latest code.
    goto :arbiter_ready
)

echo [..] Building and starting the Vedora RCC arbiter...
rem Run from the repository root so the relative RCCService paths in
rem appsettings.json resolve to <root>\RCCService.
start "Vedora RCC Arbiter" /d "%ROOT%" cmd /k ""%DOTNET_EXE%" run --project "%ARBITER_PROJECT%" --configuration Release --urls %ARBITER_URLS%"
:arbiter_ready

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
echo [ok] Docker stack stopped.

rem Stop the arbiter too: it is a plain `dotnet run` window, not a container,
rem so leaving it alive would block port 3521 on the next start.
call :find_port_pid 3521 ARBITER_PID
if defined ARBITER_PID (
    echo [..] Stopping the RCC arbiter ^(PID !ARBITER_PID!^)...
    taskkill /PID !ARBITER_PID! /T /F >nul 2>nul
    echo [ok] RCC arbiter stopped.
) else (
    echo [ok] No RCC arbiter was running.
)
echo Close the "Vedora RCC Arbiter" window if it is still open.
goto :eof

rem ---------------------------------------------------------------
rem :find_port_pid <port> <outVar>
rem  Sets <outVar> to the PID owning a LISTENING socket on <port>, if any.
rem ---------------------------------------------------------------
:find_port_pid
set "%~2="
for /f "tokens=5" %%p in ('netstat -ano -p tcp ^| findstr /r /c:"LISTENING" ^| findstr /r /c:":%~1 "') do (
    if not defined %~2 set "%~2=%%p"
)
goto :eof

:fail
echo.
echo Startup aborted.
pause
exit /b 1
