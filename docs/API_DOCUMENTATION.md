# Indoor Navigation API - Complete Documentation

## 📌 Base URL
```
http://localhost:8000
```

## 🔐 Authentication
All endpoints (except `/auth/register` and `/auth/token`) require JWT token in header:
```
Authorization: Bearer <token>
```

---

## 🔑 Authentication Endpoints

### 1. **Register User**
```http
POST /auth/register
Content-Type: application/json

{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "securepassword123"
}
```

**Response (201):**
```json
{
  "id": "507f1f77bcf86cd799439011",
  "username": "john_doe",
  "email": "john@example.com",
  "is_admin": false,
  "created_at": "2024-01-10T10:30:00"
}
```

---

### 2. **Login User**
```http
POST /auth/token
Content-Type: application/x-www-form-urlencoded

username=john_doe&password=securepassword123
```

**Response (200):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

---

### 3. **Get Current User**
```http
GET /auth/me
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "id": "507f1f77bcf86cd799439011",
  "username": "john_doe",
  "email": "john@example.com",
  "is_admin": false,
  "created_at": "2024-01-10T10:30:00"
}
```

---

## 🏢 Building Endpoints

### 1. **Get All Buildings**
```http
GET /buildings/
Authorization: Bearer <token>
```

**Response (200):**
```json
[
  {
    "id": "507f1f77bcf86cd799439012",
    "name": "Tech Park Building A",
    "description": "Modern office building",
    "address": "123 Tech Street, Silicon Valley",
    "latitude": 37.3382,
    "longitude": -121.8863,
    "created_at": "2024-01-10T10:30:00"
  },
  {
    "id": "507f1f77bcf86cd799439013",
    "name": "Shopping Mall",
    "description": "Multi-story shopping center",
    "address": "456 Market Ave, Downtown",
    "latitude": 37.3345,
    "longitude": -121.8900,
    "created_at": "2024-01-10T11:00:00"
  }
]
```

---

### 2. **Get Building Details**
```http
GET /buildings/{building_id}
Authorization: Bearer <token>
```

**Response (200):**
```json
{
  "id": "507f1f77bcf86cd799439012",
  "name": "Tech Park Building A",
  "description": "Modern office building",
  "address": "123 Tech Street, Silicon Valley",
  "latitude": 37.3382,
  "longitude": -121.8863,
  "created_at": "2024-01-10T10:30:00"
}
```

---

### 3. **Create Building (Admin Only)**
```http
POST /buildings/
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "name": "New Office Building",
  "description": "State-of-the-art office space",
  "address": "789 Innovation Drive",
  "latitude": 37.3400,
  "longitude": -121.8850
}
```

**Response (201):**
```json
{
  "id": "507f1f77bcf86cd799439014",
  "name": "New Office Building",
  "description": "State-of-the-art office space",
  "address": "789 Innovation Drive",
  "latitude": 37.3400,
  "longitude": -121.8850,
  "created_at": "2024-01-10T12:00:00"
}
```

---

### 4. **Get Building Floors**
```http
GET /buildings/{building_id}/floors
Authorization: Bearer <token>
```

**Response (200):**
```json
[
  {
    "id": "507f1f77bcf86cd799439020",
    "building_id": "507f1f77bcf86cd799439012",
    "floor_number": 0,
    "name": "Ground Floor",
    "height": 3.0
  },
  {
    "id": "507f1f77bcf86cd799439021",
    "building_id": "507f1f77bcf86cd799439012",
    "floor_number": 1,
    "name": "First Floor",
    "height": 3.0
  }
]
```

---

### 5. **Create Floor (Admin Only)**
```http
POST /buildings/{building_id}/floors
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "floor_number": 2,
  "name": "Second Floor",
  "height": 3.5
}
```

**Response (201):**
```json
{
  "id": "507f1f77bcf86cd799439022",
  "building_id": "507f1f77bcf86cd799439012",
  "floor_number": 2,
  "name": "Second Floor",
  "height": 3.5
}
```

---

## 🚪 Room Endpoints

### 1. **Get Floor Rooms**
```http
GET /buildings/floors/{floor_id}/rooms
Authorization: Bearer <token>
```

