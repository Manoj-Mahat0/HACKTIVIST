abstract class ARGuidanceEvent {
  const ARGuidanceEvent();
}

/// Initialize AR guidance with route steps
class InitializeARGuidance extends ARGuidanceEvent {
  final List<dynamic> routeSteps; // RouteStep list
  final String buildingName;
  final dynamic startNode; // NavigationNode
  final dynamic endNode; // NavigationNode

  const InitializeARGuidance({
    required this.routeSteps,
    required this.buildingName,
    required this.startNode,
    required this.endNode,
  });
}

/// Update user's current heading (from compass)
class UpdateUserHeading extends ARGuidanceEvent {
  final double heading;

  const UpdateUserHeading(this.heading);
}

/// Update user's current position (from GPS/pedometer)
class UpdateUserPosition extends ARGuidanceEvent {
  final double x;
  final double y;
  final int stepCount;

  const UpdateUserPosition({
    required this.x,
    required this.y,
    required this.stepCount,
  });
}

/// Move to next milestone
class MoveToNextMilestone extends ARGuidanceEvent {
  const MoveToNextMilestone();
}

/// Move to previous milestone
class MoveToPreviousMilestone extends ARGuidanceEvent {
  const MoveToPreviousMilestone();
}

/// Enable/disable audio guidance
class ToggleAudioGuidance extends ARGuidanceEvent {
  final bool enabled;

  const ToggleAudioGuidance(this.enabled);
}

/// Request audio instruction for current step
class RequestAudioInstruction extends ARGuidanceEvent {
  const RequestAudioInstruction();
}

/// Exit AR navigation
class ExitARNavigation extends ARGuidanceEvent {
  const ExitARNavigation();
}

/// Check if user is aligned with target direction
class CheckDirectionAlignment extends ARGuidanceEvent {
  const CheckDirectionAlignment();
}

/// Update route visibility
class UpdateRouteVisibility extends ARGuidanceEvent {
  final bool showRoute;
  final bool showFootsteps;
  final bool showArrow;

  const UpdateRouteVisibility({
    required this.showRoute,
    required this.showFootsteps,
    required this.showArrow,
  });
}
