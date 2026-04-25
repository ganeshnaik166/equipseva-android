package com.equipseva.app.core.observability

import android.os.SystemClock
import android.util.Log
import io.sentry.ITransaction
import io.sentry.Sentry
import io.sentry.SpanStatus
import java.util.concurrent.atomic.AtomicReference

/**
 * Cold-start → first-frame timing baseline.
 *
 * Captures the wall-clock elapsed between [markStart] (first thing in
 * [Application.onCreate]) and [markReady] (right before
 * [Activity.setContent] returns control to the framework). The intent is
 * to establish a baseline so we can set an SLO once telemetry from real
 * devices comes back — see PR body for the p95 target.
 *
 * Behavior:
 * - Uses [SystemClock.elapsedRealtime] so deep sleep doesn't poison the
 *   measurement.
 * - Always logs the duration at INFO so the value is visible in logcat
 *   even when no telemetry backend is wired (DSN blank, etc.).
 * - Opens a Sentry transaction named `app.cold_start` lazily; if the
 *   Sentry SDK hasn't been initialized (DSN blank) the SDK returns a
 *   NoOp transaction and finishing it is a free-ish no-op. We still call
 *   it so the path is exercised on every cold start in case the DSN
 *   gets wired later — no behavior changes needed.
 * - The work done here is intentionally trivial (one volatile read, one
 *   subtraction, one log) so it doesn't bias what it's measuring.
 */
object StartupTelemetry {

    private const val TAG = "ColdStart"
    private const val TRANSACTION_NAME = "app.cold_start"
    private const val OP = "app.start"

    private val startElapsedMs = AtomicReference<Long?>(null)
    private val transactionRef = AtomicReference<ITransaction?>(null)
    private val finished = AtomicReference(false)

    /** Call from [Application.onCreate] BEFORE any other init. */
    fun markStart() {
        // Idempotent: only the first call wins. Subsequent calls (e.g. if
        // the process gets recycled mid-startup) are ignored so we don't
        // restart the timer.
        if (!startElapsedMs.compareAndSet(null, SystemClock.elapsedRealtime())) return

        // Sentry.startTransaction returns a NoOp transaction when the SDK
        // isn't initialized, so this is safe to call even when DSN is
        // blank. We don't keep the scope hot — finishing it later closes
        // the span chain.
        val txn = runCatching {
            Sentry.startTransaction(TRANSACTION_NAME, OP)
        }.getOrNull()
        transactionRef.set(txn)
    }

    /**
     * Call from the activity hosting first frame, right after
     * `setContent {}` returns — i.e. the end of [MainActivity.onCreate].
     */
    fun markReady() {
        val start = startElapsedMs.get() ?: return
        if (!finished.compareAndSet(false, true)) return

        val durationMs = SystemClock.elapsedRealtime() - start
        Log.i(TAG, "Cold start ready in ${durationMs}ms")

        val txn = transactionRef.getAndSet(null)
        if (txn != null) {
            runCatching {
                txn.setMeasurement("cold_start_ms", durationMs)
                txn.setTag("phase", "first_frame")
                txn.finish(SpanStatus.OK)
            }
        }
    }
}
