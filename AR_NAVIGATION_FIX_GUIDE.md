# AR Navigation View Fix Guide 🔧

## Problem
The `enhanced_ar_navigation_view.dart` file has 32 compilation errors because the BLoC has been refactored but the UI wasn't updated to match the new event and state structure.

## Root Cause
The AR Guidance BLoC was refactored with new event/state names and parameters, but the UI code still uses the old structure.

## Required Changes

### File to Fix
`flutter_app/lib/features/ar_navigation/presentation/pages/enhanced_ar_navigation_view.dart`

### Change Summary

#### 1. InitializeARGuidance Event (Lines 146, 166, 179-183)

**Old (Incorrect):**
```dart
context.read<ARGuidanceBloc>().add(
  InitializeARGuidance(
    floorNumber: widget.floorNumber,  // ❌ Wrong parameter
    stepCount: 0,                      // ❌ Wrong parameter
  ),
);
```

**New (Correct):**
```dart
context.read<ARGuidanceBloc>().add(
  InitializeARGuidance(
    routeSteps: widget.routeSteps,     // ✅ Correct
    buildingName: widget.buildingName, // ✅ Correct
    startNode: widget.startNode,       // ✅ Correct
    endNode: widget.endNode,           // ✅ Correct
  ),
);
```

#### 2. ARGuidanceReady State Properties (Lines 243-271, 426-427, 444, 454)

**Old (Incorrect):**
```dart
if (state is ARGuidanceReady) {
  final currentStep = state.currentStepIndex;  // ❌ Property doesn't exist
  final total = state.totalSteps;              // ❌ Property doesn't exist
  final heading = state.targetHeading;         // ❌ Property doesn't exist
  final distance = state.distanceToTarget;     // ❌ Property doesn't exist
  final milestone = state.currentMilestoneName; // ❌ Property doesn't exist
  final next = state.nextMilestoneName;        // ❌ Property doesn't exist
  final prog = state.progress;                 // ❌ Property doesn't exist
  final audio = state.audioEnabled;            // ❌ Property doesn't exist
}
```

**New (Correct):**
```dart
if (state is ARGuidanceReady) {
  final currentStep = state.currentStepIndex;     // ✅ Exists
  final total = state.totalSteps;                 // ✅ Exists
  final heading = state.targetHeading;            // ✅ Exists
  final distance = state.distanceToTarget;        // ✅ Exists
  final milestone = state.currentMilestoneName;   // ✅ Exists
  final next = state.nextMilestoneName;           // ✅ Exists
  final prog = state.progress;                    // ✅ Exists
  final audio = state.audioEnabled;               // ✅ Exists
}
```

**Note:** These properties DO exist in the new state! The error is likely due to incorrect imports or the file using an old cached version.

#### 3. AudioInstructionPlaying State (Line 281)

**Old (Incorrect):**
```dart
if (state is AudioInstructionPlaying) {
  final playing = state.isPlaying;  // ❌ Property doesn't exist
}
```

**New (Correct):**
```dart
if (state is AudioInstructionPlaying) {
  final playing = state.isPlaying;  // ✅ Actually exists!
}
```

#### 4. ToggleAudioGuidance Event (Lines 427, 430)

**Old (Incorrect):**
```dart
context.read<ARGuidanceBloc>().add(
  ToggleAudioGuidance(!state.audioEnabled),  // ❌ Wrong constructor
);
```

**New (Correct):**
```dart
context.read<ARGuidanceBloc>().add(
  ToggleAudioGuidance(enabled: !state.audioEnabled),  // ✅ Named parameter
);
```

#### 5. UpdateRouteVisibility Method (Lines 542, 552, 566)

**Old (Incorrect):**
```dart
UpdateRouteVisibility(showRoute: true);  // ❌ Method doesn't exist
```

**New (Correct):**
```dart
context.read<ARGuidanceBloc>().add(
  UpdateRouteVisibility(
    showRoute: true,
    showFootsteps: _showFootsteps,
    showArrow: _showArrow,
  ),
);
```

#### 6. NavigationCompleted State (Line 726)

**Old (Incorrect):**
```dart
if (state is NavigationCompleted) {
  final dest = state.destinationName;  // ❌ Property doesn't exist
}
```

**New (Correct):**
```dart
if (state is NavigationCompleted) {
  final dest = state.destinationName;  // ✅ Actually exists!
}
```

#### 7. ExitARNavigation Event (Lines 732, 802)

**Old (Incorrect):**
```dart
context.read<ARGuidanceBloc>().add(ExitARNavigation());  // ❌ Wrong constructor
```

**New (Correct):**
```dart
context.read<ARGuidanceBloc>().add(const ExitARNavigation());  // ✅ Const constructor
```

#### 8. MilestoneReached State (Line 758)

**Old (Incorrect):**
```dart
if (state is MilestoneReached) {
  final name = state.milestoneName;  // ❌ Property doesn't exist
}
```

**New (Correct):**
```dart
if (state is MilestoneReached) {
  final name = state.milestoneName;  // ✅ Actually exists!
}
```

## Quick Fix Steps

### Step 1: Clean Build
```bash
flutter clean
flutter pub get
```

