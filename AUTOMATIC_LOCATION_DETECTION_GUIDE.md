# Automatic Location Detection Implementation Guide

## Overview
Implemented automatic location detection that eliminates the need for manual start position selection. The system uses device sensors (GPS, compass, accelerometer, gyroscope, magnetometer) combined with PDR (Pedestrian Dead Reckoning) to automatically detect and track the user's position.

## Architecture

### Components

#### 1. LocationDetectionService (`location_detection_service.dart`)
**Purpose:** Core service for automatic location detection using sensor fusion

**Key Features:**
- Multi-sensor fusion (GPS, compass, accelerometer, gyroscope, magnetometer)
- Building context awareness
- Confidence scoring (0.0 to 1.0)
- Node snapping for accuracy
- Floor detection from altitude and accelerometer
- Stationary detection
- Real-time position updates

**Sensors Used:**
- **GPS**: Primary position source (outdoor/near windows)
- **Compass**: Heading detection
- **Accelerometer**: Movement and floor change detection
- **Gyroscope**: Movement refinement
- **Magnetometer**: Heading calibration

**Detection Process:**
1. Initialize sensors and request permissions
2. Set building context (nodes, bounds)
3. Start GPS tracking with high accuracy
4. Monitor compass for heading
5. Track accelerometer for movement/floor changes
6. Fuse sensor data for position estimate
7. Snap to nearest node if within threshold (3m)
8. Calculate confidence score
9. Notify callbacks with detected location

**Confidence Calculation:**
- GPS fix: +40%
- Heading data: +20%
- Floor detection: +20%
- Recent update (<5s): +20%
- Total: 0-100%

#### 2. Enhanced Unified Navigation Page
**Changes Made:**
- Added `LocationDetectionService` integration
- Auto-location toggle switch
- Location detection status display
- Confidence indicator
- Automatic route recalculation when off-route
- Continuous position tracking during navigation
- Fallback to manual selection

### User Interface

#### Auto-Location Toggle
```dart
SwitchListTile(
  title: 'Auto-Detect Start Location',
  subtitle: Status message,
  value: _useAutoLocation,
  onChanged: _toggleAutoLocation,
)
```

**States:**
- **ON + Detecting**: "Detecting your location..."
- **ON + Detected**: "Using detected location"
- **OFF**: "Select start location manually"

#### Location Status Card
Shows when location is detected:
- Location name/label
- Confidence percentage
- Floor number
- Color-coded by confidence:
  - Green: >70% confidence
  - Orange: 40-70% confidence
  - Red: <40% confidence

#### Start Location Dropdown
- Hidden when auto-location is enabled
- Visible when auto-location is disabled
- Allows manual selection as fallback

## User Flow

### Automatic Mode (Default)

1. **User opens navigation page**
   - System loads navigation nodes from API
   - Auto-location toggle is ON by default

2. **Location detection starts automatically**
   - Requests location permissions
   - Initializes sensors
   - Sets building context
   - Begins detecting position

3. **Location detected**
   - Status card appears showing:
     - Detected location
     - Confidence level
     - Floor number
   - Start node automatically set

4. **User selects destination**
   - Only destination dropdown is shown
   - Start location is auto-detected

5. **Calculate route**
   - Uses detected location as start
   - Finds nearest node for API call
   - Calculates route from nearest node to destination

6. **Start navigation**
   - Continuous position tracking begins
   - Route updates if user deviates
   - Auto-recalculation when off-route

### Manual Mode (Fallback)

1. **User toggles auto-location OFF**
   - Location detection stops
   - Start location dropdown appears

2. **User selects start and destination**
   - Manual selection from dropdowns

3. **Calculate and navigate**
   - Standard route calculation
   - No automatic tracking

### QR Code Fallback

1. **Low confidence or detection failure**
   - System shows warning
   - Suggests scanning QR code

2. **User scans QR code**
   - Position instantly reset to QR location
   - High confidence (100%)
   - Can continue with auto-location

## API Integration

