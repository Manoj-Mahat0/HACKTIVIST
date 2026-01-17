# OTPless-Only Authentication System

## 🎯 Overview

The authentication system has been **completely replaced** with OTPless. Traditional username/password authentication has been removed. The system now supports:

1. **Phone OTP** - SMS-based authentication
2. **Email OTP** - Email-based authentication  
3. **WhatsApp OTP** - WhatsApp-based authentication
4. **Google Login** - Social login via Google
5. **Facebook Login** - Social login via Facebook

All authentication is handled through OTPless API.

## 🔑 OTPless Credentials

```
App ID: 1ZL5IUR4FITTIV93TX49
Client ID: PPLZ8PLRP17J4FALF78B8G6MG90A95LS
Client Secret: x7ass763h83f36uo5t2uyx22kquoi2r4
```

## 📡 API Endpoints

### 1. Send OTP
**Endpoint**: `POST /auth/send-otp`

Send OTP via Phone, Email, or WhatsApp.

**Request**:
```json
{
  "channel": "PHONE",  // or "EMAIL" or "WHATSAPP"
  "phone": "+919876543210",  // Required for PHONE/WHATSAPP
  "email": "user@example.com"  // Required for EMAIL
}
```

**Response**:
```json
{
  "success": true,
  "message": "OTP sent successfully",
  "request_id": "order_xyz123"
}
```

### 2. Verify OTP (Login/Register)
**Endpoint**: `POST /auth/verify-otp`

Verify OTP and automatically login or register user.

**For Existing User (Login)**:
```json
{
  "channel": "PHONE",
  "phone": "+919876543210",
  "otp": "123456"
}
```

**For New User (Register)**:
```json
{
  "channel": "PHONE",
  "phone": "+919876543210",
  "otp": "123456",
  "username": "john_doe",  // Required for new users
  "role": "user"  // Optional: "user" or "admin"
}
```

**Response**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "id": "...",
    "username": "john_doe",
    "email": "phone:+919876543210",
    "phone": "+919876543210",
    "is_admin": false,
    "role": "user",
    "auth_method": "otpless",
    "created_at": "2024-01-01T00:00:00"
  }
}
```

### 3. Social Login (Google/Facebook)
**Endpoint**: `POST /auth/social-login`

Login or register using Google/Facebook via OTPless.

**Request**:
```json
{
  "token": "otpless_token_from_sdk",  // Token from OTPless SDK after social login
  "username": "john_doe",  // Optional: auto-generated if not provided
  "role": "user"  // Optional: "user" or "admin"
}
```

**Response**: Same as verify-otp

### 4. Get Current User
**Endpoint**: `GET /auth/me`

**Headers**: `Authorization: Bearer <token>`

**Response**:
```json
{
  "id": "...",
  "username": "john_doe",
  "email": "user@example.com",
  "phone": "+919876543210",
  "is_admin": false,
  "role": "user",
  "auth_method": "social_google",
  "profile_picture": null,
  "created_at": "2024-01-01T00:00:00"
}
```

### 5. Update Profile
**Endpoint**: `PUT /auth/me`

**Headers**: `Authorization: Bearer <token>`

**Request**:
```json
{
  "username": "new_username",  // Optional
  "email": "newemail@example.com"  // Optional
}
```

### 6. Profile Picture Endpoints
- `POST /auth/me/profile-picture` - Upload profile picture
- `GET /auth/profile-picture/{filename}` - Get profile picture
- `DELETE /auth/me/profile-picture` - Delete profile picture

## 🔄 Authentication Flows

### Phone/Email/WhatsApp OTP Flow

```
1. User enters phone/email
   ↓
2. Frontend calls POST /auth/send-otp
   ↓
3. User receives OTP
   ↓
4. User enters OTP (and username if new user)
   ↓
5. Frontend calls POST /auth/verify-otp
   ↓
6. Backend verifies OTP with OTPless
   ↓
7. If user exists: Login
   If user doesn't exist: Register (if username provided)
   ↓
8. Return JWT token
```

### Google/Facebook Social Login Flow

```
1. User clicks "Login with Google/Facebook"
   ↓
2. Frontend initiates OTPless SDK social login
   ↓
3. User authenticates with Google/Facebook
   ↓
4. OTPless SDK returns token
   ↓
5. Frontend calls POST /auth/social-login with token
   ↓
