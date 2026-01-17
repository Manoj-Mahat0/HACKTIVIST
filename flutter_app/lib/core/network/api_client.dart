import 'package:dio/dio.dart';
import 'package:indoor_navigation/core/storage/token_storage.dart';
import 'package:indoor_navigation/core/di/injection_container.dart';

class ApiClient {
  static const String baseUrl = 'https://be.google.knocknockindia.com'; // Production backend
  
  final Dio _dio;
  late final TokenStorage _tokenStorage;

  Dio get dio => _dio;

  ApiClient(this._dio) {
    _tokenStorage = getIt<TokenStorage>();
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.followRedirects = true;
    _dio.options.maxRedirects = 5;

    // Request interceptor for adding auth token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          // Ensure content type is set for POST requests
          if (options.method == 'POST' || options.method == 'PUT') {
            options.headers['Content-Type'] = 'application/json';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // Token expired, logout user
            _tokenStorage.deleteToken();
          }
          handler.next(error);
        },
      ),
    );

    // Logging interceptor
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (object) => print(object),
      ),
    );
  }

  // Auth endpoints - OTPless only
  // Traditional authentication methods
  Future<Response> login(String username, String password) async {
    return await _dio.post(
      '/auth/login',
      data: {
        'username': username,
        'password': password,
      },
    );
  }

  Future<Response> signup(String username, String email, String password, String role) async {
    return await _dio.post(
      '/auth/signup',
      data: {
        'username': username,
        'email': email,
        'password': password,
        'role': role,
      },
    );
  }

  // OTPless authentication methods
  Future<Response> sendOTP({
    required String channel,
    String? phone,
    String? email,
  }) async {
    return await _dio.post(
      '/auth/send-otp',
      data: {
        'channel': channel,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
      },
    );
  }

  Future<Response> verifyOTP({
    required String channel,
    required String otp,
    String? phone,
    String? email,
    String? username,  // Required for new users
    String role = 'user',
  }) async {
    return await _dio.post(
      '/auth/verify-otp',
      data: {
        'channel': channel,
        'otp': otp,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (username != null) 'username': username,
        'role': role,
      },
    );
  }

  Future<Response> socialLogin({
    required String token,
    String? username,
    String role = 'user',
  }) async {
    return await _dio.post(
      '/auth/social-login',
      data: {
        'token': token,
        if (username != null) 'username': username,
        'role': role,
      },
    );
  }

  Future<Response> getCurrentUser() async {
    return await _dio.get('/auth/me');
  }

  Future<Response> updateProfile(Map<String, dynamic> profileData) async {
    return await _dio.put('/auth/me', data: profileData);
  }

  Future<Response> uploadProfilePicture(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    return await _dio.post('/auth/me/profile-picture', data: formData);
  }

  Future<Response> deleteProfilePicture() async {
    return await _dio.delete('/auth/me/profile-picture');
  }

  String getProfilePictureUrl(String? profilePicture) {
    if (profilePicture == null || profilePicture.isEmpty) {
      return '';
    }
    return '$baseUrl$profilePicture';
  }

  // Buildings endpoints
  Future<Response> getBuildings() async {
    return await _dio.get('/buildings/');
  }

  Future<Response> getBuilding(String buildingId) async {
    return await _dio.get('/buildings/$buildingId');
  }

  Future<Response> createBuilding(Map<String, dynamic> buildingData) async {
    return await _dio.post('/buildings/', data: buildingData);
  }

  // Navigation endpoints
  Future<Response> getNavigation(Map<String, dynamic> navigationRequest) async {
    return await _dio.post('/navigation/navigate', data: navigationRequest);
  }

  Future<Response> getArMarkers(String buildingId) async {
    return await _dio.get('/navigation/buildings/$buildingId/ar-markers');
  }

  // Admin endpoints
  Future<Response> generate3DModel(String buildingId, List<Map<String, dynamic>> coordinates) async {
    return await _dio.post('/admin/buildings/$buildingId/generate-3d', data: coordinates);
  }

  Future<Response> getAnalytics() async {
    return await _dio.get('/admin/analytics/buildings');
  }

  Future<Response> updateBuildingBoundary(String buildingId, Map<String, dynamic> data) async {
    return await _dio.put('/buildings/$buildingId/boundary', data: data);
  }

  Future<Response> getBuildingStructure(String buildingId) async {
    return await _dio.get('/buildings/$buildingId/structure');
  }

  // Smart Navigation endpoints
  Future<Response> getBuildingLocations(String buildingId) async {
    return await _dio.get('/navigation/buildings/$buildingId/locations');
  }

  Future<Response> calculateSmartRoute(
    String buildingId,
    String startNodeId,
    String endNodeId,
  ) async {
    return await _dio.post(
      '/navigation/buildings/$buildingId/route',
      data: {
        'start_node_id': startNodeId,
        'end_node_id': endNodeId,
      },
    );
  }

  Future<Response> getBuildingNavGraph(String buildingId) async {
    return await _dio.get('/buildings/$buildingId/nav-graph');
  }

  // ============================================
  // INDOOR GRAPH API ENDPOINTS
  // ============================================

  /// Get indoor navigation graph for a building
  Future<Response> getIndoorGraph(String buildingId) async {
    return await _dio.get('/indoor/buildings/$buildingId/indoor-graph');
  }

  /// Save indoor navigation graph
  Future<Response> saveIndoorGraph(String buildingId, Map<String, dynamic> graphData) async {
    return await _dio.post('/indoor/buildings/$buildingId/indoor-graph', data: graphData);
  }

  /// Get route between two nodes with ETA and haptic patterns
  Future<Response> getIndoorRoute(
    String buildingId,
    String fromNode,
    String toNode, {
    bool accessible = false,
    bool avoidCrowds = false,
    double stepLength = 0.7,
    double walkingSpeed = 1.2,
  }) async {
    return await _dio.get(
      '/indoor/buildings/$buildingId/indoor-graph/route',
      queryParameters: {
        'from_node': fromNode,
        'to_node': toNode,
        'accessible': accessible,
        'avoid_crowds': avoidCrowds,
        'step_length': stepLength,
        'walking_speed': walkingSpeed,
      },
    );
  }

  /// Get nearest emergency exit
  Future<Response> getNearestEmergencyExit(
    String buildingId,
    String fromNode, {
    bool accessible = false,
  }) async {
    return await _dio.get(
      '/indoor/buildings/$buildingId/indoor-graph/emergency-exit',
      queryParameters: {
        'from_node': fromNode,
        'accessible': accessible,
      },
    );
  }

  /// Lookup node by QR code
  Future<Response> lookupNodeByQR(String buildingId, String qrData) async {
    return await _dio.get(
      '/indoor/buildings/$buildingId/indoor-graph/qr-lookup',
      queryParameters: {'qr_data': qrData},
    );
  }

  /// Get graph statistics
  Future<Response> getIndoorGraphStats(String buildingId) async {
    return await _dio.get('/indoor/buildings/$buildingId/indoor-graph/stats');
  }

  /// Validate indoor graph
  Future<Response> validateIndoorGraph(String buildingId) async {
    return await _dio.get('/indoor/buildings/$buildingId/indoor-graph/validate');
  }

  /// Get all-pairs shortest paths
  Future<Response> getShortestPaths(String buildingId, {bool accessible = false}) async {
    return await _dio.get(
      '/indoor/buildings/$buildingId/indoor-graph/shortest-paths',
      queryParameters: {'accessible': accessible},
    );
  }

  /// Export indoor graph as JSON
  Future<Response> exportIndoorGraph(String buildingId) async {
    return await _dio.get('/indoor/buildings/$buildingId/indoor-graph/export');
  }

  /// Import indoor graph from JSON
  Future<Response> importIndoorGraph(String buildingId, Map<String, dynamic> importData) async {
    return await _dio.post('/indoor/buildings/$buildingId/indoor-graph/import', data: importData);
  }

  /// Get graph version history
  Future<Response> getGraphVersions(String buildingId) async {
    return await _dio.get('/indoor/buildings/$buildingId/indoor-graph/versions');
  }

  /// Rollback to a previous version
  Future<Response> rollbackGraph(String buildingId, int version) async {
    return await _dio.post('/indoor/buildings/$buildingId/indoor-graph/rollback/$version');
  }

  // ============================================
  // USER FEATURES
  // ============================================

  /// Get user favorites
  Future<Response> getFavorites() async {
    return await _dio.get('/indoor/favorites');
  }

  /// Add favorite destination
  Future<Response> addFavorite(Map<String, dynamic> favorite) async {
    return await _dio.post('/indoor/favorites', data: favorite);
  }

  /// Remove favorite
  Future<Response> removeFavorite(String nodeId) async {
    return await _dio.delete('/indoor/favorites/$nodeId');
  }

  /// Get recent routes
  Future<Response> getRecentRoutes() async {
    return await _dio.get('/indoor/recent-routes');
  }

  /// Add recent route
  Future<Response> addRecentRoute(Map<String, dynamic> route) async {
    return await _dio.post('/indoor/recent-routes', data: route);
  }

  /// Share location
  Future<Response> shareLocation(Map<String, dynamic> shareData) async {
    return await _dio.post('/indoor/share-location', data: shareData);
  }

  /// Get shared location
  Future<Response> getSharedLocation(String shareId) async {
    return await _dio.get('/indoor/share-location/$shareId');
  }

  /// Save user preferences
  Future<Response> saveUserPreferences(Map<String, dynamic> preferences) async {
    return await _dio.post('/indoor/user/preferences', data: preferences);
  }

  /// Calculate dead reckoning position
  Future<Response> calculateDeadReckoning(Map<String, dynamic> data) async {
    return await _dio.post('/indoor/dead-reckoning/calculate', data: data);
  }

  /// Get haptic patterns
  Future<Response> getHapticPatterns() async {
    return await _dio.get('/indoor/haptic-patterns');
  }

  /// Update crowd density
  Future<Response> updateCrowdDensity(String buildingId, List<Map<String, dynamic>> updates) async {
    return await _dio.post('/indoor/buildings/$buildingId/indoor-graph/crowd-density', data: updates);
  }

  /// Get magnetic calibration
  Future<Response> getMagneticCalibration(String buildingId) async {
    return await _dio.get('/indoor/buildings/$buildingId/magnetic-calibration');
  }

  /// Save magnetic calibration
  Future<Response> saveMagneticCalibration(String buildingId, Map<String, dynamic> calibration) async {
    return await _dio.post('/indoor/buildings/$buildingId/magnetic-calibration', data: calibration);
  }

  // ============================================
  // CROWDSOURCED INTELLIGENCE ENDPOINTS
  // ============================================

  /// Submit travel report (silent background)
  Future<Response> submitTravelReport(Map<String, dynamic> report) async {
    return await _dio.post('/indoor/travel-report', data: report);
  }

  /// Submit landmark report (silent background)
  Future<Response> submitLandmarkReport(Map<String, dynamic> report) async {
    return await _dio.post('/indoor/landmark-report', data: report);
  }

  /// Submit blocked path report
  Future<Response> submitBlockedPathReport(Map<String, dynamic> report) async {
    return await _dio.post('/indoor/blocked-path-report', data: report);
  }

  /// Get live conditions for a building
  Future<Response> getLiveConditions(String buildingId) async {
    return await _dio.get('/indoor/buildings/$buildingId/live-conditions');
  }

  /// Get smart route with live data
  Future<Response> getSmartRoute(
    String buildingId,
    String fromNode,
    String toNode, {
    bool accessible = false,
    bool useLiveData = true,
    double stepLength = 0.7,
    double walkingSpeed = 1.2,
  }) async {
    return await _dio.get(
      '/indoor/buildings/$buildingId/indoor-graph/smart-route',
      queryParameters: {
        'from_node': fromNode,
        'to_node': toNode,
        'accessible': accessible,
        'use_live_data': useLiveData,
        'step_length': stepLength,
        'walking_speed': walkingSpeed,
      },
    );
  }

  /// Clear blocked path report
  Future<Response> clearBlockedPath(String buildingId, String fromNode, String toNode) async {
    return await _dio.post(
      '/indoor/buildings/$buildingId/clear-blocked-path',
      queryParameters: {
        'from_node': fromNode,
        'to_node': toNode,
      },
    );
  }

  /// Get landmark changes (admin)
  Future<Response> getLandmarkChanges(String buildingId) async {
    return await _dio.get('/indoor/buildings/$buildingId/landmark-changes');
  }

  /// Get route anomalies (admin)
  Future<Response> getRouteAnomalies(String buildingId) async {
    return await _dio.get('/indoor/buildings/$buildingId/route-anomalies');
  }

  // ============================================
  // AI ASSISTANT ENDPOINTS
  // ============================================

  /// Generate smart label suggestion based on node type
  Future<Response> suggestLabel({
    required String nodeType,
    String? number,
    String? name,
  }) async {
    return await _dio.post('/ai/suggest-label', data: {
      'node_type': nodeType,
      'number': number,
      'name': name,
    });
  }

  /// Generate AI-powered landmark description
  Future<Response> generateLandmarkDescription({
    required String nodeType,
    required String label,
    String? context,
  }) async {
    return await _dio.post('/ai/generate-landmark-description', data: {
      'node_type': nodeType,
      'label': label,
      'context': context,
    });
  }

  /// Get available node types with metadata
  Future<Response> getNodeTypes() async {
    return await _dio.get('/ai/node-types');
  }
}
