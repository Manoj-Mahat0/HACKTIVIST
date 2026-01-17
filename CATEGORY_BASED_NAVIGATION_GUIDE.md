# Category-Based Navigation Implementation Guide

## Overview

The category field has been added to the indoor navigation system to enable intent-based navigation. This allows users to find locations based on their purpose (e.g., "find food", "find shopping") rather than knowing specific location names.

## Changes Made

### 1. Frontend (Flutter App)

#### Coordinate Collection Page
- **File**: `flutter_app/lib/features/admin/presentation/pages/coordinate_collection_page.dart`
- **Changes**:
  - Added `category` field to `IndoorNode` class
  - Added category dropdown selector in the add node dialog
  - Category is now saved with each node during creation
  - Category is included in JSON serialization/deserialization

#### Available Categories
The following categories are available for selection:
- **Food & Dining** (`food`) - Restaurants, cafes, food courts
- **Shopping** (`shopping`) - Retail stores, shops
- **Services** (`services`) - Banks, ATMs, customer service
- **Entertainment** (`entertainment`) - Cinemas, gaming zones
- **Health & Medical** (`health`) - Clinics, pharmacies, first aid
- **Education** (`education`) - Classrooms, libraries, study areas
- **Office** (`office`) - Office spaces, meeting rooms
- **Parking** (`parking`) - Parking areas, garages
- **Amenities** (`amenities`) - Restrooms, water fountains, lounges

### 2. Backend (Python/FastAPI)

#### Models
- **File**: `backend/models.py`
- **Changes**:
  - Added `category` field to `IndoorGraphNode` model
  - Added `category` field to `GraphNode` model

#### API Schemas
- **File**: `backend/routers/indoor_graph.py`
- **Changes**:
  - Added `category` field to `IndoorNodeRequest` schema
  - Category is now handled during graph save operations

#### Navigation Endpoints
- **File**: `backend/routers/navigation.py`
- **New Endpoints**:

##### 1. Get Locations by Category
```
GET /navigation/buildings/{building_id}/locations/by-category/{category}
```
Returns all locations in a building that match the specified category.

**Example Request**:
```bash
GET /navigation/buildings/507f1f77bcf86cd799439011/locations/by-category/food
```

**Example Response**:
```json
{
  "category": "food",
  "count": 5,
  "locations": [
    {
      "id": "node_1234567890",
      "name": "Food Court",
      "node_type": "room",
      "floor_number": 2,
      "latitude": 12.9716,
      "longitude": 77.5946,
      "image_url": "https://...",
      "neighbors": ["node_1234567891"],
      "category": "food"
    }
  ]
}
```

##### 2. Get Available Categories
```
GET /navigation/buildings/{building_id}/categories
```
Returns all categories that have at least one location in the building.

**Example Request**:
```bash
GET /navigation/buildings/507f1f77bcf86cd799439011/categories
```

**Example Response**:
```json
{
  "building_id": "507f1f77bcf86cd799439011",
  "building_name": "Shopping Mall",
  "categories": ["food", "shopping", "entertainment", "parking"],
  "count": 4
}
```

##### 3. Enhanced Location Listing
```
GET /navigation/buildings/{building_id}/locations
```
Now includes the `category` field in each location object.

##### 4. Enhanced Route Calculation
```
POST /navigation/buildings/{building_id}/route
```
Route steps now include the `category` field for each waypoint.

## Usage Examples

### 1. Admin: Adding a Node with Category

When creating a new node in the coordinate collection page:
1. Fill in the node label (e.g., "Starbucks Coffee")
2. Select the node type (e.g., "Room")
3. **Select a category** from the dropdown (e.g., "Food & Dining")
4. Complete other fields as needed
5. Save the node

The category will be stored with the node and can be used for intent-based navigation.

### 2. User: Finding Locations by Intent

**Scenario**: User wants to find all food options in a building

```dart
// Flutter code example
final response = await http.get(
  Uri.parse('$apiUrl/navigation/buildings/$buildingId/locations/by-category/food'),
  headers: {'Authorization': 'Bearer $token'},
);

final data = json.decode(response.body);
final foodLocations = data['locations'] as List;

// Display food locations to user
for (var location in foodLocations) {
  print('${location['name']} on Floor ${location['floor_number']}');
}
```

