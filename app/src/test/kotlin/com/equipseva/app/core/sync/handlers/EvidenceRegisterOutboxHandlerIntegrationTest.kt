package com.equipseva.app.core.sync.handlers

import android.util.Log
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.observability.CrashReporter
import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.OutboxKinds
import com.equipseva.app.core.util.BuildConfigValues
import com.equipseva.app.testing.TestSupabaseClient
import com.equipseva.app.testing.TestSupabaseClient.importSyntheticSession
import io.github.jan.supabase.exceptions.RestException
import io.ktor.client.request.HttpRequestData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import io.mockk.verify
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * INT-03 (claudedev-help M1 frozen slice) — the r3820 client half of the
 * photo-evidence contract meets the r3821 server half on the wire.
 *
 * Why this exists: `register_evidence` (round3821) authorizes the caller from
 * the HTTP body it receives — the bucket-prefixed 4-segment `p_storage_url`,
 * a lowercase 64-hex `p_content_sha256`, a numeric `p_content_size_bytes`,
 * `p_producer_kind = engineer`, and the caller's bearer token — and nothing
 * else. Until this class no test exercised [EvidenceRegisterOutboxHandler]
 * at all: `OutboxErrorClassifierTest` proves the Retry/GiveUp routing of a
 * hand-built exception and `EvidenceRegisterPayloadTest` proves the payload
 * builder, but neither proves that the handler puts those values into a
 * `POST /rest/v1/rpc/register_evidence` with exactly the ten `p_*` names the
 * server function declares. A silent rename, a stringified size, or a
 * metadata key drift would pass every existing test and be denied (or,
 * worse, mis-attributed) in production.
 *
 * How: the REAL handler drives a REAL supabase-kt 3.6.0 client (Auth +
 * Postgrest plugins, production code path) whose only network is ktor's
 * `MockEngine` ([TestSupabaseClient]). Every request is recorded before it
 * is answered, and the answer FAILS the test for any path other than the
 * RPC, so a hidden `auth/v1/user` or token-refresh call cannot hide behind a
 * passing outcome. The two gate cases (no session, producer mismatch) and the
 * client-side sha gate assert ZERO recorded requests; the positive control
 * that a call otherwise happens is the success test in this same class.
 *
 * NOT proven here: real PostgREST behaviour (this engine answers what the
 * test says), real Supabase Storage (no upload happens), the deployed
 * database (production runs round492; the round3821 rules are exercised only
 * by INT-04 on PGlite), and that `auth.uid()` equals `session.user.id` (a
 * GoTrue invariant observed only by the DEV-01 device drive).
 *
 * `android.util.Log` is a throwing stub on the plain JVM and the handler
 * calls `Log.i` on its success path inside a `catch (Throwable)`; without the
 * `mockkStatic(Log::class)` stub below a Success would silently read as
 * Retry. The stub is the reason this class is plain JUnit, not Robolectric.
 */
class EvidenceRegisterOutboxHandlerIntegrationTest {

    /** Any request that reached the engine on a path other than the RPC. Must stay empty. */
    private val offPathRequests = mutableListOf<String>()

    @Before fun stubAndroidLog() {
        offPathRequests.clear()
        mockkStatic(Log::class)
        every { Log.i(any(), any()) } returns 0
        every { Log.i(any(), any(), any()) } returns 0
        every { Log.w(any(), any<String>()) } returns 0
        every { Log.w(any(), any<Throwable>()) } returns 0
        every { Log.w(any(), any<String>(), any()) } returns 0
        every { Log.e(any(), any()) } returns 0
        every { Log.e(any(), any(), any()) } returns 0
    }

    @After fun unstubAndroidLog() {
        try {
            assertTrue(
                "The engine saw traffic off the RPC path: $offPathRequests",
                offPathRequests.isEmpty(),
            )
        } finally {
            unmockkStatic(Log::class)
        }
    }

    // ---------------------------------------------------------------- fixtures

