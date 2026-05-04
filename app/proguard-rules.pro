# Keep kotlinx.serialization metadata
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

-keep,includedescriptorclasses class com.equipseva.app.**$$serializer { *; }
-keepclassmembers class com.equipseva.app.** {
    *** Companion;
}
-keepclasseswithmembers class com.equipseva.app.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Retrofit
-keepattributes Signature, Exceptions
-keep,allowshrinking interface * extends retrofit2.Call
-keep class retrofit2.** { *; }

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# Hilt
-keep class dagger.hilt.** { *; }
-keep class * extends dagger.hilt.android.internal.managers.** { *; }
# R8 full-mode: Hilt generates classes by reflection at init; keep their
# constructors and generated modules intact so DI resolves at runtime.
-keep class * extends dagger.hilt.android.components.** { *; }
-keep @dagger.hilt.android.HiltAndroidApp class * { <init>(...); }
-keep @dagger.hilt.android.AndroidEntryPoint class * { <init>(...); }
-keep @dagger.hilt.InstallIn class * { *; }
-keep @dagger.hilt.components.SingletonComponent class * { *; }

# Room
-keep class androidx.room.** { *; }

# SQLCipher native bindings are JNI-linked; R8 full-mode will otherwise strip
# the class that the .so resolves symbols against.
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# Anti-tamper runtime checks — called reflectively via the obfuscated
# Application subclass, but keep the public API intact for clarity.
-keep class com.equipseva.app.core.security.SignatureVerifier { *; }
-keep class com.equipseva.app.core.security.DeviceIntegrityCheck { *; }
-keep class com.equipseva.app.core.security.DeviceIntegrityCheck$Verdict { *; }
-keep class com.equipseva.app.core.security.PlayIntegrityClient { *; }

# Google Play Integrity / Play Core — internal task adapters are referenced
# reflectively by the .aar so keep the package intact.
-keep class com.google.android.play.core.integrity.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Sentry (mappings are uploaded separately)
-keep class io.sentry.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }

# Strip noisy, non-actionable log statements in release. Log.w / Log.e / Log.wtf are
# preserved so genuine warnings + errors + "should never happen" assertions still surface
# in Logcat for post-incident triage (e.g. SignatureVerifier mismatch reasons).
# println / System.out paths are removed since release code should never use them.
# R8 treats these as side-effect free so the calls (and their argument expressions) drop out.
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
}
-assumenosideeffects class java.io.PrintStream {
    public void print(...);
    public void println(...);
}
