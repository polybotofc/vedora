@echo off
rem Legacy standalone launcher from the upstream RCCService2020 build. It fires
rem the four render helpers below on fixed ports. Vedora does NOT use this: the
rem RCC arbiter (vedora.bat) manages RCCService instances itself, on ports
rem allocated from Arbiter:Ports:Rcc.
echo "Starting Vedora Player Render RCC"
start /b RCCPlayerRender.bat
echo "Starting Vedora Image Render RCC"
start /b RCCImageRender.bat
echo "Starting Vedora Game Render RCC"
start /b RCCGameRender.bat
echo "Starting Vedora Catalog Render RCC"
start /b RCCCatalogRender.bat