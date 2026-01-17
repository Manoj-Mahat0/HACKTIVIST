# OTPless Integration - Architecture Diagram

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Frontend Layer                          │
│  ┌──────────────────────┐      ┌──────────────────────┐        │
│  │  Traditional Login   │      │   OTPless Login      │        │
│  │  ┌────────────────┐  │      │  ┌────────────────┐  │        │
│  │  │ Username       │  │      │  │ Phone/Email    │  │        │
│  │  │ Password       │  │      │  │ OTP Code       │  │        │
│  │  │ [Login Button] │  │      │  │ [Send OTP]     │  │        │
│  │  └────────────────┘  │      │  │ [Verify OTP]   │  │        │
│  └──────────────────────┘      │  └────────────────┘  │        │
│           │                     │          │           │        │
└───────────┼─────────────────────┼──────────┼───────────┘        
            │                     │          │                    
            ▼                     ▼          ▼                    
┌─────────────────────────────────────────────────────────────────┐
│                      FastAPI Backend                            │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Auth Router                            │  │
│  │                                                            │  │
│  │  Traditional Endpoints      │    OTPless Endpoints        │  │
│  │  ┌──────────────────┐      │    ┌──────────────────┐    │  │
│  │  │ POST /register   │      │    │ POST /send-otp   │    │  │
│  │  │ POST /login      │      │    │ POST /verify-    │    │  │
│  │  │ POST /token      │      │    │      login       │    │  │
│  │  │ GET  /me         │      │    │ POST /verify-    │    │  │
│  │  │ PUT  /me         │      │    │      register    │    │  │
│  │  └──────────────────┘      │    └──────────────────┘    │  │
│  │          │                  │            │               │  │
│  │          ▼                  │            ▼               │  │
│  │  ┌──────────────────┐      │    ┌──────────────────┐    │  │
│  │  │ verify_password  │      │    │ send_otp_via_    │    │  │
│  │  │ get_password_hash│      │    │   otpless        │    │  │
│  │  │ authenticate_user│      │    │ verify_otp_via_  │    │  │
│  │  └──────────────────┘      │    │   otpless        │    │  │
│  │          │                  │    └──────────────────┘    │  │
│  └──────────┼──────────────────┼────────────┼───────────────┘  │
│             │                  │            │                   │
│             ▼                  │            ▼                   │
│  ┌──────────────────┐         │    ┌──────────────────┐       │
│  │ create_access_   │◄────────┴────┤  httpx Client    │       │
│  │   token (JWT)    │              │  (Async HTTP)    │       │
│  └──────────────────┘              └──────────────────┘       │
│             │                               │                   │
└─────────────┼───────────────────────────────┼───────────────────┘
              │                               │                    
              ▼                               ▼                    
┌─────────────────────────┐     ┌────────────────────────────┐   
│   MongoDB Database      │     │   OTPless API Service      │   
│                         │     │                            │   
│  ┌──────────────────┐  │     │  ┌──────────────────────┐  │   
│  │  Users Collection│  │     │  │  POST /otp/v1/send   │  │   
│  │                  │  │     │  │  POST /otp/v1/verify │  │   
│  │  {               │  │     │  └──────────────────────┘  │   
│  │   username       │  │     │                            │   
│  │   email          │  │     │  Handles:                  │   
│  │   hashed_password│  │     │  - OTP generation          │   
│  │   phone          │  │     │  - SMS/Email delivery      │   
│  │   auth_method    │  │     │  - OTP verification        │   
│  │   is_admin       │  │     │  - Rate limiting           │   
│  │   role           │  │     │                            │   
│  │   ...            │  │     │                            │   
│  │  }               │  │     │                            │   
│  └──────────────────┘  │     └────────────────────────────┘   
└─────────────────────────┘                                      
```

## 🔄 Authentication Flow Diagrams

### Traditional Authentication Flow

```
┌──────┐                                                    ┌──────────┐
│Client│                                                    │ Backend  │
└──┬───┘                                                    └────┬─────┘
   │                                                             │
   │  POST /auth/login                                          │
   │  {username, password}                                      │
   ├────────────────────────────────────────────────────────────►
   │                                                             │
   │                                    Find user by username   │
   │                                    ┌──────────────────────►│
   │                                    │                        │
   │                                    │  User found            │
   │                                    ◄──────────────────────┐│
   │                                                             │
   │                                    Verify password hash    │
   │                                    ┌──────────────────────►│
   │                                    │                        │
   │                                    │  Password valid        │
   │                                    ◄──────────────────────┐│
   │                                                             │
   │                                    Generate JWT token      │
   │                                    ┌──────────────────────►│
   │                                    │                        │
   │                                    │  Token created         │
   │                                    ◄──────────────────────┐│
   │                                                             │
   │  {access_token, user}                                      │
   ◄────────────────────────────────────────────────────────────┤
   │                                                             │
   │  Store token in localStorage/storage                       │
   │                                                             │
   │  Subsequent requests with Authorization header             │
   │  Authorization: Bearer <token>                             │
   ├────────────────────────────────────────────────────────────►
   │                                                             │
