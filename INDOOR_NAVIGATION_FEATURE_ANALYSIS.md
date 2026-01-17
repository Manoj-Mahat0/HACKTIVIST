# Indoor Navigation Feature Analysis & Implementation Plan

## Feature Implementation Status

Based on analysis of `backend/routers/indoor_graph.py` (2202 lines), here's the current status of all 18 documented features:

---

## ✅ FULLY IMPLEMENTED FEATURES

### 1. QR Code at each node ✅
**Status:** Fully Implemented
**Location:** Lines 371-374, 700-750, 1082-1150
**Implementation:**
- Auto-generation: `generate_qr_code_data(building_id, node_id)` → `indoor-nav://{building_id}/{node_id}`
- QR lookup endpoint: `GET /buildings/{building_id}/indoor-graph/qr-lookup`
- QR export endpoint: `GET /buildings/{building_id}/qr-markers/export`
- Stored in `IndoorGraphNode.qr_code` field

**Side:** Admin (creation) + User (scanning)

---

### 2. Landmark photos ✅
**Status:** Fully Implemented
**Location:** Lines 95-100, 700-750
**Implementation:**
- `image_url` field on each node
- `landmark_description` field for text descriptions
- Landmark change detection via crowdsourced reports
- Admin endpoint for reviewing landmark changes

**Side:** Admin (upload) + User (view)

---

### 3. Turn-by-turn animation data ✅
**Status:** Fully Implemented
**Location:** Lines 870-920
**Implementation:**
- Animation data in route instructions: `{"type": "arrow", "direction": "S", "angle": 180}`
- Direction-to-angle conversion: `_direction_to_angle()`
- Celebration animation at destination

**Side:** User (display)

---

### 4. ETA calculation ✅
**Status:** Fully Implemented
**Location:** Lines 330-350
**Implementation:**
- `calculate_eta(total_steps, step_length, walking_speed)`
- Returns: `distance_meters`, `time_seconds`, `time_formatted`
- Adjustable based on user preferences
- Live delay adjustments in smart routes

**Side:** User (display)

---

### 5. Accessibility routes (wheelchair-friendly) ✅
**Status:** Fully Implemented
**Location:** Lines 230-300, 700-750
**Implementation:**
- `is_accessible` flag on nodes and edges
- `accessible_only` parameter in Floyd-Warshall
- Precomputed `accessible_paths` stored in graph
- Emergency exit routes support accessibility filter

**Side:** Admin (configuration) + User (routing)

---

### 6. Dead reckoning fallback ✅
**Status:** Fully Implemented
**Location:** Lines 1570-1650
**Implementation:**
- `POST /dead-reckoning/calculate` endpoint
- Estimates position from last known node + steps + direction
- Returns possible nodes with confidence scores
- Falls back to lat/lng estimation if no match

**Side:** User (positioning)

---

### 7. Magnetic field calibration ✅
**Status:** Partially Implemented (Backend only)
**Location:** Lines 1530-1555
**Implementation:**
- `POST /buildings/{building_id}/magnetic-calibration` - save calibration
- `GET /buildings/{building_id}/magnetic-calibration` - retrieve calibration
- In-memory storage (should be MongoDB)

**Side:** Admin (calibration) + User (compass correction)
**Missing:** Flutter integration for actual compass calibration

---

### 8. Step length personalization ✅
**Status:** Fully Implemented
**Location:** Lines 355-365, 1555-1570
**Implementation:**
- `UserPreferences` schema with `step_length`, `walking_speed`, `height_cm`
- `calculate_step_length_from_height(height_cm)` - 41% of height formula
- Route calculations accept custom step_length parameter

**Side:** User (preferences)

---

### 9. Crowd density data ✅
**Status:** Fully Implemented
**Location:** Lines 45-80, 430-530, 1660-1720
**Implementation:**
- `crowd_level` field on edges (0-5 scale)
- Live congestion reports with decay (15 min)
- `POST /buildings/{building_id}/indoor-graph/crowd-density` - update
- `GET /buildings/{building_id}/live-conditions` - real-time data
- Crowdsourced travel reports auto-calculate crowd levels

**Side:** Admin (manual) + User (crowdsourced) + System (auto-calculation)

---

### 10. Emergency exit routes ✅
**Status:** Fully Implemented
**Location:** Lines 1000-1080
**Implementation:**
- `is_emergency_exit` flag on nodes
- `GET /buildings/{building_id}/indoor-graph/emergency-exit` endpoint
- Finds nearest exit from any location
- Supports accessibility filter
- Returns all exits with distances

