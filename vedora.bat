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
rem   NOTE: inside ( ... ) blocks, paths are read with !VAR! (delayed
rem   expansion) instead of %VAR%, so folders like "Program Files (x86)"
rem   or a repo path containing ")" cannot break the block.
rem ---------------------------------------------------------------
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "ROBLOX_DIR=%ROOT%\Roblox"
set "ARBITER_PROJECT=%ROBLOX_DIR%\Vedora.RccServiceArbiter\Vedora.RccServiceArbiter.csproj"
rem The Docker services reach the arbiter through
rem Render__BaseUrl=http://host.docker.internal:3521. A container cannot reach
rem the host's 127.0.0.1, so the arbiter must bind 0.0.0.0. Keep port 3521 to
rem match Render__BaseUrl in docker-compose.yml.
set "ARBITER_URLS=http://0.0.0.0:3521"
set "ARBITER_URLS_LOCAL=http://localhost:3521"
rem The arbiter is launched with "dotnet run" so it uses appsettings.json, which
rem only loads for the Development environment.
set "ASPNETCORE_ENVIRONMENT=Development"
set "RCC_ROOT=%ROOT%\RCCService"
set "RCC2021=%RCC_ROOT%\RCCService2021"
set "PUBLIC_BASE_URL=https://vedora.xyz"

rem ---------------------------------------------------------------
rem 0a. Environment file (Discord, hCaptcha, secrets, ...)
rem  Docker Compose only auto-loads a file literally named ".env".
rem  Pick up, in order: VEDORA_ENV_FILE, .env, then .env.prod.
rem ---------------------------------------------------------------
set "ENV_FILE="
if defined VEDORA_ENV_FILE if exist "%VEDORA_ENV_FILE%" set "ENV_FILE=%VEDORA_ENV_FILE%"
if not defined ENV_FILE if exist "%ROOT%\.env" set "ENV_FILE=%ROOT%\.env"
if not defined ENV_FILE if exist "%ROOT%\.env.prod" set "ENV_FILE=%ROOT%\.env.prod"

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
    echo         window so PATH is refreshed.
    goto :fail
)

docker info >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Docker is installed but its engine is not running.
    echo         Start Docker Desktop and wait until the engine is running.
    echo         If WSL2 reports virtualization errors, enable virtualization in BIOS/UEFI.
    goto :fail
)
docker compose version >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Docker Compose v2 was not found.
    goto :fail
)

rem ---------------------------------------------------------------
rem 1b. .NET SDK
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
    echo         then close and reopen this window ^(or reboot^) so PATH is refreshed.
    goto :fail
)

set "DOTNET_SDK10="
for /f "tokens=1 delims=. " %%v in ('""%DOTNET_EXE%" --list-sdks 2^>nul"') do if "%%v"=="10" set "DOTNET_SDK10=1"
if not defined DOTNET_SDK10 (
    echo [ERROR] dotnet was found at "!DOTNET_EXE!" but no .NET 10 SDK is installed.
    echo         Vedora targets net10.0; the runtime or an older SDK is not enough.
    echo         Install the .NET 10 SDK from https://dotnet.microsoft.com/download
    goto :fail
)
for %%d in ("%DOTNET_EXE%") do set "PATH=%%~dpd;%PATH%"

rem ---------------------------------------------------------------
rem 2. RCCService2021 (game servers + renders)
rem ---------------------------------------------------------------
if not exist "%RCC2021%\RCCService.exe" (
    echo [ERROR] RCCService2021 was not found at:
    echo         !RCC2021!\RCCService.exe
    echo         Add the RCCService2021 build before starting Vedora.
    goto :fail
)
echo [ok] RCCService2021 found ^(game servers + renders^).