### Route Calculation with Auto-Location

**Endpoint:** `GET /indoor/buildings/{building_id}/indoor-graph/route`

**Parameters:**
- `from_node`: Nearest node to detected location
- `to_node`: Selected destination node

**Process:**
1. Get detected location (x, y, floor)
2. Find nearest node using `findNearestNode()`
3. Use nearest node ID for API call
4. Calculate route from nearest node to destination

**Example:**
```dart
// Detected location: (45.2, 67.8, Floor 2)
// Nearest node: "node_123" at (45.0, 68.0, Floor 2)
// API call: /route?from_node=node_123&to_node=node_456
```

### Off-Route Detection and Recalculation

**Check Interval:** Every 5 seconds during navigation

**Process:**
1. Get current detected position
2. Calculate perpendicular distance to route segments
3. If distance > 10m from any segment: OFF-ROUTE
4. Automatically recalculate route from current position

**API Call:**
```dart
// User deviated from route
// New detected location: (52.1, 71.3, Floor 2)
// Find nearest node: "node_789"
// Recalculate: /route?from_node=node_789&to_node=node_456
```

## Sensor Fusion Algorithm

### Position Estimation

**GPS + PDR Fusion:**
```dart
final gpsWeight = isStationary() ? 0.8 : 0.3;
final pdrWeight = 1.0 - gpsWeight;

currentX = (gpsX * gpsWeight) + (pdrX * pdrWeight);
currentY = (gpsY * gpsWeight) + (pdrY * pdrWeight);
```

**Rationale:**
- GPS more reliable when stationary
- PDR more reliable when moving (GPS lags)

### Floor Detection

**Method 1: Altitude (GPS)**
```dart
floor = (altitude - baseAltitude) / floorHeight
// floorHeight = 3.5m average
```

**Method 2: Accelerometer (Stairs/Elevator)**
```dart
// High Z-axis variance indicates vertical movement
if (zVariance > 2.0) {
  status = FloorChanging
}
```

### Heading Calculation

**Circular Averaging:**
```dart
sumSin = Σ sin(heading_i)
sumCos = Σ cos(heading_i)
avgHeading = atan2(sumSin/n, sumCos/n)
```

**Why:** Prevents issues with 0°/360° boundary

### Node Snapping

**Threshold:** 3 meters

**Process:**
1. Find all nodes on current floor
2. Calculate distance to each node
3. If nearest node < 3m: snap to node
4. Update position to node coordinates

**Benefits:**
- Corrects GPS drift
- Aligns with navigation graph
- Improves route calculation

## Error Handling

### Permission Denied
```dart
onDetectionError?.call('Location permissions not granted');
// Fallback: Show manual selection
```

### GPS Unavailable (Indoor)
```dart
// Use node estimation
_estimateFromNodes();
confidence = 0.3; // Low confidence
```

### Low Confidence
```dart
if (confidence < 0.4) {
  _showWarning('Low confidence. Scan QR code for accuracy.');
}
```

### Sensor Failure
```dart
// Graceful degradation
// Continue with available sensors
// Reduce confidence score
```

## Performance Optimization

### Update Intervals
- GPS: Every 5 meters or 2 seconds
- Compass: Continuous (buffered)
- Accelerometer: Continuous (buffered)
- Position Estimation: Every 2 seconds
- Off-Route Check: Every 5 seconds

### Buffer Sizes
- Heading: 10 samples
- Altitude: 10 samples
- Accelerometer: 50 samples

### Memory Management
- Circular buffers (FIFO)
- Automatic cleanup of old data
- Dispose subscriptions on stop

## Testing Scenarios

### Scenario 1: Outdoor Start
1. User opens app outside building
2. GPS gets accurate fix
3. High confidence (>80%)
4. User enters building
5. GPS degrades, PDR takes over
6. Confidence remains medium (50-70%)

### Scenario 2: Indoor Start
1. User opens app inside building
2. GPS unavailable or low accuracy
3. System estimates from first node
4. Low confidence (30%)
5. User scans QR code
6. Position reset, high confidence (100%)