    /** One built client + the collaborators the handler needs, closed by [withCase]. */
    private class Case(
        val harness: TestSupabaseClient.Harness,
        val crash: CrashReporter,
        val handler: EvidenceRegisterOutboxHandler,
    )

    /**
     * Builds a fresh harness whose fake PostgREST answers [status]/[body] for
     * the RPC and fails the test for anything else, runs [block], and always
     * closes the client so MockEngine/HttpClient coroutines never leak into
     * the next case.
     */
    private suspend fun withCase(status: HttpStatusCode, body: String, block: suspend (Case) -> Unit) {
        val harness = TestSupabaseClient.build { request ->
            if (request.url.encodedPath != RPC_PATH) {
                val where = "${request.method.value} ${request.url.encodedPath}"
                offPathRequests += where
                throw AssertionError("Unexpected request off the RPC path: $where")
            }
            status to body
        }
        val crash = mockk<CrashReporter>(relaxed = true)
        val handler = EvidenceRegisterOutboxHandler(harness.client, Json, crash)
        try {
            block(Case(harness, crash, handler))
        } finally {
            harness.close()
        }
    }

    /** Mirrors `conforming_example` in supabase/tests/android_evidence_contract.json. */
    private fun payload(
        producerUserId: String = ENGINEER_UID,
        contentSha256: String = SHA_LOWER,
    ) = EvidenceRegisterPayload(
        evidenceKind = EvidenceRegisterPayload.KIND_PHOTO_BEFORE,
        sourceKind = EvidenceRegisterPayload.SOURCE_REPAIR_JOB,
        sourceId = JOB_ID,
        contentSha256 = contentSha256,
        contentSizeBytes = 3L,
        storageUrl = STORAGE_URL,
        producerKind = EvidenceRegisterPayload.PRODUCER_ENGINEER,
        producerUserId = producerUserId,
        capturedAt = CAPTURED_AT,
        mimeType = "image/jpeg",
    )

    private fun entry(p: EvidenceRegisterPayload) = OutboxEntryEntity(
        kind = OutboxKinds.EVIDENCE_REGISTER,
        payload = Json.encodeToString(EvidenceRegisterPayload.serializer(), p),
        createdAt = 1L,
    )

    private fun postgrestError(code: String, message: String): String =
        """{"code":"$code","message":"$message","details":null,"hint":null}"""

    /** The one recorded request, after proving there was exactly one and it hit the RPC. */
    private fun singleRpcRequest(harness: TestSupabaseClient.Harness): TestSupabaseClient.Recorded {
        assertEquals(
            "exactly one HTTP request expected, got ${harness.recorded.map { it.request.url.encodedPath }}",
            1,
            harness.recorded.size,
        )
        val rec = harness.recorded.single()
        assertEquals(HttpMethod.Post, rec.request.method)
        assertEquals(RPC_PATH, rec.request.url.encodedPath)
        return rec
    }

    private fun assertNoHttp(harness: TestSupabaseClient.Harness) {
        assertTrue(
            "no HTTP request may be made, got ${harness.recorded.map { it.request.url.encodedPath }}",
            harness.recorded.isEmpty(),
        )
    }

    private fun giveUpReason(outcome: OutboxKindHandler.Outcome): String {
        assertTrue("expected GiveUp, got $outcome", outcome is OutboxKindHandler.Outcome.GiveUp)
        return (outcome as OutboxKindHandler.Outcome.GiveUp).reason
    }

    private fun retryReason(outcome: OutboxKindHandler.Outcome): Throwable {
        assertTrue("expected Retry, got $outcome", outcome is OutboxKindHandler.Outcome.Retry)
        return (outcome as OutboxKindHandler.Outcome.Retry).reason
    }

    // ------------------------------------------------------------------- tests

