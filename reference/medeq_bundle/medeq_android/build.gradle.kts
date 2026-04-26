// Top-level Gradle file. The Android Studio "Empty Activity" template generates
// most of the surrounding wiring; this file only declares plugin versions
// shared across modules.
plugins {
    id("com.android.application") version "8.5.2" apply false
    kotlin("android") version "1.9.24" apply false
    id("com.google.devtools.ksp") version "1.9.24-1.0.20" apply false
}