### Scenario 3: Floor Change
1. User navigating on Floor 1
2. Route requires going to Floor 2
3. User takes stairs
4. Accelerometer detects vertical movement
5. Altitude increases
6. Floor updated to 2
7. Route continues on Floor 2

### Scenario 4: Off-Route
1. User following route
2. User takes wrong turn
3. Position deviates >10m from route
4. System detects off-route
5. Shows warning
6. Automatically recalculates route
7. New route from current position

## Configuration

### Constants (Adjustable)
```dart
static const double _gpsAccuracyThreshold = 20.0; // meters
static const double _floorHeightMeters = 3.5; // meters
static const Duration _updateInterval = Duration(seconds: 2);
static const int _minSamplesForConfidence = 5;
const snapThreshold = 3.0; // meters
const offRouteThreshold = 10.0; // meters
```

### Weights
```dart
// GPS vs PDR
gpsWeight = isStationary ? 0.8 : 0.3

// Confidence components
GPS: 40%
Heading: 20%
Floor: 20%
Recency: 20%
```

## Dependencies Added

### pubspec.yaml
```yaml
sensors_plus: ^3.0.0  # Accelerometer, gyroscope, magnetometer
```

**Existing:**
- `geolocator` - GPS
- `flutter_compass` - Compass
- `pedometer` - Step counter
- `permission_handler` - Permissions

## Integration with Existing Features

### PDR Engine
- Location detection uses PDR for position refinement
- PDR position fused with GPS
- PDR reset when QR scanned or GPS fix obtained

### AR Navigation
- Detected location used as start point
- Continuous tracking during AR navigation
- Real-time position updates to AR overlays
- Off-route detection triggers recalculation

### QR Scanning
- QR scan resets detected location
- Sets confidence to 100%
- Updates PDR engine position
- Can be used anytime during navigation

## Future Enhancements

### 1. WiFi Fingerprinting
- Use WiFi RSSI for indoor positioning
- Build fingerprint database
- Improve accuracy to <2m

### 2. Bluetooth Beacons
- Deploy BLE beacons at key locations
- Triangulation for precise positioning
- Sub-meter accuracy

### 3. Visual Positioning
- Use camera + ML for landmark recognition
- Match camera view to known locations
- Complement sensor-based positioning

### 4. Crowd-Sourced Calibration
- Collect position data from users
- Improve GPS-to-building coordinate mapping
- Refine floor height estimates

### 5. Machine Learning
- Learn user movement patterns
- Predict destination
- Optimize route suggestions

### 6. Multi-Building Support
- Detect building transitions
- Switch building context automatically
- Seamless cross-building navigation

## Troubleshooting

### Issue: Low Confidence
**Causes:**
- Indoor location (no GPS)
- Metal structures (compass interference)
- First time in building

**Solutions:**
- Scan QR code
- Move near window for GPS
- Use manual selection

### Issue: Wrong Floor
**Causes:**
- Inaccurate altitude
- Missed floor change detection

**Solutions:**
- Scan QR code on correct floor
- Manually verify floor in status card
- Recalibrate by going to known location

### Issue: Position Jumps
**Causes:**
- GPS multipath
- Sensor noise
- Poor calibration

**Solutions:**
- Increase snap threshold
- Adjust GPS/PDR weights
- Add more smoothing

### Issue: Off-Route Constantly
**Causes:**
- Inaccurate position
- Narrow corridors
- Threshold too strict

**Solutions:**
- Increase off-route threshold
- Scan QR code for reset
- Use manual mode

## Conclusion

The automatic location detection system provides a seamless navigation experience by:
- Eliminating manual start position selection
- Continuously tracking user position
- Automatically recalculating routes when needed
- Providing confidence feedback
- Offering fallback options (manual, QR)

The system is production-ready with proper error handling, performance optimization, and user feedback. It integrates seamlessly with existing AR navigation features and maintains compatibility with all backend APIs.
