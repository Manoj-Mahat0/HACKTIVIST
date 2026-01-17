import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../data/services/audio_feedback_service.dart';
import 'ar_guidance_event.dart';
import 'ar_guidance_state.dart';

/// AR Guidance Bloc
/// Manages AR navigation guidance logic including footstep tracking, heading calculations,
/// and milestone progress tracking
class ARGuidanceBloc extends Bloc<ARGuidanceEvent, ARGuidanceState> {
  final AudioFeedbackService _audioService;

  // Navigation data
  List<dynamic> _routeSteps = [];
  String _buildingName = '';
  dynamic _startNode;
  dynamic _endNode;

  // Current state
  int _currentStepIndex = 0;
  double _userHeading = 0;
  int _stepCount = 0;
  int _initialStepCount = 0;

  // Settings
  bool _audioEnabled = true;
  bool _showRoute = true;
  bool _showFootsteps = true;
  bool _showArrow = true;
  bool _hasAnnouncedStep = false;

  ARGuidanceBloc({AudioFeedbackService? audioService})
      : _audioService = audioService ?? AudioFeedbackService(),
        super(const ARGuidanceInitial()) {
    on<InitializeARGuidance>(_onInitialize);
    on<UpdateUserHeading>(_onUpdateHeading);
    on<UpdateUserPosition>(_onUpdatePosition);
    on<MoveToNextMilestone>(_onNextMilestone);
    on<MoveToPreviousMilestone>(_onPreviousMilestone);
    on<ToggleAudioGuidance>(_onToggleAudio);
    on<RequestAudioInstruction>(_onRequestAudioInstruction);
    on<ExitARNavigation>(_onExit);
    on<CheckDirectionAlignment>(_onCheckAlignment);
    on<UpdateRouteVisibility>(_onUpdateVisibility);
  }

  /// Initialize AR guidance with route steps
  Future<void> _onInitialize(
    InitializeARGuidance event,
    Emitter<ARGuidanceState> emit,
  ) async {
    try {
      debugPrint('🚀 Initializing AR Guidance');

      _routeSteps = event.routeSteps;
      _buildingName = event.buildingName;
      _startNode = event.startNode;
      _endNode = event.endNode;
      _currentStepIndex = 0;
      _hasAnnouncedStep = false;

      // Initialize audio service
      await _audioService.initialize();

      if (_routeSteps.isEmpty) {
        emit(const ARGuidanceError(
          message: 'No route steps available',
          code: 'EMPTY_ROUTE',
        ));
        return;
      }

      // Emit ready state
      final ready = _buildReadyState(emit);
      emit(ready);

      // Announce start of navigation
      if (_audioEnabled) {
        await _audioService.speakInstruction(
          'Navigation started. Follow the arrows on your screen.',
        );
      }

      debugPrint('✅ AR Guidance initialized successfully');
    } catch (e) {
      debugPrint('❌ Initialization error: $e');
      emit(ARGuidanceError(
        message: 'Failed to initialize AR guidance: $e',
        code: 'INIT_ERROR',
      ));
    }
  }

  /// Update user heading (compass data)
  Future<void> _onUpdateHeading(
    UpdateUserHeading event,
    Emitter<ARGuidanceState> emit,
  ) async {
    try {
      _userHeading = event.heading;

      if (state is ARGuidanceReady) {
        final currentState = state as ARGuidanceReady;
        final targetHeading = _calculateTargetHeading();
        
        emit(currentState.copyWith(
          userHeading: _userHeading,
          targetHeading: targetHeading,
        ));

        // Check alignment periodically
        _checkAndUpdateAlignment(emit, targetHeading);
      }
    } catch (e) {
      debugPrint('❌ Error updating heading: $e');
    }
  }

  /// Update user position (GPS/pedometer data)
  Future<void> _onUpdatePosition(
    UpdateUserPosition event,
    Emitter<ARGuidanceState> emit,
  ) async {
    try {
      // Update step count
      if (_initialStepCount == 0) {
        _initialStepCount = event.stepCount;
      }
      _stepCount = event.stepCount - _initialStepCount;

      if (state is ARGuidanceReady) {
        final currentState = state as ARGuidanceReady;
        final newDistance = _calculateDistanceToNext();

        emit(currentState.copyWith(
          distanceToTarget: newDistance,
        ));

        // Check if milestone should be reached
        await _checkMilestoneProgress(emit, currentState);
      }
    } catch (e) {
      debugPrint('❌ Error updating position: $e');
    }
  }

