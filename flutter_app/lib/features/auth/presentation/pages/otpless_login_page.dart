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

class OTPlessLoginPage extends StatefulWidget {
  const OTPlessLoginPage({super.key});

  @override
  State<OTPlessLoginPage> createState() => _OTPlessLoginPageState();
}

class _OTPlessLoginPageState extends State<OTPlessLoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _contactController = TextEditingController();
  final _otpController = TextEditingController();
  
  String _selectedChannel = 'PHONE'; // 'PHONE' or 'EMAIL'
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

  void _verifyOTP() {
    if (_otpController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please enter OTP',
        backgroundColor: AppColors.error,
        textColor: Colors.white,
      );
      return;
    }

    context.read<AuthBloc>().add(
      OTPlessLoginEvent(
        channel: _selectedChannel,
        otp: _otpController.text.trim(),
        phone: _selectedChannel == 'PHONE' ? _contactController.text.trim() : null,
        email: _selectedChannel == 'EMAIL' ? _contactController.text.trim() : null,
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
                          SizedBox(height: Responsive.height(3)),
                          _buildHeader(),
                          SizedBox(height: Responsive.height(4)),
                          if (!_isOTPSent) ...[
                            _buildChannelSelector(),
                            SizedBox(height: Responsive.height(3)),
                            _buildContactForm(),
                            SizedBox(height: Responsive.height(3)),
                            _buildSendOTPButton(),
                          ] else ...[
                            _buildOTPForm(),
                            SizedBox(height: Responsive.height(3)),
                            _buildVerifyButton(),
                            SizedBox(height: Responsive.height(2)),
                            _buildResendButton(),
                          ],
                          SizedBox(height: Responsive.height(4)),
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
                AppColors.primaryOrangeLight,
                AppColors.primaryOrange,
                AppColors.sunsetOrange,
                AppColors.primaryOrangeDark,
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
            width: 100,
            height: 100,
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
              Icons.phone_android_rounded,
              size: 50,
              color: AppColors.primaryOrange,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'OTPless Login',
            style: TextStyle(
              fontSize: Responsive.fontSize(28),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isOTPSent ? 'Enter the OTP sent to your ${_selectedChannel.toLowerCase()}' : 'Sign in with OTP',
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

  Widget _buildOTPForm() {
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
          onTap: isLoading ? null : _verifyOTP,
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
                        const Icon(Icons.verified_user_rounded, color: AppColors.primaryOrange),
                        const SizedBox(width: 8),
                        Text(
                          'Verify & Login',
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
