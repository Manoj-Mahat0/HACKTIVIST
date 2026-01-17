import 'dart:async';
import 'dart:math' as math;
import 'audio_feedback_service.dart';

/// Smart audio guidance service with AI-powered contextual instructions
class SmartAudioGuidanceService {
  final AudioFeedbackService _audioService;
  
  // Navigation state
  List<Map<String, dynamic>> _route = [];
  int _currentWaypointIndex = 0;
  double _userX = 0.0;
  double _userY = 0.0;
  double _userHeading = 0.0;
  int _userFloor = 0;
  
  // Instruction state
  String? _lastInstruction;
  DateTime? _lastInstructionTime;
  Map<String, dynamic>? _nextLandmark;
  double _distanceToNextWaypoint = 0.0;
  
  // Configuration
  static const double _instructionCooldown = 5.0; // seconds
  static const double _proximityThreshold = 15.0; // meters for "approaching" announcements
  static const double _turnAnnouncementDistance = 10.0; // meters before turn
  static const double _waypointReachedThreshold = 3.0; // meters
  
  // Instruction history to avoid repetition
  final List<String> _recentInstructions = [];
  static const int _maxInstructionHistory = 5;
  
  // Distance thresholds for announcements
  final Map<double, bool> _distanceAnnouncementsMade = {};
  
  SmartAudioGuidanceService(this._audioService);
  
  /// Initialize navigation with route
  Future<void> initializeNavigation({
    required List<Map<String, dynamic>> route,
    required double startX,
    required double startY,
    required int startFloor,
    required double startHeading,
  }) async {
    _route = route;
    _currentWaypointIndex = 0;
    _userX = startX;
    _userY = startY;
    _userFloor = startFloor;
    _userHeading = startHeading;
    _lastInstruction = null;
    _lastInstructionTime = null;
    _recentInstructions.clear();
    _distanceAnnouncementsMade.clear();
    
    await _audioService.initialize();
    
    // Initial announcement
    if (_route.isNotEmpty) {
      final destination = _route.last;
      await _announceNavigationStart(destination['label'] ?? 'destination');
    }
  }
  
  /// Update user position and provide guidance
  Future<void> updatePosition({
    required double x,
    required double y,
    required int floor,
    required double heading,
  }) async {
    _userX = x;
    _userY = y;
    _userFloor = floor;
    _userHeading = heading;
    
    if (_route.isEmpty || _currentWaypointIndex >= _route.length) return;
    
    // Calculate distance to next waypoint
    final nextWaypoint = _route[_currentWaypointIndex];
    _distanceToNextWaypoint = _calculateDistance(
      _userX,
      _userY,
      nextWaypoint['latitude'],
      nextWaypoint['longitude'],
    );
    
    // Check if waypoint reached
    if (_distanceToNextWaypoint < _waypointReachedThreshold) {
      await _handleWaypointReached();
      return;
    }
    
    // Provide contextual guidance
    await _provideContextualGuidance();
  }
  
  /// Handle waypoint reached
  Future<void> _handleWaypointReached() async {
    final reachedWaypoint = _route[_currentWaypointIndex];
    
    // Announce waypoint reached
    await _announceWaypointReached(reachedWaypoint);
    
    // Move to next waypoint
    _currentWaypointIndex++;
    _distanceAnnouncementsMade.clear();
    
    // Check if destination reached
    if (_currentWaypointIndex >= _route.length) {
      await _announceDestinationReached(reachedWaypoint);
      return;
    }
    
    // Announce next waypoint
    final nextWaypoint = _route[_currentWaypointIndex];
    await _announceNextWaypoint(nextWaypoint);
  }
  
