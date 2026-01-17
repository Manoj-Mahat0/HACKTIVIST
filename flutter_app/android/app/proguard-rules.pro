# Flutter Compass - Suppress calibration warnings
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
}

# Keep compass functionality but suppress debug logs
-keep class hemanthraj.fluttercompass.** { *; }
