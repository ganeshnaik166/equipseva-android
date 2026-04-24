import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
    alias(libs.plugins.google.services)
    alias(libs.plugins.firebase.crashlytics)
    alias(libs.plugins.sentry)
}

val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

fun localOrEnv(key: String, default: String = ""): String =
    localProps.getProperty(key) ?: System.getenv(key) ?: default

val keystoreProps = Properties().apply {
    val f = project.file("keystore.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKeystore: Boolean =
    keystoreProps.getProperty("storeFile")?.let { project.file(it).exists() } == true

android {
    namespace = "com.equipseva.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.equipseva.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables { useSupportLibrary = true }

        buildConfigField("String", "SUPABASE_URL", "\"${localOrEnv("SUPABASE_URL")}\"")
        buildConfigField("String", "SUPABASE_ANON_KEY", "\"${localOrEnv("SUPABASE_ANON_KEY")}\"")
        buildConfigField("String", "SENTRY_DSN", "\"${localOrEnv("SENTRY_DSN")}\"")
        buildConfigField("String", "RAZORPAY_KEY", "\"${localOrEnv("RAZORPAY_KEY")}\"")
        buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", "\"${localOrEnv("GOOGLE_WEB_CLIENT_ID")}\"")

        // Base64(SHA-256(signing cert DER)). Blank until the release keystore
        // is provisioned — SignatureVerifier skips the check when empty so
        // debug builds and CI don't fail before the Play Console blocker
        // clears. Fill from keystore.properties / CI secret once the upload
        // key lands; SignatureVerifier flips to enforce on release then.
        buildConfigField("String", "EXPECTED_CERT_SHA256", "\"${localOrEnv("EXPECTED_CERT_SHA256")}\"")
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = project.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            isDebuggable = true
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Sign with the upload key when keystore.properties + *.jks are
            // present locally. CI seeds an empty keystore.properties so the
            // release build still goes through R8 with default debug-signing;
            // those APKs are never published.
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
        freeCompilerArgs += listOf(
            "-Xjvm-default=all",
            "-opt-in=kotlin.RequiresOptIn",
        )
    }

    sourceSets {
        named("main") {
            java.srcDirs("src/main/kotlin")
        }
        named("test") {
            java.srcDirs("src/test/kotlin")
        }
        named("androidTest") {
            java.srcDirs("src/androidTest/kotlin")
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources {
            excludes += setOf(
                "/META-INF/{AL2.0,LGPL2.1}",
                "/META-INF/LICENSE*",
                "/META-INF/NOTICE*",
            )
        }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.splashscreen)
    implementation(libs.google.material)
    implementation(libs.androidx.lifecycle.viewmodel.compose)

    // Google Sign-in via Credential Manager
    implementation(libs.androidx.credentials)
    implementation(libs.androidx.credentials.play.services.auth)
    implementation(libs.google.id)

    // Compose
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)
    debugImplementation(libs.androidx.compose.ui.tooling)

    // Navigation
    implementation(libs.androidx.navigation.compose)

    // Hilt
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation.compose)
    implementation(libs.hilt.work)
    ksp(libs.hilt.work.compiler)

    // Room
    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)

    // DataStore
    implementation(libs.datastore.preferences)

    // EXIF scrubbing for storage uploads
    implementation(libs.androidx.exifinterface)

    // WorkManager
    implementation(libs.work.runtime.ktx)

    // Networking
    implementation(libs.retrofit)
    implementation(libs.retrofit.kotlinx.serialization)
    implementation(libs.okhttp.logging)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)

    // Supabase Kotlin SDK
    implementation(platform(libs.supabase.bom))
    implementation(libs.supabase.auth)
    implementation(libs.supabase.postgrest)
    implementation(libs.supabase.realtime)
    implementation(libs.supabase.storage)
    implementation(libs.supabase.functions)
    implementation(libs.ktor.client.okhttp)

    // Coil
    implementation(libs.coil.compose)
    implementation(libs.coil.network.okhttp)

    // Firebase
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)
    implementation(libs.firebase.crashlytics)
    implementation(libs.firebase.analytics)

    // Sentry
    implementation(libs.sentry.android)

    // Razorpay Standard Checkout
    implementation(libs.razorpay.checkout)

    // SQLCipher for Room at-rest encryption.
    // Passphrase lives in Android Keystore (see DbPassphraseStore).
    implementation(libs.sqlcipher.android)
    implementation(libs.androidx.sqlite)

    // EncryptedSharedPreferences for role + onboarding + favorites (see SecurePrefs).
    implementation(libs.androidx.security.crypto)

    // Test
    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
}

// Sentry Android Gradle plugin — R8/ProGuard mapping upload.
//
// The plugin only uploads when a minified mapping.txt is produced, i.e. only
// on the `release` variant (debug has isMinifyEnabled = false, so no mapping).
// Uploads require the following env vars in CI:
//   SENTRY_AUTH_TOKEN   — Sentry internal integration / user auth token
//   SENTRY_ORG          — Sentry org slug
//   SENTRY_PROJECT      — Sentry project slug
// Do NOT commit a .sentryclirc with real tokens. Locally, leave them unset and
// the plugin will skip the upload step.
sentry {
    includeProguardMapping.set(true)
    autoUploadProguardMapping.set(true)
    // Native is not shipped from this module.
    uploadNativeSymbols.set(false)
    includeNativeSources.set(false)
    // The runtime SDK is already declared in `dependencies`; don't let the
    // plugin re-add it.
    autoInstallation {
        enabled.set(false)
    }
}
