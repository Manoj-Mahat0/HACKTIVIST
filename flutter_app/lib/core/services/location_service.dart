import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../network/api_client.dart';

class LocationAddress {
  final String address;
  final String city;
  final String country;
  final String source; // 'backend', 'weather', 'geocoding', 'cache'
  final DateTime fetchedAt;

  LocationAddress({
    required this.address,
    required this.city,
    required this.country,
    required this.source,
    required this.fetchedAt,
  });

  factory LocationAddress.fromWeatherApi(Map<String, dynamic> data) {
    final city = data['name'] ?? '';
    final country = data['sys']?['country'] ?? '';
    return LocationAddress(
      address: city.isNotEmpty 
          ? '$city${country.isNotEmpty ? ", $country" : ""}'
          : 'Unknown location',
      city: city,
      country: country,
      source: 'weather',
      fetchedAt: DateTime.now(),
    );
  }

  factory LocationAddress.fromGeocodingApi(Map<String, dynamic> data) {
    final results = data['results'] as List?;
    if (results != null && results.isNotEmpty) {
      final result = results.first;
      final address = result['formatted_address'] ?? 'Unknown location';
      
      String city = '';
      String country = '';
      
      final components = result['address_components'] as List?;
      if (components != null) {
        for (final component in components) {
          final types = List<String>.from(component['types'] ?? []);
          if (types.contains('locality')) {
            city = component['long_name'] ?? '';
          }
          if (types.contains('country')) {
            country = component['short_name'] ?? '';
          }
        }
      }
      
      return LocationAddress(
        address: address,
        city: city,
        country: country,
        source: 'geocoding',
        fetchedAt: DateTime.now(),
      );
    }
    
    return LocationAddress(
      address: 'Unknown location',
      city: '',
      country: '',
      source: 'geocoding',
      fetchedAt: DateTime.now(),
    );
  }