```

### OTPless Authentication Flow

```
┌──────┐                    ┌──────────┐                ┌──────────┐
│Client│                    │ Backend  │                │ OTPless  │
└──┬───┘                    └────┬─────┘                └────┬─────┘
   │                             │                           │
   │  1. POST /auth/otpless/send-otp                        │
   │     {channel: "PHONE", phone: "+91..."}                │
   ├─────────────────────────────►                          │
   │                             │                           │
   │                             │  POST /otp/v1/send        │
   │                             │  {phoneNumber, channel}   │
   │                             ├──────────────────────────►│
   │                             │                           │
   │                             │                  Generate OTP
   │                             │                  Send SMS  │
   │                             │                           │
   │                             │  {orderId, success}       │
   │                             ◄──────────────────────────┤│
   │                             │                           │
   │  {success: true, request_id}                           │
   ◄─────────────────────────────┤                          │
   │                             │                           │
   │  User receives SMS with OTP │                           │
   │  📱 "Your OTP is: 123456"   │                           │
   │                             │                           │
   │  2. POST /auth/otpless/verify-login                    │
   │     {channel: "PHONE", phone: "+91...", otp: "123456"} │
   ├─────────────────────────────►                          │
   │                             │                           │
   │                             │  POST /otp/v1/verify      │
   │                             │  {phoneNumber, otp}       │
   │                             ├──────────────────────────►│
   │                             │                           │
   │                             │                  Verify OTP
   │                             │                           │
   │                             │  {isOTPVerified: true}    │
   │                             ◄──────────────────────────┤│
   │                             │                           │
   │                    Find user by phone                   │
   │                    ┌──────────────────────►             │
   │                    │                                    │
   │                    │  User found                        │
   │                    ◄──────────────────────┐             │
   │                             │                           │
   │                    Generate JWT token                   │
   │                    ┌──────────────────────►             │
   │                    │                                    │
   │                    │  Token created                     │
   │                    ◄──────────────────────┐             │
   │                             │                           │
   │  {access_token, user}       │                           │
   ◄─────────────────────────────┤                          │
   │                             │                           │
   │  Store token in localStorage/storage                    │
   │                             │                           │
```

## 🗂️ Data Flow

### User Registration Comparison

#### Traditional Registration
```
User Input                Database Storage
┌──────────────┐         ┌──────────────────────┐
│ username     │────────►│ username             │
│ email        │────────►│ email                │
│ password     │─┐       │ hashed_password      │
└──────────────┘ │       │ auth_method: "password"│
                 │       │ phone: null          │
                 ▼       └──────────────────────┘
         ┌──────────────┐
         │ bcrypt hash  │
         │ (12 rounds)  │
         └──────────────┘
```

#### OTPless Registration
```
User Input                OTPless Verify         Database Storage
┌──────────────┐         ┌──────────────┐       ┌──────────────────────┐
│ phone/email  │────────►│ Verify OTP   │──────►│ username             │
│ otp          │         │ via API      │       │ email: "phone:+91..."│
│ username     │────────►└──────────────┘       │ hashed_password      │
└──────────────┘                                 │   (random UUID)      │
                                                 │ auth_method: "otpless"│
                                                 │ phone: "+91..."      │
                                                 └──────────────────────┘
