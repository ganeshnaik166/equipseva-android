package com.equipseva.app.features.repair

import android.app.Application
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.engineers.Engineer
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.data.escrow.RepairJobEscrowRepository
import com.equipseva.app.core.data.payouts.EngineerPayoutRepository
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.repair.CostRevisionRepository
import com.equipseva.app.core.data.repair.RepairBidRepository
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.core.storage.StorageRepository
import com.equipseva.app.core.sync.handlers.EvidenceRegisterPayload
import com.equipseva.app.core.sync.handlers.PhotoUploadPayload
import com.equipseva.app.core.sync.handlers.PhotoUploadStash
import com.equipseva.app.core.util.fetchCurrentLocation
import com.equipseva.app.core.util.sha256Hex
import com.equipseva.app.navigation.Routes
import com.equipseva.app.testing.FakeAuthRepository
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkAll
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File

/**
 * INT-04, Kotlin half (claudedev-help M1 frozen slice) — the r3820 client's
 * photo-evidence shape is proven against the shared cross-layer fixture
 * `supabase/tests/android_evidence_contract.json`, the same file the Node
 * half (`supabase/tests/evidence_client_contract.test.mjs`) executes against
 * the actual round3821 `register_evidence` on PGlite. Every regex, literal and
 * expected value below is READ from that file at runtime; nothing is retyped
 * here, so the two layers cannot silently drift apart.
 *
 * What is driven: the REAL [RepairJobDetailViewModel] (its `init { load() }`,
 * viewer-role resolution and the two engineer actions) with the repositories
 * stubbed explicitly. `submitCompletionProof` (after photos) and
 * `submitCheckinWithProof` (before photos) each hand [PhotoUploadStash.enqueue]
 * an object path of the form `<uid>/<job>/<before|after>-<millis>-<uuid>-<sanitized40>`;
 * each captured path is then fed through the REAL
 * [EvidenceRegisterPayload.forUploadedPhoto] with a real
 * [StorageRepository.UploadReceipt] (real [sha256Hex]) and the resulting
 * registration is checked against the fixture rules (bucket literal, four
 * segments, uid, job id, filename charset and forbidden names, lowercase sha,
 * kinds, source, producer) and the sanitizer table, in list order.
 *
 * Vacuity guards, because this path has several silent gates (job not loaded,
 * viewer not Engineer, wrong status, blank uid) that would leave the captured
 * list EMPTY and let a conformance loop pass over nothing: the post-load state
 * is asserted first (job, Engineer role, engineer row id, idle flags), then
 * `coVerify(exactly = photos.size)` and `captured.size == photos.size` are
 * asserted BEFORE any loop, and each test finally proves the coroutine ran to
 * its end (`updateStatus` fired once and the job reads Completed; or the
 * location fetch was reached and the check-in degraded with no RPC).
 *
 * uid segment: the client writes `session.user.id` (here the fixture's
 * `identities.engineer_uid`, delivered through [FakeAuthRepository]) as the
 * first path segment, while the server compares that segment with
 * `auth.uid()` (the JWT `sub`). Their equality is a GoTrue invariant assumed
 * by both test sides and observed only by the DEV-01 device drive (fixture key
 * `uid_source`).
 *
 * NOT proven here (fixture `not_proven_here`, verbatim):
 *  1. Real Supabase Storage stamps `storage.objects.owner_id` and
 *     `metadata.size` for supabase-kt upsert uploads (both harnesses seed
 *     those columns by hand).
 *  2. `SECURITY DEFINER SELECT ... FOR SHARE` privilege on `storage.objects`
 *     under production ownership.
 *  3. That `auth.uid()` equals `session.user.id` at runtime (GoTrue
 *     invariant; see `uid_source`).
 *  4. Anything about the deployed database, which runs round492.
 *
 * Plain JUnit, not Robolectric: the before-photo path ends in `checkIn()` →
 * `fetchCurrentLocation(app)`, whose permission check hits `android.os.Process`
 * (a throwing stub on the plain JVM) and then Play-services location; the
 * top-level function is static-mocked to return `null`, which is exactly the
 * production "no fix" branch (flag reset, one message, no RPC). The
 * [Application] mock is strict so any other touch of it fails loudly instead
 * of wandering into the stubs.
 */