6. Backend verifies token with OTPless
   ↓
7. If user exists: Login
   If user doesn't exist: Register (auto-generate username if needed)
   ↓
8. Return JWT token
```

## 💾 Database Schema

### User Model
```python
{
  "username": str (unique),
  "email": str (unique),
  "hashed_password": Optional[str],  # Not used, kept for compatibility
  "phone": Optional[str],
  "is_admin": bool,
  "role": str,  # "user" or "admin"
  "profile_picture": Optional[str],
  "auth_method": str,  # "otpless", "social_google", "social_facebook"
  "created_at": datetime
}
```

### Email Field Storage
- **Phone users**: `phone:+919876543210`
- **Email users**: `user@example.com`
- **Social users**: Email from provider or `provider:provider_id`

## 🚀 Frontend Integration

### React Example

```javascript
import React, { useState } from 'react';

function OTPlessAuth() {
  const [step, setStep] = useState('input'); // 'input', 'otp', 'social'
  const [channel, setChannel] = useState('PHONE');
  const [contact, setContact] = useState('');
  const [otp, setOtp] = useState('');
  const [username, setUsername] = useState('');

  // Send OTP
  const sendOTP = async () => {
    const payload = {
      channel: channel,
      [channel === 'EMAIL' ? 'email' : 'phone']: contact
    };

    const response = await fetch('/auth/send-otp', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    if (response.ok) {
      setStep('otp');
    }
  };

  // Verify OTP
  const verifyOTP = async () => {
    const payload = {
      channel: channel,
      [channel === 'EMAIL' ? 'email' : 'phone']: contact,
      otp: otp,
      username: username || undefined
    };

    const response = await fetch('/auth/verify-otp', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    const data = await response.json();
    if (response.ok) {
      localStorage.setItem('token', data.access_token);
      // Redirect to dashboard
    }
  };

  // Social Login (requires OTPless SDK)
  const socialLogin = async (provider) => {
    // Initialize OTPless SDK and get token
    // const token = await OTPless.signIn(provider);
    
    const response = await fetch('/auth/social-login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: 'token_from_sdk' })
    });

    const data = await response.json();
    if (response.ok) {
      localStorage.setItem('token', data.access_token);
      // Redirect to dashboard
    }
  };

  return (
    <div>
      {step === 'input' && (
        <div>
          <select value={channel} onChange={(e) => setChannel(e.target.value)}>
            <option value="PHONE">Phone</option>
            <option value="EMAIL">Email</option>
            <option value="WHATSAPP">WhatsApp</option>
          </select>
          
          <input
            type={channel === 'EMAIL' ? 'email' : 'tel'}
            placeholder={channel === 'EMAIL' ? 'Email' : 'Phone (+91...)'}
            value={contact}
            onChange={(e) => setContact(e.target.value)}
          />
          
          <button onClick={sendOTP}>Send OTP</button>
          
          <div>
            <button onClick={() => socialLogin('google')}>
              Login with Google
            </button>
            <button onClick={() => socialLogin('facebook')}>
              Login with Facebook
            </button>
          </div>
        </div>
      )}

      {step === 'otp' && (
        <div>
          <input
            type="text"
            placeholder="Enter OTP"
            value={otp}
            onChange={(e) => setOtp(e.target.value)}
            maxLength={6}
          />
          
          <input
            type="text"
            placeholder="Username (for new users)"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
          />
          
          <button onClick={verifyOTP}>Verify</button>
        </div>
      )}
    </div>
  );
}
```

### Flutter Example

```dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OTPlessAuthPage extends StatefulWidget {
  @override
  _OTPlessAuthPageState createState() => _OTPlessAuthPageState();
}

class _OTPlessAuthPageState extends State<OTPlessAuthPage> {
  String _channel = 'PHONE';
  final _contactController = TextEditingController();
  final _otpController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _otpSent = false;

  Future<void> sendOTP() async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'channel': _channel,
        if (_channel == 'EMAIL') 'email': _contactController.text
        else 'phone': _contactController.text,
      }),
    );

    if (response.statusCode == 200) {
      setState(() => _otpSent = true);
    }
  }

  Future<void> verifyOTP() async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'channel': _channel,
        if (_channel == 'EMAIL') 'email': _contactController.text
        else 'phone': _contactController.text,
        'otp': _otpController.text,
        if (_usernameController.text.isNotEmpty)
          'username': _usernameController.text,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Save token and navigate
    }
  }

  Future<void> socialLogin(String provider) async {
    // Initialize OTPless SDK and get token
    // final token = await OTPlessSDK.signIn(provider);
    
    final response = await http.post(
      Uri.parse('$baseUrl/auth/social-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': 'token_from_sdk'}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Save token and navigate
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _otpSent ? _buildOTPInput() : _buildContactInput(),
    );
  }

  Widget _buildContactInput() {
    return Column(
      children: [
        DropdownButton<String>(
          value: _channel,
          items: ['PHONE', 'EMAIL', 'WHATSAPP']
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _channel = v!),
        ),
        TextField(
          controller: _contactController,
          decoration: InputDecoration(
            labelText: _channel == 'EMAIL' ? 'Email' : 'Phone',
          ),
        ),
        ElevatedButton(
          onPressed: sendOTP,
          child: Text('Send OTP'),
        ),
        ElevatedButton(
          onPressed: () => socialLogin('google'),
          child: Text('Login with Google'),
        ),
        ElevatedButton(
          onPressed: () => socialLogin('facebook'),
          child: Text('Login with Facebook'),
        ),
      ],
    );
  }

  Widget _buildOTPInput() {
    return Column(
      children: [
        TextField(
          controller: _otpController,
          decoration: InputDecoration(labelText: 'OTP'),
          maxLength: 6,
        ),
        TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: 'Username (for new users)',
          ),
        ),
        ElevatedButton(
          onPressed: verifyOTP,
          child: Text('Verify'),
        ),
      ],
    );
  }
}
```

## 🔐 Security Features

1. **No Password Storage**: Passwords are not used or stored
2. **OTP Verification**: All OTP verification through OTPless API
3. **Social Token Verification**: Social login tokens verified with OTPless
4. **JWT Tokens**: Secure JWT tokens for session management
5. **Unique Constraints**: Phone/email uniqueness enforced

## 🧪 Testing

### Test with cURL

```bash
# 1. Send OTP
curl -X POST http://localhost:8000/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"channel": "PHONE", "phone": "+919876543210"}'