**Response (200):**
```json
[
  {
    "id": "507f1f77bcf86cd799439030",
    "floor_id": "507f1f77bcf86cd799439020",
    "name": "Conference Room A",
    "room_type": "meeting_room",
    "coordinates": {
      "lat": 37.3382,
      "lng": -121.8863,
      "floor": 0,
      "width": 50.0,
      "length": 40.0
    }
  },
  {
    "id": "507f1f77bcf86cd799439031",
    "floor_id": "507f1f77bcf86cd799439020",
    "name": "Office 101",
    "room_type": "office",
    "coordinates": {
      "lat": 37.3383,
      "lng": -121.8864,
      "floor": 0,
      "width": 30.0,
      "length": 25.0
    }
  }
]
```

---

### 2. **Create Room (Admin Only)**
```http
POST /buildings/floors/{floor_id}/rooms
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "name": "Cafeteria",
  "room_type": "cafeteria",
  "coordinates": {
    "lat": 37.3384,
    "lng": -121.8865,
    "floor": 0,
    "width": 100.0,
    "length": 80.0
  }
}
```

**Response (201):**
```json
{
  "id": "507f1f77bcf86cd799439032",
  "floor_id": "507f1f77bcf86cd799439020",
  "name": "Cafeteria",
  "room_type": "cafeteria",
  "coordinates": {
    "lat": 37.3384,
    "lng": -121.8865,
    "floor": 0,
    "width": 100.0,
    "length": 80.0
  }
}
```

---

## 🧭 Waypoint Endpoints

### 1. **Get Floor Waypoints**
```http
GET /buildings/floors/{floor_id}/waypoints
Authorization: Bearer <token>
```

**Response (200):**
```json
[
  {
    "id": "507f1f77bcf86cd799439040",
    "floor_id": "507f1f77bcf86cd799439020",
    "latitude": 37.3382,
    "longitude": -121.8863,
    "floor_number": 0,
    "waypoint_type": "entrance",
    "name": "Main Entrance"
  },
  {
    "id": "507f1f77bcf86cd799439041",
    "floor_id": "507f1f77bcf86cd799439020",
    "latitude": 37.3383,
    "longitude": -121.8864,
    "floor_number": 0,
    "waypoint_type": "junction",
    "name": "Corridor Junction"
  }
]
```

---

### 2. **Create Waypoint (Admin Only)**
```http
POST /buildings/floors/{floor_id}/waypoints
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "latitude": 37.3385,
  "longitude": -121.8866,
  "floor_number": 0,
  "waypoint_type": "exit",
  "name": "Emergency Exit"
}
```

**Response (201):**
```json
{
  "id": "507f1f77bcf86cd799439042",
  "floor_id": "507f1f77bcf86cd799439020",
  "latitude": 37.3385,
  "longitude": -121.8866,
  "floor_number": 0,
  "waypoint_type": "exit",
  "name": "Emergency Exit"
}
```

---

## 🗺️ Navigation Endpoints

### 1. **Get Navigation Path**
```http
POST /navigation/navigate
Authorization: Bearer <token>
Content-Type: application/json

{
  "building_id": "507f1f77bcf86cd799439012",
  "start_latitude": 37.3382,
  "start_longitude": -121.8863,
  "start_floor": 0,
  "destination_room_name": "Conference Room A"
}
```

**Response (200):**
```json
{
  "path": [
    {
      "latitude": 37.3382,
      "longitude": -121.8863,
      "floor_number": 0
    },
    {
      "latitude": 37.3383,
      "longitude": -121.8864,
      "floor_number": 0
    },
    {
      "latitude": 37.3384,
      "longitude": -121.8865,
      "floor_number": 0
    }
  ],
  "distance": 245.5,
  "estimated_time": 175,
  "instructions": [
    "Head to the nearest waypoint",
    "Navigate to Conference Room A",
    "You have arrived at your destination"
  ]
}
```

---

### 2. **Get AR Markers**
```http
GET /navigation/buildings/{building_id}/ar-markers
Authorization: Bearer <token>
```

