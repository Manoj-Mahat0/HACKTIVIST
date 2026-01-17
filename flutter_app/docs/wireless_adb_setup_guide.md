# Wireless ADB Connection Guide for Flutter Development

This guide provides step-by-step instructions to establish a wireless ADB connection to your Android device for Flutter development, allowing you to run and debug your app without a USB cable.

## Prerequisites

Before setting up wireless ADB, ensure you have:

1. **ADB installed**: Android Debug Bridge should be in your system PATH (already verified on your system)
2. **Physical Android device** with developer options enabled
3. **USB cable** (initially required to set up wireless connection)
4. **Same WiFi network** for both your computer and Android device
5. **USB debugging enabled** on your Android device
6. **Computer and device connected to the same network**

## Step-by-Step Setup Process

### Step 1: Enable Developer Options and USB Debugging on Your Android Device

1. Go to Settings > About Phone
2. Tap "Build Number" 7 times to enable Developer Options
3. Return to Settings > Developer Options
4. Enable "USB Debugging"
5. Optionally enable "Wireless debugging" (on newer Android versions)

### Step 2: Initial Connection via USB

1. Connect your Android device to your computer via USB cable
2. On your device, accept any RSA fingerprint authorization dialogs that appear
3. Open a terminal/command prompt and run:
   ```
   adb devices
   ```
4. Confirm your device appears in the list as "connected"

### Step 3: Set Up Wireless ADB Connection

1. First, find your device's IP address:
   - Go to Settings > WiFi
   - Tap on your connected network
   - Look for the IP address (typically starts with 192.168.x.x)

2. In terminal, execute the following commands:
   ```
   # Connect to your device via USB first and check its status
   adb devices
   
   # Set your device to listen on TCP/IP on port 5555
   adb tcpip 5555
   
   # Disconnect USB cable now
   # Connect wirelessly using the IP address
   adb connect 192.168.29.247:5555
   ```

### Step 4: Verify Wireless Connection

Run the following command to verify your device is connected wirelessly:
```
adb devices
```

You should see your device listed with "device" status (not "offline" or "unauthorized").

## Specific Steps for Your IP Address (192.168.29.247)

Based on your issue, here are the exact commands to connect to your specific device:

1. Ensure your device is connected via USB initially
2. Execute these commands in order:
   ```
   adb tcpip 5555
   adb disconnect
   adb connect 192.168.29.247:5555
   adb devices
   ```

## Troubleshooting Common Issues

### Issue: "Device not found" Error
**Solutions:**
1. Make sure your device is connected to the same WiFi network as your computer
2. Verify the IP address is correct (check in phone's WiFi settings)
3. Ensure USB debugging is enabled on your device
4. Try restarting ADB server:
   ```
   adb kill-server
   adb start-server
   adb connect 192.168.29.247:5555
   ```

### Issue: "Unauthorized" Status
**Solutions:**
1. On your Android device, look for the RSA fingerprint authorization dialog
2. Tap "Allow" to authorize your computer
3. If the dialog doesn't appear, disable and re-enable USB debugging
4. Revoke USB debugging authorizations and reconnect

### Issue: Connection Drops Frequently
**Solutions:**
1. Check WiFi signal strength on both devices
2. Try using a different port:
   ```
   adb tcpip 5556
   adb connect 192.168.29.247:5556
   ```
3. Restart your router if necessary

### Issue: Cannot Find IP Address
**Solutions:**
1. On Android 11+: Go to Settings > WiFi > tap on your network > expand "IP settings" to reveal IP address
2. Use ADB to find the IP when connected via USB:
   ```
   adb shell ip addr show wlan0
   ```

## Using with Flutter

Once your wireless ADB connection is established, you can run your Flutter app using:
```
flutter devices  # Verify your device is detected
flutter run      # Run your app on the connected device
```

## Alternative Method (Android 11+)

On newer Android versions, you can connect directly without USB:

1. On your device: Settings > Developer Options > Wireless debugging
2. Tap "Pair device with pairing code" 
3. Note the IP, port, and pairing code
4. On your computer: `adb pair <ip>:<port>` and enter the code
5. After pairing, connect with: `adb connect <device_ip>:<device_port>`

## Security Notes

- Wireless ADB is less secure than USB connection
- Only use on trusted networks
- Disconnect when not in use: `adb disconnect <device_ip>:5555`

## Resetting Connection

If you encounter persistent issues:
```
adb kill-server
adb start-server
adb connect 192.168.29.247:5555
```

Remember to maintain the same network connection for both devices to ensure stable wireless debugging.