  /// Provide contextual guidance based on position and route
  Future<void> _provideContextualGuidance() async {
    if (!_canAnnounce()) return;
    
    final nextWaypoint = _route[_currentWaypointIndex];
    final nodeType = nextWaypoint['node_type'] ?? 'waypoint';
    
    // Check for landmarks approaching
    if (_distanceToNextWaypoint < _proximityThreshold) {
      await _announceLandmarkApproaching(nextWaypoint, _distanceToNextWaypoint);
    }
    
    // Check for turn instructions
    if (_currentWaypointIndex < _route.length - 1) {
      final currentWaypoint = _currentWaypointIndex > 0 
          ? _route[_currentWaypointIndex - 1] 
          : null;
      
      if (_distanceToNextWaypoint < _turnAnnouncementDistance) {
        await _announceTurnInstruction(currentWaypoint, nextWaypoint);
      }
    }
    
    // Distance-based announcements
    await _announceDistanceBasedInstructions(_distanceToNextWaypoint, nextWaypoint);
    
    // Check for wrong direction
    await _checkDirectionAlignment(nextWaypoint);
  }
  
  /// Announce landmark approaching
  Future<void> _announceLandmarkApproaching(
    Map<String, dynamic> waypoint,
    double distance,
  ) async {
    final nodeType = waypoint['node_type'] ?? 'waypoint';
    final label = waypoint['label'] ?? 'location';
    
    String instruction = '';
    
    switch (nodeType.toLowerCase()) {
      case 'stairs':
        final nextFloor = waypoint['floor_number'] ?? _userFloor;
        if (nextFloor > _userFloor) {
          instruction = 'Approaching stairs. Take stairs up to floor $nextFloor';
        } else if (nextFloor < _userFloor) {
          instruction = 'Approaching stairs. Take stairs down to floor $nextFloor';
        } else {
          instruction = 'Approaching stairs';
        }
        break;
        
      case 'elevator':
        final nextFloor = waypoint['floor_number'] ?? _userFloor;
        if (nextFloor > _userFloor) {
          instruction = 'Approaching elevator. Take elevator up to floor $nextFloor';
        } else if (nextFloor < _userFloor) {
          instruction = 'Approaching elevator. Take elevator down to floor $nextFloor';
        } else {
          instruction = 'Approaching elevator';
        }
        break;
        
      case 'entrance':
        instruction = 'Approaching entrance to $label';
        break;
        
      case 'exit':
        instruction = 'Approaching exit';
        break;
        
      case 'junction':
        instruction = 'Approaching junction';
        break;
        
      default:
        if (label.toLowerCase().contains('restroom') || 
            label.toLowerCase().contains('bathroom') ||
            label.toLowerCase().contains('toilet')) {
          instruction = 'Approaching restroom';
        } else if (label.toLowerCase().contains('conference') ||
                   label.toLowerCase().contains('meeting')) {
          instruction = 'Approaching conference room';
        } else if (label.toLowerCase().contains('office')) {
          instruction = 'Approaching $label';
        } else {
          instruction = 'Approaching $label in ${distance.toStringAsFixed(0)} meters';
        }
    }
    
    if (instruction.isNotEmpty && !_wasRecentlyAnnounced(instruction)) {
      await _speak(instruction);
    }
  }
  
  /// Announce turn instruction
  Future<void> _announceTurnInstruction(
    Map<String, dynamic>? currentWaypoint,
    Map<String, dynamic> nextWaypoint,
  ) async {
    if (currentWaypoint == null) return;
    
    final currentX = currentWaypoint['latitude'];
    final currentY = currentWaypoint['longitude'];
    final nextX = nextWaypoint['latitude'];
    final nextY = nextWaypoint['longitude'];
    
    // Calculate bearing from current to next
    final targetBearing = _calculateBearing(currentX, currentY, nextX, nextY);
    
    // Calculate turn angle
    final turnAngle = _normalizeBearing(targetBearing - _userHeading);
    
    String direction = _getTurnDirection(turnAngle);
    String instruction = '';
    
    final distance = _distanceToNextWaypoint;
    final distanceText = distance < 5 
        ? 'now' 
        : 'in ${distance.toStringAsFixed(0)} meters';
    
    switch (direction) {
      case 'straight':
        instruction = 'Continue straight ahead';
        break;
      case 'slight_right':
        instruction = 'Turn slightly right $distanceText';
        break;
      case 'right':
        instruction = 'Turn right $distanceText';
        break;
      case 'sharp_right':
        instruction = 'Make a sharp right turn $distanceText';
        break;
      case 'u_turn':
        instruction = 'Make a U-turn $distanceText';
        break;
      case 'sharp_left':
        instruction = 'Make a sharp left turn $distanceText';
        break;
      case 'left':
        instruction = 'Turn left $distanceText';
        break;
      case 'slight_left':
        instruction = 'Turn slightly left $distanceText';
        break;
    }
    
    if (instruction.isNotEmpty && !_wasRecentlyAnnounced(instruction)) {
      await _speak(instruction);
    }
  }
  
