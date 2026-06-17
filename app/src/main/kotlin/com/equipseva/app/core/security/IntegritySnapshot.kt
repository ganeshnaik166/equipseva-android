package com.equipseva.app.core.security

import android.content.Context
import java.util.concurrent.atomic.AtomicReference

/**
 * Captures the boot-time integrity verdicts into a single string the network
 * layer can stamp onto every outbound request. The server inspects the header
 * and (eventually) refuses high-stakes RPCs from clients that self-report a
 * dirty state.
 *
 * "But a tampered client can lie about this header" — yes. The server still
 * cross-checks against the Play Integrity attestation token on sensitive
 * actions (KYC submit, payout release, checkout). This header is the cheap
 * first signal, not the final word. Two purposes:
 *   1. Catches lazy mods that didn't strip the integrity layer (the common
 *      case — most modders patch one if-statement, not the whole pipeline).
 *   2. Lets the server log + observe what real installs look like vs. the
 *      tail of suspect installs, even when the verdict is Unknown.
 *
 * Thread-safety: snapshot lives in an AtomicReference set once at app boot.
 * The network layer reads it from any thread without blocking.
 */
object IntegritySnapshot {

    /** Compact comma-separated form. Empty string until captured. */
    private val current = AtomicReference("")

    fun capture(
        context: Context,
        sig: SignatureVerifier.Verdict,
        install: InstallSourceVerifier.Verdict,
        device: DeviceIntegrityCheck.Verdict,
        reTools: ReverseEngineeringDetector.Verdict,
    ) {
        val parts = buildList {
            add("sig=${sig.name.lowercase()}")
            add("install=${install.name.lowercase()}")
            add("re=${reTools.foundPackages.size}")
            if (device.rooted) add("root=1")
            if (device.emulator) add("emu=1")
            if (device.fridaDetected) add("frida=1")
            if (device.debuggerAttached) add("dbg=1")
        }
        current.set(parts.joinToString(","))
    }

    /** Empty string before capture (e.g. tests). */
    fun header(): String = current.get()
}