rem ---------------------------------------------------------------
rem 3. Quilkin proxy (game server traffic)
rem ---------------------------------------------------------------
if not exist "%RCC_ROOT%\quilkin.exe" (
    echo [..] quilkin.exe not found. Downloading the proxy...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$ErrorActionPreference='Stop';" ^
        "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
        "$zip=Join-Path $env:TEMP 'quilkin.zip';" ^
        "$dst=Join-Path $env:TEMP 'quilkin-extract';" ^
        "Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/EmbarkStudios/quilkin/releases/download/v0.9.0/quilkin-0.9.0.zip' -OutFile $zip;" ^
        "if (Test-Path $dst) { Remove-Item $dst -Recurse -Force };" ^
        "Expand-Archive -Path $zip -DestinationPath $dst -Force;" ^
        "Copy-Item (Join-Path $dst 'x86_64-pc-windows-gnu\release\quilkin.exe') '!RCC_ROOT!\quilkin.exe' -Force;"
    if errorlevel 1 (
        echo [ERROR] Could not download quilkin.exe.
        echo         Download the Windows build manually and place it at:
        echo         !RCC_ROOT!\quilkin.exe
        goto :fail
    )
    echo [ok] quilkin.exe installed.
) else (
    echo [ok] quilkin.exe found.
)

rem ---------------------------------------------------------------
rem 4. Docker stack
rem  Normalize scripts/*.sh to LF so the Linux containers can run them.
rem ---------------------------------------------------------------
if not exist "%ROOT%\scripts\windows\Normalize-ShLineEndings.ps1" (
    echo [ERROR] Normalize-ShLineEndings.ps1 is missing. Update the repository first.
    goto :fail
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\scripts\windows\Normalize-ShLineEndings.ps1" -Root "%ROOT%"
if errorlevel 1 (
    echo [ERROR] Failed to normalize shell script line endings.
    goto :fail
)

echo.
echo [..] Starting the Docker stack ^(this can take a few minutes on the first run^)...
if defined ENV_FILE (
    echo [ok] Using environment file: !ENV_FILE!
    docker compose --env-file "!ENV_FILE!" -f "!ROOT!\docker-compose.yml" up -d --build
) else (
    echo [warn] No .env or .env.prod found. Discord OAuth, hCaptcha and other keyed
    echo        integrations will stay unset. Copy .env.prod.example to .env and fill it in.
    docker compose -f "!ROOT!\docker-compose.yml" up -d --build
)
if errorlevel 1 (
    echo [ERROR] docker compose failed to start the stack.
    goto :fail
)

echo [..] Waiting for the API proxy to accept connections...
set "API_READY="
for /l %%i in (1,1,60) do (
    if not defined API_READY (
        powershell -NoProfile -Command "try { $c = New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1',5200); $c.Close(); exit 0 } catch { exit 1 }" >nul 2>nul
        if not errorlevel 1 (
            set "API_READY=1"
        ) else (
            timeout /t 3 /nobreak >nul
        )
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
call :find_port_pid 3521 ARBITER_PID
if defined ARBITER_PID (
    echo [..] %ARBITER_URLS_LOCAL% is already in use ^(PID !ARBITER_PID!^).
    echo      An RCC arbiter is already running, so a second one is not started.
    echo      Run "vedora.bat down" first to restart it with the latest code.
    goto :arbiter_ready
)

echo [..] Building and starting the Vedora RCC arbiter...
start "Vedora RCC Arbiter" /d "%ROOT%" cmd /k ""%DOTNET_EXE%" run --project "%ARBITER_PROJECT%" --configuration Release --urls %ARBITER_URLS%"
:arbiter_ready

echo.
echo ==========================================================
echo   Vedora is starting.
echo.
echo   Website   : %PUBLIC_BASE_URL%
echo   Local API : http://localhost:5200
echo   Arbiter   : %ARBITER_URLS_LOCAL%
echo.
echo   The arbiter runs in its own window. Close it to stop
echo   game servers and renders.
echo   Run "vedora.bat down" to stop the Docker stack.
echo ==========================================================
goto :eof

:shutdown
echo [..] Stopping the Vedora Docker stack...
if defined ENV_FILE (
    docker compose --env-file "!ENV_FILE!" -f "!ROOT!\docker-compose.yml" down
) else (
    docker compose -f "!ROOT!\docker-compose.yml" down
)
if errorlevel 1 goto :fail
echo [ok] Docker stack stopped.

call :find_port_pid 3521 ARBITER_PID
if defined ARBITER_PID (
    echo [..] Stopping the RCC arbiter ^(PID !ARBITER_PID!^)...
    taskkill /PID !ARBITER_PID! /T /F >nul 2>nul
    echo [ok] RCC arbiter stopped.
) else (
    echo [ok] No RCC arbiter was running.
)
goto :eof

rem :find_port_pid <port> <outVar> - PID listening on <port>, if any
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