    /**
     * The wire contract. Catches: a renamed/dropped/added `p_*` parameter
     * (PostgREST would answer 404 "function not found" for a mismatched
     * signature), `p_content_size_bytes` serialised as a string (round3821
     * compares it to `storage.objects.metadata->>'size'` as a number), a
     * sha that is not lowercase 64-hex, a storage url without the bucket
     * prefix or the job segment (both denied 42501 by round3821), a
     * platform version not of the `android/<versionName>` shape, drifted
     * metadata keys, and a request that carries the anon key but not the
     * caller's bearer token (the server would see `auth.uid()` NULL).
     */
    @Test fun `200 uuid body is Success and the wire request is POST rest v1 rpc register_evidence with exactly the ten p_ parameters`() = runTest {
        withCase(HttpStatusCode.OK, LEDGER_ID_BODY) { case ->
            val token = case.harness.client.importSyntheticSession(ENGINEER_UID)
            val p = payload()

            val outcome = case.handler.handle(entry(p))

            assertEquals(OutboxKindHandler.Outcome.Success, outcome)
            val rec = singleRpcRequest(case.harness)
            assertEquals(TestSupabaseClient.HOST, rec.request.url.host)
            assertEquals("Bearer $token", rec.request.headers[HttpHeaders.Authorization])
            assertEquals(TestSupabaseClient.ANON_KEY, rec.request.headers["apikey"])

            val body: JsonObject = Json.parseToJsonElement(rec.body).jsonObject
            assertEquals(RPC_PARAMS, body.keys)

            assertEquals("photo_before", body.getValue("p_evidence_kind").jsonPrimitive.content)
            assertEquals("repair_job", body.getValue("p_source_kind").jsonPrimitive.content)
            val sourceId = body.getValue("p_source_id").jsonPrimitive
            assertTrue("p_source_id must be a JSON string", sourceId.isString)
            assertEquals(JOB_ID, sourceId.content)
            assertTrue("p_source_id must be a lowercase uuid: ${sourceId.content}", UUID_LOWER.matches(sourceId.content))

            val sha = body.getValue("p_content_sha256").jsonPrimitive.content
            assertEquals(SHA_LOWER, sha)
            assertTrue("sha must be lowercase 64-hex: $sha", SHA256_HEX.matches(sha))

            val size = body.getValue("p_content_size_bytes").jsonPrimitive
            assertFalse("p_content_size_bytes must be a JSON number, not a string", size.isString)
            assertEquals(3L, size.long)

            val storageUrl = body.getValue("p_storage_url").jsonPrimitive.content
            assertEquals(p.storageUrl, storageUrl)
            val segments = storageUrl.split('/')
            assertEquals("bucket/uid/job/file", 4, segments.size)
            assertEquals("repair-photos", segments[0])
            assertEquals(ENGINEER_UID, segments[1])
            assertEquals(JOB_ID, segments[2])

            assertEquals("engineer", body.getValue("p_producer_kind").jsonPrimitive.content)
            assertEquals(p.capturedAt, body.getValue("p_captured_at").jsonPrimitive.content)

            val platform = body.getValue("p_platform_version").jsonPrimitive.content
            assertEquals("android/" + BuildConfigValues.versionName, platform)
            assertTrue("platform version off the contract regex: $platform", PLATFORM_VERSION.matches(platform))

            val metadata = body.getValue("p_metadata").jsonObject
            assertEquals(METADATA_KEYS, metadata.keys)
            assertEquals("image/jpeg", metadata.getValue("mime_type").jsonPrimitive.content)
            assertEquals(EvidenceRegisterPayload.CAPTURED_FROM_UPLOAD, metadata.getValue("captured_from").jsonPrimitive.content)
            assertEquals("upload_time", metadata.getValue("captured_from").jsonPrimitive.content)
            assertEquals("android", metadata.getValue("client").jsonPrimitive.content)

            verify(exactly = 0) { case.crash.report(any(), any()) }
        }
    }

