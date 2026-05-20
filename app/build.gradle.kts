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

// Resolve signing creds env-first so CI (and a future at-rest-hardened
// local setup) can drop keystore.properties entirely. Local dev keeps
// using the file. Env keys: RELEASE_KEYSTORE_PATH, RELEASE_KEYSTORE_PASSWORD,
// RELEASE_KEY_ALIAS, RELEASE_KEY_PASSWORD.
fun keystoreField(envKey: String, fileKey: String): String? =
    System.getenv(envKey)?.takeIf { it.isNotBlank() }
        ?: keystoreProps.getProperty(fileKey)?.takeIf { it.isNotBlank() }

val releaseStorePath: String? = keystoreField("RELEASE_KEYSTORE_PATH", "storeFile")
val releaseStorePassword: String? = keystoreField("RELEASE_KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias: String? = keystoreField("RELEASE_KEY_ALIAS", "keyAlias")
val releaseKeyPassword: String? = keystoreField("RELEASE_KEY_PASSWORD", "keyPassword")
val hasReleaseKeystore: Boolean =
    releaseStorePath?.let { project.file(it).exists() } == true
        && releaseStorePassword != null
        && releaseKeyAlias != null
        && releaseKeyPassword != null

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
        // Razorpay key id is no longer baked into the APK — both order
        // creation (create-razorpay-order, create-amc-payment-order,
        // create-repair-job-payment-order) and HMAC verify happen on
        // edge functions using server-side env. Client only carries
        // the order_id returned from those edge fns.
        buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", "\"${localOrEnv("GOOGLE_WEB_CLIENT_ID")}\"")

        // Base64(SHA-256(signing cert DER)). Comma-separated for multi-cert
        // setups: the upload-key fingerprint AND the Play App Signing key
        // fingerprint (Google re-signs distributed APKs after first AAB
        // upload). Blank until the release keystore is provisioned —
        // SignatureVerifier returns Verdict.Unknown when empty so debug +
        // CI builds don't fail. Compute via:
        //   keytool -list -v -keystore app/equipseva-upload.jks \
        //     -alias equipseva-upload -storepass <pwd> | grep -A1 SHA256
        //   (then strip colons, hex-decode, base64-encode — see
        //   docs/launch/V21_ACTIVATION_RUNBOOK.md §5a)
        buildConfigField("String", "EXPECTED_CERT_SHA256", "\"${localOrEnv("EXPECTED_CERT_SHA256")}\"")

        // PR-D46: hard fail-closed on tamper verdict. Default false so
        // local + CI + first Play-Internal-Testing builds still boot. Flip
        // to true in local.properties / CI secret AFTER both upload-key
        // SHA and Play App Signing SHA have been added to
        // EXPECTED_CERT_SHA256 (per runbook §5c). When true and the
        // current cert isn't in the expected list, EquipSevaApplication
        // hard-exits before any auth / network code runs.
        run {
            val raw = localOrEnv("TAMPER_ENFORCE").trim().ifEmpty { "false" }
            val flag = raw.equals("true", ignoreCase = true) || raw == "1"
            buildConfigField("boolean", "TAMPER_ENFORCE", flag.toString())
        }

        // Google Maps API key — passed both as a BuildConfig string for the
        // Kotlin side and via manifestPlaceholders so the Maps SDK picks it
        // up at runtime via AndroidManifest meta-data. Blank when unset so
        // CI / debug builds compile; the map widget renders empty tiles
        // until a real key is wired in local.properties or env.
        buildConfigField("String", "MAPS_API_KEY", "\"${localOrEnv("MAPS_API_KEY")}\"")
        manifestPlaceholders["MAPS_API_KEY"] = localOrEnv("MAPS_API_KEY")
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = project.file(releaseStorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
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

    testOptions {
        // Robolectric needs merged AAR resources on the unit-test classpath
        // to resolve drawables / strings / themes from inside JVM tests.
        // Cheap when no Robolectric test runs (gradle only assembles the
        // resources when the test source-set actually depends on them).
        unitTests {
            isIncludeAndroidResources = true
        }
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
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)

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

    // Networking — Supabase SDK (below) handles HTTP; Retrofit/OkHttp
    // were dropped along with the orphan AuthInterceptor in round 158.
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

    // Sentry
    implementation(libs.sentry.android)

    // Razorpay Standard Checkout — re-added for v2.1 AMC monthly fee
    // payments (PR-C6). Catalog entry already at version 1.6.41. Live
    // key flows through the create-amc-payment-order edge fn return
    // value `key_id`; the manifest meta-data placeholder is just to
    // satisfy SDK init (the SDK reads key from Checkout.setKeyID()).
    implementation(libs.razorpay.checkout)

    // SQLCipher for Room at-rest encryption.
    // Passphrase lives in Android Keystore (see DbPassphraseStore).
    implementation(libs.sqlcipher.android)
    implementation(libs.androidx.sqlite)

    // EncryptedSharedPreferences for role + onboarding + favorites (see SecurePrefs).
    implementation(libs.androidx.security.crypto)

    // Google Maps Compose — engineer feed renders the 50 km service-area
    // circle and nearby-job pins. Mobile SDK is in the always-free tier;
    // user provides the API key via local.properties / MAPS_API_KEY env.
    implementation(libs.maps.compose)
    implementation(libs.play.services.maps)
    // FusedLocationProviderClient for "Use my current location" address autofill.
    implementation(libs.play.services.location)

    // Google Play Integrity API — client side of verify-play-integrity Edge Function.
    // Token request happens on-device, server-side decode happens in the Edge Function.
    implementation(libs.play.integrity)

    // Test
    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.mockk)
    // Robolectric — JVM Android-simulator for unit tests that need a
    // Context (DataStore, NotificationManager, etc.) without an emulator.
    // Slow per test (~1-3s) so use sparingly; keep the bulk of tests
    // pure-JUnit.
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.androidx.test.runner)
    // Hilt test infra — HiltTestApplication + HiltAndroidRule so JVM
    // tests can boot the real Hilt graph with @TestInstallIn modules
    // replacing the prod ones (e.g. swap SupabaseClient for a fake).
    testImplementation(libs.hilt.android.testing)
    kspTest(libs.hilt.compiler)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
}

