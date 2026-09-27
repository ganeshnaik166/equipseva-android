package com.equipseva.app.navigation

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import androidx.navigation.navigation
import com.equipseva.app.features.auth.ForgotPasswordScreen
import com.equipseva.app.features.auth.SignInScreen
import com.equipseva.app.features.auth.SignUpScreen
import com.equipseva.app.features.auth.WelcomeScreen

/**
 * Auth sub-graph wired into the root NavHost when the session is signed-out.
 * Email + password is the primary path: Welcome → SignIn → (Forgot password
 * recovery) or SignUp → land on the main graph (the SessionViewModel observes
 * the new auth state and the host swaps graphs). Google sign-in is triggered
 * inline from SignInScreen and reaches the same SignedIn state.
 */
fun NavGraphBuilder.authNavGraph(
    navController: NavHostController,
    showSnackbar: (String) -> Unit,
    onHospitalPhoneRequested: () -> Unit,
    onHospitalPhoneDone: () -> Unit,
    onSignUpProfileCommitted: () -> Unit,
) {
    navigation(
        route = Routes.AUTH_GRAPH,
        startDestination = Routes.AUTH_WELCOME,
    ) {
        composable(Routes.AUTH_WELCOME) {
            WelcomeScreen(
                onSignIn = { navController.navigate(Routes.AUTH_SIGN_IN) },
                onSignUp = { navController.navigate(Routes.AUTH_SIGN_UP) },
            )
        }
        composable(Routes.AUTH_SIGN_IN) {
            SignInScreen(
                onBack = { navController.popBackStack() },
                onForgotPassword = { navController.navigate(Routes.AUTH_FORGOT_PASSWORD) },
                onCreateAccount = { navController.navigate(Routes.AUTH_SIGN_UP) },
                onShowMessage = showSnackbar,
            )
        }
        composable(Routes.AUTH_SIGN_UP) {
            SignUpScreen(
                onShowMessage = showSnackbar,
                onBack = { navController.popBackStack() },
                onSignIn = {
                    navController.returnToSignInFromSignUp()
                },
                onNavigateToHome = onSignUpProfileCommitted,
                // The effect requests phone collection; AuthHostInline waits
                // for a server-confirmed hospital role before opening it.
                onNavigateToPhoneOnboarding = {
                    onHospitalPhoneRequested()
                },
            )
        }
        composable(Routes.AUTH_FORGOT_PASSWORD) {
            ForgotPasswordScreen(onBack = { navController.popBackStack() })
        }
        // Post-signup phone collection for confirmed hospitals. The host
        // retains this route through the save/revalidation boundary.
        composable(Routes.HOSPITAL_PHONE_ONBOARDING) {
            com.equipseva.app.features.onboarding.HospitalPhoneOnboardingScreen(
                onDone = {
                    // Keep this entry mounted until the root session validates
                    // the saved profile, then hand off to Main/Onboarding.
                    onHospitalPhoneDone()
                },
                onShowMessage = showSnackbar,
            )
        }
    }
}

/** Return to the existing SignIn entry, or replace a direct Welcome → SignUp entry. */
internal fun NavHostController.returnToSignInFromSignUp() {
    // A queued/double tap from the old SignUp composition must not rewrite a later auth screen.
    if (currentDestination?.route != Routes.AUTH_SIGN_UP) return
    if (popBackStack(Routes.AUTH_SIGN_IN, inclusive = false)) return

    navigate(Routes.AUTH_SIGN_IN) {
        popUpTo(Routes.AUTH_SIGN_UP) { inclusive = true }
        launchSingleTop = true
    }
}
