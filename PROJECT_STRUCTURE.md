# Project Structure - Indoor Navigation App

## Overview
This document describes the organized project structure following senior developer best practices.

## Directory Structure

```
indoor-navigation-app/
│
├── backend/                          # Backend API (Python/FastAPI)
│   ├── routers/                     # API route handlers
│   │   ├── admin.py                # Admin endpoints
│   │   ├── auth.py                 # Authentication endpoints
│   │   ├── buildings.py            # Building management
│   │   ├── navigation.py           # Navigation endpoints
│   │   └── offline.py              # Offline data endpoints
│   │
│   ├── services/                    # Business logic services
│   │   └── websocket_manager.py    # WebSocket connection manager
│   │
│   ├── scripts/                     # Utility scripts
│   │   ├── run_backend.py          # Quick start script
│   │   ├── restart_backend.bat     # Windows restart script
│   │   ├── create_admin.py         # Admin user creation
│   │   └── reset_password.py       # Password reset utility
│   │
│   ├── tests/                       # API test collections
│   │   ├── Indoor_Navigation_API.postman_collection.json
│   │   ├── AUTH_TEST_COLLECTION.json
│   │   └── TEST_ROLE_BASED_AUTH.json
│   │
│   ├── venv/                        # Python virtual environment
│   ├── models.py                    # Database models (Beanie/MongoDB)
│   ├── schemas.py                   # Pydantic schemas
│   ├── auth_utils.py                # Authentication utilities
│   ├── main.py                      # Application entry point
│   └── requirements.txt             # Python dependencies
│
├── flutter_app/                     # Mobile app (Flutter/Dart)
│   ├── lib/                        # Dart source code
│   │   ├── core/                   # Core functionality
│   │   │   ├── database/          # Local database
│   │   │   ├── di/                # Dependency injection
│   │   │   ├── navigation/        # Navigation utilities
│   │   │   ├── network/           # API client
│   │   │   ├── positioning/       # PDR engine
│   │   │   ├── services/          # App services
│   │   │   ├── storage/           # Secure storage
│   │   │   └── theme/             # App theme
│   │   │
│   │   ├── features/              # Feature modules
│   │   │   ├── admin/            # Admin features
│   │   │   ├── auth/             # Authentication
│   │   │   ├── buildings/        # Building management
│   │   │   ├── home/             # Home screen
│   │   │   ├── navigation/       # AR navigation
│   │   │   ├── offline/          # Offline mode
│   │   │   ├── profile/          # User profile
│   │   │   └── splash/           # Splash screen
│   │   │
│   │   ├── models/                # Data models
│   │   └── main.dart              # App entry point
│   │
│   ├── android/                    # Android configuration
│   ├── ios/                        # iOS configuration
│   ├── scripts/                    # Utility scripts
│   │   ├── run_flutter_app.bat    # Windows run script
│   │   ├── run_flutter_app.sh     # Unix run script
│   │   ├── install_flutter.bat    # Flutter installation
│   │   └── fix_google_maps.bat    # Google Maps fix
│   │
│   ├── test/                       # Unit tests
│   ├── pubspec.yaml                # Flutter dependencies
│   └── README.md                   # Flutter app documentation
│
├── admin-web/                       # Admin web interface (React)
│   ├── src/                        # React source code
│   │   ├── components/            # React components
│   │   ├── context/               # React context
│   │   └── App.js                 # Main app component
│   │
│   ├── public/                     # Static assets
│   ├── package.json                # Node dependencies
│   └── README.md                   # Admin web documentation
│
├── deployment/                      # Deployment scripts
│   └── deploy_fix.sh               # Deployment fix script
│
├── docs/                           # Documentation
│   ├── API_DOCUMENTATION.md        # API reference
│   └── SETUP.md                    # Setup instructions
│
├── .vscode/                        # VS Code configuration
├── README.md                       # Main project documentation
└── PROJECT_STRUCTURE.md            # This file
```

## Key Principles

### 1. Separation of Concerns
- **Backend**: All Python/FastAPI code in `backend/`
- **Mobile**: All Flutter/Dart code in `flutter_app/`
- **Admin Web**: All React code in `admin-web/`
- **Documentation**: All docs in `docs/`
- **Deployment**: All deployment scripts in `deployment/`

### 2. Backend Organization
```
backend/
├── routers/      # API endpoints (controllers)
├── services/     # Business logic
├── scripts/      # Utility scripts
├── tests/        # Test collections
├── models.py     # Data models
├── schemas.py    # Request/response schemas
└── main.py       # Entry point
```

