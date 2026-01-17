import 'package:flutter/material.dart';

class Responsive {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double blockSizeHorizontal;
  static late double blockSizeVertical;
  static late double safeAreaHorizontal;
  static late double safeAreaVertical;
  static late double safeBlockHorizontal;
  static late double safeBlockVertical;
  static late bool isMobile;
  static late bool isTablet;
  static late bool isDesktop;
  static late DeviceType deviceType;

  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    blockSizeHorizontal = screenWidth / 100;
    blockSizeVertical = screenHeight / 100;

    safeAreaHorizontal = _mediaQueryData.padding.left + _mediaQueryData.padding.right;
    safeAreaVertical = _mediaQueryData.padding.top + _mediaQueryData.padding.bottom;
    safeBlockHorizontal = (screenWidth - safeAreaHorizontal) / 100;
    safeBlockVertical = (screenHeight - safeAreaVertical) / 100;

    // Device type detection
    if (screenWidth < 600) {
      deviceType = DeviceType.mobile;
      isMobile = true;
      isTablet = false;
      isDesktop = false;
    } else if (screenWidth < 1200) {
      deviceType = DeviceType.tablet;
      isMobile = false;
      isTablet = true;
      isDesktop = false;
    } else {
      deviceType = DeviceType.desktop;
      isMobile = false;
      isTablet = false;
      isDesktop = true;
    }
  }

  // Responsive font size
  static double fontSize(double size) {
    double scaleFactor = screenWidth / 375; // Base on iPhone X width
    return size * scaleFactor.clamp(0.8, 1.3);
  }

  // Responsive spacing
  static double spacing(double size) {
    double scaleFactor = screenWidth / 375;
    return size * scaleFactor.clamp(0.8, 1.5);
  }

  // Responsive width
  static double width(double percentage) {
    return screenWidth * (percentage / 100);
  }

  // Responsive height
  static double height(double percentage) {
    return screenHeight * (percentage / 100);
  }

  // Get responsive value based on device type
  static T value<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }

  // Responsive padding
  static EdgeInsets padding({
    double? all,
    double? horizontal,
    double? vertical,
    double? left,
    double? right,
    double? top,
    double? bottom,
  }) {
    if (all != null) {
      return EdgeInsets.all(spacing(all));
    }
    return EdgeInsets.only(
      left: spacing(left ?? horizontal ?? 0),
      right: spacing(right ?? horizontal ?? 0),
      top: spacing(top ?? vertical ?? 0),
      bottom: spacing(bottom ?? vertical ?? 0),
    );
  }

  // Grid columns based on device
  static int gridColumns() {
    return value(mobile: 2, tablet: 3, desktop: 4);
  }

  // Card aspect ratio based on device
  static double cardAspectRatio() {
    return value(mobile: 1.0, tablet: 1.1, desktop: 1.2);
  }
}

enum DeviceType { mobile, tablet, desktop }

// Responsive Builder Widget
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    return builder(context, Responsive.deviceType);
  }
}

// Responsive Layout Widget
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= 600) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }
}

// Responsive Grid
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns;
        if (constraints.maxWidth >= 1200) {
          columns = desktopColumns ?? 4;
        } else if (constraints.maxWidth >= 600) {
          columns = tabletColumns ?? 3;
        } else {
          columns = mobileColumns ?? 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: runSpacing,
            childAspectRatio: 1.0,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

// Extension for responsive sizing
extension ResponsiveExtension on num {
  double get w => Responsive.width(toDouble());
  double get h => Responsive.height(toDouble());
  double get sp => Responsive.fontSize(toDouble());
  double get r => Responsive.spacing(toDouble());
}
