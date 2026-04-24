package com.equipseva.app.features.kyc

import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.Engineer
import com.equipseva.app.core.data.engineers.EngineerCertificate
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.sync.handlers.PhotoUploadStash
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class KycViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()

    @Before fun setup() { Dispatchers.setMain(dispatcher) }
    @After fun teardown() { Dispatchers.resetMain() }

    @Test fun `save rejects when aadhaar number is present but not 12 digits`() = runTest {
        val auth = FakeAuthRepository(userId = "user-1")
        val repo = FakeEngineerRepository()
        val vm = KycViewModel(auth, repo, FakePhotoUploadStash())
        vm.toggleSpecialization(RepairEquipmentCategory.ImagingRadiology)
        vm.onAadhaarNumberChange("12345")

        val effect = async(vm) { vm.save() }

        assertEquals("Aadhaar must be 12 digits", effect.first().text())
        assertEquals(0, repo.upsertCalls)
    }

    @Test fun `save rejects when no specialization selected`() = runTest {
        val auth = FakeAuthRepository(userId = "user-1")
        val repo = FakeEngineerRepository()
        val vm = KycViewModel(auth, repo, FakePhotoUploadStash())

        val effect = async(vm) { vm.save() }

        assertEquals("Pick at least one specialization", effect.first().text())
        assertEquals(0, repo.upsertCalls)
    }

    @Test fun `save persists certificates with type discriminator`() = runTest {
        val auth = FakeAuthRepository(userId = "user-1")
        val repo = FakeEngineerRepository()
        val vm = KycViewModel(auth, repo, FakePhotoUploadStash())
        vm.toggleSpecialization(RepairEquipmentCategory.ImagingRadiology)

        // simulate prior uploads populating both slots
        vm.uploadAadhaarDoc("scan.jpg", ByteArray(8), "image/jpeg")
        vm.uploadCertificate("c1.pdf", ByteArray(8), "application/pdf")

        vm.save()

        assertEquals(1, repo.upsertCalls)
        val saved = repo.lastCertificates
        assertEquals(2, saved.size)
        assertEquals(EngineerCertificate.TYPE_AADHAAR, saved[0].type)
        assertTrue(saved[0].path.contains("aadhaar-"))
        assertEquals(EngineerCertificate.TYPE_CERT, saved[1].type)
        assertTrue(saved[1].path.contains("cert-"))
    }

    @Test fun `hydrate splits certificates into aadhaar and cert slots`() = runTest {
        val auth = FakeAuthRepository(userId = "user-1")
        val repo = FakeEngineerRepository().apply {
            fetched = engineer(
                certificates = listOf(
                    EngineerCertificate(EngineerCertificate.TYPE_AADHAAR, "user-1/aadhaar-x.jpg", "t1"),
                    EngineerCertificate(EngineerCertificate.TYPE_CERT, "user-1/cert-a.pdf", "t2"),
                    EngineerCertificate(EngineerCertificate.TYPE_CERT, "user-1/cert-b.pdf", "t3"),
                ),
            )
        }
        val vm = KycViewModel(auth, repo, FakePhotoUploadStash())

        // wait for load() to complete
        val state = vm.state.first { !it.loading }

        assertEquals("user-1/aadhaar-x.jpg", state.aadhaarDocPath)
        assertEquals(listOf("user-1/cert-a.pdf", "user-1/cert-b.pdf"), state.certDocPaths)
    }

    @Test fun `save surfaces repository failure as user message`() = runTest {
        val auth = FakeAuthRepository(userId = "user-1")
        val repo = FakeEngineerRepository().apply { upsertError = RuntimeException("boom") }
        val vm = KycViewModel(auth, repo, FakePhotoUploadStash())
        vm.toggleSpecialization(RepairEquipmentCategory.ImagingRadiology)

        val effect = async(vm) { vm.save() }

        val msg = effect.first().text()
        assertTrue("got: $msg", msg.isNotBlank())
        assertNull("save flag should reset", vm.state.value.saving.takeIf { it })
    }

    private suspend fun async(
        vm: KycViewModel,
        block: suspend () -> Unit,
    ): Flow<KycViewModel.Effect> {
        block()
        return vm.effects
    }

    private fun KycViewModel.Effect.text(): String = when (this) {
        is KycViewModel.Effect.ShowMessage -> text
    }

    private fun engineer(
        certificates: List<EngineerCertificate> = emptyList(),
    ): Engineer = Engineer(
        id = "engineer-1",
        userId = "user-1",
        aadhaarNumber = null,
        aadhaarVerified = false,
        qualifications = emptyList(),
        specializations = emptyList(),
        brandsServiced = emptyList(),
        experienceYears = 0,
        serviceRadiusKm = 25,
        city = null,
        state = null,
        verificationStatus = VerificationStatus.Pending,
        backgroundCheckStatus = VerificationStatus.Pending,
        certificates = certificates,
    )
}

