package com.equipseva.app.features.hospital

import androidx.compose.runtime.Composable
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.github.takahirom.roborazzi.RobolectricDeviceQualifiers
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Pins the two visual states of the post-submit confirmation as
 * Roborazzi goldens. The screen is already stateless (no ViewModel,
 * no effects), so it renders directly with fixed inputs.
 *
 * The body line is the only input-dependent surface: a job number
 * produces the bold "Job RPR-xxxxx is live" sentence, its absence
 * falls back to the generic string resource. Nothing on the screen
 * reads the clock, so both goldens are stable across days.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(application = android.app.Application::class, sdk = [35], qualifiers = RobolectricDeviceQualifiers.Pixel5)
class RequestSentScreenScreenshotTest {

    @get:Rule
    val composeRule = createComposeRule()

    private fun capture(name: String, content: @Composable () -> Unit) {
        composeRule.setContent { EquipSevaTheme(darkTheme = false) { content() } }
        composeRule.onRoot().captureRoboImage("screens/RequestSentScreen_" + name + ".png")
    }

    @Test
    fun with_job_number() = capture("with_job_number") {
        RequestSentScreen(
            jobNumber = "RPR-00041",
            onViewJob = {},
            onBackHome = {},
        )
    }

    @Test
    fun no_job_number() = capture("no_job_number") {
        RequestSentScreen(
            jobNumber = null,
            onViewJob = {},
            onBackHome = {},
        )
    }
}
