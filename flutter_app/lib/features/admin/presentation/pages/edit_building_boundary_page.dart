import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:indoor_navigation/features/buildings/presentation/bloc/buildings_bloc.dart';
import 'package:indoor_navigation/features/buildings/domain/entities/building.dart';
import 'package:indoor_navigation/core/navigation/app_navigator.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:indoor_navigation/core/theme/app_theme.dart';

class EditBuildingBoundaryPage extends StatefulWidget {
  final Building building;

  const EditBuildingBoundaryPage({super.key, required this.building});

  @override
  State<EditBuildingBoundaryPage> createState() => _EditBuildingBoundaryPageState();
}

class _EditBuildingBoundaryPageState extends State<EditBuildingBoundaryPage> {
  final Completer<GoogleMapController> _controller = Completer();
  final List<LatLng> _boundaryPoints = [];
  final Set<Marker> _markers = {};
  final Set<Polygon> _polygons = {};
  
  bool _isLoadingLocation = true;
  bool _isFetchingAddress = false;
  final bool _isEditMode = true; // Start in edit mode
  int? _selectedPointIndex;
  String _buildingName = '';
  String _buildingAddress = '';
  String _buildingDescription = '';
  String? _autoFetchedAddress;
  bool _hasChanges = false;

  static const String _openWeatherApiKey = 'b85432bbf800736d6ce856b0a41b1ebc';

  @override
  void initState() {
    super.initState();
    _initializeBuildingData();
    _requestLocationPermission();
  }

