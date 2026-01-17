# Flutter OTPless Integration - Complete Guide

## Overview

The Flutter mobile app now supports **dual authentication methods**:
1. **Traditional Username/Password** - Existing authentication (unchanged)
2. **OTPless Phone/Email** - New passwordless authentication via OTP

## Files Modified

### 1. Domain Layer

#### `lib/features/auth/domain/entities/user.dart`
**Added Fields**:
```dart
final String? phone;  // Phone number for OTPless
final String authMethod;  // "password" or "otpless"
```

#### `lib/features/auth/domain/repositories/auth_repository.dart`
**Added Methods**:
```dart
Future<Map<String, dynamic>> sendOTP({required String channel, String? phone, String? email});
Future<String> otplessLogin({required String channel, required String otp, String? phone, String? email});
Future<User> otplessSignup({required String channel, required String otp, required String username, String? phone, String? email, String role = 'user'});
```

### 2. Data Layer

#### `lib/features/auth/data/models/user_model.dart`
**Updated**:
- Added `phone` and `authMethod` fields
- Updated `fromJson` and `toJson` methods

#### `lib/features/auth/data/repositories/auth_repository_impl.dart`
**Implemented**:
- `sendOTP()` - Sends OTP via backend
- `otplessLogin()` - Verifies OTP and logs in
- `otplessSignup()` - Verifies OTP and registers user

### 3. Network Layer

#### `lib/core/network/api_client.dart`
**Added Endpoints**:
```dart
Future<Response> sendOTP({required String channel, String? phone, String? email})
Future<Response> verifyOTPLogin({required String channel, required String otp, String? phone, String? email})
Future<Response> verifyOTPRegister({required String channel, required String otp, required String username, String? phone, String? email, String role = 'user'})
```

### 4. Presentation Layer

#### `lib/features/auth/presentation/bloc/auth_bloc.dart`
**Added Events**:
- `SendOTPEvent` - Triggers OTP sending
- `OTPlessLoginEvent` - Triggers OTPless login
- `OTPlessSignupEvent` - Triggers OTPless signup

**Added States**:
- `OTPSentState` - Indicates OTP was sent successfully

**Added Handlers**:
- `_onSendOTP()` - Handles OTP sending
- `_onOTPlessLogin()` - Handles OTPless login
- `_onOTPlessSignup()` - Handles OTPless signup

#### `lib/features/auth/presentation/pages/login_page.dart`
**Modified**:
- Added "Login with OTP" button
- Added divider between traditional and OTPless login
- Added navigation to OTPlessLoginPage

#### `lib/features/auth/presentation/pages/signup_page.dart`
**Modified**:
- Added "Signup with OTP" button
- Added divider between traditional and OTPless signup
- Added navigation to OTPlessSignupPage

## New Files Created

### 1. `lib/features/auth/presentation/pages/otpless_login_page.dart`
**Features**:
- Channel selector (Phone/Email)
- Contact input field
- OTP input field
- Send OTP button
- Verify & Login button
- Resend OTP functionality
- Beautiful animated UI matching app theme

### 2. `lib/features/auth/presentation/pages/otpless_signup_page.dart`
**Features**:
- Channel selector (Phone/Email)
- Contact input field
- Username input field
- OTP input field
- Role selector (User/Admin)
- Send OTP button
- Create Account button
- Resend OTP functionality
- Beautiful animated UI matching app theme

## User Flow

### OTPless Login Flow
```
1. User opens app → Login Page
2. User taps "Login with OTP"
3. User selects Phone or Email
4. User enters phone/email
5. User taps "Send OTP"
6. Backend sends OTP via OTPless API
7. User receives OTP (SMS/Email)
8. User enters OTP
9. User taps "Verify & Login"
10. Backend verifies OTP with OTPless
11. User is logged in
12. Navigate to Home/Admin Dashboard
```

### OTPless Signup Flow
```
1. User opens app → Signup Page
2. User taps "Signup with OTP"
3. User selects Phone or Email
4. User enters phone/email
5. User taps "Send OTP"
6. Backend sends OTP via OTPless API
7. User receives OTP (SMS/Email)
8. User enters username and OTP
9. User selects role (User/Admin)
10. User taps "Create Account"
11. Backend verifies OTP and creates account
12. User is logged in
13. Navigate to Home/Admin Dashboard
```

## UI Screenshots Description

### Login Page
- Traditional login form at top
- "OR" divider
- "Login with OTP" button with phone icon
- Gradient animated background
- Glass morphism design

### OTPless Login Page
- Phone/Email channel selector
- Contact input field with validation
- OTP input field (6 digits, centered)
- Send OTP / Verify buttons
- Resend OTP option
- Back button to return to traditional login

### OTPless Signup Page
- Phone/Email channel selector
- Contact input field
- Username input field
- OTP input field
- User/Admin role selector
- Send OTP / Create Account buttons
- Resend OTP option

## API Integration

### Send OTP
```dart
context.read<AuthBloc>().add(
  SendOTPEvent(
    channel: 'PHONE', // or 'EMAIL'
    phone: '+919876543210',
    email: null,
  ),
);
```

### OTPless Login
```dart
context.read<AuthBloc>().add(
  OTPlessLoginEvent(
    channel: 'PHONE',
    otp: '123456',
    phone: '+919876543210',
    email: null,
  ),
);
```

