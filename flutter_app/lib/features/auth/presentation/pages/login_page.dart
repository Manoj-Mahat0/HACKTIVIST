import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:indoor_navigation/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:indoor_navigation/core/navigation/app_navigator.dart';
import 'package:indoor_navigation/core/theme/app_theme.dart';
import 'package:indoor_navigation/core/widgets/animated_widgets.dart';
import 'package:indoor_navigation/core/utils/responsive.dart';
import 'package:indoor_navigation/features/auth/presentation/pages/signup_page.dart';
import 'package:indoor_navigation/features/auth/presentation/pages/otpless_login_page.dart';
import 'package:indoor_navigation/features/home/presentation/pages/home_page.dart';
import 'package:indoor_navigation/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:math' as math;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Animation Controllers
  late AnimationController _backgroundController;
  late AnimationController _logoController;
  late AnimationController _formController;
  late AnimationController _buttonController;
  
  // Animations
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<Offset> _formSlide;
  late Animation<double> _formFade;
  late Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
  }

  void _initAnimations() {
    // Background animation
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    // Logo animation
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoRotation = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    // Form animation
    _formController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeOutCubic),
    );
    _formFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _formController, curve: Curves.easeOut),
    );

    // Button animation
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _buttonScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.elasticOut),
    );
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _formController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _buttonController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _backgroundController.dispose();
    _logoController.dispose();
    _formController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
        LoginEvent(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthenticatedState) {
            if (state.user.role == 'admin' || state.user.isAdmin) {
              AppNavigator.popAllAndPush(const AdminDashboardPage());
            } else {
              AppNavigator.popAllAndPush(const HomePage());
            }
          } else if (state is AuthErrorState) {
            Fluttertoast.showToast(
              msg: state.message,
              toastLength: Toast.LENGTH_LONG,
              backgroundColor: AppColors.error,
              textColor: Colors.white,
            );
          }
        },
        child: Stack(
          children: [
            // Animated Background
            _buildAnimatedBackground(),
            
            // Content
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: Responsive.padding(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      SizedBox(height: Responsive.height(5)),
                      
                      // Animated Logo
                      _buildAnimatedLogo(),
                      
                      SizedBox(height: Responsive.height(3)),
                      
                      // Welcome Text
                      _buildWelcomeText(),
                      
                      SizedBox(height: Responsive.height(5)),
                      
                      // Login Form
                      _buildLoginForm(),
                      
                      SizedBox(height: Responsive.height(3)),
                      
                      // Login Button
                      _buildLoginButton(),
                      
                      SizedBox(height: Responsive.height(3)),
                      
                      // Sign Up Link
                      _buildSignUpLink(),
                      
                      SizedBox(height: Responsive.height(2)),
                      
                      // // Divider
                      // _buildDivider(),
                      
                      // SizedBox(height: Responsive.height(2)),
                      
                      // // OTPless Login Button
                      // _buildOTPlessButton(),
                      
                      SizedBox(height: Responsive.height(2)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Container(
      color: AppColors.backgroundDark,
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _logoController,
      builder: (context, child) {
        return Transform.scale(
          scale: _logoScale.value,
          child: Transform.rotate(
            angle: _logoRotation.value,
            child: Container(
              width: Responsive.value(mobile: 100.0, tablet: 120.0),
              height: Responsive.value(mobile: 100.0, tablet: 120.0),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.navigation_rounded,
                size: Responsive.value(mobile: 50.0, tablet: 60.0),
                color: AppColors.primaryOrange,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeText() {
    return SlideInAnimation(
      delay: const Duration(milliseconds: 600),
      child: Column(
        children: [
          Text(
            'Welcome Back!',
            style: TextStyle(
              fontSize: Responsive.fontSize(32),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to continue your journey',
            style: TextStyle(
              fontSize: Responsive.fontSize(16),
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return SlideTransition(
      position: _formSlide,
      child: FadeTransition(
        opacity: _formFade,
        child: Container(
          padding: Responsive.padding(all: 24),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Username Field
                _buildTextField(
                  controller: _usernameController,
                  label: 'Username',
                  icon: Icons.person_outline_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your username';
                    }
                    return null;
                  },
                ),
                SizedBox(height: Responsive.spacing(20)),
                
                // Password Field
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.white70,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        errorStyle: const TextStyle(color: AppColors.error),
      ),
      validator: validator,
    );
  }

  Widget _buildLoginButton() {
    return ScaleTransition(
      scale: _buttonScale,
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isLoading = state is AuthLoadingState;
          
          return AnimatedScaleButton(
            onTap: isLoading ? null : _login,
            child: Container(
              width: double.infinity,
              padding: Responsive.padding(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(16),
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSignUpLink() {
    return SlideInAnimation(
      delay: const Duration(milliseconds: 1000),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: Responsive.fontSize(14),
            ),
          ),
          TextButton(
            onPressed: () => AppNavigator.push(const SignupPage()),
            child: Text(
              'Sign Up',
              style: TextStyle(
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.bold,
                fontSize: Responsive.fontSize(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.5),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOTPlessButton() {
    return SlideInAnimation(
      delay: const Duration(milliseconds: 1200),
      child: AnimatedScaleButton(
        onTap: () => AppNavigator.push(
          const OTPlessLoginPage(),
        ),
        child: Container(
          width: double.infinity,
          padding: Responsive.padding(vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.phone_android_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Text(
                'Login with OTP',
                style: TextStyle(
                  fontSize: Responsive.fontSize(18),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
