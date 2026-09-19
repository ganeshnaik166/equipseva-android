package com.equipseva.app.core.security

import android.content.Context
import android.os.Build
import android.os.Debug
import android.provider.Settings
import android.util.Log
import com.equipseva.app.BuildConfig
import java.io.File
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.atomic.AtomicReference

/**
 * Runs cheap local probes for signals that the device is rooted, an emulator,
 * under a debugger, or has Frida attached. The intent is to *report*, not to
 * block — a determined attacker always wins on-device. The real backstop is
 * server-side: forward [Verdict] alongside a Play Integrity token to the
 * server, and let the server refuse sensitive ops (order create, KYC submit,
 * payout release) when the verdict is dirty.
 *
 * Keep the probes conservative: false positives on legitimate
 * developer / rooted enthusiast devices are bad UX.
 */
object DeviceIntegrityCheck {

    data class Verdict(
        val debuggerAttached: Boolean,
        val rooted: Boolean,
        val emulator: Boolean,
        val fridaDetected: Boolean,
        val devOptionsEnabled: Boolean = false,
        val usbDebuggingEnabled: Boolean = false,
    ) {
        val clean: Boolean
            get() = !debuggerAttached && !rooted && !emulator && !fridaDetected &&
                !devOptionsEnabled && !usbDebuggingEnabled

        /**
         * Round 470: HARD blocker — refuse to render the app UI when set.
         * USB debugging enabled is a strong MITM/instrumentation signal;
         * Developer Options main toggle is a softer signal but commonly
         * accompanies it. Either is enough to block on release builds.
         * Debug builds skip — would prevent our own development.
         */
        val devModeBlocking: Boolean
            get() = !BuildConfig.DEBUG && (devOptionsEnabled || usbDebuggingEnabled)

        fun toTag(): String = buildString {
            append("debugger=").append(debuggerAttached)
            append(" rooted=").append(rooted)
            append(" emulator=").append(emulator)
            append(" frida=").append(fridaDetected)
            append(" devOptions=").append(devOptionsEnabled)
            append(" usbDebug=").append(usbDebuggingEnabled)
        }
    }

    /**
     * Round 470: takes Context to probe device Settings (USB debugging +
     * Developer Options). Callers should pass the application context.
     * Backwards-compat [run] (no-arg) sets the dev-mode fields to false
     * — only legacy call sites that haven't been migrated.
     */
    fun run(context: Context): Verdict {
        val debugger = !BuildConfig.DEBUG && (Debug.isDebuggerConnected() || Debug.waitingForDebugger())
        val verdict = Verdict(
            debuggerAttached = debugger,
            rooted = looksRooted(),
            emulator = looksLikeEmulator(),
            fridaDetected = looksLikeFrida(),
            devOptionsEnabled = isDevOptionsEnabled(context),
            usbDebuggingEnabled = isUsbDebuggingEnabled(context),
        )
        if (!verdict.clean) {
            Log.w(TAG, "Device integrity: ${verdict.toTag()}")
        }
        return verdict
    }

    /** Backwards-compat shim — no Context, dev-mode fields default to false. */
    fun run(): Verdict {
        val debugger = !BuildConfig.DEBUG && (Debug.isDebuggerConnected() || Debug.waitingForDebugger())
        val verdict = Verdict(
            debuggerAttached = debugger,
            rooted = looksRooted(),
            emulator = looksLikeEmulator(),
            fridaDetected = looksLikeFrida(),
        )
        if (!verdict.clean) {
            Log.w(TAG, "Device integrity: ${verdict.toTag()}")
        }
        return verdict
    }

    private fun isDevOptionsEnabled(context: Context): Boolean = runCatching {
        Settings.Global.getInt(
            context.contentResolver,
            Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
            0,
        ) == 1
    }.getOrDefault(false)

    private fun isUsbDebuggingEnabled(context: Context): Boolean = runCatching {
        Settings.Global.getInt(
            context.contentResolver,
            Settings.Global.ADB_ENABLED,
            0,
        ) == 1
    }.getOrDefault(false)

    private fun looksRooted(): Boolean {
        val suspects = listOf(
            "/system/app/Superuser.apk",
            "/system/xbin/su",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/busybox",
            "/data/local/su",
            "/data/local/bin/su",
            "/data/local/xbin/su",
            "/data/adb/magisk",
            "/sbin/.magisk",
        )
        if (suspects.any { File(it).exists() }) return true
        if (Build.TAGS?.contains("test-keys") == true) return true
        // Writable /system is a rooted-ROM tell.
        return File("/system").canWrite()
    }

    private fun looksLikeEmulator(): Boolean {
        val fp = Build.FINGERPRINT.orEmpty()
        val model = Build.MODEL.orEmpty()
        val manufacturer = Build.MANUFACTURER.orEmpty()
        val product = Build.PRODUCT.orEmpty()
        val hardware = Build.HARDWARE.orEmpty()
        return fp.startsWith("generic") ||
            fp.startsWith("unknown") ||
            fp.contains("vbox") ||
            model.contains("google_sdk") ||
            model.contains("Emulator", ignoreCase = true) ||
            model.contains("Android SDK built for") ||
            manufacturer.contains("Genymotion", ignoreCase = true) ||
            product.contains("sdk") ||
            hardware.contains("goldfish") ||
            hardware.contains("ranchu")
    }

    private fun looksLikeFrida(): Boolean = probeOffCallerThread(
        threadName = "integrity-frida-probe",
        joinTimeoutMs = FRIDA_PROBE_JOIN_MS,
        ifUnavailable = false,
    ) {
        // Frida-server default TCP port on the device's loopback. Very cheap
        // probe; misses gadget-based Frida but catches the common case.
        Socket().use { s ->
            s.connect(InetSocketAddress("127.0.0.1", FRIDA_SERVER_PORT), FRIDA_CONNECT_TIMEOUT_MS)
            true
        }
    }

    private const val TAG = "DeviceIntegrityCheck"
    private const val FRIDA_SERVER_PORT = 27042
    private const val FRIDA_CONNECT_TIMEOUT_MS = 50
    private const val FRIDA_PROBE_JOIN_MS = 250L
}

/**
 * Runs [probe] on a short-lived daemon thread and waits at most
 * [joinTimeoutMs] for an answer, yielding [ifUnavailable] when the probe
 * throws or outlives that window.
 *
 * The integrity checks are invoked from `Application.onCreate`, the
 * ProcessLifecycleOwner observer and the activity's own resume path — all
 * on the main thread, where Android throws NetworkOnMainThreadException
 * even for a loopback connect. Swallowed, that made the socket probe read
 * "clean" on every device and killed the signal it exists to provide.
 * The join stays bounded because a hung probe must never stall a cold
 * start, and a missed detection is picked up by the periodic re-check.
 */
internal fun <T> probeOffCallerThread(
    threadName: String,
    joinTimeoutMs: Long,
    ifUnavailable: T,
    probe: () -> T,
): T {
    val answer = AtomicReference(ifUnavailable)
    val worker = Thread(
        {
            // A probe that cannot run is indistinguishable from a negative
            // result for these signals, so failures keep the fallback.
            runCatching { answer.set(probe()) }
        },
        threadName,
    ).apply { isDaemon = true }
    worker.start()
    try {
        worker.join(joinTimeoutMs)
    } catch (_: InterruptedException) {
        // Restore the flag for whoever owns the calling thread.
        Thread.currentThread().interrupt()
    }
    return answer.get()
}
