package com.equipseva.app.navigation

import androidx.navigation.NavHostController
import androidx.navigation.compose.ComposeNavigator
import androidx.navigation.compose.composable
import androidx.navigation.createGraph
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** The SignUp footer has two real entry stacks; its destination and Back must agree for both. */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE)
class SignUpToSignInNavigationTest {
    private fun authController(): NavHostController =
        NavHostController(ApplicationProvider.getApplicationContext()).apply {
            navigatorProvider.addNavigator(ComposeNavigator())
            graph = createGraph(
                startDestination = Routes.AUTH_WELCOME,
                route = Routes.AUTH_GRAPH,
            ) {
                composable(Routes.AUTH_WELCOME) {}
                composable(Routes.AUTH_SIGN_IN) {}
                composable(Routes.AUTH_SIGN_UP) {}
            }
        }

    @Test fun `direct Welcome to SignUp footer reaches SignIn then Back returns Welcome`() {
        val controller = authController()
        controller.navigate(Routes.AUTH_SIGN_UP)

        controller.returnToSignInFromSignUp()

        assertEquals(Routes.AUTH_SIGN_IN, controller.currentDestination?.route)
        assertTrue(controller.popBackStack())
        assertEquals(Routes.AUTH_WELCOME, controller.currentDestination?.route)
    }

    @Test fun `SignIn to SignUp footer reuses existing SignIn then Back returns Welcome`() {
        val controller = authController()
        controller.navigate(Routes.AUTH_SIGN_IN)
        controller.navigate(Routes.AUTH_SIGN_UP)

        controller.returnToSignInFromSignUp()

        assertEquals(Routes.AUTH_SIGN_IN, controller.currentDestination?.route)
        assertTrue(controller.popBackStack())
        assertEquals(Routes.AUTH_WELCOME, controller.currentDestination?.route)
    }

    @Test fun `ordinary Back from SignUp still returns to its entry screen`() {
        val direct = authController()
        direct.navigate(Routes.AUTH_SIGN_UP)
        assertTrue(direct.popBackStack())
        assertEquals(Routes.AUTH_WELCOME, direct.currentDestination?.route)

        val viaSignIn = authController()
        viaSignIn.navigate(Routes.AUTH_SIGN_IN)
        viaSignIn.navigate(Routes.AUTH_SIGN_UP)
        assertTrue(viaSignIn.popBackStack())
        assertEquals(Routes.AUTH_SIGN_IN, viaSignIn.currentDestination?.route)
    }
}
