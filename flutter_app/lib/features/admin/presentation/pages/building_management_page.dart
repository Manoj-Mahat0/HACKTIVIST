import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:indoor_navigation/features/buildings/presentation/bloc/buildings_bloc.dart';
import 'package:indoor_navigation/features/buildings/domain/entities/building.dart';
import 'package:indoor_navigation/core/navigation/app_navigator.dart';
import 'package:indoor_navigation/features/admin/presentation/pages/edit_building_boundary_page.dart';
import 'package:indoor_navigation/core/theme/app_theme.dart';

class BuildingManagementPage extends StatefulWidget {
  const BuildingManagementPage({super.key});

  @override
  State<BuildingManagementPage> createState() => _BuildingManagementPageState();
}

class _BuildingManagementPageState extends State<BuildingManagementPage> {
  String _searchQuery = '';
  bool _isMapView = false;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polygon> _polygons = {};

  @override
  void initState() {
    super.initState();
    context.read<BuildingsBloc>().add(LoadBuildingsEvent());
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  double _calculateBuildingArea(List<dynamic>? boundaryPoints) {
    if (boundaryPoints == null || boundaryPoints.length < 3) return 0;
    
    double area = 0;
    for (int i = 0; i < boundaryPoints.length; i++) {
      int j = (i + 1) % boundaryPoints.length;
      final point1 = boundaryPoints[i] as Map<String, dynamic>;
      final point2 = boundaryPoints[j] as Map<String, dynamic>;
      
      area += (point1['lat'] as double) * (point2['lng'] as double);
      area -= (point2['lat'] as double) * (point1['lng'] as double);
    }
    return (area.abs() / 2) * 111000 * 111000;
  }

  String _formatArea(double area) {
    if (area < 1000) {
      return '${area.toStringAsFixed(0)} m²';
    } else {
      return '${(area / 1000).toStringAsFixed(2)} km²';
    }
  }

  List<Building> _filterBuildings(List<Building> buildings) {
    if (_searchQuery.isEmpty) return buildings;
    return buildings.where((b) {
      return b.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             b.address.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Building Management',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isMapView ? Icons.list : Icons.map),
            onPressed: () {
              setState(() {
                _isMapView = !_isMapView;
              });
            },
            tooltip: _isMapView ? 'List View' : 'Map View',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<BuildingsBloc>().add(LoadBuildingsEvent());
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: BlocBuilder<BuildingsBloc, BuildingsState>(
        builder: (context, state) {
          if (state is BuildingsLoadingState) {
            return _buildLoadingState();
          }

          if (state is BuildingsErrorState) {
            return _buildErrorState(context, state.message);
          }

          if (state is BuildingsLoadedState) {
            if (_isMapView) {
              return _buildMapView(context, state.buildings);
            } else {
              return _buildLoadedState(context, state.buildings);
            }
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildMapView(BuildContext context, List<Building> buildings) {
    if (buildings.isEmpty) {
      return _buildEmptyState();
    }

    _createMarkersAndPolygons(buildings);

    // Calculate center position
    double avgLat = 0;
    double avgLng = 0;
    for (var building in buildings) {
      avgLat += building.latitude;
      avgLng += building.longitude;
    }
    avgLat /= buildings.length;
    avgLng /= buildings.length;

    final filteredBuildings = _filterBuildings(buildings);

    return Stack(
      children: [
        // Google Map
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(avgLat, avgLng),
            zoom: 13,
          ),
          markers: _markers,
          polygons: _polygons,
          onMapCreated: (controller) {
            _mapController = controller;
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: true,
          mapType: MapType.normal,
        ),
        
        // Top gradient overlay for better visibility
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        
        // Search Bar
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: _buildMapSearchBar(),
        ),
        
        // Custom Location Button
        Positioned(
          right: 16,
          bottom: 200,
          child: FloatingActionButton(
            heroTag: 'building_location_btn',
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () async {
              // Get current location and move camera
              if (_mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newLatLng(LatLng(avgLat, avgLng)),
                );
              }
            },
            child: const Icon(Icons.my_location, color: AppColors.primaryOrange),
          ),
        ),
        
        // Zoom Controls
        Positioned(
          right: 16,
          bottom: 260,
          child: Column(
            children: [
              FloatingActionButton(
                heroTag: 'building_zoom_in_btn',
                mini: true,
                backgroundColor: Colors.white,
                onPressed: () {
                  _mapController?.animateCamera(CameraUpdate.zoomIn());
                },
                child: const Icon(Icons.add, color: AppColors.primaryOrange),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'building_zoom_out_btn',
                mini: true,
                backgroundColor: Colors.white,
                onPressed: () {
                  _mapController?.animateCamera(CameraUpdate.zoomOut());
                },
                child: const Icon(Icons.remove, color: AppColors.primaryOrange),
              ),
            ],
          ),
        ),
        
        // Bottom Building List
        DraggableScrollableSheet(
          initialChildSize: 0.25,
          minChildSize: 0.15,
          maxChildSize: 0.7,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.business,
                            color: AppColors.primaryOrange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${filteredBuildings.length} Buildings',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Swipe up for list',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(height: 1),
                  
                  // Building List
                  Expanded(
                    child: filteredBuildings.isEmpty
                        ? Center(
                            child: Text(
                              'No buildings found',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredBuildings.length,
                            itemBuilder: (context, index) {
                              return _buildCompactBuildingCard(
                                filteredBuildings[index],
                                onTap: () {
                                  // Move camera to building
                                  _mapController?.animateCamera(
                                    CameraUpdate.newLatLngZoom(
                                      LatLng(
                                        filteredBuildings[index].latitude,
                                        filteredBuildings[index].longitude,
                                      ),
                                      16,
                                    ),
                                  );
                                  // Show details
                                  _showBuildingDetailsOnMap(context, filteredBuildings[index]);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMapSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search buildings...',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade400),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildCompactBuildingCard(Building building, {required VoidCallback onTap}) {
    final area = _calculateBuildingArea(building.boundaryPoints);
    final pointsCount = building.boundaryPoints?.length ?? 0;
    final isComplete = pointsCount >= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        building.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              building.address,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isComplete ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isComplete ? 'Complete' : 'Incomplete',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isComplete ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatArea(area),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _createMarkersAndPolygons(List<Building> buildings) {
    _markers.clear();
    _polygons.clear();

    for (var building in buildings) {
      final pointsCount = building.boundaryPoints?.length ?? 0;
      final isComplete = pointsCount >= 3;
      
      // Add main building marker with custom info
      _markers.add(
        Marker(
          markerId: MarkerId(building.id),
          position: LatLng(building.latitude, building.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isComplete ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: building.name,
            snippet: '${_formatArea(_calculateBuildingArea(building.boundaryPoints))} • $pointsCount points',
            onTap: () => _showBuildingDetailsOnMap(context, building),
          ),
        ),
      );

      // Add polygon and vertex markers if boundary points exist
      if (building.boundaryPoints != null && building.boundaryPoints!.length >= 3) {
        List<LatLng> polygonPoints = [];
        
        // Create polygon points and vertex markers
        for (int i = 0; i < building.boundaryPoints!.length; i++) {
          final pointMap = building.boundaryPoints![i] as Map<String, dynamic>;
          final lat = pointMap['lat'] as double;
          final lng = pointMap['lng'] as double;
          final point = LatLng(lat, lng);
          polygonPoints.add(point);
          
          // Add vertex marker for each boundary point
          _markers.add(
            Marker(
              markerId: MarkerId('${building.id}_vertex_$i'),
              position: point,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
              anchor: const Offset(0.5, 0.5),
              infoWindow: InfoWindow(
                title: '${building.name} - Point ${i + 1}',
                snippet: 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}',
              ),
            ),
          );
        }

        // Create polygon with enhanced styling
        _polygons.add(
          Polygon(
            polygonId: PolygonId(building.id),
            points: polygonPoints,
            strokeColor: isComplete ? AppColors.primaryOrange : const Color(0xFFFF9800),
            strokeWidth: 4,
            fillColor: (isComplete ? AppColors.primaryOrange : const Color(0xFFFF9800))
                .withOpacity(0.3),
            consumeTapEvents: true,
            geodesic: true,
            onTap: () {
              // Zoom to building and show details
              _mapController?.animateCamera(
                CameraUpdate.newLatLngBounds(
                  _getBoundsFromPoints(polygonPoints),
                  100, // padding
                ),
              );
              _showBuildingDetailsOnMap(context, building);
            },
          ),
        );
      }
    }
  }

  LatLngBounds _getBoundsFromPoints(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _showBuildingDetailsOnMap(BuildContext context, Building building) {
    final area = _calculateBuildingArea(building.boundaryPoints);
    final pointsCount = building.boundaryPoints?.length ?? 0;
    final isComplete = pointsCount >= 3;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Header with Icon and Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.business, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          building.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        if (building.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            building.description!,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Address Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on,
                        size: 20,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Address',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            building.address,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Stats Grid
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.square_foot,
                      label: 'Area',
                      value: _formatArea(area),
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.location_on,
                      label: 'Points',
                      value: '$pointsCount',
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.gps_fixed,
                      label: 'Latitude',
                      value: building.latitude.toStringAsFixed(6),
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.gps_fixed,
                      label: 'Longitude',
                      value: building.longitude.toStringAsFixed(6),
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isComplete ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isComplete ? Colors.green.shade200 : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isComplete ? Icons.check_circle : Icons.pending,
                      size: 20,
                      color: isComplete ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isComplete ? 'Complete Building' : 'Incomplete Building',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isComplete ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      isComplete ? 'Ready to use' : 'Needs more points',
                      style: TextStyle(
                        fontSize: 12,
                        color: isComplete ? Colors.green.shade600 : Colors.orange.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showBuildingDetails(context, building);
                      },
                      icon: const Icon(Icons.info_outline, size: 20),
                      label: const Text('Full Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryOrange,
                        side: const BorderSide(color: AppColors.primaryOrange, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        AppNavigator.push(EditBuildingBoundaryPage(building: building));
                      },
                      icon: const Icon(Icons.edit_location, size: 20),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
          ),
          SizedBox(height: 16),
          Text(
            'Loading buildings...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Buildings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<BuildingsBloc>().add(LoadBuildingsEvent());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, List<Building> allBuildings) {
    if (allBuildings.isEmpty) {
      return _buildEmptyState();
    }

    final buildings = _filterBuildings(allBuildings);
    double totalArea = 0;
    for (var building in allBuildings) {
      totalArea += _calculateBuildingArea(building.boundaryPoints);
    }

    return Column(
      children: [
        _buildStatsHeader(allBuildings.length, totalArea),
        _buildSearchBar(),
        const SizedBox(height: 16),
        Expanded(
          child: buildings.isEmpty
              ? _buildNoResultsState()
              : _buildBuildingsList(buildings),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.business_outlined,
                size: 80,
                color: Colors.blue.shade300,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No Buildings Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first building to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No buildings found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(int buildingCount, double totalArea) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryOrange, AppColors.primaryOrangeDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.business, color: Colors.white70, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Total Buildings',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$buildingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 60,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.square_foot, color: Colors.white70, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Total Area',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatArea(totalArea),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search buildings...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey.shade400),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBuildingsList(List<Building> buildings) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<BuildingsBloc>().add(LoadBuildingsEvent());
      },
      color: AppColors.primaryOrange,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: buildings.length,
        itemBuilder: (context, index) {
          return _buildBuildingCard(buildings[index]);
        },
      ),
    );
  }

  Widget _buildBuildingCard(Building building) {
    final area = _calculateBuildingArea(building.boundaryPoints);
    final pointsCount = building.boundaryPoints?.length ?? 0;
    final isComplete = pointsCount >= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showBuildingOptions(context, building),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(building),
                const SizedBox(height: 16),
                _buildAddressSection(building.address),
                const SizedBox(height: 16),
                _buildCardFooter(area, pointsCount, isComplete),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(Building building) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blue.shade600],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.business,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                building.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              if (building.description?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  building.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSection(String address) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            size: 18,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              address,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFooter(double area, int pointsCount, bool isComplete) {
    return Row(
      children: [
        _buildInfoChip(
          icon: Icons.square_foot,
          label: _formatArea(area),
          color: Colors.green,
        ),
        const SizedBox(width: 12),
        _buildInfoChip(
          icon: Icons.location_on,
          label: '$pointsCount pts',
          color: Colors.blue,
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: isComplete
                ? Colors.green.shade50
                : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isComplete ? Icons.check_circle : Icons.pending,
                size: 14,
                color: isComplete
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                isComplete ? 'Complete' : 'Incomplete',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isComplete
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showBuildingOptions(BuildContext context, Building building) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        building.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Building Options',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildOptionTile(
              icon: Icons.edit_location,
              title: 'Edit Boundary',
              subtitle: 'Modify building area',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                AppNavigator.push(
                  EditBuildingBoundaryPage(building: building),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildOptionTile(
              icon: Icons.info,
              title: 'View Details',
              subtitle: 'See building information',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _showBuildingDetails(context, building);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBuildingDetails(BuildContext context, Building building) {
    final area = _calculateBuildingArea(building.boundaryPoints);
    final pointsCount = building.boundaryPoints?.length ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.business,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                building.name,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Description', building.description ?? 'No description'),
              _buildDetailRow('Address', building.address),
              _buildDetailRow('Area', _formatArea(area)),
              _buildDetailRow('Boundary Points', '$pointsCount points'),
              _buildDetailRow(
                'Coordinates',
                '${building.latitude.toStringAsFixed(6)}, ${building.longitude.toStringAsFixed(6)}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              AppNavigator.push(
                EditBuildingBoundaryPage(building: building),
              );
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
