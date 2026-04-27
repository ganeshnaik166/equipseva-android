package com.equipseva.app.navigation

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import androidx.navigation.navigation
import com.equipseva.app.features.auth.WelcomeScreen
import com.equipseva.app.features.auth.phone.PhoneOtpRequestScreen
import com.equipseva.app.features.auth.phone.PhoneOtpVerifyScreen

/**
 * Auth sub-graph wired into the root NavHost when the session is signed-out.
 * Phone OTP is the only path: Welcome → PhoneOtpRequest → PhoneOtpVerify →
 * land on the main graph (the SessionViewModel observes the new auth state
 * and the host swaps graphs).
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
                onUsePhone = { navController.navigate(Routes.AUTH_PHONE_OTP_REQUEST) },
                onShowMessage = showSnackbar,
            )
        }
        composable(Routes.AUTH_PHONE_OTP_REQUEST) {
            PhoneOtpRequestScreen(
                onBack = { navController.popBackStack() },
                onNavigateToVerify = { phone ->
                    navController.navigate(Routes.phoneOtpVerifyRoute(phone))
                },
            )
        }
        composable(
            route = "${Routes.AUTH_PHONE_OTP_VERIFY}/{${Routes.AUTH_PHONE_OTP_VERIFY_ARG_PHONE}}",
            arguments = listOf(
                navArgument(Routes.AUTH_PHONE_OTP_VERIFY_ARG_PHONE) { type = NavType.StringType },
            ),
        ) {
            PhoneOtpVerifyScreen(
                onBack = { navController.popBackStack() },
            )
        }
    }
}
