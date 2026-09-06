param(
    [ValidateSet("debug","release","clean","all")]
    [string]$Mode = "debug"
)

$ErrorActionPreference = "Stop"
$projectRoot = "D:\jay pos complete project\jaypos"
$env:ANDROID_HOME = "D:\jay pos complete project\android-sdk"
$env:JAVA_HOME = "D:\jay pos complete project\jdk17\jdk-17.0.19+10"
$env:PATH = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:PATH"
$env:FLUTTER_USE_SYMLINKS = "false"
$flutter = "C:\flutter\bin\flutter.bat"

Set-Location $projectRoot

switch ($Mode) {
    "clean" {
        Write-Host "=== CLEAN ===" -ForegroundColor Cyan
        & $flutter clean
        & $flutter pub get
    }
    "debug" {
        Write-Host "=== BUILD DEBUG APK ===" -ForegroundColor Cyan
        & $flutter build apk --debug --android-skip-build-dependency-validation
        if ($?) {
            $apk = "build\app\outputs\flutter-apk\app-debug.apk"
            $size = [math]::Round((Get-Item $apk).Length / 1MB, 1)
            Write-Host "DEBUG APK: $apk ($size MB)" -ForegroundColor Green
        }
    }
    "release" {
        Write-Host "=== BUILD RELEASE APK ===" -ForegroundColor Cyan
        & $flutter build apk --release --android-skip-build-dependency-validation
        if ($?) {
            $apk = "build\app\outputs\flutter-apk\app-release.apk"
            $size = [math]::Round((Get-Item $apk).Length / 1MB, 1)
            Write-Host "RELEASE APK: $apk ($size MB)" -ForegroundColor Green
        }
    }
    "all" {
        Write-Host "=== CLEAN ===" -ForegroundColor Cyan
        & $flutter clean
        & $flutter pub get
        Write-Host "`n=== DEBUG ===" -ForegroundColor Cyan
        & $flutter build apk --debug --android-skip-build-dependency-validation
        Write-Host "`n=== RELEASE ===" -ForegroundColor Cyan
        & $flutter build apk --release --android-skip-build-dependency-validation
    }
}
