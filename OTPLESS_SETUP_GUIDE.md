# OTPless Integration - Quick Setup Guide

## 🚀 Quick Start

This guide will help you set up and test the OTPless authentication integration in 5 minutes.

## 📋 Prerequisites

- Python 3.8+
- FastAPI backend running
- MongoDB database
- Internet connection (for OTPless API calls)

## 🔧 Installation Steps

### Step 1: Install Dependencies

```bash
cd backend
pip install httpx==0.25.2
```

Or install all dependencies:
```bash
pip install -r requirements.txt
```

### Step 2: Verify Configuration

The OTPless credentials are already configured in `backend/routers/auth.py`:

```python
OTPLESS_APP_ID = "1ZL5IUR4FITTIV93TX49"
OTPLESS_CLIENT_ID = "PPLZ8PLRP17J4FALF78B8G6MG90A95LS"
OTPLESS_CLIENT_SECRET = "x7ass763h83f36uo5t2uyx22kquoi2r4"
```

### Step 3: Start the Backend Server

```bash
cd backend
uvicorn main:app --reload
```

The server should start on `http://localhost:8000`

### Step 4: Verify Installation

Check if the new endpoints are available:
```bash
curl http://localhost:8000/docs
```

Look for these new endpoints in the Swagger UI:
- `/auth/otpless/send-otp`
- `/auth/otpless/verify-login`
- `/auth/otpless/verify-register`

## 🧪 Testing

### Option 1: Interactive Test Script

```bash
cd backend
python test_otpless_integration.py
```

Follow the interactive menu to test different endpoints.

### Option 2: Manual Testing with cURL

#### Test 1: Send OTP to Phone
```bash
curl -X POST http://localhost:8000/auth/otpless/send-otp \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "PHONE",
    "phone": "+919876543210"
  }'
```

Expected Response:
```json
{
  "success": true,
  "message": "OTP sent successfully",
  "request_id": "order_xyz123"
}
```

#### Test 2: Register New User with OTP
```bash
curl -X POST http://localhost:8000/auth/otpless/verify-register \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "PHONE",
    "phone": "+919876543210",
    "otp": "123456",
    "username": "john_doe",
    "role": "user"
  }'
```

Expected Response:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "id": "...",
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

#### Test 3: Login Existing User with OTP
```bash
curl -X POST http://localhost:8000/auth/otpless/verify-login \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "PHONE",
    "phone": "+919876543210",
    "otp": "123456"
  }'
```

#### Test 4: Verify Traditional Auth Still Works
```bash
# Register with password
curl -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "traditional_user",
    "email": "user@example.com",
    "password": "securepass123",
    "role": "user"
  }'

# Login with password
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "traditional_user",
    "password": "securepass123"
  }'
```

### Option 3: Swagger UI Testing

1. Open browser: `http://localhost:8000/docs`
2. Find `/auth/otpless/send-otp` endpoint
3. Click "Try it out"
4. Enter test data:
   ```json
   {
     "channel": "PHONE",
     "phone": "+919876543210"
   }
   ```
5. Click "Execute"
6. Check the response

## 📱 Frontend Integration Examples

### React Example

```javascript
// OTPlessAuth.js
import React, { useState } from 'react';

function OTPlessAuth() {
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState('');
  const [username, setUsername] = useState('');
  const [step, setStep] = useState('phone'); // 'phone' or 'otp'
  const [isRegistering, setIsRegistering] = useState(false);

  const sendOTP = async () => {
    try {
      const response = await fetch('/auth/otpless/send-otp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          channel: 'PHONE',
          phone: phone
        })
      });
      
      const data = await response.json();
      
      if (data.success) {
        setStep('otp');
        alert('OTP sent successfully!');
      } else {
        alert('Failed to send OTP: ' + data.message);
      }
    } catch (error) {
      alert('Error: ' + error.message);
    }
  };

  const verifyOTP = async () => {
    try {
      const endpoint = isRegistering 
        ? '/auth/otpless/verify-register'
        : '/auth/otpless/verify-login';
      
      const body = {
        channel: 'PHONE',
        phone: phone,
        otp: otp
      };
      
      if (isRegistering) {
        body.username = username;
        body.role = 'user';
      }
      
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
      });
      
      const data = await response.json();
      
      if (response.ok) {
        localStorage.setItem('token', data.access_token);
        localStorage.setItem('user', JSON.stringify(data.user));
        alert('Success! Redirecting...');
        window.location.href = '/dashboard';
      } else {
        alert('Verification failed: ' + data.detail);
      }
    } catch (error) {
      alert('Error: ' + error.message);
    }
  };

  return (
    <div className="otpless-auth">
      <h2>OTPless Authentication</h2>
      
      {step === 'phone' && (
        <div>
          <input
            type="tel"
            placeholder="+919876543210"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
          />
          
          <label>
            <input
              type="checkbox"
              checked={isRegistering}
              onChange={(e) => setIsRegistering(e.target.checked)}
            />
            New user? Register
          </label>
          
          {isRegistering && (
            <input
              type="text"
              placeholder="Username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
            />
          )}
          
          <button onClick={sendOTP}>Send OTP</button>
        </div>
      )}
      
      {step === 'otp' && (
        <div>
          <p>OTP sent to {phone}</p>
          <input
            type="text"
            placeholder="Enter OTP"
            value={otp}
            onChange={(e) => setOtp(e.target.value)}
            maxLength={6}
          />
          <button onClick={verifyOTP}>Verify OTP</button>
          <button onClick={() => setStep('phone')}>Back</button>
        </div>
      )}
    </div>
  );
}

export default OTPlessAuth;
```

