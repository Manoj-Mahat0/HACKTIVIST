@echo off
echo ========================================
echo Indoor Navigation Flutter App
echo ========================================
echo.

cd flutter_app

echo Checking Flutter installation...
flutter doctor
echo.

echo Getting dependencies...
flutter pub get
echo.

echo Checking connected devices...
flutter devices
echo.

echo Building and running app on connected device...
flutter run --release
