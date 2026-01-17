import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:indoor_navigation/features/auth/domain/entities/user.dart';
import 'package:indoor_navigation/features/auth/domain/repositories/auth_repository.dart';
import 'package:indoor_navigation/features/auth/domain/usecases/login_usecase.dart';
import 'package:indoor_navigation/features/auth/domain/usecases/signup_usecase.dart';
import 'package:indoor_navigation/features/auth/domain/usecases/traditional_login_usecase.dart';
import 'package:indoor_navigation/features/auth/domain/usecases/traditional_signup_usecase.dart';
import 'package:indoor_navigation/features/auth/domain/usecases/logout_usecase.dart';
import 'package:indoor_navigation/features/auth/domain/usecases/get_current_user_usecase.dart';

// Events
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class CheckAuthStatusEvent extends AuthEvent {}

// OTPless Events
class SendOTPEvent extends AuthEvent {
  final String channel; // "PHONE", "EMAIL", or "WHATSAPP"
  final String? phone;
  final String? email;

  SendOTPEvent({
    required this.channel,
    this.phone,
    this.email,
  });

  @override
  List<Object?> get props => [channel, phone, email];
}

class OTPlessLoginEvent extends AuthEvent {
  final String channel;
  final String otp;
  final String? phone;
  final String? email;

  OTPlessLoginEvent({
    required this.channel,
    required this.otp,
    this.phone,
    this.email,
  });

  @override
  List<Object?> get props => [channel, otp, phone, email];
}

class OTPlessSignupEvent extends AuthEvent {
  final String channel;
  final String otp;
  final String username;
  final String? phone;
  final String? email;
  final String role;

  OTPlessSignupEvent({
    required this.channel,
    required this.otp,
    required this.username,
    this.phone,
    this.email,
    this.role = 'user',
  });

  @override
  List<Object?> get props => [channel, otp, username, phone, email, role];
}

// Traditional Auth Events (for backward compatibility)
class LoginEvent extends AuthEvent {
  final String username;
  final String password;

  LoginEvent({
    required this.username,
    required this.password,
  });

  @override
  List<Object?> get props => [username, password];
}

class SignupEvent extends AuthEvent {
  final String username;
  final String email;
  final String password;
  final String role;

  SignupEvent({
    required this.username,
    required this.email,
    required this.password,
    this.role = 'user',
  });

  @override
  List<Object?> get props => [username, email, password, role];
}

class LogoutEvent extends AuthEvent {}

class UpdateProfileEvent extends AuthEvent {
  final String? username;
  final String? email;
  final String? currentPassword;
  final String? newPassword;

  UpdateProfileEvent({
    this.username,
    this.email,
    this.currentPassword,
    this.newPassword,
  });

  @override
  List<Object?> get props => [username, email, currentPassword, newPassword];
}

class UploadProfilePictureEvent extends AuthEvent {
  final String filePath;

  UploadProfilePictureEvent({required this.filePath});

  @override
  List<Object?> get props => [filePath];
}

class DeleteProfilePictureEvent extends AuthEvent {}

// OTPless States
class OTPSentState extends AuthState {
  final String message;
  final String? requestId;

  OTPSentState({required this.message, this.requestId});

  @override
  List<Object?> get props => [message, requestId];
}

// States
abstract class AuthState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthInitialState extends AuthState {}

class AuthLoadingState extends AuthState {}

class AuthenticatedState extends AuthState {
  final User user;

  AuthenticatedState({required this.user});

  @override
  List<Object?> get props => [user];
}

class UnauthenticatedState extends AuthState {}

class AuthErrorState extends AuthState {
  final String message;

  AuthErrorState({required this.message});

  @override
  List<Object?> get props => [message];
}

class ProfileUpdatedState extends AuthState {
  final User user;

  ProfileUpdatedState({required this.user});

  @override
  List<Object?> get props => [user];
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final SignupUseCase signupUseCase;
  final TraditionalLoginUseCase traditionalLoginUseCase;
  final TraditionalSignupUseCase traditionalSignupUseCase;
  final LogoutUseCase logoutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final AuthRepository authRepository;

