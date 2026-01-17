import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Data Sources
import 'package:indoor_navigation/core/network/api_client.dart';
import 'package:indoor_navigation/core/storage/token_storage.dart';
import 'package:indoor_navigation/core/database/local_database.dart';
import 'package:indoor_navigation/core/positioning/pdr_engine.dart';
import 'package:indoor_navigation/core/positioning/qr_position_reset.dart';
import 'package:indoor_navigation/core/positioning/location_detection_service.dart';
import 'package:indoor_navigation/core/services/tour_service.dart';
import 'package:indoor_navigation/core/services/connectivity_service.dart';
import 'package:indoor_navigation/core/services/offline_sync_service.dart';
import 'package:indoor_navigation/core/services/location_service.dart';
import 'package:indoor_navigation/core/services/api_service.dart';
import 'package:indoor_navigation/core/services/ocr_service.dart';
import 'package:indoor_navigation/core/services/crowdsourced_intelligence_service.dart';
import 'package:indoor_navigation/core/navigation/offline_navigation_service.dart';

// Repositories
import 'package:indoor_navigation/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:indoor_navigation/features/auth/domain/repositories/auth_repository.dart';
import 'package:indoor_navigation/features/buildings/data/repositories/buildings_repository_impl.dart';
import 'package:indoor_navigation/features/buildings/domain/repositories/buildings_repository.dart';
import 'package:indoor_navigation/features/navigation/data/repositories/navigation_repository_impl.dart';
import 'package:indoor_navigation/features/navigation/domain/repositories/navigation_repository.dart';
import 'package:indoor_navigation/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:indoor_navigation/features/admin/domain/repositories/admin_repository.dart';
import 'package:indoor_navigation/features/offline/data/repositories/offline_repository.dart';
import 'package:indoor_navigation/features/ar_navigation/data/repositories/ar_navigation_repository_impl.dart';
import 'package:indoor_navigation/features/ar_navigation/domain/repositories/ar_navigation_repository.dart';

// Use Cases
import 'package:indoor_navigation/features/auth/domain/usecases/login_usecase.dart';
import 'package:indoor_navigation/features/auth/domain/usecases/signup_usecase.dart';
import 'package:indoor_navigation/features/auth/domain/usecases/traditional_login_usecase.dart';
import 'package:indoor_navigation/features/auth/domain/usecases/traditional_signup_usecase.dart';
import 'package:indoor_navigation/features/auth/domain/usecases/logout_usecase.dart';
import 'package:indoor_navigation/features/auth/domain/usecases/get_current_user_usecase.dart';
import 'package:indoor_navigation/features/buildings/domain/usecases/get_buildings_usecase.dart';
import 'package:indoor_navigation/features/navigation/domain/usecases/get_navigation_usecase.dart';
import 'package:indoor_navigation/features/navigation/domain/usecases/get_ar_markers_usecase.dart';
import 'package:indoor_navigation/features/admin/domain/usecases/generate_3d_model_usecase.dart';
import 'package:indoor_navigation/features/admin/domain/usecases/get_analytics_usecase.dart';
import 'package:indoor_navigation/features/admin/domain/usecases/get_building_structure_usecase.dart';

// Blocs
import 'package:indoor_navigation/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:indoor_navigation/features/buildings/presentation/bloc/buildings_bloc.dart';
import 'package:indoor_navigation/features/navigation/presentation/bloc/navigation_bloc.dart';
import 'package:indoor_navigation/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:indoor_navigation/features/offline/presentation/bloc/offline_bloc.dart';
import 'package:indoor_navigation/features/ar_navigation/presentation/bloc/ar_navigation_bloc.dart';
import 'package:indoor_navigation/features/ar_navigation/presentation/bloc/ar_guidance_bloc.dart';

// Services
import 'package:indoor_navigation/features/navigation/presentation/services/audio_feedback_service.dart';
import 'package:indoor_navigation/features/navigation/presentation/services/smart_audio_guidance_service.dart';

final getIt = GetIt.instance;

