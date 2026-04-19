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

# Room
-keep class androidx.room.** { *; }

# Sentry (mappings are uploaded separately)
-keep class io.sentry.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }

# Strip non-error log statements in release. Log.e is preserved so genuine errors still
# surface. println / System.out paths are removed as well. R8 treats these as side-effect
# free so the calls (and their argument expressions) drop out entirely.
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
    public static *** w(...);
    public static *** wtf(...);
}
-assumenosideeffects class java.io.PrintStream {
    public void print(...);
    public void println(...);
}
