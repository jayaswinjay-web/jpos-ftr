@echo off
echo ========================================
echo   Fixing Visual Studio 2026 for Flutter
echo ========================================
echo.
echo This script must be run as Administrator!
echo.
echo It will add the "Desktop development with C++" workload
echo needed by Flutter's Windows build.
echo.
pause

set VS_INSTALLER="C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe"
set VS_PATH="D:\VSBuildTools"

echo.
echo Modifying Visual Studio installation...
%VS_INSTALLER% modify --installPath %VS_PATH% --add Microsoft.VisualStudio.Workload.NativeDesktop --passive --norestart

echo.
echo Done. If successful, restart your computer then run:
echo   flutter build windows
echo.
pause
