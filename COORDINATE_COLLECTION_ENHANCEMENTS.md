# Coordinate Collection Page Enhancements - Summary

## Changes Made:

### 1. **Enhanced Data Model**
- Added `roomName` field to `CoordinateWithMedia` class
- Supports room identification for each coordinate point

### 2. **Live Location Tracking**
- Implemented continuous GPS streaming with `LocationAccuracy.bestForNavigation`
- Real-time coordinate updates in the dialog
- Toggle button to start/stop live tracking
- Visual "LIVE" indicator when tracking is active
- Coordinates update automatically as user moves

### 3. **Camera Integration**
- Replaced gallery picker with direct camera capture
- `_takePhoto()` method uses `ImageSource.camera`
- Enhanced photo preview with numbered thumbnails
- Delete individual photos with red X button

### 4. **Room Name/Number Field**
- Dedicated TextField for room identification
- Required field with validation
- Auto-capitalization for proper formatting
- Prefix icon for better UX

### 5. **Step-Based Manual Adjustment**
- New feature to adjust coordinates by walking steps
- Input: Number of steps + Direction (8 compass directions)
- Calculates distance using 0.7m per step
- Converts steps to lat/lng degree changes
- Useful when GPS isn't updating accurately

### 6. **Edit Functionality**
- New `_editCoordinate(int index)` method
- Opens dialog with pre-filled data
- Allows updating room names, coordinates, photos, notes
- Updates existing point instead of creating new one

### 7. **Enhanced UI/UX**
- Responsive design with screen height constraints
- Keyboard-aware padding
- Live tracking toggle in header
- ExpansionTile for step adjustment (keeps UI clean)
- Better visual hierarchy with icons and colors
- Improved button states and validation feedback

### 8. **Coordinate Display in List**
- Shows room name prominently
- 8 decimal precision for coordinates
- Swipe to delete
- Tap to edit (needs to be wired up)

## Files Modified:

1. **flutter_app/lib/features/admin/presentation/pages/coordinate_collection_page.dart**
   - Added `dart:math` import
   - Enhanced `CoordinateWithMedia` class
   - Updated `_addCurrentLocationWithDialog()` method
   - Added `_editCoordinate()` method
   - Completely rewrote `_AddCoordinateSheet` widget
   - Added live tracking functionality
   - Added step-based adjustment
   - Enhanced camera functionality

## Backend Changes Needed:

### Update Waypoint Model (backend/models.py):
```python
class Waypoint(Document):
    floor_id: ObjectId
    latitude: float
    longitude: float
    floor_number: int
    waypoint_type: str
    name: str
    room_name: Optional[str] = None  # ADD THIS
    notes: Optional[str] = None  # ADD THIS
    images: Optional[List[str]] = None  # ADD THIS (URLs to stored images)
    
    model_config = ConfigDict(arbitrary_types_allowed=True)
    
    class Settings:
        name = "waypoints"
```

### Update Waypoint Schema (backend/schemas.py):
```python
class WaypointBase(BaseModel):
    latitude: float
    longitude: float
    floor_number: int
    waypoint_type: str
    name: str
    room_name: Optional[str] = None  # ADD THIS
    notes: Optional[str] = None  # ADD THIS
    images: Optional[List[str]] = None  # ADD THIS
```

### Update Admin Router (backend/routers/admin.py):
- Modify `generate_3d_model` endpoint to handle room_name field
- Add image upload handling if needed
- Store room_name with waypoints

## Testing Checklist:

- [ ] Live location tracking starts automatically
- [ ] Coordinates update in real-time
- [ ] Toggle button stops/starts tracking
- [ ] Camera opens and captures photos
- [ ] Photos display with thumbnails
- [ ] Room name is required before saving
- [ ] Step adjustment calculates correctly
- [ ] All 8 directions work properly
- [ ] Boundary validation works
- [ ] Edit functionality opens with correct data
- [ ] Updates save correctly
- [ ] List shows room names
- [ ] Swipe to delete works
- [ ] Responsive on different screen sizes

## Key Features Summary:

✅ Live GPS tracking with toggle
✅ Real-time coordinate updates
✅ Camera integration (no gallery)
✅ Room name/number field
✅ Edit existing points
✅ Step-based manual adjustment
✅ 8 decimal precision (~1mm)
✅ Boundary validation
✅ Enhanced UI/UX
✅ Responsive design
✅ Photo management
✅ Notes field

## Next Steps:

1. Wire up edit functionality in the list (add onTap to ListTile)
2. Test on physical device for GPS accuracy
3. Update backend models and schemas
4. Add image upload to backend
5. Test step adjustment accuracy in real-world scenarios
