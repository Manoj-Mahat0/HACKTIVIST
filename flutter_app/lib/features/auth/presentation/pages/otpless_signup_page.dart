import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:indoor_navigation/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:indoor_navigation/core/navigation/app_navigator.dart';
import 'package:indoor_navigation/core/theme/app_theme.dart';
import 'package:indoor_navigation/core/widgets/animated_widgets.dart';
import 'package:indoor_navigation/core/utils/responsive.dart';
import 'package:indoor_navigation/features/home/presentation/pages/home_page.dart';
import 'package:indoor_navigation/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:math' as math;

class OTPlessSignupPage extends StatefulWidget {
  const OTPlessSignupPage({super.key});

  @override
  State<OTPlessSignupPage> createState() => _OTPlessSignupPageState();
}

class _OTPlessSignupPageState extends State<OTPlessSignupPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _contactController = TextEditingController();
  final _usernameController = TextEditingController();
  final _otpController = TextEditingController();
  
  String _selectedChannel = 'PHONE';
  String _selectedRole = 'user';
  bool _isOTPSent = false;
  String? _requestId;

  late AnimationController _backgroundController;
  late AnimationController _contentController;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _contentController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _contactController.dispose();
    _usernameController.dispose();
    _otpController.dispose();
    _backgroundController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _sendOTP() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
        SendOTPEvent(
          channel: _selectedChannel,
          phone: _selectedChannel == 'PHONE' ? _contactController.text.trim() : null,
          email: _selectedChannel == 'EMAIL' ? _contactController.text.trim() : null,
        ),
      );
    }
  }

  void _verifyAndSignup() {
    if (_usernameController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please enter a username',
        backgroundColor: AppColors.error,
        textColor: Colors.white,
      );
      return;
    }

    if (_otpController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please enter OTP',
        backgroundColor: AppColors.error,
        textColor: Colors.white,
      );
      return;
    }

    context.read<AuthBloc>().add(
      OTPlessSignupEvent(
        channel: _selectedChannel,
        otp: _otpController.text.trim(),
        username: _usernameController.text.trim(),
        phone: _selectedChannel == 'PHONE' ? _contactController.text.trim() : null,
        email: _selectedChannel == 'EMAIL' ? _contactController.text.trim() : null,
        role: _selectedRole,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is OTPSentState) {
            setState(() {
              _isOTPSent = true;
              _requestId = state.requestId;
            });
            Fluttertoast.showToast(
              msg: state.message,
              backgroundColor: AppColors.success,
              textColor: Colors.white,
            );
          } else if (state is AuthenticatedState) {
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
            _buildAnimatedBackground(),
            SafeArea(
              child: Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: Responsive.padding(horizontal: 24),
                      child: Column(
                        children: [
                          SizedBox(height: Responsive.height(2)),
                          _buildHeader(),
                          SizedBox(height: Responsive.height(3)),
                          if (!_isOTPSent) ...[
                            _buildChannelSelector(),
                            SizedBox(height: Responsive.height(2)),
                            _buildContactForm(),
                            SizedBox(height: Responsive.height(2)),
                            _buildSendOTPButton(),
                          ] else ...[
                            _buildSignupForm(),
                            SizedBox(height: Responsive.height(2)),
                            _buildVerifyButton(),
                            SizedBox(height: Responsive.height(2)),
                            _buildResendButton(),
                          ],
                          SizedBox(height: Responsive.height(3)),
                        ],
                      ),
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

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(
                math.cos(_backgroundController.value * 2 * math.pi),
                math.sin(_backgroundController.value * 2 * math.pi),
              ),
              end: Alignment(
                -math.cos(_backgroundController.value * 2 * math.pi),
                -math.sin(_backgroundController.value * 2 * math.pi),
              ),
              colors: const [
                AppColors.sunsetOrange,
                AppColors.primaryOrange,
                AppColors.primaryOrangeLight,
                AppColors.warmOrange,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          AnimatedScaleButton(
            onTap: () => AppNavigator.pop(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SlideInAnimation(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_add_rounded,
              size: 40,
              color: AppColors.primaryOrange,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'OTPless Signup',
            style: TextStyle(
              fontSize: Responsive.fontSize(28),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isOTPSent ? 'Enter OTP and create your account' : 'Create account with OTP',
            style: TextStyle(
              fontSize: Responsive.fontSize(16),
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChannelSelector() {
    return GlassContainer(
      blur: 20,
      opacity: 0.25,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: AnimatedScaleButton(
              onTap: () => setState(() => _selectedChannel = 'PHONE'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedChannel == 'PHONE' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_android_rounded,
                      color: _selectedChannel == 'PHONE' ? AppColors.primaryOrange : Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Phone',
                      style: TextStyle(
                        color: _selectedChannel == 'PHONE' ? AppColors.primaryOrange : Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedScaleButton(
              onTap: () => setState(() => _selectedChannel = 'EMAIL'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedChannel == 'EMAIL' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.email_outlined,
                      color: _selectedChannel == 'EMAIL' ? AppColors.primaryOrange : Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Email',
                      style: TextStyle(
                        color: _selectedChannel == 'EMAIL' ? AppColors.primaryOrange : Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactForm() {
    return GlassContainer(
      blur: 20,
      opacity: 0.25,
      padding: Responsive.padding(all: 24),
      child: Form(
        key: _formKey,
        child: TextFormField(
          controller: _contactController,
          keyboardType: _selectedChannel == 'PHONE' ? TextInputType.phone : TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: _selectedChannel == 'PHONE' ? 'Phone Number' : 'Email Address',
            hintText: _selectedChannel == 'PHONE' ? '+919876543210' : 'user@example.com',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
            prefixIcon: Icon(
              _selectedChannel == 'PHONE' ? Icons.phone : Icons.email,
              color: Colors.white70,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white, width: 2),
            ),
            errorStyle: const TextStyle(color: Colors.white),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your ${_selectedChannel.toLowerCase()}';
            }
            if (_selectedChannel == 'EMAIL' && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email';
            }
            if (_selectedChannel == 'PHONE' && !value.startsWith('+')) {
              return 'Phone number must include country code (e.g., +91)';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildSignupForm() {
    return GlassContainer(
      blur: 20,
      opacity: 0.25,
      padding: Responsive.padding(all: 24),
      child: Column(
        children: [
          Text(
            'Sent to: ${_contactController.text}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _usernameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Username',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
              prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              labelText: 'Enter OTP',
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
              counterText: '',
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildRoleSelector(),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedScaleButton(
              onTap: () => setState(() => _selectedRole = 'user'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedRole == 'user' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      color: _selectedRole == 'user' ? AppColors.primaryOrange : Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'User',
                      style: TextStyle(
                        color: _selectedRole == 'user' ? AppColors.primaryOrange : Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedScaleButton(
              onTap: () => setState(() => _selectedRole = 'admin'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedRole == 'admin' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      color: _selectedRole == 'admin' ? AppColors.primaryOrange : Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Admin',
                      style: TextStyle(
                        color: _selectedRole == 'admin' ? AppColors.primaryOrange : Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendOTPButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoadingState;
        
        return AnimatedScaleButton(
          onTap: isLoading ? null : _sendOTP,
          child: Container(
            width: double.infinity,
            padding: Responsive.padding(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, color: AppColors.primaryOrange),
                        const SizedBox(width: 8),
                        Text(
                          'Send OTP',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(18),
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerifyButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoadingState;
        
        return AnimatedScaleButton(
          onTap: isLoading ? null : _verifyAndSignup,
          child: Container(
            width: double.infinity,
            padding: Responsive.padding(vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.primaryOrange),
                        const SizedBox(width: 8),
                        Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: Responsive.fontSize(18),
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResendButton() {
    return AnimatedScaleButton(
      onTap: () {
        setState(() {
          _isOTPSent = false;
          _otpController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Resend OTP',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: Responsive.fontSize(14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
