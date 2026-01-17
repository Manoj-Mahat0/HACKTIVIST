# OTPless Authentication - Quick Start

## 🚀 What Changed?

**Old System** ❌: Username + Password
**New System** ✅: OTPless (Phone/Email/WhatsApp OTP + Google/Facebook)

## 📡 New API Endpoints

| Endpoint | Purpose |
|----------|---------|
| `POST /auth/send-otp` | Send OTP to phone/email/WhatsApp |
| `POST /auth/verify-otp` | Verify OTP and login/register |
| `POST /auth/social-login` | Login with Google/Facebook |
| `GET /auth/me` | Get current user (unchanged) |
| `PUT /auth/me` | Update profile (unchanged) |

## 🔑 Credentials

```
App ID: 1ZL5IUR4FITTIV93TX49
Client ID: PPLZ8PLRP17J4FALF78B8G6MG90A95LS
Client Secret: x7ass763h83f36uo5t2uyx22kquoi2r4
```

## 💻 Quick Test

```bash
# 1. Send OTP
curl -X POST http://localhost:8000/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"channel": "PHONE", "phone": "+919876543210"}'

# 2. Verify OTP (use actual OTP received)
curl -X POST http://localhost:8000/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{
    "channel": "PHONE",
    "phone": "+919876543210",
    "otp": "123456",
    "username": "testuser"
  }'
```

## 📱 Frontend Example (React)

```javascript
// Send OTP
const sendOTP = async (phone) => {
  await fetch('/auth/send-otp', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      channel: 'PHONE',
      phone: phone
    })
  });
};

// Verify OTP
const verifyOTP = async (phone, otp, username) => {
  const response = await fetch('/auth/verify-otp', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      channel: 'PHONE',
      phone: phone,
      otp: otp,
      username: username  // Only for new users
    })
  });
  
  const data = await response.json();
  localStorage.setItem('token', data.access_token);
};
```

## 📚 Full Documentation

- **Complete Guide**: `OTPLESS_ONLY_AUTH_GUIDE.md`
- **Migration Details**: `AUTH_SYSTEM_MIGRATION_SUMMARY.md`
- **Summary**: `OTPLESS_FINAL_SUMMARY.md`

## ⚠️ Important

1. **Frontend Update Required** - Old login won't work
2. **Users Must Re-register** - Using phone/email OTP
3. **No Passwords** - System is now passwordless

## ✅ Next Steps

1. ✅ Backend is ready (already done)
2. ⏳ Update frontend to use new endpoints
3. ⏳ Integrate OTPless SDK for social login
4. ⏳ Test with real users

## 🎯 Benefits

✅ No passwords to remember
✅ Faster login (just OTP)
✅ More secure
✅ Social login support
✅ Multiple channels (Phone/Email/WhatsApp)

---

**Need Help?** Check `OTPLESS_ONLY_AUTH_GUIDE.md` for detailed examples and troubleshooting.
