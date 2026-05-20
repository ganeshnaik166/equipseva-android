package com.equipseva.app.features.hospital

import androidx.lifecycle.SavedStateHandle
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
import com.equipseva.app.core.util.timestampedName
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId
import javax.inject.Inject

@HiltViewModel
class RequestServiceViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val jobRepository: RepairJobRepository,
    private val storageRepository: StorageRepository,
    private val savedStateHandle: SavedStateHandle,
) : ViewModel() {

    // Round 453 — process-death-safe draft state. Hospital booking is a
    // 4-step wizard, often filled out over several minutes (issue field
    // can be 2k chars). Without this the user goes to another app to
    // copy-paste a serial number, the OS kills our process in the
    // background, and they return to a blank form with everything lost.
    private object SavedKeys {
        const val CATEGORY = "req.category"
        const val URGENCY = "req.urgency"
        const val BRAND = "req.brand"
        const val MODEL = "req.model"
        const val SERIAL = "req.serial"
        const val SITE_ADDRESS = "req.siteAddress"
        const val SITE_LOCATION = "req.siteLocation"
        const val PICKED_DATE = "req.pickedDate"
        const val SITE_LAT = "req.siteLat"
        const val SITE_LNG = "req.siteLng"
        const val ISSUE = "req.issue"
        const val BUDGET = "req.budget"
        const val PHOTOS = "req.photos"
    }

    data class UiState(
        val category: RepairEquipmentCategory = RepairEquipmentCategory.ImagingRadiology,
        val urgency: RepairJobUrgency = RepairJobUrgency.Scheduled,
        val brand: String = "",
        val model: String = "",
        val serial: String = "",
        val siteAddress: String = "",
        val siteLocation: String = "",
        val pickedDateMillis: Long? = null,
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
        val siteAddressError: String? = null,
    )

    sealed interface Effect {
        data class Submitted(val jobId: String, val jobNumber: String?) : Effect
        data class ShowMessage(val text: String) : Effect
    }

    private val _state = MutableStateFlow(restoredInitialState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private fun restoredInitialState(): UiState {
        val category = savedStateHandle.get<String>(SavedKeys.CATEGORY)
            ?.let { name -> runCatching { RepairEquipmentCategory.valueOf(name) }.getOrNull() }
            ?: RepairEquipmentCategory.ImagingRadiology
        val urgency = savedStateHandle.get<String>(SavedKeys.URGENCY)
            ?.let { name -> runCatching { RepairJobUrgency.valueOf(name) }.getOrNull() }
            ?: RepairJobUrgency.Scheduled
        return UiState(
            category = category,
            urgency = urgency,
            brand = savedStateHandle.get<String>(SavedKeys.BRAND).orEmpty(),
            model = savedStateHandle.get<String>(SavedKeys.MODEL).orEmpty(),
            serial = savedStateHandle.get<String>(SavedKeys.SERIAL).orEmpty(),
            siteAddress = savedStateHandle.get<String>(SavedKeys.SITE_ADDRESS).orEmpty(),
            siteLocation = savedStateHandle.get<String>(SavedKeys.SITE_LOCATION).orEmpty(),
            pickedDateMillis = savedStateHandle.get<Long>(SavedKeys.PICKED_DATE),
            siteLatitude = savedStateHandle.get<Double>(SavedKeys.SITE_LAT),
            siteLongitude = savedStateHandle.get<Double>(SavedKeys.SITE_LNG),
            issue = savedStateHandle.get<String>(SavedKeys.ISSUE).orEmpty(),
            budget = savedStateHandle.get<String>(SavedKeys.BUDGET).orEmpty(),
            photos = savedStateHandle.get<Array<String>>(SavedKeys.PHOTOS)?.toList().orEmpty(),
        )
    }

    private fun clearSavedDraft() {
        savedStateHandle.remove<String>(SavedKeys.CATEGORY)
        savedStateHandle.remove<String>(SavedKeys.URGENCY)
        savedStateHandle.remove<String>(SavedKeys.BRAND)
        savedStateHandle.remove<String>(SavedKeys.MODEL)
        savedStateHandle.remove<String>(SavedKeys.SERIAL)
        savedStateHandle.remove<String>(SavedKeys.SITE_ADDRESS)
        savedStateHandle.remove<String>(SavedKeys.SITE_LOCATION)
        savedStateHandle.remove<Long>(SavedKeys.PICKED_DATE)
        savedStateHandle.remove<Double>(SavedKeys.SITE_LAT)
        savedStateHandle.remove<Double>(SavedKeys.SITE_LNG)
        savedStateHandle.remove<String>(SavedKeys.ISSUE)
        savedStateHandle.remove<String>(SavedKeys.BUDGET)
        savedStateHandle.remove<Array<String>>(SavedKeys.PHOTOS)
    }

    private val effectChannel = kotlinx.coroutines.flow.MutableSharedFlow<Effect>(extraBufferCapacity = 4)
    val effects: kotlinx.coroutines.flow.Flow<Effect> = effectChannel

    private var userId: String? = null
    private var orgId: String? = null
    // Round 324 — hospital phone gate. Submitting a booking without
    // it leaves the engineer with no way to reach the hospital
    // (chat works, but masked-calling via request-call-session
    // returns 422 missing_phone). Cache the value at sign-in so the
    // submit gate doesn't have to fetch on every tap.
    private var hospitalPhone: String? = null

    init {
        viewModelScope.launch {
            authRepository.sessionState
                .filterIsInstance<AuthSession.SignedIn>()
                .distinctUntilChangedBy { it.userId }
                .collect { session ->
                    userId = session.userId
                    val profile = profileRepository.fetchById(session.userId).getOrNull()
                    orgId = profile?.organizationId
                    hospitalPhone = profile?.phone?.takeIf { it.isNotBlank() }
                }
        }
    }

    fun onCategoryChange(value: RepairEquipmentCategory) {
        savedStateHandle[SavedKeys.CATEGORY] = value.name
        _state.update { it.copy(category = value) }
    }
    fun onUrgencyChange(value: RepairJobUrgency) {
        savedStateHandle[SavedKeys.URGENCY] = value.name
        _state.update { it.copy(urgency = value) }
    }
    fun onBrandChange(value: String) {
        val capped = value.take(100)
        savedStateHandle[SavedKeys.BRAND] = capped
        _state.update { it.copy(brand = capped) }
    }
    fun onModelChange(value: String) {
        val capped = value.take(100)
        savedStateHandle[SavedKeys.MODEL] = capped
        _state.update { it.copy(model = capped) }
    }
    fun onSerialChange(value: String) {
        val capped = value.take(100)
        savedStateHandle[SavedKeys.SERIAL] = capped
        _state.update { it.copy(serial = capped) }
    }
    fun onSiteAddressChange(value: String) {
        val capped = value.take(500)
        savedStateHandle[SavedKeys.SITE_ADDRESS] = capped
        _state.update {
            it.copy(siteAddress = capped, siteAddressError = null, errorMessage = null)
        }
    }
    fun onSiteLocationChange(value: String) {
        val capped = value.take(500)
        savedStateHandle[SavedKeys.SITE_LOCATION] = capped
        _state.update { it.copy(siteLocation = capped) }
    }
    fun onPickedDateChange(value: Long?) {
        savedStateHandle[SavedKeys.PICKED_DATE] = value
        _state.update { it.copy(pickedDateMillis = value) }
    }

    /**
     * Picked from the LocationPickerMap composable. Pair of nullable doubles
     * so the map can clear the pin (passing null/null) — though today the
     * picker only emits non-null pairs.
     */
    fun onSiteCoordsChange(latitude: Double?, longitude: Double?) {
        // Reject obviously bad coordinates. A garbled callback or a future
        // hostile callsite could pass (1000, 1000) and the engineer-side
        // distance filter would silently treat the job as unreachable.
        // WGS84 ranges; NaN guard for the IEEE-754 edge.
        val latOk = latitude == null ||
            (latitude in -90.0..90.0 && !latitude.isNaN())
        val lngOk = longitude == null ||
            (longitude in -180.0..180.0 && !longitude.isNaN())
        if (!latOk || !lngOk) {
            savedStateHandle.remove<Double>(SavedKeys.SITE_LAT)
            savedStateHandle.remove<Double>(SavedKeys.SITE_LNG)
            _state.update { it.copy(siteLatitude = null, siteLongitude = null) }
            return
        }
        savedStateHandle[SavedKeys.SITE_LAT] = latitude
        savedStateHandle[SavedKeys.SITE_LNG] = longitude
        _state.update { it.copy(siteLatitude = latitude, siteLongitude = longitude) }
    }
    fun onIssueChange(value: String) {
        // Issue is the long-form bug description; 2000 char cap covers
        // the longest realistic case while preventing a 10 KB paste
        // from wedging the form submit.
        val capped = value.take(2000)
        savedStateHandle[SavedKeys.ISSUE] = capped
        _state.update {
            it.copy(issue = capped, issueError = null, errorMessage = null)
        }
    }
    fun onBudgetChange(value: String) {
        // Budget is a numeric amount typed as text (parsed later via
        // toDoubleOrNull). Cap at 12 chars — enough for "9999999999.99"
        // (10-digit rupees + 2 decimals); blocks abuse paste.
        val capped = value.take(12)
        savedStateHandle[SavedKeys.BUDGET] = capped
        _state.update {
            it.copy(budget = capped, budgetError = null, errorMessage = null)
        }
    }

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
                effectChannel.emit(Effect.ShowMessage("Sign in again and retry"))
            }
            return
        }
        if (_state.value.uploadingPhoto) return
        _state.update { it.copy(uploadingPhoto = true) }
        val stored = "issue-${timestampedName(fileName, fallback = "photo.jpg")}"
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
                        val nextPhotos = it.photos + path
                        savedStateHandle[SavedKeys.PHOTOS] = nextPhotos.toTypedArray()
                        it.copy(
                            uploadingPhoto = false,
                            photos = nextPhotos,
                        )
                    }
                },
                onFailure = { ex ->
                    _state.update { it.copy(uploadingPhoto = false) }
                    effectChannel.emit(Effect.ShowMessage(ex.toUserMessage()))
                },
            )
        }
    }

    fun onRemovePhoto(path: String) {
        _state.update {
            val nextPhotos = it.photos - path
            savedStateHandle[SavedKeys.PHOTOS] = nextPhotos.toTypedArray()
            it.copy(photos = nextPhotos)
        }
    }

    fun onSubmit(selectedSlot: Int = -1) {
        val uid = userId
        if (uid == null) {
            _state.update { it.copy(errorMessage = "Sign in again and retry.") }
            return
        }
        // Round 324 — gate on hospital phone. Without it, the engineer
        // accepts the bid and tries to call but request-call-session
        // returns 422 missing_phone. The error is more recoverable at
        // booking time (hospital → AddPhone) than at call time
        // (engineer can't unblock themselves). Mirror the existing
        // "Pick a time slot" / "Issue too short" gate UX.
        if (hospitalPhone.isNullOrBlank()) {
            val msg = "Add your phone number on Profile → Phone number before posting a job — engineers need it to coordinate the visit."
            _state.update { it.copy(errorMessage = msg) }
            effectChannel.tryEmit(Effect.ShowMessage(msg))
            return
        }
        // Block submit when no slot is picked. Earlier code happily wrote
        // a job with scheduledDate=null + scheduledTimeSlot=null, which
        // engineers couldn't filter on and hospital later couldn't tell
        // why the bid feed was quiet.
        if (selectedSlot < 0) {
            _state.update { it.copy(errorMessage = "Pick when the engineer should come.") }
            return
        }
        val current = _state.value
        val issue = current.issue.trim()
        if (issue.length < 10) {
            // Issue lives on step 1, but Submit is on step 4 — without
            // surfacing the message at top-level the user just sees the
            // button do nothing. Mirror it into errorMessage (the banner
            // is rendered above every step) and emit a snackbar so the
            // failure is unmissable.
            val msg = "Please describe the issue (10 characters or more) on the Issue step."
            _state.update {
                it.copy(
                    issueError = "Please describe the issue (10 characters or more).",
                    errorMessage = msg,
                )
            }
            effectChannel.tryEmit(Effect.ShowMessage(msg))
            return
        }
        // Require a non-trivial site address OR map coordinates. Without
        // one, the engineer has no way to reach the hospital and the
        // job lands in their feed as an unactionable row. Map pin alone
        // isn't a substitute — engineers need a typed address for the
        // navigation app handoff. 5-char floor blocks accidental "a"
        // submits without enforcing a specific format.
        val address = current.siteAddress.trim()
        if (address.length < 5) {
            val msg = "Add the service address (5 characters or more) on the Where step."
            _state.update {
                it.copy(
                    siteAddressError = "Address is required so engineers can reach you.",
                    errorMessage = msg,
                )
            }
            effectChannel.tryEmit(Effect.ShowMessage(msg))
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
        // Booking scheduled_date is anchored to the hospital's local
        // time (IST); a device on UTC would otherwise compute "today"
        // 5.5h behind and submit a date the hospital wouldn't recognise.
        val today = LocalDate.now(ZoneId.of("Asia/Kolkata"))
        val (scheduledDate, scheduledTimeSlot) = when (selectedSlot) {
            0 -> today.toString() to "evening"
            1 -> today.plusDays(1).toString() to "morning"
            2 -> today.plusDays(1).toString() to "afternoon"
            // "Flexible" tile — the user picked it intentionally, so record
            // the preference rather than collapsing to no-selection. Date
            // stays null since they did not commit to a specific day.
            3 -> null to "flexible"
            4 -> {
                // Custom date from the calendar tile. Persist the picked date
                // with a generic "any" slot since the user did not narrow to a
                // morning / afternoon / evening window.
                val millis = current.pickedDateMillis
                if (millis != null) {
                    // Pin to IST so the date the hospital sees in the
                    // picker matches the date persisted server-side,
                    // independent of device time zone (round 237).
                    val picked = java.time.Instant.ofEpochMilli(millis)
                        .atZone(java.time.ZoneId.of("Asia/Kolkata")).toLocalDate()
                    picked.toString() to "any"
                } else {
                    null to null
                }
            }
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
                siteLocation = listOfNotNull(
                    current.siteAddress.trim().ifBlank { null }?.let { "Address: $it" },
                    current.siteLocation.trim().ifBlank { null }?.let { "Notes: $it" },
                ).joinToString("\n").ifBlank { null },
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
                    clearSavedDraft()
                    _state.update { UiState() }
                    effectChannel.tryEmit(Effect.Submitted(jobId = job.id, jobNumber = job.jobNumber))
                }
                .onFailure { error ->
                    _state.update { it.copy(submitting = false, errorMessage = error.toUserMessage()) }
                }
        }
    }

}
