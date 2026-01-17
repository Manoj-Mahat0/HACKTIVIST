import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import 'connectivity_service.dart';

class PendingRequest {
  final String id;
  final String method;
  final String endpoint;
  final Map<String, dynamic>? data;
  final Map<String, String>? headers;
  final DateTime createdAt;
  final int retryCount;
  final String? description;

  PendingRequest({
    required this.id,
    required this.method,
    required this.endpoint,
    this.data,
    this.headers,
    required this.createdAt,
    this.retryCount = 0,
    this.description,
  });

  factory PendingRequest.fromJson(Map<String, dynamic> json) {
    return PendingRequest(
      id: json['id'],
      method: json['method'],
      endpoint: json['endpoint'],
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
      headers: json['headers'] != null ? Map<String, String>.from(json['headers']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      retryCount: json['retryCount'] ?? 0,
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'method': method,
      'endpoint': endpoint,
      'data': data,
      'headers': headers,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'description': description,
    };
  }

  PendingRequest copyWith({
    String? id,
    String? method,
    String? endpoint,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
    DateTime? createdAt,
    int? retryCount,
    String? description,
  }) {
    return PendingRequest(
      id: id ?? this.id,
      method: method ?? this.method,
      endpoint: endpoint ?? this.endpoint,
      data: data ?? this.data,
      headers: headers ?? this.headers,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      description: description ?? this.description,
    );
  }
}

class OfflineSyncService {
  static const String _pendingRequestsKey = 'pending_requests';
  static const int _maxRetries = 3;
  static const Duration _syncInterval = Duration(minutes: 5);
  
  final StreamController<Map<String, dynamic>> _syncStatusController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  SharedPreferences? _prefs;
  ApiClient? _apiClient;
  ConnectivityService? _connectivityService;
  Timer? _syncTimer;
  StreamSubscription<ConnectivityStatus>? _connectivitySubscription;
  
  bool _isSyncing = false;
  List<PendingRequest> _pendingRequests = [];

  Stream<Map<String, dynamic>> get syncStatusStream => _syncStatusController.stream;
  List<PendingRequest> get pendingRequests => List.unmodifiable(_pendingRequests);
  bool get hasPendingRequests => _pendingRequests.isNotEmpty;
  bool get isSyncing => _isSyncing;

  Future<void> initialize(ApiClient apiClient) async {
    _apiClient = apiClient;
    _prefs = await SharedPreferences.getInstance();
    
    // Load pending requests
    await _loadPendingRequests();
    
    // Start periodic sync
    _startPeriodicSync();
    
    print('OfflineSyncService initialized with ${_pendingRequests.length} pending requests');
  }

  void setConnectivityService(ConnectivityService connectivityService) {
    _connectivityService = connectivityService;
    
    // Listen to connectivity changes
    _connectivitySubscription = connectivityService.statusStream.listen((status) {
      if (status == ConnectivityStatus.online && hasPendingRequests) {
        _triggerSync();
      }
    });
  }

