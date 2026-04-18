package com.equipseva.app.features.auth

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.toAuthError
import com.equipseva.app.core.util.BuildConfigValues
import com.equipseva.app.features.auth.google.GoogleSignInClient
import com.equipseva.app.features.auth.google.GoogleSignInResult
import com.equipseva.app.features.auth.state.AuthEffect
import com.equipseva.app.features.auth.state.FormUiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class WelcomeViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val googleSignInClient: GoogleSignInClient,
) : ViewModel() {

    data class WelcomeState(
        val googleConfigured: Boolean = BuildConfigValues.hasGoogleSignInConfig,
        val googleLoading: Boolean = false,
        val form: FormUiState = FormUiState(),
    )

    private val _state = MutableStateFlow(WelcomeState())
    val state: StateFlow<WelcomeState> = _state.asStateFlow()

    private val _effects = Channel<AuthEffect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()

    fun onGoogleClicked(activityContext: Context) {
        if (_state.value.googleLoading) return
        _state.update { it.copy(googleLoading = true, form = FormUiState(submitting = true)) }
        viewModelScope.launch {
            when (val result = googleSignInClient.signIn(activityContext)) {
                is GoogleSignInResult.Token -> {
                    val supabaseResult = authRepository.signInWithGoogleIdToken(result.idToken, result.rawNonce)
                    supabaseResult.fold(
                        onSuccess = {
                            _state.update { it.copy(googleLoading = false, form = FormUiState()) }
                            // SessionViewModel observes the new auth state; we just dismiss the welcome screen.
                            _effects.send(AuthEffect.NavigateToHome)
                        },
                        onFailure = { ex ->
                            _state.update {
                                it.copy(
                                    googleLoading = false,
                                    form = FormUiState(errorMessage = ex.toAuthError().userMessage),
                                )
                            }
                        },
                    )
                }
                is GoogleSignInResult.Cancelled -> {
                    _state.update { it.copy(googleLoading = false, form = FormUiState()) }
                }
                is GoogleSignInResult.NotConfigured -> {
                    _state.update {
                        it.copy(
                            googleLoading = false,
                            form = FormUiState(errorMessage = "Google sign-in isn't configured for this build."),
                        )
                    }
                }
                is GoogleSignInResult.Error -> {
                    _state.update {
                        it.copy(
                            googleLoading = false,
                            form = FormUiState(errorMessage = result.message),
                        )
                    }
                }
            }
        }
    }

    fun dismissError() {
        _state.update { it.copy(form = it.form.copy(errorMessage = null)) }
    }
}
