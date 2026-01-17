import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:indoor_navigation/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:indoor_navigation/features/buildings/presentation/bloc/buildings_bloc.dart';
import 'package:indoor_navigation/features/navigation/presentation/bloc/navigation_bloc.dart';
import 'package:indoor_navigation/core/navigation/app_navigator.dart';
import 'package:indoor_navigation/features/profile/presentation/pages/profile_page.dart';
import 'package:indoor_navigation/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:indoor_navigation/features/admin/presentation/pages/coordinate_collection_page.dart';
import 'package:indoor_navigation/features/buildings/presentation/pages/buildings_page.dart';
import 'package:indoor_navigation/features/navigation/presentation/pages/unified_navigation_page.dart';
import 'package:indoor_navigation/features/offline/presentation/pages/offline_downloads_page.dart';
import 'package:indoor_navigation/features/auth/presentation/pages/login_page.dart';
import 'package:indoor_navigation/core/services/tour_service.dart';
import 'package:indoor_navigation/core/di/injection_container.dart';
import 'package:indoor_navigation/core/widgets/connectivity_indicator.dart';
import 'package:indoor_navigation/core/theme/app_theme.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late TourService _tourService;
  TutorialCoachMark? _tutorialCoachMark;

  // Global keys for tour targets
  final GlobalKey _dashboardKey = GlobalKey();
  final GlobalKey _buildingsKey = GlobalKey();
  final GlobalKey _navigationKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _adminKey = GlobalKey();
  final GlobalKey _offlineKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tourService = getIt<TourService>();
    // Load buildings when home page loads
    context.read<BuildingsBloc>().add(LoadBuildingsEvent());
    
    // Show tour after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTour();
    });
  }

  void _checkAndShowTour() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthenticatedState) {
      if (!_tourService.hasCompletedUserTour()) {
        _showUserTour();
      }
    }
  }

  void _showUserTour() {
    final targets = <TargetFocus>[
      TargetFocus(
        identify: "dashboard",
        keyTarget: _dashboardKey,
        contents: [
          TourService.createTargetContent(
            title: "Dashboard",
            description: "View your quick actions and get started with navigation",
            align: ContentAlign.bottom,
          ),
        ],
      ),
      TargetFocus(
        identify: "buildings",
        keyTarget: _buildingsKey,
        contents: [
          TourService.createTargetContent(
            title: "Buildings",
            description: "Browse all available buildings for indoor navigation",
            align: ContentAlign.bottom,
          ),
        ],
      ),
      TargetFocus(
        identify: "navigation",
        keyTarget: _navigationKey,
        contents: [
          TourService.createTargetContent(
            title: "Navigation",
            description: "Start AR navigation to find your way indoors",
            align: ContentAlign.bottom,
          ),
        ],
      ),
      TargetFocus(
        identify: "profile",
        keyTarget: _profileKey,
        contents: [
          TourService.createTargetContent(
            title: "Profile",
            description: "Manage your account settings and preferences",
            align: ContentAlign.bottom,
          ),
        ],
      ),
    ];

    _tutorialCoachMark = _tourService.createUserHomeTour(
      targets: targets,
      onFinish: () {
        setState(() {});
      },
      onSkip: () {
        setState(() {});
      },
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      _tutorialCoachMark?.show(context: context);
    });
  }

  @override
  void dispose() {
    _tutorialCoachMark?.finish();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is UnauthenticatedState) {
          AppNavigator.popAllAndPush(const LoginPage());
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundDark,
          elevation: 0,
          title: const Text(
            'Indoor Navigation',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            const ConnectivityIndicator(showLabel: true),
            const SizedBox(width: 8),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                if (state is AuthenticatedState && state.user.isAdmin) {
                  return IconButton(
                    key: _adminKey,
                    icon: const Icon(Icons.admin_panel_settings, color: AppColors.primaryOrange),
                    onPressed: () => AppNavigator.push(const AdminDashboardPage()),
                    tooltip: 'Admin Panel',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            IconButton(
              key: _profileKey,
              icon: const Icon(Icons.person, color: AppColors.textPrimary),
              onPressed: () => AppNavigator.push(const ProfilePage()),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _DashboardTab(
              offlineKey: _offlineKey,
              adminKey: _adminKey,
            ),
            const _BuildingsTab(),
            const _NavigationTab(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.primaryOrange,
          unselectedItemColor: AppColors.textSecondary,
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              key: _dashboardKey,
              icon: const Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              key: _buildingsKey,
              icon: const Icon(Icons.business),
              label: 'Buildings',
            ),
            BottomNavigationBarItem(
              key: _navigationKey,
              icon: const Icon(Icons.navigation),
              label: 'Navigate',
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final GlobalKey? offlineKey;
  final GlobalKey? adminKey;

  const _DashboardTab({
    this.offlineKey,
    this.adminKey,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthenticatedState) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange));
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.waving_hand,
                              color: AppColors.primaryOrange,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome, ${authState.user.username}!',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Ready to navigate indoors?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Quick Actions Header
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                  _QuickActionCard(
                    key: offlineKey,
                    icon: Icons.cloud_download,
                    title: 'Offline Downloads',
                    subtitle: 'Download buildings',
                    color: AppColors.info,
                    onTap: () => AppNavigator.push(const OfflineDownloadsPage()),
                  ),
                  _QuickActionCard(
                    icon: Icons.business,
                    title: 'View Buildings',
                    subtitle: 'Browse buildings',
                    color: AppColors.success,
                    onTap: () => AppNavigator.push(const BuildingsPage()),
                  ),
                  _QuickActionCard(
                    icon: Icons.navigation,
                    title: 'Start Navigation',
                    subtitle: 'Begin AR navigation',
                    color: AppColors.primaryOrange,
                    onTap: () => AppNavigator.push(const BuildingsPage()),
                  ),
                  _QuickActionCard(
                    icon: Icons.person,
                    title: 'Profile',
                    subtitle: 'View your profile',
                    color: Colors.purple,
                    onTap: () => AppNavigator.push(const ProfilePage()),
                  ),
                  if (authState.user.isAdmin) ...[
                    _QuickActionCard(
                      key: adminKey,
                      icon: Icons.admin_panel_settings,
                      title: 'Admin Panel',
                      subtitle: 'Manage buildings',
                      color: AppColors.error,
                      onTap: () => AppNavigator.push(const AdminDashboardPage()),
                    ),
                    _QuickActionCard(
                      icon: Icons.location_on,
                      title: 'Collect Coordinates',
                      subtitle: 'Map new areas',
                      color: Colors.teal,
                      onTap: () => AppNavigator.push(const CoordinateCollectionPage()),
                    ),
                  ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final VoidCallback onTap;

  const _QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? AppColors.primaryOrange;
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: cardColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BuildingsTab extends StatelessWidget {
  const _BuildingsTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BuildingsBloc, BuildingsState>(
      builder: (context, state) {
        if (state is BuildingsLoadingState) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryOrange),
          );
        } else if (state is BuildingsErrorState) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  state.message,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<BuildingsBloc>().add(LoadBuildingsEvent());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        } else if (state is BuildingsLoadedState) {
          if (state.buildings.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business, size: 64, color: AppColors.textSecondary),
                  SizedBox(height: 16),
                  Text(
                    'No buildings available',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.buildings.length,
            itemBuilder: (context, index) {
              final building = state.buildings[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      AppNavigator.push(
                        UnifiedNavigationPage(
                          building: building,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.business,
                              color: AppColors.primaryOrange,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  building.name,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  building.address,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: AppColors.textSecondary,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}

class _NavigationTab extends StatelessWidget {
  const _NavigationTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.navigation, size: 64, color: AppColors.textSecondary),
          SizedBox(height: 16),
          Text(
            'Select a building to start navigation',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}