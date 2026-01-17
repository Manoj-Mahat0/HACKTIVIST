import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'ar_guidance_event.dart';
import 'ar_guidance_state.dart';
import '../services/smart_audio_guidance_service.dart';
import 'dart:math' as math;

/// BLoC for managing AR navigation guidance with smart audio
class ARGuidanceBloc extends Bloc<ARGuidanceEvent, ARGuidanceState> {
  final SmartAudioGuidanceService _smartAudioService;
  DateTime? _navigationStartTime;
  Timer? _proximityCheckTimer;
  Timer? _progressAnnouncementTimer;

  ARGuidanceBloc(this._smartAudioService) : super(const ARGuidanceInitial()) {
    on<InitializeARGuidance>(_onInitialize);
    on<UpdateUserHeading>(_onUpdateHeading);
    on<UpdateUserPosition>(_onUpdatePosition);
    on<MoveToNextMilestone>(_onMoveToNext);
    on<MoveToPreviousMilestone>(_onMoveToPrevious);
    on<ToggleAudioGuidance>(_onToggleAudio);
    on<RequestAudioInstruction>(_onRequestAudio);
    on<UpdateStepCount>(_onUpdateStepCount);
    on<ResetPositionFromQR>(_onResetPosition);
    on<RecalculateRoute>(_onRecalculateRoute);
    on<ToggleRouteVisibility>(_onToggleRouteVisibility);
    on<PauseNavigation>(_onPauseNavigation);
    on<ResumeNavigation>(_onResumeNavigation);
    on<CancelNavigation>(_onCancelNavigation);
  }

  @override
  Future<void> close() {
    _proximityCheckTimer?.cancel();
    _progressAnnouncementTimer?.cancel();
    return super.close();
  }

  Future<void> _onInitialize(
    InitializeARGuidance event,
    Emitter<ARGuidanceState> emit,
  ) async {
    try {
      // Convert route nodes to RouteSteps
      final steps = <RouteStep>[];
      for (int i = 0; i < event.route.length; i++) {
        final node = event.route[i];
        String direction = 'N';
        double distance = 0.0;

        if (i > 0) {
          final prevNode = event.route[i - 1];
          direction = _calculateDirection(
            prevNode['latitude'],
            prevNode['longitude'],
            node['latitude'],
            node['longitude'],
          );
          distance = _calculateDistance(
            prevNode['latitude'],
            prevNode['longitude'],
            node['latitude'],
            node['longitude'],
          );
        }

        steps.add(RouteStep.fromNode(node, direction: direction, distance: distance));
      }

      _navigationStartTime = DateTime.now();

      // Initialize smart audio service with route
      await _smartAudioService.initializeNavigation(
        route: event.route,
        startX: event.startNode['latitude'] ?? 0.0,
        startY: event.startNode['longitude'] ?? 0.0,
        startFloor: event.startNode['floor_number'] ?? 0,
        startHeading: 0.0,
      );

      // Start proximity checking
      _startProximityChecking();
      
      // Start progress announcements
      _startProgressAnnouncements();

      emit(ARGuidanceReady(
        route: steps,
        currentMilestoneIndex: 0,
        userHeading: 0,
        userX: event.startNode['latitude'] ?? 0.0,
        userY: event.startNode['longitude'] ?? 0.0,
        userFloor: event.startNode['floor_number'] ?? 0,
      ));
    } catch (e) {
      emit(ARGuidanceError('Failed to initialize AR guidance: $e'));
    }
  }

  void _onUpdateHeading(
    UpdateUserHeading event,
    Emitter<ARGuidanceState> emit,
  ) {
    if (state is ARGuidanceReady) {
      final currentState = state as ARGuidanceReady;
      final targetHeading = currentState.directionToCurrentMilestone;
      final alignmentStatus = getAlignmentStatus(event.heading, targetHeading);

      emit(currentState.copyWith(
        userHeading: event.heading,
        alignmentStatus: alignmentStatus,
      ));
    }
  }

