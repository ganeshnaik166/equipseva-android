package com.equipseva.app.core.payments

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.TimeoutCancellationException

/**
 * True when [error] means OUR coroutine was cancelled, so there is nobody
 * left to show a message to and the only correct move is to re-throw.
 *
 * The distinction matters on the money paths. Repositories bound their edge
 * function calls with `withTimeout` INSIDE `runCatching`, so "the gateway
 * took too long" arrives as a `TimeoutCancellationException` in a failed
 * Result — indistinguishable from a real cancellation by type alone. Treating
 * that as cancellation abandons the flow silently: the caller skips its error
 * copy, its crash report and its retry, and a hospital whose card was charged
 * is told nothing at all.
 */
fun isScopeCancellation(error: Throwable?): Boolean =
    error is CancellationException && error !is TimeoutCancellationException
