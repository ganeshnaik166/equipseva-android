package com.equipseva.app.core.sync.handlers

import android.util.Log
import com.equipseva.app.core.data.entities.OutboxEntryEntity
import com.equipseva.app.core.storage.StorageRepository
import com.equipseva.app.core.sync.OutboxEnqueuer
import com.equipseva.app.core.sync.OutboxKindHandler
import com.equipseva.app.core.sync.OutboxKinds
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.user.UserInfo
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

/**
 * The stash must not outlive the outbox row that names it.
 *
 * `photo-outbox/` holds a copy of whatever the user picked — a repair photo,
 * but also an Aadhaar or PAN scan on the KYC path, up to 15 MB. The outbox row
 * is the only reference to that copy, so any terminal path that deletes the
 * row without deleting the file leaves an identity document in app storage
 * indefinitely: the next reclaim opportunity is the user signing out, which
 * most never do. Only the success path used to clean up, so an owner mismatch,
 * a rejected file, a permanent storage error and the worker's poison drop all
 * leaked.
 *
 * `android.util.Log` throws on the plain JVM, so it is stubbed; the cleanup
 * helper logs when a delete fails.
 */
class PhotoUploadStashCleanupTest {

    @get:Rule val stashDir = TemporaryFolder()

    private lateinit var storage: StorageRepository
    private lateinit var client: SupabaseClient
    private lateinit var auth: Auth
    private lateinit var enqueuer: OutboxEnqueuer
    private lateinit var handler: PhotoUploadOutboxHandler

    private val json = Json { ignoreUnknownKeys = true }

    @Before fun setUp() {
        mockkStatic(Log::class)
        every { Log.d(any(), any()) } returns 0
        every { Log.d(any(), any(), any()) } returns 0
        every { Log.i(any(), any()) } returns 0
        every { Log.i(any(), any(), any()) } returns 0
        every { Log.w(any(), any<String>()) } returns 0
        every { Log.w(any(), any<Throwable>()) } returns 0
        every { Log.w(any(), any<String>(), any()) } returns 0
        every { Log.e(any(), any()) } returns 0
        every { Log.e(any(), any(), any()) } returns 0
        storage = mockk(relaxed = true)
        enqueuer = mockk(relaxed = true)
        client = mockk()
        auth = mockk()
        mockkStatic("io.github.jan.supabase.auth.AuthKt")
        every { client.auth } returns auth
        handler = PhotoUploadOutboxHandler(storage, client, json, enqueuer)
    }

    @After fun tearDown() {
        unmockkStatic("io.github.jan.supabase.auth.AuthKt")
        unmockkStatic(Log::class)
    }

    private fun signedInAs(uid: String) {
        every { auth.currentUserOrNull() } returns UserInfo(aud = "authenticated", id = uid)
    }

    private fun stashedFile(name: String, bytes: ByteArray = byteArrayOf(1, 2, 3)): File =
        stashDir.newFile(name).also { it.writeBytes(bytes) }

    private fun payload(file: File, uploader: String) = PhotoUploadPayload(
        bucket = "repair-photos",
        objectPath = "repair-photos/${file.name}",
        localFilePath = file.absolutePath,
        mimeType = "image/jpeg",
        contextType = PhotoUploadPayload.CONTEXT_REPAIR_JOB_AFTER,
        contextId = "9b0c0d3e-0000-4000-8000-000000000001",
        uploaderUserId = uploader,
    )

    private fun entry(payloadJson: String) = OutboxEntryEntity(
        kind = OutboxKinds.PHOTO_UPLOAD,
        payload = payloadJson,
        createdAt = 1_700_000_000_000L,
    )

    private fun entryFor(file: File, uploader: String) =
        entry(json.encodeToString(PhotoUploadPayload.serializer(), payload(file, uploader)))

    @Test fun `an owner mismatch drops the row and the stashed bytes with it`() = runTest {
        // The shared-device case: the row was queued by one account and another
        // is signed in now. The row is refused, so nothing will ever read the
        // file again — and it may be the other account's identity document.
        val file = stashedFile("queued-by-someone-else.jpg")
        signedInAs("11111111-1111-4111-8111-111111111111")

        val outcome = handler.handle(entryFor(file, uploader = "22222222-2222-4222-8222-222222222222"))

        assertTrue("got $outcome", outcome is OutboxKindHandler.Outcome.GiveUp)
        assertFalse("stash file survived a permanent refusal", file.exists())
    }

    @Test fun `a zero byte capture drops the row and the stashed bytes with it`() = runTest {
        val uid = "11111111-1111-4111-8111-111111111111"
        val file = stashedFile("truncated.jpg", bytes = byteArrayOf())
        signedInAs(uid)

        val outcome = handler.handle(entryFor(file, uploader = uid))

        assertTrue("got $outcome", outcome is OutboxKindHandler.Outcome.GiveUp)
        assertFalse("stash file survived a permanent refusal", file.exists())
    }

    @Test fun `the worker's drop hook releases the stashed bytes`() = runTest {
        // The poison drop happens in the worker, which knows nothing about
        // files; without this hook the row is deleted and the only reference
        // to the stashed document goes with it.
        val file = stashedFile("poisoned.pdf")

        handler.onDropped(entryFor(file, uploader = "11111111-1111-4111-8111-111111111111"))

        assertFalse("stash file survived the poison drop", file.exists())
    }

    @Test fun `the drop hook tolerates a row it cannot decode`() = runTest {
        // A row from an older build, or a corrupted payload: there is nothing
        // to clean, and throwing here would abort the rest of the drain.
        handler.onDropped(entry("{not json"))
    }
}
