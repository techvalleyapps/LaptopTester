@echo off
:: LaptopTester — Battery Test Launcher
:: Automatically re-launches PowerShell as Administrator

:: Check if already admin
net session >nul 2>&1
if %errorlevel% == 0 goto :RunScript

:: Not admin — re-launch elevated
echo Requesting Administrator rights...
powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
exit /b

:RunScript
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0BatteryTest.ps1"
