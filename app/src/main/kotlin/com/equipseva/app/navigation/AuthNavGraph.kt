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
                onShowMessage = showSnackbar,
            )
        }
        composable(Routes.AUTH_SIGN_IN) {
            SignInScreen(
                onForgotPassword = { navController.navigate(Routes.AUTH_FORGOT_PASSWORD) },
                onShowMessage = showSnackbar,
            )
        }
        composable(Routes.AUTH_SIGN_UP) {
            SignUpScreen(onShowMessage = showSnackbar)
        }
        composable(Routes.AUTH_FORGOT_PASSWORD) {
            ForgotPasswordScreen(onBack = { navController.popBackStack() })
        }
    }
}
