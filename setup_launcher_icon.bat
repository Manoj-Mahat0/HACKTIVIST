@echo off
echo ========================================
echo   Indoor Navigation - Launcher Icon Setup
echo ========================================
echo.

echo Step 1: Installing dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)
echo.

echo Step 2: Generating launcher icons...
call dart run flutter_launcher_icons
if %errorlevel% neq 0 (
    echo ERROR: Failed to generate launcher icons
    pause
    exit /b 1
)
echo.

echo Step 3: Cleaning project...
call flutter clean
if %errorlevel% neq 0 (
    echo ERROR: Failed to clean project
    pause
    exit /b 1
)
echo.

echo Step 4: Reinstalling dependencies...
call flutter pub get
if %errorlevel% neq 0 (
    echo ERROR: Failed to reinstall dependencies
    pause
    exit /b 1
)
echo.

echo ========================================
echo   SUCCESS! Launcher icons generated
echo ========================================
echo.
echo Your app now has custom launcher icons!
echo.
echo Next steps:
echo 1. Run: flutter run
echo 2. Check your app icon on the device
echo.
pause
