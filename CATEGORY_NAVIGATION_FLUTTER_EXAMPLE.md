# Category-Based Navigation - Flutter Implementation Examples

## Overview
This document provides Flutter code examples for implementing category-based navigation in the user-facing app.

## 1. Fetch Available Categories

```dart
Future<List<String>> fetchCategories(String buildingId) async {
  try {
    final token = await TokenStorage.getToken();
    final response = await http.get(
      Uri.parse('$apiBaseUrl/navigation/buildings/$buildingId/categories'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<String>.from(data['categories'] ?? []);
    } else {
      throw Exception('Failed to load categories');
    }
  } catch (e) {
    print('Error fetching categories: $e');
    return [];
  }
}
```

## 2. Fetch Locations by Category

```dart
Future<List<Location>> fetchLocationsByCategory(
  String buildingId,
  String category,
) async {
  try {
    final token = await TokenStorage.getToken();
    final response = await http.get(
      Uri.parse('$apiBaseUrl/navigation/buildings/$buildingId/locations/by-category/$category'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final locations = data['locations'] as List;
      return locations.map((loc) => Location.fromJson(loc)).toList();
    } else {
      throw Exception('Failed to load locations');
    }
  } catch (e) {
    print('Error fetching locations by category: $e');
    return [];
  }
}
```

## 3. Location Model with Category

```dart
class Location {
  final String id;
  final String name;
  final String nodeType;
  final int floorNumber;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final String? category;
  final List<String> neighbors;

  Location({
    required this.id,
    required this.name,
    required this.nodeType,
    required this.floorNumber,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.category,
    this.neighbors = const [],
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      nodeType: json['node_type'] ?? 'waypoint',
      floorNumber: json['floor_number'] ?? 0,
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      imageUrl: json['image_url'],
      category: json['category'],
      neighbors: List<String>.from(json['neighbors'] ?? []),
    );
  }

  // Get category icon
  IconData getCategoryIcon() {
    switch (category?.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'shopping':
        return Icons.shopping_bag;
      case 'services':
        return Icons.business_center;
      case 'entertainment':
        return Icons.movie;
      case 'health':
        return Icons.local_hospital;
      case 'education':
        return Icons.school;
      case 'office':
        return Icons.work;
      case 'parking':
        return Icons.local_parking;
      case 'amenities':
        return Icons.local_convenience_store;
      default:
        return Icons.location_on;
    }
  }

  // Get category color
  Color getCategoryColor() {
    switch (category?.toLowerCase()) {
      case 'food':
        return Colors.orange;
      case 'shopping':
        return Colors.pink;
      case 'services':
        return Colors.blue;
      case 'entertainment':
        return Colors.purple;
      case 'health':
        return Colors.red;
      case 'education':
        return Colors.green;
      case 'office':
        return Colors.blueGrey;
      case 'parking':
        return Colors.grey;
      case 'amenities':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  // Get category display name
  String getCategoryDisplayName() {
    switch (category?.toLowerCase()) {
      case 'food':
        return 'Food & Dining';
      case 'shopping':
        return 'Shopping';
      case 'services':
        return 'Services';
      case 'entertainment':
        return 'Entertainment';
      case 'health':
        return 'Health & Medical';
      case 'education':
        return 'Education';
      case 'office':
        return 'Office';
      case 'parking':
        return 'Parking';
      case 'amenities':
        return 'Amenities';
      default:
        return 'Other';
    }
  }
}
```

## 4. Category Browser Widget

```dart
class CategoryBrowserWidget extends StatefulWidget {
  final String buildingId;
  final Function(Location) onLocationSelected;

  const CategoryBrowserWidget({
    Key? key,
    required this.buildingId,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  State<CategoryBrowserWidget> createState() => _CategoryBrowserWidgetState();
}

class _CategoryBrowserWidgetState extends State<CategoryBrowserWidget> {
  List<String> _categories = [];
  String? _selectedCategory;
  List<Location> _locations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await fetchCategories(widget.buildingId);
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading categories: $e')),
      );
    }
  }

  Future<void> _loadLocationsByCategory(String category) async {
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
    });
    
    try {
      final locations = await fetchLocationsByCategory(widget.buildingId, category);
      setState(() {
        _locations = locations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading locations: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category chips
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Browse by Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoading && _categories.isEmpty)
                const Center(child: CircularProgressIndicator())
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((category) {
                    final isSelected = category == _selectedCategory;
                    final location = Location(
                      id: '',
                      name: '',
                      nodeType: '',
                      floorNumber: 0,
                      latitude: 0,
                      longitude: 0,
                      category: category,
                    );
                    
                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            location.getCategoryIcon(),
                            size: 16,
                            color: isSelected ? Colors.white : location.getCategoryColor(),
                          ),
                          const SizedBox(width: 6),
                          Text(location.getCategoryDisplayName()),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          _loadLocationsByCategory(category);
                        } else {
                          setState(() {
                            _selectedCategory = null;
                            _locations = [];
                          });
                        }
                      },
                      selectedColor: location.getCategoryColor(),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        
        // Locations list
        if (_selectedCategory != null) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '${_locations.length} locations found',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: ListView.builder(
                itemCount: _locations.length,
                itemBuilder: (context, index) {
                  final location = _locations[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: location.getCategoryColor().withOpacity(0.2),
                      child: Icon(
                        location.getCategoryIcon(),
                        color: location.getCategoryColor(),
                      ),
                    ),
                    title: Text(location.name),
                    subtitle: Text('Floor ${location.floorNumber}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => widget.onLocationSelected(location),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }
}
```

