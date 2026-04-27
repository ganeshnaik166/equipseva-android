package com.equipseva.app.features.auth

import androidx.lifecycle.ViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

/**
 * Welcome screen no longer carries any state — the only CTA on the screen
 * navigates to the phone-OTP request flow. This trivial VM stays so the
 * @Composable signature can keep using `hiltViewModel()` for back-compat;
 * future per-screen state can hang off it.
 */
@HiltViewModel
class WelcomeViewModel @Inject constructor() : ViewModel()
