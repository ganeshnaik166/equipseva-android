package com.equipseva.app.features.profile

import android.content.ContentResolver
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.InvalidCurrentPasswordException
import kotlinx.coroutines.flow.firstOrNull
import com.equipseva.app.core.data.account.SupabaseAccountDeletionRepository
import com.equipseva.app.core.data.account.SupabaseDataExportRepository
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.data.engineers.EngineerRepository
import com.equipseva.app.core.data.engineers.VerificationStatus
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.data.profile.Profile
import com.equipseva.app.core.data.profile.ProfileRepository
import com.equipseva.app.core.network.toUserMessage
import com.equipseva.app.core.push.DeviceTokenRegistrar
import com.equipseva.app.core.sync.OutboxScheduler
import com.equipseva.app.core.sync.handlers.PhotoUploadStash
import com.equipseva.app.core.util.IMAGE_MIME_TYPES
import com.equipseva.app.core.util.MIME_JPEG
import com.equipseva.app.features.auth.UserRole
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import javax.inject.Inject

@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val profileRepository: ProfileRepository,
    private val engineerRepository: EngineerRepository,
    private val userPrefs: UserPrefs,
    private val accountDeletionRepository: SupabaseAccountDeletionRepository,
    private val dataExportRepository: SupabaseDataExportRepository,
    private val deviceTokenRegistrar: DeviceTokenRegistrar,
    private val outboxDao: OutboxDao,
    private val outboxScheduler: OutboxScheduler,
    private val photoUploadStash: PhotoUploadStash,
    private val storageRepository: com.equipseva.app.core.storage.StorageRepository,
    private val userBlockRepository: com.equipseva.app.core.data.moderation.UserBlockRepository,
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
        val signOutConfirmOpen: Boolean = false,
        val editProfileOpen: Boolean = false,
        val editFullName: String = "",
        val editPhone: String = "",
        val editSaving: Boolean = false,
        val editError: String? = null,
        val deleteAccountOpen: Boolean = false,
        val deleteReason: String = "",
        val deletePassword: String = "",
        val deletePasswordError: String? = null,
        val deletingAccount: Boolean = false,
        /** True while an avatar image is being uploaded + the profile row updated. */
        val avatarUploading: Boolean = false,
        val exportingData: Boolean = false,
        val exportConfirmOpen: Boolean = false,
        /**
         * v2.1 PR-D30 — engineer-side cash-flag auto-suspension snapshot.
         * Null when the user is not an engineer or not currently
         * suspended. Drives the suspension banner on Profile so the
         * engineer understands why their availability flipped off.
         */
        val mySuspension: com.equipseva.app.core.data.engineers.EngineerRepository.MySuspension? = null,
    )

    sealed interface Effect {
        data class ShowMessage(val text: String) : Effect
        data class ShareExport(val path: String) : Effect
        data object NavigateHome : Effect
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private val _effects = kotlinx.coroutines.flow.MutableSharedFlow<Effect>(extraBufferCapacity = 4)
    val effects: kotlinx.coroutines.flow.Flow<Effect> = _effects

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
            // Mirror onToggleRoleAndGoHome — `updateRole` only writes the
            // scalar `role` column on profiles. The bootstrap session +
            // bottom-nav drive everything off `active_role`, so leaving
            // the active_role column at its previous value broke the
            // role flip after a cold launch (verified on Realme
            // 2026-05-08 e2e QA: cached=hospital_admin active=hospital_admin
            // raw=engineer in the SessionVM snackbar). Add the role to
            // the multi-role array first if needed, then flip
            // active_role via the dedicated RPC.
            val profile = current.profile
            val hasRole = profile?.roles?.contains(target) == true
            val ensureRole = if (hasRole) {
                Result.success(Unit)
            } else {
                profileRepository.addRole(target.storageKey)
            }
            ensureRole
                .onSuccess {
                    profileRepository.setActiveRole(target.storageKey)
                        .onSuccess {
                            userPrefs.setActiveRole(target.storageKey)
                            _state.update {
                                it.copy(
                                    profile = it.profile?.copy(
                                        role = target,
                                        rawRoleKey = target.storageKey,
                                        activeRole = target,
                                        activeRoleKey = target.storageKey,
                                        roleConfirmed = true,
                                        roles = (it.profile.roles + target).distinct(),
                                    ),
                                    roleEditorOpen = false,
                                    roleEditorSelected = null,
                                    roleUpdating = false,
                                )
                            }
                            _effects.emit(Effect.ShowMessage("Role updated to ${target.displayName}"))
                            // Bounce back to Home so the new persona's tab
                            // bar matches the visible content. Without this
                            // the user can stay parked on a route that
                            // belongs to the OLD persona (e.g. switching
                            // Engineer→Hospital while on ENGINEER_JOBS_HUB
                            // leaves the engineer tiles rendered under a
                            // Hospital bottom-nav).
                            _effects.emit(Effect.NavigateHome)
                        }
                        .onFailure { error ->
                            _state.update { it.copy(roleUpdating = false) }
                            _effects.emit(Effect.ShowMessage(error.toUserMessage()))
                        }
                }
                .onFailure { error ->
                    _state.update { it.copy(roleUpdating = false) }
                    _effects.emit(Effect.ShowMessage(error.toUserMessage()))
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

    /**
     * "Switch" CTA in the Account-type section. Toggles between Engineer ↔
     * Hospital — adds the role first if the user doesn't have it yet, then
     * sets it active and emits a NavigateHome effect so the host can pop
     * back to the role-aware home graph.
     */
    fun onToggleRoleAndGoHome() {
        val current = _state.value
        if (current.roleUpdating) return
        val profile = current.profile ?: return
        val currentRole = profile.activeRole ?: profile.role ?: return
        val target = when (currentRole) {
            UserRole.ENGINEER -> UserRole.HOSPITAL
            UserRole.HOSPITAL -> UserRole.ENGINEER
            else -> UserRole.HOSPITAL
        }
        _state.update { it.copy(roleUpdating = true) }
        viewModelScope.launch {
            val hasRole = profile.roles.contains(target)
            val ensureRole = if (hasRole) Result.success(Unit) else profileRepository.addRole(target.storageKey)
            ensureRole
                .onSuccess {
                    profileRepository.setActiveRole(target.storageKey)
                        .onSuccess {
                            userPrefs.setActiveRole(target.storageKey)
                            _state.update {
                                it.copy(
                                    roleUpdating = false,
                                    profile = it.profile?.copy(
                                        role = target,
                                        rawRoleKey = target.storageKey,
                                        activeRole = target,
                                        activeRoleKey = target.storageKey,
                                        roles = (it.profile.roles + target).distinct(),
                                    ),
                                )
                            }
                            _effects.emit(Effect.ShowMessage("Switched to ${target.displayName}"))
                            _effects.emit(Effect.NavigateHome)
                        }
                        .onFailure { ex ->
                            _state.update { it.copy(roleUpdating = false) }
                            _effects.emit(Effect.ShowMessage(ex.toUserMessage()))
                        }
                }
                .onFailure { ex ->
                    _state.update { it.copy(roleUpdating = false) }
                    _effects.emit(Effect.ShowMessage(ex.toUserMessage()))
                }
        }
    }

    fun onDismissEditProfile() {
        if (_state.value.editSaving) return
        _state.update { it.copy(editProfileOpen = false, editError = null) }
    }

    fun onEditFullNameChange(value: String) {
        // Same 100-char cap as the SignUp form — paste of a large blob
        // would otherwise either truncate server-side (silent corruption)
        // or wedge submit on profiles.full_name's effective limit.
        val capped = value.take(100)
        _state.update { it.copy(editFullName = capped, editError = null) }
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
                    _effects.emit(Effect.ShowMessage("Profile updated"))
                }
                .onFailure { error ->
                    _state.update { it.copy(editSaving = false, editError = error.toUserMessage()) }
                }
        }
    }

    /**
     * Pick an image from the gallery and upload it to the `avatars` bucket
     * keyed by the signed-in user's id. On success, persist the public URL
     * (with a cache-bust query param) on `profiles.avatar_url` so the hero
     * + every consumer of the column re-renders without restart.
     */
    fun uploadAvatar(uri: Uri) {
        val current = _state.value
        if (current.avatarUploading) return
        val profile = current.profile ?: return
        val resolver = appContext.contentResolver
        val mime = resolver.getType(uri) ?: MIME_JPEG
        // Reject formats the avatar bucket / display pipeline can't render
        // up-front rather than uploading something the server-side check
        // will reject. JPEG/PNG/WebP cover phone camera + share-sheet
        // sources; GIF/SVG/TIFF/HEIC get rejected client-side.
        val isAllowed = mime.lowercase() in IMAGE_MIME_TYPES
        if (!isAllowed) {
            viewModelScope.launch {
                _effects.emit(Effect.ShowMessage("Please pick a JPG, PNG, or WebP photo."))
            }
            return
        }
        _state.update { it.copy(avatarUploading = true, errorMessage = null) }
        viewModelScope.launch {
            // Downsample + re-encode to JPEG ~1024px / 85% before upload.
            // The previous path called readBytes() on the raw stream and
            // sent a 6-12 MB image to Supabase on every avatar change —
            // OOM risk on low-end phones, slow upload on cellular, waste
            // of storage quota.
            val bytes = withContext(kotlinx.coroutines.Dispatchers.IO) {
                runCatching { encodeAvatarBytes(resolver, uri) }.getOrNull()
            }
            if (bytes == null) {
                _state.update { it.copy(avatarUploading = false) }
                _effects.emit(Effect.ShowMessage("Couldn't read image"))
                return@launch
            }
            val path = "${profile.id}/avatar.jpg"
            storageRepository.upload(
                bucket = com.equipseva.app.core.storage.StorageRepository.Buckets.AVATARS,
                path = path,
                bytes = bytes,
                contentType = MIME_JPEG,
            )
                .onSuccess {
                    val url = storageRepository.publicUrl(
                        com.equipseva.app.core.storage.StorageRepository.Buckets.AVATARS,
                        path,
                    ) + "?v=" + System.currentTimeMillis()
                    profileRepository.updateBasicInfo(profile.id, avatarUrl = url)
                        .onSuccess {
                            _state.update {
                                it.copy(
                                    avatarUploading = false,
                                    profile = it.profile?.copy(avatarUrl = url),
                                )
                            }
                            _effects.emit(Effect.ShowMessage("Photo updated"))
                        }
                        .onFailure { ex ->
                            _state.update { it.copy(avatarUploading = false) }
                            _effects.emit(Effect.ShowMessage(ex.toUserMessage()))
                        }
                }
                .onFailure { ex ->
                    _state.update { it.copy(avatarUploading = false) }
                    _effects.emit(Effect.ShowMessage(ex.toUserMessage()))
                }
        }
    }

    /** Open the export-confirmation dialog instead of exporting immediately —
     *  the resulting JSON contains PII (profile, addresses, messages) so the
     *  user should consent to a Share-sheet before we generate it. */
    fun onOpenExportConfirm() {
        if (_state.value.exportingData) return
        _state.update { it.copy(exportConfirmOpen = true) }
    }

    fun onDismissExportConfirm() {
        if (_state.value.exportingData) return
        _state.update { it.copy(exportConfirmOpen = false) }
    }

    fun onExportMyData() {
        if (_state.value.exportingData) return
        _state.update { it.copy(exportingData = true, exportConfirmOpen = false) }
        viewModelScope.launch {
            val targetDir = File(appContext.cacheDir, "exports")
            dataExportRepository.exportToFile(targetDir)
                .onSuccess { file ->
                    _state.update { it.copy(exportingData = false) }
                    _effects.emit(Effect.ShareExport(file.absolutePath))
                }
                .onFailure { error ->
                    _state.update { it.copy(exportingData = false) }
                    _effects.emit(Effect.ShowMessage(error.toUserMessage()))
                }
        }
    }

    fun onOpenDeleteAccount() {
        if (_state.value.deletingAccount) return
        _state.update {
            it.copy(
                deleteAccountOpen = true,
                deleteReason = "",
                deletePassword = "",
                deletePasswordError = null,
            )
        }
    }

    fun onDismissDeleteAccount() {
        if (_state.value.deletingAccount) return
        _state.update {
            it.copy(
                deleteAccountOpen = false,
                deleteReason = "",
                deletePassword = "",
                deletePasswordError = null,
            )
        }
    }

    fun onDeleteReasonChange(value: String) {
        _state.update { it.copy(deleteReason = value.take(500)) }
    }

    fun onDeletePasswordChange(value: String) {
        _state.update { it.copy(deletePassword = value, deletePasswordError = null) }
    }

    fun onConfirmDeleteAccount() {
        if (_state.value.deletingAccount) return
        val reason = _state.value.deleteReason
        val password = _state.value.deletePassword
        if (password.isBlank()) {
            _state.update { it.copy(deletePasswordError = "Enter your password to confirm.") }
            return
        }
        _state.update { it.copy(deletingAccount = true, deletePasswordError = null) }
        viewModelScope.launch {
            // Re-auth gate — must succeed before we call the
            // delete-my-account RPC. Without this an attacker with
            // momentary access to an unlocked device can nuke the
            // account; the RPC runs purely on auth.uid and has no
            // server-side credential proof.
            val reauth = authRepository.verifyCurrentPassword(password)
            if (reauth.isFailure) {
                val cause = reauth.exceptionOrNull()
                val msg = if (cause is InvalidCurrentPasswordException) {
                    "Incorrect password."
                } else {
                    cause?.toUserMessage() ?: "Couldn't verify password."
                }
                _state.update {
                    it.copy(deletingAccount = false, deletePasswordError = msg)
                }
                return@launch
            }
            val outcome = accountDeletionRepository.deleteMyAccount(reason)
            outcome.fold(
                onSuccess = {
                    // Close sheet immediately so the user gets visible
                    // feedback even if the cleanup hangs.
                    _state.update {
                        it.copy(
                            deletingAccount = false,
                            deleteAccountOpen = false,
                            deleteReason = "",
                            deletePassword = "",
                        )
                    }
                    _effects.emit(Effect.ShowMessage("Account deleted. Signing you out…"))

                    // Best-effort device cleanup. Each step is wrapped so a
                    // single failure (e.g. token revoke after auth.users was
                    // deleted) doesn't block the sign-out below.
                    runCatching { deviceTokenRegistrar.revoke() }
                    runCatching { outboxDao.clearAll() }
                    runCatching { outboxScheduler.cancelAll() }
                    runCatching { photoUploadStash.clearAll() }
                    runCatching { userPrefs.setLastScreen(null) }
                    runCatching { userPrefs.clearActiveRole() }
                    runCatching { userPrefs.setMutedPushCategories(emptySet()) }
                    runCatching { userPrefs.setQuietHoursEnabled(false) }
                    runCatching { userBlockRepository.clearCache() }

                    // Sign out wipes the local session even if the network
                    // call fails — the SDK clears the cached token unconditionally.
                    runCatching { authRepository.signOut() }
                },
                onFailure = { error ->
                    _state.update {
                        it.copy(deletingAccount = false, deleteAccountOpen = false)
                    }
                    _effects.emit(Effect.ShowMessage("Couldn't delete account: ${error.toUserMessage()}"))
                },
            )
        }
    }

    fun onOpenSignOutConfirm() {
        if (_state.value.signingOut) return
        _state.update { it.copy(signOutConfirmOpen = true) }
    }

    fun onDismissSignOutConfirm() {
        _state.update { it.copy(signOutConfirmOpen = false) }
    }

    fun onSignOut() {
        if (_state.value.signingOut) return
        _state.update { it.copy(signingOut = true, signOutConfirmOpen = false) }
        viewModelScope.launch {
            // Wipe device-resident user state BEFORE the auth call so the
            // network-side token revoke still has a valid session, and so
            // the next user signing in on this device can't see the
            // previous user's queued outbox / photo stash. Each step is
            // best-effort — sign-out should never block on a flaky DELETE.
            runCatching { deviceTokenRegistrar.revoke() }
            runCatching { outboxDao.clearAll() }
            runCatching { outboxScheduler.cancelAll() }
            runCatching { photoUploadStash.clearAll() }
            runCatching { userPrefs.setLastScreen(null) }
            // Wipe activeRole too — otherwise the next user signing in on
            // the same device sees the previous user's Hub (hospital tabs
            // for an engineer account, etc.). profile.role is the truth on
            // first launch; activeRole gets re-set on Hub pick / first
            // dispatch by SessionViewModel.
            runCatching { userPrefs.clearActiveRole() }
            // Notification prefs are device-resident user state. Without
            // a reset the next account inherits the previous user's mute
            // categories + quiet-hours window, silently swallowing pushes
            // the new user explicitly enabled.
            runCatching { userPrefs.setMutedPushCategories(emptySet()) }
            runCatching { userPrefs.setQuietHoursEnabled(false) }
            // @Singleton UserBlockRepository holds the previous user's
            // blocked-id set in memory; clear so the next sign-in
            // doesn't see stale blocks until the first refresh().
            runCatching { userBlockRepository.clearCache() }
            authRepository.signOut()
                .onFailure { error ->
                    _state.update { it.copy(signingOut = false) }
                    _effects.emit(Effect.ShowMessage(error.toUserMessage()))
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
                val mySuspension = if (profile?.role == UserRole.ENGINEER) {
                    engineerRepository.fetchMySuspension().getOrNull()
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
                        mySuspension = mySuspension,
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

    /** Decode picked image with inSampleSize, apply EXIF rotation, scale to
     *  AVATAR_MAX_DIM_PX longest edge, encode JPEG @ AVATAR_JPEG_QUALITY.
     *  Keeps memory footprint sane on 12MP camera shots. */
    private fun encodeAvatarBytes(resolver: ContentResolver, uri: Uri): ByteArray? {
        val sourceBounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, sourceBounds) }
        val srcW = sourceBounds.outWidth
        val srcH = sourceBounds.outHeight
        if (srcW <= 0 || srcH <= 0) return null

        // Halve sample size until the larger dim is within 2× the target,
        // so the in-memory Bitmap stays small but we keep enough detail to
        // produce a sharp resize.
        var sample = 1
        while ((maxOf(srcW, srcH) / sample) > AVATAR_MAX_DIM_PX * 2) sample *= 2

        val decoded = resolver.openInputStream(uri)?.use { stream ->
            val opts = BitmapFactory.Options().apply { inSampleSize = sample }
            BitmapFactory.decodeStream(stream, null, opts)
        } ?: return null

        // EXIF rotation — camera shots from portrait orientation come back
        // landscape-bytes + an EXIF tag the canvas doesn't honour. Rotate
        // before resize so the result is upright.
        val rotation = runCatching {
            resolver.openInputStream(uri)?.use { stream ->
                when (ExifInterface(stream).getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )) {
                    ExifInterface.ORIENTATION_ROTATE_90 -> 90
                    ExifInterface.ORIENTATION_ROTATE_180 -> 180
                    ExifInterface.ORIENTATION_ROTATE_270 -> 270
                    else -> 0
                }
            }
        }.getOrNull() ?: 0

        val oriented = if (rotation != 0) {
            val m = Matrix().apply { postRotate(rotation.toFloat()) }
            Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, m, true)
                .also { if (it !== decoded) decoded.recycle() }
        } else decoded

        // Scale longest edge to AVATAR_MAX_DIM_PX.
        val maxEdge = maxOf(oriented.width, oriented.height)
        val scaled = if (maxEdge > AVATAR_MAX_DIM_PX) {
            val ratio = AVATAR_MAX_DIM_PX.toFloat() / maxEdge
            val targetW = (oriented.width * ratio).toInt().coerceAtLeast(1)
            val targetH = (oriented.height * ratio).toInt().coerceAtLeast(1)
            Bitmap.createScaledBitmap(oriented, targetW, targetH, true)
                .also { if (it !== oriented) oriented.recycle() }
        } else oriented

        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.JPEG, AVATAR_JPEG_QUALITY, out)
        scaled.recycle()
        return out.toByteArray()
    }

    private companion object {
        const val AVATAR_MAX_DIM_PX = 1024
        const val AVATAR_JPEG_QUALITY = 85
    }
}
