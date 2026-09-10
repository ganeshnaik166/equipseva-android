package com.equipseva.app.core.sync.handlers

import android.util.Log
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.observability.CrashReporter
import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.OutboxKinds
import com.equipseva.app.core.util.BuildConfigValues
import com.equipseva.app.testing.ContractFixture
import com.equipseva.app.testing.TestSupabaseClient
import com.equipseva.app.testing.TestSupabaseClient.importSyntheticSession
import io.github.jan.supabase.exceptions.RestException
import io.github.jan.supabase.postgrest.exception.PostgrestRestException
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
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.IOException

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
 * passing outcome. The gate cases (no session, producer mismatch, bad sha,
 * zero size, malformed payload) assert ZERO recorded requests; the positive
 * control that a call otherwise happens is the success test in this same
 * class.
 *
 * Identities, the conforming receipt, the sha, the metadata keys and every
 * regex are READ from `supabase/tests/android_evidence_contract.json` through
 * [ContractFixture]; the set of ten `p_*` names is the one thing this test
 * owns (the fixture describes the receipt, the handler owns the RPC shape).
 *
 * Server-error mapping is asserted on the exception the SDK really raises:
 * `PostgrestRestException` (verified against the cached postgrest-kt 3.6.0
 * bytecode: `code`, `hint`, `details` on top of `RestException.statusCode`),
 * with `code` equal to the SQLSTATE the fixture declares for the RAISE
 * literal, and the literal itself reaching [CrashReporter] through the
 * classifier's `Permanent <status>: <message>` reason (the SDK message embeds
 * the PostgREST `message` before its `URL:` line).
 *
 * NOT proven here: real PostgREST behaviour (this engine answers what the
 * test says), real Supabase Storage (no upload happens), the deployed
 * database (production runs round492; the round3821 rules are exercised only
 * by INT-04 on PGlite), and that `auth.uid()` equals `session.user.id` (a
 * GoTrue invariant not observed in this slice: DEV-01 is BLOCKED, see docs/HANDOFF_CLAUDEDEV_HELP.md).
 *
 * `android.util.Log` is a throwing stub on the plain JVM and the handler
 * calls `Log.i` on its success path inside a `catch (Throwable)`; without the
 * `mockkStatic(Log::class)` stub below a Success would silently read as
 * Retry. The stub is the reason this class is plain JUnit, not Robolectric.
 */
class EvidenceRegisterOutboxHandlerIntegrationTest {

    private val fixture: ContractFixture get() = ContractFixture.instance
    private val rules: ContractFixture.Rules get() = fixture.rules

    // Identities mirror supabase/tests/evidence_authorization.fixture.sql through the fixture
    // (ENGINEER = uid(3) assigned to job jid(1); HOSPITAL = uid(1) owns it).
    private val engineerUid = fixture.identities.engineerUid
    private val hospitalUid = fixture.identities.hospitalUid
    private val jobId = fixture.identities.jobId

    /** sha256 of the fixture's `kotlin.photo_bytes` — `kotlin.content_sha256`. */
    private val shaLower = fixture.kotlinBlock.contentSha256
    private val contentSizeBytes = fixture.kotlinBlock.contentSizeBytes

    /** `conforming_example`: 4 segments, bucket / uid / job / `<prefix>-<millis>-<uuid>-<sanitized40>`. */
    private val storageUrl = fixture.conformingExample.storageUrl
    private val capturedAt = fixture.conformingExample.capturedAt
    private val evidenceKind = fixture.conformingExample.evidenceKind
    private val mimeType = fixture.conformingExample.metadata.getValue("mime_type")

    /** Any request that reached the engine on a path other than the RPC. Must stay empty. */
    private val offPathRequests = mutableListOf<String>()

