# AR Navigation - Quick Reference Guide

## Feature Summary
Real-time AR navigation with visual footstep guidance, directional arrows, and audio instructions for indoor navigation - Pokémon GO style.

## User Experience Flow

```
┌─────────────────────────────────────────────────────────┐
│ 1. SELECT BUILDING (from Buildings page)                │
│    → Shows list of available buildings                  │
└────────────┬────────────────────────────────────────────┘
             ↓
┌─────────────────────────────────────────────────────────┐
│ 2. OPEN SMART NAVIGATION                                │
│    → Shows building name and navigation options         │
└────────────┬────────────────────────────────────────────┘
             ↓
┌─────────────────────────────────────────────────────────┐
│ 3. SELECT START LOCATION                                │
│    → Shows all rooms/locations in building              │
│    → Grouped by floor                                   │
│    → Search functionality                               │
└────────────┬────────────────────────────────────────────┘
             ↓
┌─────────────────────────────────────────────────────────┐
│ 4. SELECT DESTINATION                                   │
│    → Shows available destinations (excluding start)     │
│    → Same UI as start location selection                │
└────────────┬────────────────────────────────────────────┘
             ↓
┌─────────────────────────────────────────────────────────┐
│ 5. ROUTE CALCULATED                                     │
│    → Shows waypoints in preview                         │
│    → Progress indicator                                 │
│    → [START AR NAVIGATION] button appears               │
└────────────┬────────────────────────────────────────────┘
             ↓
┌─────────────────────────────────────────────────────────┐
│ 6. AR NAVIGATION VIEW OPENS                             │
│                                                         │
│  ┌─────────────────────────────────────────────────┐  │
│  │  📷 CAMERA FEED                    ⚙️ ✖️        │  │
│  │                                                 │  │
│  │        ↓ (Footsteps overlay)                   │  │
│  │       👣👣👣👣                                 │  │
│  │                                                 │  │
│  │        ➜ (Arrow pointing forward)               │  │
│  │                                                 │  │
│  │  🎯 Milestone: 2/5 | Floor 1                  │  │
│  │  ▭▭▭▭▭▭▯▯▯▯ 40% Complete                      │  │
│  │                                                 │  │
│  │  ┌──────────────────────────────────────────┐ │  │
│  │  │ 🔊 🔁 ◀ ▶ ✓                               │ │  │
│  │  │ Audio  Repeat Prev Next                   │ │  │
│  │  └──────────────────────────────────────────┘ │  │
│  └─────────────────────────────────────────────────┘  │
│                                                         │
│    Features:                                           │
│    • Footsteps guide path                              │
│    • Arrow points to next waypoint                     │
│    • Audio: "Continue straight 20 meters"             │
│    • Compass shows heading alignment                  │
│    • Milestone tracker shows progress                 │
│    • Voice announces each milestone reached            │
└────────────┬────────────────────────────────────────────┘
             ↓
┌─────────────────────────────────────────────────────────┐
│ 7. FOLLOW GUIDANCE                                      │
│    → Follow animated footsteps                         │
│    → Listen to audio instructions                      │
│    → Watch arrow for direction                         │
│    → Check milestone progress                          │
│    → Milestones auto-advance or manual control         │
└────────────┬────────────────────────────────────────────┘
             ↓
┌─────────────────────────────────────────────────────────┐
│ 8. ARRIVAL                                              │
│    → "You have arrived!" celebration                   │
│    → Audio announces destination name                  │
│    → [GO HOME] button returns to buildings             │
└─────────────────────────────────────────────────────────┘
```

## UI Components Overview

### Top Bar
- Close button (with exit confirmation)
- Building name
- Destination info
- Settings button

### AR Overlays (Camera View)
1. **Footsteps** - Animated path footprints
2. **Arrow** - Direction indicator with distance
3. **Compass** - Heading display (top-right)
4. **Milestone Indicator** - Progress tracking (bottom)
5. **Audio Indicator** - Shows when TTS playing (top-left)

### Bottom Control Panel
- **Audio Toggle** - Turn voice on/off
- **Repeat Button** - Replay current instruction
- **Previous Button** - Go to previous waypoint
- **Next Button** / **Arrived Button** - Advance or finish

