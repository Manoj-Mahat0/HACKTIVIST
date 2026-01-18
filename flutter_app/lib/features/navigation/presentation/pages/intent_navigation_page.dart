import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/network/api_client.dart';
import '../../../buildings/domain/entities/building.dart';
import 'unified_navigation_page.dart';

class IntentNavigationPage extends StatefulWidget {
  const IntentNavigationPage({super.key});

  @override
  State<IntentNavigationPage> createState() => _IntentNavigationPageState();
}

class _IntentNavigationPageState extends State<IntentNavigationPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;
  String? _selectedBuildingId;
  String? _selectedBuildingName;
  List<Map<String, dynamic>> _buildings = [];
  List<CategoryInfo> _categories = [];
  Map<String, List<LocationInfo>> _locationsByCategory = {};
  bool _showBuildingSelector = true;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBuildings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = getIt<ApiClient>();
      final response = await apiClient.dio.get('/buildings/');

      if (response.data != null) {
        final buildings = (response.data as List).cast<Map<String, dynamic>>();
        
        setState(() {
          _buildings = buildings;
          _isLoading = false;
          _showBuildingSelector = true;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load buildings: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectBuilding(String buildingId, String buildingName) async {
    setState(() {
      _selectedBuildingId = buildingId;
      _selectedBuildingName = buildingName;
      _showBuildingSelector = false;
    });
    
    await _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (_selectedBuildingId == null) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch locations from API
      final apiClient = getIt<ApiClient>();
      final response = await apiClient.dio.get(
        '/navigation/buildings/$_selectedBuildingId/locations',
      );

      if (response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final locations = (data['locations'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        // Group locations by category
        final Map<String, List<LocationInfo>> locationsByCategory = {};
        
        // If no locations have categories, create a default "All Locations" category
        bool hasCategories = false;
        
        for (final loc in locations) {
          final category = loc['category'] as String?;
          final nodeId = loc['id'] as String? ?? '';
          final name = loc['name'] as String? ?? 'Unknown';
          final floorNumber = loc['floor_number'] as int? ?? 0;
          final latitude = (loc['latitude'] as num?)?.toDouble() ?? 0.0;
          final longitude = (loc['longitude'] as num?)?.toDouble() ?? 0.0;
          final description = loc['landmark_description'] as String?;
          
          final location = LocationInfo(
            nodeId: nodeId,
            name: name,
            description: description,
            floorNumber: floorNumber,
            latitude: latitude,
            longitude: longitude,
          );
          
          if (category != null && category.isNotEmpty) {
            hasCategories = true;
            if (!locationsByCategory.containsKey(category)) {
              locationsByCategory[category] = [];
            }
            locationsByCategory[category]!.add(location);
          } else {
            // Add to "All Locations" category
            if (!locationsByCategory.containsKey('all')) {
              locationsByCategory['all'] = [];
            }
            locationsByCategory['all']!.add(location);
          }
        }

        // If no categories found, show all locations under one category
        if (!hasCategories && locationsByCategory.containsKey('all')) {
          // Keep only the "all" category - already populated above
        }

        // Create category list
        final categories = locationsByCategory.keys.map((category) {
          return CategoryInfo(
            id: category,
            name: _getCategoryDisplayName(category),
            icon: _getCategoryIcon(category),
            color: _getCategoryColor(category),
            locationCount: locationsByCategory[category]!.length,
          );
        }).toList();

        categories.sort((a, b) => a.name.compareTo(b.name));

        setState(() {
          _categories = categories;
          _locationsByCategory = locationsByCategory;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load categories: $e';
        _isLoading = false;
      });
    }
  }

  String _getCategoryDisplayName(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return 'All Locations';
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
      case 'academics':
        return 'Academics';
      case 'exams':
        return 'Exams';
      case 'restroom':
        return 'Restrooms';
      case 'parking':
        return 'Parking';
      case 'emergency':
        return 'Emergency';
      default:
        return category[0].toUpperCase() + category.substring(1);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Icons.location_on;
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
      case 'academics':
        return Icons.menu_book;
      case 'exams':
        return Icons.assignment;
      case 'restroom':
        return Icons.wc;
      case 'parking':
        return Icons.local_parking;
      case 'emergency':
        return Icons.emergency;
      default:
        return Icons.place;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Colors.deepPurple;
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
      case 'academics':
        return Colors.indigo;
      case 'exams':
        return Colors.amber;
      case 'restroom':
        return Colors.teal;
      case 'parking':
        return Colors.blueGrey;
      case 'emergency':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  List<CategoryInfo> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;
    return _categories.where((category) {
      return category.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          _showBuildingSelector 
              ? 'Select Building' 
              : _selectedBuildingName ?? 'Intent Navigation',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_showBuildingSelector) {
              Navigator.pop(context);
            } else {
              setState(() {
                _showBuildingSelector = true;
                _categories = [];
                _locationsByCategory = {};
              });
            }
          },
        ),
      ),
      body: _showBuildingSelector ? _buildBuildingSelector() : _buildCategoryView(),
    );
  }

  Widget _buildCategoryView() {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search categories...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),

        // Content
        Expanded(
          child: _buildBody(),
        ),
      ],
    );
  }

  Widget _buildBuildingSelector() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.deepPurple),
            SizedBox(height: 16),
            Text(
              'Loading buildings...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadBuildings,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_buildings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.business_outlined, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                'No buildings available',
                style: TextStyle(color: Colors.grey[400], fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _buildings.length,
      itemBuilder: (context, index) {
        final building = _buildings[index];
        return _buildBuildingCard(building);
      },
    );
  }

  Widget _buildBuildingCard(Map<String, dynamic> building) {
    final name = building['name'] as String? ?? 'Unknown Building';
    final address = building['address'] as String? ?? '';
    final description = building['description'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1E1E),
            const Color(0xFF2D2D2D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _selectBuilding(building['id'], name),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: Colors.deepPurple,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          address,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.deepPurple),
            SizedBox(height: 16),
            Text(
              'Loading categories...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadCategories,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.category_outlined, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                'No categories available',
                style: TextStyle(color: Colors.grey[400], fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Categories will appear here once locations are added to the building.',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final filteredCategories = _filteredCategories;

    if (filteredCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No categories found',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCategories,
      color: Colors.deepPurple,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredCategories.length,
        itemBuilder: (context, index) {
          final category = filteredCategories[index];
          return _buildCategoryCard(category);
        },
      ),
    );
  }

  Widget _buildCategoryCard(CategoryInfo category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1E1E),
            const Color(0xFF2D2D2D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: category.color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showLocationsForCategory(category),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category.icon,
                    color: category.color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${category.locationCount} ${category.locationCount == 1 ? 'location' : 'locations'}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLocationsForCategory(CategoryInfo category) {
    final locations = _locationsByCategory[category.id] ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: category.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        category.icon,
                        color: category.color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Select a destination',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.grey),
              // Locations list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final location = locations[index];
                    return _buildLocationItem(location, category.color);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationItem(LocationInfo location, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pop(context); // Close bottom sheet
            _navigateToLocation(location);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Location icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.place,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Location info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (location.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          location.description!,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Floor ${location.floorNumber}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Navigate button
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.navigation,
                    color: accentColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToLocation(LocationInfo location) {
    if (_selectedBuildingId == null) return;

    print('🔍 IntentNavigation - Navigating to location: ${location.name}');
    print('🔍 IntentNavigation - Location nodeId: ${location.nodeId}');

    // Find the building from the loaded buildings list
    final buildingData = _buildings.firstWhere(
      (b) => b['id'] == _selectedBuildingId,
      orElse: () => {},
    );

    if (buildingData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Building not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Parse createdAt from API response
    DateTime createdAt = DateTime.now();
    try {
      final createdAtStr = buildingData['created_at'] as String?;
      if (createdAtStr != null) {
        createdAt = DateTime.parse(createdAtStr);
      }
    } catch (e) {
      // Use current time if parsing fails
    }

    // Create Building object from API data
    final building = Building(
      id: buildingData['id'] as String,
      name: buildingData['name'] as String,
      description: buildingData['description'] as String?,
      address: buildingData['address'] as String? ?? '',
      latitude: (buildingData['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (buildingData['longitude'] as num?)?.toDouble() ?? 0.0,
      createdAt: createdAt,
      boundaryPoints: (buildingData['boundary_points'] as List?)
          ?.map((point) => Map<String, double>.from(point as Map))
          .toList(),
    );

    print('🔍 IntentNavigation - Building: ${building.name} (${building.id})');
    print('🔍 IntentNavigation - Passing destinationNodeId: ${location.nodeId}');

    // Navigate to unified navigation page with the building and pre-selected destination
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UnifiedNavigationPage(
            building: building,
            destinationNodeId: location.nodeId, // Pass the selected location's nodeId
          ),
        ),
      );
    }
  }
}

// Data models
class CategoryInfo {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final int locationCount;

  CategoryInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.locationCount,
  });
}

class LocationInfo {
  final String nodeId;
  final String name;
  final String? description;
  final int floorNumber;
  final double latitude;
  final double longitude;

  LocationInfo({
    required this.nodeId,
    required this.name,
    this.description,
    required this.floorNumber,
    required this.latitude,
    required this.longitude,
  });

  factory LocationInfo.fromJson(Map<String, dynamic> json) {
    return LocationInfo(
      nodeId: json['id'] ?? json['node_id'] ?? '',
      name: json['name'] ?? json['label'] ?? 'Unknown',
      description: json['description'] ?? json['landmark_description'],
      floorNumber: json['floor_number'] ?? 0,
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
    );
  }
}
