# AR Navigation - Visual Architecture & Flow Diagrams

## 1. Component Architecture Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                      APP LAYER                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ SmartNavigationPage (Updated)                            │  │
│  │ • Building selection                                     │  │
│  │ • Location selection (start & destination)              │  │
│  │ • Route calculation                                      │  │
│  │ • [START AR NAVIGATION] Button ←─── NEW                 │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            ↓                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ EnhancedARNavigationViewPage (NEW)                       │  │
│  │ • Camera preview                                         │  │
│  │ • AR overlay management                                  │  │
│  │ • User controls                                          │  │
│  │ • Settings panel                                         │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────────────────────────────┐
│                   UI WIDGETS LAYER (NEW)                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ AR Overlay Widgets (ar_overlay_widgets.dart)            │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │ • ArFootstepsOverlay                                    │   │
│  │ • ArDirectionArrow                                      │   │
│  │ • ArCompassIndicator                                    │   │
│  │ • ArMilestoneIndicator                                  │   │
│  │ • AudioIndicator                                        │   │
│  │ • Custom Painters (5 total)                             │   │
│  └─────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────────────────────────────┐
│                 STATE MANAGEMENT LAYER (NEW)                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ARGuidanceBloc (BLoC Pattern)                           │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │ Events: (10)                                            │   │
│  │ • InitializeARGuidance                                  │   │
│  │ • UpdateUserHeading                                     │   │
│  │ • UpdateUserPosition                                    │   │
│  │ • MoveToNextMilestone / MoveToPreviousMilestone         │   │
│  │ • ToggleAudioGuidance                                   │   │
│  │ • RequestAudioInstruction                               │   │
│  │ • CheckDirectionAlignment                               │   │
│  │ • UpdateRouteVisibility                                 │   │
│  │ • ExitARNavigation                                      │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │ States: (7)                                             │   │
│  │ • ARGuidanceReady ← Main state with all data            │   │
│  │ • MilestoneReached                                      │   │
│  │ • NavigationCompleted                                   │   │
│  │ • AudioInstructionPlaying                               │   │
│  │ • DirectionAlignmentStatus                              │   │
│  │ • RouteVisibilityUpdated                                │   │
│  │ • ARGuidanceError                                       │   │
│  └─────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────────────────────────────┐
│                    SERVICE LAYER (NEW)                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ AudioFeedbackService (Singleton)                        │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │ • initialize()                                          │   │
│  │ • speakInstruction(text)                                │   │
│  │ • speakDistance(meters)                                 │   │
│  │ • speakDirection(direction)                             │   │
│  │ • announceMilestone(name)                               │   │
│  │ • announceArrival(destination)                          │   │
│  │ • stop()                                                │   │
│  │ Uses: Flutter TTS Engine                                │   │
│  └─────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────────────────────────────┐
│                  SENSOR & HARDWARE LAYER                        │
│  ┌──────────────────┬──────────────────┬────────────────────┐  │
│  │ Flutter Compass  │ Geolocator (GPS) │ Pedometer (Steps)  │  │
│  │ Heading 0-360°   │ Latitude/Long    │ Step Count        │  │
│  │ Updates ~100ms   │ Updates ~2m      │ Updates per step   │  │
│  └──────────────────┴──────────────────┴────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Camera (device back camera)                              │  │
│  │ Live preview for AR overlay                              │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

## 2. Data Flow Diagram

```
SENSORS (Real-time input)
    │
    ├─→ Compass ──→ userHeading (0-360°)
    │                     │
    ├─→ GPS ──→ currentPosition (lat, lng)
    │                     │
    └─→ Pedometer ──→ stepCount
                           │
                           ↓
              ┌─────────────────────────┐
              │  ARGuidanceBloc         │
              │  Event Processing       │
              └─────────────────────────┘
                           │
                ┌──────────┼──────────┐
                ↓          ↓          ↓
         Calculate    Check        Update
         Heading      Milestone    Audio
             │            │           │
             ↓            ↓           ↓
     targetHeading   reached?    speak()
             │            │           │
             └──────┬─────┴─────┬─────┘
                    ↓
         ┌──────────────────────────┐
         │ ARGuidanceReady State    │
         │ • userHeading            │
         │ • targetHeading          │
         │ • distance               │
         │ • instruction            │
         │ • progress               │
         │ • isAligned              │
         └──────────────────────────┘
                    │
         ┌──────────┼──────────────────────┐
         ↓          ↓          ↓            ↓
    Footsteps   Arrow      Compass    Milestone
    Overlay     Overlay    Indicator  Indicator
         │          │          │            │
         └──────────┴──────────┴────────────┘
                    ↓
              AR UI Rendered
              on Camera Feed
```

## 3. BLoC State Transitions

