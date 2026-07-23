# Flutter / Dart
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Keep native methods
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Play Core (optional, used by some Flutter plugins)
-dontwarn com.google.android.play.core.**
