import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../core/theme/app_theme.dart';

/// Animated footsteps overlay showing direction of travel
class ArFootstepsOverlay extends StatefulWidget {
  final List<Map<String, dynamic>> route;
  final int currentIndex;
  final double userHeading;
  final bool showFootsteps;

  const ArFootstepsOverlay({
    super.key,
    required this.route,
    required this.currentIndex,
    required this.userHeading,
    this.showFootsteps = true,
  });

  @override
  State<ArFootstepsOverlay> createState() => _ArFootstepsOverlayState();
}

class _ArFootstepsOverlayState extends State<ArFootstepsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showFootsteps || widget.route.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 200,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            size: Size(MediaQuery.of(context).size.width, 300),
            painter: FootstepsPainter(
              progress: _animation.value,
              direction: widget.userHeading,
            ),
          );
        },
      ),
    );
  }
}

class FootstepsPainter extends CustomPainter {
  final double progress;
  final double direction;

  FootstepsPainter({required this.progress, required this.direction});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryOrange.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final angle = (direction - 90) * math.pi / 180;

    // Draw 3 footsteps
    for (int i = 0; i < 3; i++) {
      final opacity = 1.0 - (i * 0.3) - progress * 0.4;
      if (opacity <= 0) continue;

      paint.color = AppColors.primaryOrange.withOpacity(opacity);

      final distance = 40.0 + (i * 50) + (progress * 50);
      final offset = Offset(
        center.dx + math.cos(angle) * distance,
        center.dy + math.sin(angle) * distance,
      );

      // Alternate left and right foot
      final lateralOffset = (i % 2 == 0 ? -10.0 : 10.0);
      final footOffset = Offset(
        offset.dx + math.cos(angle + math.pi / 2) * lateralOffset,
        offset.dy + math.sin(angle + math.pi / 2) * lateralOffset,
      );

      _drawFootprint(canvas, footOffset, angle, paint);
    }
  }

  void _drawFootprint(Canvas canvas, Offset position, double angle, Paint paint) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(angle);

    // Draw simple footprint shape
    final path = Path()
      ..addOval(Rect.fromCenter(center: Offset.zero, width: 20, height: 30));
    canvas.drawPath(path, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(FootstepsPainter oldDelegate) =>
      progress != oldDelegate.progress || direction != oldDelegate.direction;
}

/// Pulsing arrow pointing to next waypoint
class ArDirectionArrow extends StatefulWidget {
  final Map<String, dynamic>? currentWaypoint;
  final Map<String, dynamic> nextWaypoint;
  final bool showArrow;

  const ArDirectionArrow({
    super.key,
    this.currentWaypoint,
    required this.nextWaypoint,
    this.showArrow = true,
  });

  @override
  State<ArDirectionArrow> createState() => _ArDirectionArrowState();
}