  /// Announce distance-based instructions
  Future<void> _announceDistanceBasedInstructions(
    double distance,
    Map<String, dynamic> waypoint,
  ) async {
    final label = waypoint['label'] ?? 'waypoint';
    final nodeType = waypoint['node_type'] ?? 'waypoint';
    
    // Announce at specific distances
    final thresholds = [20.0, 10.0, 5.0];
    
    for (final threshold in thresholds) {
      if (distance <= threshold && 
          distance > threshold - 2 && 
          !(_distanceAnnouncementsMade[threshold] ?? false)) {
        
        String instruction = '';
        
        if (nodeType == 'stairs' || nodeType == 'elevator') {
          instruction = '$nodeType approaching in ${threshold.toInt()} meters';
        } else if (_currentWaypointIndex == _route.length - 1) {
          instruction = 'Destination on your left in ${threshold.toInt()} meters';
        } else {
          instruction = '$label in ${threshold.toInt()} meters';
        }
        
        await _speak(instruction);
        _distanceAnnouncementsMade[threshold] = true;
        break;
      }
    }
  }
  
  /// Check if user is heading in wrong direction
  Future<void> _checkDirectionAlignment(Map<String, dynamic> nextWaypoint) async {
    final targetBearing = _calculateBearing(
      _userX,
      _userY,
      nextWaypoint['latitude'],
      nextWaypoint['longitude'],
    );
    
    final bearingDiff = (_userHeading - targetBearing).abs();
    final normalizedDiff = bearingDiff > 180 ? 360 - bearingDiff : bearingDiff;
    
    // If user is facing opposite direction (>135 degrees off)
    if (normalizedDiff > 135 && !_wasRecentlyAnnounced('turn around')) {
      await _speak('You are heading in the wrong direction. Please turn around');
    }
    // If user is significantly off course (>90 degrees)
    else if (normalizedDiff > 90 && !_wasRecentlyAnnounced('wrong turn')) {
      await _speak('You have taken a wrong turn. Recalculating route');
    }
  }
  
  /// Announce navigation start
  Future<void> _announceNavigationStart(String destination) async {
    await _speak('Starting navigation to $destination');
  }
  
  /// Announce waypoint reached
  Future<void> _announceWaypointReached(Map<String, dynamic> waypoint) async {
    final label = waypoint['label'] ?? 'waypoint';
    final nodeType = waypoint['node_type'] ?? 'waypoint';
    
    String instruction = '';
    
    if (nodeType == 'stairs' || nodeType == 'elevator') {
      instruction = 'You have reached the $nodeType';
    } else {
      instruction = 'Waypoint reached: $label';
    }
    
    await _speak(instruction);
  }
  
  /// Announce next waypoint
  Future<void> _announceNextWaypoint(Map<String, dynamic> waypoint) async {
    final label = waypoint['label'] ?? 'waypoint';
    final distance = _calculateDistance(
      _userX,
      _userY,
      waypoint['latitude'],
      waypoint['longitude'],
    );
    
    // Calculate progress
    final progress = (_currentWaypointIndex / _route.length * 100).toInt();
    
    String instruction = 'Next milestone: $label, ${distance.toStringAsFixed(0)} meters ahead';
    
    // Add progress if halfway or more
    if (progress >= 50) {
      instruction += '. You are $progress percent to your destination';
    }
    
    await _speak(instruction);
  }
  
