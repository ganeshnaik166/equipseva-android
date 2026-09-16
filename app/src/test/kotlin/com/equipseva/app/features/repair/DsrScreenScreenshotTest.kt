package com.equipseva.app.features.repair

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
 * Pins the DSR screen's visual states against committed goldens. Renders
 * [DsrContent] straight from a hand-built [DsrViewModel.UiState] so no
 * Hilt graph or Supabase client is involved.
 *
 * Fixtures use fixed ISO timestamps: `prettyDate` renders an absolute
 * "dd MMM yyyy" in IST, so the captured text never depends on the clock.
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(application = android.app.Application::class, sdk = [35], qualifiers = RobolectricDeviceQualifiers.Pixel5)
class DsrScreenScreenshotTest {

    @get:Rule val composeRule = createComposeRule()

    private fun capture(name: String, content: @Composable () -> Unit) {
        composeRule.setContent { EquipSevaTheme(darkTheme = false) { content() } }
        composeRule.onRoot().captureRoboImage("screens/DsrScreen_" + name + ".png")
    }

    @Composable
    private fun Fixture(state: DsrViewModel.UiState, isHospital: Boolean) {
        DsrContent(
            state = state,
            isHospital = isHospital,
            onRefresh = {},
            onSubmit = { _, _, _, _, _, _, _ -> },
            onSign = { _, _ -> },
            onBack = {},
        )
    }

    @Test fun loading() = capture("loading") {
        Fixture(
            state = DsrViewModel.UiState(loading = true, dsr = null),
            isHospital = false,
        )
    }

    // Hospital side with no report filed yet: the "nothing to sign" empty
    // state. (The engineer side of the same UiState is the filing form.)
    @Test fun empty() = capture("empty") {
        Fixture(
            state = DsrViewModel.UiState(loading = false, dsr = null),
            isHospital = true,
        )
    }

    @Test fun error() = capture("error") {
        Fixture(
            state = DsrViewModel.UiState(
                loading = false,
                error = "Couldn't reach the server. Check your connection and try again.",
                dsr = null,
            ),
            isHospital = false,
        )
    }

    // Pending-signature record seen by the hospital: warn pill, a failed
    // calibration verdict next to two passing ones, and the sign-off block.
    @Test fun populated() = capture("populated") {
        Fixture(
            state = DsrViewModel.UiState(
                loading = false,
                dsr = DsrRepository.Dsr(
                    id = "DSR-00041",
                    status = DsrRepository.STATUS_PENDING_SIGN,
                    engineerSignatureAt = "2026-03-14T09:30:00Z",
                    hospitalSignatureAt = null,
                    iec62353Passed = true,
                    calibrationWithinOem = false,
                    workSummary = "Replaced the SpO2 sensor cable and re-seated the main board " +
                        "connector. Leakage current re-tested within limits after the swap.",
                    recommendations = "Schedule OEM recalibration of the NIBP module within 30 days.",
                    equipmentSerial = "PM-8000-7731-A",
                ),
            ),
            isHospital = true,
        )
    }
}
