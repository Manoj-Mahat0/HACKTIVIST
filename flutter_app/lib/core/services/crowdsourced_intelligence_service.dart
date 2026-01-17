import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:indoor_navigation/core/network/api_client.dart';

/// Crowdsourced Intelligence Service
/// Silently collects and reports navigation data in background
/// Users don't see this - it happens automatically
class CrowdsourcedIntelligenceService {
  final ApiClient _apiClient;
  
  // Track current navigation session
  String? _currentBuildingId;
  String? _lastNodeId;
  DateTime? _lastNodeTime;
  int _stepsSinceLastNode = 0;
  
  // Queue for batch reporting
  final List<Map<String, dynamic>> _reportQueue = [];
  Timer? _batchTimer;
  
  // Live conditions cache
  Map<String, dynamic>? _liveConditionsCache;
  DateTime? _liveConditionsCacheTime;
  static const _cacheValiditySeconds = 30;

  CrowdsourcedIntelligenceService(this._apiClient) {
    // Start batch reporting timer
    _batchTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _flushReportQueue(),
    );
  }

  void dispose() {
    _batchTimer?.cancel();
    _flushReportQueue();
  }

  /// Start tracking a navigation session
  void startNavigationSession(String buildingId, String startNodeId) {
    _currentBuildingId = buildingId;
    _lastNodeId = startNodeId;
    _lastNodeTime = DateTime.now();
    _stepsSinceLastNode = 0;
    debugPrint('🔍 [CrowdIntel] Started tracking session in building $buildingId');
  }

  /// Report arrival at a node (called silently when user reaches a waypoint)
  void reportNodeArrival({
    required String nodeId,
    required int expectedSteps,
    required int actualSteps,
    required String direction,
  }) {
    if (_currentBuildingId == null || _lastNodeId == null) return;
    
    final travelTime = _lastNodeTime != null 
        ? DateTime.now().difference(_lastNodeTime!).inSeconds 
        : 0;
    
    // Queue the travel report
    _reportQueue.add({
      'type': 'travel',
      'building_id': _currentBuildingId,
      'from_node_id': _lastNodeId,
      'to_node_id': nodeId,
      'actual_steps': actualSteps,
      'expected_steps': expectedSteps,
      'travel_time_seconds': travelTime,
      'direction': direction,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Update tracking state
    _lastNodeId = nodeId;
    _lastNodeTime = DateTime.now();
    _stepsSinceLastNode = 0;
    
    debugPrint('🔍 [CrowdIntel] Queued travel report: $_lastNodeId -> $nodeId');
  }

  /// Report landmark observation (called when user views a landmark image)
  void reportLandmarkObservation({
    required String nodeId,
    String? capturedImagePath,
    bool landmarkVisible = true,
    String? notes,
  }) {
    if (_currentBuildingId == null) return;
    
    String? imageHash;
    if (capturedImagePath != null) {
      // Generate simple hash of image path (in production, hash actual image bytes)
      imageHash = md5.convert(utf8.encode(capturedImagePath)).toString();
    }
    
    _reportQueue.add({
      'type': 'landmark',
      'building_id': _currentBuildingId,
      'node_id': nodeId,
      'image_hash': imageHash,
      'landmark_visible': landmarkVisible,
      'notes': notes,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    debugPrint('🔍 [CrowdIntel] Queued landmark report for node $nodeId');
  }

  /// Report a blocked path (user can trigger this or auto-detect)
  Future<void> reportBlockedPath({
    required String fromNodeId,
    required String toNodeId,
    String reason = 'blocked',
  }) async {
    if (_currentBuildingId == null) return;
    
    try {
      await _apiClient.dio.post(
        '/indoor/blocked-path-report',
        data: {
          'building_id': _currentBuildingId,
          'from_node_id': fromNodeId,
          'to_node_id': toNodeId,
          'reason': reason,
        },
      );
      debugPrint('🔍 [CrowdIntel] Reported blocked path: $fromNodeId -> $toNodeId');
    } catch (e) {
      debugPrint('🔍 [CrowdIntel] Failed to report blocked path: $e');
    }
  }

  /// Report path is now clear
  Future<void> reportPathCleared({
    required String fromNodeId,
    required String toNodeId,
  }) async {
    if (_currentBuildingId == null) return;
    
    try {
      await _apiClient.dio.post(
        '/indoor/buildings/$_currentBuildingId/clear-blocked-path',
        queryParameters: {
          'from_node': fromNodeId,
          'to_node': toNodeId,
        },
      );
      debugPrint('🔍 [CrowdIntel] Reported path cleared: $fromNodeId -> $toNodeId');
    } catch (e) {
      debugPrint('🔍 [CrowdIntel] Failed to report path cleared: $e');
    }
  }

  /// Get live conditions for current building
  Future<Map<String, dynamic>?> getLiveConditions() async {
    if (_currentBuildingId == null) return null;
    
    // Check cache
    if (_liveConditionsCache != null && _liveConditionsCacheTime != null) {
      final cacheAge = DateTime.now().difference(_liveConditionsCacheTime!).inSeconds;
      if (cacheAge < _cacheValiditySeconds) {
        return _liveConditionsCache;
      }
    }
    
    try {
      final response = await _apiClient.dio.get(
        '/indoor/buildings/$_currentBuildingId/live-conditions',
      );
      _liveConditionsCache = response.data;
      _liveConditionsCacheTime = DateTime.now();
      return _liveConditionsCache;
    } catch (e) {
      debugPrint('🔍 [CrowdIntel] Failed to get live conditions: $e');
      return null;
    }
  }

  /// Check if a specific edge is blocked
  Future<bool> isPathBlocked(String fromNodeId, String toNodeId) async {
    final conditions = await getLiveConditions();
    if (conditions == null) return false;
    
    final conditionsList = conditions['conditions'] as List? ?? [];
    for (final condition in conditionsList) {
      if (condition['from_node'] == fromNodeId && 
          condition['to_node'] == toNodeId &&
          condition['is_blocked'] == true) {
        return true;
      }
    }
    return false;
  }

  /// Get crowd level for a specific edge
  Future<double> getCrowdLevel(String fromNodeId, String toNodeId) async {
    final conditions = await getLiveConditions();
    if (conditions == null) return 0.0;
    
    final conditionsList = conditions['conditions'] as List? ?? [];
    for (final condition in conditionsList) {
      if (condition['from_node'] == fromNodeId && 
          condition['to_node'] == toNodeId) {
        return (condition['crowd_level'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return 0.0;
  }

  /// Update step count (called from pedometer)
  void updateStepCount(int steps) {
    _stepsSinceLastNode = steps;
  }

  /// End navigation session
  void endNavigationSession() {
    _flushReportQueue();
    _currentBuildingId = null;
    _lastNodeId = null;
    _lastNodeTime = null;
    _stepsSinceLastNode = 0;
    debugPrint('🔍 [CrowdIntel] Ended tracking session');
  }

  /// Flush queued reports to server
  Future<void> _flushReportQueue() async {
    if (_reportQueue.isEmpty) return;
    
    final reports = List<Map<String, dynamic>>.from(_reportQueue);
    _reportQueue.clear();
    
    for (final report in reports) {
      try {
        final type = report['type'];
        report.remove('type');
        
        switch (type) {
          case 'travel':
            await _apiClient.dio.post('/indoor/travel-report', data: report);
            break;
          case 'landmark':
            await _apiClient.dio.post('/indoor/landmark-report', data: report);
            break;
        }
      } catch (e) {
        // Silently fail - don't interrupt user experience
        debugPrint('🔍 [CrowdIntel] Failed to send report: $e');
      }
    }
    
    if (reports.isNotEmpty) {
      debugPrint('🔍 [CrowdIntel] Flushed ${reports.length} reports');
    }
  }
}

/// Extension to easily access crowd intelligence from navigation
extension CrowdIntelligenceExtension on Map<String, dynamic> {
  bool get isBlocked => this['is_blocked'] == true;
  double get crowdLevel => (this['crowd_level'] as num?)?.toDouble() ?? 0.0;
  bool get isCrowded => crowdLevel >= 3.0;
  String get crowdWarning {
    if (isBlocked) return '⛔ Path blocked';
    if (crowdLevel >= 4) return '🚶🚶🚶 Very crowded';
    if (crowdLevel >= 3) return '🚶🚶 Crowded';
    if (crowdLevel >= 2) return '🚶 Moderate traffic';
    return '';
  }
}