### OTPless Signup
```dart
context.read<AuthBloc>().add(
  OTPlessSignupEvent(
    channel: 'PHONE',
    otp: '123456',
    username: 'john_doe',
    phone: '+919876543210',
    email: null,
    role: 'user',
  ),
);
```

## State Management

### Listening to States
```dart
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is OTPSentState) {
      // OTP sent successfully
      // Show OTP input field
    } else if (state is AuthenticatedState) {
      // User authenticated
      // Navigate to home
    } else if (state is AuthErrorState) {
      // Show error message
    } else if (state is AuthLoadingState) {
      // Show loading indicator
    }
  },
  child: YourWidget(),
)
```

## Error Handling

### Common Errors
1. **Invalid phone/email format**
   - Validation happens before sending OTP
   - Phone must include country code (+91, +1, etc.)
   - Email must be valid format

2. **OTP not received**
   - User can tap "Resend OTP"
   - Check backend logs for OTPless API response

3. **Invalid OTP**
   - Show error message from backend
   - Allow user to re-enter OTP

4. **User not found (Login)**
   - Suggest user to signup instead
   - Provide link to OTPless signup

5. **User already exists (Signup)**
   - Suggest user to login instead
   - Provide link to OTPless login

## Testing

### Test OTPless Login
1. Run the app
2. Tap "Login with OTP"
3. Select "Phone"
4. Enter: `+919876543210`
5. Tap "Send OTP"
6. Check phone for OTP
7. Enter OTP
8. Tap "Verify & Login"
9. Should navigate to home

### Test OTPless Signup
1. Run the app
2. Tap "Sign Up"
3. Tap "Signup with OTP"
4. Select "Phone"
5. Enter: `+919876543210`
6. Tap "Send OTP"
7. Check phone for OTP
8. Enter username and OTP
9. Select role
10. Tap "Create Account"
11. Should navigate to home

## Validation Rules

### Phone Number
- Must start with `+` (country code)
- Example: `+919876543210`
- Validated before sending OTP

### Email
- Must be valid email format
- Example: `user@example.com`
- Validated before sending OTP

### Username (Signup only)
- Minimum 3 characters
- Required for signup
- Checked for uniqueness on backend

### OTP
- 6 digits
- Numeric only
- Expires after 5-10 minutes (OTPless default)

## Security Features

1. **OTP Verification**: All OTP verification happens on backend via OTPless API
2. **Token Storage**: JWT tokens stored securely using TokenStorage
3. **Same Token Format**: OTPless and traditional auth use same JWT format
4. **No Password Storage**: OTPless users don't have passwords
5. **Unique Constraints**: Phone/email uniqueness enforced

## Backward Compatibility

✅ **100% Backward Compatible**:
- All existing users can continue using username/password
- No breaking changes to existing authentication
- Traditional login/signup pages unchanged
- OTPless is an additional option, not a replacement

## Dependencies

No new dependencies required! All existing dependencies support OTPless integration:
- `flutter_bloc` - State management
- `dio` - HTTP client
- `equatable` - Value equality
- `fluttertoast` - Toast messages

## Configuration

### Backend URL
Located in `lib/core/network/api_client.dart`:
```dart
static const String baseUrl = 'https://be.google.knocknockindia.com';
```

### OTPless Endpoints
- `/auth/otpless/send-otp` - Send OTP
- `/auth/otpless/verify-login` - Verify and login
- `/auth/otpless/verify-register` - Verify and register

## Troubleshooting

### Issue: OTP not sent
**Solution**:
- Check internet connection
- Verify phone number format includes country code
- Check backend logs for OTPless API errors

### Issue: Invalid OTP error
**Solution**:
- OTP may have expired
- Request new OTP
- Verify OTP code is entered correctly

### Issue: User already exists
**Solution**:
- Use OTPless login instead of signup
- Or use traditional login if registered with password

### Issue: Navigation not working
**Solution**:
- Ensure `AppNavigator` is properly initialized
- Check if user role is correctly set
- Verify navigation routes are registered

## Best Practices

1. **Phone Number Format**: Always include country code
2. **Error Messages**: Show clear, user-friendly error messages
3. **Loading States**: Show loading indicators during API calls
4. **OTP Expiry**: Inform users about OTP expiry time
5. **Resend Cooldown**: Consider adding cooldown for resend OTP
6. **Input Validation**: Validate inputs before API calls
7. **Success Feedback**: Show success messages after OTP sent

## Future Enhancements

Potential improvements:
1. Add OTP resend cooldown timer
2. Implement biometric authentication
3. Add "Remember Me" functionality
4. Support WhatsApp OTP channel
5. Add OTP auto-read functionality (Android)
6. Implement account linking (merge accounts)
7. Add social login options

## Support

For issues or questions:
- Check backend logs for API errors
- Verify OTPless credentials in backend
- Test with different phone numbers/emails
- Review `OTPLESS_INTEGRATION.md` for backend details

## Summary

The Flutter app now provides a seamless OTPless authentication experience:
- ✅ Beautiful, animated UI
- ✅ Phone and Email support
- ✅ Role-based access (User/Admin)
- ✅ Complete error handling
- ✅ Backward compatible
- ✅ Production ready

Users can choose their preferred authentication method while enjoying a consistent, high-quality user experience across both traditional and OTPless authentication flows.
