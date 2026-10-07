@echo off
rem Vedora is started through the single root launcher.
rem This wrapper exists so older shortcuts keep working.
cd /d "%~dp0"
call "%~dp0vedora.bat" %*
