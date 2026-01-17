# OTPless Authentication Integration

## Overview

The authentication system now supports **dual authentication methods**:
1. **Traditional Username/Password** - Existing authentication system (unchanged)
2. **OTPless Phone/Email** - New passwordless authentication via OTP

Both systems work side-by-side without conflicts, allowing users to choose their preferred authentication method.

## OTPless Configuration

### Credentials
- **App ID**: `1ZL5IUR4FITTIV93TX49`
- **Client ID**: `PPLZ8PLRP17J4FALF78B8G6MG90A95LS`
- **Client Secret**: `x7ass763h83f36uo5t2uyx22kquoi2r4`

### API Base URL
- `https://api.otpless.app/auth`

## Authentication Endpoints

### OTPless Authentication

#### 1. Send OTP
**Endpoint**: `POST /auth/otpless/send-otp`

**Request Body**:
```json
{
  "channel": "PHONE",  // or "EMAIL"
  "phone": "+919876543210",  // Required if channel is PHONE
  "email": "user@example.com"  // Required if channel is EMAIL
}
```

**Response**:
```json
{
  "success": true,
  "message": "OTP sent successfully",
  "request_id": "order_id_from_otpless"
}
```

#### 2. Verify OTP & Login (Existing User)
**Endpoint**: `POST /auth/otpless/verify-login`

**Request Body**:
```json
{
  "channel": "PHONE",
  "phone": "+919876543210",
  "otp": "123456"
}
```

**Response**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "id": "user_id",
    "username": "john_doe",
    "email": "phone:+919876543210",
    "is_admin": false,
    "role": "user",
    "phone": "+919876543210",
    "auth_method": "otpless",
    "created_at": "2024-01-01T00:00:00"
  }
}
```

#### 3. Verify OTP & Register (New User)
**Endpoint**: `POST /auth/otpless/verify-register`

**Request Body**:
```json
{
  "channel": "PHONE",
  "phone": "+919876543210",
  "otp": "123456",
  "username": "john_doe",
  "role": "user"  // Optional: "user" or "admin"
}
```

**Response**: Same as verify-login

### Traditional Authentication (Unchanged)

#### 1. Register with Username/Password
**Endpoint**: `POST /auth/register`

**Request Body**:
```json
{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "securepassword123",
  "role": "user"
}
```

#### 2. Login with Username/Password
**Endpoint**: `POST /auth/login`

**Request Body**:
```json
{
  "username": "john_doe",
  "password": "securepassword123"
}
```

#### 3. OAuth2 Token Endpoint
**Endpoint**: `POST /auth/token`

**Form Data**:
- `username`: john_doe
- `password`: securepassword123

## User Model Changes

### New Fields Added
- `phone` (Optional[str]): Phone number for OTPless users
- `auth_method` (str): Either "password" or "otpless"

### Email Field Behavior
- **Traditional users**: Stores actual email address
- **OTPless phone users**: Stores `phone:+919876543210` format
- **OTPless email users**: Stores actual email address

## Authentication Flow

### OTPless Registration Flow
1. User enters phone/email
2. Frontend calls `/auth/otpless/send-otp`
3. User receives OTP via SMS/Email
4. User enters OTP and username
5. Frontend calls `/auth/otpless/verify-register`
6. User is registered and logged in automatically
7. JWT token returned for subsequent requests

### OTPless Login Flow
1. User enters phone/email
2. Frontend calls `/auth/otpless/send-otp`
3. User receives OTP via SMS/Email
4. User enters OTP
5. Frontend calls `/auth/otpless/verify-login`
6. User is logged in
7. JWT token returned for subsequent requests

### Traditional Login Flow (Unchanged)
1. User enters username and password
2. Frontend calls `/auth/login`
3. Credentials verified against database
4. JWT token returned for subsequent requests

## Security Considerations

1. **OTPless users don't have passwords**: The `hashed_password` field contains a random UUID hash that cannot be used for authentication
2. **Phone numbers are unique**: Stored with `phone:` prefix in email field to ensure uniqueness
3. **JWT tokens are identical**: Both authentication methods generate the same JWT token format
4. **Existing endpoints unchanged**: All existing profile, token, and user management endpoints work with both auth methods

## Error Handling

### Common Error Responses

**400 Bad Request**:
```json
{
  "detail": "Channel must be 'PHONE' or 'EMAIL'"
}
```

**401 Unauthorized**:
```json
{
  "detail": "Invalid OTP"
}
```

**404 Not Found**:
```json
{
  "detail": "User not found. Please register first."
}
```

## Testing

### Test OTPless Registration
```bash
# 1. Send OTP
curl -X POST http://localhost:8000/auth/otpless/send-otp \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "PHONE",
    "phone": "+919876543210"
  }'