```
                    ┌─────────────────┐
                    │ ARGuidanceInit  │
                    └────────┬────────┘
                             │
                             │ InitializeARGuidance
                             ↓
                    ┌────────────────────┐
                    │ ARGuidanceReady    │
                    │ (Navigation Active)│
                    └────────┬───────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
      Position     Heading       Audio
      Update       Update      Command
              │              │              │
              ↓              ↓              ↓
         Distance    Alignment     Instruction
         Updated     Checked         Spoken
              │              │              │
              └──────────────┼──────────────┘
                             ↓
                    ┌────────────────────┐
                    │ ARGuidanceReady    │
                    │ (State Updated)    │
                    └────────┬───────────┘
                             │
                    Milestone Reached?
                      │              │
                      YES            NO
                      │              │
                      ↓              └→ Loop back
         ┌────────────────────────┐
         │ MilestoneReached       │
         │ (Show celebration)     │
         └────────────┬───────────┘
                      │ (2 seconds)
                      ↓
         ┌────────────────────────┐
         │ ARGuidanceReady        │
         │ (Next step)            │
         └────────────┬───────────┘
                      │
                Last Waypoint?
                  │        │
                  NO       YES
                  │        │
                  ↓        ↓
            Continue   ┌──────────────────┐
                      │ NavigationComplete│
                      │ (Show Celebration)│
                      └────────┬──────────┘
                               │
                    ┌──────────┴──────────┐
                    │                     │
              User Actions           Exit Navigation
                    │                     │
                    └──────────┬──────────┘
                               ↓
                    ┌────────────────────┐
                    │ ARNavigationExited │
                    │ Return to Home     │
                    └────────────────────┘
```

## 4. Milestone Detection Flow

```
CURRENT STATE
    │
    ├─ currentStepIndex = 2
    ├─ routeSteps[2].distance = 20 (steps needed)
    └─ stepsTaken = 0
                │
                │ User takes steps
                │ (Pedometer updates)
                │
                ↓
    stepsTaken increments → 5, 10, 15, 20, 21...
                │
                │ ARGuidanceBloc.UpdateUserPosition()
                │
                ↓
         ┌─────────────────────────┐
         │ Check Milestone?        │
         │ if (stepsTaken ≥ 20)    │
         └────────┬────────────────┘
                  │ YES
                  ↓
         ┌─────────────────────────┐
         │ & !hasAnnouncedStep     │
         └────────┬────────────────┘
                  │ TRUE
                  ↓
         ┌─────────────────────────┐
         │ Emit MilestoneReached   │
         │ & Play Audio            │
         │ "You reached..."        │
         └────────┬────────────────┘
                  │
                  ↓ (2 seconds)
         ┌─────────────────────────┐
         │ Advance Step Index      │
         │ currentStepIndex = 3    │
         │ Reset stepsTaken = 0    │
         └────────┬────────────────┘
                  │
                  ↓
         ┌─────────────────────────┐
         │ Return to Ready State   │
         │ (Loop continues)        │
         └─────────────────────────┘
```

## 5. Direction Alignment Detection

```
COMPASS DATA
    │
    ├─ userHeading = 45° (NE)
    └─ targetHeading = 60° (ENE)
                │
                ↓
        ┌───────────────────────┐
        │ Calculate Difference  │
        │ diff = 60 - 45 = 15° │
        └───────┬───────────────┘
                │
                ↓
        ┌──────────────────────────┐
        │ Check Threshold          │
        │ |diff| < 15°?           │
        │ |15| < 15? FALSE        │
        └───────┬──────────────────┘
                │
        ┌───────┴────────┐
        │ NO (not aligned)        │ YES (aligned)
        │                         │
        ↓                         ↓
┌──────────────────┐    ┌──────────────────┐
│ Show Turn Hint   │    │ Show Checkmark   │
│ "Turn right 15°" │    │ ✓ "Aligned"      │
└──────────────────┘    └──────────────────┘
```

## 6. AR Overlay Rendering Pipeline

```
ARGuidanceReady State
    │
    ├─ userHeading: 45°
    ├─ targetHeading: 60°
    ├─ distanceToTarget: 50m
    └─ currentInstruction: "Turn right"
                │
    ┌───────────┼─────────────┬──────────────────┐
    ↓           ↓             ↓                  ↓
Footsteps   Arrow        Compass         Milestone
Overlay     Overlay      Indicator       Indicator
    │           │             │                  │
    ├─ Path     ├─ Direction  ├─ Heading       ├─ Progress
    ├─ Anim     ├─ Distance   ├─ Alignment     ├─ Step info
    └─ Fade     └─ Pulse      └─ Turn hint     └─ Next dest
    │           │             │                  │
    └───────────┴─────────────┴──────────────────┘
            │
            ↓ CustomPaint
    ┌──────────────────────┐
    │ Canvas Drawing       │
    │ • Shapes             │
    │ • Animations         │
    │ • Colors             │
    │ • Effects            │
    └──────────┬───────────┘
               ↓
    ┌──────────────────────────────┐
    │ Rendered on Screen           │
    │ Over Camera Preview          │
    │ Updated every frame (~60 FPS)│
    └──────────────────────────────┘
```

