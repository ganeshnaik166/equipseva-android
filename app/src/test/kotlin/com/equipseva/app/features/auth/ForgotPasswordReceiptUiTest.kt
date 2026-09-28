package com.equipseva.app.features.auth

import android.app.Application
import android.content.res.Configuration
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextReplacement
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.R
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.testing.FakeAuthRepository
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.MutableStateFlow
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.util.Locale

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(application = android.app.Application::class, sdk = [35], qualifiers = RobolectricDeviceQualifiers.Pixel5)
class ForgotPasswordReceiptUiTest {
    @get:Rule val composeRule = createComposeRule()

    private fun sentViewModel(email: String): ForgotPasswordViewModel = mockk(relaxed = true) {
        every { state } returns MutableStateFlow(ForgotPasswordViewModel.UiState(email = email, sent = true))
    }

    @Test fun success_receipt_is_neutral_and_does_not_expose_the_entered_email() {
        val email = "private.person@example.com"
        val viewModel = sentViewModel(email)
        composeRule.setContent {
            EquipSevaTheme { ForgotPasswordScreen(onBack = {}, viewModel = viewModel) }
        }

        composeRule.onNodeWithText("Request received").assertIsDisplayed()
        composeRule.onNodeWithText("If an account exists", substring = true).assertIsDisplayed()
        composeRule.onAllNodesWithText(email, substring = true).assertCountEquals(0)
        composeRule.onAllNodesWithText("We've sent", substring = true).assertCountEquals(0)
        composeRule.onAllNodesWithContentDescription("Email sent").assertCountEquals(0)
    }

    @Test fun edit_email_restores_the_retained_form_without_resending_until_explicit_submit() {
        var backs = 0
        val fake = FakeAuthRepository()
        val viewModel = ForgotPasswordViewModel(fake)
        composeRule.setContent {
            EquipSevaTheme { ForgotPasswordScreen(onBack = { backs++ }, viewModel = viewModel) }
        }

        composeRule.runOnIdle {
            viewModel.onEmailChange("mistyped@example.com")
            viewModel.onSubmit()
        }
        composeRule.waitUntil(5_000) { viewModel.state.value.sent }
        assertEquals(listOf("mistyped@example.com"), fake.resetEmails)

        val edit = composeRule.onNodeWithText("Edit email").performScrollTo()
        edit.assertHasClickAction()
        edit.assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button))
        val bounds = edit.getUnclippedBoundsInRoot()
        assertTrue("Edit email target is shorter than 48dp", bounds.bottom - bounds.top >= Spacing.MinTouchTarget)
        edit.performClick()
        assertEquals(0, backs)
        assertEquals(false, viewModel.state.value.sent)
        assertEquals(listOf("mistyped@example.com"), fake.resetEmails)
        composeRule.onNodeWithText("mistyped@example.com").performScrollTo()
            .performTextReplacement("corrected@example.com")
        assertEquals("corrected@example.com", viewModel.state.value.email)
        assertEquals(listOf("mistyped@example.com"), fake.resetEmails)

        composeRule.onNodeWithText("Send reset link").performScrollTo().performClick()
        composeRule.waitUntil(5_000) { viewModel.state.value.sent }
        assertEquals(listOf("mistyped@example.com", "corrected@example.com"), fake.resetEmails)
    }

    @Test fun receipt_strings_remain_english_under_hindi_and_telugu_device_locales() {
        val app = ApplicationProvider.getApplicationContext<Application>()
        val ids = listOf(
            R.string.forgot_password_email_instructions,
            R.string.forgot_password_request_received,
            R.string.forgot_password_receipt_description,
            R.string.forgot_password_edit_email,
        )
        for (language in listOf("hi", "te")) {
            val config = Configuration(app.resources.configuration).apply {
                setLocale(Locale.forLanguageTag(language))
            }
            val localized = app.createConfigurationContext(config)
            for (id in ids) assertEquals(app.getString(id), localized.getString(id))
        }
    }

    @Test fun compact_double_text_receipt_keeps_both_actions_reachable() {
        var backs = 0
        val viewModel = sentViewModel("private.person@example.com")
        composeRule.setContent {
            CompositionLocalProvider(LocalDensity provides Density(density = 1f, fontScale = 2f)) {
                Box(Modifier.size(width = 320.dp, height = 420.dp)) {
                    EquipSevaTheme { ForgotPasswordScreen(onBack = { backs++ }, viewModel = viewModel) }
                }
            }
        }

        val edit = composeRule.onNodeWithText("Edit email").performScrollTo().assertIsDisplayed()
        val editBounds = edit.getUnclippedBoundsInRoot()
        assertTrue("Edit target is shorter than 48dp at 200% text", editBounds.bottom - editBounds.top >= Spacing.MinTouchTarget)
        composeRule.onNodeWithText("Back to sign in").performScrollTo().assertIsDisplayed().performClick()
        assertEquals(1, backs)
    }
}
