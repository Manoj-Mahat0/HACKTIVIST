import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:indoor_navigation/features/buildings/presentation/bloc/buildings_bloc.dart';
import 'package:indoor_navigation/core/navigation/app_navigator.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:indoor_navigation/core/theme/app_theme.dart';

class CreateBuildingMapPage extends StatefulWidget {
  const CreateBuildingMapPage({super.key});

  @override
  State<CreateBuildingMapPage> createState() => _CreateBuildingMapPageState();
}

class _CreateBuildingMapPageState extends State<CreateBuildingMapPage> {
  final Completer<GoogleMapController> _controller = Completer();
  final List<LatLng> _boundaryPoints = [];
  final Set<Marker> _markers = {};
  final Set<Polygon> _polygons = {};
  
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  bool _isFetchingAddress = false;
  bool _isEditMode = false;
  int? _selectedPointIndex;
  String _buildingName = '';
  String _buildingAddress = '';
  String _buildingDescription = '';
  String? _autoFetchedAddress;

  static const String _openWeatherApiKey = 'b85432bbf800736d6ce856b0a41b1ebc';

  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(28.7041, 77.1025), // Default to Delhi
    zoom: 18,
  );

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
    } else {
      setState(() => _isLoadingLocation = false);
      Fluttertoast.showToast(
        msg: 'Location permission required',
        backgroundColor: Colors.orange,
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final location = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _currentLocation = location;
        _isLoadingLocation = false;
      });

      final controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: 18),
        ),
      );

      // Auto-fetch address for current location
      _fetchAddressForLocation(location);
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      Fluttertoast.showToast(
        msg: 'Failed to get location',
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
        _isEditMode = false;
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
        _updateMarkers();
        _updatePolygon();
      });

      // Fetch address for first point
      if (_boundaryPoints.length == 1) {
        _fetchAddressForLocation(position);
      }

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
      _isEditMode = true;
    });
    Fluttertoast.showToast(
      msg: 'Tap on map to move point ${index + 1}',
      toastLength: Toast.LENGTH_LONG,
      backgroundColor: Colors.orange.shade600,
    );
  }

  void _cancelEditMode() {
    setState(() {
      _isEditMode = false;
      _selectedPointIndex = null;
    });
    Fluttertoast.showToast(
      msg: 'Edit cancelled',
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
      final isSelected = _isEditMode && _selectedPointIndex == i;
      _markers.add(
        Marker(
          markerId: MarkerId('point_$i'),
          position: _boundaryPoints[i],
          draggable: true, // Make markers draggable
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
      _updateMarkers();
      _updatePolygon();
    });
    Fluttertoast.showToast(
      msg: 'Point ${index + 1} moved',
      backgroundColor: AppColors.primaryOrange,
      toastLength: Toast.LENGTH_SHORT,
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

  LatLng _calculateCenter() {
    if (_boundaryPoints.isEmpty) return _currentLocation ?? const LatLng(0, 0);
    
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

  void _showNameDialog() {
    if (_boundaryPoints.length < 3) {
      Fluttertoast.showToast(
        msg: 'Please mark at least 3 boundary points',
        backgroundColor: Colors.orange,
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _BuildingDetailsDialog(
        suggestedAddress: _autoFetchedAddress,
        boundaryPointsCount: _boundaryPoints.length,
        estimatedArea: _calculateArea(),
        onSave: (name, address, description) {
          setState(() {
            _buildingName = name;
            _buildingAddress = address;
            _buildingDescription = description;
          });
          _createBuilding();
        },
      ),
    );
  }

  void _createBuilding() {
    final center = _calculateCenter();
    final boundaryPoints = _boundaryPoints
        .map((point) => {'lat': point.latitude, 'lng': point.longitude})
        .toList();

    context.read<BuildingsBloc>().add(
      CreateBuildingWithBoundaryEvent(
        name: _buildingName,
        description: _buildingDescription,
        address: _buildingAddress,
        latitude: center.latitude,
        longitude: center.longitude,
        boundaryPoints: boundaryPoints,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Building Boundary'),
        elevation: 0,
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: Colors.white,
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelEditMode,
              tooltip: 'Cancel Edit',
            ),
          if (_boundaryPoints.isNotEmpty && !_isEditMode)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() => _isEditMode = true);
                Fluttertoast.showToast(
                  msg: 'Drag markers to adjust boundary',
                  backgroundColor: AppColors.primaryOrange,
                  toastLength: Toast.LENGTH_LONG,
                );
              },
              tooltip: 'Edit Boundary',
            ),
          if (_boundaryPoints.isNotEmpty && !_isEditMode)
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _removeLastPoint,
              tooltip: 'Remove Last Point',
            ),
          if (_boundaryPoints.isNotEmpty && !_isEditMode)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearAllPoints,
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: BlocListener<BuildingsBloc, BuildingsState>(
        listener: (context, state) {
          if (state is BuildingCreatedState) {
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
                    const Text('Building created successfully!'),
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
              initialCameraPosition: _defaultPosition,
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
                              color: _isEditMode ? Colors.orange.shade700 : AppColors.primaryOrange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _isEditMode ? Icons.edit : Icons.touch_app,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _isEditMode 
                                  ? 'Drag markers to adjust boundary' 
                                  : 'Tap map to mark boundary',
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
                                if (_isEditMode)
                                  _LegendItem(color: Colors.orange.shade700, label: 'Draggable'),
                                if (!_isEditMode)
                                  _LegendItem(color: AppColors.primaryOrangeLight, label: 'Area'),
                              ],
                            ),
                            if (_isEditMode) ...[
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
                                        'Drag any marker to reposition it',
                                        style: TextStyle(fontSize: 11, color: Colors.black87),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_isFetchingAddress) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryOrange,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Fetching address...',
                                style: TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_autoFetchedAddress != null && !_isFetchingAddress) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.location_city, size: 16, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _autoFetchedAddress!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                            color: AppColors.primaryOrange,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Getting your location...',
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
      floatingActionButton: _boundaryPoints.length >= 3 && !_isEditMode
          ? FloatingActionButton.extended(
              onPressed: _showNameDialog,
              icon: const Icon(Icons.check_circle),
              label: const Text('Create Building'),
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              elevation: 8,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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

class _BuildingDetailsDialog extends StatefulWidget {
  final String? suggestedAddress;
  final int boundaryPointsCount;
  final double estimatedArea;
  final Function(String name, String address, String description) onSave;

  const _BuildingDetailsDialog({
    this.suggestedAddress,
    required this.boundaryPointsCount,
    required this.estimatedArea,
    required this.onSave,
  });

  @override
  State<_BuildingDetailsDialog> createState() => _BuildingDetailsDialogState();
}

class _BuildingDetailsDialogState extends State<_BuildingDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.suggestedAddress != null) {
      _addressController.text = widget.suggestedAddress!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      widget.onSave(
        _nameController.text.trim(),
        _addressController.text.trim(),
        _descriptionController.text.trim(),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.business, color: Colors.green.shade600),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Building Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryOrange, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${widget.boundaryPointsCount}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryOrange,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Points',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 40, color: AppColors.textSecondary.withOpacity(0.3)),
                          Column(
                            children: [
                              Text(
                                widget.estimatedArea.toStringAsFixed(0),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Area (m²)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Building Name *',
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                    hintText: 'e.g., Main Campus Building',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
                    ),
                    prefixIcon: Icon(Icons.business, color: AppColors.primaryOrange),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  style: const TextStyle(color: Colors.black87),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter building name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Address *',
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                    hintText: 'Full address',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
                    ),
                    prefixIcon: Icon(Icons.location_on, color: AppColors.primaryOrange),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    helperText: widget.suggestedAddress != null 
                        ? 'Auto-detected from location' 
                        : null,
                    helperStyle: TextStyle(color: Colors.green.shade700, fontSize: 11),
                  ),
                  style: const TextStyle(color: Colors.black87),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                    hintText: 'Brief description',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
                    ),
                    prefixIcon: Icon(Icons.description, color: AppColors.primaryOrange),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  style: const TextStyle(color: Colors.black87),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check),
                      label: const Text('Create'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
