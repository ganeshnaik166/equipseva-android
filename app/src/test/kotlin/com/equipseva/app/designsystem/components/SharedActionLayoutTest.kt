package com.equipseva.app.designsystem.components

import android.app.Application
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.core.app.ApplicationProvider
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.testing.IsolatedUiPackageParser
import com.equipseva.app.testing.IsolatedUiTestRunner
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(IsolatedUiTestRunner::class)
@Config(application = Application::class, sdk = [34], shadows = [IsolatedUiPackageParser::class],
    qualifiers = "en-rUS-w320dp-h800dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@OptIn(ExperimentalTestApi::class)
class SharedActionLayoutTest {
    @get:Rule val compose = createEmptyComposeRule()
    private lateinit var host: ActivityController<ComponentActivity>
    @Before fun open() {
        IsolatedUiPackageParser.assertIsolated(ApplicationProvider.getApplicationContext())
        host = Robolectric.buildActivity(ComponentActivity::class.java).setup().visible()
    }
    @After fun close() { host.pause().stop().destroy() }

    @Test fun `primary controls have at least 52dp physical height`() {
        render {
            PrimaryButton("Main action", {})
            EsBtn("Legacy main", {}, full = true)
        }
        listOf("Main action", "Legacy main").forEach { compose.onNodeWithText(it).assertHeightIsAtLeast(52.dp) }
    }

    @Test fun `English long primary labels grow at twice text size`() = longLabels("Save equipment service request details")
    @Test @Config(qualifiers = "hi-rIN-w320dp-h800dp-mdpi")
    fun `Hindi long primary labels grow at twice text size`() = longLabels("उपकरण सेवा अनुरोध का विवरण सहेजें")
    @Test @Config(qualifiers = "te-rIN-w320dp-h800dp-mdpi")
    fun `Telugu long primary labels grow at twice text size`() = longLabels("పరికరాల సేవా అభ్యర్థన వివరాలను సేవ్ చేయండి")
    @Test fun `English long primary labels grow in dark mode`() = longLabels("Save equipment service request details", dark = true)
    @Test @Config(qualifiers = "hi-rIN-w320dp-h800dp-mdpi")
    fun `Hindi long primary labels grow in dark mode`() = longLabels("उपकरण सेवा अनुरोध का विवरण सहेजें", dark = true)
    @Test @Config(qualifiers = "te-rIN-w320dp-h800dp-mdpi")
    fun `Telugu long primary labels grow in dark mode`() = longLabels("పరికరాల సేవా అభ్యర్థన వివరాలను సేవ్ చేయండి", dark = true)
    @Test @Config(qualifiers = "te-rIN-w320dp-h800dp-mdpi")
    fun `loading spinner leaves space for a complete long Telugu label`() = longLabels("పరికరాల సేవా అభ్యర్థన వివరాలను సేవ్ చేయండి", loading = true)

    @Test @Config(qualifiers = "hi-rIN-w320dp-h800dp-mdpi")
    fun `Hindi loading status is localized`() = localizedLoading("लोड हो रहा है")
    @Test @Config(qualifiers = "te-rIN-w320dp-h800dp-mdpi")
    fun `Telugu loading status is localized`() = localizedLoading("లోడ్ అవుతోంది")

    @Test fun `loading and disabled controls never replay taps when reenabled`() {
        val loading = mutableStateOf(true)
        val disabled = mutableStateOf(true)
        var primaryCalls = 0
        var legacyCalls = 0
        render {
            PrimaryButton("Save changes", { primaryCalls++ }, loading = loading.value)
            EsBtn("Confirm changes", { legacyCalls++ }, disabled = disabled.value)
        }
        val primary = compose.onNodeWithText("Save changes")
        val legacy = compose.onNodeWithText("Confirm changes")
        primary.assertIsNotEnabled().performClick()
        legacy.assertIsNotEnabled().performClick()
        compose.runOnIdle { assertEquals(0, primaryCalls); assertEquals(0, legacyCalls) }
        primary.assert(SemanticsMatcher.keyIsDefined(SemanticsProperties.StateDescription))
        compose.runOnIdle { loading.value = false; disabled.value = false }
        compose.runOnIdle { assertEquals(0, primaryCalls); assertEquals(0, legacyCalls) }
        primary.assertIsEnabled().performClick()
        legacy.assertIsEnabled().performClick()
        compose.runOnIdle { assertEquals(1, primaryCalls); assertEquals(1, legacyCalls) }
    }

    @Test fun `every legacy action kind retains button semantics and minimum target`() {
        render {
            EsBtnKind.entries.forEach { kind -> EsBtn(kind.name, {}, kind = kind, size = EsBtnSize.Sm) }
        }
        EsBtnKind.entries.forEach { kind -> compose.onNodeWithText(kind.name).performScrollTo()
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button))
            .assertHeightIsAtLeast(48.dp).assertWidthIsAtLeast(48.dp) }
    }

    @Test fun `three compact payout actions remain reachable at twice text size`() =
        actionGroup(listOf("Cancel instead", "Close", "Mark paid"))

    @Test fun `three compact cancellation actions remain reachable at twice text size`() =
        actionGroup(listOf("Back to mark-paid", "Close", "Cancel payout"),
            listOf(EsBtnKind.Ghost, EsBtnKind.Secondary, EsBtnKind.Danger))

    @Test fun `compact copy pay and call actions wrap without losing callbacks`() =
        actionGroup(listOf("Copy", "Pay via UPI", "Call"),
            listOf(EsBtnKind.Secondary, EsBtnKind.Primary, EsBtnKind.Secondary))

    private fun actionGroup(labels: List<String>,
        kinds: List<EsBtnKind> = listOf(EsBtnKind.Ghost, EsBtnKind.Secondary, EsBtnKind.Primary)) {
        val calls = mutableListOf<String>()
        render(scale = 2f) {
            EsActionGroup {
                labels.zip(kinds).forEach { (label, kind) ->
                    EsBtn(label, { calls += label }, kind = kind)
                }
            }
        }
        labels.forEachIndexed { index, label ->
            val node = compose.onNodeWithText(label).performScrollTo().assertIsDisplayed()
                .assertHeightIsAtLeast(48.dp).assertWidthIsAtLeast(48.dp)
            val bounds = node.getUnclippedBoundsInRoot()
            val viewport = compose.onRoot().getUnclippedBoundsInRoot()
            assertTrue("Entire payout action remains inside viewport: $label", bounds.left >= viewport.left &&
                bounds.right <= viewport.right && bounds.top >= viewport.top && bounds.bottom <= viewport.bottom)
            val layouts = mutableListOf<TextLayoutResult>()
            compose.onNodeWithText(label, useUnmergedTree = true)
                .performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
            val layout = layouts.single()
            assertFalse(layout.didOverflowHeight)
            assertEquals(label.length, layout.getLineEnd(layout.lineCount - 1, visibleEnd = true))
            repeat(layout.lineCount) { line ->
                assertFalse(layout.isLineEllipsized(line))
                assertTrue(layout.getLineLeft(line) >= -1f)
                assertTrue(layout.getLineRight(line) <= layout.size.width + 1f)
            }
            node.performClick()
            compose.runOnIdle { assertEquals(labels.take(index + 1), calls) }
        }
    }

    private fun localizedLoading(expected: String) {
        render { PrimaryButton("Save", {}, loading = true) }
        compose.onNodeWithText("Save").assertIsNotEnabled()
            .assert(SemanticsMatcher.expectValue(SemanticsProperties.StateDescription, expected))
        compose.onAllNodes(SemanticsMatcher.expectValue(SemanticsProperties.Role, Role.Button)).assertCountEquals(1)
    }

    private fun longLabels(label: String, dark: Boolean = false, loading: Boolean = false) {
        val labels = listOf("1 $label", "2 $label")
        render(scale = 2f, dark = dark) {
            PrimaryButton(labels[0], {}, loading = loading)
            EsBtn(labels[1], {}, full = true,
                leading = { Icon(Icons.Default.Check, null, Modifier.testTag("leading")) },
                trailing = { Icon(Icons.Default.Check, null, Modifier.testTag("trailing")) })
        }
        labels.forEach { text ->
            val target = compose.onNodeWithText(text).performScrollTo().assertIsDisplayed().assertHeightIsAtLeast(52.dp)
            val layouts = mutableListOf<TextLayoutResult>()
            val textNode = compose.onNodeWithText(text, useUnmergedTree = true)
            textNode.performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
            val layout = layouts.single()
            assertFalse("Full growing label: $text", layout.didOverflowHeight)
            assertEquals(text.length, layout.getLineEnd(layout.lineCount - 1, visibleEnd = true))
            repeat(layout.lineCount) { line ->
                assertFalse(layout.isLineEllipsized(line))
                assertTrue(layout.getLineLeft(line) >= -1f)
                assertTrue(layout.getLineRight(line) <= layout.size.width + 1f)
            }
            val buttonBounds = target.getUnclippedBoundsInRoot()
            val textBounds = textNode.getUnclippedBoundsInRoot()
            assertTrue("12dp top padding", textBounds.top >= buttonBounds.top + 12.dp)
            assertTrue("12dp bottom padding", textBounds.bottom <= buttonBounds.bottom - 12.dp)
            assertTrue(textBounds.left >= buttonBounds.left && textBounds.right <= buttonBounds.right)
            val viewport = compose.onRoot().getUnclippedBoundsInRoot()
            assertTrue("Entire growing action is visible", buttonBounds.top >= viewport.top &&
                buttonBounds.bottom <= viewport.bottom && buttonBounds.left >= viewport.left && buttonBounds.right <= viewport.right)
            if (text == labels[1]) {
                val leading = compose.onNodeWithTag("leading", useUnmergedTree = true).getUnclippedBoundsInRoot()
                val trailing = compose.onNodeWithTag("trailing", useUnmergedTree = true).getUnclippedBoundsInRoot()
                assertTrue(leading.left >= buttonBounds.left && trailing.right <= buttonBounds.right)
                assertTrue(leading.top >= buttonBounds.top && leading.bottom <= buttonBounds.bottom)
                assertTrue(trailing.top >= buttonBounds.top && trailing.bottom <= buttonBounds.bottom)
                assertTrue("Icons must not overlap label", leading.right <= textBounds.left && trailing.left >= textBounds.right)
            }
        }
    }

    private fun render(scale: Float = 1f, dark: Boolean = false, content: @Composable () -> Unit) {
        host.get().setContent {
            EquipSevaTheme(darkTheme = dark) {
                val density = LocalDensity.current
                CompositionLocalProvider(LocalDensity provides Density(density.density, scale)) {
                    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp)) { content() }
                }
            }
        }
        compose.waitForIdle()
    }
}