@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class RepairPhotoEvidenceContractTest {

    private val uid = fixture.engineerUid
    private val hospitalUid = fixture.hospitalUid
    private val jobId = fixture.jobId

    private val stash = mockk<PhotoUploadStash>()
    private val jobRepository = mockk<RepairJobRepository>()
    private val enqueues = mutableListOf<Enqueue>()
    private lateinit var vm: RepairJobDetailViewModel

    @Before fun setUp() {
        Dispatchers.setMain(StandardTestDispatcher())
        // Record every enqueue in call order. The VM wraps each call in runCatching,
        // so a throwing stub would be swallowed — assert on the record, never on exceptions.
        coEvery { stash.enqueue(any(), any(), any(), any(), any(), any(), any()) } coAnswers {
            enqueues += Enqueue(
                bucket = arg(0),
                objectPath = arg(1),
                bytes = arg(2),
                mimeType = arg(3),
                contextType = arg(4),
                contextId = arg(5),
                uploaderUserId = arg(6),
            )
        }
    }

    @After fun tearDown() {
        if (this::vm.isInitialized) vm.viewModelScope.cancel()
        Dispatchers.resetMain()
        unmockkAll()
    }

    // ------------------------------------------------------------------ tests

    @Test fun `after photos enqueue as uid slash job slash after-stored-name and the registration conforms to the fixture`() = runTest {
        val table = fixture.sanitizerTable
        assertTrue(
            "sanitizer_table must contain at least one row the sanitizer actually changes",
            table.size >= 2 && table.any { it.input != it.expected },
        )
        build(job(RepairJobStatus.InProgress))
        runCurrent() // drains init.load(), resolvePhotoSignedUrls and refreshEscrow
        assertLoadedAsAssignedEngineer(RepairJobStatus.InProgress)

        val photos = photosFromSanitizerTable()
        vm.submitCompletionProof(photos)
        runCurrent()

        // Vacuity guard BEFORE any conformance loop.
        coVerify(exactly = photos.size) { stash.enqueue(any(), any(), any(), any(), any(), any(), any()) }
        assertEquals("one enqueue per photo, in order", photos.size, enqueues.size)

        enqueues.forEachIndexed { i, e ->
            assertEnqueueConforms(
                index = i,
                e = e,
                prefix = AFTER_PREFIX,
                expectedContext = PhotoUploadPayload.CONTEXT_REPAIR_JOB_AFTER,
                row = table[i],
            )
            assertEquals("fixture.kotlin.after_context", fixture.afterContext, e.contextType)
            assertRegistrationConforms(index = i, e = e, expectedKind = fixture.afterExampleKind)
        }

        // The coroutine ran to its end: markDone() -> transitionStatus(Completed) fired exactly once and landed.
        coVerify(exactly = 1) {
            jobRepository.updateStatus(jobId, RepairJobStatus.Completed, isNull(), any(), isNull())
        }
        val s = vm.state.value
        assertEquals(RepairJobStatus.Completed, s.job?.status)
        assertFalse(s.submittingProof)
        assertFalse(s.updatingStatus)
        assertFalse(s.proofSheetOpen)
    }

    @Test fun `before photos enqueue as uid slash job slash before-stored-name and check-in degrades safely without a location fix`() = runTest {
        mockkStatic("com.equipseva.app.core.util.CurrentLocationKt")
        coEvery { fetchCurrentLocation(any(), any()) } returns null

        build(job(RepairJobStatus.Assigned))
        runCurrent()
        assertLoadedAsAssignedEngineer(RepairJobStatus.Assigned)

        // Subscribe before acting: the VM's message flow has no replay.
        val messages = mutableListOf<String>()
        backgroundScope.launch { vm.messages.collect { messages += it } }
        runCurrent()

        val photos = photosFromSanitizerTable()
        vm.submitCheckinWithProof(photos)
        runCurrent()

        // Vacuity guard BEFORE any conformance loop.
        coVerify(exactly = photos.size) { stash.enqueue(any(), any(), any(), any(), any(), any(), any()) }
        assertEquals("one enqueue per photo, in order", photos.size, enqueues.size)

        enqueues.forEachIndexed { i, e ->
            assertEnqueueConforms(
                index = i,
                e = e,
                prefix = BEFORE_PREFIX,
                expectedContext = PhotoUploadPayload.CONTEXT_REPAIR_JOB_BEFORE,
                row = fixture.sanitizerTable[i],
            )
            assertEquals("fixture.kotlin.before_context", fixture.beforeContext, e.contextType)
            assertRegistrationConforms(index = i, e = e, expectedKind = fixture.conformingExampleKind)
        }

        // checkIn() was reached AFTER the enqueue loop and degraded on the missing fix:
        // exactly one location attempt, one user message, no geo RPC, no status write, flag reset, status unchanged.
        coVerify(exactly = 1) { fetchCurrentLocation(any(), any()) }
        coVerify(exactly = 0) { jobRepository.engineerCheckInWithGeo(any(), any(), any()) }
        coVerify(exactly = 0) { jobRepository.updateStatus(any(), any(), any(), any(), any()) }
        assertEquals("the no-fix branch emits exactly one message", 1, messages.size)
        val s = vm.state.value
        assertFalse(s.updatingStatus)
        assertEquals(RepairJobStatus.Assigned, s.job?.status)
    }

    @Test fun `fixture is self-consistent with the client constants and its own declared sanitizer`() {
        // Worked examples satisfy the rules they sit next to.
        for ((label, url) in listOf(
            "conforming_example" to fixture.conformingExampleUrl,
            "after_example" to fixture.afterExampleUrl,
        )) {
            assertTrue("$label storage_url '$url' does not match storage_url_regex", fixture.storageUrlRegex.matches(url))
            val segments = url.split('/')
            assertEquals("$label segment count", fixture.segmentCount, segments.size)
            assertEquals("$label bucket segment", fixture.bucket, segments.first())
            assertTrue(
                "$label last segment '${segments.last()}' does not match client_stored_name_regex",
                fixture.clientStoredNameRegex.matches(segments.last()),
            )
            assertFalse("$label filename is forbidden", segments.last() in fixture.filenameForbidden)
        }

        // Every storage_url mutation the Node side expects r3821 to deny is also rejected by the fixture regex,
        // so the Kotlin rule is at least as strict as the SQL it stands in for.
        assertTrue("fixture must carry storage_url variants", fixture.nonConformingUrls.size >= 3)
        fixture.nonConformingUrls.forEach { (id, url) ->
            assertFalse("variant '$id' url '$url' unexpectedly matches storage_url_regex", fixture.storageUrlRegex.matches(url))
        }

        // Client constants are the fixture literals.
        assertEquals(fixture.bucket, StorageRepository.Buckets.REPAIR_PHOTOS)
        assertEquals(
            fixture.evidenceKinds.toSet(),
            setOf(EvidenceRegisterPayload.KIND_PHOTO_BEFORE, EvidenceRegisterPayload.KIND_PHOTO_AFTER),
        )
        assertEquals(fixture.sourceKind, EvidenceRegisterPayload.SOURCE_REPAIR_JOB)
        assertEquals(fixture.producerKind, EvidenceRegisterPayload.PRODUCER_ENGINEER)
        assertEquals(fixture.metadataCapturedFrom, EvidenceRegisterPayload.CAPTURED_FROM_UPLOAD)
        assertEquals(fixture.capturedFrom, EvidenceRegisterPayload.CAPTURED_FROM_UPLOAD)
        assertEquals(fixture.beforeContext, PhotoUploadPayload.CONTEXT_REPAIR_JOB_BEFORE)
        assertEquals(fixture.afterContext, PhotoUploadPayload.CONTEXT_REPAIR_JOB_AFTER)
        assertEquals(fixture.conformingExampleKind, EvidenceRegisterPayload.evidenceKindFor(fixture.beforeContext))
        assertEquals(fixture.afterExampleKind, EvidenceRegisterPayload.evidenceKindFor(fixture.afterContext))
        assertTrue(fixture.conformingExampleKind in fixture.evidenceKinds)
        assertTrue(fixture.afterExampleKind in fixture.evidenceKinds)

        // The pinned digest really is the digest of the pinned bytes, and the conforming example carries the same bytes.
        assertEquals(fixture.contentSha256, fixture.photoBytes.sha256Hex())
        assertTrue(fixture.contentSha256Regex.matches(fixture.contentSha256))
        assertEquals(fixture.contentSizeBytes, fixture.photoBytes.size.toLong())
        assertTrue(fixture.contentSizeBytes >= fixture.contentSizeMin)
        assertEquals(fixture.contentSha256, fixture.conformingExampleSha)

        // Identities are canonical lowercase uuids (storage_url_regex requires that of the uid and job segments)
        // and the engineer is not the hospital (otherwise resolveViewerRole yields Hospital, not Engineer).
        listOf(fixture.engineerUid, fixture.hospitalUid, fixture.jobId).forEach { id ->
            assertTrue("identity '$id' does not match uuid_regex", fixture.uuidRegex.matches(id))
        }
        assertNotEquals(fixture.engineerUid, fixture.hospitalUid)

        // The sanitizer table agrees with the sanitizer rule declared beside it (take first, then replace).
        fixture.sanitizerTable.forEach { row ->
            val declared = row.input.take(fixture.sanitizerTake).replace(fixture.sanitizerReplaceRegex, fixture.sanitizerReplacement)
            assertEquals("sanitizer_table row '${row.input}' disagrees with rules.sanitizer", row.expected, declared)
        }
    }

    @Test fun `legacy three-segment payload-test fixture shape fails the round3821 storage url rule`() {
        // What EvidenceRegisterPayloadTest pinned before this slice: bucket/<uid>/<file>, no job segment.
        val legacy = "repair-photos/u1/before-1.jpg"
        assertEquals(3, legacy.split('/').size)
        assertNotEquals(fixture.segmentCount, legacy.split('/').size)
        assertFalse("legacy shape must fail storage_url_regex", fixture.storageUrlRegex.matches(legacy))

        // The fixture carries the same defect as a discriminating variant (r492 accepts it, r3821 denies it).
        val variant = fixture.nonConformingUrls.firstOrNull { it.first == "three_segments_legacy_fixture" }
        assertNotNull("fixture variant three_segments_legacy_fixture missing", variant)
        assertEquals(3, variant!!.second.split('/').size)

        // The corrected EvidenceRegisterPayloadTest fixture has the segment count right. Its ids are not uuids,
        // so it is a unit fixture for string assembly only; full conformance is proven by the VM-driven tests above.
        val corrected = "repair-photos/u1/job-1/before-1.jpg"
        assertEquals(fixture.segmentCount, corrected.split('/').size)
    }

    // --------------------------------------------------------------- helpers

    private fun assertLoadedAsAssignedEngineer(expectedStatus: RepairJobStatus) {
        val s = vm.state.value
        assertFalse("load() has not finished — a stubbed call is still pending", s.loading)
        assertNotNull("load() did not populate the job — a Result-returning stub is missing or failing", s.job)
        assertEquals(expectedStatus, s.job?.status)
        assertEquals(RepairJobDetailViewModel.ViewerRole.Engineer, s.viewerRole)
        assertEquals(ENGINEER_ROW_ID, s.selfEngineerRowId)
        assertFalse(s.updatingStatus)
        assertFalse(s.submittingProof)
        assertTrue("no enqueue may precede the action", enqueues.isEmpty())
    }

    private fun photosFromSanitizerTable(): List<RepairJobDetailViewModel.CompletionProofPhoto> =
        fixture.sanitizerTable.map { row ->
            RepairJobDetailViewModel.CompletionProofPhoto(
                fileName = row.input,
                mimeType = MIME,
                bytes = fixture.photoBytes.copyOf(),
            )
        }

    /** The stash call itself: bucket, `<uid>/<job>/<prefix>-<millis>-<uuid>-<sanitized>`, context, owner. */
    private fun assertEnqueueConforms(
        index: Int,
        e: Enqueue,
        prefix: String,
        expectedContext: String,
        row: SanitizerRow,
    ) {
        val where = "enqueue[$index] for fileName '${row.input}'"
        assertEquals("$where bucket", fixture.bucket, e.bucket)
        assertEquals("$where contextType", expectedContext, e.contextType)
        assertEquals("$where contextId", jobId, e.contextId)
        assertEquals("$where uploaderUserId", uid, e.uploaderUserId)
        assertEquals("$where mimeType", MIME, e.mimeType)
        assertTrue("$where bytes", e.bytes.contentEquals(fixture.photoBytes))

        val parts = e.objectPath.split('/')
        // Bucket-relative: one segment fewer than the bucket-prefixed storage_url.
        assertEquals("$where objectPath '${e.objectPath}' must be uid/job/storedName", fixture.segmentCount - 1, parts.size)
        assertEquals("$where uid segment", uid, parts[0])
        assertEquals("$where job segment", jobId, parts[1])
        val storedName = parts[2]
        assertTrue(
            "$where storedName '$storedName' does not match client_stored_name_regex",
            fixture.clientStoredNameRegex.matches(storedName),
        )
        assertTrue("$where storedName prefix", storedName.startsWith("$prefix-"))
        assertFalse("$where storedName is a forbidden filename", storedName in fixture.filenameForbidden)
        assertTrue("$where storedName must end with the sanitized name", storedName.endsWith("-" + row.expected))

        // Decompose <prefix>-<millis>-<uuid>-<sanitized> so the REAL sanitizer's output is compared for
        // equality (in table order), not merely as a suffix.
        val afterPrefix = storedName.removePrefix("$prefix-")
        val millis = afterPrefix.substringBefore('-')
        assertTrue("$where millis '$millis'", millis.isNotEmpty() && millis.all { it.isDigit() })
        val afterMillis = afterPrefix.substringAfter('-')
        val uuidPart = afterMillis.take(UUID_LEN)
        assertTrue("$where uuid '$uuidPart' does not match uuid_regex", fixture.uuidRegex.matches(uuidPart))
        assertTrue("$where separator after uuid", afterMillis.length > UUID_LEN && afterMillis[UUID_LEN] == '-')
        assertEquals("$where sanitizer output", row.expected, afterMillis.substring(UUID_LEN + 1))
    }

    /** The registration the outbox would send for this enqueue, built the way DefaultPhotoUploadStash + the upload handler build it. */
    private fun assertRegistrationConforms(index: Int, e: Enqueue, expectedKind: String) {
        val where = "registration[$index] for '${e.objectPath}'"
        val upload = PhotoUploadPayload(
            bucket = e.bucket,
            objectPath = e.objectPath,
            // DefaultPhotoUploadStash stores a stash-dir copy; the local path never reaches the ledger.
            localFilePath = "photo-outbox/" + e.objectPath.substringAfterLast('/'),
            mimeType = e.mimeType,
            contextType = e.contextType,
            contextId = e.contextId,
            uploaderUserId = e.uploaderUserId,
        )
        val receipt = StorageRepository.UploadReceipt(
            bucket = e.bucket,
            objectPath = e.objectPath,
            sha256Hex = e.bytes.sha256Hex(),
            sizeBytes = e.bytes.size.toLong(),
        )
        val payload = EvidenceRegisterPayload.forUploadedPhoto(upload, receipt, e.uploaderUserId, nowIso = { CAPTURED_AT })
        assertNotNull("$where forUploadedPhoto returned null for an evidence context", payload)
        payload!!

        assertEquals("$where storageUrl", fixture.bucket + "/" + e.objectPath, payload.storageUrl)
        assertTrue(
            "$where storageUrl '${payload.storageUrl}' does not match storage_url_regex",
            fixture.storageUrlRegex.matches(payload.storageUrl),
        )
        val segments = payload.storageUrl.split('/')
        assertEquals("$where segment count", fixture.segmentCount, segments.size)
        assertEquals("$where segments", listOf(fixture.bucket, uid, jobId, e.objectPath.substringAfterLast('/')), segments)

        assertEquals("$where evidenceKind", expectedKind, payload.evidenceKind)
        assertTrue("$where evidenceKind not in fixture.evidence_kinds", payload.evidenceKind in fixture.evidenceKinds)
        assertEquals("$where sourceKind", fixture.sourceKind, payload.sourceKind)
        assertEquals("$where sourceId", jobId, payload.sourceId)
        assertEquals("$where producerKind", fixture.producerKind, payload.producerKind)
        assertEquals("$where producerUserId", uid, payload.producerUserId)
        assertEquals("$where contentSha256", fixture.contentSha256, payload.contentSha256)
        assertTrue("$where contentSha256 shape", fixture.contentSha256Regex.matches(payload.contentSha256))
        assertEquals("$where contentSizeBytes", fixture.contentSizeBytes, payload.contentSizeBytes)
        assertTrue("$where contentSizeBytes floor", payload.contentSizeBytes >= fixture.contentSizeMin)
        assertEquals("$where mimeType", MIME, payload.mimeType)
        assertEquals("$where capturedAt", CAPTURED_AT, payload.capturedAt)
    }

    private fun job(status: RepairJobStatus) = RepairJob(
        id = jobId,
        jobNumber = "RPR-00040",
        title = "Monitor dead",
        issueDescription = "Monitor dead",
        equipmentCategory = RepairEquipmentCategory.PatientMonitoring,
        equipmentBrand = null,
        equipmentModel = null,
        status = status,
        urgency = RepairJobUrgency.Scheduled,
        estimatedCostRupees = null,
        scheduledDate = null,
        scheduledTimeSlot = null,
        siteLocation = null,
        isAssignedToEngineer = true,
        engineerId = ENGINEER_ROW_ID,
        // Must be non-null and differ from uid, or resolveViewerRole yields Other / Hospital and every action no-ops.
        hospitalUserId = hospitalUid,
        startedAtInstant = null,
        completedAtInstant = null,
        hospitalRating = null,
        hospitalReview = null,
        engineerRating = null,
        engineerReview = null,
        createdAtInstant = null,
        updatedAtInstant = null,
    )

    private fun engineerRow() = Engineer(
        id = ENGINEER_ROW_ID,
        userId = uid,
        aadhaarNumber = null,
        aadhaarVerified = true,
        qualifications = emptyList(),
        specializations = listOf(RepairEquipmentCategory.PatientMonitoring),
        brandsServiced = emptyList(),
        experienceYears = 5,
        serviceRadiusKm = 25,
        city = null,
        state = null,
        verificationStatus = VerificationStatus.Verified,
        backgroundCheckStatus = VerificationStatus.Verified,
        certificates = emptyList(),
    )

    /**
     * Every Result-returning call reached by load()/refreshEscrow()/the action is stubbed explicitly:
     * a relaxed MockK default for kotlin.Result is a broken value that fails inside getOrNull()/fold().
     */
    private fun build(job: RepairJob): RepairJobDetailViewModel {
        coEvery { jobRepository.fetchById(jobId) } returns Result.success(job)
        coEvery { jobRepository.updateStatus(any(), any(), any(), any(), any()) } coAnswers {
            Result.success(job.copy(status = secondArg()))
        }
        return RepairJobDetailViewModel(
            savedState = SavedStateHandle(mapOf(Routes.REPAIR_DETAIL_ARG_ID to jobId)),
            // Strict: only checkIn() -> fetchCurrentLocation(app) touches it, and that function is static-mocked.
            app = mockk<Application>(),
            jobRepository = jobRepository,
            bidRepository = mockk<RepairBidRepository> {
                coEvery { fetchOwnBidForJob(jobId) } returns Result.success(null)
            },
            chatRepository = mockk(relaxed = true),
            authRepository = FakeAuthRepository(AuthSession.SignedIn(uid, "engineer@test.invalid")),
            engineerRepository = mockk<EngineerRepository> {
                coEvery { fetchByUserId(uid) } returns Result.success(engineerRow())
            },
            profileRepository = mockk<ProfileRepository> {
                coEvery { fetchById(any()) } returns Result.success(null)
            },
            userPrefs = mockk<UserPrefs> { every { activeRole } returns flowOf("engineer") },
            outboxEnqueuer = mockk(relaxed = true),
            outboxDao = mockk<OutboxDao> { every { observePendingCountByKind(any()) } returns flowOf(0) },
            reportRepository = mockk(relaxed = true),
            photoUploadStash = stash,
            storageRepository = mockk(relaxed = true),
            costRevisionRepository = mockk<CostRevisionRepository> { every { observePending(jobId) } returns flowOf(null) },
            serviceReportRepository = mockk(relaxed = true),
            repairInvoiceRepository = mockk(relaxed = true),
            escrowRepository = mockk<RepairJobEscrowRepository> {
                coEvery { fetchByJob(jobId) } returns Result.success(null)
            },
            payoutRepository = mockk<EngineerPayoutRepository> {
                coEvery { fetchPayoutStatusForJob(jobId) } returns Result.success(null)
            },
            json = Json,
            analytics = mockk(relaxed = true),
            crashReporter = mockk(relaxed = true),
        ).also { vm = it }
    }

    /** One recorded [PhotoUploadStash.enqueue] call, in the order the VM made it. */
    private class Enqueue(
        val bucket: String,
        val objectPath: String,
        val bytes: ByteArray,
        val mimeType: String,
        val contextType: String,
        val contextId: String,
        val uploaderUserId: String,
    )

    private data class SanitizerRow(val input: String, val expected: String)

    /** Typed, read-once view over the fixture; every value is read from the file, none retyped. */
    private class ContractFixture(root: JsonObject) {
        private val rules = root.obj("rules")
        private val kotlinBlock = root.obj("kotlin")
        private val identities = root.obj("identities")
        private val sanitizer = rules.obj("sanitizer")
        private val conformingExample = root.obj("conforming_example")
        private val afterExample = root.obj("after_example")

        val bucket = rules.str("bucket")
        val segmentCount = rules.int("segment_count")
        val uuidRegex = Regex(rules.str("uuid_regex"))
        val filenameForbidden = rules.strings("filename_forbidden")
        val storageUrlRegex = Regex(rules.str("storage_url_regex"))
        val clientStoredNameRegex = Regex(rules.str("client_stored_name_regex"))
        val contentSha256Regex = Regex(rules.str("content_sha256_regex"))
        val contentSizeMin = rules.int("content_size_min")
        val evidenceKinds = rules.strings("evidence_kinds")
        val sourceKind = rules.str("source_kind")
        val producerKind = rules.str("producer_kind")
        val metadataCapturedFrom = rules.str("metadata_captured_from")
        val sanitizerTake = sanitizer.int("take")
        val sanitizerReplaceRegex = Regex(sanitizer.str("replace_regex"))
        val sanitizerReplacement = sanitizer.str("replacement")

        val sanitizerTable: List<SanitizerRow> = root.req("sanitizer_table").jsonArray
            .map { it.jsonObject }
            .map { SanitizerRow(input = it.str("input"), expected = it.str("expected")) }

        val photoBytes: ByteArray = kotlinBlock.req("photo_bytes").jsonArray
            .map { it.jsonPrimitive.int.toByte() }
            .toByteArray()
        val contentSha256 = kotlinBlock.str("content_sha256")
        val contentSizeBytes = kotlinBlock.req("content_size_bytes").jsonPrimitive.long
        val beforeContext = kotlinBlock.str("before_context")
        val afterContext = kotlinBlock.str("after_context")
        val capturedFrom = kotlinBlock.str("captured_from")

        val engineerUid = identities.str("engineer_uid")
        val hospitalUid = identities.str("hospital_uid")
        val jobId = identities.str("job_id")

        val conformingExampleUrl = conformingExample.str("storage_url")
        val conformingExampleKind = conformingExample.str("evidence_kind")
        val conformingExampleSha = conformingExample.str("content_sha256")
        val afterExampleUrl = afterExample.str("storage_url")
        val afterExampleKind = afterExample.str("evidence_kind")

        /** (variant id, mutated storage_url) for every variant whose mutation touches storage_url. */
        val nonConformingUrls: List<Pair<String, String>> = root.obj("non_conforming_variants").req("variants").jsonArray
            .map { it.jsonObject }
            .mapNotNull { v -> v.obj("mutation")["storage_url"]?.jsonPrimitive?.content?.let { url -> v.str("id") to url } }

        private companion object {
            fun JsonObject.req(key: String) = this[key] ?: throw AssertionError("fixture key '$key' is missing from $FIXTURE_REL")
            fun JsonObject.obj(key: String) = req(key).jsonObject
            fun JsonObject.str(key: String) = req(key).jsonPrimitive.content
            fun JsonObject.int(key: String) = req(key).jsonPrimitive.int
            fun JsonObject.strings(key: String) = req(key).jsonArray.map { it.jsonPrimitive.content }
        }
    }

    private companion object {
        const val FIXTURE_REL = "supabase/tests/android_evidence_contract.json"
        const val ROOT_MARKER = "settings.gradle.kts"
        const val ENGINEER_ROW_ID = "eng-row-1"
        const val MIME = "image/jpeg"
        const val CAPTURED_AT = "2026-09-09T05:00:00Z"
        const val BEFORE_PREFIX = "before"
        const val AFTER_PREFIX = "after"

        /** Canonical java.util.UUID string length; the slice is then proven against fixture uuid_regex. */
        const val UUID_LEN = 36

        /**
         * Gradle runs :app unit tests with cwd = app/, Android Studio uses the repo root; walk up until a
         * directory holds BOTH the fixture and settings.gradle.kts (cf. TaxonomyDriftGuardTest / StringsParityTest).
         */
        val fixture: ContractFixture by lazy {
            val start = File(System.getProperty("user.dir") ?: ".").absoluteFile
            val tried = mutableListOf<String>()
            var dir: File? = start
            while (dir != null) {
                tried += dir.path
                if (File(dir, ROOT_MARKER).isFile && File(dir, FIXTURE_REL).isFile) {
                    val file = File(dir, FIXTURE_REL)
                    return@lazy ContractFixture(Json.parseToJsonElement(file.readText()).jsonObject)
                }
                dir = dir.parentFile
            }
            throw AssertionError(
                "Could not locate $FIXTURE_REL beside $ROOT_MARKER walking up from $start (tried $tried) — " +
                    "fix this test's root resolution; do NOT delete the contract test.",
            )
        }
    }
}