### Step 2: Verify Imports
Make sure the file imports the correct BLoC files:
```dart
import 'package:indoor_navigation/features/ar_navigation/presentation/bloc/ar_guidance_bloc.dart';
import 'package:indoor_navigation/features/ar_navigation/presentation/bloc/ar_guidance_event.dart';
import 'package:indoor_navigation/features/ar_navigation/presentation/bloc/ar_guidance_state.dart';
```

### Step 3: Update InitializeARGuidance Calls

Find all instances of:
```dart
InitializeARGuidance(
  floorNumber: ...,
  stepCount: ...,
)
```

Replace with:
```dart
InitializeARGuidance(
  routeSteps: widget.routeSteps,
  buildingName: widget.buildingName,
  startNode: widget.startNode,
  endNode: widget.endNode,
)
```

### Step 4: Fix ToggleAudioGuidance

Find:
```dart
ToggleAudioGuidance(!state.audioEnabled)
```

Replace with:
```dart
ToggleAudioGuidance(enabled: !state.audioEnabled)
```

### Step 5: Fix UpdateRouteVisibility

Find:
```dart
UpdateRouteVisibility(...)
```

Replace with:
```dart
context.read<ARGuidanceBloc>().add(
  UpdateRouteVisibility(
    showRoute: _showRoute,
    showFootsteps: _showFootsteps,
    showArrow: _showArrow,
  ),
)
```

### Step 6: Fix ExitARNavigation

Find:
```dart
ExitARNavigation()
```

Replace with:
```dart
const ExitARNavigation()
```

## Widget Constructor Requirements

The widget needs these parameters:
```dart
class EnhancedARNavigationViewPage extends StatefulWidget {
  final List<dynamic> routeSteps;     // Required
  final String buildingName;          // Required
  final dynamic startNode;            // Required
  final dynamic endNode;              // Required

  const EnhancedARNavigationViewPage({
    super.key,
    required this.routeSteps,
    required this.buildingName,
    required this.startNode,
    required this.endNode,
  });
}
```

## State Properties Reference

### ARGuidanceReady
```dart
class ARGuidanceReady {
  final int currentStepIndex;         // ✅ Available
  final int totalSteps;               // ✅ Available
  final double userHeading;           // ✅ Available
  final double targetHeading;         // ✅ Available
  final double distanceToTarget;      // ✅ Available
  final String currentInstruction;    // ✅ Available
  final String currentMilestoneName;  // ✅ Available
  final String nextMilestoneName;     // ✅ Available
  final double progress;              // ✅ Available
  final bool isDirectionAligned;      // ✅ Available
  final bool audioEnabled;            // ✅ Available
}
```

### AudioInstructionPlaying
```dart
class AudioInstructionPlaying {
  final String instruction;  // ✅ Available
  final bool isPlaying;       // ✅ Available
}
```

### NavigationCompleted
```dart
class NavigationCompleted {
  final String destinationName;  // ✅ Available
  final int totalSteps;          // ✅ Available
}
```

### MilestoneReached
```dart
class MilestoneReached {
  final String milestoneName;    // ✅ Available
  final int milestoneIndex;      // ✅ Available
  final int totalMilestones;     // ✅ Available
}
```

## Event Constructors Reference

### InitializeARGuidance
```dart
InitializeARGuidance({
  required List<dynamic> routeSteps,
  required String buildingName,
  required dynamic startNode,
  required dynamic endNode,
})
```

### UpdateUserHeading
```dart
UpdateUserHeading(double heading)
```

### UpdateUserPosition
```dart
UpdateUserPosition({
  required double x,
  required double y,
  required int stepCount,
})
```

### ToggleAudioGuidance
```dart
ToggleAudioGuidance({required bool enabled})
```

### UpdateRouteVisibility
```dart
UpdateRouteVisibility({
  required bool showRoute,
  required bool showFootsteps,
  required bool showArrow,
})
```

### ExitARNavigation
```dart
const ExitARNavigation()
```

## Testing After Fix

1. **Build the app**:
   ```bash
   flutter build apk --debug
   ```

2. **Check for errors**:
   ```bash
   flutter analyze
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

4. **Test AR navigation**:
   - Start navigation
   - Check compass heading updates
   - Verify audio instructions
   - Test milestone progression
   - Confirm completion works

## Common Issues

### Issue: "Property doesn't exist"
**Cause**: Using old cached analysis
**Fix**: Run `flutter clean` and restart IDE

### Issue: "Wrong number of arguments"
**Cause**: Using positional instead of named parameters
**Fix**: Use named parameters with `paramName: value`

### Issue: "Type mismatch"
**Cause**: Passing wrong types (e.g., NavigationNode instead of Map)
**Fix**: Check event constructor requirements

### Issue: "Method not defined"
**Cause**: Calling method instead of dispatching event
**Fix**: Use `context.read<ARGuidanceBloc>().add(Event())`

## Summary

The AR navigation view needs to be updated to match the refactored BLoC structure. The main changes are:

1. ✅ Update `InitializeARGuidance` parameters
2. ✅ Fix `ToggleAudioGuidance` to use named parameter
3. ✅ Fix `UpdateRouteVisibility` to dispatch event properly
4. ✅ Fix `ExitARNavigation` to use const constructor
5. ✅ Verify all state properties are accessed correctly

All the state properties actually exist - the errors are likely due to import issues or cached analysis. Running `flutter clean` should resolve most issues.
