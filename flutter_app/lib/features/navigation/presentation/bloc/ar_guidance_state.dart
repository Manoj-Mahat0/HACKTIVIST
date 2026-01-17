import 'package:equatable/equatable.dart';
import 'ar_guidance_event.dart';

/// Base class for AR guidance states
abstract class ARGuidanceState extends Equatable {
  const ARGuidanceState();

  @override
  List<Object?> get props => [];
}

/// Initial state before AR guidance is initialized
class ARGuidanceInitial extends ARGuidanceState {
  const ARGuidanceInitial();
}

/// AR guidance is ready and active
class ARGuidanceReady extends ARGuidanceState {
  final List<RouteStep> route;
  final int currentMilestoneIndex;
  final double userHeading;
  final double userX;
  final double userY;
  final int userFloor;
  final int stepCount;
  final bool isAudioEnabled;
  final bool isRouteVisible;
  final bool isPaused;
  final DirectionAlignmentStatus alignmentStatus;

  const ARGuidanceReady({
    required this.route,
    required this.currentMilestoneIndex,
    required this.userHeading,
    required this.userX,
    required this.userY,
    required this.userFloor,
    this.stepCount = 0,
    this.isAudioEnabled = true,
    this.isRouteVisible = true,
    this.isPaused = false,
    this.alignmentStatus = DirectionAlignmentStatus.aligned,
  });

  RouteStep get currentMilestone => route[currentMilestoneIndex];
  RouteStep? get nextMilestone =>
      currentMilestoneIndex < route.length - 1
          ? route[currentMilestoneIndex + 1]
          : null;

  double get distanceToCurrentMilestone {
    final dx = currentMilestone.x - userX;
    final dy = currentMilestone.y - userY;
    return _calculateDistance(dx, dy);
  }

  double get directionToCurrentMilestone {
    final dx = currentMilestone.x - userX;
    final dy = currentMilestone.y - userY;
    return _calculateBearing(dx, dy);
  }

  double get totalDistance {
    double total = 0;
    for (int i = currentMilestoneIndex; i < route.length - 1; i++) {
      final dx = route[i + 1].x - route[i].x;
      final dy = route[i + 1].y - route[i].y;
      total += _calculateDistance(dx, dy);
    }
    return total + distanceToCurrentMilestone;
  }

  int get remainingSteps => route.length - currentMilestoneIndex;

  double get progressPercentage =>
      route.length > 1 ? (currentMilestoneIndex / (route.length - 1)) * 100 : 0;

  String get currentInstruction {
    if (isPaused) return 'Navigation paused';
    if (distanceToCurrentMilestone < 2) {
      return 'Arriving at ${currentMilestone.label}';
    }
    return 'Head ${_getDirectionName(currentMilestone.direction)} to ${currentMilestone.label}';
  }

  bool get isNearMilestone => distanceToCurrentMilestone < 3.0; // Within 3 meters

  ARGuidanceReady copyWith({
    List<RouteStep>? route,
    int? currentMilestoneIndex,
    double? userHeading,
    double? userX,
    double? userY,
    int? userFloor,
    int? stepCount,
    bool? isAudioEnabled,
    bool? isRouteVisible,
    bool? isPaused,
    DirectionAlignmentStatus? alignmentStatus,
  }) {
    return ARGuidanceReady(
      route: route ?? this.route,
      currentMilestoneIndex: currentMilestoneIndex ?? this.currentMilestoneIndex,
      userHeading: userHeading ?? this.userHeading,
      userX: userX ?? this.userX,
      userY: userY ?? this.userY,
      userFloor: userFloor ?? this.userFloor,
      stepCount: stepCount ?? this.stepCount,
      isAudioEnabled: isAudioEnabled ?? this.isAudioEnabled,
      isRouteVisible: isRouteVisible ?? this.isRouteVisible,
      isPaused: isPaused ?? this.isPaused,
      alignmentStatus: alignmentStatus ?? this.alignmentStatus,
    );
  }

