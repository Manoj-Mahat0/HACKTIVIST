import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection_container.dart';
import '../bloc/ar_guidance_bloc.dart';
import '../bloc/ar_guidance_event.dart';
import '../bloc/ar_guidance_state.dart';
import '../widgets/ar_overlay_widgets.dart';
import '../../data/services/audio_feedback_service.dart';

/// Enhanced AR Navigation View - Pokémon GO Style with Full AR Guidance
/// Shows camera with AR overlay including footsteps, directional arrow, and audio cues
class EnhancedARNavigationViewPage extends StatefulWidget {
  final List<RouteStep> routeSteps;
  final String buildingName;
  final NavigationNode startNode;
  final NavigationNode endNode;

  const EnhancedARNavigationViewPage({
    super.key,
    required this.routeSteps,
    required this.buildingName,
    required this.startNode,
    required this.endNode,
  });

  @override
  State<EnhancedARNavigationViewPage> createState() =>
      _EnhancedARNavigationViewPageState();
}

class _EnhancedARNavigationViewPageState
    extends State<EnhancedARNavigationViewPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Camera
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  // Sensors
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<StepCount>? _pedometerSubscription;
  StreamSubscription<Position>? _positionSubscription;

  // Animation controllers
  late AnimationController _arrowPulseController;
  late AnimationController _footstepController;
  late Animation<double> _arrowPulseAnimation;
  late Animation<double> _footstepAnimation;

  // UI State
  bool _showSettings = false;
  bool _audioEnabled = true;
  bool _showFootsteps = true;
  bool _showArrow = true;
  bool _showCompass = true;

  // Current sensor readings
  double _currentHeading = 0;
  Position? _currentPosition;
  int _stepCount = 0;

  late ARGuidanceBloc _guidanceBloc;
  late AudioFeedbackService _audioService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _initializeControllers();
    _initializeCamera();
    _initializeSensors();
    _initializeBloc();
  }

  void _initializeControllers() {
    _arrowPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _arrowPulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _arrowPulseController, curve: Curves.easeInOut),
    );

    _footstepController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _footstepAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _footstepController, curve: Curves.linear),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('❌ Camera init error: $e');
    }
  }

  void _initializeSensors() {
    // Compass
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (mounted && event.heading != null) {
        _currentHeading = event.heading!;
        _guidanceBloc.add(UpdateUserHeading(_currentHeading));
      }
    });

    // Pedometer
    try {
      _pedometerSubscription = Pedometer.stepCountStream.listen((event) {
        if (mounted) {
          setState(() {
            _stepCount = event.steps;
          });
          _guidanceBloc.add(UpdateUserPosition(
            x: _currentPosition?.latitude ?? 0,
            y: _currentPosition?.longitude ?? 0,
            stepCount: event.steps,
          ));
        }
      });
    } catch (e) {
      debugPrint('⚠️ Pedometer error: $e');
    }

    // GPS
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((position) {
      if (mounted) {
        _currentPosition = position;
        _guidanceBloc.add(UpdateUserPosition(
          x: position.latitude,
          y: position.longitude,
          stepCount: _stepCount,
        ));
      }
    });
  }

  void _initializeBloc() {
    _guidanceBloc = getIt<ARGuidanceBloc>();
    _audioService = AudioFeedbackService();

    _guidanceBloc.add(InitializeARGuidance(
      routeSteps: widget.routeSteps,
      buildingName: widget.buildingName,
      startNode: widget.startNode,
      endNode: widget.endNode,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isCameraInitialized || _cameraController == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _cameraController!.initialize().then((_) {
          if (mounted) setState(() {});
        });
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
        _cameraController?.dispose();
        break;
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _compassSubscription?.cancel();
    _pedometerSubscription?.cancel();
    _positionSubscription?.cancel();
    _arrowPulseController.dispose();
    _footstepController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocConsumer<ARGuidanceBloc, ARGuidanceState>(
        bloc: _guidanceBloc,
        listener: _handleStateChanges,
        builder: (context, state) {
          return Stack(
            children: [
              // Camera Preview
              _buildCameraPreview(),

              // AR Overlays
              if (state is ARGuidanceReady) ...[
                // Footsteps overlay
                if (_showFootsteps)
                  ArFootstepsOverlay(
                    animationController: _footstepController,
                    animation: _footstepAnimation,
                    userHeading: state.userHeading,
                    currentStepIndex: state.currentStepIndex,
                    totalSteps: state.totalSteps,
                  ),

                // Direction arrow overlay
                if (_showArrow)
                  ArDirectionArrow(
                    pulseController: _arrowPulseController,
                    pulseAnimation: _arrowPulseAnimation,
                    targetHeading: state.targetHeading,
                    userHeading: state.userHeading,
                    distanceToTarget: state.distanceToTarget,
                    instruction: state.currentInstruction,
                  ),

                // Compass indicator
                if (_showCompass)
                  ArCompassIndicator(
                    userHeading: state.userHeading,
                    targetHeading: state.targetHeading,
                  ),

                // Milestone indicator
                ArMilestoneIndicator(
                  currentStep: state.currentStepIndex,
                  totalSteps: state.totalSteps,
                  currentMilestoneName: state.currentMilestoneName,
                  nextMilestoneName: state.nextMilestoneName,
                  progress: state.progress,
                ),

                // Top info bar
                _buildTopInfoBar(state),
              ],

              // Audio indicator
              if (state is AudioInstructionPlaying)
                AudioIndicator(
                  isPlaying: state.isPlaying,
                  instruction: state.instruction,
                ),

              // Bottom controls
              if (state is ARGuidanceReady) _buildBottomControls(context, state),

              // Loading state
              if (state is ARGuidanceInitial) _buildLoadingState(),

              // Error state
              if (state is ARGuidanceError) _buildErrorState(state),

              // Settings panel
              if (_showSettings) _buildSettingsPanel(),

              // Completion overlay
              if (state is NavigationCompleted) _buildCompletionOverlay(state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primaryOrange),
              SizedBox(height: 16),
              Text(
                'Initializing camera...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize?.height ?? 100,
          height: _cameraController!.value.previewSize?.width ?? 100,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildTopInfoBar(ARGuidanceReady state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Close button
            GestureDetector(
              onTap: _showExitConfirmation,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),

            // Building and destination info
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.buildingName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'To: ${widget.endNode.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Settings button
            GestureDetector(
              onTap: () => setState(() => _showSettings = !_showSettings),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.settings, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, ARGuidanceReady state) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Audio toggle
              _buildIconButton(
                icon: state.audioEnabled ? Icons.volume_up : Icons.volume_off,
                label: state.audioEnabled ? 'Audio On' : 'Audio Off',
                onPressed: () {
                  setState(() => _audioEnabled = !_audioEnabled);
                  _guidanceBloc.add(ToggleAudioGuidance(_audioEnabled));
                },
              ),

              // Request instruction
              _buildIconButton(
                icon: Icons.speaker_notes,
                label: 'Repeat',
                onPressed: () {
                  _guidanceBloc.add(const RequestAudioInstruction());
                },
              ),

              // Previous step
              if (state.currentStepIndex > 0)
                _buildIconButton(
                  icon: Icons.arrow_back,
                  label: 'Previous',
                  onPressed: () {
                    _guidanceBloc.add(const MoveToPreviousMilestone());
                  },
                ),

              // Next step
              if (state.currentStepIndex < state.totalSteps - 1)
                _buildIconButton(
                  icon: Icons.arrow_forward,
                  label: 'Next',
                  onPressed: () {
                    _guidanceBloc.add(const MoveToNextMilestone());
                  },
                )
              else
                _buildIconButton(
                  icon: Icons.check_circle,
                  label: 'Arrived',
                  onPressed: null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: onPressed != null ? AppColors.primaryOrange : Colors.grey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSettingsPanel() {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width * 0.7,
      child: Container(
        color: Colors.black.withOpacity(0.95),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AR Settings',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showSettings = false),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSettingTile(
                  'Audio Guidance',
                  'Voice instructions',
                  _audioEnabled,
                  (value) {
                    setState(() => _audioEnabled = value);
                    _guidanceBloc.add(ToggleAudioGuidance(value));
                  },
                ),
                const Divider(color: Colors.white24),
                _buildSettingTile(
                  'Show Footsteps',
                  'Display animated footsteps',
                  _showFootsteps,
                  (value) {
                    setState(() => _showFootsteps = value);
                    _guidanceBloc.add(UpdateRouteVisibility(
                      showRoute: true,
                      showFootsteps: value,
                      showArrow: _showArrow,
                    ));
                  },
                ),
                const Divider(color: Colors.white24),
                _buildSettingTile(
                  'Show Arrow',
                  'Direction indicator',
                  _showArrow,
                  (value) {
                    setState(() => _showArrow = value);
                    _guidanceBloc.add(UpdateRouteVisibility(
                      showRoute: true,
                      showFootsteps: _showFootsteps,
                      showArrow: value,
                    ));
                  },
                ),
                const Divider(color: Colors.white24),
                _buildSettingTile(
                  'Show Compass',
                  'Heading indicator',
                  _showCompass,
                  (value) => setState(() => _showCompass = value),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showExitConfirmation,
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Exit Navigation'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryOrange),
            SizedBox(height: 16),
            Text(
              'Initializing AR Navigation...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ARGuidanceError state) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Navigation Error',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionOverlay(NavigationCompleted state) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.celebration,
              size: 80,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            Text(
              'You have arrived!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Welcome to ${state.destinationName}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _guidanceBloc.add(const ExitARNavigation());
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.home),
              label: const Text('Go Home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleStateChanges(BuildContext context, ARGuidanceState state) {
    if (state is MilestoneReached) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reached: ${state.milestoneName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (state is NavigationCompleted) {
      HapticFeedback.heavyImpact();
    } else if (state is ARGuidanceError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Exit Navigation?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to stop navigating?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _guidanceBloc.add(const ExitARNavigation());
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