    /**
     * round3821 denies an unattached photo with SQLSTATE 42501 → HTTP 403.
     * Catches: a permanent denial being retried forever (burning the outbox
     * attempts budget), or being dropped WITHOUT reaching observability — a
     * photo on the job with no ledger row is the compliance gap the ledger
     * exists to end. The report must carry the real RestException (status
     * 403) so dashboards cluster it with sibling denials.
     */
    @Test fun `403 with a 42501 body is GiveUp Permanent 403 and is reported once with the RestException`() = runTest {
        withCase(HttpStatusCode.Forbidden, postgrestError("42501", "evidence_photo_not_attached")) { case ->
            case.harness.client.importSyntheticSession(ENGINEER_UID)

            val outcome = case.handler.handle(entry(payload()))

            val reason = giveUpReason(outcome)
            assertTrue("got: $reason", reason.startsWith("Permanent 403"))
            singleRpcRequest(case.harness)
            verify(exactly = 1) { case.crash.report(any(), any()) }
            verify(exactly = 1) {
                case.crash.report(
                    match<Throwable> { it is RestException && it.statusCode == 403 },
                    match<String> { it.startsWith("evidence_register permanent failure: Permanent 403") },
                )
            }
        }
    }

    /**
     * round3821 raises 22023 `evidence_object_size_mismatch` → HTTP 400 when
     * the receipt size disagrees with the stored object. Re-sending the same
     * receipt can never fix that, so it must GiveUp and be reported once.
     */
    @Test fun `400 with a 22023 size-mismatch body is GiveUp Permanent 400 and reported once`() = runTest {
        withCase(HttpStatusCode.BadRequest, postgrestError("22023", "evidence_object_size_mismatch")) { case ->
            case.harness.client.importSyntheticSession(ENGINEER_UID)

            val outcome = case.handler.handle(entry(payload()))

            val reason = giveUpReason(outcome)
            assertTrue("got: $reason", reason.startsWith("Permanent 400"))
            singleRpcRequest(case.harness)
            verify(exactly = 1) { case.crash.report(any(), any()) }
            verify(exactly = 1) {
                case.crash.report(
                    match<Throwable> { it is RestException && it.statusCode == 400 },
                    match<String> { it.startsWith("evidence_register permanent failure: Permanent 400") },
                )
            }
        }
    }

    /**
     * 02000 `repair_job_not_found` → HTTP 400: the job the photo was queued
     * against no longer exists. Catches a "not found" being treated as
     * transient — it would be retried until the attempts cap and never seen.
     */
    @Test fun `400 with a 02000 repair_job_not_found body is GiveUp Permanent 400 and reported once`() = runTest {
        withCase(HttpStatusCode.BadRequest, postgrestError("02000", "repair_job_not_found")) { case ->
            case.harness.client.importSyntheticSession(ENGINEER_UID)

            val outcome = case.handler.handle(entry(payload()))

            val reason = giveUpReason(outcome)
            assertTrue("got: $reason", reason.startsWith("Permanent 400"))
            singleRpcRequest(case.harness)
            verify(exactly = 1) { case.crash.report(any(), any()) }
            verify(exactly = 1) {
                case.crash.report(
                    match<Throwable> { it is RestException && it.statusCode == 400 },
                    match<String> { it.startsWith("evidence_register permanent failure: Permanent 400") },
                )
            }
        }
    }

    /**
     * round3821 RAISEs 40001 `evidence_registration_retry` on a serialization
     * conflict; PostgREST maps 40001 to HTTP 500. The client Retry path is the
     * only thing keeping that server-side retry contract alive. Catches a
     * 5xx being poison-dropped, and a Retry that loses the RestException
     * (the worker records `reason` as the row's lastError). Mapping is
     * asserted on `statusCode`, not on `message` — the SDK embeds URL and
     * headers into the message, which is brittle to pin.
     */
    @Test fun `500 with a 40001 evidence_registration_retry body is Retry carrying the RestException and is not reported`() = runTest {
        withCase(HttpStatusCode.InternalServerError, postgrestError("40001", "evidence_registration_retry")) { case ->
            case.harness.client.importSyntheticSession(ENGINEER_UID)

            val outcome = case.handler.handle(entry(payload()))

            val cause = retryReason(outcome)
            assertTrue("expected RestException, got $cause", cause is RestException)
            assertEquals(500, (cause as RestException).statusCode)
            singleRpcRequest(case.harness)
            verify(exactly = 0) { case.crash.report(any(), any()) }
        }
    }

