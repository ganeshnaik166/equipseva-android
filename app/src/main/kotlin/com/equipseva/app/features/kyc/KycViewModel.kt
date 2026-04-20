package com.equipseva.app.features.kyc

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.engineers.Engineer
import com.equipseva.app.core.data.engineers.EngineerCertificate
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.network.toUserMessage
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
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val errorMessage: String? = null,
        val verificationStatus: VerificationStatus = VerificationStatus.Pending,
        val aadhaarVerified: Boolean = false,
        val aadhaarNumber: String = "",
        val city: String = "",
        val state: String = "",
        val experienceYears: String = "",
        val serviceRadiusKm: String = "25",
        val qualificationDraft: String = "",
        val qualifications: List<String> = emptyList(),
        val selectedSpecializations: Set<RepairEquipmentCategory> = emptySet(),
        val aadhaarDocPath: String? = null,
        val certDocPaths: List<String> = emptyList(),
        val uploadingAadhaar: Boolean = false,
        val uploadingCert: Boolean = false,
        val saving: Boolean = false,
    )

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
        engineerRepository.fetchByUserId(uid).fold(
            onSuccess = { engineer -> hydrate(engineer) },
            onFailure = { ex ->
                _state.update { it.copy(loading = false, errorMessage = ex.toUserMessage()) }
            },
        )
    }

    private fun hydrate(engineer: Engineer?) {
        _state.update {
            if (engineer == null) {
                it.copy(loading = false)
            } else {
                it.copy(
                    loading = false,
                    verificationStatus = engineer.verificationStatus,
                    aadhaarVerified = engineer.aadhaarVerified,
                    aadhaarNumber = engineer.aadhaarNumber.orEmpty(),
                    city = engineer.city.orEmpty(),
                    state = engineer.state.orEmpty(),
                    experienceYears = engineer.experienceYears.toString(),
                    serviceRadiusKm = engineer.serviceRadiusKm.toString(),
                    qualifications = engineer.qualifications,
                    selectedSpecializations = engineer.specializations.toSet(),
                    aadhaarDocPath = engineer.aadhaarDocPath,
                    certDocPaths = engineer.certDocPaths,
                )
            }
        }
    }

    fun onAadhaarNumberChange(value: String) {
        val digits = value.filter { it.isDigit() }.take(12)
        _state.update { it.copy(aadhaarNumber = digits) }
    }

    fun onCityChange(value: String) = _state.update { it.copy(city = value) }
    fun onStateChange(value: String) = _state.update { it.copy(state = value) }

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

    fun uploadAadhaarDoc(fileName: String, bytes: ByteArray, contentType: String?) {
        val uid = userId ?: return
        if (_state.value.uploadingAadhaar) return
        _state.update { it.copy(uploadingAadhaar = true) }
        viewModelScope.launch {
            engineerRepository.uploadKycDoc(
                userId = uid,
                fileName = "aadhaar-${timestampedName(fileName)}",
                bytes = bytes,
                contentType = contentType,
            ).fold(
                onSuccess = { path ->
                    _state.update { it.copy(uploadingAadhaar = false, aadhaarDocPath = path) }
                    _effects.send(Effect.ShowMessage("Aadhaar document uploaded"))
                },
                onFailure = { ex ->
                    _state.update { it.copy(uploadingAadhaar = false) }
                    _effects.send(Effect.ShowMessage(ex.toUserMessage()))
                },
            )
        }
    }

    fun uploadCertificate(fileName: String, bytes: ByteArray, contentType: String?) {
        val uid = userId ?: return
        if (_state.value.uploadingCert) return
        _state.update { it.copy(uploadingCert = true) }
        viewModelScope.launch {
            engineerRepository.uploadKycDoc(
                userId = uid,
                fileName = "cert-${timestampedName(fileName)}",
                bytes = bytes,
                contentType = contentType,
            ).fold(
                onSuccess = { path ->
                    _state.update {
                        it.copy(
                            uploadingCert = false,
                            certDocPaths = it.certDocPaths + path,
                        )
                    }
                    _effects.send(Effect.ShowMessage("Certificate uploaded"))
                },
                onFailure = { ex ->
                    _state.update { it.copy(uploadingCert = false) }
                    _effects.send(Effect.ShowMessage(ex.toUserMessage()))
                },
            )
        }
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
            val now = Clock.System.now().toString()
            val certificates = buildList {
                snap.aadhaarDocPath?.let {
                    add(EngineerCertificate(EngineerCertificate.TYPE_AADHAAR, it, now))
                }
                snap.certDocPaths.forEach {
                    add(EngineerCertificate(EngineerCertificate.TYPE_CERT, it, now))
                }
            }
            engineerRepository.upsert(
                userId = uid,
                aadhaarNumber = aadhaarDigits.takeIf { it.isNotEmpty() },
                qualifications = snap.qualifications,
                specializations = snap.selectedSpecializations.toList(),
                experienceYears = snap.experienceYears.toIntOrNull() ?: 0,
                serviceRadiusKm = snap.serviceRadiusKm.toIntOrNull() ?: 25,
                city = snap.city.takeIf { it.isNotBlank() },
                state = snap.state.takeIf { it.isNotBlank() },
                certificates = certificates,
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