# 2. Verify OTP (New User)
curl -X POST http://localhost:8000/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "PHONE",
    "phone": "+919876543210",
    "otp": "123456",
    "username": "testuser"
  }'

# 3. Verify OTP (Existing User)
curl -X POST http://localhost:8000/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "PHONE",
    "phone": "+919876543210",
    "otp": "123456"
  }'

# 4. Social Login
curl -X POST http://localhost:8000/auth/social-login \
  -H "Content-Type: application/json" \
  -d '{"token": "otpless_token_here"}'

# 5. Get Current User
curl -X GET http://localhost:8000/auth/me \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## 📋 Migration from Old System

### For Existing Users
- Old username/password authentication is **removed**
- Existing users need to re-register using OTPless
- User data (username, email) can be preserved if email matches

### Database Changes
- `hashed_password` field is now optional (not used)
- `auth_method` default changed to "otpless"
- New values: "otpless", "social_google", "social_facebook"

## ⚠️ Important Notes

1. **OTPless SDK Required**: For social login, integrate OTPless SDK in frontend
2. **Phone Format**: Must include country code (+91, +1, etc.)
3. **Username Auto-generation**: Social login auto-generates username if not provided
4. **No Password Reset**: Not needed since passwords aren't used
5. **Token Expiry**: JWT tokens expire after 16400 minutes (configurable)

## 📚 Resources

- **OTPless Dashboard**: https://otpless.com/dashboard
- **OTPless Documentation**: https://otpless.com/docs
- **OTPless SDK**: https://otpless.com/docs/sdk
- **API Reference**: http://localhost:8000/docs

## 🎉 Benefits

✅ **Passwordless**: No password management needed
✅ **Secure**: OTP and social login verification
✅ **User-Friendly**: Simple OTP-based authentication
✅ **Multi-Channel**: Phone, Email, WhatsApp support
✅ **Social Integration**: Google and Facebook login
✅ **Modern**: Industry-standard authentication

## 💬 Support

For issues:
1. Check OTPless dashboard for delivery status
2. Review OTPless documentation
3. Contact OTPless support: support@otpless.com
