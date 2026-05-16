package com.equipseva.app.core.sync

import com.equipseva.app.core.storage.UploadError
import io.github.jan.supabase.exceptions.HttpRequestException
import io.github.jan.supabase.exceptions.RestException
import kotlinx.serialization.SerializationException
import java.io.IOException

/**
 * Sorts an exception into `Retry` vs `GiveUp`. Every outbox handler
 * funnels its `Result.onFailure` through here so a permanent error
 * (RLS 403, 4xx validation, malformed payload) is dropped immediately
 * instead of consuming the worker's MAX_ATTEMPTS budget — that budget
 * exists to ride out transient outages, not to repeatedly attempt
 * writes the server will never accept.
 *
 * Heuristics, conservative-by-default:
 *  - IOException / HttpRequestException → Retry (network outage).
 *  - RestException 4xx → GiveUp (auth, RLS, missing record, validator
 *    failure — none of these clear themselves over time). Two
 *    exceptions: 408 Request Timeout and 429 Too Many Requests are
 *    transient by definition; treat as Retry so a rate-limited /
 *    timed-out write isn't poison-dropped on the first attempt.
 *  - RestException 5xx → Retry (server temporarily off).
 *  - SerializationException → GiveUp (malformed payload — re-encoding
 *    would change the row, which the worker isn't allowed to do).
 *  - IllegalArgumentException / IllegalStateException → GiveUp. These
 *    fire when a handler discovers its payload doesn't make sense
 *    (e.g. PhotoUploadOutboxHandler hitting a vanished local file, a
 *    null required field, a payload whose `engineerUserId` no longer
 *    matches the signed-in user). Retrying that won't recover.
 *  - Default → Retry. The MAX_ATTEMPTS cap will eventually drop a
 *    truly stuck row to the poison-drop notification path.
 */
fun classifyOutboxError(error: Throwable): OutboxKindHandler.Outcome = when (error) {
    is IOException -> OutboxKindHandler.Outcome.Retry(error)
    is HttpRequestException -> OutboxKindHandler.Outcome.Retry(error)
    is RestException -> when {
        // 408 + 429 are 4xx by category but transient by spec — a
        // rate-limited or timed-out write will succeed on a backoff.
        // Treat as Retry so they don't burn the attempts budget.
        error.statusCode == 408 || error.statusCode == 429 ->
            OutboxKindHandler.Outcome.Retry(error)
        error.statusCode in 400..499 -> OutboxKindHandler.Outcome.GiveUp(
            "Permanent ${error.statusCode}: ${error.message ?: error::class.simpleName}",
        )
        else -> OutboxKindHandler.Outcome.Retry(error)
    }
    is SerializationException -> OutboxKindHandler.Outcome.GiveUp(
        "Malformed payload: ${error.message ?: "decode failed"}",
    )
    // Validator failures from the storage layer (mime/size/path) are
    // permanent — re-trying won't change the file we're handing in.
    is UploadError -> OutboxKindHandler.Outcome.GiveUp(
        "Upload rejected: ${error.message ?: error::class.simpleName}",
    )
    is IllegalArgumentException, is IllegalStateException -> OutboxKindHandler.Outcome.GiveUp(
        "Bad outbox payload: ${error.message ?: error::class.simpleName}",
    )
    else -> OutboxKindHandler.Outcome.Retry(error)
}
