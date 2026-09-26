package com.equipseva.app.designsystem

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertWidthIsEqualTo
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.dp
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Pins [Modifier.maxContentWidth] against modifier-order regression.
 *
 * The cap was a no-op for as long as it existed: `fillMaxWidth()` fixed the
 * incoming constraints to the parent width and the following
 * `widthIn(max = 840.dp)` — which enforces incoming constraints — was coerced
 * straight back to it. On a tablet, content still spanned the full window,
 * which is exactly what the modifier exists to prevent. The ordering is the
 * whole behaviour here, so only a real measure pass can pin it.
 */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class MaxContentWidthTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Test
    @Config(qualifiers = "w1000dp-h800dp-mdpi")
    fun `expanded window caps content at ContentMaxWidth`() {
        composeRule.setContent {
            Box(Modifier.fillMaxSize()) {
                Box(Modifier.maxContentWidth().height(24.dp).testTag("capped"))
            }
        }
        composeRule.onNodeWithTag("capped").assertWidthIsEqualTo(ContentMaxWidth)
    }

    @Test
    @Config(qualifiers = "w720dp-h800dp-mdpi")
    fun `medium window is also capped`() {
        // Medium is the foldable-unfolded bucket; it is under the cap, so the
        // observable result is "fills the window" — but via the capped branch,
        // which is what makes the 840dp assertion above meaningful.
        composeRule.setContent {
            Box(Modifier.fillMaxSize()) {
                Box(Modifier.maxContentWidth().height(24.dp).testTag("capped"))
            }
        }
        val rootBounds = composeRule.onRoot().getUnclippedBoundsInRoot()
        val rootWidth = rootBounds.right - rootBounds.left
        composeRule.onNodeWithTag("capped").assertWidthIsEqualTo(rootWidth)
    }

    @Test
    @Config(qualifiers = "w411dp-h800dp-mdpi")
    fun `phone window fills the full width uncapped`() {
        composeRule.setContent {
            Box(Modifier.fillMaxSize()) {
                Box(Modifier.maxContentWidth().height(24.dp).testTag("capped"))
            }
        }
        val rootBounds = composeRule.onRoot().getUnclippedBoundsInRoot()
        val rootWidth = rootBounds.right - rootBounds.left
        composeRule.onNodeWithTag("capped").assertWidthIsEqualTo(rootWidth)
    }
}
