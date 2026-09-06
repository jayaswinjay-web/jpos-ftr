# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Drift / SQLite
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }

# Dio / Retrofit
-keepattributes Signature
-keepattributes *Annotation*
-keep class retrofit2.** { *; }
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}

# Gson / Json
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Kotlin
-keep class kotlin.** { *; }
-keep class org.jetbrains.** { *; }

# Secure Storage
-keep class com.google.android.gms.** { *; }
-keep class net.sqlcipher.** { *; }

# Keep model classes
-keep class com.jaytech.jaypos.** { *; }

# Play Core: Flutter engine references split-install classes that are only
# used for deferred components (unused in this app). Firebase ships the newer
# core-common which would duplicate them, so old play:core is excluded and
# R8 is told to ignore the dead references instead.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Remove logging
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
