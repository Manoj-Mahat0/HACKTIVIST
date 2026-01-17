import 'package:equatable/equatable.dart';

abstract class ARGuidanceState extends Equatable {
  const ARGuidanceState();
  
  @override
  List<Object?> get props => [];
}

/// Initial state
class ARGuidanceInitial extends ARGuidanceState {
  const ARGuidanceInitial();
}

/// AR guidance is initialized and ready
class ARGuidanceReady extends ARGuidanceState {
  final int currentStepIndex;
  final int totalSteps;
  final double userHeading;
  final double targetHeading;
  final double distanceToTarget;
  final String currentInstruction;
  final String currentMilestoneName;
  final String nextMilestoneName;
  final double progress;
  final bool isDirectionAligned;
  final bool audioEnabled;

  const ARGuidanceReady({
    required this.currentStepIndex,
    required this.totalSteps,
    required this.userHeading,
    required this.targetHeading,
    required this.distanceToTarget,
    required this.currentInstruction,
    required this.currentMilestoneName,
    required this.nextMilestoneName,
    required this.progress,
    required this.isDirectionAligned,
    required this.audioEnabled,
  });

  ARGuidanceReady copyWith({
    int? currentStepIndex,
    int? totalSteps,
    double? userHeading,
    double? targetHeading,
    double? distanceToTarget,
    String? currentInstruction,
    String? currentMilestoneName,
    String? nextMilestoneName,
    double? progress,
    bool? isDirectionAligned,
    bool? audioEnabled,
  }) {
    return ARGuidanceReady(
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      totalSteps: totalSteps ?? this.totalSteps,
      userHeading: userHeading ?? this.userHeading,
      targetHeading: targetHeading ?? this.targetHeading,
      distanceToTarget: distanceToTarget ?? this.distanceToTarget,
      currentInstruction: currentInstruction ?? this.currentInstruction,
      currentMilestoneName: currentMilestoneName ?? this.currentMilestoneName,
      nextMilestoneName: nextMilestoneName ?? this.nextMilestoneName,
      progress: progress ?? this.progress,
      isDirectionAligned: isDirectionAligned ?? this.isDirectionAligned,
      audioEnabled: audioEnabled ?? this.audioEnabled,
    );
  }

  @override
  List<Object?> get props => [
    currentStepIndex,
    totalSteps,
    userHeading,
    targetHeading,
    distanceToTarget,
    currentInstruction,
    currentMilestoneName,
    nextMilestoneName,
    progress,
    isDirectionAligned,
    audioEnabled,
  ];
}

/// Milestone reached - play celebration
class MilestoneReached extends ARGuidanceState {
  final String milestoneName;
  final int milestoneIndex;
  final int totalMilestones;

  const MilestoneReached({
    required this.milestoneName,
    required this.milestoneIndex,
    required this.totalMilestones,
  });

  @override
  List<Object?> get props => [milestoneName, milestoneIndex, totalMilestones];
}

/// Navigation completed successfully
class NavigationCompleted extends ARGuidanceState {
  final String destinationName;
  final int totalSteps;

  const NavigationCompleted({
    required this.destinationName,
    required this.totalSteps,
  });

  @override
  List<Object?> get props => [destinationName, totalSteps];
}

/// Audio instruction is being played
class AudioInstructionPlaying extends ARGuidanceState {
  final String instruction;
  final bool isPlaying;

  const AudioInstructionPlaying({
    required this.instruction,
    required this.isPlaying,
  });

  @override
  List<Object?> get props => [instruction, isPlaying];
}

/// Direction alignment status
class DirectionAlignmentStatus extends ARGuidanceState {
  final bool isAligned;
  final double headingDifference;
  final String alignmentHint;

  const DirectionAlignmentStatus({
    required this.isAligned,
    required this.headingDifference,
    required this.alignmentHint,
  });

  @override
  List<Object?> get props => [isAligned, headingDifference, alignmentHint];
}

/// Route visibility settings changed
class RouteVisibilityUpdated extends ARGuidanceState {
  final bool showRoute;
  final bool showFootsteps;
  final bool showArrow;

  const RouteVisibilityUpdated({
    required this.showRoute,
    required this.showFootsteps,
    required this.showArrow,
  });

  @override
  List<Object?> get props => [showRoute, showFootsteps, showArrow];
}

/// Error occurred during guidance
class ARGuidanceError extends ARGuidanceState {
  final String message;
  final String? code;

  const ARGuidanceError({
    required this.message,
    this.code,
  });

  @override
  List<Object?> get props => [message, code];
}

/// Navigation exited
class ARNavigationExited extends ARGuidanceState {
  final String reason;

  const ARNavigationExited({required this.reason});

  @override
  List<Object?> get props => [reason];
}
