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
import com.equipseva.app.testing.ContractFixture
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
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.Instant

/**
 * INT-04, Kotlin half (claudedev-help M1 frozen slice) — the r3820 client's
 * photo-evidence shape is proven against the shared cross-layer fixture
 * `supabase/tests/android_evidence_contract.json`, the same file the Node
 * half (`supabase/tests/evidence_client_contract.test.mjs`) executes against
 * the actual round3821 `register_evidence` on PGlite. Every regex, literal and
 * expected value below is READ from that file at runtime through
 * [ContractFixture]; nothing is retyped here, so the two layers cannot
 * silently drift apart.
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
 * segments, uid, job id, filename charset and forbidden names, the declared
 * prefix set, lowercase sha, kinds, source, producer) and the sanitizer table,
 * in list order.
 *
 * Vacuity guards, because this path has several silent gates (job not loaded,
 * viewer not Engineer, wrong status, blank uid) that would leave the captured
 * list EMPTY and let a conformance loop pass over nothing: the post-load state
 * is asserted first (job, Engineer role, engineer row id, idle flags), then
 * `coVerify(exactly = photos.size)` and `captured.size == photos.size` are
 * asserted BEFORE any loop, and each test finally proves the coroutine ran to
 * its end (`updateStatus` fired once with a non-null `completedAt` and the job
 * reads Completed; or the location fetch was reached and the check-in degraded
 * with exactly one message that names the missing location and no RPC).
 *
 * uid segment: the client writes `session.user.id` (here the fixture's
 * `identities.engineer_uid`, delivered through [FakeAuthRepository]) as the
 * first path segment, while the server compares that segment with
 * `auth.uid()` (the JWT `sub`). Their equality is a GoTrue invariant assumed
 * by both test sides and not observed in this slice, DEV-01 being BLOCKED (fixture key
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

    private val fixture: ContractFixture get() = ContractFixture.instance
    private val rules: ContractFixture.Rules get() = fixture.rules

    private val uid = fixture.identities.engineerUid
    private val hospitalUid = fixture.identities.hospitalUid
    private val jobId = fixture.identities.jobId

    private val stash = mockk<PhotoUploadStash>()
    private val jobRepository = mockk<RepairJobRepository>()
    private val enqueues = mutableListOf<Enqueue>()
    private val statusWrites = mutableListOf<StatusWrite>()
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

        val after = fixture.afterExample
        enqueues.forEachIndexed { i, e ->
            assertEnqueueConforms(
                index = i,
                e = e,
                prefix = after.storedNamePrefix,
                expectedContext = PhotoUploadPayload.CONTEXT_REPAIR_JOB_AFTER,
                row = table[i],
            )
            assertEquals("fixture.kotlin.after_context", fixture.kotlinBlock.afterContext, e.contextType)
            assertRegistrationConforms(index = i, e = e, expectedKind = after.evidenceKind)
        }

        // The coroutine ran to its end: markDone() -> transitionStatus(Completed, setCompletedAt = true)
        // fired exactly once and landed. completedAt must be NON-null (the write stamps completion),
        // startedAt and cancellationReason null — asserted on the recorded call, not inferred from state.
        coVerify(exactly = 1) {
            jobRepository.updateStatus(jobId, RepairJobStatus.Completed, isNull(), any(), isNull())
        }
        assertEquals("exactly one status write", 1, statusWrites.size)
        val write = statusWrites.single()
        assertEquals(jobId, write.jobId)
        assertEquals(RepairJobStatus.Completed, write.newStatus)
        assertNull("markDone sets no startedAt", write.startedAt)
        assertNotNull("markDone (setCompletedAt = true) must stamp completedAt", write.completedAt)
        assertNull("markDone carries no cancellation reason", write.cancellationReason)
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

        val before = fixture.conformingExample
        enqueues.forEachIndexed { i, e ->
            assertEnqueueConforms(
                index = i,
                e = e,
                prefix = before.storedNamePrefix,
                expectedContext = PhotoUploadPayload.CONTEXT_REPAIR_JOB_BEFORE,
                row = fixture.sanitizerTable[i],
            )
            assertEquals("fixture.kotlin.before_context", fixture.kotlinBlock.beforeContext, e.contextType)
            assertRegistrationConforms(index = i, e = e, expectedKind = before.evidenceKind)
        }

        // checkIn() was reached AFTER the enqueue loop and degraded on the missing fix:
        // exactly one location attempt, one user message, no geo RPC, no status write, flag reset, status unchanged.
        coVerify(exactly = 1) { fetchCurrentLocation(any(), any()) }
        coVerify(exactly = 0) { jobRepository.engineerCheckInWithGeo(any(), any(), any()) }
        coVerify(exactly = 0) { jobRepository.updateStatus(any(), any(), any(), any(), any()) }
        assertTrue("no status write may be recorded on the no-fix branch", statusWrites.isEmpty())
        assertEquals("the no-fix branch emits exactly one message", 1, messages.size)
        // The message identifies the no-fix branch (not the sign-in gate, not a geo RPC failure).
        assertTrue(
            "the single message must name the missing location, got: ${messages.single()}",
            messages.single().contains("location", ignoreCase = true),
        )
        val s = vm.state.value
        assertFalse(s.updatingStatus)
        assertEquals(RepairJobStatus.Assigned, s.job?.status)
    }

    @Test fun `fixture is self-consistent with the client constants and its own declared sanitizer`() {
        // Worked examples satisfy the rules they sit next to.
        for ((label, example) in listOf(
            "conforming_example" to fixture.conformingExample,
            "after_example" to fixture.afterExample,
        )) {
            val url = example.storageUrl
            assertTrue("$label storage_url '$url' does not match storage_url_regex", rules.storageUrlRegex.matches(url))
            val segments = url.split('/')
            assertEquals("$label segment count", rules.segmentCount, segments.size)
            assertEquals("$label bucket segment", rules.bucket, segments.first())
            assertEquals("$label storage_url is bucket/object_path", rules.bucket + "/" + example.objectPath, url)
            assertTrue(
                "$label last segment '${segments.last()}' does not match client_stored_name_regex",
                rules.clientStoredNameRegex.matches(segments.last()),
            )
            assertTrue(
                "$label last segment '${segments.last()}' does not match filename_regex",
                rules.filenameRegex.matches(segments.last()),
            )
            assertFalse("$label filename is forbidden", segments.last() in rules.filenameForbidden)
            assertTrue(
                "$label prefix '${example.storedNamePrefix}' is not in rules.prefixes ${rules.prefixes}",
                example.storedNamePrefix in rules.prefixes,
            )
            assertTrue("$label evidence_kind not in rules.evidence_kinds", example.evidenceKind in rules.evidenceKinds)
            assertEquals("$label source_kind", rules.sourceKind, example.sourceKind)
            assertEquals("$label producer_kind", rules.producerKind, example.producerKind)
            assertTrue("$label content_sha256 shape", rules.sha256Regex.matches(example.contentSha256))
            assertTrue("$label content_size_bytes floor", example.contentSizeBytes >= rules.sizeMin)
            assertTrue(
                "$label platform_version '${example.platformVersion}' off platform_version_regex",
                rules.platformVersionRegex.matches(example.platformVersion),
            )
            assertTrue(
                "$label platform_version not among platform_version_examples_accepted",
                example.platformVersion in fixture.platformVersionExamplesAccepted,
            )
            assertEquals("$label metadata keys", rules.metadataKeys.toSet(), example.metadata.keys)
            assertEquals("$label metadata.captured_from", rules.metadataCapturedFrom, example.metadata["captured_from"])
            assertEquals("$label metadata.client", rules.metadataClient, example.metadata["client"])
        }
        // The two examples cover BOTH client prefixes, and the declared prefix set is exactly those two.
        assertEquals(
            "rules.prefixes must be exactly the two example prefixes",
            setOf(fixture.conformingExample.storedNamePrefix, fixture.afterExample.storedNamePrefix),
            rules.prefixes.toSet(),
        )
        assertEquals("two distinct prefixes", 2, rules.prefixes.toSet().size)
        assertNotEquals(fixture.conformingExample.evidenceKind, fixture.afterExample.evidenceKind)
        fixture.platformVersionExamplesAccepted.forEach { v ->
            assertTrue("accepted platform example '$v' off platform_version_regex", rules.platformVersionRegex.matches(v))
        }

        // Every storage_url mutation the Node side expects r3821 to deny is also rejected by the fixture regex,
        // so the Kotlin rule is at least as strict as the SQL it stands in for.
        assertTrue("fixture must carry storage_url variants", fixture.nonConformingUrls.size >= 3)
        fixture.nonConformingUrls.forEach { (id, url) ->
            assertFalse("variant '$id' url '$url' unexpectedly matches storage_url_regex", rules.storageUrlRegex.matches(url))
        }
        // Every variant mutates exactly one property, and every denial names a SQLSTATE the rules declare.
        assertTrue("fixture must carry variants", fixture.nonConformingVariants.isNotEmpty())
        fixture.nonConformingVariants.forEach { v ->
            assertEquals("variant '${v.id}' must mutate exactly one property", 1, v.mutation.size)
            assertEquals("variant '${v.id}' r3821 outcome", "denied", v.r3821.outcome)
            val sqlstate = v.r3821.sqlstate ?: throw AssertionError("variant '${v.id}' r3821 sqlstate missing")
            assertTrue(
                "variant '${v.id}' r3821 sqlstate '$sqlstate' is not one the rules declare",
                sqlstate in rules.serverSqlstates.values,
            )
            val key = v.r3821.sqlstateKey ?: v.r3821.literal
            if (key != null && key in rules.serverSqlstates) {
                assertEquals("variant '${v.id}' sqlstate disagrees with server_sqlstates[$key]", rules.serverSqlstates[key], sqlstate)
            }
            assertEquals(
                "variant '${v.id}' discriminating flag disagrees with its verdicts",
                v.r492.outcome == "accepted" && v.r3821.outcome == "denied",
                v.discriminating,
            )
        }

        // Client constants are the fixture literals.
        assertEquals(rules.bucket, StorageRepository.Buckets.REPAIR_PHOTOS)
        assertEquals(
            rules.evidenceKinds.toSet(),
            setOf(EvidenceRegisterPayload.KIND_PHOTO_BEFORE, EvidenceRegisterPayload.KIND_PHOTO_AFTER),
        )
        assertEquals(rules.sourceKind, EvidenceRegisterPayload.SOURCE_REPAIR_JOB)
        assertEquals(rules.producerKind, EvidenceRegisterPayload.PRODUCER_ENGINEER)
        assertEquals(rules.metadataCapturedFrom, EvidenceRegisterPayload.CAPTURED_FROM_UPLOAD)
        assertEquals(fixture.kotlinBlock.capturedFrom, EvidenceRegisterPayload.CAPTURED_FROM_UPLOAD)
        assertEquals(fixture.kotlinBlock.beforeContext, PhotoUploadPayload.CONTEXT_REPAIR_JOB_BEFORE)
        assertEquals(fixture.kotlinBlock.afterContext, PhotoUploadPayload.CONTEXT_REPAIR_JOB_AFTER)
        assertEquals(fixture.conformingExample.evidenceKind, EvidenceRegisterPayload.evidenceKindFor(fixture.kotlinBlock.beforeContext))
        assertEquals(fixture.afterExample.evidenceKind, EvidenceRegisterPayload.evidenceKindFor(fixture.kotlinBlock.afterContext))
        assertTrue(fixture.conformingExample.evidenceKind in rules.evidenceKinds)
        assertTrue(fixture.afterExample.evidenceKind in rules.evidenceKinds)

        // The pinned digest really is the digest of the pinned bytes, and the conforming example carries the same bytes.
        assertEquals(fixture.kotlinBlock.contentSha256, fixture.kotlinBlock.photoBytes.sha256Hex())
        assertTrue(rules.sha256Regex.matches(fixture.kotlinBlock.contentSha256))
        assertEquals(fixture.kotlinBlock.contentSizeBytes, fixture.kotlinBlock.photoBytes.size.toLong())
        assertTrue(fixture.kotlinBlock.contentSizeBytes >= rules.sizeMin)
        assertEquals(fixture.kotlinBlock.contentSha256, fixture.conformingExample.contentSha256)
        assertEquals(fixture.kotlinBlock.contentSizeBytes, fixture.conformingExample.contentSizeBytes)

        // Identities are canonical lowercase uuids (storage_url_regex requires that of the uid and job segments)
        // and the engineer is not the hospital (otherwise resolveViewerRole yields Hospital, not Engineer).
        listOf(fixture.identities.engineerUid, fixture.identities.hospitalUid, fixture.identities.jobId).forEach { id ->
            assertTrue("identity '$id' does not match uuid_regex", rules.uuidRegex.matches(id))
        }
        assertNotEquals(fixture.identities.engineerUid, fixture.identities.hospitalUid)
        assertEquals(
            "conforming_example object_path starts with engineer_uid/job_id",
            listOf(fixture.identities.engineerUid, fixture.identities.jobId),
            fixture.conformingExample.objectPath.split('/').take(2),
        )

        // The sanitizer table agrees with the sanitizer rule declared beside it (take first, then replace).
        fixture.sanitizerTable.forEach { row ->
            val declared = row.input.take(rules.sanitizerTake).replace(rules.sanitizerReplaceRegex, rules.sanitizerReplacement)
            assertEquals("sanitizer_table row '${row.input}' disagrees with rules.sanitizer", row.expected, declared)
        }

        // The fixture states what it does not prove; this class's KDoc mirrors that list.
        assertEquals(4, fixture.notProvenHere.size)
    }

    /**
     * The shape `EvidenceRegisterPayloadTest` pinned before this slice
     * (`bucket/<uid>/<file>`, no job segment) is exactly what round3821
     * denies with `evidence_object_not_authorized`. The fixture carries that
     * defect as the discriminating variant `three_segments_legacy_fixture`
     * (r492 accepts it, r3821 denies it); here the Kotlin rule is shown to
     * reject the same url, with the fixture's own SQLSTATE cross-checked
     * against `rules.server_sqlstates`. Full conformance of the corrected
     * client shape is proven by the VM-driven tests above, not by a literal.
     */
    @Test fun `legacy three-segment payload-test fixture shape fails the round3821 storage url rule`() {
        val variant = fixture.variant("three_segments_legacy_fixture")
            ?: throw AssertionError("fixture variant three_segments_legacy_fixture missing")
        val legacy = variant.mutation["storage_url"]
            ?: throw AssertionError("three_segments_legacy_fixture must mutate storage_url")

        // Documented legacy failure: three segments where round3821 requires segment_count.
        assertEquals(3, legacy.split('/').size)
        assertNotEquals(rules.segmentCount, legacy.split('/').size)
        assertEquals("legacy shape still carries the bucket", rules.bucket, legacy.split('/').first())
        assertEquals("legacy shape still carries the engineer uid", fixture.identities.engineerUid, legacy.split('/')[1])
        assertFalse("legacy shape must fail storage_url_regex", rules.storageUrlRegex.matches(legacy))

        // The fixture's verdicts: production accepts, the candidate denies with a declared SQLSTATE.
        assertEquals("accepted", variant.r492.outcome)
        assertEquals("denied", variant.r3821.outcome)
        assertTrue(variant.discriminating)
        val literal = variant.r3821.literal
            ?: throw AssertionError("three_segments_legacy_fixture must name its RAISE literal")
        assertEquals(rules.serverSqlstates.getValue(literal), variant.r3821.sqlstate)
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
        assertTrue("no status write may precede the action", statusWrites.isEmpty())
    }

    private fun photosFromSanitizerTable(): List<RepairJobDetailViewModel.CompletionProofPhoto> =
        fixture.sanitizerTable.map { row ->
            RepairJobDetailViewModel.CompletionProofPhoto(
                fileName = row.input,
                mimeType = MIME,
                bytes = fixture.kotlinBlock.photoBytes.copyOf(),
            )
        }

    /** The stash call itself: bucket, `<uid>/<job>/<prefix>-<millis>-<uuid>-<sanitized>`, context, owner. */
    private fun assertEnqueueConforms(
        index: Int,
        e: Enqueue,
        prefix: String,
        expectedContext: String,
        row: ContractFixture.SanitizerRow,
    ) {
        val where = "enqueue[$index] for fileName '${row.input}'"
        assertEquals("$where bucket", rules.bucket, e.bucket)
        assertEquals("$where contextType", expectedContext, e.contextType)
        assertEquals("$where contextId", jobId, e.contextId)
        assertEquals("$where uploaderUserId", uid, e.uploaderUserId)
        assertEquals("$where mimeType", MIME, e.mimeType)
        assertTrue("$where bytes", e.bytes.contentEquals(fixture.kotlinBlock.photoBytes))

        val parts = e.objectPath.split('/')
        // Bucket-relative: one segment fewer than the bucket-prefixed storage_url.
        assertEquals("$where objectPath '${e.objectPath}' must be uid/job/storedName", rules.segmentCount - 1, parts.size)
        assertEquals("$where uid segment", uid, parts[0])
        assertEquals("$where job segment", jobId, parts[1])
        val storedName = parts[2]
        assertTrue(
            "$where storedName '$storedName' does not match client_stored_name_regex",
            rules.clientStoredNameRegex.matches(storedName),
        )
        assertTrue(
            "$where storedName '$storedName' does not match filename_regex",
            rules.filenameRegex.matches(storedName),
        )
        assertTrue("$where expected prefix '$prefix' is not in rules.prefixes ${rules.prefixes}", prefix in rules.prefixes)
        assertTrue("$where storedName prefix", storedName.startsWith("$prefix-"))
        assertTrue(
            "$where storedName prefix '${storedName.substringBefore('-')}' is not in rules.prefixes ${rules.prefixes}",
            storedName.substringBefore('-') in rules.prefixes,
        )
        assertFalse("$where storedName is a forbidden filename", storedName in rules.filenameForbidden)
        assertTrue("$where storedName must end with the sanitized name", storedName.endsWith("-" + row.expected))

        // Decompose <prefix>-<millis>-<uuid>-<sanitized> so the REAL sanitizer's output is compared for
        // equality (in table order), not merely as a suffix.
        val afterPrefix = storedName.removePrefix("$prefix-")
        val millis = afterPrefix.substringBefore('-')
        assertTrue("$where millis '$millis'", millis.isNotEmpty() && millis.all { it.isDigit() })
        val afterMillis = afterPrefix.substringAfter('-')
        val uuidPart = afterMillis.take(UUID_LEN)
        assertTrue("$where uuid '$uuidPart' does not match uuid_regex", rules.uuidRegex.matches(uuidPart))
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
        val payload = EvidenceRegisterPayload.forUploadedPhoto(upload, receipt, e.uploaderUserId, nowIso = { capturedAt })
        assertNotNull("$where forUploadedPhoto returned null for an evidence context", payload)
        payload!!

        assertEquals("$where storageUrl", rules.bucket + "/" + e.objectPath, payload.storageUrl)
        assertTrue(
            "$where storageUrl '${payload.storageUrl}' does not match storage_url_regex",
            rules.storageUrlRegex.matches(payload.storageUrl),
        )
        val segments = payload.storageUrl.split('/')
        assertEquals("$where segment count", rules.segmentCount, segments.size)
        assertEquals("$where segments", listOf(rules.bucket, uid, jobId, e.objectPath.substringAfterLast('/')), segments)

        assertEquals("$where evidenceKind", expectedKind, payload.evidenceKind)
        assertTrue("$where evidenceKind not in fixture.evidence_kinds", payload.evidenceKind in rules.evidenceKinds)
        assertEquals("$where sourceKind", rules.sourceKind, payload.sourceKind)
        assertEquals("$where sourceId", jobId, payload.sourceId)
        assertEquals("$where producerKind", rules.producerKind, payload.producerKind)
        assertEquals("$where producerUserId", uid, payload.producerUserId)
        assertEquals("$where contentSha256", fixture.kotlinBlock.contentSha256, payload.contentSha256)
        assertTrue("$where contentSha256 shape", rules.sha256Regex.matches(payload.contentSha256))
        assertEquals("$where contentSizeBytes", fixture.kotlinBlock.contentSizeBytes, payload.contentSizeBytes)
        assertTrue("$where contentSizeBytes floor", payload.contentSizeBytes >= rules.sizeMin)
        assertEquals("$where mimeType", MIME, payload.mimeType)
        assertEquals("$where capturedAt", capturedAt, payload.capturedAt)
    }

    /** The fixture's conforming capture instant, injected through `nowIso`. */
    private val capturedAt: String get() = fixture.conformingExample.capturedAt

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
     * `updateStatus` records its arguments (same pattern as the enqueue record) so the after-photos
     * test can assert the NON-null completedAt directly instead of matching on a nullable Instant.
     */
    private fun build(job: RepairJob): RepairJobDetailViewModel {
        coEvery { jobRepository.fetchById(jobId) } returns Result.success(job)
        coEvery { jobRepository.updateStatus(any(), any(), any(), any(), any()) } coAnswers {
            statusWrites += StatusWrite(
                jobId = arg(0),
                newStatus = arg(1),
                startedAt = arg(2),
                completedAt = arg(3),
                cancellationReason = arg(4),
            )
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

    /** One recorded [RepairJobRepository.updateStatus] call. */
    private class StatusWrite(
        val jobId: String,
        val newStatus: RepairJobStatus,
        val startedAt: Instant?,
        val completedAt: Instant?,
        val cancellationReason: String?,
    )

    private companion object {
        const val ENGINEER_ROW_ID = "eng-row-1"
        const val MIME = "image/jpeg"

        /** Canonical java.util.UUID string length; the slice is then proven against fixture uuid_regex. */
        const val UUID_LEN = 36
    }
}
