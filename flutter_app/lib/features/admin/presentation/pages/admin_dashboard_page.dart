import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:indoor_navigation/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:indoor_navigation/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:indoor_navigation/core/navigation/app_navigator.dart';
import 'package:indoor_navigation/features/admin/presentation/pages/coordinate_collection_page.dart';
import 'package:indoor_navigation/features/admin/presentation/pages/create_building_map_page.dart';
import 'package:indoor_navigation/features/admin/presentation/pages/building_management_page.dart';
import 'package:indoor_navigation/features/admin/presentation/pages/offline_building_management_page.dart';
import 'package:indoor_navigation/features/admin/presentation/pages/modern_qr_management_page.dart';
import 'package:indoor_navigation/features/profile/presentation/pages/profile_page.dart';
import 'package:indoor_navigation/features/auth/presentation/pages/login_page.dart';
import 'package:indoor_navigation/core/services/tour_service.dart';
import 'package:indoor_navigation/core/widgets/connectivity_status_widget.dart';
import 'package:indoor_navigation/core/di/injection_container.dart';
import 'package:indoor_navigation/core/theme/app_theme.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with SingleTickerProviderStateMixin {
  late TourService _tourService;
  TutorialCoachMark? _tutorialCoachMark;
  late TabController _tabController;
  int _selectedIndex = 0;

  // Global keys for tour targets
  final GlobalKey _statsKey = GlobalKey();
  final GlobalKey _coordinatesKey = GlobalKey();
  final GlobalKey _buildingsListKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _createBuildingKey = GlobalKey();
  final GlobalKey _manageBuildingsKey = GlobalKey();
  final GlobalKey _offlineManagementKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tourService = getIt<TourService>();
    _tabController = TabController(length: 4, vsync: this);
    context.read<AdminBloc>().add(LoadAnalyticsEvent());
    
    // Show tour after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_tourService.hasCompletedAdminTour()) {
        _showAdminTour();
      }
    });
  }

  void _showAdminTour() {
    final targets = <TargetFocus>[
      TargetFocus(
        identify: "stats",
        keyTarget: _statsKey,
        contents: [
          TourService.createTargetContent(
            title: "📊 Statistics Overview",
            description: "Monitor your indoor navigation system with real-time statistics. Track total buildings, floors, rooms, and waypoints across your entire network.",
            additionalInfo: "These numbers update automatically as you add new buildings and collect coordinates.",
            align: ContentAlign.bottom,
          ),
        ],
      ),
      TargetFocus(
        identify: "create_building",
        keyTarget: _createBuildingKey,
        contents: [
          TourService.createTargetContent(
            title: "🏗️ Create Building (Online)",
            description: "Create buildings when you have internet connection. Use the interactive satellite map to mark precise building boundaries by tapping multiple points around the perimeter.",
            additionalInfo: "Perfect for accurate boundary definition. Requires internet for map loading and address fetching.",
            align: ContentAlign.top,
          ),
        ],
      ),
      TargetFocus(
        identify: "manage_buildings",
        keyTarget: _manageBuildingsKey,
        contents: [
          TourService.createTargetContent(
            title: "🏢 Manage Buildings",
            description: "View and edit all your existing buildings. See area calculations, update boundaries by dragging markers, and manage building information. Perfect for maintaining your building database.",
            additionalInfo: "Edit boundaries, view details, or delete buildings. All changes are saved immediately.",
            align: ContentAlign.top,
          ),
        ],
      ),
      TargetFocus(
        identify: "offline_management",
        keyTarget: _offlineManagementKey,
        contents: [
          TourService.createTargetContent(
            title: "🔴 Offline Management",
            description: "Create buildings WITHOUT internet connection! Mark boundaries offline and sync later when online. Perfect for remote locations or areas with poor connectivity.",
            additionalInfo: "View sync logs, manage offline buildings, and track what's been uploaded. Auto-syncs when connection is restored.",
            align: ContentAlign.top,
          ),
        ],
      ),
      TargetFocus(
        identify: "coordinates",
        keyTarget: _coordinatesKey,
        contents: [
          TourService.createTargetContent(
            title: "📍 Collect Coordinates",
            description: "After creating buildings, walk around each floor to collect GPS waypoints. Add floor numbers, attach images/videos, and create detailed navigation points for indoor mapping.",
            additionalInfo: "Essential for AR navigation. Each coordinate becomes a waypoint in your indoor navigation system.",
            align: ContentAlign.top,
          ),
        ],
      ),
      TargetFocus(
        identify: "buildings",
        keyTarget: _buildingsListKey,
        contents: [
          TourService.createTargetContent(
            title: "🏗️ Recent Buildings",
            description: "View your recently created buildings and their status. Once you collect coordinates for a building, you can generate a 3D model with AI to automatically create rooms and waypoints.",
            additionalInfo: "The AI analyzes your coordinate data to intelligently map indoor spaces and create navigation paths.",
            align: ContentAlign.top,
          ),
        ],
      ),
      TargetFocus(
        identify: "profile",
        keyTarget: _profileKey,
        contents: [
          TourService.createTargetContent(
            title: "👤 Profile & Settings",
            description: "Access your profile information, app settings, and account management. You can also replay this tour anytime or access help documentation.",
            additionalInfo: "Manage your account, update preferences, and get support when needed.",
            align: ContentAlign.bottom,
          ),
        ],
      ),
    ];

    _tutorialCoachMark = _tourService.createAdminTour(
      targets: targets,
      onFinish: () {
        setState(() {});
        // Show completion message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Tour completed! You\'re ready to start building your indoor navigation system.'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Start Creating',
              textColor: Colors.white,
              onPressed: () {
                AppNavigator.push(const CreateBuildingMapPage());
              },
            ),
          ),
        );
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is UnauthenticatedState) {
          AppNavigator.popAllAndPush(const LoginPage());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          elevation: 0,
          actions: [
            const ConnectivityStatusWidget(showDetails: false),
            const SizedBox(width: 8),
            IconButton(
              key: _profileKey,
              icon: const Icon(Icons.person),
              onPressed: () => AppNavigator.push(const ProfilePage()),
              tooltip: 'Profile',
            ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                _tourService.resetTours();
                _showAdminTour();
              },
              tooltip: 'Show Tour',
            ),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildDashboardTab(),
            _buildFeedbackTab(),
            _buildFAQTab(),
            _buildSettingsTab(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.feedback_outlined),
              selectedIcon: Icon(Icons.feedback),
              label: 'Feedback',
            ),
            NavigationDestination(
              icon: Icon(Icons.help_outline),
              selectedIcon: Icon(Icons.help),
              label: 'FAQ',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return BlocListener<AdminBloc, AdminState>(
      listener: (context, state) {
        if (state is Model3DGeneratedState) {
          // When 3D model is generated, reload analytics to refresh the dashboard
          context.read<AdminBloc>().add(LoadAnalyticsEvent());
        }
      },
      child: BlocBuilder<AdminBloc, AdminState>(
        builder: (context, state) {
          if (state is AdminLoadingState) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is AdminErrorState) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<AdminBloc>().add(LoadAnalyticsEvent());
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (state is AnalyticsLoadedState) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<AdminBloc>().add(LoadAnalyticsEvent());
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Card
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, authState) {
                        if (authState is AuthenticatedState) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: AppColors.primaryOrange.withOpacity(0.2),
                                    child: Text(
                                      authState.user.username[0].toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryOrange,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Welcome, ${authState.user.username}!',
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryOrange,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Manage your indoor navigation system',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    // const SizedBox(height: 24),
                    
                    // // Statistics Cards with softer colors
                    // Text(
                    //   'Overview',
                    //   style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    //     fontWeight: FontWeight.bold,
                    //   ),
                    // ),
                    // const SizedBox(height: 12),
                    // GridView.count(
                    //   key: _statsKey,
                    //   shrinkWrap: true,
                    //   physics: const NeverScrollableScrollPhysics(),
                    //   crossAxisCount: 2,
                    //   crossAxisSpacing: 12,
                    //   mainAxisSpacing: 12,
                    //   childAspectRatio: 1.5,
                    //   children: [
                    //     _StatCard(
                    //       title: 'Buildings',
                    //       value: state.analytics.totalBuildings.toString(),
                    //       icon: Icons.business,
                    //       color: Colors.blue.shade400,
                    //       backgroundColor: Colors.blue.shade50,
                    //     ),
                    //     _StatCard(
                    //       title: 'Floors',
                    //       value: state.analytics.totalFloors.toString(),
                    //       icon: Icons.layers,
                    //       color: Colors.green.shade400,
                    //       backgroundColor: Colors.green.shade50,
                    //     ),
                    //     _StatCard(
                    //       title: 'Rooms',
                    //       value: state.analytics.totalRooms.toString(),
                    //       icon: Icons.room,
                    //       color: Colors.amber.shade600,
                    //       backgroundColor: Colors.amber.shade50,
                    //     ),
                    //     _StatCard(
                    //       title: 'Waypoints',
                    //       value: state.analytics.totalWaypoints.toString(),
                    //       icon: Icons.navigation,
                    //       color: Colors.purple.shade400,
                    //       backgroundColor: Colors.purple.shade50,
                    //     ),
                    //   ],
                    // ),
                    const SizedBox(height: 24),
                    
                    // Quick Actions
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Card(
                      key: _createBuildingKey,
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.add_business, color: Colors.green.shade600),
                        ),
                        title: const Text('Create Boundary'),
                        subtitle: const Text('Mark boundary on map'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => AppNavigator.push(const CreateBuildingMapPage()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Card(
                      key: _manageBuildingsKey,
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.business, color: Colors.orange.shade600),
                        ),
                        title: const Text('Manage Boundary'),
                        subtitle: const Text('View and edit existing Boundary'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => AppNavigator.push(const BuildingManagementPage()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Card(
                      key: _offlineManagementKey,
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.wifi_off, color: Colors.purple.shade600),
                        ),
                        title: const Text('Offline Management'),
                        subtitle: const Text('Manage Boundary offline status'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => AppNavigator.push(const OfflineBuildingManagementPage()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Card(
                      key: _coordinatesKey,
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.location_on, color: Colors.blue.shade600),
                        ),
                        title: const Text('Collect Coordinates'),
                        subtitle: const Text('Map coordinates areas with GPS'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => AppNavigator.push(const CoordinateCollectionPage()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Card(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.qr_code_2, color: Colors.teal.shade600),
                        ),
                        title: const Text('QR Code Management'),
                        subtitle: const Text('View and export QR markers'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => AppNavigator.push(const ModernQRManagementPage()),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Recent Buildings
                    Text(
                      'Recent Boundary',
                      key: _buildingsListKey,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (state.analytics.buildings.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.business_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'No buildings created yet',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ...state.analytics.buildings.take(5).map(
                        (building) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade50,
                              child: Icon(Icons.business, color: Colors.blue.shade600),
                            ),
                            title: Text(building.name),
                            subtitle: Text(building.address),
                            trailing: Text(
                              building.createdAt.toString().split(' ')[0],
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          } else if (state is Model3DGeneratedState || state is BuildingStructureLoadedState) {
            // These are intermediate states that trigger dialogs or navigation.
            // When we return to the dashboard and these are still active, we show 
            // the last known analytics or a loading spinner if analytics is being reloaded.
            return const Center(child: CircularProgressIndicator());
          }

          // Default fallback to prevent black screen
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Loading dashboard...', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeedbackTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Feedback',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'View and respond to user feedback',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          
          // Sample feedback items
          _FeedbackCard(
            userName: 'John Doe',
            rating: 5,
            comment: 'Great app! The AR navigation is very accurate.',
            date: DateTime.now().subtract(const Duration(days: 1)),
          ),
          _FeedbackCard(
            userName: 'Jane Smith',
            rating: 4,
            comment: 'Good experience, but could use more building coverage.',
            date: DateTime.now().subtract(const Duration(days: 2)),
          ),
          _FeedbackCard(
            userName: 'Mike Johnson',
            rating: 5,
            comment: 'Offline mode works perfectly!',
            date: DateTime.now().subtract(const Duration(days: 3)),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frequently Asked Questions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Common questions and answers',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          
          const _FAQItem(
            question: 'How do I add a new building?',
            answer: 'Go to the Collect Coordinates section and start mapping the building by collecting GPS coordinates at key points.',
          ),
          const _FAQItem(
            question: 'How does the 3D model generation work?',
            answer: 'Our AI processes the collected GPS coordinates to automatically generate floors, rooms, and waypoints for indoor navigation.',
          ),
          const _FAQItem(
            question: 'Can users navigate offline?',
            answer: 'Yes! Users can download buildings for offline use. The offline data includes all floors, rooms, and navigation waypoints.',
          ),
          const _FAQItem(
            question: 'How accurate is the AR navigation?',
            answer: 'AR navigation uses a combination of GPS, sensors, and QR code positioning for high accuracy indoor navigation.',
          ),
          const _FAQItem(
            question: 'How do I manage user permissions?',
            answer: 'User roles are set during signup. Admin users have access to this dashboard and can manage buildings.',
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryOrange,
                  AppColors.primaryOrangeLight,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.settings_rounded,
                  size: 40,
                  color: Colors.white,
                ),
                SizedBox(height: 12),
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Manage your admin preferences',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Settings Cards Section
          Text(
            'Account & Preferences',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          
          _buildSettingsCard(
            icon: Icons.person_rounded,
            title: 'Profile',
            subtitle: 'View and edit your profile',
            color: AppColors.primaryOrange,
            onTap: () => AppNavigator.push(const ProfilePage()),
          ),
          const SizedBox(height: 16),
          
          _buildSettingsCard(
            icon: Icons.tour_rounded,
            title: 'Show Tour',
            subtitle: 'Replay the onboarding tutorial',
            color: AppColors.warning,
            onTap: () {
              _tourService.resetTours();
              setState(() {
                _selectedIndex = 0;
              });
              Future.delayed(const Duration(milliseconds: 300), () {
                _showAdminTour();
              });
            },
          ),
          const SizedBox(height: 16),
          
          _buildSettingsCard(
            icon: Icons.refresh_rounded,
            title: 'Refresh Data',
            subtitle: 'Reload analytics and buildings',
            color: AppColors.success,
            onTap: () {
              context.read<AdminBloc>().add(LoadAnalyticsEvent());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing data...'),
                  backgroundColor: AppColors.primaryOrange,
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          
          // System Status Section
          Text(
            'System Status',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.textSecondary.withOpacity(0.2),
              ),
            ),
            child: const ConnectivityStatusWidget(showDetails: true),
          ),
          const SizedBox(height: 32),
          
          // About Section
          Text(
            'About',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surfaceDark,
                  AppColors.cardDark,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.textSecondary.withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryOrange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.explore,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CITIAN',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Navigation that knows your intent',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
        ],
      ),
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardDark,
            AppColors.surfaceDark,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 20,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color.withOpacity(0.8),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final String userName;
  final int rating;
  final String comment;
  final DateTime date;

  const _FeedbackCard({
    required this.userName,
    required this.rating,
    required this.comment,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Text(
                    userName[0].toUpperCase(),
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            size: 16,
                            color: Colors.amber.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(comment),
          ],
        ),
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
              if (_isExpanded) ...[
                const SizedBox(height: 12),
                Text(
                  widget.answer,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
