package com.equipseva.app.features.kyc

import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.Engineer
import com.equipseva.app.core.data.engineers.EngineerCertificate
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.security.IntegrityVerifier
import com.equipseva.app.core.sync.handlers.PhotoUploadStash
import com.equipseva.app.features.auth.UserRole
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
        val vm = newViewModel()
        vm.toggleSpecialization(RepairEquipmentCategory.ImagingRadiology)
        vm.onAadhaarNumberChange("12345")

        val effect = async(vm) { vm.save() }

        assertEquals("Aadhaar must be 12 digits", effect.first().text())
    }

    @Test fun `save rejects when no specialization selected`() = runTest {
        val vm = newViewModel()

        val effect = async(vm) { vm.save() }

        assertEquals("Pick at least one specialization", effect.first().text())
    }

    @Test fun `save persists certificates with type discriminator`() = runTest {
        val repo = FakeEngineerRepository()
        val vm = newViewModel(engineerRepo = repo)
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
        val repo = FakeEngineerRepository().apply {
            fetched = engineer(
                certificates = listOf(
                    EngineerCertificate(EngineerCertificate.TYPE_AADHAAR, "user-1/aadhaar-x.jpg", "t1"),
                    EngineerCertificate(EngineerCertificate.TYPE_CERT, "user-1/cert-a.pdf", "t2"),
                    EngineerCertificate(EngineerCertificate.TYPE_CERT, "user-1/cert-b.pdf", "t3"),
                ),
            )
        }
        val vm = newViewModel(engineerRepo = repo)

        // wait for load() to complete
        val state = vm.state.first { !it.loading }

        assertEquals("user-1/aadhaar-x.jpg", state.aadhaarDocPath)
        assertEquals(listOf("user-1/cert-a.pdf", "user-1/cert-b.pdf"), state.certDocPaths)
    }

    @Test fun `save surfaces repository failure as user message`() = runTest {
        val repo = FakeEngineerRepository().apply { upsertError = RuntimeException("boom") }
        val vm = newViewModel(engineerRepo = repo)
        vm.toggleSpecialization(RepairEquipmentCategory.ImagingRadiology)

        val effect = async(vm) { vm.save() }

        val msg = effect.first().text()
        assertTrue("got: $msg", msg.isNotBlank())
        assertNull("save flag should reset", vm.state.value.saving.takeIf { it })
    }

    private fun newViewModel(
        authRepo: FakeAuthRepository = FakeAuthRepository(userId = "user-1"),
        engineerRepo: FakeEngineerRepository = FakeEngineerRepository(),
        profileRepo: FakeProfileRepository = FakeProfileRepository(),
        photoStash: FakePhotoUploadStash = FakePhotoUploadStash(),
        playIntegrity: FakePlayIntegrityClient = FakePlayIntegrityClient(),
    ): KycViewModel = KycViewModel(
        authRepository = authRepo,
        engineerRepository = engineerRepo,
        profileRepository = profileRepo,
        photoUploadStash = photoStash,
        playIntegrityClient = playIntegrity,
    )

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
    override suspend fun sendPhoneOtp(phone: String) = Result.success(Unit)
    override suspend fun verifyPhoneOtp(phone: String, token: String) = Result.success(Unit)
    override suspend fun requestPhoneAdd(phone: String) = Result.success(Unit)
    override suspend fun verifyPhoneAdd(phone: String, token: String) = Result.success(Unit)
    override suspend fun signOut() = Result.success(Unit)
    override suspend fun sendPasswordResetEmail(email: String) = Result.success(Unit)
    override suspend fun updatePassword(newPassword: String) = Result.success(Unit)
    override suspend fun updateEmail(newEmail: String) = Result.success(Unit)
    override suspend fun refreshSession() = Result.success(Unit)
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

private class FakeProfileRepository : ProfileRepository {
    override suspend fun fetchById(userId: String): Result<Profile?> = Result.success(
        Profile(
            id = userId,
            email = "e@x",
            phone = "+919999999999",
            fullName = "Test Engineer",
            avatarUrl = null,
            role = UserRole.ENGINEER,
            rawRoleKey = "engineer",
            roleConfirmed = true,
            onboardingCompleted = true,
            isActive = true,
            organizationId = null,
            organizationName = null,
            organizationCity = null,
            organizationState = null,
        )
    )
    override suspend fun updateRole(userId: String, role: UserRole) = Result.success(Unit)
    override suspend fun updateBasicInfo(userId: String, fullName: String?, phone: String?) = Result.success(Unit)
    override suspend fun fetchDisplayNames(userIds: List<String>) = Result.success(emptyMap<String, String>())
    override suspend fun addRole(roleKey: String) = Result.success(Unit)
    override suspend fun setActiveRole(roleKey: String) = Result.success(Unit)
}

/**
 * Always-pass integrity verifier — KycViewModel.save() is gated on this; the
 * real Play Integrity check needs Google Play Services so we stub it out for
 * unit tests.
 */
private class FakePlayIntegrityClient : IntegrityVerifier {
    override suspend fun requestVerification(action: String): Result<Boolean> = Result.success(true)
}

private class FakeEngineerRepository : EngineerRepository {
    var fetched: Engineer? = null
    var upsertError: Throwable? = null
    var upsertCalls: Int = 0
    var lastCertificates: List<EngineerCertificate> = emptyList()
    var lastResetVerificationToPending: Boolean = false

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
        aadhaarUploaded: Boolean,
        resetVerificationToPending: Boolean,
    ): Result<Engineer> {
        upsertCalls++
        lastCertificates = certificates
        lastResetVerificationToPending = resetVerificationToPending
        upsertError?.let { return Result.failure(it) }
        return Result.success(
            Engineer(
                id = "engineer-1",
                userId = userId,
                aadhaarNumber = aadhaarNumber,
                aadhaarVerified = aadhaarUploaded,
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
