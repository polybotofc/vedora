@echo off
setlocal enabledelayedexpansion
rem Diagnostic helper for RCCService2021.
rem
rem It launches RCCService.exe directly, then reports which TCP port that
rem process actually opens. Compare that with the port the arbiter probes
rem (Arbiter:Ports:Rcc, default 45000) to find out why the readiness probe
rem times out and the worker is killed.
rem
rem Usage:
rem   diagnose-rcc.bat                 (uses: -Console -verbose)
rem   diagnose-rcc.bat "-Console -verbose -port 64989"
rem
rem Run it from the repository root.

set "ROOT=%~dp0.."
if not exist "%ROOT%\RCCService\RCCService2021\RCCService.exe" set "ROOT=%~dp0"
if not exist "%ROOT%\RCCService\RCCService2021\RCCService.exe" (
    echo [ERROR] Could not find RCCService\RCCService2021\RCCService.exe.
    echo         Place this script in the repository root and retry.
    exit /b 1
)

set "DIR=%ROOT%\RCCService\RCCService2021"
if "%~1"=="" (set "ARGS=-Console -verbose") else (set "ARGS=%~1")

echo ==========================================================
echo  RCCService2021 diagnostic
echo  Folder: %DIR%
echo  Args:   %ARGS%
echo ==========================================================
echo.

pushd "%DIR%"
echo Launching RCCService2021 in a new window...
start "RCC 2021 (diagnostic)" cmd /k ""RCCService.exe" %ARGS%"
popd

echo Waiting for RCCService.exe to start...
set "PID="
for /l %%i in (1,1,20) do (
    for /f "tokens=2 delims=," %%p in ('tasklist /fi "imagename eq RCCService.exe" /fo csv /nh 2^>nul') do (
        set "PID=%%~p"
        goto :gotpid
    )
    timeout /t 1 >nul
)

:gotpid
if not defined PID (
    echo   [FAIL] RCCService.exe is not running. It exited immediately -
    echo          read the "RCC 2021 (diagnostic)" window for the reason.
    goto :done
)

echo   RCCService.exe PID = !PID!
echo   Listening TCP ports for that process (checked for 30s^):
echo.

set "FOUND="
for /l %%i in (1,1,30) do (
    for /f "tokens=2" %%a in ('netstat -ano ^| findstr /r /c:"LISTENING" ^| findstr /r /c:" !PID!$"') do (
        echo     %%a  LISTENING  ^(pid !PID!^)
        set "FOUND=1"
    )
    timeout /t 1 >nul
)

echo.
if defined FOUND (
    echo   [OK] RCC is listening on the port^(s^) listed above.
    echo        Make sure the arbiter's Rcc port range includes that port,
    echo        and pass the matching port in the launch args if RCC needs it.
) else (
    echo   [FAIL] RCCService.exe opened no TCP port in 30s.
    echo          It is probably missing a dependency ^(install the Visual C++
    echo          Redistributable 2015-2022 x86^) or rejected its arguments.
    echo          Read the "RCC 2021 (diagnostic)" window for details.
)

:done
echo.
echo Done. Close the RCC window manually when you are finished.
endlocal