## 5. Quick Category Search

```dart
class QuickCategorySearch extends StatelessWidget {
  final String buildingId;
  final Function(Location) onLocationSelected;

  const QuickCategorySearch({
    Key? key,
    required this.buildingId,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What are you looking for?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildQuickCategoryCard(
                context,
                'Food',
                Icons.restaurant,
                Colors.orange,
                'food',
              ),
              _buildQuickCategoryCard(
                context,
                'Shopping',
                Icons.shopping_bag,
                Colors.pink,
                'shopping',
              ),
              _buildQuickCategoryCard(
                context,
                'Restroom',
                Icons.wc,
                Colors.teal,
                'amenities',
              ),
              _buildQuickCategoryCard(
                context,
                'Parking',
                Icons.local_parking,
                Colors.grey,
                'parking',
              ),
              _buildQuickCategoryCard(
                context,
                'Services',
                Icons.business_center,
                Colors.blue,
                'services',
              ),
              _buildQuickCategoryCard(
                context,
                'More',
                Icons.more_horiz,
                Colors.blueGrey,
                null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCategoryCard(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    String? category,
  ) {
    return InkWell(
      onTap: () async {
        if (category != null) {
          // Show loading
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
          );

          try {
            final locations = await fetchLocationsByCategory(buildingId, category);
            Navigator.pop(context); // Close loading

            if (locations.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('No $label locations found')),
              );
            } else if (locations.length == 1) {
              // Only one location, select it directly
              onLocationSelected(locations.first);
            } else {
              // Multiple locations, show list
              _showLocationsList(context, label, locations);
            }
          } catch (e) {
            Navigator.pop(context); // Close loading
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        } else {
          // Show all categories
          _showAllCategories(context);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationsList(
    BuildContext context,
    String categoryLabel,
    List<Location> locations,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$categoryLabel (${locations.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: locations.length,
                itemBuilder: (context, index) {
                  final location = locations[index];
                  return ListTile(
                    leading: Icon(location.getCategoryIcon()),
                    title: Text(location.name),
                    subtitle: Text('Floor ${location.floorNumber}'),
                    onTap: () {
                      Navigator.pop(context);
                      onLocationSelected(location);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllCategories(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryBrowserWidget(
          buildingId: buildingId,
          onLocationSelected: onLocationSelected,
        ),
      ),
    );
  }
}
```

## 6. Integration in Navigation Page

```dart
// In your unified_navigation_page.dart or similar

class UnifiedNavigationPage extends StatefulWidget {
  // ... existing code
}

class _UnifiedNavigationPageState extends State<UnifiedNavigationPage> {
  // ... existing state variables

  void _showCategorySearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: CategoryBrowserWidget(
          buildingId: _selectedBuilding!.id,
          onLocationSelected: (location) {
            Navigator.pop(context);
            setState(() {
              _destinationNode = location;
            });
            _calculateRoute();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... existing scaffold code
      body: Column(
        children: [
          // ... existing widgets
          
          // Add category search button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _showCategorySearch,
              icon: const Icon(Icons.category),
              label: const Text('Browse by Category'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
          
          // Or use quick category search
          QuickCategorySearch(
            buildingId: _selectedBuilding!.id,
            onLocationSelected: (location) {
              setState(() {
                _destinationNode = location;
              });
              _calculateRoute();
            },
          ),
          
          // ... rest of your widgets
        ],
      ),
    );
  }
}
```

## 7. AI Assistant Integration

```dart
Future<void> handleNaturalLanguageQuery(String query) async {
  // Map natural language to categories
  final queryLower = query.toLowerCase();
  String? category;

  if (queryLower.contains('food') || 
      queryLower.contains('eat') || 
      queryLower.contains('hungry') ||
      queryLower.contains('restaurant')) {
    category = 'food';
  } else if (queryLower.contains('shop') || 
             queryLower.contains('store') || 
             queryLower.contains('buy')) {
    category = 'shopping';
  } else if (queryLower.contains('restroom') || 
             queryLower.contains('bathroom') || 
             queryLower.contains('toilet')) {
    category = 'amenities';
  } else if (queryLower.contains('park')) {
    category = 'parking';
  }
  // ... add more mappings

  if (category != null) {
    final locations = await fetchLocationsByCategory(buildingId, category);
    // Show locations to user
    _showLocationsList(locations);
  } else {
    // Fall back to regular search or AI assistant
    _handleWithAI(query);
  }
}
```

## Summary

These examples show how to:
1. Fetch available categories from the backend
2. Search locations by category
3. Display category-based UI with icons and colors
4. Integrate category search into navigation flow
5. Handle natural language queries with category mapping

The category field enables a more intuitive and user-friendly navigation experience!