# 2. Verify and Register
curl -X POST http://localhost:8000/auth/otpless/verify-register \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "PHONE",
    "phone": "+919876543210",
    "otp": "123456",
    "username": "test_user"
  }'
```

### Test OTPless Login
```bash
# 1. Send OTP
curl -X POST http://localhost:8000/auth/otpless/send-otp \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "PHONE",
    "phone": "+919876543210"
  }'

# 2. Verify and Login
curl -X POST http://localhost:8000/auth/otpless/verify-login \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "PHONE",
    "phone": "+919876543210",
    "otp": "123456"
  }'
```

## Dependencies

Added to `requirements.txt`:
- `httpx==0.25.2` - For making async HTTP requests to OTPless API

## Migration Notes

### Existing Users
- All existing users continue to work with username/password authentication
- `auth_method` defaults to "password" for existing users
- No migration required for existing user data

### New Users
- Can choose either authentication method during registration
- OTPless users have `auth_method` set to "otpless"
- Traditional users have `auth_method` set to "password"

## Frontend Integration Guide

### React/JavaScript Example

```javascript
// Send OTP
const sendOTP = async (channel, contact) => {
  const response = await fetch('/auth/otpless/send-otp', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      channel: channel, // "PHONE" or "EMAIL"
      phone: channel === "PHONE" ? contact : null,
      email: channel === "EMAIL" ? contact : null
    })
  });
  return await response.json();
};

// Verify OTP and Login
const verifyAndLogin = async (channel, contact, otp) => {
  const response = await fetch('/auth/otpless/verify-login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      channel: channel,
      phone: channel === "PHONE" ? contact : null,
      email: channel === "EMAIL" ? contact : null,
      otp: otp
    })
  });
  const data = await response.json();
  // Store token
  localStorage.setItem('token', data.access_token);
  return data;
};

// Verify OTP and Register
const verifyAndRegister = async (channel, contact, otp, username) => {
  const response = await fetch('/auth/otpless/verify-register', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      channel: channel,
      phone: channel === "PHONE" ? contact : null,
      email: channel === "EMAIL" ? contact : null,
      otp: otp,
      username: username,
      role: "user"
    })
  });
  const data = await response.json();
  // Store token
  localStorage.setItem('token', data.access_token);
  return data;
};
```

### Flutter/Dart Example

```dart
// Send OTP
Future<Map<String, dynamic>> sendOTP(String channel, String contact) async {
  final response = await http.post(
    Uri.parse('$baseUrl/auth/otpless/send-otp'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'channel': channel,
      if (channel == 'PHONE') 'phone': contact,
      if (channel == 'EMAIL') 'email': contact,
    }),
  );
  return jsonDecode(response.body);
}

// Verify OTP and Login
Future<Map<String, dynamic>> verifyAndLogin(
  String channel, String contact, String otp
) async {
  final response = await http.post(
    Uri.parse('$baseUrl/auth/otpless/verify-login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'channel': channel,
      if (channel == 'PHONE') 'phone': contact,
      if (channel == 'EMAIL') 'email': contact,
      'otp': otp,
    }),
  );
  final data = jsonDecode(response.body);
  // Store token
  await storage.write(key: 'token', value: data['access_token']);
  return data;
}
```

## Troubleshooting

### OTP Not Received
- Verify phone number format includes country code (e.g., +91 for India)
- Check OTPless dashboard for delivery status
- Ensure OTPless credentials are correct

### Invalid OTP Error
- OTP may have expired (typically 5-10 minutes validity)
- Request a new OTP
- Verify the OTP code is entered correctly

### User Already Exists
- Phone/email is already registered
- Use `/auth/otpless/verify-login` instead of verify-register
- Or use traditional login if registered with password

## Support

For OTPless-specific issues:
- Documentation: https://otpless.com/docs
- Dashboard: https://otpless.com/dashboard
- Support: support@otpless.com
