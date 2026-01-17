# OTPless Integration - Quick Reference Card

## 🔑 Credentials
```
App ID: 1ZL5IUR4FITTIV93TX49
Client ID: PPLZ8PLRP17J4FALF78B8G6MG90A95LS
Client Secret: x7ass763h83f36uo5t2uyx22kquoi2r4
```

## 🌐 API Endpoints

### OTPless Endpoints
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/auth/otpless/send-otp` | POST | Send OTP to phone/email |
| `/auth/otpless/verify-login` | POST | Login with OTP |
| `/auth/otpless/verify-register` | POST | Register with OTP |

### Traditional Endpoints (Unchanged)
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/auth/register` | POST | Register with password |
| `/auth/login` | POST | Login with password |
| `/auth/token` | POST | OAuth2 token |
| `/auth/me` | GET | Get current user |

## 📝 Request Examples

### Send OTP (Phone)
```json
POST /auth/otpless/send-otp
{
  "channel": "PHONE",
  "phone": "+919876543210"
}
```

### Send OTP (Email)
```json
POST /auth/otpless/send-otp
{
  "channel": "EMAIL",
  "email": "user@example.com"
}
```

### Register with OTP
```json
POST /auth/otpless/verify-register
{
  "channel": "PHONE",
  "phone": "+919876543210",
  "otp": "123456",
  "username": "john_doe",
  "role": "user"
}
```

### Login with OTP
```json
POST /auth/otpless/verify-login
{
  "channel": "PHONE",
  "phone": "+919876543210",
  "otp": "123456"
}
```

## 🔄 Authentication Flow

### OTPless Flow
```
1. User enters phone/email
2. Call /send-otp
3. User receives OTP
4. User enters OTP
5. Call /verify-login or /verify-register
6. Receive JWT token
7. Use token for authenticated requests
```

### Traditional Flow
```
1. User enters username/password
2. Call /login
3. Receive JWT token
4. Use token for authenticated requests
```

## 💾 Database Fields

### User Model
```python
username: str (unique)
email: str (unique)
hashed_password: str
phone: Optional[str]
auth_method: str  # "password" or "otpless"
is_admin: bool
role: str
profile_picture: Optional[str]
created_at: datetime
```

## 🎯 Key Features

✅ **Dual Authentication**: Both password and OTPless work together
✅ **Backward Compatible**: Existing users unaffected
✅ **Same JWT Tokens**: Both methods use identical token format
✅ **Phone & Email**: Support for both OTP channels
✅ **Role-Based**: Admin and user roles supported

## 🚀 Quick Test

```bash
# 1. Install dependency
pip install httpx==0.25.2

# 2. Start server
uvicorn main:app --reload

# 3. Test OTPless
curl -X POST http://localhost:8000/auth/otpless/send-otp \
  -H "Content-Type: application/json" \
  -d '{"channel": "PHONE", "phone": "+919876543210"}'

# 4. Test traditional (still works)
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "user", "password": "pass"}'
```

## ⚠️ Important Notes

1. **Phone Format**: Must include country code (+91, +1, etc.)
2. **Email Storage**: Phone users stored as `phone:+919876543210`
3. **No Password**: OTPless users don't need passwords
4. **Token Usage**: Same for both auth methods
5. **Unique Constraint**: Phone/email must be unique

## 🔧 Configuration

Located in `backend/routers/auth.py`:
```python
OTPLESS_APP_ID = "1ZL5IUR4FITTIV93TX49"
OTPLESS_CLIENT_ID = "PPLZ8PLRP17J4FALF78B8G6MG90A95LS"
OTPLESS_CLIENT_SECRET = "x7ass763h83f36uo5t2uyx22kquoi2r4"
OTPLESS_API_BASE = "https://api.otpless.app/auth"
```

## 📊 Response Format

### Success Response
```json
{
  "access_token": "eyJhbGc...",
  "token_type": "bearer",
  "user": {
    "id": "...",
    "username": "john_doe",
    "email": "phone:+919876543210",
    "phone": "+919876543210",
    "auth_method": "otpless",
    "is_admin": false,
    "role": "user",
    "created_at": "2024-01-01T00:00:00"
  }
}
```

### Error Response
```json
{
  "detail": "Error message here"
}
```

## 🐛 Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| Invalid OTP | Wrong/expired OTP | Request new OTP |
| User not found | Not registered | Use verify-register |
| User exists | Already registered | Use verify-login |
| Invalid channel | Wrong channel value | Use "PHONE" or "EMAIL" |

## 📚 Documentation Files

- `OTPLESS_SETUP_GUIDE.md` - Setup instructions
- `OTPLESS_INTEGRATION.md` - Complete documentation
- `OTPLESS_IMPLEMENTATION_SUMMARY.md` - Technical details
- `test_otpless_integration.py` - Test script

## 🔗 Useful Links

- Swagger UI: http://localhost:8000/docs
- OTPless Dashboard: https://otpless.com/dashboard
- OTPless Docs: https://otpless.com/docs

## ✅ Checklist

Before deploying:
- [ ] Dependencies installed
- [ ] Credentials configured
- [ ] Endpoints tested
- [ ] Traditional auth verified
- [ ] Frontend integrated
- [ ] Error handling tested
- [ ] Documentation reviewed

---

**Need Help?** Check `OTPLESS_SETUP_GUIDE.md` for detailed setup instructions.
