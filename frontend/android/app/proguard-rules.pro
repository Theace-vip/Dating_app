# ===== SoulMate release ProGuard/R8 =====

# Flutter embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# WebRTC (flutter_webrtc) — library native được gọi qua JNI
-keep class org.webrtc.** { *; }
-keep class com.cloudwebrtc.** { *; }
-dontwarn org.webrtc.**

# Socket.IO / engine.io (gọi qua reflection)
-keep class io.socket.** { *; }
-keep class libsockjso.** { *; }
-dontwarn io.socket.**

# Ảnh: image_picker / file_picker
-keep class androidx.core.content.FileProvider { *; }

# Secure storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Giữ annotation @SerializedName nếu có (JSON)
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Play Core (Flutter deferred components reference)
-dontwarn com.google.android.play.core.**
