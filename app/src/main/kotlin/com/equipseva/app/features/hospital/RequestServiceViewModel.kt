package com.equipseva.app.features.hospital

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJobDraft
import com.equipseva.app.core.data.repair.RepairJobRepository
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.storage.StorageRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import javax.inject.Inject

@HiltViewModel
class RequestServiceViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val jobRepository: RepairJobRepository,
    private val storageRepository: StorageRepository,
) : ViewModel() {

    data class UiState(
        val category: RepairEquipmentCategory = RepairEquipmentCategory.ImagingRadiology,
        val urgency: RepairJobUrgency = RepairJobUrgency.Scheduled,
        val brand: String = "",
        val model: String = "",
        val serial: String = "",
        val siteLocation: String = "",
        val siteLatitude: Double? = null,
        val siteLongitude: Double? = null,
        val issue: String = "",
        val budget: String = "",
        val budgetError: String? = null,
        val photos: List<String> = emptyList(),
        val uploadingPhoto: Boolean = false,
        val submitting: Boolean = false,
        val errorMessage: String? = null,
        val issueError: String? = null,
    )

    sealed interface Effect {
        data class Submitted(val jobId: String, val jobNumber: String?) : Effect
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val effectChannel = Channel<Effect>(Channel.BUFFERED)
    val effects = effectChannel.receiveAsFlow()

    private var userId: String? = null
    private var orgId: String? = null

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { session ->
                    userId = session.userId
                    orgId = profileRepository.fetchById(session.userId).getOrNull()?.organizationId
                }
        }
    }

    fun onCategoryChange(value: RepairEquipmentCategory) = _state.update { it.copy(category = value) }
    fun onUrgencyChange(value: RepairJobUrgency) = _state.update { it.copy(urgency = value) }
    fun onBrandChange(value: String) = _state.update { it.copy(brand = value) }
    fun onModelChange(value: String) = _state.update { it.copy(model = value) }
    fun onSerialChange(value: String) = _state.update { it.copy(serial = value) }
    fun onSiteLocationChange(value: String) = _state.update { it.copy(siteLocation = value) }

    /**
     * Picked from the LocationPickerMap composable. Pair of nullable doubles
     * so the map can clear the pin (passing null/null) — though today the
     * picker only emits non-null pairs.
     */
    fun onSiteCoordsChange(latitude: Double?, longitude: Double?) {
        _state.update { it.copy(siteLatitude = latitude, siteLongitude = longitude) }
    }
    fun onIssueChange(value: String) = _state.update { it.copy(issue = value, issueError = null) }
    fun onBudgetChange(value: String) = _state.update { it.copy(budget = value, budgetError = null) }

    /**
     * Uploads [bytes] to the `repair-photos` bucket under the signed-in user's
     * folder and pins the resulting object path into UI state. The path is
     * passed straight into the `issue_photos` array on submit; SignedUrls can
     * be derived later for display by anyone with access to the row.
     */
    fun onPhotoPicked(fileName: String, bytes: ByteArray, contentType: String?) {
        val uid = userId
        if (uid == null) {
            viewModelScope.launch {
                effectChannel.send(Effect.ShowMessage("Sign in again and retry"))
            }
            return
        }
        if (_state.value.uploadingPhoto) return
        _state.update { it.copy(uploadingPhoto = true) }
        val stored = "issue-${timestampedName(fileName)}"
        val path = "$uid/$stored"
        viewModelScope.launch {
            storageRepository.upload(
                bucket = StorageRepository.Buckets.REPAIR_PHOTOS,
                path = path,
                bytes = bytes,
                contentType = contentType,
            ).fold(
                onSuccess = {
                    _state.update {
                        it.copy(
                            uploadingPhoto = false,
                            photos = it.photos + path,
                        )
                    }
                },
                onFailure = { ex ->
                    _state.update { it.copy(uploadingPhoto = false) }
                    effectChannel.send(Effect.ShowMessage(ex.toUserMessage()))
                },
            )
        }
    }

    fun onRemovePhoto(path: String) {
        _state.update { it.copy(photos = it.photos - path) }
    }

    fun onSubmit(selectedSlot: Int = -1) {
        val uid = userId
        if (uid == null) {
            _state.update { it.copy(errorMessage = "Sign in again and retry.") }
            return
        }
        val current = _state.value
        val issue = current.issue.trim()
        if (issue.length < 10) {
            _state.update { it.copy(issueError = "Please describe the issue (10 characters or more).") }
            return
        }
        val budgetText = current.budget.trim()
        val estimatedCost: Double? = if (budgetText.isBlank()) {
            null
        } else {
            val parsed = budgetText.toDoubleOrNull()
            if (parsed == null || parsed <= 0.0) {
                _state.update { it.copy(budgetError = "Enter a valid amount.") }
                return
            }
            parsed
        }
        val today = LocalDate.now()
        val (scheduledDate, scheduledTimeSlot) = when (selectedSlot) {
            0 -> today.toString() to "evening"
            1 -> today.plusDays(1).toString() to "morning"
            2 -> today.plusDays(1).toString() to "afternoon"
            else -> null to null
        }
        _state.update { it.copy(submitting = true, errorMessage = null) }
        viewModelScope.launch {
            val draft = RepairJobDraft(
                hospitalUserId = uid,
                hospitalOrgId = orgId,
                issueDescription = issue,
                equipmentCategory = current.category,
                equipmentBrand = current.brand.trim().ifBlank { null },
                equipmentModel = current.model.trim().ifBlank { null },
                equipmentSerial = current.serial.trim().ifBlank { null },
                siteLocation = current.siteLocation.trim().ifBlank { null },
                siteLatitude = current.siteLatitude,
                siteLongitude = current.siteLongitude,
                issuePhotos = current.photos,
                urgency = current.urgency.takeIf { it != RepairJobUrgency.Unknown } ?: RepairJobUrgency.Scheduled,
                scheduledDate = scheduledDate,
                scheduledTimeSlot = scheduledTimeSlot,
                estimatedCostRupees = estimatedCost,
            )
            jobRepository.create(draft)
                .onSuccess { job ->
                    _state.update {
                        UiState()
                    }
                    effectChannel.trySend(Effect.Submitted(jobId = job.id, jobNumber = job.jobNumber))
                }
                .onFailure { error ->
                    _state.update {
                        it.copy(submitting = false, errorMessage = error.toUserMessage())
                    }
                }
        }
    }

    private fun timestampedName(original: String): String {
        val sanitized = original.substringAfterLast('/').ifBlank { "photo.jpg" }
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
        val stamp = System.currentTimeMillis()
        return "$stamp-$sanitized"
    }
}
