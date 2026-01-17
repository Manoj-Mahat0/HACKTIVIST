import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

enum ConnectivityStatus {
  online,
  offline,
  limited, // Connected but no internet access
}

class ConnectivityService {
  static const Duration _checkInterval = Duration(seconds: 30);
  static const Duration _requestTimeout = Duration(seconds: 5);
  
  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectivityStatus> _statusController = 
      StreamController<ConnectivityStatus>.broadcast();
  
  ConnectivityStatus _currentStatus = ConnectivityStatus.offline;
  Timer? _periodicCheck;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  Stream<ConnectivityStatus> get statusStream => _statusController.stream;
  ConnectivityStatus get currentStatus => _currentStatus;
  bool get isOnline => _currentStatus == ConnectivityStatus.online;
  bool get isOffline => _currentStatus == ConnectivityStatus.offline;

  Future<void> initialize() async {
    // Initial check
    await _checkConnectivity();
    
    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) async {
        await _checkConnectivity();
      },
    );
    
    // Periodic connectivity check
    _periodicCheck = Timer.periodic(_checkInterval, (_) async {
      await _checkConnectivity();
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        _updateStatus(ConnectivityStatus.offline);
        return;
      }
      
      // Check if we have actual internet access
      final hasInternet = await _hasInternetAccess();
      
      if (hasInternet) {
        _updateStatus(ConnectivityStatus.online);
      } else {
        _updateStatus(ConnectivityStatus.limited);
      }
    } catch (e) {
      print('Connectivity check failed: $e');
      _updateStatus(ConnectivityStatus.offline);
    }
  }

  Future<bool> _hasInternetAccess() async {
    try {
      // Try multiple reliable endpoints
      final endpoints = [
        'https://www.google.com',
        'https://www.cloudflare.com',
        'https://httpbin.org/status/200',
      ];
      
      for (final endpoint in endpoints) {
        try {
          final response = await http.head(
            Uri.parse(endpoint),
          ).timeout(_requestTimeout);
          
          if (response.statusCode == 200) {
            return true;
          }
        } catch (e) {
          continue; // Try next endpoint
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  void _updateStatus(ConnectivityStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
      print('Connectivity status changed: ${status.name}');
    }
  }

  /// Force a connectivity check
  Future<ConnectivityStatus> checkNow() async {
    await _checkConnectivity();
    return _currentStatus;
  }

  /// Check if a specific host is reachable
  Future<bool> canReachHost(String host, {int port = 80}) async {
    try {
      final result = await InternetAddress.lookup(host);
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        final socket = await Socket.connect(host, port, timeout: _requestTimeout);
        socket.destroy();
        return true;
      }
    } catch (e) {
      print('Host $host unreachable: $e');
    }
    return false;
  }

  /// Get detailed connectivity info
  Future<Map<String, dynamic>> getConnectivityInfo() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    final hasInternet = await _hasInternetAccess();
    
    return {
      'type': connectivityResult.name,
      'status': _currentStatus.name,
      'hasInternet': hasInternet,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  void dispose() {
    _periodicCheck?.cancel();
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}