  void _initializeBuildingData() {
    _buildingName = widget.building.name;
    _buildingAddress = widget.building.address;
    _buildingDescription = widget.building.description ?? '';

    // Load existing boundary points
    if (widget.building.boundaryPoints != null) {
      for (var point in widget.building.boundaryPoints!) {
        _boundaryPoints.add(LatLng(
          (point['lat'] as num).toDouble(),
          (point['lng'] as num).toDouble(),
        ));
      }
    }
    _updateMarkers();
    _updatePolygon();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      _moveToBuilding();
    } else {
      setState(() => _isLoadingLocation = false);
      Fluttertoast.showToast(
        msg: 'Location permission required',
        backgroundColor: Colors.orange,
      );
    }
  }

  Future<void> _moveToBuilding() async {
    try {
      final buildingLocation = LatLng(widget.building.latitude, widget.building.longitude);
      
      setState(() => _isLoadingLocation = false);

      final controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: buildingLocation, zoom: 18),
        ),
      );
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      Fluttertoast.showToast(
        msg: 'Failed to load building location',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _fetchAddressForLocation(LatLng location) async {
    setState(() => _isFetchingAddress = true);
    
    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=${location.latitude}&lon=${location.longitude}&appid=$_openWeatherApiKey'
      );
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final cityName = data['name'] ?? '';
        final country = data['sys']?['country'] ?? '';
        
        setState(() {
          _autoFetchedAddress = cityName.isNotEmpty 
              ? '$cityName${country.isNotEmpty ? ", $country" : ""}'
              : 'Address not found';
          _isFetchingAddress = false;
        });
      } else {
        setState(() {
          _autoFetchedAddress = 'Unable to fetch address';
          _isFetchingAddress = false;
        });
      }
    } catch (e) {
      setState(() {
        _autoFetchedAddress = 'Error fetching address';
        _isFetchingAddress = false;
      });
    }
  }

  void _onMapTap(LatLng position) {
    if (_isEditMode && _selectedPointIndex != null) {
      // Update the selected point position
      setState(() {
        _boundaryPoints[_selectedPointIndex!] = position;
        _selectedPointIndex = null;
        _hasChanges = true;
        _updateMarkers();
        _updatePolygon();
      });
      Fluttertoast.showToast(
        msg: 'Point updated',
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: Colors.green.shade600,
      );
    } else {
      // Add new point
      setState(() {
        _boundaryPoints.add(position);
        _hasChanges = true;
        _updateMarkers();
        _updatePolygon();
      });

      Fluttertoast.showToast(
        msg: 'Point ${_boundaryPoints.length} added',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: AppColors.primaryOrange,
      );
    }
  }

  void _onMarkerTap(int index) {
    setState(() {
      _selectedPointIndex = index;
    });
    Fluttertoast.showToast(
      msg: 'Tap on map to move point ${index + 1}',
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.orange.shade600,
    );
  }

  void _cancelEditMode() {
    setState(() {
      _selectedPointIndex = null;
    });
    Fluttertoast.showToast(
      msg: 'Point selection cancelled',
      backgroundColor: Colors.grey.shade600,
    );
  }

  void _deletePoint(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Point?'),
        content: Text('Remove point ${index + 1}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _boundaryPoints.removeAt(index);
                _hasChanges = true;
                _updateMarkers();
                _updatePolygon();
              });
              Navigator.pop(context);
              Fluttertoast.showToast(
                msg: 'Point deleted',
                backgroundColor: Colors.red.shade600,
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _updateMarkers() {
    _markers.clear();
    for (int i = 0; i < _boundaryPoints.length; i++) {
      final isSelected = _selectedPointIndex == i;
      _markers.add(
        Marker(
          markerId: MarkerId('point_$i'),
          position: _boundaryPoints[i],
          draggable: true,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueBlue,
          ),
          infoWindow: InfoWindow(
            title: isSelected ? '📍 Editing Point ${i + 1}' : '📍 Point ${i + 1}',
            snippet: 'Drag to move or tap for options',
          ),
          onTap: () => _showPointOptions(i),
          onDragEnd: (newPosition) => _onMarkerDragEnd(i, newPosition),
        ),
      );
    }
  }

  void _onMarkerDragEnd(int index, LatLng newPosition) {
    setState(() {
      _boundaryPoints[index] = newPosition;
      _hasChanges = true;
      _updateMarkers();
      _updatePolygon();
    });
    Fluttertoast.showToast(
      msg: 'Point ${index + 1} moved',
      backgroundColor: AppColors.primaryOrange,
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  void _updatePolygon() {
    _polygons.clear();
    if (_boundaryPoints.length >= 3) {
      _polygons.add(
        Polygon(
          polygonId: const PolygonId('building_boundary'),
          points: _boundaryPoints,
          strokeColor: AppColors.primaryOrange,
          strokeWidth: 3,
          fillColor: AppColors.primaryOrange.withOpacity(0.25),
        ),
      );
    }
  }

  void _removeLastPoint() {
    if (_boundaryPoints.isNotEmpty) {
      setState(() {
        _boundaryPoints.removeLast();
        _hasChanges = true;
        _updateMarkers();
        _updatePolygon();
      });
      Fluttertoast.showToast(
        msg: 'Last point removed',
        backgroundColor: Colors.orange.shade600,
      );
    }
  }

  void _clearAllPoints() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Points?'),
        content: const Text('This will remove all boundary points.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _boundaryPoints.clear();
                _markers.clear();
                _polygons.clear();
                _hasChanges = true;
                _autoFetchedAddress = null;
              });
              Navigator.pop(context);
              Fluttertoast.showToast(
                msg: 'All points cleared',
                backgroundColor: Colors.red.shade600,
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPointOptions(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
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
            Text(
              'Point ${index + 1}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lat: ${_boundaryPoints[index].latitude.toStringAsFixed(6)}\nLng: ${_boundaryPoints[index].longitude.toStringAsFixed(6)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit_location, color: AppColors.primaryOrange),
              ),
              title: const Text('Move Point'),
              subtitle: const Text('Tap on map to reposition'),
              onTap: () {
                Navigator.pop(context);
                _onMarkerTap(index);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete, color: Colors.red.shade700),
              ),
              title: const Text('Delete Point'),
              subtitle: const Text('Remove this point'),
              onTap: () {
                Navigator.pop(context);
                _deletePoint(index);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  LatLng _calculateCenter() {
    if (_boundaryPoints.isEmpty) {
      return LatLng(widget.building.latitude, widget.building.longitude);
    }
    
    double lat = 0;
    double lng = 0;
    for (var point in _boundaryPoints) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / _boundaryPoints.length, lng / _boundaryPoints.length);
  }

  double _calculateArea() {
    if (_boundaryPoints.length < 3) return 0;
    
    double area = 0;
    for (int i = 0; i < _boundaryPoints.length; i++) {
      int j = (i + 1) % _boundaryPoints.length;
      area += _boundaryPoints[i].latitude * _boundaryPoints[j].longitude;
      area -= _boundaryPoints[j].latitude * _boundaryPoints[i].longitude;
    }
    return (area.abs() / 2) * 111000 * 111000; // Approximate area in square meters
  }

  void _saveChanges() {
    if (_boundaryPoints.length < 3) {
      Fluttertoast.showToast(
        msg: 'Please mark at least 3 boundary points',
        backgroundColor: Colors.orange,
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    final center = _calculateCenter();
    final boundaryPoints = _boundaryPoints
        .map((point) => {'lat': point.latitude, 'lng': point.longitude})
        .toList();

    context.read<BuildingsBloc>().add(
      UpdateBuildingBoundaryEvent(
        buildingId: widget.building.id,
        latitude: center.latitude,
        longitude: center.longitude,
        boundaryPoints: boundaryPoints,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Unsaved Changes'),
              content: const Text('You have unsaved changes. Do you want to discard them?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Edit ${widget.building.name}'),
          backgroundColor: Colors.orange.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            if (_selectedPointIndex != null)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _cancelEditMode,
                tooltip: 'Cancel Selection',
              ),
            if (_boundaryPoints.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: _removeLastPoint,
                tooltip: 'Remove Last Point',
              ),
            if (_boundaryPoints.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: _clearAllPoints,
                tooltip: 'Clear All',
              ),
          ],
        ),
        body: BlocListener<BuildingsBloc, BuildingsState>(
          listener: (context, state) {
            if (state is BuildingUpdatedState) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 28),
                      SizedBox(width: 12),
                      Text('Success!'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Building boundary updated successfully!'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '✓ ${_boundaryPoints.length} boundary points saved',
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '✓ Area: ${_calculateArea().toStringAsFixed(0)} m²',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        AppNavigator.pop();
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            } else if (state is BuildingsErrorState) {
              Fluttertoast.showToast(
                msg: 'Error: ${state.message}',
                backgroundColor: Colors.red,
                toastLength: Toast.LENGTH_LONG,
              );
            }
          },
          child: Stack(
            children: [
              // Google Map
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(widget.building.latitude, widget.building.longitude),
                  zoom: 18,
                ),
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                },
                onTap: _onMapTap,
                markers: _markers,
                polygons: _polygons,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                mapType: MapType.satellite,
                zoomControlsEnabled: true,
                compassEnabled: true,
                mapToolbarEnabled: false,
                minMaxZoomPreference: const MinMaxZoomPreference(10, 22),
                tiltGesturesEnabled: false,
                rotateGesturesEnabled: true,
              ),

              // Instructions Card
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Card(
                  elevation: 8,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedPointIndex != null
                                    ? 'Tap map to move selected point'
                                    : 'Drag markers or tap to add points',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  _LegendItem(color: AppColors.primaryOrange, label: 'Points'),
                                  const SizedBox(width: 16),
                                  _LegendItem(color: Colors.orange.shade700, label: 'Selected'),
                                  const SizedBox(width: 16),
                                  _LegendItem(color: AppColors.primaryOrangeLight, label: 'Area'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Drag markers to adjust or tap to add new points',
                                        style: TextStyle(fontSize: 11, color: Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Stats Card
              if (_boundaryPoints.isNotEmpty)
                Positioned(
                  bottom: 100,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 8,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            icon: Icons.location_on,
                            label: 'Points',
                            value: '${_boundaryPoints.length}',
                            color: AppColors.primaryOrange,
                          ),
                          Container(width: 1, height: 40, color: Colors.grey.shade300),
                          _StatItem(
                            icon: Icons.square_foot,
                            label: 'Area',
                            value: '${_calculateArea().toStringAsFixed(0)} m²',
                            color: Colors.green.shade700,
                          ),
                          if (_hasChanges) ...[
                            Container(width: 1, height: 40, color: Colors.grey.shade300),
                            _StatItem(
                              icon: Icons.edit,
                              label: 'Status',
                              value: 'Modified',
                              color: Colors.orange.shade700,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

              // Loading Indicator
              if (_isLoadingLocation)
                Container(
                  color: Colors.black87,
                  child: Center(
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.orange.shade700,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Loading building location...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: _boundaryPoints.length >= 3 && _hasChanges
            ? FloatingActionButton.extended(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                elevation: 8,
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}