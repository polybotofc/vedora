@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem ---------------------------------------------------------------
rem Start the Vedora RCC arbiter (the render server) on 0.0.0.0:3521.
rem
rem The arbiter runs on the host, not in Docker. The dev stack reaches it
rem through Render__BaseUrl=http://host.docker.internal:3521, so it must bind
rem 0.0.0.0 (a container cannot reach the host's 127.0.0.1) on port 3521.
rem
rem Usage:
rem   scripts\start-render-server.bat
rem   set RENDER_PORT=3600 && scripts\start-render-server.bat
rem ---------------------------------------------------------------
cd /d "%~dp0.."
set "ROOT=%CD%"
if not defined RENDER_PORT set "RENDER_PORT=3521"
set "PROJECT=%ROOT%\Roblox\Vedora.RccServiceArbiter\Vedora.RccServiceArbiter.csproj"

rem appsettings.json (BaseUrl, RCCService paths, Render:DefaultYear) only loads
rem for the Development environment.
set "ASPNETCORE_ENVIRONMENT=Development"

echo ==========================================================
echo   Vedora RCC arbiter ^(render server^)
echo   Bind:  0.0.0.0:%RENDER_PORT%
echo   Root:  %ROOT%
echo ==========================================================
echo.

netstat -ano | findstr /R /C:":%RENDER_PORT% .*LISTENING" >nul 2>nul
if not errorlevel 1 (
    echo [..] Port %RENDER_PORT% is already listening - an arbiter is probably running.
    echo      Check:  netstat -ano ^| findstr :%RENDER_PORT%
    goto :eof
)

where dotnet >nul 2>nul
if errorlevel 1 (
    echo [ERROR] dotnet was not found in PATH. Install the .NET SDK 10 and retry.
    exit /b 1
)

echo [..] Starting arbiter ^(Ctrl+C to stop^)...
dotnet run --project "%PROJECT%" --configuration Release --urls "http://0.0.0.0:%RENDER_PORT%"