  @override
  List<Object?> get props => [
        route,
        currentMilestoneIndex,
        userHeading,
        userX,
        userY,
        userFloor,
        stepCount,
        isAudioEnabled,
        isRouteVisible,
        isPaused,
        alignmentStatus,
      ];

  static double _calculateDistance(double dx, double dy) {
    return (dx * dx + dy * dy).abs().toDouble();
  }

  static double _calculateBearing(double dx, double dy) {
    final angle = (450 - (dy.atan2(dx) * 180 / 3.14159)) % 360;
    return angle;
  }

  static String _getDirectionName(String direction) {
    switch (direction.toUpperCase()) {
      case 'N':
        return 'north';
      case 'S':
        return 'south';
      case 'E':
        return 'east';
      case 'W':
        return 'west';
      case 'NE':
        return 'northeast';
      case 'NW':
        return 'northwest';
      case 'SE':
        return 'southeast';
      case 'SW':
        return 'southwest';
      case 'UP':
        return 'upstairs';
      case 'DOWN':
        return 'downstairs';
      default:
        return 'forward';
    }
  }
}

/// Milestone reached - trigger audio and visual feedback
class MilestoneReached extends ARGuidanceState {
  final RouteStep milestone;
  final RouteStep? nextMilestone;
  final int milestoneNumber;
  final int totalMilestones;

  const MilestoneReached({
    required this.milestone,
    this.nextMilestone,
    required this.milestoneNumber,
    required this.totalMilestones,
  });

  @override
  List<Object?> get props => [milestone, nextMilestone, milestoneNumber, totalMilestones];
}

/// Navigation completed - destination reached
class NavigationCompleted extends ARGuidanceState {
  final RouteStep destination;
  final int totalSteps;
  final double totalDistance;
  final Duration duration;

  const NavigationCompleted({
    required this.destination,
    required this.totalSteps,
    required this.totalDistance,
    required this.duration,
  });

  @override
  List<Object?> get props => [destination, totalSteps, totalDistance, duration];
}

/// Audio instruction is being played
class AudioInstructionPlaying extends ARGuidanceState {
  final String instruction;
  final ARGuidanceReady previousState;

  const AudioInstructionPlaying({
    required this.instruction,
    required this.previousState,
  });

  @override
  List<Object?> get props => [instruction, previousState];
}

/// User is off-route - recalculating
class OffRoute extends ARGuidanceState {
  final double distanceFromRoute;
  final ARGuidanceReady previousState;

  const OffRoute({
    required this.distanceFromRoute,
    required this.previousState,
  });

  @override
  List<Object?> get props => [distanceFromRoute, previousState];
}

/// Route is being recalculated
class RecalculatingRoute extends ARGuidanceState {
  final String reason;

  const RecalculatingRoute(this.reason);

  @override
  List<Object?> get props => [reason];
}

/// AR guidance error
class ARGuidanceError extends ARGuidanceState {
  final String message;
  final String? details;

  const ARGuidanceError(this.message, {this.details});

  @override
  List<Object?> get props => [message, details];
}

/// Direction alignment status
enum DirectionAlignmentStatus {
  aligned, // User is facing the right direction (within 30 degrees)
  slightlyOff, // User is 30-60 degrees off
  wayOff, // User is more than 60 degrees off
  opposite, // User is facing opposite direction (150-210 degrees off)
}

/// Helper to determine alignment status
DirectionAlignmentStatus getAlignmentStatus(double userHeading, double targetHeading) {
  double diff = (targetHeading - userHeading + 360) % 360;

  if (diff < 30 || diff > 330) {
    return DirectionAlignmentStatus.aligned;
  } else if (diff < 60 || diff > 300) {
    return DirectionAlignmentStatus.slightlyOff;
  } else if (diff >= 150 && diff <= 210) {
    return DirectionAlignmentStatus.opposite;
  } else {
    return DirectionAlignmentStatus.wayOff;
  }
}
