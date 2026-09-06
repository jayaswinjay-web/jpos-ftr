@echo off
echo ========================================
echo   Enabling Windows Developer Mode
echo ========================================
echo.
echo This script must be run as Administrator!
echo.
pause

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d "1"
if %errorlevel% equ 0 (
    echo Developer Mode enabled successfully.
) else (
    echo Failed to enable Developer Mode. Try running as Administrator.
)
pause