  /// Queue a request for offline sync
  Future<void> queueRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
    String? description,
  }) async {
    final request = PendingRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: method.toUpperCase(),
      endpoint: endpoint,
      data: data,
      headers: headers,
      createdAt: DateTime.now(),
      description: description,
    );

    _pendingRequests.add(request);
    await _savePendingRequests();
    
    _syncStatusController.add({
      'type': 'request_queued',
      'request': request.toJson(),
      'pending_count': _pendingRequests.length,
    });

    print('Request queued: ${request.method} ${request.endpoint}');
    
    // Try immediate sync if online
    if (_connectivityService?.isOnline == true) {
      _triggerSync();
    }
  }

  /// Manually trigger sync
  Future<Map<String, dynamic>> syncNow() async {
    if (_isSyncing) {
      return {
        'success': false,
        'message': 'Sync already in progress',
        'synced': 0,
        'failed': 0,
      };
    }

    if (_connectivityService?.isOffline == true) {
      return {
        'success': false,
        'message': 'No internet connection',
        'synced': 0,
        'failed': 0,
      };
    }

    return await _performSync();
  }

  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      if (_connectivityService?.isOnline == true && hasPendingRequests) {
        _triggerSync();
      }
    });
  }

  void _triggerSync() {
    if (!_isSyncing && hasPendingRequests) {
      Timer(const Duration(seconds: 2), () => _performSync());
    }
  }

  Future<Map<String, dynamic>> _performSync() async {
    if (_isSyncing || _apiClient == null) {
      return {'success': false, 'message': 'Sync not available'};
    }

    _isSyncing = true;
    int syncedCount = 0;
    int failedCount = 0;
    final List<String> errors = [];

    _syncStatusController.add({
      'type': 'sync_started',
      'total_requests': _pendingRequests.length,
    });

    try {
      final requestsToSync = List<PendingRequest>.from(_pendingRequests);
      
      for (final request in requestsToSync) {
        try {
          await _syncRequest(request);
          _pendingRequests.removeWhere((r) => r.id == request.id);
          syncedCount++;
          
          _syncStatusController.add({
            'type': 'request_synced',
            'request': request.toJson(),
            'synced_count': syncedCount,
            'remaining': _pendingRequests.length,
          });
          
        } catch (e) {
          final updatedRequest = request.copyWith(retryCount: request.retryCount + 1);
          
          if (updatedRequest.retryCount >= _maxRetries) {
            _pendingRequests.removeWhere((r) => r.id == request.id);
            failedCount++;
            errors.add('${request.description ?? request.endpoint}: $e');
            
            _syncStatusController.add({
              'type': 'request_failed',
              'request': request.toJson(),
              'error': e.toString(),
            });
          } else {
            // Update retry count
            final index = _pendingRequests.indexWhere((r) => r.id == request.id);
            if (index != -1) {
              _pendingRequests[index] = updatedRequest;
            }
          }
        }
      }
      
      await _savePendingRequests();
      
    } finally {
      _isSyncing = false;
    }

    final result = {
      'success': true,
      'synced': syncedCount,
      'failed': failedCount,
      'remaining': _pendingRequests.length,
      'errors': errors,
    };

    _syncStatusController.add({
      'type': 'sync_completed',
      ...result,
    });

    return result;
  }

  Future<void> _syncRequest(PendingRequest request) async {
    if (_apiClient == null) throw Exception('API client not available');

    switch (request.method) {
      case 'GET':
        await _apiClient!.dio.get(request.endpoint);
        break;
      case 'POST':
        await _apiClient!.dio.post(request.endpoint, data: request.data);
        break;
      case 'PUT':
        await _apiClient!.dio.put(request.endpoint, data: request.data);
        break;
      case 'DELETE':
        await _apiClient!.dio.delete(request.endpoint);
        break;
      default:
        throw Exception('Unsupported HTTP method: ${request.method}');
    }
  }

  Future<void> _loadPendingRequests() async {
    try {
      final requestsJson = _prefs?.getString(_pendingRequestsKey);
      if (requestsJson != null) {
        final List<dynamic> requestsList = json.decode(requestsJson);
        _pendingRequests = requestsList
            .map((json) => PendingRequest.fromJson(json))
            .toList();
      }
    } catch (e) {
      print('Failed to load pending requests: $e');
      _pendingRequests = [];
    }
  }

  Future<void> _savePendingRequests() async {
    try {
      final requestsJson = json.encode(
        _pendingRequests.map((r) => r.toJson()).toList(),
      );
      await _prefs?.setString(_pendingRequestsKey, requestsJson);
    } catch (e) {
      print('Failed to save pending requests: $e');
    }
  }

  /// Clear all pending requests
  Future<void> clearPendingRequests() async {
    _pendingRequests.clear();
    await _savePendingRequests();
    
    _syncStatusController.add({
      'type': 'requests_cleared',
      'pending_count': 0,
    });
  }

  /// Remove specific request
  Future<void> removeRequest(String requestId) async {
    _pendingRequests.removeWhere((r) => r.id == requestId);
    await _savePendingRequests();
    
    _syncStatusController.add({
      'type': 'request_removed',
      'request_id': requestId,
      'pending_count': _pendingRequests.length,
    });
  }

  /// Get sync statistics
  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final oldRequests = _pendingRequests.where((r) => 
      now.difference(r.createdAt).inHours > 24
    ).length;
    
    final retryRequests = _pendingRequests.where((r) => r.retryCount > 0).length;
    
    return {
      'total_pending': _pendingRequests.length,
      'old_requests': oldRequests,
      'retry_requests': retryRequests,
      'is_syncing': _isSyncing,
      'connectivity': _connectivityService?.currentStatus.name ?? 'unknown',
    };
  }

  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
  }
}