### Flutter Example

```dart
// otpless_auth_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class OTPlessAuthPage extends StatefulWidget {
  @override
  _OTPlessAuthPageState createState() => _OTPlessAuthPageState();
}

class _OTPlessAuthPageState extends State<OTPlessAuthPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _usernameController = TextEditingController();
  
  bool _isOtpSent = false;
  bool _isRegistering = false;
  bool _isLoading = false;
  
  final String baseUrl = 'http://localhost:8000';

  Future<void> sendOTP() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/otpless/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'channel': 'PHONE',
          'phone': _phoneController.text,
        }),
      );
      
      final data = jsonDecode(response.body);
      
      if (data['success']) {
        setState(() => _isOtpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP sent successfully!')),
        );
      } else {
        throw Exception(data['message']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> verifyOTP() async {
    setState(() => _isLoading = true);
    
    try {
      final endpoint = _isRegistering
          ? '/auth/otpless/verify-register'
          : '/auth/otpless/verify-login';
      
      final body = {
        'channel': 'PHONE',
        'phone': _phoneController.text,
        'otp': _otpController.text,
      };
      
      if (_isRegistering) {
        body['username'] = _usernameController.text;
        body['role'] = 'user';
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Store token and navigate
        // await storage.write(key: 'token', value: data['access_token']);
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('OTPless Login')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            if (!_isOtpSent) ...[
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+919876543210',
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 16),
              CheckboxListTile(
                title: Text('New user? Register'),
                value: _isRegistering,
                onChanged: (value) {
                  setState(() => _isRegistering = value ?? false);
                },
              ),
              if (_isRegistering)
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(labelText: 'Username'),
                ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : sendOTP,
                child: _isLoading
                    ? CircularProgressIndicator()
                    : Text('Send OTP'),
              ),
            ] else ...[
              Text('OTP sent to ${_phoneController.text}'),
              SizedBox(height: 16),
              TextField(
                controller: _otpController,
                decoration: InputDecoration(labelText: 'Enter OTP'),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : verifyOTP,
                child: _isLoading
                    ? CircularProgressIndicator()
                    : Text('Verify OTP'),
              ),
              TextButton(
                onPressed: () => setState(() => _isOtpSent = false),
                child: Text('Back'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

## 🔍 Troubleshooting

### Issue: "Module 'httpx' not found"
**Solution**: Install httpx
```bash
pip install httpx==0.25.2
```

### Issue: "OTP not received"
**Possible causes**:
1. Invalid phone number format (must include country code: +91...)
2. OTPless API credentials incorrect
3. Network connectivity issues

**Solution**: 
- Verify phone number format
- Check OTPless dashboard for delivery status
- Test with a different phone number

### Issue: "Invalid OTP"
**Possible causes**:
1. OTP expired (typically 5-10 minutes)
2. Wrong OTP entered
3. OTP already used

**Solution**:
- Request a new OTP
- Verify the OTP code carefully
- Check OTPless dashboard for verification status

### Issue: "User already exists"
**Solution**: Use `/auth/otpless/verify-login` instead of `/auth/otpless/verify-register`

### Issue: Traditional auth not working
**Solution**: The traditional authentication system is unchanged. If it's not working, the issue is unrelated to OTPless integration.

## 📊 Monitoring

### Check OTPless Dashboard
- Login to: https://otpless.com/dashboard
- View OTP delivery status
- Check API usage statistics
- Monitor success/failure rates

### Backend Logs
Monitor backend logs for OTPless API responses:
```bash
# In your terminal where backend is running
# Look for OTPless-related log messages
```

## 🔐 Security Best Practices

1. **Never expose credentials in frontend code**
2. **Use HTTPS in production**
3. **Implement rate limiting for OTP requests**
4. **Add CAPTCHA for OTP send endpoint**
5. **Monitor for suspicious activity**
6. **Set appropriate token expiration times**

## 📚 Additional Resources

- **Full Documentation**: See `OTPLESS_INTEGRATION.md`
- **Implementation Summary**: See `OTPLESS_IMPLEMENTATION_SUMMARY.md`
- **Test Script**: Run `backend/test_otpless_integration.py`
- **OTPless Docs**: https://otpless.com/docs
- **API Reference**: http://localhost:8000/docs (Swagger UI)

## ✅ Verification Checklist

- [ ] Dependencies installed (`httpx`)
- [ ] Backend server running
- [ ] Can access Swagger UI at `/docs`
- [ ] New OTPless endpoints visible in Swagger
- [ ] Can send OTP successfully
- [ ] Can register new user with OTP
- [ ] Can login existing user with OTP
- [ ] Traditional auth still works
- [ ] JWT tokens work for both auth methods

## 🎉 Success!

If all tests pass, your OTPless integration is complete and ready for production use!

## 💬 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review `OTPLESS_INTEGRATION.md` for detailed documentation
3. Check OTPless documentation: https://otpless.com/docs
4. Contact OTPless support: support@otpless.com