**Response (200):**
```json
[
  {
    "id": "507f1f77bcf86cd799439050",
    "latitude": 37.3382,
    "longitude": -121.8863,
    "floor_number": 0,
    "type": "qr_code",
    "data": "MARKER_001",
    "description": "Main Entrance QR Code"
  },
  {
    "id": "507f1f77bcf86cd799439051",
    "latitude": 37.3383,
    "longitude": -121.8864,
    "floor_number": 0,
    "type": "beacon",
    "data": "BEACON_A1",
    "description": "Corridor Beacon"
  }
]
```

---

## 🤖 Admin Endpoints

### 1. **Generate 3D Model from Coordinates**
```http
POST /admin/buildings/{building_id}/generate-3d
Authorization: Bearer <admin_token>
Content-Type: application/json

[
  {
    "latitude": 37.3382,
    "longitude": -121.8863,
    "floor_number": 0
  },
  {
    "latitude": 37.3383,
    "longitude": -121.8864,
    "floor_number": 0
  },
  {
    "latitude": 37.3384,
    "longitude": -121.8865,
    "floor_number": 0
  },
  {
    "latitude": 37.3382,
    "longitude": -121.8863,
    "floor_number": 1
  }
]
```

**Response (200):**
```json
{
  "message": "3D model generated successfully",
  "rooms_created": 6,
  "waypoints_created": 12,
  "model_data": {
    "floors": [
      {
        "number": 0,
        "height": 3.0,
        "coordinates": [...]
      },
      {
        "number": 1,
        "height": 3.0,
        "coordinates": [...]
      }
    ],
    "rooms": [...],
    "waypoints": [...]
  }
}
```

---

### 2. **Get Analytics**
```http
GET /admin/analytics/buildings
Authorization: Bearer <admin_token>
```

**Response (200):**
```json
{
  "total_buildings": 5,
  "total_floors": 12,
  "total_rooms": 48,
  "total_waypoints": 96,
  "buildings": [
    {
      "id": "507f1f77bcf86cd799439012",
      "name": "Tech Park Building A",
      "description": "Modern office building",
      "address": "123 Tech Street, Silicon Valley",
      "latitude": 37.3382,
      "longitude": -121.8863,
      "created_at": "2024-01-10T10:30:00"
    },
    ...
  ]
}
```

---

## ❌ Error Responses

### **400 Bad Request**
```json
{
  "detail": "Invalid input data"
}
```

### **401 Unauthorized**
```json
{
  "detail": "Could not validate credentials"
}
```

### **403 Forbidden**
```json
{
  "detail": "Not enough permissions"
}
```

### **404 Not Found**
```json
{
  "detail": "Building not found"
}
```

### **500 Internal Server Error**
```json
{
  "detail": "Internal server error"
}
```

---

## 📊 Coordinate System

### **GPS Coordinates**
- **Latitude (X)**: North/South position (-90 to +90)
- **Longitude (Y)**: East/West position (-180 to +180)
- **Floor (Z)**: Vertical level (0 = Ground, 1 = First, etc)

### **Example Coordinates**
```
Building Location: (37.3382, -121.8863, 0)
- Latitude: 37.3382° N
- Longitude: 121.8863° W
- Floor: 0 (Ground Floor)
```

---

## 🔄 Request/Response Flow

```
1. Client sends request with JWT token
   ↓
2. Backend validates token
   ↓
3. Backend checks user permissions
   ↓
4. Backend processes request
   ↓
5. Backend queries MongoDB
   ↓
6. Backend returns response
   ↓
7. Client receives and processes response
```

---

## 🧪 Testing with cURL

### **Register User**
```bash
curl -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123"
  }'
```

### **Login**
```bash
curl -X POST http://localhost:8000/auth/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=testuser&password=password123"
```

### **Get Buildings**
```bash
curl -X GET http://localhost:8000/buildings/ \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

### **Get Navigation**
```bash
curl -X POST http://localhost:8000/navigation/navigate \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "building_id": "507f1f77bcf86cd799439012",
    "start_latitude": 37.3382,
    "start_longitude": -121.8863,
    "start_floor": 0,
    "destination_room_name": "Conference Room A"
  }'
```

---

## 📝 Notes

- All timestamps are in UTC format (ISO 8601)
- Distances are in meters
- Times are in seconds
- Coordinates use WGS84 (GPS standard)
- JWT tokens expire after 30 minutes
- All endpoints return JSON responses
- Pagination not implemented in MVP