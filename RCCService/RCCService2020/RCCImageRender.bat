@echo off
rem Legacy standalone RCC launcher from the upstream RCCService2020 build.
rem Vedora does NOT use this: the RCC arbiter (vedora.bat) starts RCCService.exe
rem directly on a port it allocates from Arbiter:Ports:Rcc. Keep this only for
rem manually poking a single RCC instance outside Vedora.
:loop
echo "Starting Vedora Image Render RCC (standalone)"
RCCService.exe -console -verbose -port 2621
echo Restarting this RCC, Control+C to cancel restart!
timeout 10
echo (%time%) Restarting RCC!
goto loop