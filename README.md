# Indoor Navigation AR/VR App

A Flutter-based mobile application for indoor navigation using AR/VR technology with FastAPI backend.

## Features

- **User App**: AR-based indoor navigation with real-time positioning
- **Admin Panel**: 3D building structure creation using GPS coordinates
- **AI-powered 3D modeling**: Automatic 3D model generation from coordinates
- **Real-time navigation**: Step-by-step indoor directions

## Tech Stack

- **Mobile**: Flutter (Cross-platform), ARCore, GPS Location
- **Backend**: FastAPI (Python), MongoDB Atlas, AI/ML models
- **Admin Web**: React + Material-UI

## Project Structure

```
indoor-navigation-app/
├── backend/                    # FastAPI backend
│   ├── routers/               # API route handlers
│   ├── services/              # Business logic services
│   ├── scripts/               # Backend utility scripts
│   │   ├── run_backend.py    # Quick start script
│   │   ├── restart_backend.bat
│   │   ├── create_admin.py   # Admin user management
│   │   └── reset_password.py # Password reset utility
│   ├── tests/                 # API test collections
│   ├── models.py              # Database models
│   ├── schemas.py             # Pydantic schemas
│   ├── auth_utils.py          # Authentication utilities
│   ├── main.py                # Application entry point
│   └── requirements.txt       # Python dependencies
├── flutter_app/               # Flutter mobile app
│   ├── lib/                   # Dart source code
│   ├── android/               # Android configuration
│   ├── ios/                   # iOS configuration
│   └── scripts/               # Flutter utility scripts
│       ├── run_flutter_app.bat
│       ├── run_flutter_app.sh
│       ├── install_flutter.bat
│       └── fix_google_maps.bat
├── admin-web/                 # Admin web interface
│   ├── src/                   # React source code
│   └── package.json           # Node dependencies
├── deployment/                # Deployment scripts
│   └── deploy_fix.sh
├── docs/                      # Documentation
│   ├── API_DOCUMENTATION.md
│   └── SETUP.md
└── README.md                  # This file
```

## Quick Start

### Backend
```bash
# Option 1: Using the script
python backend/scripts/run_backend.py

# Option 2: Manual
cd backend
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Admin Web
```bash
cd admin-web
npm install
npm start
```

### Flutter App
```bash
cd flutter_app
flutter pub get
flutter run
```

## Admin User Management

Create admin users or reset passwords:

```bash
cd backend

# Create a new admin user
python create_admin.py

# Reset user password
python reset_password.py
```

## API Documentation

Once the backend is running, visit:
- **API Docs**: http://localhost:8000/docs
- **Alternative Docs**: http://localhost:8000/redoc

## Testing

API test collections are available in `backend/tests/`:
- `Indoor_Navigation_API.postman_collection.json` - Full API test suite
- `AUTH_TEST_COLLECTION.json` - Authentication tests
- `TEST_ROLE_BASED_AUTH.json` - Role-based access tests

Import these into Postman or any API testing tool.

## Clean Architecture

The project uses a clean, modern architecture:
- ✅ **Flutter** for cross-platform mobile support
- ✅ **MongoDB Atlas** for cloud database
- ✅ **GPS-based coordinates** (lat/lng/floor)
- ✅ **Clean Architecture** with BLoC pattern
- ✅ **Dependency Injection** with GetIt
- ✅ **Secure Storage** for authentication
- ✅ **Proper separation** of backend, frontend, and mobile code