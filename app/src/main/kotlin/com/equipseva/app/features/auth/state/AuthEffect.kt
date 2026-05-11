package com.equipseva.app.features.auth.state

/**
 * One-shot side effects emitted by auth ViewModels. Screens collect these via
 * `LaunchedEffect` and translate to navigation or snackbars.
 */
sealed interface AuthEffect {
    data object NavigateToHome : AuthEffect
    data class ShowMessage(val text: String) : AuthEffect
}