**Side:** Admin (marking exits) + User (emergency navigation)

---

### 11. Graph validation ✅
**Status:** Fully Implemented
**Location:** Lines 380-450
**Implementation:**
- `validate_graph()` function checks:
  - Disconnected nodes (no edges)
  - Dead ends (single connection)
  - Missing reverse edges
  - Inaccessible nodes
  - Graph connectivity (BFS)
- `GET /buildings/{building_id}/indoor-graph/validate` endpoint
- Auto-validation on save

**Side:** Admin (validation)

---

### 12. Bulk import/export ✅
**Status:** Fully Implemented
**Location:** Lines 1415-1500
**Implementation:**
- `GET /buildings/{building_id}/indoor-graph/export` - JSON export
- `POST /buildings/{building_id}/indoor-graph/import` - JSON import
- QR markers export: JSON and CSV formats
- Content-Disposition headers for file download

**Side:** Admin (import/export)

---

### 13. Version history ✅
**Status:** Fully Implemented
**Location:** Lines 1300-1410
**Implementation:**
- `_graph_versions` stores last 10 versions per building
- `GET /buildings/{building_id}/indoor-graph/versions` - list versions
- `POST /buildings/{building_id}/indoor-graph/rollback/{version}` - restore
- Auto-saves version on each update

**Side:** Admin (version management)

---

### 14. A/B testing routes ⚠️
**Status:** NOT IMPLEMENTED
**Documented but no code exists**

**Side:** Admin (configuration) + User (routing) + System (analytics)

---

### 15. Favorite destinations ✅
**Status:** Fully Implemented
**Location:** Lines 1155-1220
**Implementation:**
- `POST /favorites` - add favorite
- `GET /favorites` - list favorites
- `DELETE /favorites/{node_id}` - remove
- In-memory storage (should be MongoDB)
- Keeps last 20 favorites

**Side:** User (personalization)

---

### 16. Recent routes ✅
**Status:** Fully Implemented
**Location:** Lines 1220-1250
**Implementation:**
- `POST /recent-routes` - save route
- `GET /recent-routes` - list recent
- In-memory storage (should be MongoDB)
- Keeps last 10 routes

**Side:** User (history)

---

### 17. Share location ✅
**Status:** Fully Implemented
**Location:** Lines 1250-1300
**Implementation:**
- `POST /share-location` - generate share link
- `GET /share-location/{share_id}` - retrieve shared location
- Expiration support (configurable minutes)
- Custom messages
- Link format: `https://nav.app/share/{share_id}`

**Side:** User (sharing)

---

### 18. Haptic feedback patterns ✅
**Status:** Fully Implemented
**Location:** Lines 180-230, 365-380, 1720-1730
**Implementation:**
- `HAPTIC_PATTERNS` dictionary with 7 patterns:
  - turn_left, turn_right, go_straight, arrived, warning, floor_change, recalculating
- `get_haptic_for_direction_change()` - smart pattern selection
- `GET /haptic-patterns` - list all patterns
- Included in route instructions

**Side:** User (feedback)

---

## ❌ UNIMPLEMENTED FEATURES

### 14. A/B Testing Routes
**Status:** NOT IMPLEMENTED
**Priority:** Medium
**Complexity:** High

**Required Implementation:**

#### Admin Side:
- Create A/B test experiments (define route variants)
- Set user allocation percentages
- View test results and analytics
- End tests and select winners

#### User Side:
- Automatic assignment to test groups
- Route variant selection based on group
- Silent tracking of route completion

#### Backend:
- Experiment model and storage
- User group assignment logic
- Analytics collection
- Statistical significance calculation

---

## ⚠️ PARTIALLY IMPLEMENTED / NEEDS IMPROVEMENT

### 7. Magnetic Field Calibration
**Current:** Backend endpoints only
**Missing:**
- Flutter integration for compass calibration
- Per-floor calibration data
- Calibration wizard UI
- Automatic calibration detection

### Storage Issues (Multiple Features)
**Current:** In-memory dictionaries
**Should be:** MongoDB collections
**Affected:**
- `_user_favorites`
- `_user_recent_routes`
- `_shared_locations`
- `_graph_versions`
- `_magnetic_calibration`
- `_live_congestion_reports`
- `_travel_time_reports`
- `_landmark_change_reports`
- `_blocked_paths`
- `_route_anomalies`