  /// Move to next milestone
  Future<void> _onNextMilestone(
    MoveToNextMilestone event,
    Emitter<ARGuidanceState> emit,
  ) async {
    try {
      if (_currentStepIndex < _routeSteps.length - 1) {
        _currentStepIndex++;
        _hasAnnouncedStep = false;
        _stepCount = 0;
        _initialStepCount = 0;

        final ready = _buildReadyState(emit);
        emit(ready);

        // Announce next step
        if (_audioEnabled) {
          final nextStep = _getRouteStep(_currentStepIndex);
          await _audioService.speakInstruction(
            'Next: ${nextStep?['name'] ?? 'next location'}',
          );
        }
      } else {
        // Navigation complete
        _announceCompletion(emit);
      }
    } catch (e) {
      debugPrint('❌ Error moving to next milestone: $e');
    }
  }

  /// Move to previous milestone
  Future<void> _onPreviousMilestone(
    MoveToPreviousMilestone event,
    Emitter<ARGuidanceState> emit,
  ) async {
    try {
      if (_currentStepIndex > 0) {
        _currentStepIndex--;
        _hasAnnouncedStep = false;
        _stepCount = 0;
        _initialStepCount = 0;

        final ready = _buildReadyState(emit);
        emit(ready);
      }
    } catch (e) {
      debugPrint('❌ Error moving to previous milestone: $e');
    }
  }

  /// Toggle audio guidance on/off
  Future<void> _onToggleAudio(
    ToggleAudioGuidance event,
    Emitter<ARGuidanceState> emit,
  ) async {
    try {
      _audioEnabled = event.enabled;

      if (!_audioEnabled) {
        await _audioService.stop();
      }

      if (state is ARGuidanceReady) {
        final currentState = state as ARGuidanceReady;
        emit(currentState.copyWith(audioEnabled: _audioEnabled));
      }
    } catch (e) {
      debugPrint('❌ Error toggling audio: $e');
    }
  }

  /// Request audio instruction for current step
  Future<void> _onRequestAudioInstruction(
    RequestAudioInstruction event,
    Emitter<ARGuidanceState> emit,
  ) async {
    try {
      final currentStep = _getRouteStep(_currentStepIndex);
      if (currentStep != null) {
        final instruction = currentStep['instruction'] ?? 'Continue';
        
        emit(AudioInstructionPlaying(instruction: instruction, isPlaying: true));
        
        await _audioService.speakInstruction(instruction);
        
        emit(AudioInstructionPlaying(instruction: instruction, isPlaying: false));
      }
    } catch (e) {
      debugPrint('❌ Error requesting audio instruction: $e');
    }
  }

  /// Exit AR navigation
  Future<void> _onExit(
    ExitARNavigation event,
    Emitter<ARGuidanceState> emit,
  ) async {
    try {
      await _audioService.stop();
      emit(const ARNavigationExited(reason: 'User exited navigation'));
    } catch (e) {
      debugPrint('❌ Error exiting navigation: $e');
    }
  }

  /// Check direction alignment
  Future<void> _onCheckAlignment(
    CheckDirectionAlignment event,
    Emitter<ARGuidanceState> emit,
  ) async {
    try {
      final targetHeading = _calculateTargetHeading();
      final difference = _calculateHeadingDifference(_userHeading, targetHeading);
      final isAligned = difference.abs() < 15; // Within 15 degrees

      final alignmentHint = _getAlignmentHint(difference);

      emit(DirectionAlignmentStatus(
        isAligned: isAligned,
        headingDifference: difference,
        alignmentHint: alignmentHint,
      ));
    } catch (e) {
      debugPrint('❌ Error checking alignment: $e');
    }
  }

  /// Update route visibility settings
  Future<void> _onUpdateVisibility(
    UpdateRouteVisibility event,
    Emitter<ARGuidanceState> emit,
  ) async {
    try {
      _showRoute = event.showRoute;
      _showFootsteps = event.showFootsteps;
      _showArrow = event.showArrow;

      emit(RouteVisibilityUpdated(
        showRoute: _showRoute,
        showFootsteps: _showFootsteps,
        showArrow: _showArrow,
      ));
    } catch (e) {
      debugPrint('❌ Error updating visibility: $e');
    }
  }

  // ============ Helper Methods ============

  /// Build ready state from current data
  ARGuidanceReady _buildReadyState(Emitter<ARGuidanceState> emit) {
    final targetHeading = _calculateTargetHeading();
    final distance = _calculateDistanceToNext();
    final progress = _calculateProgress();
    final isAligned = _calculateHeadingDifference(_userHeading, targetHeading).abs() < 15;

    final currentStep = _getRouteStep(_currentStepIndex);
    final nextStep = _getRouteStep(_currentStepIndex + 1);

    return ARGuidanceReady(
      currentStepIndex: _currentStepIndex,
      totalSteps: _routeSteps.length,
      userHeading: _userHeading,
      targetHeading: targetHeading,
      distanceToTarget: distance,
      currentInstruction: currentStep?['instruction'] ?? 'Continue',
      currentMilestoneName: currentStep?['name'] ?? 'Current Location',
      nextMilestoneName: nextStep?['name'] ?? 'Destination',
      progress: progress,
      isDirectionAligned: isAligned,
      audioEnabled: _audioEnabled,
    );
  }