### 3. Flutter Organization (Clean Architecture)
```
flutter_app/lib/
├── core/         # Core functionality (DI, network, storage)
├── features/     # Feature modules (presentation, domain, data)
├── models/       # Shared data models
└── main.dart     # Entry point
```

### 4. Scripts Organization
- **Backend scripts**: `backend/scripts/`
- **Flutter scripts**: `flutter_app/scripts/`
- **Deployment scripts**: `deployment/`

## Running the Application

### Backend
```bash
# From project root
python backend/scripts/run_backend.py

# Or from backend directory
cd backend
python scripts/run_backend.py

# Or manually
cd backend
python -m uvicorn main:app --reload
```

### Flutter App
```bash
# From project root
cd flutter_app
flutter run

# Or using script (Windows)
flutter_app/scripts/run_flutter_app.bat
```

### Admin Web
```bash
cd admin-web
npm install
npm start
```

## Admin Utilities

### Create Admin User
```bash
cd backend
python scripts/create_admin.py
```

### Reset Password
```bash
cd backend
python scripts/reset_password.py
```

## Testing

### API Tests
Import test collections from `backend/tests/` into Postman:
- `Indoor_Navigation_API.postman_collection.json` - Full API suite
- `AUTH_TEST_COLLECTION.json` - Auth tests
- `TEST_ROLE_BASED_AUTH.json` - Role-based access tests

### Flutter Tests
```bash
cd flutter_app
flutter test
```

## Development Workflow

### Backend Development
1. Navigate to `backend/`
2. Activate virtual environment
3. Make changes to routers, services, or models
4. Test using Postman collections in `backend/tests/`
5. Run server: `python -m uvicorn main:app --reload`

### Flutter Development
1. Navigate to `flutter_app/`
2. Make changes in `lib/`
3. Hot reload: Press `r` in terminal
4. Hot restart: Press `R` in terminal
5. Full rebuild: `flutter run`

### Admin Web Development
1. Navigate to `admin-web/`
2. Make changes in `src/`
3. Auto-reload is enabled with `npm start`

## Best Practices

### ✅ DO
- Keep backend code in `backend/`
- Keep Flutter code in `flutter_app/`
- Keep admin web code in `admin-web/`
- Use scripts directories for utility scripts
- Keep tests with their respective projects
- Document API changes in `docs/API_DOCUMENTATION.md`

### ❌ DON'T
- Mix backend and frontend code
- Put scripts in root directory
- Put test files in root directory
- Put documentation files in root directory
- Commit virtual environments or build artifacts

## File Locations Quick Reference

| File Type | Location |
|-----------|----------|
| Backend API | `backend/routers/` |
| Backend Models | `backend/models.py` |
| Backend Scripts | `backend/scripts/` |
| Backend Tests | `backend/tests/` |
| Flutter Code | `flutter_app/lib/` |
| Flutter Scripts | `flutter_app/scripts/` |
| Admin Web | `admin-web/src/` |
| Documentation | `docs/` |
| Deployment | `deployment/` |

## Dependencies

### Backend
- Python 3.8+
- FastAPI
- MongoDB (Atlas)
- See `backend/requirements.txt` for full list

### Flutter
- Flutter SDK 3.0+
- Dart 3.0+
- See `flutter_app/pubspec.yaml` for full list

### Admin Web
- Node.js 14+
- React 18+
- See `admin-web/package.json` for full list

## Environment Variables

### Backend
Set in `backend/.env` or environment:
- `MONGODB_URL` - MongoDB connection string
- `SECRET_KEY` - JWT secret key
- `ALGORITHM` - JWT algorithm (HS256)

### Flutter
Set in `flutter_app/lib/core/config/`:
- API base URL
- Google Maps API key (in AndroidManifest.xml)

## Maintenance

### Updating Dependencies

**Backend:**
```bash
cd backend
pip install -r requirements.txt --upgrade
pip freeze > requirements.txt
```

**Flutter:**
```bash
cd flutter_app
flutter pub upgrade
```

**Admin Web:**
```bash
cd admin-web
npm update
```

## Support

For issues or questions:
1. Check `docs/SETUP.md` for setup instructions
2. Check `docs/API_DOCUMENTATION.md` for API reference
3. Review this structure document for file locations
4. Check individual README files in each directory