### Settings Panel (Slide-over)
- Audio Guidance toggle
- Show Footsteps toggle
- Show Arrow toggle
- Show Compass toggle
- Exit Navigation button

## Key Features

| Feature | Description | Trigger |
|---------|-------------|---------|
| **Footsteps** | Animated path guide | Real-time, follows heading |
| **Direction Arrow** | Points to next waypoint | Real-time, updates with compass |
| **Audio Guidance** | Turn-by-turn instructions | On start, milestone, completion |
| **Milestone Detection** | Auto-advances at waypoint | Step count threshold reached |
| **Progress Tracking** | Visual progress indicator | Updated as steps taken |
| **Compass Alignment** | Shows if facing right way | Compass heading vs. target |
| **Haptic Feedback** | Vibrations for events | Milestone reached, arrival |
| **Settings Panel** | Customize overlays | Slide-over menu |

## Technical Architecture

```
┌──────────────────────────────────────────────────────────┐
│                   UI Layer                               │
│  ┌────────────────────────────────────────────────────┐ │
│  │ EnhancedARNavigationViewPage (Main UI)             │ │
│  │ • Camera preview                                   │ │
│  │ • AR overlay composition                           │ │
│  │ • Control panels                                   │ │
│  └────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────┐ │
│  │ AR Overlay Widgets                                 │ │
│  │ • ArFootstepsOverlay                               │ │
│  │ • ArDirectionArrow                                 │ │
│  │ • ArCompassIndicator                               │ │
│  │ • ArMilestoneIndicator                             │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────┬───────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│                 State Management Layer                    │
│  ┌────────────────────────────────────────────────────┐ │
│  │ ARGuidanceBloc                                     │ │
│  │ • Tracks state (Ready, Complete, Error, etc.)    │ │
│  │ • Processes user events                           │ │
│  │ • Calculates guidance data                        │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────┬───────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│                   Service Layer                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ AudioFeedbackService (Singleton)                  │ │
│  │ • Text-to-speech conversion                       │ │
│  │ • Direction/distance formatting                   │ │
│  │ • TTS lifecycle management                        │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────┬───────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────┐
│                  Sensor Integration                       │
│  ┌──────────────┬──────────────┬──────────────────────┐ │
│  │ Compass      │ GPS/Position │ Pedometer/Steps      │ │
│  │ (Heading)    │ (Location)   │ (Step Count)         │ │
│  └──────────────┴──────────────┴──────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

## BLoC Event Flow

```
InitializeARGuidance
    ↓
    → Load route steps
    → Initialize sensors
    → Create ready state
    ↓
UpdateUserHeading (continuous from compass)
    ↓
    → Update user heading
    → Check alignment
    ↓
UpdateUserPosition (continuous from GPS/pedometer)
    ↓
    → Update position
    → Check milestone progress
    → Possibly emit MilestoneReached
    ↓
MoveToNextMilestone (manual or auto)
    ↓
    → Advance step index
    → Reset counters
    → Announce next step
    ↓
[Loop back to heading/position updates]
    ↓
NavigationCompleted (reached destination)
    ↓
    → Emit completion state
    → Announce arrival
```

## Data Flow

```
Sensors (Real-time)
├── Compass → userHeading (0-360°)
├── GPS → latitude, longitude
└── Pedometer → stepCount

ARGuidanceBloc
├── Calculate targetHeading (from current step direction)
├── Calculate distanceToTarget (remaining steps)
├── Calculate progress (currentStep / totalSteps)
├── Check alignment (|userHeading - targetHeading| < 15°)
└── Check milestone (stepsTaken >= stepRequired)

