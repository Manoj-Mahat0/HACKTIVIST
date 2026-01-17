import 'package:indoor_navigation/features/navigation/domain/entities/navigation_request.dart';
import 'package:indoor_navigation/features/navigation/domain/entities/navigation_response.dart';
import 'package:indoor_navigation/features/navigation/domain/entities/ar_marker.dart';

abstract class NavigationRepository {
  Future<NavigationResponse> getNavigation(NavigationRequest request);
  Future<List<ArMarker>> getArMarkers(String buildingId);
  
  // Smart Navigation methods
  Future<List<Map<String, dynamic>>> getBuildingLocations(String buildingId);
  Future<List<Map<String, dynamic>>> calculateRoute(
    String buildingId, 
    String startNodeId, 
    String endNodeId, {
    bool accessible = false,
    bool avoidCrowds = false,
    double stepLength = 0.7,
    double walkingSpeed = 1.2,
  });
}