```

## 🔐 Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Security Layers                         │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Layer 1: Input Validation                         │    │
│  │  - Phone/email format validation                   │    │
│  │  - Username length check                           │    │
│  │  - Password strength (traditional)                 │    │
│  └────────────────────────────────────────────────────┘    │
│                          │                                   │
│                          ▼                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Layer 2: Authentication                           │    │
│  │  - OTPless API verification (OTPless users)        │    │
│  │  - Bcrypt hash comparison (traditional users)      │    │
│  └────────────────────────────────────────────────────┘    │
│                          │                                   │
│                          ▼                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Layer 3: Token Generation                         │    │
│  │  - JWT with HS256 algorithm                        │    │
│  │  - Expiration: 16400 minutes                       │    │
│  │  - Payload: {sub: username, exp: timestamp}        │    │
│  └────────────────────────────────────────────────────┘    │
│                          │                                   │
│                          ▼                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Layer 4: Authorization                            │    │
│  │  - Bearer token validation                         │    │
│  │  - User role checking (admin/user)                 │    │
│  │  - Endpoint access control                         │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 📊 Database Schema

```
┌─────────────────────────────────────────────────────────────┐
│                    Users Collection                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Field Name         Type        Constraints    Default      │
│  ─────────────────────────────────────────────────────────  │
│  _id                ObjectId    Primary Key    Auto         │
│  username           String      Unique         Required     │
│  email              String      Unique         Required     │
│  hashed_password    String      -              Required     │
│  phone              String      Optional       null         │
│  auth_method        String      -              "password"   │
│  is_admin           Boolean     -              false        │
│  role               String      -              "user"       │
│  profile_picture    String      Optional       null         │
│  created_at         DateTime    -              now()        │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│  Indexes:                                                    │
│  - username (unique)                                         │
│  - email (unique)                                            │
└─────────────────────────────────────────────────────────────┘

Example Documents:

Traditional User:
{
  "_id": ObjectId("..."),
  "username": "john_doe",
  "email": "john@example.com",
  "hashed_password": "$2b$12$...",
  "phone": null,
  "auth_method": "password",
  "is_admin": false,
  "role": "user",
  "profile_picture": null,
  "created_at": ISODate("2024-01-01T00:00:00Z")
}

OTPless User (Phone):
{
  "_id": ObjectId("..."),
  "username": "jane_smith",
  "email": "phone:+919876543210",
  "hashed_password": "$2b$12$random_uuid_hash...",
  "phone": "+919876543210",
  "auth_method": "otpless",
  "is_admin": false,
  "role": "user",
  "profile_picture": null,
  "created_at": ISODate("2024-01-01T00:00:00Z")
}