private class FakeAuthRepository(userId: String) : AuthRepository {
    override val sessionState: MutableStateFlow<AuthSession> =
        MutableStateFlow(AuthSession.SignedIn(userId = userId, email = "e@x"))

    override suspend fun signInWithEmailPassword(email: String, password: String) = Result.success(Unit)
    override suspend fun sendEmailOtp(email: String) = Result.success(Unit)
    override suspend fun verifyEmailOtp(email: String, token: String) = Result.success(Unit)
    override suspend fun signInWithGoogleIdToken(idToken: String, nonce: String?) = Result.success(Unit)
    override suspend fun signOut() = Result.success(Unit)
    override suspend fun sendPasswordResetEmail(email: String) = Result.success(Unit)
    override suspend fun updatePassword(newPassword: String) = Result.success(Unit)
    override suspend fun updateEmail(newEmail: String) = Result.success(Unit)
}

private class FakePhotoUploadStash : PhotoUploadStash {
    val calls = mutableListOf<String>()
    override suspend fun enqueue(
        bucket: String,
        objectPath: String,
        bytes: ByteArray,
        mimeType: String,
        contextType: String,
        contextId: String,
        uploaderUserId: String,
    ) {
        calls += objectPath
    }
}

private class FakeEngineerRepository : EngineerRepository {
    var fetched: Engineer? = null
    var upsertError: Throwable? = null
    var upsertCalls: Int = 0
    var lastCertificates: List<EngineerCertificate> = emptyList()

    override suspend fun fetchByUserId(userId: String): Result<Engineer?> =
        Result.success(fetched)

    override suspend fun upsert(
        userId: String,
        aadhaarNumber: String?,
        qualifications: List<String>,
        specializations: List<RepairEquipmentCategory>,
        experienceYears: Int,
        serviceRadiusKm: Int,
        city: String?,
        state: String?,
        certificates: List<EngineerCertificate>,
    ): Result<Engineer> {
        upsertCalls++
        lastCertificates = certificates
        upsertError?.let { return Result.failure(it) }
        return Result.success(
            Engineer(
                id = "engineer-1",
                userId = userId,
                aadhaarNumber = aadhaarNumber,
                aadhaarVerified = false,
                qualifications = qualifications,
                specializations = specializations,
                brandsServiced = emptyList(),
                experienceYears = experienceYears,
                serviceRadiusKm = serviceRadiusKm,
                city = city,
                state = state,
                verificationStatus = VerificationStatus.Pending,
                backgroundCheckStatus = VerificationStatus.Pending,
                certificates = certificates,
            )
        )
    }

    override suspend fun uploadKycDoc(
        userId: String,
        fileName: String,
        bytes: ByteArray,
        contentType: String?,
    ): Result<String> = Result.success("$userId/$fileName")

    override suspend fun upsertProfile(
        userId: String,
        hourlyRate: Double,
        yearsExperience: Int,
        serviceAreas: List<String>,
        specializations: List<String>,
        bio: String,
        isAvailable: Boolean,
    ): Result<Engineer> = Result.success(fetched ?: error("FakeEngineerRepository.upsertProfile not stubbed"))
}
