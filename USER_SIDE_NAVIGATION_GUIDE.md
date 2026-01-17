# User-Side Indoor Navigation Implementation Guide

## Overview
This guide explains how to use the indoor navigation system from the user side, leveraging the indoor_graph.py backend API to provide turn-by-turn navigation, accessibility features, crowd avoidance, and more.

## Table of Contents
1. [API Endpoints](#api-endpoints)
2. [Data Structures](#data-structures)
3. [Implementation Steps](#implementation-steps)
4. [Feature Integration](#feature-integration)
5. [Code Examples](#code-examples)

---

## API Endpoints

### 1. Get Indoor Graph
**Endpoint**: `GET /indoor/buildings/{building_id}/indoor-graph`

**Purpose**: Retrieve all navigation nodes and edges for a building

**Response**:
```json
{
  "nodes": [
    {
      "id": "node_123",
      "label": "Main Entrance",
      "latitude": 40.7128,
      "longitude": -74.0060,
      "floor_number": 1,
      "node_type": "entrance",
      "image_url": "https://...",
      "qr_code": "indoor-nav://building_id/node_123",
      "landmark_description": "Glass doors with company logo",
      "is_emergency_exit": false,
      "edges": [
        {
          "to_node_id": "node_124",
          "steps": 50,
          "direction": "N",
          "is_accessible": true,
          "crowd_level": 2
        }
      ]
    }
  ],
  "edges": [...],
  "metadata": {...}
}
```

### 2. Calculate Route
**Endpoint**: `GET /indoor/buildings/{building_id}/indoor-graph/route`

**Parameters**:
- `start_node_id`: Starting node ID
- `end_node_id`: Destination node ID
- `accessible`: Boolean (wheelchair-friendly route)
- `avoid_crowds`: Boolean (avoid crowded areas)
- `step_length`: Float (user's step length in meters)
- `walking_speed`: Float (user's walking speed in m/s)

**Response**:
```json
{
  "path": ["node_123", "node_124", "node_125"],
  "total_steps": 150,
  "total_distance_meters": 105.0,
  "estimated_time_seconds": 87.5,
  "instructions": [
    {
      "node_id": "node_123",
      "instruction": "Start at Main Entrance",
      "direction": "N",
      "steps_to_next": 50,
      "distance_meters": 35.0,
      "landmark": "Glass doors with company logo",
      "image_url": "https://...",
      "haptic_pattern": "start"
    },
    {
      "node_id": "node_124",
      "instruction": "Turn right at the corridor",
      "direction": "E",
      "steps_to_next": 100,
      "distance_meters": 70.0,
      "landmark": "Water fountain on left",
      "image_url": "https://...",
      "haptic_pattern": "turn_right"
    }
  ],
  "floor_changes": [
    {
      "at_node": "node_125",
      "from_floor": 1,
      "to_floor": 2,
      "method": "elevator"
    }
  ]
}
```

### 3. Smart Route (with Live Conditions)
**Endpoint**: `GET /indoor/buildings/{building_id}/indoor-graph/smart-route`

**Parameters**: Same as Calculate Route + considers live crowd data

**Purpose**: Get optimal route considering real-time crowd density and blocked paths

### 4. QR Code Lookup
**Endpoint**: `GET /indoor/buildings/{building_id}/indoor-graph/qr-lookup`

**Parameters**:
- `qr_data`: QR code string (e.g., "indoor-nav://building_id/node_123")

**Response**:
```json
{
  "node_id": "node_123",
  "label": "Main Entrance",
  "latitude": 40.7128,
  "longitude": -74.0060,
  "floor_number": 1,
  "node_type": "entrance"
}
```

### 5. Emergency Exit Route
**Endpoint**: `GET /indoor/buildings/{building_id}/indoor-graph/emergency-exit`

**Parameters**:
- `current_node_id`: User's current position

**Purpose**: Find nearest emergency exit with fastest route

### 6. Favorites & Recent Routes
- `POST /indoor/favorites` - Save favorite destination
- `GET /indoor/favorites` - Get user's favorites
- `POST /indoor/recent-routes` - Save recent route
- `GET /indoor/recent-routes` - Get recent routes

### 7. Share Location
- `POST /indoor/share-location` - Generate shareable link
- `GET /indoor/share-location/{share_id}` - Get shared location

### 8. Live Conditions
**Endpoint**: `GET /indoor/buildings/{building_id}/live-conditions`

**Response**:
```json
{
  "congestion": {
    "node_123_to_node_124": {
      "crowd_level": 3,
      "reports_count": 5,
      "last_updated": "2024-01-16T10:30:00"
    }
  },
  "blocked_paths": {
    "node_125_to_node_126": {
      "confirmed": true,
      "reports_count": 4,
      "reported_at": "2024-01-16T10:00:00"
    }
  }
}
```

### 9. Haptic Patterns
**Endpoint**: `GET /indoor/haptic-patterns`

**Response**:
```json
{
  "start": [100, 50, 100],
  "turn_left": [50, 30, 50, 30, 50],
  "turn_right": [100, 50, 100, 50, 100],
  "arrived": [200, 100, 200, 100, 200],
  "floor_change": [150, 75, 150, 75, 150],
  "warning": [50, 25, 50, 25, 50, 25, 50]
}
```

---

## Data Structures

### Node Types
- `waypoint`: Generic navigation point
- `room`: Room or office
- `entrance`: Building entrance
- `exit`: Building exit
- `elevator`: Elevator location
- `stairs`: Staircase location
- `bathroom`: Restroom location
- `emergency_exit`: Emergency exit

### Node Properties
```dart
class IndoorNode {
  String id;
  String label;
  double latitude;
  double longitude;
  int floorNumber;
  String nodeType;
  String? imageUrl;
  String? qrCode;
  String? landmarkDescription;
  bool isEmergencyExit;
  List<Edge> edges;
}
```

### Edge Properties
```dart
class Edge {
  String toNodeId;
  int steps;
  String direction; // N, S, E, W, NE, NW, SE, SW, UP, DOWN
  bool isAccessible;
  int crowdLevel; // 0-5
}
```

---

## Implementation Steps

### Step 1: Load Building Nodes

```dart
Future<List<IndoorNode>> loadBuildingNodes(String buildingId) async {
  final response = await apiClient.get(
    '/indoor/buildings/$buildingId/indoor-graph'
  );
  
  if (response.statusCode == 200) {
    final data = response.data;
    return (data['nodes'] as List)
        .map((node) => IndoorNode.fromJson(node))
        .toList();
  }
  throw Exception('Failed to load nodes');
}
```

### Step 2: Display Nodes in Dropdown

```dart
Widget buildNodeDropdown(List<IndoorNode> nodes) {
  return DropdownButton<IndoorNode>(
    items: nodes.map((node) {
      return DropdownMenuItem(
        value: node,
        child: Row(
          children: [
            Icon(_getNodeIcon(node.nodeType)),
            SizedBox(width: 8),
            Text('${node.label} (Floor ${node.floorNumber})'),
          ],
        ),
      );
    }).toList(),
    onChanged: (node) {
      setState(() => selectedNode = node);
    },
  );
}

IconData _getNodeIcon(String nodeType) {
  switch (nodeType) {
    case 'entrance': return Icons.door_front_door;
    case 'exit': return Icons.exit_to_app;
    case 'elevator': return Icons.elevator;
    case 'stairs': return Icons.stairs;
    case 'bathroom': return Icons.wc;
    case 'room': return Icons.meeting_room;
    case 'emergency_exit': return Icons.emergency;
    default: return Icons.location_on;
  }
}
```

### Step 3: Calculate Route

```dart
Future<NavigationRoute> calculateRoute({
  required String buildingId,
  required String startNodeId,
  required String endNodeId,
  bool accessible = false,
  bool avoidCrowds = false,
}) async {
  final response = await apiClient.get(
    '/indoor/buildings/$buildingId/indoor-graph/route',
    queryParameters: {
      'start_node_id': startNodeId,
      'end_node_id': endNodeId,
      'accessible': accessible,
      'avoid_crowds': avoidCrowds,
      'step_length': userStepLength,
      'walking_speed': userWalkingSpeed,
    },
  );
  
  if (response.statusCode == 200) {
    return NavigationRoute.fromJson(response.data);
  }
  throw Exception('Failed to calculate route');
}
```

### Step 4: Display Turn-by-Turn Instructions

```dart
Widget buildInstructionsList(List<Instruction> instructions) {
  return ListView.builder(
    itemCount: instructions.length,
    itemBuilder: (context, index) {
      final instruction = instructions[index];
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            child: Text('${index + 1}'),
          ),
          title: Text(instruction.instruction),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${instruction.stepsToNext} steps (${instruction.distanceMeters.toStringAsFixed(1)}m)'),
              if (instruction.landmark != null)
                Text('Landmark: ${instruction.landmark}',
                    style: TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
          trailing: Icon(_getDirectionIcon(instruction.direction)),
        ),
      );
    },
  );
}
```

### Step 5: QR Code Scanning for Position Reset

```dart
Future<IndoorNode?> scanQRCode() async {
  final qrData = await MobileScanner.scan();
  
  if (qrData != null && qrData.startsWith('indoor-nav://')) {
    final parts = qrData.replaceFirst('indoor-nav://', '').split('/');
    final buildingId = parts[0];
    final nodeId = parts[1];
    
    final response = await apiClient.get(
      '/indoor/buildings/$buildingId/indoor-graph/qr-lookup',
      queryParameters: {'qr_data': qrData},
    );
    
    if (response.statusCode == 200) {
      return IndoorNode.fromJson(response.data);
    }
  }
  return null;
}

// Use scanned node to reset position
void resetPosition(IndoorNode node) {
  setState(() {
    currentPosition = node;
    currentNodeId = node.id;
  });
  
  // Reset PDR engine
  pdrEngine.resetPosition(
    node.latitude,
    node.longitude,
    node.floorNumber,
    0.0, // heading
  );
  
  // Recalculate route if destination is set
  if (destinationNodeId != null) {
    calculateRoute(
      buildingId: buildingId,
      startNodeId: currentNodeId!,
      endNodeId: destinationNodeId!,
    );
  }
}
```

---

## Feature Integration

### 1. Accessibility Routes

```dart
// Enable accessibility mode
bool accessibilityMode = true;

final route = await calculateRoute(
  buildingId: buildingId,
  startNodeId: startNodeId,
  endNodeId: endNodeId,
  accessible: accessibilityMode, // Only wheelchair-accessible paths
);
```

### 2. Crowd Avoidance

```dart
// Enable crowd avoidance
bool avoidCrowds = true;

final route = await calculateRoute(
  buildingId: buildingId,
  startNodeId: startNodeId,
  endNodeId: endNodeId,
  avoidCrowds: avoidCrowds, // Avoid crowded areas
);

// Or use smart route for real-time conditions
final smartRoute = await apiClient.get(
  '/indoor/buildings/$buildingId/indoor-graph/smart-route',
  queryParameters: {
    'start_node_id': startNodeId,
    'end_node_id': endNodeId,
  },
);
```

### 3. ETA Calculation

```dart
// ETA is automatically calculated in route response
void displayETA(NavigationRoute route) {
  final eta = route.estimatedTimeSeconds;
  final minutes = (eta / 60).floor();
  final seconds = (eta % 60).floor();
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Estimated Time'),
      content: Text('$minutes min $seconds sec'),
    ),
  );
}
```

### 4. Haptic Feedback

```dart
class HapticNavigationService {
  Map<String, List<int>>? _patterns;
  
  Future<void> loadPatterns() async {
    final response = await apiClient.get('/indoor/haptic-patterns');
    _patterns = Map<String, List<int>>.from(response.data);
  }
  
  Future<void> playPattern(String patternName) async {
    final pattern = _patterns?[patternName];
    if (pattern != null) {
      for (int duration in pattern) {
        await HapticFeedback.vibrate();
        await Future.delayed(Duration(milliseconds: duration));
      }
    }
  }
  
  // Use during navigation
  void onInstructionReached(Instruction instruction) {
    playPattern(instruction.hapticPattern);
  }
}
```

### 5. Emergency Exit

```dart
Future<void> findEmergencyExit() async {
  final response = await apiClient.get(
    '/indoor/buildings/$buildingId/indoor-graph/emergency-exit',
    queryParameters: {'current_node_id': currentNodeId},
  );
  
  if (response.statusCode == 200) {
    final route = NavigationRoute.fromJson(response.data);
    
    // Show emergency route with high priority UI
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: Row(
          children: [
            Icon(Icons.emergency, color: Colors.white),
            SizedBox(width: 8),
            Text('Emergency Exit Route', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Nearest exit: ${route.instructions.last.landmark}\n'
          'Distance: ${route.totalDistanceMeters}m\n'
          'Time: ${route.estimatedTimeSeconds}s',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
    
    // Start navigation
    startNavigation(route);
  }
}
```

### 6. Favorites

```dart
Future<void> saveFavorite(String nodeId, String label) async {
  await apiClient.post('/indoor/favorites', data: {
    'node_id': nodeId,
    'label': label,
    'building_id': buildingId,
  });
}

Future<List<Favorite>> loadFavorites() async {
  final response = await apiClient.get('/indoor/favorites');
  return (response.data as List)
      .map((f) => Favorite.fromJson(f))
      .toList();
}
```

### 7. Share Location

```dart
Future<String> shareCurrentLocation() async {
  final response = await apiClient.post('/indoor/share-location', data: {
    'building_id': buildingId,
    'node_id': currentNodeId,
    'floor_number': currentFloor,
    'message': 'Meet me here!',
  });
  
  final shareId = response.data['share_id'];
  final shareUrl = 'https://app.example.com/location/$shareId';
  
  await Share.share(shareUrl);
  return shareUrl;
}
```

### 8. Live Conditions Display

```dart
Future<void> showLiveConditions() async {
  final response = await apiClient.get(
    '/indoor/buildings/$buildingId/live-conditions'
  );
  
  final conditions = response.data;
  
  // Display crowd levels on map
  for (var entry in conditions['congestion'].entries) {
    final edgeKey = entry.key;
    final crowdLevel = entry.value['crowd_level'];
    
    // Color code paths based on crowd level
    final color = _getCrowdColor(crowdLevel);
    drawPathOnMap(edgeKey, color);
  }
  
  // Show blocked paths
  for (var entry in conditions['blocked_paths'].entries) {
    if (entry.value['confirmed']) {
      markPathAsBlocked(entry.key);
    }
  }
}

Color _getCrowdColor(int level) {
  switch (level) {
    case 0: return Colors.green;
    case 1: return Colors.lightGreen;
    case 2: return Colors.yellow;
    case 3: return Colors.orange;
    case 4: return Colors.deepOrange;
    case 5: return Colors.red;
    default: return Colors.grey;
  }
}
```

---

## Complete Navigation Flow Example

```dart
class NavigationController {
  String? buildingId;
  List<IndoorNode> nodes = [];
  IndoorNode? startNode;
  IndoorNode? endNode;
  NavigationRoute? currentRoute;
  int currentInstructionIndex = 0;
  
  // Step 1: Load building data
  Future<void> initialize(String buildingId) async {
    this.buildingId = buildingId;
    nodes = await loadBuildingNodes(buildingId);
  }
  
  // Step 2: Select start and end
  void selectStart(IndoorNode node) {
    startNode = node;
  }
  
  void selectEnd(IndoorNode node) {
    endNode = node;
  }
  
  // Step 3: Calculate route
  Future<void> calculateRoute({
    bool accessible = false,
    bool avoidCrowds = false,
  }) async {
    if (startNode == null || endNode == null) return;
    
    currentRoute = await apiClient.get(
      '/indoor/buildings/$buildingId/indoor-graph/route',
      queryParameters: {
        'start_node_id': startNode!.id,
        'end_node_id': endNode!.id,
        'accessible': accessible,
        'avoid_crowds': avoidCrowds,
      },
    ).then((r) => NavigationRoute.fromJson(r.data));
    
    currentInstructionIndex = 0;
  }
  
  // Step 4: Start navigation
  void startNavigation() {
    if (currentRoute == null) return;
    
    // Play start haptic
    hapticService.playPattern('start');
    
    // Show first instruction
    showCurrentInstruction();
    
    // Start PDR tracking
    pdrEngine.start();
    
    // Listen for position updates
    pdrEngine.positionStream.listen((position) {
      checkIfReachedNextNode(position);
    });
  }
  
  // Step 5: Navigate through instructions
  void showCurrentInstruction() {
    if (currentRoute == null) return;
    
    final instruction = currentRoute!.instructions[currentInstructionIndex];
    
    // Display instruction
    showInstructionUI(instruction);
    
    // Show landmark photo if available
    if (instruction.imageUrl != null) {
      showLandmarkPhoto(instruction.imageUrl!);
    }
  }
  
  void nextInstruction() {
    if (currentRoute == null) return;
    
    currentInstructionIndex++;
    
    if (currentInstructionIndex >= currentRoute!.instructions.length) {
      // Arrived at destination
      arriveAtDestination();
    } else {
      final instruction = currentRoute!.instructions[currentInstructionIndex];
      
      // Play haptic for turn
      hapticService.playPattern(instruction.hapticPattern);
      
      // Show next instruction
      showCurrentInstruction();
    }
  }
  
  void arriveAtDestination() {
    // Play arrival haptic
    hapticService.playPattern('arrived');
    
    // Show arrival message
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Arrived!'),
        content: Text('You have reached ${endNode!.label}'),
      ),
    );
    
    // Save to recent routes
    saveRecentRoute();
    
    // Stop PDR
    pdrEngine.stop();
  }
  
  // Step 6: QR code position reset
  Future<void> scanQRAndReset() async {
    final node = await scanQRCode();
    if (node != null) {
      resetPosition(node);
      
      // Recalculate route from new position
      startNode = node;
      await calculateRoute();
    }
  }
}
```

---

## Summary

The indoor navigation system provides:

1. **Node-based navigation** with detailed properties (type, floor, landmarks, QR codes)
2. **Multiple routing options** (shortest, accessible, crowd-avoiding, emergency)
3. **Turn-by-turn instructions** with landmarks and photos
4. **Real-time features** (crowd density, blocked paths, live conditions)
5. **User personalization** (step length, walking speed, favorites)
6. **Haptic feedback** for better navigation experience
7. **QR code positioning** for accurate location reset
8. **Offline support** through local database caching

All features are accessible through the REST API endpoints in `indoor_graph.py`, making it easy to integrate into any Flutter or mobile application.
