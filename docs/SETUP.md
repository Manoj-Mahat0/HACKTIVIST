# Indoor Navigation AR/VR App Setup Guide

## Prerequisites

- Python 3.8+
- Node.js 16+
- Android Studio (for mobile app)
- MongoDB Atlas account (or local MongoDB)
- Git

## Backend Setup (FastAPI + MongoDB)

1. Navigate to backend directory:
```bash
cd backend
```

2. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Run the server:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`
API documentation: `http://localhost:8000/docs`

**MongoDB Connection**: The app uses MongoDB Atlas with the provided connection string. No additional setup required.

## Admin Web Interface Setup

1. Navigate to admin-web directory:
```bash
cd admin-web
```

2. Install dependencies:
```bash
npm install
```

3. Start development server:
```bash
npm start
```

The admin panel will be available at `http://localhost:3000`

## Mobile App Setup (Android)

1. Open Android Studio
2. Open the `mobile-app` directory as a project
3. Sync Gradle files
4. Update the API base URL in `NetworkModule.kt`:
   - For emulator: `http://10.0.2.2:8000/`
   - For real device: `http://YOUR_COMPUTER_IP:8000/`
5. Build and run on device/emulator

## Coordinate System

The app uses a GPS-based coordinate system:
- **X coordinate**: Latitude (GPS latitude)
- **Y coordinate**: Longitude (GPS longitude)  
- **Z coordinate**: Floor number (0 = ground floor, 1 = first floor, etc.)

## Features Included in MVP

### Backend (FastAPI + MongoDB)
- User authentication (JWT)
- Building/floor/room management with GPS coordinates
- Navigation path calculation using GPS
- AR marker management
- Admin analytics
- AI-powered 3D model generation from GPS coordinates

### Mobile App (Kotlin)
- **User Features**:
  - AR camera integration (ARCore ready)
  - Real-time GPS-based navigation
  - Building selection
  - Path visualization
  - User authentication
- **Admin Features** (for admin users):
  - GPS coordinate collection using device location
  - Manual coordinate input
  - Floor-by-floor mapping
  - Real-time 3D model generation
  - Building structure creation

### Admin Web Interface
- Dashboard with analytics
- 3D model generator from GPS coordinates
- Building management
- Real-time data visualization

## Admin Access

### Mobile App Admin Panel
1. Register/login as admin user (set `is_admin: true` in MongoDB)
2. Admin users will see an additional "Admin Panel" button
3. Use GPS location or manual input to collect building coordinates
4. Generate 3D models directly from the mobile app

### Web Admin Panel
- Access via browser at `http://localhost:3000`
- Create buildings and generate 3D structures
- View analytics and manage data

## Initial Data Setup

1. Start the backend server
2. Register a user and set `is_admin: true` in MongoDB
3. Use either mobile admin panel or web interface to:
   - Create buildings
   - Collect GPS coordinates
   - Generate 3D models
4. Use the mobile app to test navigation

## GPS Coordinate Collection

### Mobile App (Recommended)
1. Open admin panel in mobile app
2. Walk around the building perimeter and rooms
3. Use "Add Current GPS Location" to collect coordinates
4. Change floor number as you move between floors
5. Generate 3D model when done

### Manual Input
- Enter latitude/longitude coordinates manually
- Specify floor numbers for multi-story buildings
- Use sample coordinates for testing

## Next Steps for Production

1. **Enhanced AR Features**:
   - Full ARCore integration with GPS
   - 3D path visualization in AR space
   - Real-time position tracking with GPS + IMU

2. **AI Improvements**:
   - Advanced room detection from GPS clusters
   - Machine learning for optimal pathfinding
   - Computer vision for automatic indoor mapping

3. **VR Support**:
   - VR headset compatibility
   - Immersive navigation experience
   - Virtual building tours

4. **Advanced Features**:
   - Multi-language support
   - Offline navigation with cached maps
   - Voice commands and accessibility
   - Integration with building management systems

## Troubleshooting

- **CORS Issues**: Backend allows all origins for development
- **ARCore Issues**: Ensure device supports ARCore and permissions granted
- **GPS Issues**: Ensure location permissions and GPS enabled
- **MongoDB Issues**: Check connection string and network access
- **Admin Access**: Manually set `is_admin: true` in MongoDB user document