package com.equipseva.app.features.auth.state

/**
 * One-shot side effects emitted by auth ViewModels. Screens collect these via
 * `LaunchedEffect` and translate to navigation or snackbars.
 */
sealed interface AuthEffect {
    data object NavigateToHome : AuthEffect
    data class ShowMessage(val text: String) : AuthEffect
    // v0.3.4: hospitals route to phone collection after role select,
    // not directly to Home. Engineers continue straight to Home (their
    // phone is collected as part of the KYC flow).
    data object NavigateToHospitalPhoneOnboarding : AuthEffect
}