  AuthBloc({
    required this.loginUseCase,
    required this.signupUseCase,
    required this.traditionalLoginUseCase,
    required this.traditionalSignupUseCase,
    required this.logoutUseCase,
    required this.getCurrentUserUseCase,
    required this.authRepository,
  }) : super(AuthInitialState()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<LoginEvent>(_onTraditionalLogin);
    on<SignupEvent>(_onTraditionalSignup);
    on<SendOTPEvent>(_onSendOTP);
    on<OTPlessLoginEvent>(_onOTPlessLogin);
    on<OTPlessSignupEvent>(_onOTPlessSignup);
    on<LogoutEvent>(_onLogout);
    on<UpdateProfileEvent>(_onUpdateProfile);
    on<UploadProfilePictureEvent>(_onUploadProfilePicture);
    on<DeleteProfilePictureEvent>(_onDeleteProfilePicture);
  }

  Future<void> _onTraditionalLogin(
    LoginEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    try {
      final user = await traditionalLoginUseCase(
        username: event.username,
        password: event.password,
      );
      emit(AuthenticatedState(user: user));
    } catch (e) {
      emit(AuthErrorState(message: e.toString()));
    }
  }

  Future<void> _onTraditionalSignup(
    SignupEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    try {
      final user = await traditionalSignupUseCase(
        username: event.username,
        email: event.email,
        password: event.password,
        role: event.role,
      );
      emit(AuthenticatedState(user: user));
    } catch (e) {
      emit(AuthErrorState(message: e.toString()));
    }
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    try {
      final user = await getCurrentUserUseCase();
      emit(AuthenticatedState(user: user));
    } catch (e) {
      emit(UnauthenticatedState());
    }
  }

  Future<void> _onSendOTP(
    SendOTPEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    try {
      final result = await authRepository.sendOTP(
        channel: event.channel,
        phone: event.phone,
        email: event.email,
      );
      emit(OTPSentState(
        message: result['message'] ?? 'OTP sent successfully',
        requestId: result['request_id'],
      ));
    } catch (e) {
      emit(AuthErrorState(message: e.toString()));
    }
  }

  Future<void> _onOTPlessLogin(
    OTPlessLoginEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    try {
      await authRepository.otplessLogin(
        channel: event.channel,
        otp: event.otp,
        phone: event.phone,
        email: event.email,
      );
      final user = await getCurrentUserUseCase();
      emit(AuthenticatedState(user: user));
    } catch (e) {
      emit(AuthErrorState(message: e.toString()));
    }
  }

  Future<void> _onOTPlessSignup(
    OTPlessSignupEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    try {
      final user = await authRepository.otplessSignup(
        channel: event.channel,
        otp: event.otp,
        username: event.username,
        phone: event.phone,
        email: event.email,
        role: event.role,
      );
      emit(AuthenticatedState(user: user));
    } catch (e) {
      emit(AuthErrorState(message: e.toString()));
    }
  }

  Future<void> _onLogout(
    LogoutEvent event,
    Emitter<AuthState> emit,
  ) async {
    await logoutUseCase();
    emit(UnauthenticatedState());
  }

  Future<void> _onUpdateProfile(
    UpdateProfileEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    try {
      final user = await authRepository.updateProfile(
        username: event.username,
        email: event.email,
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
      );
      emit(ProfileUpdatedState(user: user));
      emit(AuthenticatedState(user: user));
    } catch (e) {
      emit(AuthErrorState(message: e.toString()));
    }
  }

  Future<void> _onUploadProfilePicture(
    UploadProfilePictureEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    try {
      final user = await authRepository.uploadProfilePicture(event.filePath);
      emit(ProfileUpdatedState(user: user));
      emit(AuthenticatedState(user: user));
    } catch (e) {
      emit(AuthErrorState(message: e.toString()));
    }
  }

  Future<void> _onDeleteProfilePicture(
    DeleteProfilePictureEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoadingState());
    try {
      final user = await authRepository.deleteProfilePicture();
      emit(ProfileUpdatedState(user: user));
      emit(AuthenticatedState(user: user));
    } catch (e) {
      emit(AuthErrorState(message: e.toString()));
    }
  }
}