  void _onUpdatePosition(
    UpdateUserPosition event,
    Emitter<ARGuidanceState> emit,
  ) async {
    if (state is ARGuidanceReady) {
      final currentState = state as ARGuidanceReady;

      // Update smart audio service with new position
      await _smartAudioService.updatePosition(
        x: event.x,
        y: event.y,
        floor: event.floorNumber,
        heading: currentState.userHeading,
      );

      // Check if near current milestone
      final distance = _calculateDistance(
        event.x,
        event.y,
        currentState.currentMilestone.x,
        currentState.currentMilestone.y,
      );

      if (distance < 3.0 && currentState.currentMilestoneIndex < currentState.route.length - 1) {
        // Reached milestone, move to next
        add(const MoveToNextMilestone());
      } else {
        // Check if off-route
        final isOffRoute = _checkIfOffRoute(
          event.x,
          event.y,
          currentState.route,
          currentState.currentMilestoneIndex,
        );

        if (isOffRoute) {
          emit(OffRoute(
            distanceFromRoute: distance,
            previousState: currentState,
          ));
          await _smartAudioService.announceOffRoute();
        } else {
          emit(currentState.copyWith(
            userX: event.x,
            userY: event.y,
            userFloor: event.floorNumber,
          ));
        }
      }
    }
  }

  void _onMoveToNext(
    MoveToNextMilestone event,
    Emitter<ARGuidanceState> emit,
  ) async {
    if (state is ARGuidanceReady) {
      final currentState = state as ARGuidanceReady;
      final nextIndex = currentState.currentMilestoneIndex + 1;

      if (nextIndex >= currentState.route.length) {
        // Reached destination
        final duration = DateTime.now().difference(_navigationStartTime ?? DateTime.now());
        // Smart audio service handles destination announcement

        emit(NavigationCompleted(
          destination: currentState.currentMilestone,
          totalSteps: currentState.stepCount,
          totalDistance: currentState.totalDistance,
          duration: duration,
        ));
      } else {
        // Move to next milestone - smart audio service handles announcements

        emit(MilestoneReached(
          milestone: currentState.currentMilestone,
          nextMilestone: currentState.route[nextIndex],
          milestoneNumber: nextIndex,
          totalMilestones: currentState.route.length,
        ));

        // Return to ready state with updated index
        await Future.delayed(const Duration(seconds: 2));
        emit(currentState.copyWith(currentMilestoneIndex: nextIndex));
      }
    }
  }

  void _onMoveToPrevious(
    MoveToPreviousMilestone event,
    Emitter<ARGuidanceState> emit,
  ) {
    if (state is ARGuidanceReady) {
      final currentState = state as ARGuidanceReady;
      if (currentState.currentMilestoneIndex > 0) {
        emit(currentState.copyWith(
          currentMilestoneIndex: currentState.currentMilestoneIndex - 1,
        ));
      }
    }
  }

  void _onToggleAudio(
    ToggleAudioGuidance event,
    Emitter<ARGuidanceState> emit,
  ) {
    if (state is ARGuidanceReady) {
      final currentState = state as ARGuidanceReady;
      final newValue = !currentState.isAudioEnabled;
      _smartAudioService.setEnabled(newValue);
      emit(currentState.copyWith(isAudioEnabled: newValue));
    }
  }

  void _onRequestAudio(
    RequestAudioInstruction event,
    Emitter<ARGuidanceState> emit,
  ) async {
    if (state is ARGuidanceReady) {
      final currentState = state as ARGuidanceReady;
      final instruction = _smartAudioService.currentInstruction ?? currentState.currentInstruction;

      emit(AudioInstructionPlaying(
        instruction: instruction,
        previousState: currentState,
      ));

      // Return to ready state
      await Future.delayed(const Duration(milliseconds: 500));
      emit(currentState);
    }
  }

  void _onUpdateStepCount(
    UpdateStepCount event,
    Emitter<ARGuidanceState> emit,
  ) {
    if (state is ARGuidanceReady) {
      final currentState = state as ARGuidanceReady;
      emit(currentState.copyWith(stepCount: event.steps));
    }
  }

  void _onResetPositionFromQR(
    ResetPositionFromQR event,
    Emitter<ARGuidanceState> emit,
  ) async {
    if (state is ARGuidanceReady) {
      final currentState = state as ARGuidanceReady;

      // Smart audio service will announce QR scan via its own logic

      emit(currentState.copyWith(
        userX: event.node['latitude'] ?? currentState.userX,
        userY: event.node['longitude'] ?? currentState.userY,
        userFloor: event.node['floor_number'] ?? currentState.userFloor,
      ));
    }
  }

