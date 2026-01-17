# Coordinate Collection 3D View Feature

## Overview
Added a sophisticated toggle feature to switch between 2D and 3D views in the Indoor Graph Builder (Coordinate Collection Page), utilizing the advanced Building3DViewer component.

## Features Implemented

### 1. View Toggle Button
- **Location**: Top-right corner of the floor view
- **States**: 
  - 2D Mode: Shows map icon with "2D" label (black background)
  - 3D Mode: Shows 3D cube icon with "3D" label (orange background)
- **Interaction**: Tap to toggle between views

### 2. 2D View (Default)
- **Grid**: Simple orthogonal grid with 30px spacing
- **Nodes**: Flat circular nodes with icons
- **Connections**: Straight lines between connected nodes
- **Colors**: 
  - Orange for accessible paths
  - Grey for non-accessible paths
  - Green for nodes with connections
  - Red for isolated nodes

### 3. 3D View (Advanced - Using Building3DViewer)
- **Rendering**: Professional 3D building visualization with:
  - Proper perspective projection
  - Z-depth sorting (painter's algorithm)
  - Room-based representation of nodes
  - Floor slabs with thickness
  - Realistic shadows and lighting
  
- **Node Representation**:
  - Nodes converted to 3D rooms with proper dimensions
  - Different room types based on node type:
    - Entrance/Exit → Lobby (cyan)
    - Elevator → Elevator shaft (red with arrows)
    - Stairs → Stepped structure (orange)
    - Bathroom → Restroom (purple)
    - Room → Office (blue)
  - Automatic distribution across floor space
  
- **Interactive Controls**:
  - **Rotation**: Drag to rotate the building
  - **Zoom**: Pinch to zoom in/out
  - **Preset Views**:
    - Isometric view (default)
    - Top view (plan view)
    - Front view
  - **Reset**: Return to default view
  
- **Visual Features**:
  - Grid pattern on floor surfaces
  - Color-coded room types
  - Room labels with names
  - Smooth animations
  - Professional lighting and shadows

### 4. 3D Control Panel
- **Location**: Right side of 3D view
- **Controls**:
  - Isometric View button
  - Top View button
  - Zoom In button
  - Zoom Out button
  - Reset button
- **Style**: Dark semi-transparent background with white icons

## Technical Implementation

### Dependencies
```dart
import 'package:indoor_navigation/features/admin/presentation/widgets/building_3d_viewer.dart';
```

### State Management
```dart
bool _is3DView = false; // Toggle state
BuildingInteractionController? _3dController; // 3D view controller
```

### Key Components

#### 1. Building3DViewer Integration
- Uses `Building3DPainter` for rendering
- `BuildingInteractionController` for interactions
- Converts IndoorNodes to Room3D objects
- Creates Floor3D and Building3D structures

#### 2. Node to Room Conversion
```dart
RoomType _getNodeRoomType(String nodeType) {
  // Maps node types to room types for 3D visualization
}
```

#### 3. Interactive Gestures
- Scale gestures for zoom
- Drag gestures for rotation
- Smooth animations via AnimatedBuilder

### Custom Painters (from Building3DViewer)
1. `Building3DPainter` - Main 3D rendering engine
   - Handles perspective projection
   - Z-depth sorting
   - Floor and room rendering
   - Special handling for stairs and elevators

## Visual Differences

### 2D View
- Flat, top-down perspective
- Simple grid background
- Basic node rendering
- Straight connection lines
- Minimal visual effects

### 3D View
- Full 3D perspective with rotation
- Professional building visualization
- Rooms instead of simple nodes
- Realistic depth and shadows
- Interactive camera controls
- Multiple viewing angles
- Color-coded room types
- Professional architectural appearance

## User Experience
- Seamless toggle between views
- No data loss when switching
- Maintains current floor selection
- Intuitive 3D controls
- Professional visualization
- Smooth animations
- Touch-friendly interactions

## Color Scheme (Dark Theme)
- Background: #1E1E1E (surfaceDark)
- Primary Accent: #FF6B00 (primaryOrange)
- Room Colors: Type-specific (blue, green, purple, orange, red, cyan, brown, amber)
- Floor: Light grey with grid pattern
- Shadows: Black with varying opacity
- Labels: White text on colored backgrounds

## Performance Considerations
- Efficient custom painter rendering
- Z-depth sorting for correct layering
- Minimal state changes on toggle
- Reuses existing node data
- Smooth 60fps animations
- Optimized gesture handling

## Advantages Over Simple 3D
1. **Professional Appearance**: Looks like architectural software
2. **Better Spatial Understanding**: Rooms show actual space usage
3. **Interactive Controls**: Multiple viewing angles
4. **Visual Hierarchy**: Clear distinction between floors and rooms
5. **Type Differentiation**: Color-coded room types
6. **Realistic Rendering**: Proper shadows and perspective
7. **Smooth Interactions**: Professional-grade gesture handling

## Future Enhancements
- Multi-floor stacking in 3D view
- Connection lines between rooms in 3D
- Room editing in 3D mode
- Export 3D view as image
- VR/AR preview mode
- Lighting controls
- Material customization
