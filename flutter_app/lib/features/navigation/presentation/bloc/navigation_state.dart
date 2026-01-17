import 'package:equatable/equatable.dart';
import 'package:indoor_navigation/features/navigation/domain/entities/navigation_response.dart';
import 'package:indoor_navigation/features/navigation/domain/entities/ar_marker.dart';
import 'package:indoor_navigation/models/navigation_node.dart';

// States
abstract class NavigationState extends Equatable {
  @override
  List<Object?> get props => [];
}

class NavigationInitialState extends NavigationState {}
class NavigationLoadingState extends NavigationState {}
class NavigationLoading extends NavigationState {}

class NavigationError extends NavigationState {
  final String message;
  NavigationError(this.message);
  @override
  List<Object?> get props => [message];
}

class LocationsLoaded extends NavigationState {
  final List<NavigationNode> locations;
  LocationsLoaded(this.locations);
  @override
  List<Object?> get props => [locations];
}

class RouteCalculated extends NavigationState {
  final List<Map<String, dynamic>> steps;
  RouteCalculated(this.steps);
  @override
  List<Object?> get props => [steps];
}

class NavigationActiveState extends NavigationState {
  final NavigationResponse navigationResponse;
  final List<ArMarker> arMarkers;
  NavigationActiveState({
    required this.navigationResponse,
    required this.arMarkers,
  });
  @override
  List<Object?> get props => [navigationResponse, arMarkers];
}

class NavigationErrorState extends NavigationState {
  final String message;
  NavigationErrorState({required this.message});
  @override
  List<Object?> get props => [message];
}

class ArMarkersLoadedState extends NavigationState {
  final List<ArMarker> arMarkers;
  ArMarkersLoadedState({required this.arMarkers});
  @override
  List<Object?> get props => [arMarkers];
}