## 7. User Interaction Flow

```
USER ACTIONS                SYSTEM RESPONSE
    │
    ├─ Rotate Device ──→ Compass Heading Updated
    │                           │
    │                           ↓
    │                  Update Arrow Direction
    │                  Check Alignment
    │                  Play Turn Hint Audio
    │
    ├─ Walk Forward ──→ Pedometer Steps Increase
    │                           │
    │                           ↓
    │                  Update Distance Remaining
    │                  Update Footsteps Animation
    │                  Check Milestone
    │
    ├─ Tap "Repeat" ──→ Replay Current Instruction
    │                           │
    │                           ↓
    │                  AudioFeedbackService.speak()
    │
    ├─ Tap "Next" ────→ Advance Step Index
    │                           │
    │                           ↓
    │                  Jump to Next Waypoint
    │                  Update All AR Elements
    │
    ├─ Toggle Audio ──→ _audioEnabled = !_audioEnabled
    │                           │
    │                           ↓
    │                  Stop/Resume Audio Announcements
    │
    ├─ Toggle Overlay ──→ _showFootsteps/Arrow/Compass
    │                           │
    │                           ↓
    │                  Rerender AR Elements
    │
    ├─ Tap "Exit" ────→ Show Confirmation Dialog
    │                           │
    │                           ↓
    │                  ExitARNavigation Event
    │                  Return to Previous Screen
    │
    └─ Reach Destination → NavigationCompleted State
                                  │
                                  ↓
                         Show Celebration UI
                         Play Arrival Audio
                         Offer Home Navigation
```

## 8. Audio Feedback Timeline

```
NAVIGATION LIFECYCLE            AUDIO ANNOUNCEMENTS
                                
Start                           "Navigation started."
  │                             "Follow the arrows."
  │
  ↓
Move Forward (continuous)       [Footsteps audio fades in]
  │
  ↓
Turn Required                   "Turn right 30 degrees."
  │                             [Arrow pulsing louder]
  │
  ↓
Milestone Reached (e.g., at     "You reached Conference Room."
junction)
  │                             [Celebration sound]
  │
  ↓
Continue Forward                [Audio resumes]
  │                             "Continue straight 15 meters."
  │
  ↓
Multiple Milestones             [Repeats for each]
  │
  ↓
Final Milestone                 "Next: Main Entrance"
  │
  ↓
Arrive at Destination           "You have arrived at Main Entrance!"
                                [Victory sound/music]
                                
User can:
  • Toggle Audio Off/On any time
  • Tap "Repeat" to hear instruction again
  • Manually navigate with Previous/Next buttons
```

## 9. Route Step Progression

```
Route: [A] → [B] → [C] → [D] → [E] (Destination)

Initial State:
┌─────────────┐
│ Step 0 (A)  │ ← currentStepIndex = 0
│ ACTIVE      │
└─────────────┘
┌─────────────┐
│ Step 1 (B)  │
│ upcoming    │
└─────────────┘
┌─────────────┐
│ Step 2 (C)  │
│ upcoming    │
└─────────────┘
    ...etc

After Walking:
┌─────────────┐
│ Step 0 (A)  │ ← COMPLETED ✓
│ completed   │
└─────────────┘
┌─────────────┐
│ Step 1 (B)  │ ← currentStepIndex = 1
│ ACTIVE      │
└─────────────┘
┌─────────────┐
│ Step 2 (C)  │
│ upcoming    │
└─────────────┘
    ...etc

At Destination:
┌─────────────┐
│ Step 0 (A)  │ ← COMPLETED ✓
└─────────────┘
┌─────────────┐
│ Step 1 (B)  │ ← COMPLETED ✓
└─────────────┘
┌─────────────┐
│ Step 2 (C)  │ ← COMPLETED ✓
└─────────────┘
┌─────────────┐
│ Step 3 (D)  │ ← COMPLETED ✓
└─────────────┘
┌─────────────┐
│ Step 4 (E)  │ ← ARRIVED! 🎉
│ DESTINATION │
└─────────────┘
```

## 10. Settings Panel Impact

```
SETTING                  OFF              ON
────────────────────────────────────────────────
Footsteps       No footsteps    Animated path
                overlay         guide overlay

Arrow          No direction     Direction arrow
                indicator       + distance label

Compass        No heading       Heading display
                display         + alignment hint

Audio          Silent           Voice guidance
                               + announcements
```

---

These diagrams provide a complete visual understanding of the AR Navigation system architecture, data flow, state transitions, and user interactions.
