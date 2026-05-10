package com.equipseva.app.features.auth

import androidx.lifecycle.ViewModel
import com.equipseva.app.features.auth.state.AuthEffect
import com.equipseva.app.features.auth.state.FormUiState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import javax.inject.Inject

@HiltViewModel
class WelcomeViewModel @Inject constructor() : ViewModel() {

    data class WelcomeState(
        val form: FormUiState = FormUiState(),
    )

    private val _state = MutableStateFlow(WelcomeState())
    val state: StateFlow<WelcomeState> = _state.asStateFlow()

    private val _effects = Channel<AuthEffect>(Channel.BUFFERED)
    val effects = _effects.receiveAsFlow()
}
