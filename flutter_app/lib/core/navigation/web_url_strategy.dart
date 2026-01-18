import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart' if (dart.library.io) '';

/// Configure URL strategy for web
/// This removes the # from URLs for better SEO and PWA experience
void configureWebUrlStrategy() {
  if (kIsWeb) {
    // Use path-based URL strategy instead of hash-based
    // This makes URLs cleaner: /buildings instead of /#/buildings
    setUrlStrategy(PathUrlStrategy());
  }
}
