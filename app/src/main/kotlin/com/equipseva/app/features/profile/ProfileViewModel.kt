package com.equipseva.app.features.profile

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import kotlinx.coroutines.flow.firstOrNull
import com.equipseva.app.core.data.account.AccountDeletionRepository
import com.equipseva.app.core.data.account.DataExportRepository
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.data.prefs.ThemeMode
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.features.auth.UserRole
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val engineerRepository: EngineerRepository,
    private val userPrefs: UserPrefs,
    private val accountDeletionRepository: AccountDeletionRepository,
    private val dataExportRepository: DataExportRepository,
    @ApplicationContext private val appContext: Context,
) : ViewModel() {

    data class UiState(
        val loading: Boolean = true,
        val profile: Profile? = null,
        /** True only when the auth layer reports SignedOut (not just profile==null). */
        val isSignedOut: Boolean = false,
        /** engineers.id of the signed-in user (only when role=Engineer + KYC verified). */
        val ownEngineerId: String? = null,
        /**
         * Verification status of the signed-in engineer's KYC row, or null when
         * the user is not an engineer / has no engineer row yet. Drives the
         * Profile "Verification (KYC)" chip so it agrees with the KYC screen
         * and the Engineer Jobs hub gate instead of being hardcoded to "Review".
         */
        val engineerStatus: VerificationStatus? = null,
        /**
         * True when the engineer has uploaded all three required KYC docs
         * (Aadhaar + PAN + at least one certificate). Used together with
         * [engineerStatus] to distinguish "draft" from "in review" while the
         * backend still reports a single Pending state.
         */
        val engineerKycSubmitted: Boolean = false,
        val errorMessage: String? = null,
        val roleEditorOpen: Boolean = false,
        val roleEditorSelected: UserRole? = null,
        val roleUpdating: Boolean = false,
        val signingOut: Boolean = false,
        val editProfileOpen: Boolean = false,
        val editFullName: String = "",
        val editPhone: String = "",
        val editSaving: Boolean = false,
        val editError: String? = null,
        val deleteAccountOpen: Boolean = false,
        val deleteReason: String = "",
        val deletingAccount: Boolean = false,
        val exportingData: Boolean = false,
    )

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
        data class ShareExport(val path: String) : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = Channel<Effect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    val themeMode: StateFlow<ThemeMode> = userPrefs.themeMode.stateIn(
        viewModelScope,
        SharingStarted.Eagerly,
        ThemeMode.Light,
    )

    private val _settingsOpen = MutableStateFlow(false)
    val settingsOpen: StateFlow<Boolean> = _settingsOpen.asStateFlow()

    fun onOpenSettings() {
        _settingsOpen.value = true
    }

    fun onDismissSettings() {
        _settingsOpen.value = false
    }

    fun onThemeModeChange(mode: ThemeMode) {
        viewModelScope.launch {
            userPrefs.setThemeMode(mode)
        }
    }

    init {
        viewModelScope.launch {
            // Handle every session state, not just SignedIn — otherwise a
            // signed-out user opening the Profile tab gets stuck on the
            // initial loading=true spinner forever (the SignedOutPrompt
            // never gets a chance to render).
            authRepository.sessionState.collect { session ->
                when (session) {
                    is AuthSession.SignedIn -> {
                        _state.update { it.copy(isSignedOut = false) }
                        if (_state.value.profile?.id != session.userId) {
                            load(session.userId, initial = true)
                        }
                    }
                    AuthSession.SignedOut -> {
                        _state.update {
                            it.copy(
                                loading = false,
                                profile = null,
                                isSignedOut = true,
                                errorMessage = null,
                            )
                        }
                    }
                    AuthSession.Unknown -> Unit
                }
            }
        }
    }

    fun onRefresh() {
        val session = _state.value.profile?.id ?: return
        viewModelScope.launch {
            load(session, initial = false)
        }
    }

    /**
     * Retry profile load when the previous fetch failed (profile==null +
     * errorMessage set). Pulls the current auth.uid() out of the session
     * flow and restarts `load` from scratch — `onRefresh` can't do this
     * because it short-circuits when profile is null.
     */
    fun onRetryFromAuth() {
        viewModelScope.launch {
            val signedIn = authRepository.sessionState
                .firstOrNull { it is AuthSession.SignedIn } as? AuthSession.SignedIn
                ?: return@launch
            load(signedIn.userId, initial = true)
        }
    }

    fun onOpenRoleEditor() {
        _state.update {
            it.copy(
                roleEditorOpen = true,
                roleEditorSelected = it.profile?.role,
            )
        }
    }

    fun onDismissRoleEditor() {
        if (_state.value.roleUpdating) return
        _state.update { it.copy(roleEditorOpen = false, roleEditorSelected = null) }
    }

    fun onRoleEditorSelect(role: UserRole) {
        _state.update { it.copy(roleEditorSelected = role) }
    }

    fun onRoleEditorConfirm() {
        val current = _state.value
        val target = current.roleEditorSelected ?: return
        val userId = current.profile?.id ?: return
        if (current.roleUpdating) return
        if (target == current.profile?.role) {
            _state.update { it.copy(roleEditorOpen = false, roleEditorSelected = null) }
            return
        }
        _state.update { it.copy(roleUpdating = true) }
        viewModelScope.launch {
            profileRepository.updateRole(userId, target)
                .onSuccess {
                    userPrefs.setActiveRole(target.storageKey)
                    _state.update {
                        it.copy(
                            profile = it.profile?.copy(role = target, rawRoleKey = target.storageKey, roleConfirmed = true),
                            roleEditorOpen = false,
                            roleEditorSelected = null,
                            roleUpdating = false,
                        )
                    }
                    _effects.send(Effect.ShowMessage("Role updated to ${target.displayName}"))
                }
                .onFailure { error ->
                    _state.update { it.copy(roleUpdating = false) }
                    _effects.send(Effect.ShowMessage(error.toUserMessage()))
                }
        }
    }

    fun onOpenEditProfile() {
        val profile = _state.value.profile ?: return
        _state.update {
            it.copy(
                editProfileOpen = true,
                editFullName = profile.fullName.orEmpty(),
                editPhone = profile.phone.orEmpty(),
                editError = null,
            )
        }
    }

    fun onDismissEditProfile() {
        if (_state.value.editSaving) return
        _state.update { it.copy(editProfileOpen = false, editError = null) }
    }

    fun onEditFullNameChange(value: String) {
        _state.update { it.copy(editFullName = value, editError = null) }
    }

    fun onSaveEditProfile() {
        val current = _state.value
        if (current.editSaving) return
        val profile = current.profile ?: return
        val trimmedName = current.editFullName.trim()
        if (trimmedName.isBlank()) {
            _state.update { it.copy(editError = "Name can't be empty.") }
            return
        }
        val nextName = trimmedName
        if (nextName == profile.fullName.orEmpty()) {
            _state.update { it.copy(editProfileOpen = false) }
            return
        }
        _state.update { it.copy(editSaving = true, editError = null) }
        viewModelScope.launch {
            profileRepository.updateBasicInfo(profile.id, nextName, profile.phone)
                .onSuccess {
                    _state.update {
                        it.copy(
                            editSaving = false,
                            editProfileOpen = false,
                            profile = it.profile?.copy(fullName = nextName),
                        )
                    }
                    _effects.send(Effect.ShowMessage("Profile updated"))
                }
                .onFailure { error ->
                    _state.update { it.copy(editSaving = false, editError = error.toUserMessage()) }
                }
        }
    }

    fun onExportMyData() {
        if (_state.value.exportingData) return
        _state.update { it.copy(exportingData = true) }
        viewModelScope.launch {
            val targetDir = File(appContext.cacheDir, "exports")
            dataExportRepository.exportToFile(targetDir)
                .onSuccess { file ->
                    _state.update { it.copy(exportingData = false) }
                    _effects.send(Effect.ShareExport(file.absolutePath))
                }
                .onFailure { error ->
                    _state.update { it.copy(exportingData = false) }
                    _effects.send(Effect.ShowMessage(error.toUserMessage()))
                }
        }
    }

    fun onOpenDeleteAccount() {
        if (_state.value.deletingAccount) return
        _state.update { it.copy(deleteAccountOpen = true, deleteReason = "") }
    }

    fun onDismissDeleteAccount() {
        if (_state.value.deletingAccount) return
        _state.update { it.copy(deleteAccountOpen = false, deleteReason = "") }
    }

    fun onDeleteReasonChange(value: String) {
        _state.update { it.copy(deleteReason = value.take(500)) }
    }

    fun onConfirmDeleteAccount() {
        if (_state.value.deletingAccount) return
        val reason = _state.value.deleteReason
        _state.update { it.copy(deletingAccount = true) }
        viewModelScope.launch {
            accountDeletionRepository.deleteMyAccount(reason)
                .onSuccess {
                    authRepository.signOut()
                    _state.update {
                        it.copy(
                            deletingAccount = false,
                            deleteAccountOpen = false,
                            deleteReason = "",
                        )
                    }
                    _effects.send(Effect.ShowMessage("Account deleted. You have been signed out."))
                }
                .onFailure { error ->
                    _state.update { it.copy(deletingAccount = false) }
                    _effects.send(Effect.ShowMessage(error.toUserMessage()))
                }
        }
    }

    fun onSignOut() {
        if (_state.value.signingOut) return
        _state.update { it.copy(signingOut = true) }
        viewModelScope.launch {
            authRepository.signOut()
                .onFailure { error ->
                    _state.update { it.copy(signingOut = false) }
                    _effects.send(Effect.ShowMessage(error.toUserMessage()))
                }
            // On success, SessionViewModel transitions to SignedOut and root nav unmounts this screen.
        }
    }

    private suspend fun load(userId: String, initial: Boolean) {
        if (initial) _state.update { it.copy(loading = true, errorMessage = null) }
        profileRepository.fetchById(userId)
            .onSuccess { profile ->
                // For engineers, also fetch the engineers row so the screen
                // can render a status-accurate KYC chip and (when verified)
                // offer the public-profile preview link. engineer_public_profile
                // RPC gates to verified, so the preview link still requires
                // VerificationStatus.Verified.
                val engineer = if (profile?.role == UserRole.ENGINEER) {
                    engineerRepository.fetchByUserId(userId).getOrNull()
                } else null
                _state.update {
                    it.copy(
                        loading = false,
                        profile = profile,
                        ownEngineerId = engineer
                            ?.takeIf { eng -> eng.verificationStatus == VerificationStatus.Verified }
                            ?.id,
                        engineerStatus = engineer?.verificationStatus,
                        engineerKycSubmitted = engineer != null &&
                            !engineer.aadhaarDocPath.isNullOrBlank() &&
                            !engineer.panDocPath.isNullOrBlank() &&
                            engineer.certDocPaths.isNotEmpty(),
                        errorMessage = if (profile == null) "Profile not found" else null,
                    )
                }
            }
            .onFailure { error ->
                _state.update {
                    it.copy(
                        loading = false,
                        errorMessage = error.toUserMessage(),
                    )
                }
            }
    }

}
