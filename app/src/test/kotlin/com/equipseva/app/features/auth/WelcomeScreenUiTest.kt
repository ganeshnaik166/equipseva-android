package com.equipseva.app.features.auth

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
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
class WelcomeScreenUiTest {
    @get:Rule val composeRule = createComposeRule()

    @Test
    fun primary_actions_keep_separate_callbacks() {
        var signIns = 0
        var signUps = 0
        composeRule.setContent {
            EquipSevaTheme {
                WelcomeScreen(onSignIn = { signIns++ }, onSignUp = { signUps++ })
            }
        }

        composeRule.onNodeWithText("Sign in").performClick()
        composeRule.onNodeWithText("Create account").performClick()
        assertEquals(1, signIns)
        assertEquals(1, signUps)
    }

    @Test
    fun terms_and_privacy_have_independent_accessible_targets() {
        composeRule.setContent {
            EquipSevaTheme { WelcomeScreen(onSignIn = {}, onSignUp = {}) }
        }

        listOf("Terms", "Privacy").forEach { label ->
            val action = composeRule.onNodeWithText(label)
            action.assertHasClickAction()
            val bounds = action.getUnclippedBoundsInRoot()
            assertTrue("$label target is under 48dp", bounds.bottom - bounds.top >= 48.dp)
        }
    }

    @Test
    fun legal_actions_dispatch_only_their_own_callbacks() {
        var terms = 0
        var privacy = 0
        composeRule.setContent {
            EquipSevaTheme {
                WelcomeContent(
                    onSignIn = {},
                    onSignUp = {},
                    onTerms = { terms++ },
                    onPrivacy = { privacy++ },
                )
            }
        }

        composeRule.onNodeWithText("Terms").performClick()
        assertEquals(1, terms)
        assertEquals(0, privacy)
        composeRule.onNodeWithText("Privacy").performClick()
        assertEquals(1, terms)
        assertEquals(1, privacy)
    }

    @Test
    fun narrow_screen_at_double_font_scale_can_scroll_to_every_action() {
        composeRule.setContent {
            CompositionLocalProvider(LocalDensity provides Density(density = 1f, fontScale = 2f)) {
                Box(Modifier.size(width = 320.dp, height = 420.dp)) {
                    EquipSevaTheme {
                        WelcomeScreen(onSignIn = {}, onSignUp = {})
                    }
                }
            }
        }

        composeRule.onNodeWithText("Sign in").assertIsDisplayed()
        listOf("Sign in", "Create account", "Terms", "Privacy").forEach { label ->
            composeRule.onNodeWithText(label).performScrollTo().assertIsDisplayed()
        }
    }

    @Test
    fun brand_logo_does_not_repeat_the_adjacent_title_for_screen_readers() {
        composeRule.setContent {
            EquipSevaTheme { WelcomeScreen(onSignIn = {}, onSignUp = {}) }
        }

        composeRule.onNodeWithText("EquipSeva").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("EquipSeva").assertDoesNotExist()
    }
}
