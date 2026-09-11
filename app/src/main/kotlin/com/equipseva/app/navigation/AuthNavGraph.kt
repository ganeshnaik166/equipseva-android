package com.equipseva.app.navigation

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import androidx.navigation.navigation
import androidx.compose.runtime.LaunchedEffect
import com.equipseva.app.features.auth.ForgotPasswordScreen
import com.equipseva.app.features.auth.SignInScreen
import com.equipseva.app.features.auth.SignUpScreen
import com.equipseva.app.features.auth.WelcomeScreen

/**
 * Auth sub-graph wired into the root NavHost when the session is signed-out.
 * Email + password is the primary path: Welcome → SignIn → (Forgot password
 * recovery) or SignUp → server-profile validation and required setup. Google sign-in is triggered
 * inline from SignInScreen and reaches the same SignedIn state.
 */
fun NavGraphBuilder.authNavGraph(
    navController: NavHostController,
    showSnackbar: (String) -> Unit,
    onProfileSaved: () -> Unit = {},
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
                    if (!navController.popBackStack(Routes.AUTH_SIGN_IN, inclusive = false)) {
                        navController.navigate(Routes.AUTH_SIGN_IN) { launchSingleTop = true }
                    }
                },
                // Child effects only request an owned server refresh. Root
                // selects role confirmation, complete onboarding, or Main.
                onNavigateToPhoneOnboarding = onProfileSaved,
                onProfileSaved = onProfileSaved,
            )
        }
        composable(Routes.AUTH_FORGOT_PASSWORD) {
            ForgotPasswordScreen(onBack = { navController.popBackStack() })
        }
        legacyPhoneAuthRedirect(navController)
    }
}

/** Restoring an old signed-out graph must never instantiate authenticated setup. */
internal fun NavGraphBuilder.legacyPhoneAuthRedirect(navController: NavHostController) {
    composable(Routes.HOSPITAL_PHONE_ONBOARDING) {
        LaunchedEffect(Unit) {
            navController.navigate(Routes.AUTH_SIGN_IN) {
                popUpTo(Routes.AUTH_GRAPH) { inclusive = false }
                launchSingleTop = true
            }
        }
    }
}
