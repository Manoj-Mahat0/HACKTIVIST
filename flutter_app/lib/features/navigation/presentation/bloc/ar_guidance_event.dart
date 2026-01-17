import 'package:equatable/equatable.dart';

/// Base class for AR guidance events
abstract class ARGuidanceEvent extends Equatable {
  const ARGuidanceEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize AR guidance with route data
class InitializeARGuidance extends ARGuidanceEvent {
  final List<Map<String, dynamic>> route;
  final Map<String, dynamic> startNode;
  final Map<String, dynamic> endNode;

  const InitializeARGuidance({
    required this.route,
    required this.startNode,
    required this.endNode,
  });

  @override
  List<Object?> get props => [route, startNode, endNode];
}

/// Update user's current heading from compass
class UpdateUserHeading extends ARGuidanceEvent {
  final double heading; // Degrees (0-360)

  const UpdateUserHeading(this.heading);

  @override
  List<Object?> get props => [heading];
}

/// Update user's current position from PDR or GPS
class UpdateUserPosition extends ARGuidanceEvent {
  final double x;
  final double y;
  final int floorNumber;

  const UpdateUserPosition({
    required this.x,
    required this.y,
    required this.floorNumber,
  });

  @override
  List<Object?> get props => [x, y, floorNumber];
}

/// Move to next milestone in route
class MoveToNextMilestone extends ARGuidanceEvent {
  const MoveToNextMilestone();
}

/// Move to previous milestone in route
class MoveToPreviousMilestone extends ARGuidanceEvent {
  const MoveToPreviousMilestone();
}

/// Toggle audio guidance on/off
class ToggleAudioGuidance extends ARGuidanceEvent {
  const ToggleAudioGuidance();
}

/// Request audio instruction for current position
class RequestAudioInstruction extends ARGuidanceEvent {
  const RequestAudioInstruction();
}

/// Update step count from pedometer
class UpdateStepCount extends ARGuidanceEvent {
  final int steps;

  const UpdateStepCount(this.steps);

  @override
  List<Object?> get props => [steps];
}

/// Reset position from QR code scan
class ResetPositionFromQR extends ARGuidanceEvent {
  final Map<String, dynamic> node;

  const ResetPositionFromQR(this.node);

  @override
  List<Object?> get props => [node];
}

/// Recalculate route (user went off-route)
class RecalculateRoute extends ARGuidanceEvent {
  final Map<String, dynamic> currentNode;
  final Map<String, dynamic> destinationNode;

  const RecalculateRoute({
    required this.currentNode,
    required this.destinationNode,
  });

  @override
  List<Object?> get props => [currentNode, destinationNode];
}

/// Toggle route visibility on AR view
class ToggleRouteVisibility extends ARGuidanceEvent {
  const ToggleRouteVisibility();
}

/// Request emergency exit route
class RequestEmergencyExit extends ARGuidanceEvent {
  const RequestEmergencyExit();
}

/// Pause navigation
class PauseNavigation extends ARGuidanceEvent {
  const PauseNavigation();
}

/// Resume navigation
class ResumeNavigation extends ARGuidanceEvent {
  const ResumeNavigation();
}

/// Cancel navigation
class CancelNavigation extends ARGuidanceEvent {
  const CancelNavigation();
}

/// Supporting class for route steps
class RouteStep {
  final String nodeId;
  final String label;
  final double x;
  final double y;
  final int floorNumber;
  final String direction;
  final double distance;

  const RouteStep({
    required this.nodeId,
    required this.label,
    required this.x,
    required this.y,
    required this.floorNumber,
    required this.direction,
    required this.distance,
  });

  factory RouteStep.fromNode(Map<String, dynamic> node, {
    String direction = 'N',
    double distance = 0.0,
  }) {
    return RouteStep(
      nodeId: node['id'] ?? '',
      label: node['label'] ?? 'Unknown',
      x: (node['latitude'] ?? 0.0).toDouble(),
      y: (node['longitude'] ?? 0.0).toDouble(),
      floorNumber: node['floor_number'] ?? 0,
      direction: direction,
      distance: distance,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nodeId': nodeId,
      'label': label,
      'x': x,
      'y': y,
      'floorNumber': floorNumber,
      'direction': direction,
      'distance': distance,
    };
  }
}
