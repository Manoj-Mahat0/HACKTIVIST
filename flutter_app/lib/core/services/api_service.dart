import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import '../network/api_client.dart';
import 'connectivity_service.dart';
import 'offline_sync_service.dart';

class ApiResponse<T> {
  final T? data;
  final bool success;
  final String? error;
  final String source; // 'backend', 'cache', 'fallback', 'offline'
  final bool fromCache;

  ApiResponse({
    this.data,
    required this.success,
    this.error,
    required this.source,
    this.fromCache = false,
  });

  factory ApiResponse.success(T data, String source, {bool fromCache = false}) {
    return ApiResponse(
      data: data,
      success: true,
      source: source,
      fromCache: fromCache,
    );
  }

  factory ApiResponse.error(String error, String source) {
    return ApiResponse(
      success: false,
      error: error,
      source: source,
    );
  }

  factory ApiResponse.offline() {
    return ApiResponse(
      success: false,
      error: 'Device is offline',
      source: 'offline',
    );
  }
}

class ApiService {
  final ApiClient _apiClient;
  final ConnectivityService _connectivityService;
  final OfflineSyncService _offlineSyncService;
  
  static const Duration _requestTimeout = Duration(seconds: 10);

  ApiService(
    this._apiClient,
    this._connectivityService,
    this._offlineSyncService,
  );

  /// Make API request with intelligent fallback
  Future<ApiResponse<T>> request<T>({
    required String method,
    required String endpoint,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
    T Function(dynamic)? parser,
    Future<T?> Function()? cacheGetter,
    Future<void> Function(T)? cacheSetter,
    Future<T?> Function()? fallbackProvider,
    bool queueIfOffline = true,
    String? description,
  }) async {
    // Check connectivity first
    if (_connectivityService.isOffline) {
      // Try cache first
      if (cacheGetter != null) {
        try {
          final cachedData = await cacheGetter();
          if (cachedData != null) {
            return ApiResponse.success(cachedData, 'cache', fromCache: true);
          }
        } catch (e) {
          print('Cache read failed: $e');
        }
      }

      // Try fallback provider
      if (fallbackProvider != null) {
        try {
          final fallbackData = await fallbackProvider();
          if (fallbackData != null) {
            return ApiResponse.success(fallbackData, 'fallback');
          }
        } catch (e) {
          print('Fallback provider failed: $e');
        }
      }

      // Queue for later sync if it's a write operation
      if (queueIfOffline && ['POST', 'PUT', 'DELETE'].contains(method.toUpperCase())) {
        await _offlineSyncService.queueRequest(
          method: method,
          endpoint: endpoint,
          data: data,
          headers: headers,
          description: description,
        );
        return ApiResponse.success(null as T, 'queued');
      }

      return ApiResponse.offline();
    }

    // Try main API request
    try {
      final response = await _makeRequest(method, endpoint, data, headers);
      
      T? parsedData;
      if (parser != null && response.data != null) {
        parsedData = parser(response.data);
      } else {
        parsedData = response.data as T?;
      }

      // Cache successful response
      if (cacheSetter != null && parsedData != null) {
        try {
          await cacheSetter(parsedData);
        } catch (e) {
          print('Cache write failed: $e');
        }
      }

      return ApiResponse.success(parsedData as T, 'backend');
      
    } catch (e) {
      print('API request failed: $e');
      
      // Try cache on API failure
      if (cacheGetter != null) {
        try {
          final cachedData = await cacheGetter();
          if (cachedData != null) {
            return ApiResponse.success(cachedData, 'cache', fromCache: true);
          }
        } catch (cacheError) {
          print('Cache read failed: $cacheError');
        }
      }

      // Try fallback provider on API failure
      if (fallbackProvider != null) {
        try {
          final fallbackData = await fallbackProvider();
          if (fallbackData != null) {
            return ApiResponse.success(fallbackData, 'fallback');
          }
        } catch (fallbackError) {
          print('Fallback provider failed: $fallbackError');
        }
      }

      // Queue for later if it's a write operation
      if (queueIfOffline && ['POST', 'PUT', 'DELETE'].contains(method.toUpperCase())) {
        await _offlineSyncService.queueRequest(
          method: method,
          endpoint: endpoint,
          data: data,
          headers: headers,
          description: description,
        );
        return ApiResponse.success(null as T, 'queued');
      }

      return ApiResponse.error(e.toString(), 'backend');
    }
  }

  Future<Response> _makeRequest(
    String method,
    String endpoint,
    Map<String, dynamic>? data,
    Map<String, String>? headers,
  ) async {
    final options = Options(
      method: method.toUpperCase(),
      headers: headers,
      sendTimeout: _requestTimeout,
      receiveTimeout: _requestTimeout,
      followRedirects: true,
      maxRedirects: 5,
    );

    switch (method.toUpperCase()) {
      case 'GET':
        return await _apiClient.dio.get(endpoint, options: options);
      case 'POST':
        return await _apiClient.dio.post(endpoint, data: data, options: options);
      case 'PUT':
        return await _apiClient.dio.put(endpoint, data: data, options: options);
      case 'DELETE':
        return await _apiClient.dio.delete(endpoint, options: options);
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
  }

  /// Make public API request (bypasses backend)
  Future<ApiResponse<T>> publicApiRequest<T>({
    required String url,
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, String>? headers,
    T Function(dynamic)? parser,
    Duration? timeout,
  }) async {
    if (_connectivityService.isOffline) {
      return ApiResponse.offline();
    }

    try {
      final uri = Uri.parse(url);
      http.Response response;
      
      final requestTimeout = timeout ?? _requestTimeout;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(requestTimeout);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: data != null ? json.encode(data) : null,
          ).timeout(requestTimeout);
          break;
        default:
          throw Exception('Unsupported public API method: $method');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(response.body);
        T? parsedData;
        
        if (parser != null) {
          parsedData = parser(responseData);
        } else {
          parsedData = responseData as T?;
        }
        
        return ApiResponse.success(parsedData as T, 'public_api');
      } else {
        return ApiResponse.error(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          'public_api',
        );
      }
    } catch (e) {
      return ApiResponse.error(e.toString(), 'public_api');
    }
  }

  /// Batch request with fallback strategies
  Future<List<ApiResponse<T>>> batchRequest<T>(
    List<Map<String, dynamic>> requests,
  ) async {
    final results = <ApiResponse<T>>[];
    
    for (final requestConfig in requests) {
      final response = await request<T>(
        method: requestConfig['method'] ?? 'GET',
        endpoint: requestConfig['endpoint'],
        data: requestConfig['data'],
        headers: requestConfig['headers'],
        parser: requestConfig['parser'],
        cacheGetter: requestConfig['cacheGetter'],
        cacheSetter: requestConfig['cacheSetter'],
        fallbackProvider: requestConfig['fallbackProvider'],
        queueIfOffline: requestConfig['queueIfOffline'] ?? true,
        description: requestConfig['description'],
      );
      
      results.add(response);
    }
    
    return results;
  }

  /// Check if service is available
  Future<bool> isServiceAvailable() async {
    if (_connectivityService.isOffline) return false;
    
    try {
      final response = await _apiClient.dio.get('/health').timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get service status
  Future<Map<String, dynamic>> getServiceStatus() async {
    return {
      'connectivity': _connectivityService.currentStatus.name,
      'backend_available': await isServiceAvailable(),
      'pending_requests': _offlineSyncService.pendingRequests.length,
      'is_syncing': _offlineSyncService.isSyncing,
    };
  }
}