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
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.features.auth.state.AuthEffect
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.emptyFlow
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
class SignUpFooterTargetTest {
    @get:Rule val composeRule = createComposeRule()

    private fun signUpViewModel(): SignUpViewModel = mockk(relaxed = true) {
        every { state } returns MutableStateFlow(SignUpViewModel.UiState())
        every { effects } returns emptyFlow<AuthEffect>()
    }

    @Test
    fun sign_in_footer_has_a_real_48dp_action_target_and_button_role() {
        val viewModel = signUpViewModel()
        composeRule.setContent {
            EquipSevaTheme {
                SignUpScreen(onShowMessage = {}, onSignIn = {}, viewModel = viewModel)
            }
        }

        val signIn = composeRule.onNodeWithText("Sign in").performScrollTo()
        signIn.assertHasClickAction()
        val bounds = signIn.getUnclippedBoundsInRoot()
        assertTrue(
            "Sign in layout target is shorter than 48dp",
            bounds.bottom - bounds.top >= Spacing.MinTouchTarget,
        )
        signIn.assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button))
    }

    @Test
    fun sign_in_footer_dispatches_once_without_using_the_back_action() {
        var signIns = 0
        var backs = 0
        val viewModel = signUpViewModel()
        composeRule.setContent {
            EquipSevaTheme {
                SignUpScreen(
                    onShowMessage = {},
                    onBack = { backs++ },
                    onSignIn = { signIns++ },
                    viewModel = viewModel,
                )
            }
        }

        composeRule.onNodeWithText("Sign in").performScrollTo().performClick()
        assertEquals(1, signIns)
        assertEquals(0, backs)
    }

    @Test
    fun compact_screen_at_double_font_scale_keeps_sign_in_reachable() {
        var signIns = 0
        val viewModel = signUpViewModel()
        composeRule.setContent {
            CompositionLocalProvider(LocalDensity provides Density(density = 1f, fontScale = 2f)) {
                Box(Modifier.size(width = 320.dp, height = 420.dp)) {
                    EquipSevaTheme {
                        SignUpScreen(
                            onShowMessage = {},
                            onSignIn = { signIns++ },
                            viewModel = viewModel,
                        )
                    }
                }
            }
        }

        val signIn = composeRule.onNodeWithText("Sign in").performScrollTo().assertIsDisplayed()
        val bounds = signIn.getUnclippedBoundsInRoot()
        assertTrue(
            "Sign in layout target is shorter than 48dp at 200% font scale",
            bounds.bottom - bounds.top >= Spacing.MinTouchTarget,
        )
        signIn.performClick()
        assertEquals(1, signIns)
    }
}
