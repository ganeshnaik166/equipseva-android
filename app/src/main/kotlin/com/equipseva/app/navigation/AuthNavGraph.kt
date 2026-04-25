package com.equipseva.app.navigation

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import androidx.navigation.navigation
import com.equipseva.app.features.auth.ForgotPasswordScreen
import com.equipseva.app.features.auth.OtpRequestScreen
import com.equipseva.app.features.auth.OtpVerifyScreen
import com.equipseva.app.features.auth.SignInScreen
import com.equipseva.app.features.auth.SignUpScreen
import com.equipseva.app.features.auth.WelcomeScreen
import com.equipseva.app.features.auth.phone.PhoneOtpRequestScreen
import com.equipseva.app.features.auth.phone.PhoneOtpVerifyScreen

/**
 * Auth sub-graph wired into the root NavHost when the session is signed-out.
 * The graph is self-contained: no dependency on the main bottom-tab graph beyond
 * the showSnackbar callback supplied by the host.
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
                onUseEmailCode = { navController.navigate(Routes.AUTH_OTP_REQUEST) },
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
        composable(Routes.AUTH_SIGN_IN) {
            SignInScreen(
                onUseOtpInstead = { navController.navigate(Routes.AUTH_OTP_REQUEST) },
                onForgotPassword = { navController.navigate(Routes.AUTH_FORGOT_PASSWORD) },
                onShowMessage = showSnackbar,
            )
        }
        composable(Routes.AUTH_SIGN_UP) {
            SignUpScreen(
                onOtpVerifyRequested = { email ->
                    navController.navigate(Routes.otpVerifyRoute(email))
                },
                onShowMessage = showSnackbar,
            )
        }
        composable(Routes.AUTH_FORGOT_PASSWORD) {
            ForgotPasswordScreen(onBack = { navController.popBackStack() })
        }
        composable(Routes.AUTH_OTP_REQUEST) {
            OtpRequestScreen(
                onCodeSent = { email ->
                    navController.navigate(Routes.otpVerifyRoute(email))
                },
                onShowMessage = showSnackbar,
            )
        }
        composable(
            route = "${Routes.AUTH_OTP_VERIFY}/{${Routes.AUTH_OTP_VERIFY_ARG_EMAIL}}",
            arguments = listOf(
                navArgument(Routes.AUTH_OTP_VERIFY_ARG_EMAIL) { type = NavType.StringType },
            ),
        ) { entry ->
            val raw = entry.arguments?.getString(Routes.AUTH_OTP_VERIFY_ARG_EMAIL).orEmpty()
            val email = runCatching {
                java.net.URLDecoder.decode(raw, Charsets.UTF_8.name())
            }.getOrDefault(raw)
            OtpVerifyScreen(
                email = email,
                onShowMessage = showSnackbar,
            )
        }
    }
}
