import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:indoor_navigation/core/services/proximity_building_detector.dart';
import 'package:indoor_navigation/features/buildings/domain/entities/building.dart';
import 'package:indoor_navigation/core/theme/app_theme.dart';
import 'package:indoor_navigation/core/navigation/app_navigator.dart';

class ProximityDetectorWidget extends StatefulWidget {
  final List<Building> buildings;
  final Stream<Position> locationStream;
  final Function(Building)? onBuildingDetected;

  const ProximityDetectorWidget({
    super.key,
    required this.buildings,
    required this.locationStream,
    this.onBuildingDetected,
  });

  @override
  State<ProximityDetectorWidget> createState() => _ProximityDetectorWidgetState();
}

class _ProximityDetectorWidgetState extends State<ProximityDetectorWidget> with SingleTickerProviderStateMixin {
  final ProximityBuildingDetector _detector = ProximityBuildingDetector();
  ProximityResult? _currentResult;
  bool _isSearching = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Start detection
    _detector.startDetection(widget.locationStream, widget.buildings);
    
    // Listen to results
    _detector.resultStream.listen((result) {
      setState(() {
        _currentResult = result;
        _isSearching = false;
      });
      
      // Notify callback
      widget.onBuildingDetected?.call(result.building);
      
      // Show notification
      _showProximityNotification(result);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _detector.dispose();
    super.dispose();
  }

  void _showProximityNotification(ProximityResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You are ${result.distance.toStringAsFixed(0)}m away from ${result.building.name}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Navigate',
          textColor: Colors.white,
          onPressed: () => _navigateToBuilding(result.building),
        ),
      ),
    );
  }

  void _navigateToBuilding(Building building) {
    // TODO: Navigate to building details or start navigation
    print('🧭 Navigating to ${building.name}');
  }

  @override
  Widget build(BuildContext context) {
    if (_currentResult == null && !_isSearching) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.all(16),
      child: _currentResult != null
          ? _buildDetectedCard(_currentResult!)
          : _buildSearchingCard(),
    );
  }

  Widget _buildSearchingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryOrange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.radar,
                color: AppColors.primaryOrange,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Searching for nearby buildings...',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Expanding search radius',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedCard(ProximityResult result) {
    final distanceText = result.distance < 1000
        ? '${result.distance.toStringAsFixed(0)}m'
        : '${(result.distance / 1000).toStringAsFixed(1)}km';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryOrange.withOpacity(0.15),
            AppColors.primaryOrange.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryOrange.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.primaryOrange,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.building.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.near_me,
                          size: 14,
                          color: AppColors.primaryOrange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$distanceText away',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.primaryOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _navigateToBuilding(result.building),
                  icon: const Icon(Icons.navigation, size: 18),
                  label: const Text('Navigate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryOrange,
                    side: const BorderSide(color: AppColors.primaryOrange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: View building details
                    print('📍 Viewing ${result.building.name}');
                  },
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