    /**
     * 408 and 429 are 4xx by category but transient by definition. Catches a
     * regression that folds them into the generic 4xx GiveUp branch — a
     * rate-limited or timed-out registration would be dropped on its first
     * attempt and reported as a permanent failure it is not.
     */
    @Test fun `408 and 429 are Retry not GiveUp and are not reported`() = runTest {
        for (code in listOf(408, 429)) {
            withCase(HttpStatusCode.fromValue(code), """{"message":"transient $code"}""") { case ->
                case.harness.client.importSyntheticSession(ENGINEER_UID)

                val outcome = case.handler.handle(entry(payload()))

                val cause = retryReason(outcome)
                assertTrue("$code: expected RestException, got $cause", cause is RestException)
                assertEquals(code, (cause as RestException).statusCode)
                singleRpcRequest(case.harness)
                verify(exactly = 0) { case.crash.report(any(), any()) }
            }
        }
    }

    /**
     * A 200 whose body is blank or the JSON literal `null` means the RPC
     * "succeeded" without returning a ledger id, so nothing was registered.
     * Catches the handler treating any 2xx as Success (the photo would be
     * marked evidence with no ledger row and nobody told). The report's
     * throwable is an IllegalStateException and its message is the handler's
     * own "evidence_register: <kind> for <source>/<id>" string, which is what
     * a dashboard needs to find the job.
     */
    @Test fun `200 with a blank or null body is GiveUp no ledger id and reported once as IllegalStateException`() = runTest {
        for (body in listOf("", "null")) {
            withCase(HttpStatusCode.OK, body) { case ->
                case.harness.client.importSyntheticSession(ENGINEER_UID)

                val outcome = case.handler.handle(entry(payload()))

                val reason = giveUpReason(outcome)
                assertEquals("body=<$body>", "register_evidence returned no ledger id", reason)
                singleRpcRequest(case.harness)
                verify(exactly = 1) { case.crash.report(any(), any()) }
                verify(exactly = 1) {
                    case.crash.report(
                        match<Throwable> { it is IllegalStateException },
                        match<String> {
                            it.startsWith("evidence_register: photo_before for repair_job/") && it.endsWith(JOB_ID)
                        },
                    )
                }
            }
        }
    }

    /**
     * No session yet (cold start before the auth session is restored) must
     * defer, not drop: the photo is already in Storage and the ledger row is
     * still owed. Catches a Retry that leaks an HTTP call without a bearer
     * token (the server would see `auth.uid()` NULL) — zero requests are
     * asserted. The positive control that a call otherwise happens is the
     * 200 success test in this class, which imports a session and records
     * exactly one request.
     */
    @Test fun `no session is Retry with zero HTTP requests`() = runTest {
        withCase(HttpStatusCode.OK, LEDGER_ID_BODY) { case ->
            // Deliberately NO importSyntheticSession.
            val outcome = case.handler.handle(entry(payload()))

            val cause = retryReason(outcome)
            assertTrue("got $cause", cause is IllegalStateException)
            assertTrue("got: ${cause.message}", cause.message.orEmpty().contains("No auth session"))
            assertNoHttp(case.harness)
            verify(exactly = 0) { case.crash.report(any(), any()) }
        }
    }

