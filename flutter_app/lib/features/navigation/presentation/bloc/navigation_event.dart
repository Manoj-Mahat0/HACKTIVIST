import 'package:equatable/equatable.dart';
import 'package:indoor_navigation/features/navigation/domain/entities/navigation_request.dart';

// Events
abstract class NavigationEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class StartNavigationEvent extends NavigationEvent {
  final NavigationRequest request;
  StartNavigationEvent({required this.request});
  @override
  List<Object?> get props => [request];
}

class LoadArMarkersEvent extends NavigationEvent {
  final String buildingId;
  LoadArMarkersEvent({required this.buildingId});
  @override
  List<Object?> get props => [buildingId];
}

class StopNavigationEvent extends NavigationEvent {}

class LoadBuildingLocations extends NavigationEvent {
  final String buildingId;
  LoadBuildingLocations(this.buildingId);
  @override
  List<Object?> get props => [buildingId];
}

class CalculateRoute extends NavigationEvent {
  final String buildingId;
  final String startNodeId;
  final String endNodeId;
  final bool accessible;
  final bool avoidCrowds;
  final double stepLength;
  final double walkingSpeed;
  
  CalculateRoute({
    required this.buildingId,
    required this.startNodeId,
    required this.endNodeId,
    this.accessible = false,
    this.avoidCrowds = false,
    this.stepLength = 0.7,
    this.walkingSpeed = 1.2,
  });
  
  @override
  List<Object?> get props => [
    buildingId, 
    startNodeId, 
    endNodeId, 
    accessible, 
    avoidCrowds, 
    stepLength, 
    walkingSpeed,
  ];
}