class _ArDirectionArrowState extends State<ArDirectionArrow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _calculateDistance() {
    if (widget.currentWaypoint == null) return 0.0;
    final dx = (widget.nextWaypoint['latitude'] ?? 0.0) - (widget.currentWaypoint!['latitude'] ?? 0.0);
    final dy = (widget.nextWaypoint['longitude'] ?? 0.0) - (widget.currentWaypoint!['longitude'] ?? 0.0);
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showArrow) return const SizedBox.shrink();

    final distance = _calculateDistance();
    final targetName = widget.nextWaypoint['label'] ?? 'Next Point';

    return Positioned(
      top: 150,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Arrow
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryOrange.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_upward,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Distance and name
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${distance.toStringAsFixed(1)}m',
                          style: const TextStyle(
                            color: AppColors.primaryOrange,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          targetName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Compass indicator showing user's heading
class ArCompassIndicator extends StatelessWidget {
  final double currentHeading;
  final double targetHeading;
  final bool showCompass;

  const ArCompassIndicator({
    super.key,
    required this.currentHeading,
    required this.targetHeading,
    this.showCompass = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showCompass) return const SizedBox.shrink();

    return Positioned(
      top: 100,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compass rose
            SizedBox(
              width: 80,
              height: 80,
              child: CustomPaint(
                painter: CompassPainter(
                  heading: currentHeading,
                  targetHeading: targetHeading,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Heading text
            Text(
              '${currentHeading.toInt()}°',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _getCardinalDirection(currentHeading),
              style: const TextStyle(
                color: AppColors.primaryOrange,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCardinalDirection(double degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) / 45).floor() % 8;
    return directions[index];
  }
}

class CompassPainter extends CustomPainter {
  final double heading;
  final double targetHeading;

  CompassPainter({required this.heading, required this.targetHeading});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw compass circle
    final circlePaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 5, circlePaint);

    // Draw cardinal directions
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    final directions = ['N', 'E', 'S', 'W'];
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90 - heading) * math.pi / 180;
      final x = center.dx + math.cos(angle - math.pi / 2) * (radius - 15);
      final y = center.dy + math.sin(angle - math.pi / 2) * (radius - 15);

      textPainter.text = TextSpan(
        text: directions[i],
        style: TextStyle(
          color: i == 0 ? AppColors.primaryOrange : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }

    // Draw target direction indicator
    final targetAngle = (targetHeading - heading) * math.pi / 180;
    final targetPaint = Paint()
      ..color = AppColors.primaryOrange
      ..style = PaintingStyle.fill;

    final targetPath = Path()
      ..moveTo(center.dx, center.dy - radius + 10)
      ..lineTo(center.dx - 8, center.dy - radius + 25)
      ..lineTo(center.dx + 8, center.dy - radius + 25)
      ..close();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(targetAngle);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(targetPath, targetPaint);
    canvas.restore();

    // Draw heading indicator (user direction)
    final headingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final headingPath = Path()
      ..moveTo(center.dx, center.dy - radius + 5)
      ..lineTo(center.dx - 6, center.dy - radius + 20)
      ..lineTo(center.dx + 6, center.dy - radius + 20)
      ..close();

    canvas.drawPath(headingPath, headingPaint);
  }

  @override
  bool shouldRepaint(CompassPainter oldDelegate) =>
      heading != oldDelegate.heading || targetHeading != oldDelegate.targetHeading;
}

/// Progress indicator showing current step and total steps
class ArMilestoneIndicator extends StatelessWidget {
  final List<Map<String, dynamic>> route;
  final int currentIndex;
  final String buildingName;

  const ArMilestoneIndicator({
    super.key,
    required this.route,
    required this.currentIndex,
    required this.buildingName,
  });

  @override
  Widget build(BuildContext context) {
    if (route.isEmpty) return const SizedBox.shrink();

    final progress = route.length > 1 ? currentIndex / (route.length - 1) : 0.0;
    final currentNode = currentIndex < route.length ? route[currentIndex] : route.last;
    final currentInstruction = 'Go to ${currentNode['label']}';

    return Positioned(
      bottom: 120,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryOrange,
                      ),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${currentIndex + 1}/${route.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Current instruction
            Row(
              children: [
                const Icon(
                  Icons.directions_walk,
                  color: AppColors.primaryOrange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentInstruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Audio indicator showing when audio is playing
class AudioIndicator extends StatefulWidget {
  final bool isPlaying;
  final String instruction;
  final bool audioEnabled;

  const AudioIndicator({
    super.key,
    required this.isPlaying,
    required this.instruction,
    this.audioEnabled = true,
  });

  @override
  State<AudioIndicator> createState() => _AudioIndicatorState();
}

class _AudioIndicatorState extends State<AudioIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    if (widget.isPlaying) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AudioIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying || !widget.audioEnabled || widget.instruction.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 220,
      left: 20,
      right: 20,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated sound waves
                ...List.generate(3, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      width: 4,
                      height: 16 + (_controller.value * 12) * (index + 1) / 3,
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 12),
                // Instruction text
                Flexible(
                  child: Text(
                    widget.instruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Destination reached celebration overlay
class DestinationReachedOverlay extends StatefulWidget {
  final String destinationName;
  final VoidCallback onDismiss;

  const DestinationReachedOverlay({
    super.key,
    required this.destinationName,
    required this.onDismiss,
  });

  @override
  State<DestinationReachedOverlay> createState() =>
      _DestinationReachedOverlayState();
}

class _DestinationReachedOverlayState extends State<DestinationReachedOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryOrange.withOpacity(0.9),
                    AppColors.primaryOrange.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 80,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Destination Reached!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.destinationName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: widget.onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryOrange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
