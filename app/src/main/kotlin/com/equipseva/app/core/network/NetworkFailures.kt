package com.equipseva.app.core.network

import io.github.jan.supabase.exceptions.HttpRequestException
import io.github.jan.supabase.exceptions.RestException
import kotlinx.coroutines.TimeoutCancellationException
import java.io.IOException

/**
 * Would handing this failure to the outbox actually deliver the write?
 *
 * Load-bearing wherever a write is optimistically mirrored into local
 * state and handed to the outbox. The drain gives up permanently on a
 * server *refusal* — an invalid status transition, "only the assigned
 * engineer can mark this job complete", an RLS denial, a closed chat —
 * so queueing one drops the row silently while the screen keeps showing
 * the change as applied and promises it will send when back online. A
 * promise the app cannot keep is worse than the error it hid: the user
 * stops looking. So a refusal has to leave local state untouched and
 * surface the server's own reason via [toUserMessage].
 *
 * The mirror of that mistake is refusing to queue something the drain
 * would have delivered, and the HTTP statuses below are exactly where
 * that happens. `classifyOutboxError` retries 401 (PostgREST's expired
 * JWT, which a drain behind a refreshed token sails through), 408 and
 * 429 (4xx by category, transient by spec) and every 5xx — including the
 * ~19 s window where a PostgREST schema-cache reload answers every call
 * with 503. Dropping those on the floor discarded a write the queue was
 * built to carry. Keep this list and the classifier's in step; the pin in
 * `NetworkFailuresTest` fails if they drift.
 *
 * [HttpRequestException] is the SDK's wrapper around an engine-level
 * failure (socket death, DNS, airplane mode) and currently extends
 * [IOException], but it is listed explicitly so a future SDK that
 * re-parents it cannot silently narrow this predicate — the same reason
 * [toUserMessage] names both.
 *
 * [TimeoutCancellationException] is a `CancellationException`, so any
 * caller that rethrows cancellation must consult this predicate FIRST:
 * a `withTimeout` that expired means an unreachable server, not a
 * caller that walked away.
 */
internal fun isNetworkFailure(t: Throwable): Boolean = when {
    t is IOException || t is HttpRequestException || t is TimeoutCancellationException -> true
    t is RestException -> t.statusCode in QUEUEABLE_HTTP_STATUSES || t.statusCode >= 500
    else -> false
}

/**
 * 4xx statuses the drain retries, so a write that hit one still belongs in
 * the queue. Anything else in 4xx is a refusal.
 */
internal val QUEUEABLE_HTTP_STATUSES = setOf(401, 408, 429)
