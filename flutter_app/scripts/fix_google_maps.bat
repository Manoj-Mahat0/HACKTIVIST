@echo off
echo ========================================
echo Fixing Google Maps Plugin
echo ========================================
echo.

cd flutter_app

echo Step 1: Cleaning Flutter build...
call flutter clean

echo.
echo Step 2: Getting Flutter packages...
call flutter pub get

echo.
echo Step 3: Cleaning Android build...
cd android
call gradlew clean
cd ..

echo.
echo Step 4: Rebuilding the app...
echo This will take a few minutes...
call flutter build apk --debug

echo.
echo ========================================
echo Fix Complete!
echo ========================================
echo.
echo Now run the app with: flutter run
echo.
pause
