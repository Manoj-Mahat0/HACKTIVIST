# Offline Navigation System

## Overview

The AR Navigation app now supports comprehensive offline navigation capabilities, allowing users to navigate indoors without requiring an active internet connection. This document describes the implementation and usage of the offline navigation system.

## Features

### 1. Offline Navigation
- Navigate indoors using pre-downloaded building data
- Local pathfinding using A* and Floyd-Warshall algorithms
- Turn-by-turn instructions generated locally
- ETA calculation based on user's walking speed
- Step count estimation based on user's step length

### 2. Offline QR Code Scanning
- Scan QR codes to determine exact location without network
- Supports multiple QR formats:
  - `indoor-nav://building_id/node_id` (simple format)
  - JSON format with full position data
  - Simple node ID format
- Position reset for PDR engine
- Building validation to prevent cross-building errors

### 3. Local Data Management
- Download complete building data for offline use
- Includes: nodes, edges, QR markers, floors, rooms
- Version tracking for cache invalidation
- Automatic update checking when online

### 4. Seamless Online/Offline Transition
- Automatic detection of network status
- Graceful fallback to offline mode
- Visual indicator showing current mode
- Route recalculation when switching modes

## Architecture

### Core Components

```
flutter_app/lib/core/
├── navigation/
│   ├── offline_navigation_service.dart  # Main orchestrator
│   ├── offline_pathfinding.dart         # A* and Floyd-Warshall algorithms
│   └── pathfinding.dart                 # Original A* implementation
├── services/
│   └── offline_qr_service.dart          # Offline QR parsing
├── database/
│   └── local_database.dart              # Hive local storage
└── positioning/
    ├── pdr_engine.dart                  # Pedestrian Dead Reckoning
    └── qr_position_reset.dart           # QR-based position reset
```

### Data Flow

1. **Building Download**
   ```
   API → OfflineRepository → LocalDatabase (Hive)
   ```

2. **Offline Route Calculation**
   ```
   User Request → OfflineNavigationService → OfflinePathfinding → RouteSteps
   ```

3. **QR Code Scanning**
   ```
   Camera → QR Data → OfflineQRService → LocalDatabase → Position Update
   ```

## Usage

### Downloading Building Data

```dart
final offlineRepo = getIt<OfflineRepository>();

// Download building for offline use
final result = await offlineRepo.downloadBuildingForOffline(
  buildingId,
  onProgress: (progress, status) {
    print('$status: ${(progress * 100).toInt()}%');
  },
);

if (result.success) {
  print('Downloaded ${result.nodeCount} nodes');
}
```

### Checking Offline Availability

```dart
final availability = await offlineRepo.checkOfflineAvailability(buildingId);

if (availability.isAvailable) {
  print('Building available offline');
  print('Nodes: ${availability.nodeCount}');
  print('Markers: ${availability.markerCount}');
} else {
  print('Download required: ${availability.reason}');
}
```

### Calculating Routes Offline

```dart
final offlineNav = OfflineNavigationService(database, pdrEngine);

// Initialize for building
await offlineNav.initializeForBuilding(buildingId);

// Calculate route
final result = await offlineNav.calculateRoute(
  startNodeId: 'node_1',
  endNodeId: 'node_10',
  accessibleOnly: true,  // Avoid stairs
  avoidCrowds: false,
  stepLength: 0.7,       // meters
  walkingSpeed: 1.2,     // m/s
);

if (result.success) {
  for (final instruction in result.instructions!) {
    print('${instruction.instruction} (${instruction.distance}m)');
  }
  print('ETA: ${result.estimatedTime}');
}
```

### Processing QR Codes Offline

```dart
final qrService = OfflineQRService(database);

// Parse QR code
final result = await qrService.parseQRCode(qrData, buildingId);

if (result.success) {
  print('Location: ${result.x}, ${result.y}');
  print('Floor: ${result.floor}');
  
  // Update PDR engine
  pdrEngine.resetPosition(result.x!, result.y!, result.floor!, result.orientation ?? 0);
}
```

## QR Code Format

### Simple Format (Recommended)
```
indoor-nav://building_id/node_id
```

Example: `indoor-nav://bldg_123/node_456`

### JSON Format (Full Data)
```json
{
  "building_id": "bldg_123",
  "node_id": "node_456",
  "x": 10.5,
  "y": 20.3,
  "floor": 1,
  "orientation": 90,
  "label": "Main Entrance",
  "node_type": "entrance"
}
```

## Pathfinding Algorithms

### A* Algorithm
- Used for real-time route calculation
- Supports accessibility constraints
- Crowd avoidance penalties
- O(E log V) complexity

### Floyd-Warshall Precomputation
- Precomputes all-pairs shortest paths
- Called once when building data is loaded
- O(n) path reconstruction
- Ideal for offline use with instant routing

## Storage

### Hive Boxes
- `buildings` - Building metadata
- `floors` - Floor information
- `rooms` - Room data
- `navigation_nodes` - Navigation graph nodes
- `qr_markers` - QR marker positions
- `offline_buildings` - User-created offline buildings
- `sync_logs` - Synchronization history

### Data Size Estimates
- Small building (50 nodes): ~50KB
- Medium building (200 nodes): ~200KB
- Large building (500 nodes): ~500KB

## Error Handling

### Network Errors
- Automatic fallback to offline mode
- User notification of mode change
- Cached data used for navigation

### QR Scan Errors
- Invalid format detection
- Wrong building warning
- Node not found handling

### Route Calculation Errors
- No path found notification
- Fallback to online calculation if available
- Clear error messages

## Best Practices

1. **Download buildings before going offline**
   - Use the Offline Downloads page
   - Check for updates periodically

2. **Keep QR codes visible**
   - Scan QR codes at key locations
   - Helps maintain accurate position

3. **Configure walking parameters**
   - Set step length for accurate ETA
   - Adjust walking speed as needed

4. **Use accessibility options**
   - Enable wheelchair mode if needed
   - Routes will avoid stairs

## Limitations

- Floor plan images not cached (only navigation data)
- Real-time crowd data not available offline
- Emergency alerts require network
- Building updates require re-download

## Future Enhancements

- [ ] Floor plan image caching
- [ ] Offline landmark photos
- [ ] Bluetooth beacon support
- [ ] WiFi fingerprinting
- [ ] Incremental updates