// Room schema export. JSONs land in `app/schemas/<db-fqcn>/<version>.json`
// and are committed to source so future Migration(N, N+1) can be derived
// from a real diff. See AppDatabase.kt for the bump workflow.
ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
    arg("room.incremental", "true")
}

// APK size budget guardrail (PENDING.md #50).
//
// Floor for size regressions. Run `./gradlew :app:checkApkSize` after a
// release build to fail loudly if the R8'd APK creeps past the budget.
// Default budget lives in root `gradle.properties` so it can be bumped
// without code changes when a genuinely larger build is acceptable.
//
// Not wired into CI by default — release builds need signing config and
// take a long time. Team can opt in once stable.
val apkSizeBudget = extra.properties.getOrDefault("apkSizeBudgetMb", "28").toString().toLong() * 1024 * 1024

// Pre-release configuration guard — fails any release build when the
// launch-checklist gaps from the pre-Play-Store memo aren't closed.
// Wired as a dependency on bundleRelease + assembleRelease so a casual
// "./gradlew :app:bundleRelease" can never silently ship with
// EXPECTED_CERT_SHA256 empty / assetlinks.json missing / keystore
// references broken. CI dry-runs that intentionally bypass should set
// PRECHECK_LOOSE=1.
tasks.register<Exec>("preReleaseCheck") {
    group = "verification"
    description = "Run scripts/pre-release-checks.sh — guards launch-checklist gaps"
    workingDir = rootDir
    commandLine = listOf("bash", "scripts/pre-release-checks.sh")
    standardOutput = System.out
    errorOutput = System.err
}

// Wire the guard onto release outputs so engineers can't forget to run
// it. afterEvaluate so the AGP-generated tasks exist.
afterEvaluate {
    listOf("assembleRelease", "bundleRelease").forEach { name ->
        tasks.findByName(name)?.dependsOn("preReleaseCheck")
    }
}

tasks.register("checkApkSize") {
    group = "verification"
    description = "Fail if release APK exceeds the size budget"
    dependsOn("assembleRelease")
    doLast {
        val apk = layout.buildDirectory.file("outputs/apk/release/app-release.apk").get().asFile
        require(apk.exists()) { "APK not found at ${apk.path}" }
        val actual = apk.length()
        println("Release APK: ${actual / 1024 / 1024} MB (budget ${apkSizeBudget / 1024 / 1024} MB)")
        check(actual <= apkSizeBudget) {
            "APK size ${actual / 1024 / 1024} MB exceeds budget ${apkSizeBudget / 1024 / 1024} MB. " +
            "Investigate with ./gradlew :app:analyze before increasing apkSizeBudgetMb in gradle.properties."
        }
    }
}

// Sentry Android Gradle plugin — R8/ProGuard mapping upload.
//
// Gate upload on env vars so local + PR-branch builds don't fail when the
// secrets aren't wired. Plugin still generates the mapping; only the upload
// step is skipped. When CI has SENTRY_AUTH_TOKEN + SENTRY_ORG + SENTRY_PROJECT
// set, `autoUploadProguardMapping` flips true and deobfuscation works.
val hasSentryCreds: Boolean = listOf("SENTRY_AUTH_TOKEN", "SENTRY_ORG", "SENTRY_PROJECT")
    .all { (System.getenv(it) ?: "").isNotBlank() }
sentry {
    includeProguardMapping.set(hasSentryCreds)
    autoUploadProguardMapping.set(hasSentryCreds)
    // Native is not shipped from this module.
    uploadNativeSymbols.set(false)
    includeNativeSources.set(false)
    // The runtime SDK is already declared in `dependencies`; don't let the
    // plugin re-add it.
    autoInstallation {
        enabled.set(false)
    }
}
