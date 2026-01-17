import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// AR Footsteps Overlay
/// Shows animated footsteps along the path to guide user movement
class ArFootstepsOverlay extends StatefulWidget {
  final AnimationController animationController;
  final Animation<double> animation;
  final double userHeading;
  final int currentStepIndex;
  final int totalSteps;

  const ArFootstepsOverlay({
    super.key,
    required this.animationController,
    required this.animation,
    required this.userHeading,
    required this.currentStepIndex,
    required this.totalSteps,
  });

  @override
  State<ArFootstepsOverlay> createState() => _ArFootstepsOverlayState();
}

class _ArFootstepsOverlayState extends State<ArFootstepsOverlay> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        return CustomPaint(
          painter: FootstepsPainter(
            progress: widget.animation.value,
            userHeading: widget.userHeading,
            footstepCount: 5,
          ),
          child: Container(),
        );
      },
    );
  }
}

/// Custom painter for rendering animated footsteps
class FootstepsPainter extends CustomPainter {
  final double progress;
  final double userHeading;
  final int footstepCount;

  FootstepsPainter({
    required this.progress,
    required this.userHeading,
    required this.footstepCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final baseRadius = 100.0;

    // Draw footsteps in an arc pattern
    for (int i = 0; i < footstepCount; i++) {
      final stepProgress = (progress - (i / footstepCount)) % 1.0;
      
      if (stepProgress >= 0 && stepProgress <= 1.0) {
        final distance = baseRadius + (stepProgress * 150);
        final angle = userHeading * (math.pi / 180);
        
        final x = centerX + distance * math.sin(angle);
        final y = centerY - distance * math.cos(angle);
        
        // Opacity fades out as footstep moves forward
        final opacity = 1.0 - (stepProgress * 0.8);
        
        _drawFootprint(canvas, x, y, opacity, 30 - (stepProgress * 15));
      }
    }
  }

  void _drawFootprint(Canvas canvas, double x, double y, double opacity, double size) {
    final paint = Paint()
      ..color = AppColors.primaryOrange.withOpacity(opacity * 0.6)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = AppColors.primaryOrange.withOpacity(opacity * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Main footprint shape (oval)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: size * 0.8, height: size),
      paint,
    );

    // Toe marks
    for (int i = 0; i < 4; i++) {
      final toeX = x - (size * 0.3) + (i * size * 0.2);
      final toeY = y + (size * 0.35);
      canvas.drawCircle(Offset(toeX, toeY), size * 0.15, paint);
    }

    // Border
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: size * 0.8, height: size),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(FootstepsPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.userHeading != userHeading;
}

/// AR Direction Arrow
/// Shows directional arrow pointing toward next waypoint
class ArDirectionArrow extends StatefulWidget {
  final AnimationController pulseController;
  final Animation<double> pulseAnimation;
  final double targetHeading;
  final double userHeading;
  final double distanceToTarget;
  final String instruction;

  const ArDirectionArrow({
    super.key,
    required this.pulseController,
    required this.pulseAnimation,
    required this.targetHeading,
    required this.userHeading,
    required this.distanceToTarget,
    required this.instruction,
  });

  @override
  State<ArDirectionArrow> createState() => _ArDirectionArrowState();
}

class _ArDirectionArrowState extends State<ArDirectionArrow> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.pulseAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: DirectionArrowPainter(
            targetHeading: widget.targetHeading,
            userHeading: widget.userHeading,
            distanceToTarget: widget.distanceToTarget,
            pulseScale: widget.pulseAnimation.value,
          ),
          child: Container(),
        );
      },
    );
  }
}

/// Custom painter for direction arrow
class DirectionArrowPainter extends CustomPainter {
  final double targetHeading;
  final double userHeading;
  final double distanceToTarget;
  final double pulseScale;

