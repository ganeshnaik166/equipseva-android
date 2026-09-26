package com.equipseva.app.features.auth

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.auth.google.GoogleSignInClient
import com.equipseva.app.features.auth.google.GoogleSignInResult
import com.equipseva.app.testing.FakeAuthRepository
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.CompletableDeferred
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(application = android.app.Application::class, sdk = [35], qualifiers = RobolectricDeviceQualifiers.Pixel5)
class SignInRecoveryTargetTest {
    @get:Rule val composeRule = createComposeRule()

    @Test
    fun recovery_action_has_button_semantics_and_48dp_target_without_authentication() {
        val repository = FakeAuthRepository()
        val viewModel = SignInViewModel(repository, mockk(relaxed = true))
        var recoveryCalls = 0
        composeRule.setContent {
            EquipSevaTheme {
                SignInScreen(
                    onBack = {},
                    onForgotPassword = { recoveryCalls++ },
                    onCreateAccount = {},
                    onShowMessage = {},
                    viewModel = viewModel,
                )
            }
        }

        val recovery = composeRule.onNodeWithText("Forgot password?")
        recovery.assertHasClickAction()
        recovery.assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button))
        val bounds = recovery.getUnclippedBoundsInRoot()
        assertTrue("Recovery target height is under 48dp", bounds.bottom - bounds.top >= Spacing.MinTouchTarget)
        recovery.performClick()
        assertEquals(1, recoveryCalls)
        assertTrue(repository.signInCalls.isEmpty())
        assertTrue(repository.resetEmails.isEmpty())
    }

    @Test
    fun recovery_action_is_reachable_on_small_screen_with_double_text_scale() {
        val viewModel = SignInViewModel(FakeAuthRepository(), mockk(relaxed = true))
        composeRule.setContent {
            CompositionLocalProvider(LocalDensity provides Density(density = 1f, fontScale = 2f)) {
                Box(Modifier.size(width = 320.dp, height = 420.dp)) {
                    EquipSevaTheme {
                        SignInScreen(
                            onBack = {},
                            onForgotPassword = {},
                            onCreateAccount = {},
                            onShowMessage = {},
                            viewModel = viewModel,
                        )
                    }
                }
            }
        }

        val recovery = composeRule.onNodeWithText("Forgot password?")
        recovery.performScrollTo().assertIsDisplayed()
        val bounds = recovery.getUnclippedBoundsInRoot()
        assertTrue("Large-text recovery target height is under 48dp", bounds.bottom - bounds.top >= Spacing.MinTouchTarget)
    }

    @Test
    fun recovery_action_stays_disabled_during_sign_in() {
        val pending = CompletableDeferred<GoogleSignInResult>()
        val googleClient = mockk<GoogleSignInClient>()
        coEvery { googleClient.signIn(any()) } coAnswers { pending.await() }
        val repository = FakeAuthRepository()
        val viewModel = SignInViewModel(repository, googleClient)
        var recoveryCalls = 0
        composeRule.setContent {
            EquipSevaTheme {
                SignInScreen(
                    onBack = {},
                    onForgotPassword = { recoveryCalls++ },
                    onCreateAccount = {},
                    onShowMessage = {},
                    viewModel = viewModel,
                )
            }
        }

        viewModel.onGoogleClicked(ApplicationProvider.getApplicationContext())
        composeRule.waitForIdle()
        composeRule.onNodeWithText("Forgot password?").assertIsNotEnabled()
        assertEquals(0, recoveryCalls)
        assertTrue(repository.googleCalls.isEmpty())
        pending.complete(GoogleSignInResult.Cancelled)
        composeRule.waitForIdle()
    }
}
