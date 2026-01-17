import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:indoor_navigation/core/di/injection_container.dart';
import 'package:indoor_navigation/core/theme/app_theme.dart';
import 'package:indoor_navigation/core/navigation/app_navigator.dart';
import 'package:indoor_navigation/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:indoor_navigation/features/buildings/presentation/bloc/buildings_bloc.dart';
import 'package:indoor_navigation/features/navigation/presentation/bloc/navigation_bloc.dart';
import 'package:indoor_navigation/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:indoor_navigation/features/offline/presentation/bloc/offline_bloc.dart';
import 'package:indoor_navigation/features/splash/presentation/pages/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dependency injection
  await initializeDependencies();
  
  runApp(const IndoorNavigationApp());
}

class IndoorNavigationApp extends StatelessWidget {
  const IndoorNavigationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<AuthBloc>()),
        BlocProvider(create: (_) => getIt<BuildingsBloc>()),
        BlocProvider(create: (_) => getIt<NavigationBloc>()),
        BlocProvider(create: (_) => getIt<AdminBloc>()),
        BlocProvider(create: (_) => getIt<OfflineBloc>()),
      ],
      child: MaterialApp(
        title: 'Indoor Navigation',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const SplashPage(),
        navigatorKey: AppNavigator.navigatorKey,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}