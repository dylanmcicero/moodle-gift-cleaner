@echo off
REM Drag one or more Respondus GIFT export files onto this icon.
REM Cleaned copies are written next to the originals as *_clean.gift

if "%~1"=="" (
    echo.
    echo   Drag one or more .txt question files onto this file.
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Clean-Gift.ps1" %*
set "exitcode=%errorlevel%"

pause
exit /b %exitcode%