  /// Announce destination reached
  Future<void> _announceDestinationReached(Map<String, dynamic> destination) async {
    final label = destination['label'] ?? 'destination';
    await _speak('You have reached your destination: $label');
  }
  
  /// Announce off-route
  Future<void> announceOffRoute() async {
    await _speak('You are off course. Recalculating route from your current location');
  }
  
  /// Announce route recalculated
  Future<void> announceRouteRecalculated() async {
    await _speak('New route calculated. Follow the updated directions');
  }
  
  /// Announce milestone progress
  Future<void> announceMilestoneProgress() async {
    if (_route.isEmpty) return;
    
    final progress = (_currentWaypointIndex / _route.length * 100).toInt();
    final remaining = _route.length - _currentWaypointIndex;
    
    String instruction = '';
    
    if (progress == 50) {
      instruction = 'You are halfway to your destination. $remaining waypoints remaining';
    } else if (progress == 75) {
      instruction = 'You are three quarters to your destination. $remaining waypoints remaining';
    } else if (progress == 25) {
      instruction = 'You are one quarter to your destination. $remaining waypoints remaining';
    }
    
    if (instruction.isNotEmpty) {
      await _speak(instruction);
    }
  }
  
  /// Get turn direction from angle
  String _getTurnDirection(double angle) {
    final absAngle = angle.abs();
    
    if (absAngle < 15) {
      return 'straight';
    } else if (absAngle < 45) {
      return angle > 0 ? 'slight_right' : 'slight_left';
    } else if (absAngle < 135) {
      return angle > 0 ? 'right' : 'left';
    } else if (absAngle < 160) {
      return angle > 0 ? 'sharp_right' : 'sharp_left';
    } else {
      return 'u_turn';
    }
  }
  
  /// Calculate bearing between two points
  double _calculateBearing(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final angle = math.atan2(dy, dx) * 180 / math.pi;
    return _normalizeBearing(angle);
  }
  
  /// Normalize bearing to 0-360
  double _normalizeBearing(double bearing) {
    return (bearing + 360) % 360;
  }
  
  /// Calculate distance between two points
  double _calculateDistance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }
  
  /// Check if can announce (cooldown period)
  bool _canAnnounce() {
    if (_lastInstructionTime == null) return true;
    
    final elapsed = DateTime.now().difference(_lastInstructionTime!).inSeconds;
    return elapsed >= _instructionCooldown;
  }
  
  /// Check if instruction was recently announced
  bool _wasRecentlyAnnounced(String instruction) {
    // Normalize instruction for comparison
    final normalized = instruction.toLowerCase().trim();
    
    for (final recent in _recentInstructions) {
      if (recent.toLowerCase().contains(normalized) ||
          normalized.contains(recent.toLowerCase())) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Speak instruction and track it
  Future<void> _speak(String instruction) async {
    await _audioService.speak(instruction);
    
    _lastInstruction = instruction;
    _lastInstructionTime = DateTime.now();
    
    _recentInstructions.add(instruction);
    if (_recentInstructions.length > _maxInstructionHistory) {
      _recentInstructions.removeAt(0);
    }
  }
  
  /// Enable/disable audio
  void setEnabled(bool enabled) {
    _audioService.setEnabled(enabled);
  }
  
  /// Check if audio is enabled
  bool get isEnabled => _audioService.isEnabled;
  
  /// Check if currently speaking
  bool get isSpeaking => _audioService.isSpeaking;
  
  /// Get current instruction
  String? get currentInstruction => _lastInstruction;
  
  /// Stop current speech
  Future<void> stop() async {
    await _audioService.stop();
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await _audioService.dispose();
    _recentInstructions.clear();
    _distanceAnnouncementsMade.clear();
  }
}
