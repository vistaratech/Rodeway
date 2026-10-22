# Flutter wrapper rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter Unity Widget & Unity Player
-keep class com.xraph.plugin.flutter_unity_widget.** { *; }
-keep interface com.xraph.plugin.flutter_unity_widget.** { *; }
-keep class com.unity3d.player.** { *; }
-keep interface com.unity3d.player.** { *; }
-dontwarn com.unity3d.player.**
-keepattributes *Annotation*

# Google Play Services & Maps / Navigation
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.android.libraries.navigation.** { *; }
-dontwarn com.google.android.libraries.navigation.**

# Flutter Reactive BLE
-keep class com.signify.hue.flutterreactiveble.** { *; }
-dontwarn com.signify.hue.flutterreactiveble.**

# TensorFlow Lite
-keep class org.tensorflow.lite.** { *; }
-keep interface org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# Protocol Buffers
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# General keep rules
-dontwarn javax.annotation.**
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
