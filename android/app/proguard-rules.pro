# ML Kit ProGuard Rules
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.ml.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.gms.tflite.** { *; }

# Prevent R8 from stripping away text recognition options
-keep class com.google.mlkit.vision.text.** { *; }
-keep interface com.google.mlkit.vision.text.** { *; }

# Agora RTC Engine Rules
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# Flutter CallKit Incoming Rules
-keep class com.hiennv.flutter_callkit_incoming.** { *; }

# General Flutter & Plugin Attributes
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Suppress warnings
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
