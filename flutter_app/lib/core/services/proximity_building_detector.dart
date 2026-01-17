import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:indoor_navigation/features/buildings/domain/entities/building.dart';

/// Result of proximity detection
class ProximityResult {
  final Building building;
  final double distance; // in meters
  final Position userPosition;

  ProximityResult({
    required this.building,
    required this.distance,
    required this.userPosition,
  });
}

/// Service to detect nearby buildings using expanding radius search
class ProximityBuildingDetector {
  static const double _initialRadius = 5.0; // Start with 5 meters
  static const double _radiusIncrement = 5.0; // Increase by 5 meters each step
  static const double _maxRadius = 100.0; // Stop at 100 meters
  static const Duration _searchInterval = Duration(seconds: 5); // Check every 5 seconds

  Timer? _searchTimer;
  Position? _lastPosition;
  ProximityResult? _lastResult;
  
  final _resultController = StreamController<ProximityResult>.broadcast();
  
  /// Stream of proximity detection results
  Stream<ProximityResult> get resultStream => _resultController.stream;
  
  /// Get last detection result
  ProximityResult? get lastResult => _lastResult;

  /// Start continuous proximity detection
  void startDetection(Stream<Position> locationStream, List<Building> buildings) {
    stopDetection();
    
    locationStream.listen((position) {
      _lastPosition = position;
      _performProximitySearch(position, buildings);
    });
    
    // Also perform periodic searches
    _searchTimer = Timer.periodic(_searchInterval, (_) {
      if (_lastPosition != null) {
        _performProximitySearch(_lastPosition!, buildings);
      }
    });
  }

  /// Perform proximity search with expanding radius
  void _performProximitySearch(Position userPosition, List<Building> buildings) {
    if (buildings.isEmpty) {
      print('⚠️ No buildings available for proximity search');
      return;
    }

    print('🔍 Starting proximity search from (${userPosition.latitude}, ${userPosition.longitude})');
    
    double currentRadius = _initialRadius;
    Building? closestBuilding;
    double closestDistance = double.infinity;

    // Expanding radius search
    while (currentRadius <= _maxRadius) {
      print('📏 Searching within ${currentRadius}m radius...');
      
      for (final building in buildings) {
        // Check if building has boundary coordinates
        if (building.boundaryCoordinates == null || building.boundaryCoordinates!.isEmpty) {
          continue;
        }

        // Calculate distance to building's center or closest boundary point
        final distance = _calculateDistanceToBuilding(userPosition, building);
        
        if (distance <= currentRadius) {
          // Found a building within current radius
          if (distance < closestDistance) {
            closestDistance = distance;
            closestBuilding = building;
          }
        }
      }

      // If we found a building, stop searching
      if (closestBuilding != null) {
        print('✅ Found building "${closestBuilding.name}" at ${closestDistance.toStringAsFixed(1)}m');
        
        final result = ProximityResult(
          building: closestBuilding,
          distance: closestDistance,
          userPosition: userPosition,
        );
        
        // Only emit if it's a new result or distance changed significantly
        if (_shouldEmitResult(result)) {
          _lastResult = result;
          _resultController.add(result);
        }
        
        return;
      }

      // Expand radius
      currentRadius += _radiusIncrement;
    }

    print('❌ No buildings found within ${_maxRadius}m');
  }

  /// Calculate distance from user position to building
  double _calculateDistanceToBuilding(Position userPosition, Building building) {
    if (building.boundaryCoordinates == null || building.boundaryCoordinates!.isEmpty) {
      return double.infinity;
    }

    // Calculate distance to building center
    final center = _calculateBuildingCenter(building.boundaryCoordinates!);
    final centerDistance = _calculateDistance(
      userPosition.latitude,
      userPosition.longitude,
      center['lat']!,
      center['lng']!,
    );

    // Also check distance to closest boundary point
    double minBoundaryDistance = double.infinity;
    for (final coord in building.boundaryCoordinates!) {
      final distance = _calculateDistance(
        userPosition.latitude,
        userPosition.longitude,
        coord['lat']!,
        coord['lng']!,
      );
      if (distance < minBoundaryDistance) {
        minBoundaryDistance = distance;
      }
    }

    // Return the smaller of center distance or closest boundary distance
    return math.min(centerDistance, minBoundaryDistance);
  }

  /// Calculate building center from boundary coordinates
  Map<String, double> _calculateBuildingCenter(List<Map<String, double>> coordinates) {
    double sumLat = 0;
    double sumLng = 0;
    
    for (final coord in coordinates) {
      sumLat += coord['lat']!;
      sumLng += coord['lng']!;
    }
    
    return {
      'lat': sumLat / coordinates.length,
      'lng': sumLng / coordinates.length,
    };
  }

  /// Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
        math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) *
        math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  /// Check if result should be emitted (avoid spam)
  bool _shouldEmitResult(ProximityResult result) {
    if (_lastResult == null) return true;
    
    // Emit if building changed
    if (_lastResult!.building.id != result.building.id) return true;
    
    // Emit if distance changed by more than 2 meters
    if ((result.distance - _lastResult!.distance).abs() > 2.0) return true;
    
    return false;
  }

  /// Perform one-time proximity search
  Future<ProximityResult?> searchOnce(Position userPosition, List<Building> buildings) async {
    if (buildings.isEmpty) return null;

    double currentRadius = _initialRadius;
    Building? closestBuilding;
    double closestDistance = double.infinity;

    while (currentRadius <= _maxRadius) {
      for (final building in buildings) {
        if (building.boundaryCoordinates == null || building.boundaryCoordinates!.isEmpty) {
          continue;
        }

        final distance = _calculateDistanceToBuilding(userPosition, building);
        
        if (distance <= currentRadius && distance < closestDistance) {
          closestDistance = distance;
          closestBuilding = building;
        }
      }

      if (closestBuilding != null) {
        return ProximityResult(
          building: closestBuilding,
          distance: closestDistance,
          userPosition: userPosition,
        );
      }

      currentRadius += _radiusIncrement;
    }

    return null;
  }

  /// Stop detection
  void stopDetection() {
    _searchTimer?.cancel();
    _searchTimer = null;
  }

  /// Dispose resources
  void dispose() {
    stopDetection();
    _resultController.close();
  }
}
