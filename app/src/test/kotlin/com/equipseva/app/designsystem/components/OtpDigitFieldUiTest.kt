package com.equipseva.app.designsystem.components

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasSetTextAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.performTextInput
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * UI smoke for [OtpDigitField]. The visible boxes are decorative; a hidden
 * `BasicTextField` underneath captures input. Pin the two pieces of real
 * behaviour: (1) non-digit characters are filtered before they reach the
 * caller, and (2) the error message renders below the boxes when supplied
 * — both signals matter on the OTP-verify screen (auth flow).
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class OtpDigitFieldUiTest {

    @get:Rule val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `digit characters arrive on the onValueChange callback`() {
        var captured = ""
        composeRule.setContent {
            Themed {
                OtpDigitField(
                    value = "",
                    onValueChange = { captured = it },
                )
            }
        }
        composeRule.onNode(hasSetTextAction()).performTextInput("123")
        assertEquals("123", captured)
    }

    @Test fun `non-digit input is filtered before the callback fires`() {
        var captured = ""
        composeRule.setContent {
            Themed {
                OtpDigitField(
                    value = "",
                    onValueChange = { captured = it },
                )
            }
        }
        composeRule.onNode(hasSetTextAction()).performTextInput("12ab34")
        assertEquals("1234", captured)
    }

    @Test fun `input over length is truncated`() {
        var captured = ""
        composeRule.setContent {
            Themed {
                OtpDigitField(
                    value = "",
                    onValueChange = { captured = it },
                    length = 4,
                )
            }
        }
        composeRule.onNode(hasSetTextAction()).performTextInput("123456789")
        assertEquals("1234", captured)
    }

    @Test fun `error message renders when supplied`() {
        composeRule.setContent {
            Themed {
                OtpDigitField(
                    value = "12",
                    onValueChange = {},
                    error = "Wrong code, try again",
                )
            }
        }
        composeRule.onNode(hasText("Wrong code, try again")).assertIsDisplayed()
    }

    @Test fun `no error message node exists when error is null`() {
        composeRule.setContent {
            Themed {
                OtpDigitField(
                    value = "12",
                    onValueChange = {},
                    error = null,
                )
            }
        }
        composeRule.onAllNodes(hasText("Wrong code, try again")).assertCountEquals(0)
    }
}
