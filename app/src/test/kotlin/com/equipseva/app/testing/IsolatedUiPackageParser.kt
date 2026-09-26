package com.equipseva.app.testing

import android.app.Application
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import java.io.File
import java.util.Collections
import java.util.IdentityHashMap
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.annotation.RealObject
import org.robolectric.annotation.Resetter
import org.robolectric.internal.ManifestFactory
import org.robolectric.internal.ManifestIdentifier
import org.robolectric.res.Fs
import org.robolectric.shadow.api.Shadow
import org.robolectric.util.ReflectionHelpers
import org.robolectric.util.ReflectionHelpers.ClassParameter

/**
 * AGP's resource APK contains the production merged manifest, and Robolectric
 * ignores Config.NONE for that APK. Keep real resources while removing app
 * components before package installation. The text manifest is independently
 * replaced by [IsolatedUiTestRunner], because Robolectric also registers its
 * receivers directly. Neither path may start production code in these tests.
 */
@Implements(className = "android.content.pm.PackageParser", isInAndroidSdk = false, looseSignatures = true)
class IsolatedUiPackageParser {
    @RealObject private lateinit var parser: Any

    @Implementation
    protected fun parsePackage(file: File, flags: Int): Any {
        // A fresh default PackageParser has no disk cache. Refuse cached parsing
        // instead of mutating a descriptor that another test could reuse.
        check(ReflectionHelpers.getField<File?>(parser, "mCacheDir") == null)
        val parsed = checkNotNull(Shadow.directlyOn<Any>(
            parser, "android.content.pm.PackageParser", "parsePackage",
            ClassParameter.from(File::class.java, file),
            ClassParameter.from(Int::class.javaPrimitiveType, flags),
        ))
        check(parsedPackages.add(parsed)) { "Package parser reused a descriptor" }
        check(ReflectionHelpers.getField<String>(parsed, "packageName") == "com.equipseva.app.debug") {
            "Isolated UI shadow is restricted to the normal debug test resource APK"
        }
        originalProviderCount += checkNotNull(list(parsed, "providers")).size
        listOf("activities", "receivers", "services", "providers", "permissions", "permissionGroups",
            "requestedPermissions", "protectedBroadcasts").forEach { list(parsed, it)?.clear() }
        ReflectionHelpers.setField(parsed, "mAppMetaData", null)
        val info = ReflectionHelpers.getField<ApplicationInfo>(parsed, "applicationInfo")
        info.metaData = null
        info.className = Application::class.java.name
        // This framework field was introduced in P. API26 has no factory to strip.
        if (android.os.Build.VERSION.SDK_INT >= 28) info.appComponentFactory = null
        info.permission = null
        parsedCount++
        return parsed
    }

    companion object {
        private val parsedPackages: MutableSet<Any> = Collections.newSetFromMap(IdentityHashMap())
        private var parsedCount = 0
        private var originalProviderCount = 0

        private fun list(parsed: Any, field: String): MutableList<Any>? = ReflectionHelpers.getField(parsed, field)

        @JvmStatic @Resetter fun reset() {
            parsedPackages.clear()
            parsedCount = 0
            originalProviderCount = 0
        }

        /** Run before mounting every UI activity, not just in a standalone smoke test. */
        @Suppress("DEPRECATION")
        fun assertIsolated(application: Application) {
            assertEquals(Application::class.java, application.javaClass)
            assertTrue("The pre-install parser shadow must actually execute", parsedCount > 0)
            assertTrue("Fixture must strip the real APK, not a fabricated empty package", originalProviderCount > 0)
            val info = application.packageManager.getPackageInfo(application.packageName,
                PackageManager.GET_ACTIVITIES or PackageManager.GET_PROVIDERS or PackageManager.GET_SERVICES or
                    PackageManager.GET_RECEIVERS or PackageManager.GET_PERMISSIONS or PackageManager.GET_META_DATA)
            assertTrue("activities survived isolation", info.activities.isNullOrEmpty())
            assertTrue("providers survived isolation", info.providers.isNullOrEmpty())
            assertTrue("services survived isolation", info.services.isNullOrEmpty())
            assertTrue("receivers survived isolation", info.receivers.isNullOrEmpty())
            assertTrue("requested permissions survived isolation", info.requestedPermissions.isNullOrEmpty())
            assertTrue("declared permissions survived isolation", info.permissions.isNullOrEmpty())
            assertTrue("application metadata survived isolation", info.applicationInfo?.metaData?.isEmpty != false)
        }
    }
}

/** Minimal text manifest plus the unchanged real APK/resource identity. */
class IsolatedUiTestRunner(testClass: Class<*>) : RobolectricTestRunner(testClass) {
    override fun getManifestFactory(config: Config): ManifestFactory {
        val original = super.getManifestFactory(config)
        val loader = checkNotNull(javaClass.classLoader)
        val manifest = Fs.fromUrl(checkNotNull(loader.getResource("isolated_ui_manifest.xml")))
        return ManifestFactory { requested ->
            val source = original.identify(requested)
            ManifestIdentifier(source.packageName, manifest, source.resDir, source.assetDir, emptyList(), source.apkFile)
        }
    }
}