### 3. User: Browsing Available Categories

```dart
// Flutter code example
final response = await http.get(
  Uri.parse('$apiUrl/navigation/buildings/$buildingId/categories'),
  headers: {'Authorization': 'Bearer $token'},
);

final data = json.decode(response.body);
final categories = data['categories'] as List<String>;

// Show category chips to user
// User can tap a category to see all locations in that category
```

### 4. AI Assistant Integration

The category field can be used with the AI assistant for natural language queries:

**User**: "I'm hungry, where can I eat?"
**AI**: Queries `/locations/by-category/food` and suggests nearby food options

**User**: "Find me a restroom"
**AI**: Queries `/locations/by-category/amenities` filtered by node_type "bathroom"

## Database Schema

### IndoorGraphNode (MongoDB)
```json
{
  "id": "node_1234567890",
  "label": "Starbucks Coffee",
  "latitude": 12.9716,
  "longitude": 77.5946,
  "floor_number": 2,
  "node_type": "room",
  "category": "food",
  "image_url": "https://...",
  "edges": [...],
  "qr_code": "indoor-nav://...",
  "is_emergency_exit": false,
  "is_accessible": true,
  "landmark_description": "Near the main escalator"
}
```

## Best Practices

### 1. Category Assignment
- Assign categories to **destination nodes** (rooms, specific locations)
- **Waypoints** typically don't need categories unless they serve a specific purpose
- **Elevators and stairs** don't need categories (they're infrastructure)
- **Entrances/exits** can have categories if they lead to specific areas

### 2. Consistency
- Use consistent category naming across all buildings
- Follow the predefined category list for uniformity
- Document any custom categories added

### 3. Multiple Categories
- Currently, each node supports one category
- If a location serves multiple purposes, choose the primary one
- Example: A cafe with a bookstore → choose "food" as primary

### 4. Search Optimization
- Categories are case-insensitive in the API
- Use lowercase for consistency in the database
- The API handles case conversion automatically

## Future Enhancements

### Potential Improvements
1. **Multiple Categories per Node**: Allow nodes to have multiple categories
2. **Category Hierarchy**: Parent-child relationships (e.g., "food" → "fast-food", "fine-dining")
3. **Custom Categories**: Allow building admins to define custom categories
4. **Category Icons**: Associate icons with categories for better UI
5. **Category Filters**: Combine category with other filters (accessible, open now, etc.)
6. **Popular Categories**: Track and display most-searched categories
7. **Category-Based Recommendations**: Suggest categories based on time of day or user history

## Testing

### Test Scenarios

1. **Create Node with Category**
   - Create a node with category "food"
   - Verify it's saved correctly
   - Verify it appears in category search

2. **Search by Category**
   - Query `/locations/by-category/food`
   - Verify only food-related locations are returned
   - Verify count matches actual locations

3. **List Categories**
   - Query `/categories`
   - Verify all used categories are listed
   - Verify count is accurate

4. **Navigation with Categories**
   - Calculate route to a categorized location
   - Verify category appears in route steps
   - Verify category is preserved through route calculation

## Troubleshooting

### Category Not Appearing in Search
- Verify the category is spelled correctly (case-insensitive)
- Check if the node was saved with the category field
- Ensure the building graph was saved after adding the category

### Category Field Missing in Response
- Update backend to latest version
- Verify the `IndoorGraphNode` model includes the category field
- Check if the graph was saved after the model update

### Old Nodes Without Categories
- Old nodes will have `category: null`
- They can be edited to add categories
- They won't appear in category-based searches until updated

## API Reference Summary

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/navigation/buildings/{id}/locations` | GET | Get all locations (includes category) |
| `/navigation/buildings/{id}/locations/by-category/{category}` | GET | Get locations by category |
| `/navigation/buildings/{id}/categories` | GET | Get available categories |
| `/navigation/buildings/{id}/route` | POST | Calculate route (includes category in steps) |
| `/indoor/buildings/{id}/indoor-graph` | POST | Save graph (accepts category field) |
| `/indoor/buildings/{id}/indoor-graph` | GET | Get graph (includes category field) |

## Conclusion

The category field enables powerful intent-based navigation, allowing users to find locations based on their needs rather than specific names. This improves the user experience and makes the navigation system more intuitive and accessible.
