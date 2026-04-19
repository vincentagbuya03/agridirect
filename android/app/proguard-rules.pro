# ML Kit ProGuard Rules
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.ml.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.android.gms.tflite.** { *; }

# Prevent R8 from stripping away text recognition options
-keep class com.google.mlkit.vision.text.** { *; }
-keep interface com.google.mlkit.vision.text.** { *; }

# Suppress warnings
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**
