import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:indoor_navigation/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:indoor_navigation/core/navigation/app_navigator.dart';
import 'package:indoor_navigation/core/theme/app_theme.dart';
import 'package:indoor_navigation/core/widgets/animated_widgets.dart';
import 'package:indoor_navigation/core/utils/responsive.dart';
import 'package:indoor_navigation/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:indoor_navigation/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:indoor_navigation/features/profile/presentation/pages/feedback_page.dart';
import 'package:indoor_navigation/features/profile/presentation/pages/faq_page.dart';
import 'package:indoor_navigation/features/profile/presentation/pages/privacy_policy_page.dart';
import 'package:indoor_navigation/features/profile/presentation/pages/terms_conditions_page.dart';
import 'package:indoor_navigation/core/services/tour_service.dart';
import 'package:indoor_navigation/core/di/injection_container.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _contentController;
  late Animation<double> _headerScale;
  late Animation<double> _contentFade;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.elasticOut),
    );
    _headerController.forward();

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      _contentController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    return Scaffold(
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is! AuthenticatedState) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange));
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(state),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _contentFade,
                  child: Padding(
                    padding: Responsive.padding(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        _buildQuickStats(state),
                        SizedBox(height: Responsive.spacing(20)),
                        _buildMenuSection('Account', [
                          _MenuItem(
                            icon: Icons.person_outline_rounded,
                            title: 'Edit Profile',
                            subtitle: 'Update your information',
                            color: AppColors.primaryOrange,
                            onTap: () => AppNavigator.push(const EditProfilePage()),
                          ),
                          if (state.user.isAdmin)
                            _MenuItem(
                              icon: Icons.admin_panel_settings_rounded,
                              title: 'Admin Panel',
                              subtitle: 'Manage buildings & data',
                              color: AppColors.sunsetOrange,
                              onTap: () => AppNavigator.push(const AdminDashboardPage()),
                            ),
                        ]),
                        SizedBox(height: Responsive.spacing(16)),
                        _buildMenuSection('Support', [
                          _MenuItem(
                            icon: Icons.feedback_outlined,
                            title: 'Send Feedback',
                            subtitle: 'Help us improve',
                            color: Colors.blue,
                            onTap: () => AppNavigator.push(const FeedbackPage()),
                          ),
                          _MenuItem(
                            icon: Icons.help_outline_rounded,
                            title: 'FAQ',
                            subtitle: 'Frequently asked questions',
                            color: Colors.green,
                            onTap: () => AppNavigator.push(const FAQPage()),
                          ),
                          _MenuItem(
                            icon: Icons.tour_rounded,
                            title: 'App Tour',
                            subtitle: 'Replay onboarding tutorial',
                            color: Colors.purple,
                            onTap: () async {
                              final tourService = getIt<TourService>();
                              await tourService.resetTours();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Tour reset! Go to Home to see it again.'),
                                    backgroundColor: AppColors.primaryOrange,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            },
                          ),
                        ]),
                        SizedBox(height: Responsive.spacing(16)),
                        _buildMenuSection('Legal', [
                          _MenuItem(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy Policy',
                            subtitle: 'How we handle your data',
                            color: Colors.teal,
                            onTap: () => AppNavigator.push(const PrivacyPolicyPage()),
                          ),
                          _MenuItem(
                            icon: Icons.description_outlined,
                            title: 'Terms & Conditions',
                            subtitle: 'Usage terms',
                            color: Colors.indigo,
                            onTap: () => AppNavigator.push(const TermsConditionsPage()),
                          ),
                        ]),
                        SizedBox(height: Responsive.spacing(24)),
                        _buildLogoutButton(),
                        SizedBox(height: Responsive.spacing(16)),
                        _buildAppVersion(),
                        SizedBox(height: Responsive.spacing(32)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(AuthenticatedState state) {
    return SliverAppBar(
      expandedHeight: Responsive.height(35),
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primaryOrange,
      leading: AnimatedScaleButton(
        onTap: () => AppNavigator.pop(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppGradients.primaryGradient),
          child: SafeArea(
            child: ScaleTransition(
              scale: _headerScale,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  _buildProfileAvatar(state),
                  SizedBox(height: Responsive.spacing(16)),
                  Text(
                    state.user.username,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(24),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.user.email,
                    style: TextStyle(
                      fontSize: Responsive.fontSize(14),
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (state.user.isAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Administrator',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: Responsive.fontSize(12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(AuthenticatedState state) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Text(
              state.user.username[0].toUpperCase(),
              style: TextStyle(
                fontSize: Responsive.fontSize(40),
                fontWeight: FontWeight.bold,
                color: AppColors.primaryOrange,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: AnimatedScaleButton(
            onTap: () => AppNavigator.push(const EditProfilePage()),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryOrangeDark,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(AuthenticatedState state) {
    return AnimatedCard(
      gradient: AppGradients.cardGradient,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.calendar_today_rounded,
            value: _formatDate(state.user.createdAt),
            label: 'Member Since',
          ),
          Container(width: 1, height: 40, color: AppColors.primaryOrange.withOpacity(0.2)),
          _StatItem(
            icon: Icons.badge_rounded,
            value: state.user.isAdmin ? 'Admin' : 'User',
            label: 'Account Type',
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title, List<_MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: Responsive.fontSize(18),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        ...items.asMap().entries.map((entry) {
          return AnimatedListItem(
            index: entry.key,
            child: _buildMenuItem(entry.value),
          );
        }),
      ],
    );
  }

  Widget _buildMenuItem(_MenuItem item) {
    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: item.onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(16),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(12),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppColors.textSecondary,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return AnimatedScaleButton(
      onTap: () => _showLogoutDialog(),
      child: Container(
        width: double.infinity,
        padding: Responsive.padding(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, color: AppColors.error),
            const SizedBox(width: 12),
            Text(
              'Sign Out',
              style: TextStyle(
                fontSize: Responsive.fontSize(16),
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppVersion() {
<<<<<<< HEAD
    return Column(
      children: [
        const Icon(Icons.navigation_rounded, color: AppColors.primaryOrange, size: 32),
        const SizedBox(height: 8),
        Text(
          'Indoor Navigation',
          style: TextStyle(
            fontSize: Responsive.fontSize(14),
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          'Version 1.0.0',
          style: TextStyle(
            fontSize: Responsive.fontSize(12),
            color: AppColors.textSecondary.withOpacity(0.7),
=======
    return const Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.explore, color: AppColors.primaryOrange, size: 32),
          SizedBox(height: 8),
          Text(
            'CITIAN',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Version 1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
>>>>>>> 969f15b (Add proximity detection system and update admin dashboard)
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.logout_rounded, color: AppColors.error),
            ),
            const SizedBox(width: 12),
            const Text('Sign Out'),
          ],
        ),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(LogoutEvent());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryOrange, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: Responsive.fontSize(16),
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: Responsive.fontSize(12),
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
