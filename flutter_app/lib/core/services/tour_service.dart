import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class TourService {
  static const String _userTourKey = 'user_tour_completed';
  static const String _adminTourKey = 'admin_tour_completed';

  final SharedPreferences _prefs;

  TourService(this._prefs);

  // Check if user tour has been completed
  bool hasCompletedUserTour() {
    return _prefs.getBool(_userTourKey) ?? false;
  }

  // Check if admin tour has been completed
  bool hasCompletedAdminTour() {
    return _prefs.getBool(_adminTourKey) ?? false;
  }

  // Mark user tour as completed
  Future<void> completeUserTour() async {
    await _prefs.setBool(_userTourKey, true);
  }

  // Mark admin tour as completed
  Future<void> completeAdminTour() async {
    await _prefs.setBool(_adminTourKey, true);
  }

  // Reset tours (for testing or user preference)
  Future<void> resetTours() async {
    await _prefs.remove(_userTourKey);
    await _prefs.remove(_adminTourKey);
  }

  // Create user home tour
  TutorialCoachMark createUserHomeTour({
    required List<TargetFocus> targets,
    required VoidCallback onFinish,
    VoidCallback? onSkip,
  }) {
    return TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      paddingFocus: 10,
      opacityShadow: 0.8,
      textSkip: "SKIP",
      textStyleSkip: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      onFinish: () {
        completeUserTour();
        onFinish();
      },
      onSkip: () {
        completeUserTour();
        onSkip?.call();
        return true;
      },
      onClickTarget: (target) {},
      onClickTargetWithTapPosition: (target, tapDetails) {},
      onClickOverlay: (target) {},
    );
  }

  // Create admin dashboard tour
  TutorialCoachMark createAdminTour({
    required List<TargetFocus> targets,
    required VoidCallback onFinish,
    VoidCallback? onSkip,
  }) {
    return TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      paddingFocus: 10,
      opacityShadow: 0.8,
      textSkip: "SKIP TOUR",
      textStyleSkip: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      onFinish: () {
        completeAdminTour();
        onFinish();
      },
      onSkip: () {
        completeAdminTour();
        onSkip?.call();
        return true;
      },
      onClickTarget: (target) {},
      onClickTargetWithTapPosition: (target, tapDetails) {},
      onClickOverlay: (target) {},
    );
  }

  // Create comprehensive workflow tour
  TutorialCoachMark createWorkflowTour({
    required List<TargetFocus> targets,
    required VoidCallback onFinish,
    VoidCallback? onSkip,
  }) {
    return TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      paddingFocus: 10,
      opacityShadow: 0.8,
      textSkip: "SKIP TOUR",
      textStyleSkip: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      onFinish: () {
        completeAdminTour();
        onFinish();
      },
      onSkip: () {
        completeAdminTour();
        onSkip?.call();
        return true;
      },
      onClickTarget: (target) {},
      onClickTargetWithTapPosition: (target, tapDetails) {},
      onClickOverlay: (target) {},
    );
  }

  // Helper to create workflow content with step indicators
  static TargetContent createWorkflowContent({
    required String title,
    required String description,
    required String workflow,
    ContentAlign align = ContentAlign.bottom,
    int? stepNumber,
    int? totalSteps,
  }) {
    return TargetContent(
      align: align,
      builder: (context, controller) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade600, Colors.purple.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stepNumber != null && totalSteps != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Step $stepNumber of $totalSteps',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔄 Complete Workflow:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      workflow,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Tap to continue →',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper to create target content with enhanced styling
  static TargetContent createTargetContent({
    required String title,
    required String description,
    ContentAlign align = ContentAlign.bottom,
    String? additionalInfo,
  }) {
    return TargetContent(
      align: align,
      builder: (context, controller) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              if (additionalInfo != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    additionalInfo,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Tap anywhere to continue',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