    /**
     * The row was queued by one account and the app is now signed in as
     * another (account switch with a stale outbox). The RPC stamps
     * `producer_user_id` from `auth.uid()`, so sending it would file A's photo
     * under B. Catches the handler forwarding the request anyway — zero
     * requests are asserted, and the reason names both ids for the
     * poison-drop log.
     */
    @Test fun `producer mismatch is GiveUp with zero HTTP requests`() = runTest {
        withCase(HttpStatusCode.OK, LEDGER_ID_BODY) { case ->
            case.harness.client.importSyntheticSession(HOSPITAL_UID)

            val outcome = case.handler.handle(entry(payload(producerUserId = ENGINEER_UID)))

            val reason = giveUpReason(outcome)
            assertTrue("got: $reason", reason.startsWith("Producer mismatch"))
            assertTrue("reason should name the queued producer: $reason", reason.contains(ENGINEER_UID))
            assertTrue("reason should name the current account: $reason", reason.contains(HOSPITAL_UID))
            assertNoHttp(case.harness)
            verify(exactly = 0) { case.crash.report(any(), any()) }
        }
    }

    /**
     * Mirrors the `uppercase_hex_sha` pin in the contract fixture: both
     * round492 and round3821 reject uppercase hex with 22023, and the handler
     * must reject it BEFORE any HTTP call so a malformed receipt never costs
     * a round trip or a server-side error row. Catches the client gate being
     * loosened (or reordered after the RPC call).
     */
    @Test fun `uppercase hex sha is rejected client-side with zero HTTP requests`() = runTest {
        withCase(HttpStatusCode.OK, LEDGER_ID_BODY) { case ->
            case.harness.client.importSyntheticSession(ENGINEER_UID)

            val outcome = case.handler.handle(entry(payload(contentSha256 = SHA_UPPER)))

            val reason = giveUpReason(outcome)
            assertTrue("got: $reason", reason.startsWith("Evidence payload rejected client-side"))
            assertNoHttp(case.harness)
            verify(exactly = 0) { case.crash.report(any(), any()) }
        }
    }

    private companion object {
        const val RPC_PATH = "/rest/v1/rpc/register_evidence"

        /** PostgREST returns a uuid-valued RPC result as a quoted JSON string. */
        const val LEDGER_ID_BODY = "\"9b0c0d3e-0000-4000-8000-000000000001\""

        // Identities mirror supabase/tests/evidence_authorization.fixture.sql
        // (ENGINEER = uid(3) assigned to job jid(1); HOSPITAL = uid(1) owns it).
        const val ENGINEER_UID = "10000000-0000-0000-0000-000000000003"
        const val HOSPITAL_UID = "10000000-0000-0000-0000-000000000001"
        const val JOB_ID = "30000000-0000-0000-0000-000000000001"

        /** sha256 of bytes [1, 2, 3] — the fixture's `kotlin.content_sha256`. */
        const val SHA_LOWER = "039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81"
        const val SHA_UPPER = "039058C6F2C0CB492C533B0A4D14EF77CC0F78ABCCCED5287D84A1A2011CFB81"
        const val CAPTURED_AT = "2026-09-09T05:00:00Z"

        /** 4 segments: bucket / uid / job / `<prefix>-<millis>-<uuid>-<sanitized40>`. */
        const val STORAGE_URL =
            "repair-photos/$ENGINEER_UID/$JOB_ID/before-1757394000000-9b0c0d3e-1111-4222-8333-444455556666-IMG_2026-09-09__1_.jpg"

        val RPC_PARAMS = setOf(
            "p_evidence_kind",
            "p_source_kind",
            "p_source_id",
            "p_content_sha256",
            "p_content_size_bytes",
            "p_storage_url",
            "p_producer_kind",
            "p_captured_at",
            "p_platform_version",
            "p_metadata",
        )
        val METADATA_KEYS = setOf("mime_type", "captured_from", "client")

        val SHA256_HEX = Regex("^[0-9a-f]{64}$")
        val UUID_LOWER = Regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
        val PLATFORM_VERSION = Regex("^android/[0-9]+\\.[0-9]+\\.[0-9]+(-debug)?$")
    }
}
