package com.equipseva.app.features.kyc

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.Engineer
import com.equipseva.app.core.data.engineers.EngineerCertificate
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.security.IntegrityVerifier
import com.equipseva.app.core.security.PlayIntegrityClient
import com.equipseva.app.core.storage.StorageRepository
import com.equipseva.app.core.sync.handlers.PhotoUploadPayload
import com.equipseva.app.core.sync.handlers.PhotoUploadStash
import kotlinx.datetime.Clock
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class KycViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val engineerRepository: EngineerRepository,
    private val profileRepository: ProfileRepository,
    private val photoUploadStash: PhotoUploadStash,
    private val playIntegrityClient: IntegrityVerifier,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val errorMessage: String? = null,
        val verificationStatus: VerificationStatus = VerificationStatus.Pending,
        val aadhaarVerified: Boolean = false,
        val aadhaarNumber: String = "",
        val panNumber: String = "",
        // KYC v2: free-text "service address" (multi-line) + map pin replace the
        // legacy city + state pair. Stored on `engineers.city` (overloaded as a
        // free-text label) so the founder zone-density view can group rows by
        // self-reported area.
        val serviceAddress: String = "",
        val serviceLatitude: Double? = null,
        val serviceLongitude: Double? = null,
        val experienceYears: String = "",
        val serviceRadiusKm: String = "25",
        val qualificationDraft: String = "",
        val qualifications: List<String> = emptyList(),
        val selectedSpecializations: Set<RepairEquipmentCategory> = emptySet(),
        val aadhaarDocPath: String? = null,
        val certDocPaths: List<String> = emptyList(),
        val panDocPath: String? = null,
        val uploadingAadhaar: Boolean = false,
        val uploadingCert: Boolean = false,
        val uploadingPan: Boolean = false,
        val aadhaarFailed: Boolean = false,
        val certFailed: Boolean = false,
        val panFailed: Boolean = false,
        val saving: Boolean = false,
        /** Free-text reason from admin when verification_status='rejected'. */
        val verificationNotes: String? = null,
        /**
         * Subset of {'aadhaar','pan','cert'} the admin flagged. Empty means
         * either the row isn't rejected or admin used a global rejection
         * (verificationNotes covers it). When non-empty, the screen highlights
         * only these doc rows and `startReupload` clears only their paths.
         */
        val rejectedDocTypes: List<String> = emptyList(),
        // Stepper state
        val currentStep: KycStep = KycStep.Personal,
        val email: String? = null,
        val phone: String? = null,
        val fullName: String? = null,
        val emailVerified: Boolean = false,
        val phoneVerified: Boolean = false,
        val attestationAccepted: Boolean = false,
        /** Inline email-edit draft on Step 1; synced from `email` on first load. */
        val emailDraft: String = "",
        val savingEmail: Boolean = false,
        /** True when the inline email-OTP verify sheet is showing. */
        val emailVerifySheetOpen: Boolean = false,
        val emailOtpCode: String = "",
        val sendingEmailOtp: Boolean = false,
        val verifyingEmailOtp: Boolean = false,
    ) {
        /**
         * Returns null when the current step's required fields are filled in
         * correctly, else a one-line message safe to render in the step body.
         * Verified engineers (status=verified) skip validation — they're just
         * viewing their submission.
         */
        fun stepError(): String? {
            if (verificationStatus == VerificationStatus.Verified) return null
            return when (currentStep) {
                KycStep.Personal -> {
                    when {
                        fullName.isNullOrBlank() -> "Add your name from Profile settings before continuing."
                        email.isNullOrBlank() -> "Email missing — add it before continuing."
                        !EMAIL_REGEX.matches(email) -> "That email doesn't look right."
                        !emailVerified -> "Verify your email — tap the Verify button."
                        phone.isNullOrBlank() -> "Add your phone number to continue."
                        !phoneVerified -> "Verify your phone — tap the Verify button."
                        serviceAddress.length < 8 -> "Add the area you serve."
                        serviceLatitude == null || serviceLongitude == null ->
                            "Pin your service location on the map."
                        else -> null
                    }
                }
                KycStep.Documents -> {
                    when {
                        aadhaarNumber.length != 12 -> "Aadhaar must be 12 digits."
                        !AadhaarValidator.isValid(aadhaarNumber) -> "That doesn't look like a valid Aadhaar number."
                        aadhaarDocPath.isNullOrBlank() -> "Upload your Aadhaar (PDF or photo) before continuing."
                        panNumber.length != 10 -> "PAN must be 10 characters (5 letters, 4 digits, 1 letter)."
                        !PanValidator.isValid(panNumber) -> "That doesn't look like a valid PAN."
                        panDocPath.isNullOrBlank() -> "Upload a photo of your PAN card."
                        certDocPaths.isEmpty() -> "Upload at least one trade or qualification certificate."
                        !attestationAccepted -> "You must confirm the attestation to submit."
                        else -> null
                    }
                }
            }
        }

        val canAdvance: Boolean
            get() = stepError() == null &&
                !uploadingAadhaar && !uploadingCert && !uploadingPan

        /**
         * True once every required KYC document has been uploaded to storage —
         * the actual signal the engineer's submission is in-flight to a
         * reviewer. The previous `aadhaarVerified` proxy was misleading
         * because Aadhaar can verify before PAN/cert exist, leaving the
         * timeline + banner claiming "submitted" while the row was still
         * mid-edit. Used by the timeline header, the status banner, and any
         * cross-surface chip that needs a single source of truth.
         */
        val kycSubmitted: Boolean
            get() = !aadhaarDocPath.isNullOrBlank() &&
                !panDocPath.isNullOrBlank() &&
                certDocPaths.isNotEmpty()
    }

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    private var userId: String? = null

    init {
        viewModelScope.launch { load() }
    }

    fun retry() {
        viewModelScope.launch { load() }
    }

    private suspend fun load() {
        _state.update { it.copy(loading = true, errorMessage = null) }
        val session = authRepository.sessionState
            .filterIsInstance<AuthSession.SignedIn>()
            .firstOrNull()
        val uid = session?.userId
        if (uid.isNullOrBlank()) {
            _state.update { it.copy(loading = false, errorMessage = "Please sign in to manage verification") }
            return
        }
        userId = uid
        // Fetch profile for email + phone + full name. KYC submit blocks if
        // either contact field is missing — hospitals reach out via these.
        val profile = profileRepository.fetchById(uid).getOrNull()
        engineerRepository.fetchByUserId(uid).fold(
            onSuccess = { engineer ->
                hydrate(engineer)
                _state.update {
                    it.copy(
                        email = profile?.email,
                        phone = profile?.phone,
                        fullName = profile?.fullName,
                        emailVerified = profile?.emailVerified == true,
                        phoneVerified = profile?.phoneVerified == true,
                        emailDraft = profile?.email.orEmpty(),
                    )
                }
            },
            onFailure = { ex ->
                _state.update { it.copy(loading = false, errorMessage = ex.toUserMessage()) }
            },
        )
    }

    fun goToNextStep() {
        val snap = _state.value
        if (!snap.canAdvance) {
            viewModelScope.launch {
                snap.stepError()?.let { _effects.send(Effect.ShowMessage(it)) }
            }
            return
        }
        val next = snap.currentStep.next() ?: return
        _state.update { it.copy(currentStep = next) }
    }

    fun goToPreviousStep() {
        val prev = _state.value.currentStep.previous() ?: return
        _state.update { it.copy(currentStep = prev) }
    }

    fun jumpToStep(step: KycStep) {
        _state.update { it.copy(currentStep = step) }
    }

    fun onAttestationChange(value: Boolean) {
        _state.update { it.copy(attestationAccepted = value) }
    }

    /**
     * Trigger an email-verify code send + open the inline OTP sheet. Bound to
     * the "Verify" button on the Personal step. No-op if email is missing or
     * already verified.
     */
    fun startEmailVerification() {
        val snap = _state.value
        val email = snap.email
        if (email.isNullOrBlank() || !EMAIL_REGEX.matches(email)) {
            viewModelScope.launch {
                _effects.send(Effect.ShowMessage("Add a valid email first."))
            }
            return
        }
        if (snap.emailVerified) return
        _state.update {
            it.copy(emailVerifySheetOpen = true, emailOtpCode = "", sendingEmailOtp = true)
        }
        viewModelScope.launch {
            authRepository.sendEmailOtp(email)
                .onSuccess {
                    _state.update { it.copy(sendingEmailOtp = false) }
                    _effects.send(Effect.ShowMessage("Code sent to $email"))
                }
                .onFailure { err ->
                    _state.update { it.copy(sendingEmailOtp = false, emailVerifySheetOpen = false) }
                    _effects.send(Effect.ShowMessage(err.toUserMessage()))
                }
        }
    }

    fun onEmailOtpChange(code: String) {
        val cleaned = code.filter { it.isDigit() }.take(6)
        _state.update { it.copy(emailOtpCode = cleaned) }
    }

    fun closeEmailVerifySheet() {
        if (_state.value.verifyingEmailOtp) return
        _state.update { it.copy(emailVerifySheetOpen = false, emailOtpCode = "") }
    }

    fun submitEmailOtp() {
        val snap = _state.value
        val email = snap.email ?: return
        if (snap.emailOtpCode.length != 6) {
            viewModelScope.launch {
                _effects.send(Effect.ShowMessage("Enter the 6-digit code."))
            }
            return
        }
        _state.update { it.copy(verifyingEmailOtp = true) }
        viewModelScope.launch {
            authRepository.verifyEmailOtp(email, snap.emailOtpCode)
                .onSuccess {
                    // Auth trigger flips profile.email_verified server-side;
                    // reload the profile so UiState.emailVerified flips too.
                    val uid = userId
                    val refreshed = uid?.let { profileRepository.fetchById(it).getOrNull() }
                    _state.update {
                        it.copy(
                            verifyingEmailOtp = false,
                            emailVerifySheetOpen = false,
                            emailOtpCode = "",
                            emailVerified = refreshed?.emailVerified == true,
                        )
                    }
                    _effects.send(Effect.ShowMessage("Email verified"))
                }
                .onFailure { err ->
                    _state.update { it.copy(verifyingEmailOtp = false) }
                    _effects.send(Effect.ShowMessage(err.toUserMessage()))
                }
        }
    }

    fun onEmailDraftChange(value: String) {
        _state.update { it.copy(emailDraft = value.trim(), errorMessage = null) }
    }

    /**
     * Push the inline email edit through Supabase auth. Server fires a
     * confirmation link to the new address — actual `profiles.email` flips
     * once the user clicks. We surface that expectation in the toast.
     */
    fun saveEmailDraft() {
        val snap = _state.value
        if (snap.savingEmail) return
        val newEmail = snap.emailDraft.trim()
        if (newEmail.isEmpty() || !EMAIL_REGEX.matches(newEmail)) {
            viewModelScope.launch { _effects.send(Effect.ShowMessage("That doesn't look like a valid email")) }
            return
        }
        if (newEmail.equals(snap.email, ignoreCase = true)) {
            viewModelScope.launch { _effects.send(Effect.ShowMessage("That's already your email")) }
            return
        }
        _state.update { it.copy(savingEmail = true) }
        viewModelScope.launch {
            authRepository.updateEmail(newEmail)
                .onSuccess {
                    _state.update { it.copy(savingEmail = false) }
                    _effects.send(Effect.ShowMessage("Confirmation link sent to $newEmail"))
                }
                .onFailure { err ->
                    _state.update { it.copy(savingEmail = false) }
                    _effects.send(Effect.ShowMessage(err.toUserMessage()))
                }
        }
    }

    private fun hydrate(engineer: Engineer?) {
        _state.update {
            if (engineer == null) {
                it.copy(loading = false)
            } else {
                it.copy(
                    loading = false,
                    verificationStatus = engineer.verificationStatus,
                    verificationNotes = engineer.verificationNotes,
                    rejectedDocTypes = engineer.rejectedDocTypes,
                    aadhaarVerified = engineer.aadhaarVerified,
                    aadhaarNumber = engineer.aadhaarNumber.orEmpty(),
                    serviceAddress = engineer.city.orEmpty(),
                    serviceLatitude = engineer.latitude,
                    serviceLongitude = engineer.longitude,
                    experienceYears = engineer.experienceYears.toString(),
                    serviceRadiusKm = engineer.serviceRadiusKm.toString(),
                    qualifications = engineer.qualifications,
                    selectedSpecializations = engineer.specializations.toSet(),
                    aadhaarDocPath = engineer.aadhaarDocPath,
                    certDocPaths = engineer.certDocPaths,
                    panDocPath = engineer.panDocPath,
                    panNumber = engineer.panNumber.orEmpty(),
                )
            }
        }
    }

    fun onAadhaarNumberChange(value: String) {
        val digits = value.filter { it.isDigit() }.take(12)
        _state.update { it.copy(aadhaarNumber = digits) }
    }

    fun onPanNumberChange(value: String) {
        // PAN is 10 chars, A-Z + 0-9. Force uppercase + drop everything else.
        val cleaned = value.uppercase().filter { it.isLetterOrDigit() }.take(10)
        _state.update { it.copy(panNumber = cleaned) }
    }

    fun onServiceAddressChange(value: String) =
        _state.update { it.copy(serviceAddress = value) }

    fun onServiceCoordsChange(latitude: Double?, longitude: Double?) =
        _state.update { it.copy(serviceLatitude = latitude, serviceLongitude = longitude) }

    fun onExperienceYearsChange(value: String) {
        val digits = value.filter { it.isDigit() }.take(2)
        _state.update { it.copy(experienceYears = digits) }
    }

    fun onServiceRadiusChange(value: String) {
        val digits = value.filter { it.isDigit() }.take(4)
        _state.update { it.copy(serviceRadiusKm = digits) }
    }

    fun onQualificationDraftChange(value: String) =
        _state.update { it.copy(qualificationDraft = value) }

    fun addQualification() {
        val draft = _state.value.qualificationDraft.trim()
        if (draft.isEmpty()) return
        _state.update {
            val deduped = (it.qualifications + draft).distinct()
            it.copy(qualifications = deduped, qualificationDraft = "")
        }
    }

    fun removeQualification(value: String) {
        _state.update { it.copy(qualifications = it.qualifications.filterNot { q -> q == value }) }
    }

    fun toggleSpecialization(category: RepairEquipmentCategory) {
        _state.update {
            val next = it.selectedSpecializations.toMutableSet()
            if (!next.add(category)) next.remove(category)
            it.copy(selectedSpecializations = next)
        }
    }

    /**
     * Clears the locally-tracked KYC doc paths so the rejected engineer is forced to
     * re-pick fresh files before Submit is enabled. The old rows on the engineer
     * record are overwritten on the next successful save (upsert replaces the
     * `certificates` array entirely).
     */
    fun startReupload() {
        _state.update { snap ->
            // If admin flagged specific doc types, only those get cleared so
            // the engineer doesn't re-upload approved docs unnecessarily.
            // Empty list (legacy or global-reason rejections) falls back to
            // the old "clear everything" behaviour.
            if (snap.rejectedDocTypes.isEmpty()) {
                snap.copy(
                    aadhaarDocPath = null,
                    certDocPaths = emptyList(),
                    panDocPath = null,
                )
            } else {
                val flagged = snap.rejectedDocTypes.toSet()
                snap.copy(
                    aadhaarDocPath = if (EngineerCertificate.TYPE_AADHAAR in flagged) null else snap.aadhaarDocPath,
                    panDocPath = if (EngineerCertificate.TYPE_PAN in flagged) null else snap.panDocPath,
                    certDocPaths = if (EngineerCertificate.TYPE_CERT in flagged) emptyList() else snap.certDocPaths,
                )
            }
        }
        viewModelScope.launch {
            val flagged = _state.value.rejectedDocTypes
            val message = if (flagged.isEmpty()) {
                "Please re-upload your documents"
            } else {
                "Please re-upload: ${flagged.joinToString { docTypeLabel(it) }}"
            }
            _effects.send(Effect.ShowMessage(message))
        }
    }

    private fun docTypeLabel(type: String): String = when (type) {
        EngineerCertificate.TYPE_AADHAAR -> "Aadhaar"
        EngineerCertificate.TYPE_PAN -> "PAN"
        EngineerCertificate.TYPE_CERT -> "certificate"
        else -> type
    }

    fun uploadAadhaarDoc(fileName: String, bytes: ByteArray, contentType: String?) {
        val uid = userId ?: return
        if (_state.value.uploadingAadhaar) return
        _state.update { it.copy(uploadingAadhaar = true, aadhaarFailed = false) }
        viewModelScope.launch {
            val stored = "aadhaar-${timestampedName(fileName)}"
            engineerRepository.uploadKycDoc(
                userId = uid,
                fileName = stored,
                bytes = bytes,
                contentType = contentType,
            ).fold(
                onSuccess = { path ->
                    _state.update { it.copy(uploadingAadhaar = false, aadhaarDocPath = path, aadhaarFailed = false) }
                    _effects.send(Effect.ShowMessage("Aadhaar document uploaded"))
                },
                onFailure = { ex ->
                    // Weak-network fallback: stash bytes + enqueue so the worker re-uploads
                    // the doc when we're back online. UI optimistically pins the path the
                    // drain will land on (StorageRepository uses "$uid/$fileName").
                    val queued = tryQueuePhotoUpload(
                        uid = uid,
                        bytes = bytes,
                        storedFileName = stored,
                        contentType = contentType,
                    )
                    if (queued != null) {
                        _state.update { it.copy(uploadingAadhaar = false, aadhaarDocPath = queued, aadhaarFailed = false) }
                        _effects.send(Effect.ShowMessage("Aadhaar will upload when back online"))
                    } else {
                        _state.update { it.copy(uploadingAadhaar = false, aadhaarFailed = true) }
                        _effects.send(Effect.ShowMessage(ex.toUserMessage()))
                    }
                },
            )
        }
    }

    fun uploadCertificate(fileName: String, bytes: ByteArray, contentType: String?) {
        val uid = userId ?: return
        if (_state.value.uploadingCert) return
        _state.update { it.copy(uploadingCert = true, certFailed = false) }
        viewModelScope.launch {
            val stored = "cert-${timestampedName(fileName)}"
            engineerRepository.uploadKycDoc(
                userId = uid,
                fileName = stored,
                bytes = bytes,
                contentType = contentType,
            ).fold(
                onSuccess = { path ->
                    _state.update {
                        it.copy(
                            uploadingCert = false,
                            certDocPaths = it.certDocPaths + path,
                            certFailed = false,
                        )
                    }
                    _effects.send(Effect.ShowMessage("Certificate uploaded"))
                },
                onFailure = { ex ->
                    val queued = tryQueuePhotoUpload(
                        uid = uid,
                        bytes = bytes,
                        storedFileName = stored,
                        contentType = contentType,
                    )
                    if (queued != null) {
                        _state.update {
                            it.copy(
                                uploadingCert = false,
                                certDocPaths = it.certDocPaths + queued,
                                certFailed = false,
                            )
                        }
                        _effects.send(Effect.ShowMessage("Certificate will upload when back online"))
                    } else {
                        _state.update { it.copy(uploadingCert = false, certFailed = true) }
                        _effects.send(Effect.ShowMessage(ex.toUserMessage()))
                    }
                },
            )
        }
    }

    fun uploadPan(fileName: String, bytes: ByteArray, contentType: String?) {
        val uid = userId ?: return
        if (_state.value.uploadingPan) return
        _state.update { it.copy(uploadingPan = true, panFailed = false) }
        viewModelScope.launch {
            val stored = "pan-${timestampedName(fileName)}"
            engineerRepository.uploadKycDoc(
                userId = uid,
                fileName = stored,
                bytes = bytes,
                contentType = contentType,
            ).fold(
                onSuccess = { path ->
                    _state.update {
                        it.copy(uploadingPan = false, panDocPath = path, panFailed = false)
                    }
                    _effects.send(Effect.ShowMessage("PAN uploaded"))
                },
                onFailure = { ex ->
                    val queued = tryQueuePhotoUpload(
                        uid = uid,
                        bytes = bytes,
                        storedFileName = stored,
                        contentType = contentType,
                    )
                    if (queued != null) {
                        _state.update {
                            it.copy(uploadingPan = false, panDocPath = queued, panFailed = false)
                        }
                        _effects.send(Effect.ShowMessage("PAN will upload when back online"))
                    } else {
                        _state.update { it.copy(uploadingPan = false, panFailed = true) }
                        _effects.send(Effect.ShowMessage(ex.toUserMessage()))
                    }
                },
            )
        }
    }

    /**
     * Stashes [bytes] on disk and enqueues a [PhotoUploadPayload] for the
     * outbox worker. Returns the target object path on success so the UI can
     * pin it into state; returns `null` if we couldn't even enqueue (bad MIME,
     * oversized, missing user id, disk write failure). In that last case the
     * caller surfaces the original upload error instead.
     */
    private suspend fun tryQueuePhotoUpload(
        uid: String,
        bytes: ByteArray,
        storedFileName: String,
        contentType: String?,
    ): String? {
        val mime = contentType?.substringBefore(';')?.trim() ?: return null
        val objectPath = "$uid/$storedFileName"
        return runCatching {
            photoUploadStash.enqueue(
                bucket = StorageRepository.Buckets.KYC_DOCS,
                objectPath = objectPath,
                bytes = bytes,
                mimeType = mime,
                contextType = PhotoUploadPayload.CONTEXT_KYC_DOC,
                contextId = uid,
                uploaderUserId = uid,
            )
            objectPath
        }.getOrNull()
    }

    fun save() {
        val uid = userId ?: return
        val snap = _state.value
        if (snap.saving) return
        val aadhaarDigits = snap.aadhaarNumber
        if (aadhaarDigits.isNotEmpty() && aadhaarDigits.length != 12) {
            viewModelScope.launch {
                _effects.send(Effect.ShowMessage("Aadhaar must be 12 digits"))
            }
            return
        }
        if (snap.selectedSpecializations.isEmpty()) {
            viewModelScope.launch {
                _effects.send(Effect.ShowMessage("Pick at least one specialization"))
            }
            return
        }
        _state.update { it.copy(saving = true) }
        viewModelScope.launch {
            // Play Integrity gate before persisting KYC. Debug fails open so
            // devs without Play setup can still iterate; release blocks with
            // PlayIntegrityClient.FAILURE_MESSAGE and leaves the row untouched.
            val integrity = playIntegrityClient.requestVerification("kyc_submit")
            // Debug builds bypass: side-loaded APKs always fail Play Integrity
            // because the cert chain isn't recognised by Google. Production
            // keeps the strict gate via BuildConfig.DEBUG check below.
            val pass = integrity.getOrDefault(false) || com.equipseva.app.BuildConfig.DEBUG
            if (!pass) {
                _state.update { it.copy(saving = false) }
                _effects.send(Effect.ShowMessage(PlayIntegrityClient.FAILURE_MESSAGE))
                return@launch
            }
            val now = Clock.System.now().toString()
            val certificates = buildList {
                snap.aadhaarDocPath?.let {
                    add(EngineerCertificate(EngineerCertificate.TYPE_AADHAAR, it, now))
                }
                snap.panDocPath?.let {
                    add(EngineerCertificate(EngineerCertificate.TYPE_PAN, it, now))
                }
                snap.certDocPaths.forEach {
                    add(EngineerCertificate(EngineerCertificate.TYPE_CERT, it, now))
                }
            }
            engineerRepository.upsert(
                userId = uid,
                aadhaarNumber = aadhaarDigits.takeIf { it.isNotEmpty() },
                panNumber = snap.panNumber.takeIf { it.isNotEmpty() && PanValidator.isValid(it) },
                qualifications = snap.qualifications,
                specializations = snap.selectedSpecializations.toList(),
                experienceYears = snap.experienceYears.toIntOrNull() ?: 0,
                serviceRadiusKm = snap.serviceRadiusKm.toIntOrNull() ?: 25,
                city = snap.serviceAddress.takeIf { it.isNotBlank() },
                state = null,
                latitude = snap.serviceLatitude,
                longitude = snap.serviceLongitude,
                certificates = certificates,
                aadhaarUploaded = snap.aadhaarDocPath != null,
                // Re-submitting after rejection must flip the row back into the
                // review queue so the admin sees it again.
                resetVerificationToPending =
                    snap.verificationStatus == VerificationStatus.Rejected,
            ).fold(
                onSuccess = { engineer ->
                    hydrate(engineer)
                    _state.update { it.copy(saving = false) }
                    _effects.send(Effect.ShowMessage("Verification details saved"))
                },
                onFailure = { ex ->
                    _state.update { it.copy(saving = false) }
                    _effects.send(Effect.ShowMessage(ex.toUserMessage()))
                },
            )
        }
    }

    private fun timestampedName(original: String): String {
        val sanitized = original.substringAfterLast('/').ifBlank { "file" }
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
        val stamp = System.currentTimeMillis()
        return "$stamp-$sanitized"
    }

}

// Anchored — covers the 99% case for engineer signups without trying to be
// RFC 5322. Hospitals only need a working address.
private val EMAIL_REGEX = Regex(
    "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\$",
)
