param(
  [string]$AdbPath = "D:\jay pos complete project\android-sdk\platform-tools\adb.exe"
)

function t {
  param([int]$x, [int]$y, [string]$desc = "")
  if ($desc) { Write-Host "  Tap ($x,$y): $desc" -ForegroundColor Gray }
  & $AdbPath shell input tap $x $y
  Start-Sleep -Milliseconds 700
}

function type-text {
  param([string]$text)
  $escaped = $text -replace "'", "'\''"
  & $AdbPath shell "input text '$escaped'"
  Start-Sleep -Milliseconds 300
}

function key {
  param([int]$code)
  & $AdbPath shell input keyevent $code
  Start-Sleep -Milliseconds 300
}

function scroll {
  param([int]$dist = 300)
  $y2 = 1600 - $dist
  & $AdbPath shell input swipe 540 1600 540 $y2 200
  Start-Sleep -Milliseconds 1200
}

function screenshot {
  param([string]$name)
  & $AdbPath shell screencap /sdcard/test_$name.png
  & $AdbPath pull /sdcard/test_$name.png "D:\jay pos complete project\test_$name.png" 2>&1 | Out-Null
  Write-Host "  [Screenshot: test_$name.png]" -ForegroundColor Yellow
}

Write-Host "=== JayPOS Emulator Test (Precise Coordinates) ===" -ForegroundColor Cyan
Write-Host ""

# Clear + Launch
Write-Host "Clearing + launching app..." -ForegroundColor Yellow
& $AdbPath shell pm clear com.jaytech.jaypos 2>&1 | Out-Null
Start-Sleep -Milliseconds 1000
& $AdbPath shell am start -n com.jaytech.jaypos/.MainActivity
Start-Sleep -Milliseconds 5000

# ════════════════════════════════════════
# PAGE 1: Store Information (8 fields + Next)
# Verified bounds from uiautomator dump:
#   Store Name *  [63,494][1017,630] → center (540,562)
#   Address       [63,672][1017,872] → center (540,772)
#   Phone         [63,914][1017,1050]→ center (540,982)
#   GSTIN         [63,1092][1017,1229]→ center (540,1160)
#   UPI ID        [63,1271][1017,1407]→ center (540,1339)
#   Currency ₹    [63,1449][1017,1586]→ center (540,1517)
#   Default Tax%  [63,1628][1017,1764]→ center (540,1696)
#   Printer Width [63,1806][1017,1857]→ center (540,1831) (cut off)
#   Next button: expected at ~(540, 1640) after scroll
# ════════════════════════════════════════
Write-Host "Page 1/3: Store Information" -ForegroundColor Green
screenshot "01_setup"

t 540 562 "Store Name *"
type-text "Jay Test Store"
screenshot "01a_store"

# Scroll down to reveal Next button
scroll 450
screenshot "01b_scrolled"

# Tap Next - it should be near the bottom after scroll
t 540 1640 "Next button (page 1)"
Start-Sleep -Milliseconds 2000

# ════════════════════════════════════════
# PAGE 2: Owner Account (4 fields + Next)
# Layout SAME as page 1 (same scroll template):
#   Display Name *  [63,494][1017,630] → (540,562)
#   Username *      [63,672][1017,809] → (540,740)
#   Password *      [63,851][1017,987] → (540,919)
#   Confirm Pass *  [63,1029][1017,1166]→ (540,1097)
#   Next button: at y=1190→1238 → center (540,1214)
# ════════════════════════════════════════
Write-Host "Page 2/3: Owner Account" -ForegroundColor Green
screenshot "02_owner"

t 540 562 "Display Name *"
type-text "Jay Owner"
t 540 740 "Username *"
type-text "admin"
t 540 919 "Password *"
type-text "admin123"
t 540 1097 "Confirm Password *"
type-text "admin123"
screenshot "02a_filled"

# Next button should be at y=1214, NO scroll needed on page 2 (fewer fields)
t 540 1214 "Next button (page 2)"
Start-Sleep -Milliseconds 2000

# ════════════════════════════════════════
# PAGE 3: Review & Complete Setup
# Title at y≈294, settings card at y≈350-800
# Cloud Sync toggle at y≈850-950
# Complete Setup button at y≈1050 (before cloud scroll)
# OR at y≈1300+ (after cloud sync section opens)
# Enable cloud sync, then scroll to Complete Setup
# ════════════════════════════════════════
Write-Host "Page 3/3: Review & Complete Setup" -ForegroundColor Green
screenshot "03_review"

# Quick check: what's on screen? The Complete Setup button is the last element
# If cloud sync is OFF (default), button is at about y=1050
scroll 200
screenshot "03b_scrolled"

# Try tapping at bottom for Complete Setup
t 540 1650 "Complete Setup (estimated)"
Start-Sleep -Milliseconds 3000

# ════════════════════════════════════════
# LOGIN SCREEN
# Layout (from center/singlechildscrollview):
#   JayPOS icon + title at top center
#   Username field at ~y=880
#   Password field at ~y=980
#   Sign In button at ~y=1080
#   (Cloud sign-in expandable below)
# ════════════════════════════════════════
Write-Host "Login" -ForegroundColor Green
screenshot "04_login"

t 540 880 "Username field"
type-text "admin"
t 540 980 "Password field"
type-text "admin123"
screenshot "04a_filled"

t 540 1080 "Sign In button"
Start-Sleep -Milliseconds 5000

# ════════════════════════════════════════
# DASHBOARD
Write-Host "Dashboard" -ForegroundColor Green
screenshot "05_dashboard"

# Verify by navigating to Billing screen via NavigationRail
t 300 600 "Billing tab (NavigationRail)"
Start-Sleep -Milliseconds 2000
screenshot "06_billing"

# Check logcat for Flutter errors
Write-Host "`nLogcat errors:" -ForegroundColor Cyan
& $AdbPath logcat -d 2>&1 | Select-String -Pattern "(?i)flutter.*(?:Error|Exception)|FATAL EXCEPTION" | Select-Object -First 10

Write-Host "`nDone." -ForegroundColor Cyan
