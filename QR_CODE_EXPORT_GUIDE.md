# Complete QR Code Export & Offline Access Guide

## Overview
This guide provides step-by-step instructions for downloading, exporting, and accessing QR markers from the AR Navigation app's admin panel for offline use.

## 1. Accessing QR Marker Management

### Flutter App (Mobile Admin)
```
1. Open the AR Navigation app
2. Login with admin credentials
3. Navigate to "Admin Dashboard"
4. Select "Coordinate Collection" or "Building Management"
5. Choose your target building from the list
```

### Web Admin Panel
```
1. Open admin-web interface in browser
2. Login with admin credentials  
3. Navigate to "Building Manager" section
4. Select your building
```

## 2. Viewing All QR Markers

### In Coordinate Collection Page
- Each navigation node automatically has a QR code
- QR format: `indoor-nav://{building_id}/{node_id}`
- Tap any node to view details including QR data
- Map shows all nodes with their QR markers

### QR Code Data Structure
```json
{
  "marker_id": "node_1234567890",
  "building_id": "6967635c736d4cbede0bc2d2", 
  "floor": 0,
  "x": 22.8432519,
  "y": 86.2274803,
  "orientation": 180.0
}
```

## 3. Export Methods

### Method 1: Enhanced QR Export Page (New Feature)
```
1. Navigate to Admin Dashboard
2. Select "QR Export" (new page created)
3. Choose your building
4. Select export format:
   - JSON (complete data)
   - CSV (spreadsheet format)
   - PDF (visual report with QR images)
5. Toggle "Include QR Code Images" option
6. Tap "Export All" button
7. File saved to device and shared
```

### Method 2: Graph Export (Existing)
```
1. Go to Coordinate Collection page
2. Select your building
3. Tap "Export Graph" button (⬆️ icon)
4. Complete navigation graph with QR codes copied to clipboard
5. Paste into text file and save
```

### Method 3: Offline Download (Recommended)
```
1. Go to "Offline Downloads" page
2. Find your building in the list
3. Tap "Download" button
4. Complete building data including ALL QR markers downloaded
5. Data stored locally for offline access
```

### Method 4: Backend API Export (New)
```
GET /indoor/buildings/{building_id}/qr-markers/export?format=json
GET /indoor/buildings/{building_id}/qr-markers/export?format=csv

Returns complete QR marker data with node information
```

## 4. Offline Access & Storage

### Local Storage Locations
- **Hive Database**: `qr_markers` box stores all QR marker data
- **App Documents**: Exported files saved to device storage
- **Offline Cache**: Complete building data including QR markers

### Offline Data Structure
```dart
QRMarker {
  String id;              // Unique marker ID
  String buildingId;      // Building reference
  String floorId;         // Floor reference  
  double x;               // X coordinate (latitude)
  double y;               // Y coordinate (longitude)
  double orientationDegrees; // Marker orientation
  String qrData;          // Encoded position data
  String? description;    // Optional description
}
```

## 5. PDR Engine Integration

### QR Code Scanning Process
```
1. User scans QR code during navigation
2. QRPositionReset.processQRCode() validates data
3. PDR engine position reset with high accuracy (0.5m)
4. Continuous tracking resumes from known position
```

### Position Reset Data
```json
{
  "marker_id": "node_123",
  "building_id": "building_456", 
  "floor": 1,
  "x": 22.8432519,
  "y": 86.2274803,
  "orientation": 180.0
}
```

## 6. Step-by-Step Export Process

### For Complete Building QR Export:

**Step 1: Access Export Feature**
```
Admin Dashboard → QR Export → Select Building
```

**Step 2: Configure Export**
```
- Format: JSON (recommended for complete data)
- Include Images: Yes (for visual reference)
- Review marker count
```

**Step 3: Export & Save**
```
- Tap "Export All"
- File automatically saved to device
- Share via email/cloud storage for backup
```

**Step 4: Verify Export**
```
- Open exported file
- Verify all markers present
- Check coordinate accuracy
- Confirm QR data format
```

## 7. Offline Navigation Workflow

### Preparation (Online)
```
1. Export all QR markers for target building
2. Download building for offline use
3. Verify all data synced locally
4. Test QR scanning functionality
```

### During Navigation (Offline)
```
1. Open navigation to destination
2. When lost/uncertain, scan nearby QR code
3. PDR engine resets to accurate position
4. Continue navigation with corrected position
```

## 8. File Formats & Contents

### JSON Export
```json
{
  "building_id": "6967635c736d4cbede0bc2d2",
  "building_name": "Office Complex A",
  "exported_at": "2026-01-16T10:30:00Z",
  "total_markers": 25,
  "qr_markers": [
    {
      "id": "marker_001",
      "building_id": "6967635c736d4cbede0bc2d2",
      "floor_id": "floor_ground",
      "x": 22.8432519,
      "y": 86.2274803,
      "orientation_degrees": 180.0,
      "qr_data": "indoor-nav://6967635c736d4cbede0bc2d2/node_001",
      "description": "Main Entrance",
      "node_info": {
        "node_id": "node_001",
        "label": "Main Entrance",
        "node_type": "entrance",
        "floor_number": 0,
        "is_accessible": true,
        "is_emergency_exit": false
      }
    }
  ]
}
```

### CSV Export
```csv
ID,Building ID,Floor ID,X,Y,Floor Number,QR Data,Description,Node ID,Node Label,Node Type
marker_001,6967635c736d4cbede0bc2d2,floor_ground,22.8432519,86.2274803,0,"indoor-nav://6967635c736d4cbede0bc2d2/node_001","Main Entrance",node_001,Main Entrance,entrance
```

## 9. Troubleshooting

### Common Issues
- **No QR markers found**: Ensure building has navigation nodes created
- **Export fails**: Check device storage space and permissions
- **QR scan fails**: Verify QR data format and marker exists in local database
- **Position reset fails**: Check PDR engine initialization and sensor availability

### Verification Steps
```
1. Check marker count matches expected nodes
2. Verify QR data format is correct
3. Test QR scanning with exported data
4. Confirm offline database contains markers
5. Validate coordinate accuracy
```

## 10. Best Practices

### For Admins
- Export QR markers after any building updates
- Keep backup copies of all QR data
- Test QR scanning functionality regularly
- Document marker locations and purposes

### For Navigation Users
- Download buildings before going offline
- Carry printed QR codes as backup
- Scan QR codes when position seems inaccurate
- Report any QR scanning issues to admin

## Files Created/Modified

1. **New QR Export Page**: `flutter_app/lib/features/admin/presentation/pages/qr_export_page.dart`
2. **Enhanced Database**: Added `getAllQRMarkers()` method
3. **Backend API**: New `/qr-markers/export` endpoint
4. **Export Formats**: JSON, CSV, and PDF support

This comprehensive system provides complete offline access to QR marker data for reliable indoor navigation without internet connectivity.