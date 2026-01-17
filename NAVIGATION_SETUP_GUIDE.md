# Indoor Navigation Setup Guide

## Overview
The indoor navigation system loads navigation data directly from the API. This guide explains the complete workflow.

## Complete Workflow

### Step 1: Create Navigation Points (Admin Only)
**Location:** Admin Dashboard → Coordinate Collection

1. Open the Admin Dashboard from the home page
2. Navigate to "Coordinate Collection"
3. Select the building you want to map
4. Walk through the building and collect coordinate points:
   - Use your device's sensors (GPS, compass, pedometer)
   - Mark important locations (corridors, junctions, entrances, stairs, elevators, exits)
   - Connect nodes by walking between them
   - Add QR markers at key locations for position reset
5. Save the navigation graph to the backend

**What happens:** Navigation nodes and edges are saved to the backend API server.

### Step 2: Use Navigation
**Location:** Buildings → Select Building → Navigate

1. Go to Buildings page
2. Select the building you want to navigate in
3. Tap "Navigate" button
4. The navigation data will be loaded automatically from the API
5. You'll see the Unified Navigation Page with:
   - **Start Location dropdown:** Select where you are
   - **Destination dropdown:** Select where you want to go
   - **Calculate Route button:** Computes the path
   - **Camera Navigation button:** Opens AR navigation view
   - **QR Scanner button:** Scan QR codes to reset your position

## Navigation Features

### Location Selection
- Choose start and end points from dropdown menus
- All navigation nodes created in Step 1 will appear here
- Nodes show their floor number and type

### Route Calculation
- Calculates the shortest path between start and end points
- Uses the backend API: `/indoor/buildings/{building_id}/indoor-graph/route`
- Shows number of waypoints and estimated time

### Camera Navigation
- Opens device camera for AR-based navigation
- Uses PDR (Pedestrian Dead Reckoning) to track your movement
- Shows current position and destination
- Provides turn-by-turn guidance

### QR Code Position Reset
- Scan QR codes placed at known locations
- Instantly resets your position to the scanned location
- Provides 0.5m accuracy
- QR codes follow format: `indoor-nav://building_id/node_id`
- Automatically recalculates route from new position

## Troubleshooting

### "No Navigation Data" Warning
**Problem:** The unified navigation page shows "No Navigation Data" warning.

**Solution:**
1. Verify navigation points were created in Admin → Coordinate Collection
2. Ensure the navigation graph was saved successfully
3. Check that you selected the correct building
4. Verify you have internet connection to load data from API

### Empty Dropdowns
**Problem:** Start/End location dropdowns are empty.

**Cause:** No navigation nodes exist for this building in the backend.

**Solution:** 
1. Go to Admin Dashboard → Coordinate Collection
2. Select the building
3. Create navigation points by walking through the building
4. Save the navigation graph
5. Return to the navigation page and reload

### QR Scanner Not Working
**Problem:** QR codes not being recognized.

**Solution:**
1. Ensure QR codes follow the correct format: `indoor-nav://building_id/node_id`
2. Check camera permissions are granted
3. Ensure good lighting when scanning
4. Hold camera steady and at appropriate distance

### Route Not Calculating
**Problem:** "No route found" error.

**Cause:** Nodes are not properly connected.

**Solution:**
1. Go back to Coordinate Collection
2. Ensure nodes are connected by walking between them
3. Check that there's a valid path between start and end points
4. Re-save the navigation graph
5. Try calculating the route again

## Data Flow

```
Admin Creates Nodes → Backend API → Navigation Page Loads Data → Route Calculation
     (Step 1)                              (Step 2)
```

## API Endpoints Used

1. **Get Navigation Graph:** `GET /indoor/buildings/{building_id}/indoor-graph`
   - Returns all nodes and edges for a building
   - Used to populate the location dropdowns

2. **Calculate Route:** `GET /indoor/buildings/{building_id}/indoor-graph/route?from_node={id}&to_node={id}`
   - Calculates shortest path between two nodes
   - Returns path, total steps, and ETA

## Important Notes

1. **Online Required:** Navigation data is loaded from the API (requires internet)
2. **Admin Required:** Only admin users can create navigation points
3. **Real-time:** Changes to navigation graph are immediately available
4. **No Download:** No need to download building data to device
5. **Automatic Updates:** Always uses the latest navigation data from server

## Technical Details

### Navigation Node Properties (from API)
- `id`: Unique identifier
- `label`: Display name
- `latitude`: X coordinate
- `longitude`: Y coordinate
- `floor_number`: Floor level
- `node_type`: Type (corridor, junction, entrance, stairs, elevator, exit)
- `edges`: List of connected nodes with steps and direction
- `qr_code`: QR code content (format: `indoor-nav://building_id/node_id`)
- `is_emergency_exit`: Emergency exit flag
- `is_accessible`: Wheelchair accessible flag

### Route Response (from API)
- `path`: Array of node IDs forming the route
- `total_steps`: Total number of steps
- `directions`: Turn-by-turn directions
- `eta`: Estimated time of arrival with formatted time

### PDR Engine
- Uses device sensors (accelerometer, gyroscope, magnetometer)
- Tracks steps and heading
- Estimates position based on step length and direction
- Can be reset to precise location via QR scanning
- Provides continuous position updates during navigation

## Best Practices

1. **Create Dense Node Network:** More nodes = better navigation accuracy
2. **Mark Key Locations:** Entrances, stairs, elevators, exits
3. **Add QR Markers:** Place at strategic locations for position reset
4. **Test Routes:** Walk the routes to verify connectivity
5. **Update Regularly:** Keep navigation data current as building changes
6. **Use QR Codes:** Scan QR codes periodically to maintain accuracy
7. **Check Connectivity:** Ensure internet connection when loading navigation data