  /// Calculate target heading for current step
  double _calculateTargetHeading() {
    if (_currentStepIndex >= _routeSteps.length) return 0;
    
    final step = _routeSteps[_currentStepIndex];
    final direction = step['direction'] ?? 'N';
    
    return _directionToHeading(direction);
  }

  /// Calculate distance to next waypoint
  double _calculateDistanceToNext() {
    if (_currentStepIndex >= _routeSteps.length) return 0;
    
    final step = _routeSteps[_currentStepIndex];
    final distance = step['distance'] ?? 0;
    
    // Subtract steps already taken
    final remaining = (distance as num).toDouble() - _stepCount;
    return remaining.clamp(0, double.infinity);
  }

  /// Calculate overall progress
  double _calculateProgress() {
    if (_routeSteps.isEmpty) return 0;
    return (_currentStepIndex + 1) / _routeSteps.length;
  }

  /// Get route step by index
  Map<String, dynamic>? _getRouteStep(int index) {
    if (index >= _routeSteps.length || index < 0) return null;
    
    final step = _routeSteps[index];
    if (step is Map) {
      return Map<String, dynamic>.from(step);
    }
    
    // If it's a RouteStep object, convert to map
    return {
      'id': step.id,
      'name': step.name,
      'nodeType': step.nodeType,
      'instruction': step.instruction,
      'floorNumber': step.floorNumber,
      'distance': step.distance,
      'imageUrl': step.imageUrl,
      'direction': step.direction,
    };
  }

  /// Convert direction string to heading (degrees)
  double _directionToHeading(String direction) {
    switch (direction.toUpperCase()) {
      case 'N': return 0;
      case 'NE': return 45;
      case 'E': return 90;
      case 'SE': return 135;
      case 'S': return 180;
      case 'SW': return 225;
      case 'W': return 270;
      case 'NW': return 315;
      default: return 0;
    }
  }

  /// Calculate difference between two headings
  double _calculateHeadingDifference(double current, double target) {
    double diff = target - current;
    while (diff > 180) diff -= 360;
    while (diff < -180) diff += 360;
    return diff;
  }

  /// Get alignment hint text
  String _getAlignmentHint(double difference) {
    final absDiff = difference.abs();
    
    if (absDiff < 5) return 'Perfect alignment';
    if (absDiff < 15) return 'Almost aligned';
    if (difference > 0) return 'Turn right ${difference.toStringAsFixed(0)}°';
    return 'Turn left ${difference.abs().toStringAsFixed(0)}°';
  }

  /// Check milestone progress and emit milestone reached if appropriate
  Future<void> _checkMilestoneProgress(
    Emitter<ARGuidanceState> emit,
    ARGuidanceReady currentState,
  ) async {
    if (_currentStepIndex >= _routeSteps.length) return;

    final step = _getRouteStep(_currentStepIndex);
    final stepsNeeded = (step?['distance'] ?? 20).toInt();

    // Check if enough steps taken to advance
    if (_stepCount >= stepsNeeded && !_hasAnnouncedStep) {
      _hasAnnouncedStep = true;

      final stepName = step?['name'] ?? 'Milestone';
      
      // Announce milestone
      if (_audioEnabled) {
        await _audioService.announceMilestone(stepName);
      }

      // Emit milestone reached
      emit(MilestoneReached(
        milestoneName: stepName,
        milestoneIndex: _currentStepIndex,
        totalMilestones: _routeSteps.length,
      ));

      // Return to ready state
      Future.delayed(const Duration(seconds: 2), () {
        final ready = _buildReadyState(emit);
        emit(ready);
      });
    }
  }

  /// Check and update alignment status
  void _checkAndUpdateAlignment(Emitter<ARGuidanceState> emit, double targetHeading) {
    if (state is! ARGuidanceReady) return;

    final difference = _calculateHeadingDifference(_userHeading, targetHeading);
    final isAligned = difference.abs() < 15;

    final currentState = state as ARGuidanceReady;
    if (currentState.isDirectionAligned != isAligned) {
      emit(currentState.copyWith(isDirectionAligned: isAligned));
    }
  }

  /// Announce navigation completion
  void _announceCompletion(Emitter<ARGuidanceState> emit) {
    final destinationName = (_endNode as dynamic).name ?? 'Destination';
    
    emit(NavigationCompleted(
      destinationName: destinationName,
      totalSteps: _routeSteps.length,
    ));

    // Announce arrival
    _audioService.announceArrival(destinationName);
  }
}
