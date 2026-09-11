package com.equipseva.app.navigation

import android.app.Application
import android.content.Context
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.R
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.testing.IsolatedUiPackageParser
import com.equipseva.app.testing.IsolatedUiTestRunner
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config

/** Actual recovery controls without production providers, repositories or Hilt. */
@RunWith(IsolatedUiTestRunner::class)
@OptIn(androidx.compose.ui.test.ExperimentalTestApi::class)
@Config(application = Application::class, sdk = [34], shadows = [IsolatedUiPackageParser::class],
    qualifiers = "en-rUS-w360dp-h800dp-mdpi")
class SessionRecoveryScreenUiTest {
    @get:Rule val compose = createEmptyComposeRule()
    private lateinit var controller: ActivityController<ComponentActivity>
    private val context: Context get() = ApplicationProvider.getApplicationContext()
    private val ui = mutableStateOf(RecoveryUi())
    private val calls = mutableListOf<String>()

    private data class RecoveryUi(
        val loading: Boolean = false,
        val signingOut: Boolean = false,
        val canSignOut: Boolean = true,
    )

    @Before fun startEmptyHost() {
        IsolatedUiPackageParser.assertIsolated(ApplicationProvider.getApplicationContext())
        controller = Robolectric.buildActivity(ComponentActivity::class.java).setup().visible()
    }

    @After fun closeEmptyHost() {
        if (::controller.isInitialized) controller.pause().stop().destroy()
    }

    @Test fun `signing out takes message priority and disables retry and exit`() {
        ui.value = RecoveryUi(loading = true, signingOut = true)
        render()

        node(R.string.root_session_signing_out).assertIsDisplayed()
        node(R.string.root_session_preparing).assertDoesNotExist()
        node(R.string.root_session_retry_message).assertDoesNotExist()
        node(R.string.root_session_retry).assertIsDisplayed().assertIsNotEnabled()
        node(R.string.root_session_sign_out).assertIsDisplayed().assertIsNotEnabled()
        assertEquals(emptyList<String>(), calls)
    }

    @Test fun `failure offers retry and exit while profile loading keeps only exit enabled`() {
        render()
        node(R.string.root_session_retry_message).assertIsDisplayed()
        node(R.string.root_session_retry).assertIsEnabled().performClick()
        node(R.string.root_session_sign_out).assertIsEnabled().performClick()
        assertEquals(listOf("retry", "sign-out"), calls)

        compose.runOnIdle { ui.value = ui.value.copy(loading = true) }
        node(R.string.root_session_preparing).assertIsDisplayed()
        node(R.string.root_session_retry_message).assertDoesNotExist()
        node(R.string.root_session_retry).assertIsNotEnabled()
        node(R.string.root_session_sign_out).assertIsEnabled().performClick()
        assertEquals(listOf("retry", "sign-out", "sign-out"), calls)

        compose.runOnIdle { ui.value = ui.value.copy(canSignOut = false) }
        node(R.string.root_session_sign_out).assertDoesNotExist()
    }

    private fun render() {
        controller.get().setContent {
            EquipSevaTheme(darkTheme = false) {
                SessionRecoveryScreen(
                    loading = ui.value.loading,
                    signingOut = ui.value.signingOut,
                    canSignOut = ui.value.canSignOut,
                    onRetry = { calls += "retry" },
                    onSignOut = { calls += "sign-out" },
                )
            }
        }
        compose.waitForIdle()
    }

    private fun node(id: Int) = compose.onNodeWithText(context.getString(id))
}
