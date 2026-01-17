import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:indoor_navigation/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:indoor_navigation/core/navigation/app_navigator.dart';
import 'package:indoor_navigation/features/home/presentation/pages/modern_home_page.dart';
import 'package:indoor_navigation/features/auth/presentation/pages/login_page.dart';
import 'package:indoor_navigation/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:indoor_navigation/core/theme/app_theme.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  // Main controller for initial entry animations (logo/text block)
  late AnimationController _mainAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  // Controller for continuous icon animation
  late AnimationController _iconPulseController;
  late Animation<double> _iconRotationAnimation;
  late Animation<double> _iconScaleAnimation;

  // Controller for title & subtitle animations
  late AnimationController _textSlideController;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<Offset> _subtitleSlideAnimation;

  // Controller for loader animations
  late AnimationController _loaderAnimationController;
  late Animation<double> _loaderFadeAnimation;
  late Animation<Offset> _loaderSlideAnimation;

  // Controller for background gradient animation
  late AnimationController _backgroundGradientController;
  late Animation<AlignmentGeometry> _backgroundBeginAlignment;
  late Animation<AlignmentGeometry> _backgroundEndAlignment;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
    _checkAuthStatus();
  }

  void _setupAnimations() {
    // 1. Main Entry Animations (Logo and main text block)
    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5), // Start from slightly below center
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutQuint),
      ),
    );

    // 2. Icon Continuous Animation (Pulse and Rotate)
    _iconPulseController = AnimationController(
      duration: const Duration(seconds: 3), // Slower continuous animation
      vsync: this,
    );

    _iconRotationAnimation = Tween<double>(begin: 0.0, end: 2 * 3.14159).animate(
      CurvedAnimation(
        parent: _iconPulseController,
        curve: Curves.linear, // Constant speed rotation
      ),
    );

    _iconScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.05), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.05, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _iconPulseController,
        curve: Curves.easeInOut, // Smooth pulse
      ),
    );

    // 3. Title & Subtitle Slide Animations
    _textSlideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0), // Start from left
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textSlideController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCirc),
      ),
    );

    _subtitleSlideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start from right
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textSlideController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCirc),
      ),
    );

    // 4. Loader Animations
    _loaderAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _loaderFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loaderAnimationController,
        curve: Curves.easeIn,
      ),
    );

    _loaderSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5), // Start from slightly below
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _loaderAnimationController,
        curve: Curves.easeOutQuad,
      ),
    );

    // 5. Background Gradient Animation
    _backgroundGradientController = AnimationController(
      duration: const Duration(seconds: 10), // Slower, continuous
      vsync: this,
    )..repeat(reverse: true); // Loop the animation

    _backgroundBeginAlignment = Tween<AlignmentGeometry>(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).animate(
      CurvedAnimation(
        parent: _backgroundGradientController,
        curve: Curves.easeInOut,
      ),
    );

    _backgroundEndAlignment = Tween<AlignmentGeometry>(
      begin: Alignment.bottomRight,
      end: Alignment.topLeft,
    ).animate(
      CurvedAnimation(
        parent: _backgroundGradientController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _startAnimations() async {
    // Start main entry animations
    await _mainAnimationController.forward();

    // Start text animations after main logo settles a bit
    await Future.delayed(const Duration(milliseconds: 300));
    _textSlideController.forward();

    // Start continuous icon animation immediately after main entry
    _iconPulseController.repeat(reverse: true);

    // Start loader animations after text appears
    await Future.delayed(const Duration(milliseconds: 500));
    _loaderAnimationController.forward();
  }

  void _checkAuthStatus() {
    // Dispatch auth check event after all initial animations and a short pause for loader
    Future.delayed(const Duration(seconds: 4), () { // Adjust this duration based on total animation time
      if (mounted) { // Ensure the widget is still in the tree
        context.read<AuthBloc>().add(CheckAuthStatusEvent());
      }
    });
  }

  @override
  void dispose() {
    _mainAnimationController.dispose();
    _iconPulseController.dispose();
    _textSlideController.dispose();
    _loaderAnimationController.dispose();
    _backgroundGradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color accentColor = Theme.of(context).colorScheme.secondary; // Or define a custom accent color

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthenticatedState) {
          // Route based on user role
          if (state.user.role == 'admin') {
            AppNavigator.popAllAndPush(const AdminDashboardPage());
          } else if (state.user.role == 'user') {
            AppNavigator.popAllAndPush(const ModernHomePage());
          } else {
            // If role is neither admin nor user, redirect to login
            AppNavigator.popAllAndPush(const LoginPage());
          }
        } else if (state is UnauthenticatedState) {
          AppNavigator.popAllAndPush(const LoginPage());
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo and Title/Subtitle Block
              AnimatedBuilder(
                animation: _mainAnimationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          children: [
                            // App Logo Container & Icon
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDark,
                                borderRadius: BorderRadius.circular(70),
                              ),
                              child: AnimatedBuilder(
                                animation: _iconPulseController,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _iconScaleAnimation.value,
                                    child: Transform.rotate(
                                      angle: _iconRotationAnimation.value,
                                      child: Icon(
                                        Icons.explore,
                                        size: 70,
                                        color: AppColors.primaryOrange,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 32),
                            // App Title
                            AnimatedBuilder(
                              animation: _textSlideController,
                              builder: (context, child) {
                                return SlideTransition(
                                  position: _titleSlideAnimation,
                                  child: FadeTransition(
                                    opacity: _textSlideController,
                                    child: Text(
                                      'Indoor Navigation',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            // App Subtitle
                            AnimatedBuilder(
                              animation: _textSlideController,
                              builder: (context, child) {
                                return SlideTransition(
                                  position: _subtitleSlideAnimation,
                                  child: FadeTransition(
                                    opacity: _textSlideController,
                                    child: Text(
                                      'AR/VR Guidance System',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 80),
              // Loading Indicator & Text
              AnimatedBuilder(
                animation: _loaderAnimationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _loaderFadeAnimation,
                    child: SlideTransition(
                      position: _loaderSlideAnimation,
                      child: Column(
                        children: [
                          Text(
                            'Finding your way...',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 17,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}