  factory LocationAddress.fromCache(Map<String, dynamic> data) {
    return LocationAddress(
      address: data['address'] ?? 'Unknown location',
      city: data['city'] ?? '',
      country: data['country'] ?? '',
      source: data['source'] ?? 'cache',
      fetchedAt: DateTime.parse(data['fetchedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'city': city,
      'country': country,
      'source': source,
      'fetchedAt': fetchedAt.toIso8601String(),
    };
  }

  bool get isExpired {
    final now = DateTime.now();
    final difference = now.difference(fetchedAt);
    return difference.inDays > 7; // Cache expires after 7 days
  }
}

class LocationService {
  static const String _openWeatherApiKey = 'b85432bbf800736d6ce856b0a41b1ebc';
  static const String _googleGeocodingApiKey = 'AIzaSyAOVYRIgupAurZup5y1PRh8Ismb1A3lLao';
  static const String _cachePrefix = 'location_cache_';
  static const Duration _requestTimeout = Duration(seconds: 8);
  
  final ApiClient? _apiClient;
  final SharedPreferences _prefs;
  final Connectivity _connectivity = Connectivity();

  LocationService(this._apiClient, this._prefs);

  /// Get address with intelligent fallback strategy
  Future<LocationAddress> getAddress(double latitude, double longitude) async {
    final cacheKey = _getCacheKey(latitude, longitude);
    
    // Check cache first
    final cachedAddress = await _getCachedAddress(cacheKey);
    if (cachedAddress != null && !cachedAddress.isExpired) {
      return cachedAddress;
    }

    // Check connectivity
    final isConnected = await _isConnected();
    if (!isConnected) {
      return cachedAddress ?? _getOfflineAddress();
    }

    // Try multiple sources with fallback
    LocationAddress? address;
    
    // 1. Try backend first (if available)
    if (_apiClient != null) {
      address = await _tryBackendGeocoding(latitude, longitude);
    }
    
    // 2. Fallback to Google Geocoding API
    address ??= await _tryGoogleGeocoding(latitude, longitude);
    
    // 3. Fallback to OpenWeatherMap API
    address ??= await _tryWeatherApi(latitude, longitude);
    
    // 4. Use cached address if available
    if (address == null && cachedAddress != null) {
      return cachedAddress;
    }
    
    // 5. Return offline address as last resort
    final finalAddress = address ?? _getOfflineAddress();
    
    // Cache the result if it's not offline
    if (finalAddress.source != 'offline') {
      await _cacheAddress(cacheKey, finalAddress);
    }
    
    return finalAddress;
  }

  /// Try to get address from backend
  Future<LocationAddress?> _tryBackendGeocoding(double lat, double lng) async {
    try {
      final response = await _apiClient!.dio.get(
        '/geocoding/reverse',
        queryParameters: {'lat': lat, 'lng': lng},
        options: Options(sendTimeout: _requestTimeout, receiveTimeout: _requestTimeout),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        return LocationAddress(
          address: data['address'] ?? 'Unknown location',
          city: data['city'] ?? '',
          country: data['country'] ?? '',
          source: 'backend',
          fetchedAt: DateTime.now(),
        );
      }
    } catch (e) {
      print('Backend geocoding failed: $e');
    }
    return null;
  }

  /// Try Google Geocoding API
  Future<LocationAddress?> _tryGoogleGeocoding(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$_googleGeocodingApiKey'
      );
      
      final response = await http.get(url).timeout(_requestTimeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return LocationAddress.fromGeocodingApi(data);
        }
      }
    } catch (e) {
      print('Google Geocoding failed: $e');
    }
    return null;
  }

  /// Try OpenWeatherMap API
  Future<LocationAddress?> _tryWeatherApi(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lng&appid=$_openWeatherApiKey'
      );
      
      final response = await http.get(url).timeout(_requestTimeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return LocationAddress.fromWeatherApi(data);
      }
    } catch (e) {
      print('Weather API failed: $e');
    }
    return null;
  }

  /// Check internet connectivity
  Future<bool> _isConnected() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  /// Get cached address
  Future<LocationAddress?> _getCachedAddress(String cacheKey) async {
    try {
      final cachedData = _prefs.getString(cacheKey);
      if (cachedData != null) {
        final data = json.decode(cachedData);
        return LocationAddress.fromCache(data);
      }
    } catch (e) {
      print('Cache read failed: $e');
    }
    return null;
  }

  /// Cache address
  Future<void> _cacheAddress(String cacheKey, LocationAddress address) async {
    try {
      final data = json.encode(address.toJson());
      await _prefs.setString(cacheKey, data);
    } catch (e) {
      print('Cache write failed: $e');
    }
  }

  /// Generate cache key
  String _getCacheKey(double lat, double lng) {
    final latRounded = (lat * 1000).round() / 1000; // 3 decimal places
    final lngRounded = (lng * 1000).round() / 1000;
    return '$_cachePrefix${latRounded}_$lngRounded';
  }

  /// Get offline address
  LocationAddress _getOfflineAddress() {
    return LocationAddress(
      address: 'Address not available (offline mode)',
      city: '',
      country: '',
      source: 'offline',
      fetchedAt: DateTime.now(),
    );
  }

  /// Clear expired cache entries
  Future<void> clearExpiredCache() async {
    try {
      final keys = _prefs.getKeys().where((key) => key.startsWith(_cachePrefix));
      
      for (final key in keys) {
        final cachedAddress = await _getCachedAddress(key);
        if (cachedAddress != null && cachedAddress.isExpired) {
          await _prefs.remove(key);
        }
      }
    } catch (e) {
      print('Cache cleanup failed: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, int>> getCacheStats() async {
    try {
      final keys = _prefs.getKeys().where((key) => key.startsWith(_cachePrefix));
      int total = 0;
      int expired = 0;
      
      for (final key in keys) {
        total++;
        final cachedAddress = await _getCachedAddress(key);
        if (cachedAddress != null && cachedAddress.isExpired) {
          expired++;
        }
      }
      
      return {
        'total': total,
        'expired': expired,
        'active': total - expired,
      };
    } catch (e) {
      return {'total': 0, 'expired': 0, 'active': 0};
    }
  }
}