  DirectionArrowPainter({
    required this.targetHeading,
    required this.userHeading,
    required this.distanceToTarget,
    required this.pulseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Calculate relative heading (angle between user heading and target)
    double relativeHeading = targetHeading - userHeading;
    
    // Normalize to -180 to 180
    while (relativeHeading > 180) relativeHeading -= 360;
    while (relativeHeading < -180) relativeHeading += 360;

    // Draw pulsing circle for target
    final circlePaint = Paint()
      ..color = AppColors.primaryOrange.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final circleStrokePaint = Paint()
      ..color = AppColors.primaryOrange.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final circleRadius = 60 * pulseScale;
    canvas.drawCircle(Offset(centerX, centerY), circleRadius, circlePaint);
    canvas.drawCircle(Offset(centerX, centerY), circleRadius, circleStrokePaint);

    // Draw arrow pointing to target
    final arrowLength = 100.0;
    final angle = (relativeHeading + 90) * (math.pi / 180); // +90 because canvas coordinates
    
    final arrowTipX = centerX + arrowLength * math.cos(angle);
    final arrowTipY = centerY + arrowLength * math.sin(angle);

    final arrowPaint = Paint()
      ..color = AppColors.primaryOrange.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final arrowStrokePaint = Paint()
      ..color = AppColors.primaryOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Arrow head
    _drawArrowHead(
      canvas,
      Offset(centerX, centerY),
      Offset(arrowTipX, arrowTipY),
      30,
      arrowPaint,
      arrowStrokePaint,
    );

    // Draw distance indicator
    _drawDistanceIndicator(canvas, size, distanceToTarget);
  }

  void _drawArrowHead(
    Canvas canvas,
    Offset start,
    Offset end,
    double headWidth,
    Paint fillPaint,
    Paint strokePaint,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    
    if (len == 0) return;

    final ex = dx / len;
    final ey = dy / len;

    // Arrow shaft
    canvas.drawLine(start, end, strokePaint);

    // Arrow head points
    final p1X = end.dx - ex * headWidth - ey * headWidth;
    final p1Y = end.dy - ey * headWidth + ex * headWidth;
    final p2X = end.dx - ex * headWidth + ey * headWidth;
    final p2Y = end.dy - ey * headWidth - ex * headWidth;

    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(p1X, p1Y)
      ..lineTo(p2X, p2Y)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  void _drawDistanceIndicator(Canvas canvas, Size size, double distance) {
    final centerX = size.width / 2;
    final bottomY = size.height - 80.0;

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${distance.toStringAsFixed(0)}m ahead',
        style: const TextStyle(
          color: AppColors.primaryOrange,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        centerX - textPainter.width / 2,
        bottomY,
      ),
    );
  }

  @override
  bool shouldRepaint(DirectionArrowPainter oldDelegate) =>
      oldDelegate.targetHeading != targetHeading ||
      oldDelegate.userHeading != userHeading ||
      oldDelegate.distanceToTarget != distanceToTarget ||
      oldDelegate.pulseScale != pulseScale;
}

/// AR Milestone Indicator
/// Shows progress through the route with visual milestones
class ArMilestoneIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String currentMilestoneName;
  final String nextMilestoneName;
  final double progress;

  const ArMilestoneIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.currentMilestoneName,
    required this.nextMilestoneName,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryOrange.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Milestone ${currentStep + 1}/$totalSteps',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.cardDark,
                valueColor: const AlwaysStoppedAnimation(AppColors.primaryOrange),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currentMilestoneName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Next: $nextMilestoneName',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// AR Compass Indicator
/// Shows heading and direction alignment
class ArCompassIndicator extends StatelessWidget {
  final double userHeading;
  final double targetHeading;

  const ArCompassIndicator({
    super.key,
    required this.userHeading,
    required this.targetHeading,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate heading difference
    double difference = targetHeading - userHeading;
    while (difference > 180) difference -= 360;
    while (difference < -180) difference += 360;

    final isAligned = difference.abs() < 15; // Within 15 degrees

    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAligned
                ? Colors.green.withOpacity(0.6)
                : AppColors.primaryOrange.withOpacity(0.6),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: userHeading * (math.pi / 180),
              child: const Icon(
                Icons.navigation,
                color: AppColors.primaryOrange,
                size: 32,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _headingToDirection(userHeading),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isAligned)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check, color: Colors.green, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Aligned',
                      style: TextStyle(color: Colors.green, fontSize: 10),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _headingToDirection(double heading) {
    if (heading >= 337.5 || heading < 22.5) return 'N';
    if (heading >= 22.5 && heading < 67.5) return 'NE';
    if (heading >= 67.5 && heading < 112.5) return 'E';
    if (heading >= 112.5 && heading < 157.5) return 'SE';
    if (heading >= 157.5 && heading < 202.5) return 'S';
    if (heading >= 202.5 && heading < 247.5) return 'SW';
    if (heading >= 247.5 && heading < 292.5) return 'W';
    return 'NW';
  }
}

/// Audio Indicator Widget
/// Shows when audio instructions are being played
class AudioIndicator extends StatefulWidget {
  final bool isPlaying;
  final String? instruction;

  const AudioIndicator({
    super.key,
    required this.isPlaying,
    this.instruction,
  });

  @override
  State<AudioIndicator> createState() => _AudioIndicatorState();
}

class _AudioIndicatorState extends State<AudioIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    if (widget.isPlaying) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(AudioIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_animationController.isAnimating) {
      _animationController.repeat();
    } else if (!widget.isPlaying && _animationController.isAnimating) {
      _animationController.stop();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isPlaying
                  ? Colors.red.withOpacity(0.8)
                  : Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.red.withOpacity(
                  widget.isPlaying ? 1.0 : 0.3,
                ),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isPlaying)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CustomPaint(
                      painter: AudioWavesPainter(
                        progress: _animationController.value,
                      ),
                    ),
                  ),
                if (widget.isPlaying) const SizedBox(width: 8),
                const Text(
                  'Audio Guidance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

/// Custom painter for audio waves animation
class AudioWavesPainter extends CustomPainter {
  final double progress;

  AudioWavesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final waveWidth = size.width / 3;
    final centerY = size.height / 2;

    for (int i = 0; i < 3; i++) {
      final x = i * waveWidth;
      final height = size.height * (0.5 + 0.5 * math.sin((progress * 2 * math.pi) - (i * math.pi / 3)));
      
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(AudioWavesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
