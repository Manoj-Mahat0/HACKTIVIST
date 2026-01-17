import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:indoor_navigation/features/buildings/presentation/bloc/buildings_bloc.dart';
import 'package:indoor_navigation/core/navigation/app_navigator.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:indoor_navigation/core/theme/app_theme.dart';

class CreateBuildingPage extends StatefulWidget {
  const CreateBuildingPage({super.key});

  @override
  State<CreateBuildingPage> createState() => _CreateBuildingPageState();
}

class _CreateBuildingPageState extends State<CreateBuildingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  
  bool _isLoadingLocation = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
        _isLoadingLocation = false;
      });
      Fluttertoast.showToast(
        msg: 'Location captured!',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      Fluttertoast.showToast(
        msg: 'Failed to get location: ${e.toString()}',
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  void _createBuilding() {
    if (_formKey.currentState!.validate()) {
      final latitude = double.parse(_latitudeController.text);
      final longitude = double.parse(_longitudeController.text);

      context.read<BuildingsBloc>().add(
        CreateBuildingEvent(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          address: _addressController.text.trim(),
          latitude: latitude,
          longitude: longitude,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Building'),
        elevation: 0,
      ),
      body: BlocListener<BuildingsBloc, BuildingsState>(
        listener: (context, state) {
          if (state is BuildingCreatedState) {
            Fluttertoast.showToast(
              msg: 'Building created successfully!',
              backgroundColor: Colors.green,
            );
            AppNavigator.pop();
          } else if (state is BuildingsErrorState) {
            Fluttertoast.showToast(
              msg: 'Error: ${state.message}',
              backgroundColor: Colors.red,
              toastLength: Toast.LENGTH_LONG,
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                Card(
                  color: AppColors.primaryOrange.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.primaryOrange),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Create a building to start mapping indoor spaces',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Building Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Building Name *',
                    hintText: 'e.g., Main Campus Building',
                    prefixIcon: const Icon(Icons.business),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter building name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Brief description of the building',
                    prefixIcon: const Icon(Icons.description),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Address
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Address *',
                    hintText: 'Full address of the building',
                    prefixIcon: const Icon(Icons.location_on),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // GPS Coordinates Section
                Text(
                  'GPS Coordinates',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set the building\'s location on the map',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),

                // Use Current Location Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                    icon: _isLoadingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(_isLoadingLocation ? 'Getting location...' : 'Use Current Location'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Latitude
                TextFormField(
                  controller: _latitudeController,
                  decoration: InputDecoration(
                    labelText: 'Latitude *',
                    hintText: 'e.g., 28.7041',
                    prefixIcon: const Icon(Icons.place),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter latitude';
                    }
                    final lat = double.tryParse(value);
                    if (lat == null || lat < -90 || lat > 90) {
                      return 'Invalid latitude (-90 to 90)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Longitude
                TextFormField(
                  controller: _longitudeController,
                  decoration: InputDecoration(
                    labelText: 'Longitude *',
                    hintText: 'e.g., 77.1025',
                    prefixIcon: const Icon(Icons.place),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter longitude';
                    }
                    final lng = double.tryParse(value);
                    if (lng == null || lng < -180 || lng > 180) {
                      return 'Invalid longitude (-180 to 180)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Create Button
                BlocBuilder<BuildingsBloc, BuildingsState>(
                  builder: (context, state) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: state is BuildingsLoadingState ? null : _createBuilding,
                        icon: state is BuildingsLoadingState
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_business),
                        label: const Text('Create Building'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: AppColors.primaryOrange,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Next Steps Card
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            const Text(
                              'Next Steps',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const _NextStepItem(
                          number: '1',
                          text: 'After creating, go to Coordinate Collection',
                        ),
                        const SizedBox(height: 8),
                        const _NextStepItem(
                          number: '2',
                          text: 'Walk around and collect GPS points on each floor',
                        ),
                        const SizedBox(height: 8),
                        const _NextStepItem(
                          number: '3',
                          text: 'Generate 3D model with AI to create rooms & waypoints',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NextStepItem extends StatelessWidget {
  final String number;
  final String text;

  const _NextStepItem({
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.green.shade600,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }
}