    @Before fun stubAndroidLog() {
        offPathRequests.clear()
        mockkStatic(Log::class)
        every { Log.v(any(), any()) } returns 0
        every { Log.v(any(), any(), any()) } returns 0
        every { Log.d(any(), any()) } returns 0
        every { Log.d(any(), any(), any()) } returns 0
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
    private suspend fun withCase(status: HttpStatusCode, body: String, block: suspend (Case) -> Unit) =
        withEngine({ status to body }, block)

    /**
     * Same as [withCase] but the RPC answer is an arbitrary lambda, which may
     * THROW: the lambda runs inside ktor's `MockEngine`, so a thrown
     * `IOException` propagates as the engine failure — the closest a JVM test
     * gets to a socket dying mid-request. The request is still recorded
     * before the lambda runs.
     */
    private suspend fun withEngine(
        answer: (HttpRequestData) -> Pair<HttpStatusCode, String>,
        block: suspend (Case) -> Unit,
    ) {
        val harness = TestSupabaseClient.build { request ->
            if (request.url.encodedPath != RPC_PATH) {
                val where = "${request.method.value} ${request.url.encodedPath}"
                offPathRequests += where
                throw AssertionError("Unexpected request off the RPC path: $where")
            }
            answer(request)
        }
        val crash = mockk<CrashReporter>(relaxed = true)
        val handler = EvidenceRegisterOutboxHandler(harness.client, Json, crash)
        try {
            block(Case(harness, crash, handler))
        } finally {
            harness.close()
        }
    }

    /** Mirrors `conforming_example` in supabase/tests/android_evidence_contract.json (every value read from it). */
    private fun payload(
        producerUserId: String = engineerUid,
        contentSha256: String = shaLower,
        contentSizeBytes: Long = this.contentSizeBytes,
    ) = EvidenceRegisterPayload(
        evidenceKind = evidenceKind,
        sourceKind = rules.sourceKind,
        sourceId = jobId,
        contentSha256 = contentSha256,
        contentSizeBytes = contentSizeBytes,
        storageUrl = storageUrl,
        producerKind = rules.producerKind,
        producerUserId = producerUserId,
        capturedAt = capturedAt,
        mimeType = mimeType,
    )

    private fun entry(p: EvidenceRegisterPayload) = entry(Json.encodeToString(EvidenceRegisterPayload.serializer(), p))

    private fun entry(rawPayload: String) = OutboxEntryEntity(
        kind = OutboxKinds.EVIDENCE_REGISTER,
        payload = rawPayload,
        createdAt = 1L,
    )

    private fun postgrestError(code: String, message: String): String =
        """{"code":"$code","message":"$message","details":null,"hint":null}"""

    /** The SQLSTATE the fixture declares for a RAISE literal — read, not retyped. */
    private fun sqlstateFor(literal: String): String = rules.serverSqlstates.getValue(literal)

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

    /**
     * A permanent PostgREST denial: [http] carrying a `{code, message}` body
     * whose `code` is the fixture SQLSTATE for [literal]. Proves GiveUp
     * `Permanent <status>`, exactly one RPC request, and exactly one report
     * whose throwable is the SDK's `PostgrestRestException` (status + code)
     * and whose message carries both the classifier prefix and the RAISE
     * literal, so a dashboard can tell WHICH server rule fired.
     */
    private suspend fun assertPermanentDenial(http: HttpStatusCode, literal: String, expectedSqlstate: String) {
        val sqlstate = sqlstateFor(literal)
        assertEquals("fixture server_sqlstates[$literal]", expectedSqlstate, sqlstate)
        withCase(http, postgrestError(sqlstate, literal)) { case ->
            case.harness.client.importSyntheticSession(engineerUid)

            val outcome = case.handler.handle(entry(payload()))

            val reason = giveUpReason(outcome)
            assertTrue("got: $reason", reason.startsWith("Permanent ${http.value}"))
            assertTrue("reason should carry the RAISE literal: $reason", reason.contains(literal))
            singleRpcRequest(case.harness)
            verify(exactly = 1) { case.crash.report(any(), any()) }
            verify(exactly = 1) {
                case.crash.report(
                    match<Throwable> {
                        it is PostgrestRestException && it.statusCode == http.value && it.code == sqlstate
                    },
                    match<String> {
                        it.startsWith("evidence_register permanent failure: Permanent ${http.value}") && it.contains(literal)
                    },
                )
            }
        }
    }

    /** 4xx-by-category, transient-by-definition: must be Retry carrying the RestException, never reported. */
    private suspend fun assertTransientStatusIsRetry(code: Int) {
        withCase(HttpStatusCode.fromValue(code), """{"message":"transient $code"}""") { case ->
            case.harness.client.importSyntheticSession(engineerUid)

            val outcome = case.handler.handle(entry(payload()))

            val cause = retryReason(outcome)
            assertTrue("$code: expected RestException, got $cause", cause is RestException)
            assertEquals(code, (cause as RestException).statusCode)
            assertTrue("$code: expected PostgrestRestException, got $cause", cause is PostgrestRestException)
            assertNull("$code: a body without code yields code == null", (cause as PostgrestRestException).code)
            singleRpcRequest(case.harness)
            verify(exactly = 0) { case.crash.report(any(), any()) }
        }
    }

    /** A 2xx that carries no ledger id: GiveUp + one report with the handler's own locator message. */
    private suspend fun assertNoLedgerIdIsGiveUp(body: String) {
        withCase(HttpStatusCode.OK, body) { case ->
            case.harness.client.importSyntheticSession(engineerUid)

            val outcome = case.handler.handle(entry(payload()))

            val reason = giveUpReason(outcome)
            assertEquals("body=<$body>", "register_evidence returned no ledger id", reason)
            singleRpcRequest(case.harness)
            verify(exactly = 1) { case.crash.report(any(), any()) }
            verify(exactly = 1) {
                case.crash.report(
                    match<Throwable> { it is IllegalStateException },
                    match<String> {
                        it.startsWith("evidence_register: $evidenceKind for ${rules.sourceKind}/") && it.endsWith(jobId)
                    },
                )
            }
        }
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
     * Every expected value and regex comes from the fixture; the ten `p_*`
     * names are the handler's own contract and stay pinned here.
     */
    @Test fun `200 uuid body is Success and the wire request is POST rest v1 rpc register_evidence with exactly the ten p_ parameters`() = runTest {
        withCase(HttpStatusCode.OK, LEDGER_ID_BODY) { case ->
            val token = case.harness.client.importSyntheticSession(engineerUid)
            val p = payload()

            val outcome = case.handler.handle(entry(p))

            assertEquals(OutboxKindHandler.Outcome.Success, outcome)
            val rec = singleRpcRequest(case.harness)
            assertEquals(TestSupabaseClient.HOST, rec.request.url.host)
            assertEquals("Bearer $token", rec.request.headers[HttpHeaders.Authorization])
            assertEquals(TestSupabaseClient.ANON_KEY, rec.request.headers["apikey"])

            val body: JsonObject = Json.parseToJsonElement(rec.body).jsonObject
            assertEquals(RPC_PARAMS, body.keys)

            assertEquals(evidenceKind, body.getValue("p_evidence_kind").jsonPrimitive.content)
            assertTrue(body.getValue("p_evidence_kind").jsonPrimitive.content in rules.evidenceKinds)
            assertEquals(rules.sourceKind, body.getValue("p_source_kind").jsonPrimitive.content)
            val sourceId = body.getValue("p_source_id").jsonPrimitive
            assertTrue("p_source_id must be a JSON string", sourceId.isString)
            assertEquals(jobId, sourceId.content)
            assertTrue("p_source_id must be a lowercase uuid: ${sourceId.content}", rules.uuidRegex.matches(sourceId.content))

            val sha = body.getValue("p_content_sha256").jsonPrimitive.content
            assertEquals(shaLower, sha)
            assertTrue("sha must be lowercase 64-hex: $sha", rules.sha256Regex.matches(sha))

            val size = body.getValue("p_content_size_bytes").jsonPrimitive
            assertFalse("p_content_size_bytes must be a JSON number, not a string", size.isString)
            assertEquals(contentSizeBytes, size.long)
            assertTrue("size floor", size.long >= rules.sizeMin)

            val url = body.getValue("p_storage_url").jsonPrimitive.content
            assertEquals(p.storageUrl, url)
            assertTrue("storage url off the contract regex: $url", rules.storageUrlRegex.matches(url))
            val segments = url.split('/')
            assertEquals("bucket/uid/job/file", rules.segmentCount, segments.size)
            assertEquals(rules.bucket, segments[0])
            assertEquals(engineerUid, segments[1])
            assertTrue("uid segment must be a lowercase uuid", rules.uuidRegex.matches(segments[1]))
            assertEquals(jobId, segments[2])
            assertTrue("job segment must be a lowercase uuid", rules.uuidRegex.matches(segments[2]))
            assertTrue("filename segment off filename_regex", rules.filenameRegex.matches(segments[3]))
            assertFalse("filename segment forbidden", segments[3] in rules.filenameForbidden)

            assertEquals(rules.producerKind, body.getValue("p_producer_kind").jsonPrimitive.content)
            assertEquals(p.capturedAt, body.getValue("p_captured_at").jsonPrimitive.content)

            val platform = body.getValue("p_platform_version").jsonPrimitive.content
            assertEquals("android/" + BuildConfigValues.versionName, platform)
            assertTrue("platform version off the contract regex: $platform", rules.platformVersionRegex.matches(platform))

            val metadata = body.getValue("p_metadata").jsonObject
            assertEquals(rules.metadataKeys.toSet(), metadata.keys)
            assertEquals(mimeType, metadata.getValue("mime_type").jsonPrimitive.content)
            assertEquals(EvidenceRegisterPayload.CAPTURED_FROM_UPLOAD, metadata.getValue("captured_from").jsonPrimitive.content)
            assertEquals(rules.metadataCapturedFrom, metadata.getValue("captured_from").jsonPrimitive.content)
            assertEquals(rules.metadataClient, metadata.getValue("client").jsonPrimitive.content)

            verify(exactly = 0) { case.crash.report(any(), any()) }
        }
    }

    /**
     * round3821 denies an unattached photo with SQLSTATE 42501 → HTTP 403.
     * Catches: a permanent denial being retried forever (burning the outbox
     * attempts budget), or being dropped WITHOUT reaching observability — a
     * photo on the job with no ledger row is the compliance gap the ledger
     * exists to end. The report must carry the real `PostgrestRestException`
     * (status 403, code 42501) and the RAISE literal so dashboards cluster
     * it with sibling denials.
     */
    @Test fun `403 with a 42501 body is GiveUp Permanent 403 and is reported once with the PostgrestRestException`() = runTest {
        assertPermanentDenial(HttpStatusCode.Forbidden, "evidence_photo_not_attached", expectedSqlstate = "42501")
    }

    /**
     * round3821 raises 22023 `evidence_object_size_mismatch` → HTTP 400 when
     * the receipt size disagrees with the stored object. Re-sending the same
     * receipt can never fix that, so it must GiveUp and be reported once.
     */
    @Test fun `400 with a 22023 size-mismatch body is GiveUp Permanent 400 and reported once`() = runTest {
        assertPermanentDenial(HttpStatusCode.BadRequest, "evidence_object_size_mismatch", expectedSqlstate = "22023")
    }

    /**
     * 02000 `repair_job_not_found` → HTTP 400: the job the photo was queued
     * against no longer exists. Catches a "not found" being treated as
     * transient — it would be retried until the attempts cap and never seen.
     */
    @Test fun `400 with a 02000 repair_job_not_found body is GiveUp Permanent 400 and reported once`() = runTest {
        assertPermanentDenial(HttpStatusCode.BadRequest, "repair_job_not_found", expectedSqlstate = "02000")
    }

    /**
     * round3821 RAISEs 40001 `evidence_registration_retry` on a serialization
     * conflict; PostgREST maps 40001 to HTTP 500. The client Retry path is the
     * only thing keeping that server-side retry contract alive. Catches a
     * 5xx being poison-dropped, and a Retry that loses the RestException
     * (the worker records `reason` as the row's lastError). Mapping is
     * asserted on `statusCode` and `code`; the RAISE literal is asserted as
     * CONTAINED in the message (the SDK appends URL and headers after it,
     * which is brittle to pin whole).
     */
    @Test fun `500 with a 40001 evidence_registration_retry body is Retry carrying the PostgrestRestException and is not reported`() = runTest {
        val literal = "evidence_registration_retry"
        val sqlstate = sqlstateFor(literal)
        assertEquals("40001", sqlstate)
        withCase(HttpStatusCode.InternalServerError, postgrestError(sqlstate, literal)) { case ->
            case.harness.client.importSyntheticSession(engineerUid)

            val outcome = case.handler.handle(entry(payload()))

            val cause = retryReason(outcome)
            assertTrue("expected RestException, got $cause", cause is RestException)
            assertEquals(500, (cause as RestException).statusCode)
            assertTrue("expected PostgrestRestException, got $cause", cause is PostgrestRestException)
            assertEquals(sqlstate, (cause as PostgrestRestException).code)
            assertTrue("message should carry the RAISE literal: ${cause.message}", cause.message.orEmpty().contains(literal))
            singleRpcRequest(case.harness)
            verify(exactly = 0) { case.crash.report(any(), any()) }
        }
    }

    /**
     * A 500 whose body is not PostgREST JSON at all (a gateway error page).
     * The SDK cannot decode it and falls back to a `PostgrestRestException`
     * with no `code`; the classifier must still route on the 5xx status and
     * Retry, never GiveUp on the decode failure. Catches a regression that
     * lets the decode fallback surface as a `SerializationException` (which
     * the classifier treats as a malformed-payload GiveUp).
     */
    @Test fun `500 with a non-JSON body is Retry carrying a code-less PostgrestRestException and is not reported`() = runTest {
        withCase(HttpStatusCode.InternalServerError, "<html>oops</html>") { case ->
            case.harness.client.importSyntheticSession(engineerUid)

            val outcome = case.handler.handle(entry(payload()))

            val cause = retryReason(outcome)
            assertTrue("expected PostgrestRestException, got $cause", cause is PostgrestRestException)
            assertEquals(500, (cause as PostgrestRestException).statusCode)
            assertNull("an undecodable body yields no SQLSTATE", cause.code)
            singleRpcRequest(case.harness)
            verify(exactly = 0) { case.crash.report(any(), any()) }
        }
    }

    /**
     * The engine itself fails (socket death, DNS, airplane mode) — no HTTP
     * status exists. The SDK wraps the `IOException` in its
     * `HttpRequestException` (itself an `IOException`), and the classifier
     * must Retry without reporting: the photo is in Storage and the ledger
     * row is still owed. The request IS recorded (the engine saw it before
     * failing), so a passing test proves the call was attempted.
     */
    @Test fun `engine IOException is Retry carrying an IOException and is not reported`() = runTest {
        withEngine({ throw IOException("boom") }) { case ->
            case.harness.client.importSyntheticSession(engineerUid)

            val outcome = case.handler.handle(entry(payload()))

            val cause = retryReason(outcome)
            assertTrue("expected an IOException (or the SDK's HttpRequestException subclass), got $cause", cause is IOException)
            assertTrue("cause should carry the engine message: ${cause.message}", cause.message.orEmpty().contains("boom"))
            singleRpcRequest(case.harness)
            verify(exactly = 0) { case.crash.report(any(), any()) }
        }
    }

    /**
     * 408 is 4xx by category but transient by definition. Catches a
     * regression that folds it into the generic 4xx GiveUp branch — a
     * timed-out registration would be dropped on its first attempt and
     * reported as a permanent failure it is not.
     */
    @Test fun `408 is Retry not GiveUp and is not reported`() = runTest {
        assertTransientStatusIsRetry(408)
    }

    /**
     * 429 is 4xx by category but transient by definition. Catches a
     * regression that folds it into the generic 4xx GiveUp branch — a
     * rate-limited registration would be dropped on its first attempt and
     * reported as a permanent failure it is not.
     */
    @Test fun `429 is Retry not GiveUp and is not reported`() = runTest {
        assertTransientStatusIsRetry(429)
    }

    /**
     * A 200 whose body is blank means the RPC "succeeded" without returning
     * a ledger id, so nothing was registered. Catches the handler treating
     * any 2xx as Success (the photo would be marked evidence with no ledger
     * row and nobody told). The report's throwable is an
     * IllegalStateException and its message is the handler's own
     * "evidence_register: <kind> for <source>/<id>" string, which is what a
     * dashboard needs to find the job.
     */
    @Test fun `200 with a blank body is GiveUp no ledger id and reported once as IllegalStateException`() = runTest {
        assertNoLedgerIdIsGiveUp("")
    }

    /** As the blank-body case, for the JSON literal `null` (a uuid-returning RPC that returned NULL). */
    @Test fun `200 with a null literal body is GiveUp no ledger id and reported once as IllegalStateException`() = runTest {
        assertNoLedgerIdIsGiveUp("null")
    }

    /**
     * HANDLER OBSERVATION, recorded for the plan owner — not an endorsement.
     * A 200 whose body is the JSON string `""` (two quote characters) is
     * neither blank nor the literal `null`, so the CURRENT handler treats it
     * as Success and logs an empty ledger id. PostgREST does not return an
     * empty string for a uuid-valued RPC, so this is a corner the handler has
     * not been asked to close; the test pins today's behaviour so a future
     * change (e.g. validating the returned id against `uuid_regex`) is a
     * deliberate, visible decision rather than a silent drift. If the plan
     * owner decides the handler should GiveUp here, THIS test is the one to
     * flip.
     */
    @Test fun `200 with a quoted empty string body is Success today - handler observation for the plan owner`() = runTest {
        val body = "\"\""
        assertFalse("presence proof: the body is not blank", body.isBlank())
        assertNotEquals("presence proof: the body is not the null literal", "null", body)
        withCase(HttpStatusCode.OK, body) { case ->
            case.harness.client.importSyntheticSession(engineerUid)

            val outcome = case.handler.handle(entry(payload()))

            assertEquals(OutboxKindHandler.Outcome.Success, outcome)
            singleRpcRequest(case.harness)
            verify(exactly = 0) { case.crash.report(any(), any()) }
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
        assertNotEquals("presence proof: the two fixture identities differ", engineerUid, hospitalUid)
        withCase(HttpStatusCode.OK, LEDGER_ID_BODY) { case ->
            case.harness.client.importSyntheticSession(hospitalUid)

            val outcome = case.handler.handle(entry(payload(producerUserId = engineerUid)))

            val reason = giveUpReason(outcome)
            assertTrue("got: $reason", reason.startsWith("Producer mismatch"))
            assertTrue("reason should name the queued producer: $reason", reason.contains(engineerUid))
            assertTrue("reason should name the current account: $reason", reason.contains(hospitalUid))
            assertNoHttp(case.harness)
            verify(exactly = 0) { case.crash.report(any(), any()) }
        }
    }

    /**
     * Mirrors the `uppercase_hex_sha` pin in the contract fixture: both
     * round492 and round3821 reject uppercase hex with 22023, and the handler
     * must reject it BEFORE any HTTP call so a malformed receipt never costs
     * a round trip or a server-side error row. Catches the client gate being
     * loosened (or reordered after the RPC call). The uppercase value is
     * derived from the fixture sha and cross-checked against the fixture
     * variant when present.
     */
    @Test fun `uppercase hex sha is rejected client-side with zero HTTP requests`() = runTest {
        // Presence proof: the lowercase sha passes the rule, the uppercase one does not.
        assertTrue(rules.sha256Regex.matches(shaLower))
        val shaUpper = shaLower.uppercase()
        assertNotEquals(shaLower, shaUpper)
        assertFalse(rules.sha256Regex.matches(shaUpper))
        fixture.variant("uppercase_hex_sha")?.let { v ->
            assertEquals("fixture variant uppercase_hex_sha mutation", shaUpper, v.mutation["content_sha256"])
            assertEquals("fixture variant uppercase_hex_sha r3821 sqlstate", "22023", v.r3821.sqlstate)
        }
        withCase(HttpStatusCode.OK, LEDGER_ID_BODY) { case ->
            case.harness.client.importSyntheticSession(engineerUid)

            val outcome = case.handler.handle(entry(payload(contentSha256 = shaUpper)))

            val reason = giveUpReason(outcome)
            assertTrue("got: $reason", reason.startsWith("Evidence payload rejected client-side"))
            assertNoHttp(case.harness)
            verify(exactly = 0) { case.crash.report(any(), any()) }
        }
    }

    /**
     * The fixture's `content_size_min` is 1: a zero-byte receipt cannot be a
     * photo and round3821 would deny it against `storage.objects.metadata`.
     * The handler gates it client-side with zero HTTP calls and no report
     * (it is a malformed receipt, not a compliance gap). Catches the size
     * gate being dropped or weakened to `< 0`.
     */
    @Test fun `zero contentSizeBytes is rejected client-side with zero HTTP requests`() = runTest {
        assertTrue("presence proof: the fixture floor excludes zero", rules.sizeMin > 0)
        withCase(HttpStatusCode.OK, LEDGER_ID_BODY) { case ->
            case.harness.client.importSyntheticSession(engineerUid)

            val outcome = case.handler.handle(entry(payload(contentSizeBytes = 0L)))

            val reason = giveUpReason(outcome)
            assertTrue("got: $reason", reason.startsWith("Evidence payload rejected client-side"))
            assertTrue("reason should name the size: $reason", reason.contains("size=0"))
            assertNoHttp(case.harness)
            verify(exactly = 0) { case.crash.report(any(), any()) }
        }
    }

    /**
     * An outbox row whose payload is not JSON (a stale schema, a corrupted
     * row). Re-decoding will never succeed, so it is GiveUp with the
     * handler's own "Malformed evidence payload" prefix, zero HTTP calls and
     * no report (nothing about the job is knowable from the row). A session
     * IS imported so the gate proven is the payload decode, not the session.
     */
    @Test fun `malformed payload JSON is GiveUp Malformed evidence payload with zero HTTP requests`() = runTest {
        withCase(HttpStatusCode.OK, LEDGER_ID_BODY) { case ->
            case.harness.client.importSyntheticSession(engineerUid)

            val outcome = case.handler.handle(entry("{not json"))

            val reason = giveUpReason(outcome)
            assertTrue("got: $reason", reason.startsWith("Malformed evidence payload"))
            assertNoHttp(case.harness)
            verify(exactly = 0) { case.crash.report(any(), any()) }
        }
    }

    private companion object {
        const val RPC_PATH = "/rest/v1/rpc/register_evidence"

        /** PostgREST returns a uuid-valued RPC result as a quoted JSON string. */
        const val LEDGER_ID_BODY = "\"9b0c0d3e-0000-4000-8000-000000000001\""

        /** The handler's own contract: the ten `p_*` names `register_evidence` declares. */
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
    }
}
