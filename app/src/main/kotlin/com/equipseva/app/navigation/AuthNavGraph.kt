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
                    navController.popBackStack(Routes.AUTH_SIGN_IN, inclusive = false)
                },
                // v0.3.4 — hospitals route into the phone-onboarding gate
                // immediately after a successful signup so AppNavGraph's
                // session observer doesn't swap to Home before phone capture.
                onNavigateToPhoneOnboarding = {
                    navController.navigate(Routes.HOSPITAL_PHONE_ONBOARDING) {
                        launchSingleTop = true
                    }
                },
            )
        }
        composable(Routes.AUTH_FORGOT_PASSWORD) {
            ForgotPasswordScreen(onBack = { navController.popBackStack() })
        }
        // v0.3.4 — post-signup phone collection for hospitals. Entered
        // after RoleSelectScreen when hospital role is selected; routes
        // to main on successful save (AppNavGraph AuthHostInline observes
        // the session transition and calls onAuthSuccess to swap graphs).
        composable(Routes.HOSPITAL_PHONE_ONBOARDING) {
            com.equipseva.app.features.onboarding.HospitalPhoneOnboardingScreen(
                onDone = {
                    // Pop the entire auth graph; AppNavGraph's session
                    // transition observer will route us to the main graph.
                    navController.popBackStack(Routes.AUTH_GRAPH, inclusive = true)
                },
                onShowMessage = showSnackbar,
            )
        }
    }
}
