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

# OkHttp / Okio (used transitively via Ktor's OkHttp engine).
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
# the class that the .so resolves symbols against. Migrated to the new
# net.zetetic:sqlcipher-android artifact (4.6.x) for 16-KB-page-aligned
# native libs; new package root is `net.zetetic.database.sqlcipher`.
-keep class net.zetetic.database.** { *; }
-keep class net.zetetic.database.sqlcipher.** { *; }

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

# Razorpay SDK — reflection-based init in checkout.open() and a JS bridge
# inside the payment activity. R8 full-mode otherwise strips classes that
# the .aar loads by name, crashing the AMC payment flow on release builds.
-keep class com.razorpay.** { *; }
-keep interface com.razorpay.** { *; }
-keepclassmembers class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keepattributes JavascriptInterface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Strip verbose / debug / info log statements in release. Log.e is
# preserved because genuine errors must keep surfacing; Log.w and
# Log.wtf are now ALSO preserved because PlayIntegrityClient,
# SignatureVerifier, DeviceIntegrityCheck, and outbox handlers use
# Log.w as the only telemetry for production failures (integrity
# verdicts, signing mismatch, stash-cleanup errors). Stripping w/wtf
# silently dropped those signals in release builds, leaving field
# investigations with no breadcrumbs. println / System.out paths are
# removed since those aren't on any production breadcrumb pipeline.
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
}
-assumenosideeffects class java.io.PrintStream {
    public void print(...);
    public void println(...);
}