UI Rendering
├── Draw footsteps in userHeading direction
├── Draw arrow at targetHeading
├── Update compass display with userHeading
├── Update milestone progress bar
└── Display current instruction
```

## Code Examples

### Start AR Navigation
```dart
// In SmartNavigationPage
ElevatedButton.icon(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedARNavigationViewPage(
          routeSteps: _routeSteps,
          buildingName: widget.buildingName,
          startNode: _currentLocation!,
          endNode: _destination!,
        ),
      ),
    );
  },
  icon: const Icon(Icons.cameras_alt),
  label: const Text('Start AR Navigation'),
),
```

### Handle State Changes
```dart
BlocConsumer<ARGuidanceBloc, ARGuidanceState>(
  listener: (context, state) {
    if (state is MilestoneReached) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reached: ${state.milestoneName}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  },
  builder: (context, state) {
    if (state is ARGuidanceReady) {
      return Stack(
        children: [
          ArFootstepsOverlay(
            userHeading: state.userHeading,
            currentStepIndex: state.currentStepIndex,
          ),
          ArDirectionArrow(
            targetHeading: state.targetHeading,
            userHeading: state.userHeading,
          ),
        ],
      );
    }
    return Container();
  },
)
```

## Common Parameters

### ARGuidanceReady State
```dart
currentStepIndex      // 0-based index of current waypoint
totalSteps           // Total waypoints in route
userHeading          // Current compass heading (0-360°)
targetHeading        // Heading to next waypoint
distanceToTarget     // Remaining distance/steps
currentInstruction   // Text instruction for current step
currentMilestoneName  // Name of current waypoint
nextMilestoneName    // Name of next waypoint
progress             // 0.0-1.0 overall progress
isDirectionAligned   // User facing correct direction
audioEnabled         // Audio on/off status
```

## Key Constants & Calculations

```dart
// Direction alignment
const ALIGNMENT_THRESHOLD = 15;  // degrees

// Default distances
const DEFAULT_STEP_DISTANCE = 20;  // steps per waypoint

// Animation timings
const FOOTSTEP_ANIMATION = 2000;  // ms
const ARROW_PULSE_ANIMATION = 1500;  // ms
const MILESTONE_DISPLAY = 2000;  // ms

// GPS/Sensor filters
const GPS_DISTANCE_FILTER = 2;  // meters
const COMPASS_UPDATE_FREQUENCY = 100;  // ms
```

## Troubleshooting

### AR overlays not showing
- Check `_showFootsteps`, `_showArrow`, `_showCompass` flags
- Verify state is `ARGuidanceReady`
- Check camera is initialized

### Audio not playing
- Verify `_audioEnabled` is true
- Check device volume
- Verify `AudioFeedbackService.initialize()` called
- Check language permissions

### Heading not updating
- Verify compass permissions granted
- Check device compass calibration
- Ensure `_compassSubscription` active

### Steps not counting
- Verify pedometer permissions
- Check device has accelerometer
- Verify `_pedometerSubscription` active

### Position not updating
- Verify location permissions
- Check device location services enabled
- Verify GPS signal available

## Testing Tips

1. **Simulate Compass** - Rotate device to test heading updates
2. **Simulate Steps** - Use pedometer simulator or walk
3. **Simulate Position** - Use location spoofing app
4. **Test Audio** - Verify TTS engine working
5. **Test Overlays** - Toggle settings to verify rendering
6. **Test Navigation** - Use Previous/Next to test flow

## Performance Notes

- **BLoC** processes events asynchronously
- **Sensor updates** throttled by OS
- **Canvas painting** optimized with shouldRepaint
- **Animations** use TickerProvider for efficiency
- **Audio** uses singleton to avoid multiple TTS instances
- **Camera** disposed properly to prevent memory leaks

## Dependencies

```yaml
flutter_tts: ^0.45.0           # Text-to-speech
camera: ^0.10.0                 # Camera access
flutter_compass: ^0.8.0         # Compass heading
geolocator: ^9.0.0              # GPS location
pedometer: ^3.0.0               # Step counter
flutter_bloc: ^8.0.0            # State management
```

## Related Files

- `lib/features/ar_navigation/presentation/bloc/ar_guidance_bloc.dart`
- `lib/features/ar_navigation/presentation/bloc/ar_guidance_event.dart`
- `lib/features/ar_navigation/presentation/bloc/ar_guidance_state.dart`
- `lib/features/ar_navigation/presentation/pages/enhanced_ar_navigation_view.dart`
- `lib/features/ar_navigation/presentation/widgets/ar_overlay_widgets.dart`
- `lib/features/ar_navigation/data/services/audio_feedback_service.dart`
- `lib/features/navigation/presentation/pages/smart_navigation_page.dart` (updated)

---

**Version**: 1.0  
**Last Updated**: January 2026  
**Status**: Implementation Complete