OTPless User (Email):
{
  "_id": ObjectId("..."),
  "username": "bob_wilson",
  "email": "bob@example.com",
  "hashed_password": "$2b$12$random_uuid_hash...",
  "phone": null,
  "auth_method": "otpless",
  "is_admin": false,
  "role": "user",
  "profile_picture": null,
  "created_at": ISODate("2024-01-01T00:00:00Z")
}
```

## 🌐 API Endpoint Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    /auth Router                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Traditional Endpoints (Existing)                           │
│  ┌────────────────────────────────────────────────────┐    │
│  │ POST   /register                                   │    │
│  │ POST   /login                                      │    │
│  │ POST   /token                                      │    │
│  │ GET    /me                                         │    │
│  │ PUT    /me                                         │    │
│  │ POST   /me/profile-picture                         │    │
│  │ GET    /profile-picture/{filename}                 │    │
│  │ DELETE /me/profile-picture                         │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  OTPless Endpoints (New)                                    │
│  ┌────────────────────────────────────────────────────┐    │
│  │ POST   /otpless/send-otp                           │    │
│  │ POST   /otpless/verify-login                       │    │
│  │ POST   /otpless/verify-register                    │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 Request/Response Flow

### OTPless Send OTP

```
Request                          Processing                    Response
┌──────────────────┐            ┌──────────────────┐          ┌──────────────────┐
│ POST /send-otp   │            │ 1. Validate      │          │ {                │
│                  │            │    channel       │          │   "success": true│
│ {                │───────────►│ 2. Validate      │─────────►│   "message": "..." │
│   "channel":     │            │    contact       │          │   "request_id":  │
│     "PHONE",     │            │ 3. Call OTPless  │          │     "order_123"  │
│   "phone":       │            │    API           │          │ }                │
│     "+91..."     │            │ 4. Return result │          └──────────────────┘
│ }                │            └──────────────────┘
└──────────────────┘
```

### OTPless Verify & Login

```
Request                          Processing                    Response
┌──────────────────┐            ┌──────────────────┐          ┌──────────────────┐
│ POST /verify-    │            │ 1. Validate      │          │ {                │
│      login       │            │    input         │          │   "access_token":│
│                  │            │ 2. Verify OTP    │          │     "eyJ...",    │
│ {                │───────────►│    via OTPless   │─────────►│   "token_type":  │
│   "channel":     │            │ 3. Find user     │          │     "bearer",    │
│     "PHONE",     │            │ 4. Generate JWT  │          │   "user": {...}  │
│   "phone":       │            │ 5. Return token  │          │ }                │
│     "+91...",    │            └──────────────────┘          └──────────────────┘
│   "otp": "123456"│
│ }                │
└──────────────────┘
```

## 🎯 Component Interaction

```
┌─────────────────────────────────────────────────────────────┐
│                    Component Diagram                        │
│                                                              │
│  ┌──────────────┐                                           │
│  │   Frontend   │                                           │
│  │  Components  │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ├──────────────┬──────────────┐                     │
│         │              │              │                     │
│         ▼              ▼              ▼                     │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐               │
│  │Traditional│   │ OTPless  │   │  Profile │               │
│  │   Auth   │   │   Auth   │   │Management│               │
│  └──────┬───┘   └──────┬───┘   └──────┬───┘               │
│         │              │              │                     │
│         └──────────────┼──────────────┘                     │
│                        │                                     │
│                        ▼                                     │
│              ┌──────────────────┐                           │
│              │   Auth Router    │                           │
│              │   (FastAPI)      │                           │
│              └────────┬─────────┘                           │
│                       │                                      │
│         ┌─────────────┼─────────────┐                       │
│         │             │             │                       │
│         ▼             ▼             ▼                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│  │Password  │  │ OTPless  │  │   JWT    │                 │
│  │  Utils   │  │  Client  │  │  Utils   │                 │
│  └──────┬───┘  └──────┬───┘  └──────┬───┘                 │
│         │             │             │                       │
│         ▼             ▼             ▼                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│  │ MongoDB  │  │ OTPless  │  │  Token   │                 │
│  │ Database │  │   API    │  │ Storage  │                 │
│  └──────────┘  └──────────┘  └──────────┘                 │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 📈 Scalability Considerations

```
┌─────────────────────────────────────────────────────────────┐
│                  Scalability Architecture                   │
│                                                              │
│  Load Balancer                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Distributes requests across backend instances     │    │
│  └─────────────────┬──────────────────────────────────┘    │
│                    │                                         │
│         ┌──────────┼──────────┐                             │
│         │          │          │                             │
│         ▼          ▼          ▼                             │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐                       │
│  │Backend 1│ │Backend 2│ │Backend 3│                       │
│  │         │ │         │ │         │                       │
│  │ - Auth  │ │ - Auth  │ │ - Auth  │                       │
│  │ - JWT   │ │ - JWT   │ │ - JWT   │                       │
│  └────┬────┘ └────┬────┘ └────┬────┘                       │
│       │           │           │                             │
│       └───────────┼───────────┘                             │
│                   │                                          │
│         ┌─────────┼─────────┐                               │
│         │         │         │                               │
│         ▼         ▼         ▼                               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐                    │
│  │ MongoDB  │ │ OTPless  │ │  Redis   │                    │
│  │ Cluster  │ │   API    │ │  Cache   │                    │
│  │          │ │          │ │          │                    │
│  │ - Users  │ │ - OTP    │ │ - Tokens │                    │
│  │ - Sharded│ │ - Verify │ │ - Session│                    │
│  └──────────┘ └──────────┘ └──────────┘                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 Summary

This architecture provides:
- ✅ **Dual authentication** support
- ✅ **Scalable** design
- ✅ **Secure** implementation
- ✅ **Backward compatible**
- ✅ **Well documented**
- ✅ **Easy to maintain**

The system is production-ready and can handle both traditional and OTPless authentication methods seamlessly.