  void _onRecalculateRoute(
    RecalculateRoute event,
    Emitter<ARGuidanceState> emit,
  ) async {
    emit(const RecalculatingRoute('User went off route'));
    await _smartAudioService.announceRouteRecalculated();

    // In a real implementation, this would call the API to get a new route
    // For now, we'll just return to the previous state
    if (state is OffRoute) {
      final offRouteState = state as OffRoute;
      emit(offRouteState.previousState);
    }
  }

  void _onToggleRouteVisibility(
    ToggleRouteVisibility event,
    Emitter<ARGuidanceState> emit,
  ) {
    if (state is ARGuidanceReady) {
      final currentState = state as ARGuidanceReady;
      emit(currentState.copyWith(isRouteVisible: !currentState.isRouteVisible));
    }
  }

  void _onPauseNavigation(
    PauseNavigation event,
    Emitter<ARGuidanceState> emit,
  ) async {
    if (state is ARGuidanceReady) {
      final currentState = state as ARGuidanceReady;
      await _smartAudioService.stop();
      emit(currentState.copyWith(isPaused: true));
    }
  }

  void _onResumeNavigation(
    ResumeNavigation event,
    Emitter<ARGuidanceState> emit,
  ) async {
    if (state is ARGuidanceReady) {
      final currentState = state as ARGuidanceReady;
      // Resume will be handled by position updates
      emit(currentState.copyWith(isPaused: false));
    }
  }

  void _onCancelNavigation(
    CancelNavigation event,
    Emitter<ARGuidanceState> emit,
  ) async {
    _proximityCheckTimer?.cancel();
    _progressAnnouncementTimer?.cancel();
    await _smartAudioService.dispose();
    emit(const ARGuidanceInitial());
  }

  // Helper methods

  void _startProximityChecking() {
    _proximityCheckTimer?.cancel();
    _proximityCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (state is ARGuidanceReady) {
        // Smart audio service handles proximity-based announcements
        // via updatePosition calls
      }
    });
  }

  void _startProgressAnnouncements() {
    _progressAnnouncementTimer?.cancel();
    _progressAnnouncementTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (state is ARGuidanceReady) {
        await _smartAudioService.announceMilestoneProgress();
      }
    });
  }

  String _calculateDirection(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final angle = math.atan2(dy, dx) * 180 / math.pi;
    final normalizedAngle = (angle + 360) % 360;

    if (normalizedAngle >= 337.5 || normalizedAngle < 22.5) return 'E';
    if (normalizedAngle >= 22.5 && normalizedAngle < 67.5) return 'NE';
    if (normalizedAngle >= 67.5 && normalizedAngle < 112.5) return 'N';
    if (normalizedAngle >= 112.5 && normalizedAngle < 157.5) return 'NW';
    if (normalizedAngle >= 157.5 && normalizedAngle < 202.5) return 'W';
    if (normalizedAngle >= 202.5 && normalizedAngle < 247.5) return 'SW';
    if (normalizedAngle >= 247.5 && normalizedAngle < 292.5) return 'S';
    return 'SE';
  }

  double _calculateDistance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }

  bool _checkIfOffRoute(
    double userX,
    double userY,
    List<RouteStep> route,
    int currentIndex,
  ) {
    if (currentIndex >= route.length - 1) return false;

    final current = route[currentIndex];
    final next = route[currentIndex + 1];

    // Calculate perpendicular distance from user to route segment
    final distance = _perpendicularDistance(
      userX,
      userY,
      current.x,
      current.y,
      next.x,
      next.y,
    );

    // Consider off-route if more than 10 meters away
    return distance > 10.0;
  }

  double _perpendicularDistance(
    double px,
    double py,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final lengthSquared = dx * dx + dy * dy;

    if (lengthSquared == 0) {
      return _calculateDistance(px, py, x1, y1);
    }

    final t = math.max(0, math.min(1, ((px - x1) * dx + (py - y1) * dy) / lengthSquared));
    final projectionX = x1 + t * dx;
    final projectionY = y1 + t * dy;

    return _calculateDistance(px, py, projectionX, projectionY);
  }
}
