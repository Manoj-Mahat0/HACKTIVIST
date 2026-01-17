# Category Field - Quick Reference Card

## 🎯 What Is It?
A new optional field for navigation nodes that enables intent-based search (e.g., "find food", "find parking").

## 📋 Available Categories

| Category | Value | Icon | Example Locations |
|----------|-------|------|-------------------|
| Food & Dining | `food` | 🍽️ | Restaurants, Cafes, Food Courts |
| Shopping | `shopping` | 🛍️ | Retail Stores, Shops, Boutiques |
| Services | `services` | 💼 | Banks, ATMs, Customer Service |
| Entertainment | `entertainment` | 🎬 | Cinemas, Gaming Zones, Arcades |
| Health & Medical | `health` | 🏥 | Clinics, Pharmacies, First Aid |
| Education | `education` | 🎓 | Classrooms, Libraries, Study Areas |
| Office | `office` | 💼 | Office Spaces, Meeting Rooms |
| Parking | `parking` | 🅿️ | Parking Areas, Garages |
| Amenities | `amenities` | 🚻 | Restrooms, Water Fountains, Lounges |

## 🔧 How to Add Category (Admin)

1. Open Coordinate Collection Page
2. Tap "+" to add node
3. Fill in label and node type
4. **Select category from dropdown** ← NEW
5. Save node
6. Click "Save Graph"

## 🔌 API Endpoints

### Get Locations by Category
```
GET /navigation/buildings/{building_id}/locations/by-category/{category}
```
**Example**: `/locations/by-category/food`

### Get Available Categories
```
GET /navigation/buildings/{building_id}/categories
```

### Enhanced Endpoints (now include category)
- `GET /navigation/buildings/{id}/locations`
- `POST /navigation/buildings/{id}/route`

## 💻 Flutter Code Snippets

### Fetch Locations by Category
```dart
final response = await http.get(
  Uri.parse('$apiUrl/navigation/buildings/$buildingId/locations/by-category/food'),
  headers: {'Authorization': 'Bearer $token'},
);
final data = json.decode(response.body);
final locations = data['locations'];
```

### Display Category Icon
```dart
IconData getCategoryIcon(String? category) {
  switch (category?.toLowerCase()) {
    case 'food': return Icons.restaurant;
    case 'shopping': return Icons.shopping_bag;
    case 'services': return Icons.business_center;
    case 'entertainment': return Icons.movie;
    case 'health': return Icons.local_hospital;
    case 'education': return Icons.school;
    case 'office': return Icons.work;
    case 'parking': return Icons.local_parking;
    case 'amenities': return Icons.local_convenience_store;
    default: return Icons.location_on;
  }
}
```

## 📊 Data Structure

### IndoorNode (Flutter)
```dart
class IndoorNode {
  final String id;
  final String label;
  final String nodeType;
  final String? category;  // ← NEW
  // ... other fields
}
```

### IndoorGraphNode (Backend)
```python
class IndoorGraphNode(BaseModel):
    id: str
    label: str
    node_type: str
    category: Optional[str] = None  # ← NEW
    # ... other fields
```

## 🎨 Category Colors

```dart
Color getCategoryColor(String? category) {
  switch (category?.toLowerCase()) {
    case 'food': return Colors.orange;
    case 'shopping': return Colors.pink;
    case 'services': return Colors.blue;
    case 'entertainment': return Colors.purple;
    case 'health': return Colors.red;
    case 'education': return Colors.green;
    case 'office': return Colors.blueGrey;
    case 'parking': return Colors.grey;
    case 'amenities': return Colors.teal;
    default: return Colors.grey;
  }
}
```

## 🔍 Use Cases

### 1. Browse by Category
User taps "Food" → Shows all food locations

### 2. Natural Language
User: "I'm hungry" → App queries food category

### 3. Quick Access
Show category chips for fast navigation

### 4. Filtering
Filter search results by category

## ✅ Testing Checklist

- [ ] Create node with category
- [ ] Save graph
- [ ] Query by category
- [ ] Verify category in response
- [ ] Test with multiple categories
- [ ] Test without category (should work)

## 📚 Documentation

- **Full Guide**: `CATEGORY_BASED_NAVIGATION_GUIDE.md`
- **Implementation Summary**: `CATEGORY_FIELD_IMPLEMENTATION_SUMMARY.md`
- **Flutter Examples**: `CATEGORY_NAVIGATION_FLUTTER_EXAMPLE.md`
- **Visual Summary**: `CATEGORY_FIELD_CHANGES_VISUAL.md`
- **Complete Status**: `IMPLEMENTATION_COMPLETE_CATEGORY_FIELD.md`

## 🚀 Quick Start

### Admin
```
1. Open coordinate collection
2. Add node → Select category
3. Save graph
```

### Developer
```dart
// Get food locations
final foods = await fetchLocationsByCategory(buildingId, 'food');

// Get all categories
final categories = await fetchCategories(buildingId);
```

### User
```
1. Tap "Browse by Category"
2. Select category (e.g., Food)
3. Choose location
4. Navigate
```

## 💡 Tips

- Category is **optional** - nodes work fine without it
- Use categories for **destination nodes** (rooms, specific locations)
- **Waypoints** typically don't need categories
- **Elevators/stairs** don't need categories
- Be **consistent** with category naming

## ⚠️ Important Notes

- ✅ Backward compatible (old nodes work fine)
- ✅ Optional field (not required)
- ✅ Case-insensitive search
- ✅ No breaking changes
- ✅ Works with existing features

## 🎯 Benefits

1. **Intent-based search** - Find by purpose, not name
2. **Better UX** - More intuitive navigation
3. **AI-friendly** - Natural language queries
4. **Analytics-ready** - Track popular categories
5. **Scalable** - Easy to add new categories

---

**Status**: ✅ Complete and Ready
**Version**: 1.0
**Date**: January 17, 2026