---

## IMPLEMENTATION PLAN

### Phase 1: Critical Fixes (1-2 weeks)
**Priority:** HIGH

1. **Migrate In-Memory Storage to MongoDB**
   - Create MongoDB models for all in-memory stores
   - Add TTL indexes for auto-expiring data
   - Migrate existing endpoints
   - Side: Backend

2. **Complete Magnetic Calibration**
   - Add Flutter compass calibration service
   - Create calibration wizard UI
   - Store per-floor calibration data
   - Side: Admin + User (Flutter)

### Phase 2: A/B Testing Routes (2-3 weeks)
**Priority:** MEDIUM

1. **Backend Implementation**
   ```python
   # New models needed:
   class ABTestExperiment(Document):
       building_id: ObjectId
       name: str
       description: str
       variants: List[RouteVariant]  # Different route algorithms/preferences
       allocation: Dict[str, float]  # variant_id -> percentage
       status: str  # draft, active, completed
       start_date: datetime
       end_date: Optional[datetime]
       winner: Optional[str]
   
   class UserTestAssignment(Document):
       user_id: ObjectId
       experiment_id: ObjectId
       variant_id: str
       assigned_at: datetime
   
   class TestResult(Document):
       experiment_id: ObjectId
       variant_id: str
       user_id: ObjectId
       route_completed: bool
       completion_time: int
       user_satisfaction: Optional[int]
       timestamp: datetime
   ```

2. **Admin UI (Web)**
   - Experiment creation form
   - Variant configuration
   - Real-time results dashboard
   - Statistical analysis view

3. **User Integration (Flutter)**
   - Automatic variant assignment
   - Silent result tracking
   - Optional satisfaction survey

### Phase 3: Enhanced Features (3-4 weeks)
**Priority:** LOW

1. **Advanced Analytics Dashboard**
   - Route usage heatmaps
   - Crowd pattern analysis
   - Peak time predictions
   - Side: Admin

2. **Predictive Routing**
   - ML-based crowd prediction
   - Time-of-day routing optimization
   - Side: System + User

3. **Social Features**
   - Follow friends' locations (with permission)
   - Group navigation
   - Side: User

---

## FEATURE CATEGORIZATION BY SIDE

### Admin Only (7 features)
1. Graph validation
2. Bulk import/export
3. Version history
4. Magnetic calibration (setup)
5. Emergency exit marking
6. Landmark photo upload
7. A/B test management

### User Only (6 features)
1. Favorite destinations
2. Recent routes
3. Share location
4. Haptic feedback
5. Step length personalization
6. Dead reckoning

### Shared (Admin + User) (5 features)
1. QR codes (admin creates, user scans)
2. Accessibility routes (admin configures, user uses)
3. Crowd density (admin monitors, user reports/views)
4. ETA calculation (admin configures defaults, user sees)
5. Turn-by-turn animation (admin configures, user views)

---

## SUMMARY TABLE

| # | Feature | Status | Admin | User | Priority |
|---|---------|--------|-------|------|----------|
| 1 | QR Code at each node | ✅ | ✓ | ✓ | - |
| 2 | Landmark photos | ✅ | ✓ | ✓ | - |
| 3 | Turn-by-turn animation | ✅ | - | ✓ | - |
| 4 | ETA calculation | ✅ | - | ✓ | - |
| 5 | Accessibility routes | ✅ | ✓ | ✓ | - |
| 6 | Dead reckoning | ✅ | - | ✓ | - |
| 7 | Magnetic calibration | ⚠️ | ✓ | ✓ | HIGH |
| 8 | Step length personalization | ✅ | - | ✓ | - |
| 9 | Crowd density | ✅ | ✓ | ✓ | - |
| 10 | Emergency exit routes | ✅ | ✓ | ✓ | - |
| 11 | Graph validation | ✅ | ✓ | - | - |
| 12 | Bulk import/export | ✅ | ✓ | - | - |
| 13 | Version history | ✅ | ✓ | - | - |
| 14 | A/B testing routes | ❌ | ✓ | ✓ | MEDIUM |
| 15 | Favorite destinations | ✅ | - | ✓ | - |
| 16 | Recent routes | ✅ | - | ✓ | - |
| 17 | Share location | ✅ | - | ✓ | - |
| 18 | Haptic feedback | ✅ | - | ✓ | - |

**Legend:**
- ✅ Fully Implemented
- ⚠️ Partially Implemented
- ❌ Not Implemented