Future<void> initializeDependencies() async {
  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);
  
  const secureStorage = FlutterSecureStorage();
  getIt.registerSingleton<FlutterSecureStorage>(secureStorage);
  
  // Core
  getIt.registerSingleton<TokenStorage>(TokenStorage(getIt<FlutterSecureStorage>()));
  getIt.registerSingleton<Dio>(Dio());
  getIt.registerSingleton<ApiClient>(ApiClient(getIt<Dio>()));
  getIt.registerSingleton<TourService>(TourService(getIt<SharedPreferences>()));
  
  // Connectivity and Sync Services
  final connectivityService = ConnectivityService();
  await connectivityService.initialize();
  getIt.registerSingleton<ConnectivityService>(connectivityService);
  
  final offlineSyncService = OfflineSyncService();
  getIt.registerSingleton<OfflineSyncService>(offlineSyncService);
  
  // Location Service
  final locationService = LocationService(null, sharedPreferences); // Will be updated with API client later
  getIt.registerSingleton<LocationService>(locationService);
  
  // Local Database
  try {
    final localDatabase = LocalDatabase();
    await localDatabase.init();
    getIt.registerSingleton<LocalDatabase>(localDatabase);
    print('✅ Local database initialized successfully');
  } catch (e) {
    print('❌ Failed to initialize local database: $e');
    // Create a fallback database instance
    final localDatabase = LocalDatabase();
    getIt.registerSingleton<LocalDatabase>(localDatabase);
  }
  
  // PDR Engine
  final pdrEngine = PDREngine();
  getIt.registerSingleton<PDREngine>(pdrEngine);
  
  // Location Detection Service
  getIt.registerLazySingleton<LocationDetectionService>(
    () => LocationDetectionService(getIt<PDREngine>()),
  );
  
  // QR Position Reset
  getIt.registerLazySingleton<QRPositionReset>(
    () => QRPositionReset(getIt<PDREngine>(), getIt<LocalDatabase>()),
  );
  
  // Offline Navigation Service
  getIt.registerLazySingleton<OfflineNavigationService>(
    () => OfflineNavigationService(
      getIt<LocalDatabase>(),
      getIt<PDREngine>(),
      getIt<ConnectivityService>(),
    ),
  );
  
  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt<ApiClient>(), getIt<TokenStorage>()),
  );
  getIt.registerLazySingleton<BuildingsRepository>(
    () => BuildingsRepositoryImpl(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<NavigationRepository>(
    () => NavigationRepositoryImpl(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<AdminRepository>(
    () => AdminRepositoryImpl(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<OfflineRepository>(
    () => OfflineRepository(getIt<ApiClient>(), getIt<LocalDatabase>()),
  );
  getIt.registerLazySingleton<ArNavigationRepository>(
    () => ArNavigationRepositoryImpl(getIt<ApiService>()),
  );
  
  // Initialize offline sync service with API client
  getIt<OfflineSyncService>().initialize(getIt<ApiClient>());
  getIt<OfflineSyncService>().setConnectivityService(getIt<ConnectivityService>());
  
  // Update location service with API client
  getIt.unregister<LocationService>();
  getIt.registerSingleton<LocationService>(
    LocationService(getIt<ApiClient>(), getIt<SharedPreferences>())
  );
  
  // API Service with fallback strategies
  getIt.registerSingleton<ApiService>(
    ApiService(
      getIt<ApiClient>(),
      getIt<ConnectivityService>(),
      getIt<OfflineSyncService>(),
    ),
  );
  
  getIt.registerLazySingleton<OcrService>(() => OcrService());
  
  // Crowdsourced Intelligence Service
  getIt.registerSingleton<CrowdsourcedIntelligenceService>(
    CrowdsourcedIntelligenceService(getIt<ApiClient>()),
  );
  
  // Use Cases
  getIt.registerLazySingleton(() => LoginUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => SignupUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => TraditionalLoginUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => TraditionalSignupUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => LogoutUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => GetCurrentUserUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => GetBuildingsUseCase(getIt<BuildingsRepository>()));
  getIt.registerLazySingleton(() => GetNavigationUseCase(getIt<NavigationRepository>()));
  getIt.registerLazySingleton(() => GetArMarkersUseCase(getIt<NavigationRepository>()));
  getIt.registerLazySingleton(() => Generate3DModelUseCase(getIt<AdminRepository>()));
  getIt.registerLazySingleton(() => GetAnalyticsUseCase(getIt<AdminRepository>()));
  getIt.registerLazySingleton(() => GetBuildingStructureUseCase(getIt<AdminRepository>()));
  
  // Blocs
  getIt.registerFactory(() => AuthBloc(
    loginUseCase: getIt<LoginUseCase>(),
    signupUseCase: getIt<SignupUseCase>(),
    traditionalLoginUseCase: getIt<TraditionalLoginUseCase>(),
    traditionalSignupUseCase: getIt<TraditionalSignupUseCase>(),
    logoutUseCase: getIt<LogoutUseCase>(),
    getCurrentUserUseCase: getIt<GetCurrentUserUseCase>(),
    authRepository: getIt<AuthRepository>(),
  ));
  getIt.registerLazySingleton(() => BuildingsBloc(getIt<GetBuildingsUseCase>(), getIt<BuildingsRepository>()));
  getIt.registerLazySingleton(() => NavigationBloc(
    getNavigationUseCase: getIt<GetNavigationUseCase>(),
    getArMarkersUseCase: getIt<GetArMarkersUseCase>(),
    navigationRepository: getIt<NavigationRepository>(),
  ));
  getIt.registerLazySingleton(() => AdminBloc(
    generate3DModelUseCase: getIt<Generate3DModelUseCase>(),
    getAnalyticsUseCase: getIt<GetAnalyticsUseCase>(),
    getBuildingStructureUseCase: getIt<GetBuildingStructureUseCase>(),
  ));
  getIt.registerLazySingleton(() => OfflineBloc(getIt<OfflineRepository>()));
  getIt.registerLazySingleton(() => ArNavigationBloc(repository: getIt<ArNavigationRepository>()));
  
  // AR Guidance Services
  getIt.registerSingleton<AudioFeedbackService>(AudioFeedbackService());
  getIt.registerLazySingleton<SmartAudioGuidanceService>(
    () => SmartAudioGuidanceService(getIt<AudioFeedbackService>()),
  );
  getIt.registerFactory(() => ARGuidanceBloc(
    getIt<SmartAudioGuidanceService>(),
  ));
}