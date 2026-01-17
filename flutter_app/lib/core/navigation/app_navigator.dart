import 'package:flutter/material.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static NavigatorState? get _navigator => navigatorKey.currentState;

  /// Navigate to a page
  static Future<T?> push<T>(Widget page) {
    return _navigator?.push<T>(
      MaterialPageRoute<T>(builder: (_) => page),
    ) ?? Future.value(null);
  }

  /// Replace current page
  static Future<T?> pushReplacement<T>(Widget page) {
    return _navigator?.pushReplacement<T, T>(
      MaterialPageRoute<T>(builder: (_) => page),
    ) ?? Future.value(null);
  }

  /// Pop current page
  static void pop<T>([T? result]) {
    _navigator?.pop<T>(result);
  }

  /// Pop until a specific condition
  static void popUntil(bool Function(Route) predicate) {
    _navigator?.popUntil(predicate);
  }

  /// Pop all pages and show a new one
  static Future<T?> popAllAndPush<T>(Widget page) {
    return _navigator?.pushAndRemoveUntil<T>(
      MaterialPageRoute<T>(builder: (_) => page),
      (route) => false,
    ) ?? Future.value(null);
  }

  /// Check if can pop
  static bool canPop() {
    return _navigator?.canPop() ?? false;
  }
}
