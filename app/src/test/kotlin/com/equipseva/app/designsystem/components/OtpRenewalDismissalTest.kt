package com.equipseva.app.designsystem.components

import android.app.Application
import android.app.Dialog
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.SystemClock
import android.view.InputDevice
import android.view.MotionEvent
import android.view.View
import android.window.BackEvent
import android.window.OnBackAnimationCallback
import android.window.OnBackInvokedCallback
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.ViewRootForTest
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.test.core.app.ApplicationProvider
import androidx.test.filters.SdkSuppress
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.features.kyc.EmailVerifySheet
import com.equipseva.app.testing.IsolatedUiPackageParser
import com.equipseva.app.testing.IsolatedUiTestRunner
import java.io.File
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RuntimeEnvironment
import org.robolectric.android.controller.ActivityController
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadows.ShadowApplication
import org.robolectric.shadows.ShadowDialog
import org.robolectric.shadows.ShadowWindowManagerGlobal
import org.robolectric.util.ReflectionHelpers

/**
 * Synthetic actual-dialog dismissal tests; never invokes the application dismiss lambda.
 * Resolved source consulted when drafting (not fetched during test execution):
 * - M3 1.3.1 common ModalBottomSheet.kt: Scrim, draggable, paneTitle, hide-on-Back.
 *   https://dl.google.com/dl/android/maven2/androidx/compose/material3/material3-android/1.3.1/material3-android-1.3.1-sources.jar
 * - Robolectric 4.16.1 ShadowApplication.setEnableOnBackInvokedCallback and reset policy.
 *   https://repo.maven.apache.org/maven2/org/robolectric/shadows-framework/4.16.1/shadows-framework-4.16.1-sources.jar
 * - Robolectric 4.16.1 ShadowWindowManagerGlobal.startPredictiveBackGesture dispatches
 *   the platform-registered callback through its window-session binder, with cancel/commit.
 *   https://raw.githubusercontent.com/robolectric/robolectric/robolectric-4.16.1/shadows/framework/src/main/java/org/robolectric/shadows/ShadowWindowManagerGlobal.java
 * - Resolved Android14 View.findOnBackInvokedDispatcher returns its attached window's
 *   dispatcher; Dialog.onBackInvokedDispatcher instead returns a proxy with no getTopCallback.
 *
 * Reflection only inspects the real attached dispatcher and snapshots opt-in flags. The
 * public Robolectric gesture API performs delivery; no application callback is invoked
 * by the test. API34 platform callback lifecycle is tested, not OEM recognition/animation.
 */
@RunWith(IsolatedUiTestRunner::class)
@Config(application = Application::class, sdk = [34], shadows = [IsolatedUiPackageParser::class],
    qualifiers = "en-rUS-w360dp-h800dp-mdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@OptIn(ExperimentalTestApi::class)
@SdkSuppress(minSdkVersion = 34)
class OtpRenewalDismissalTest {
    @get:Rule val compose = createEmptyComposeRule()
    private lateinit var host: ActivityController<ComponentActivity>
    private lateinit var dialog: Dialog
    private lateinit var modalView: View
    private var activityView: View? = null
    private var initialFontScale = 1f
    private var originalAppBack = false
    private var originalPlatformBack = false
    private var backSnapshotTaken = false
    private lateinit var report: String
    private val showing = mutableStateOf(true)
    private val verifying = mutableStateOf(false)
    private val code = mutableStateOf("001234")
    private var dismissals = 0
    private var submissions = 0
    private var resends = 0
    private val editable = SemanticsMatcher.keyIsDefined(SemanticsProperties.EditableText)
    private val pane = SemanticsMatcher.keyIsDefined(SemanticsProperties.PaneTitle)
    private val app: Application get() = ApplicationProvider.getApplicationContext()

    @Before fun isolate() {
        IsolatedUiPackageParser.assertIsolated(app)
        initialFontScale = RuntimeEnvironment.getFontScale()
        originalAppBack = ReflectionHelpers.callInstanceMethod(app.applicationInfo, "isOnBackInvokedCallbackEnabled")
        originalPlatformBack = ReflectionHelpers.getStaticField(dispatcherClass(), "ENABLE_PREDICTIVE_BACK")
        backSnapshotTaken = true
    }

    @After fun tearDown() {
        try {
            if (::modalView.isInitialized) modalView.rootView.dispatchWindowFocusChanged(false)
            if (::host.isInitialized) {
                host.get().window.decorView.dispatchWindowFocusChanged(true)
                host.pause().stop().destroy()
            }
        } finally {
            RuntimeEnvironment.setFontScale(initialFontScale)
            if (backSnapshotTaken) {
                // The helper modifies both application opt-in and platform switch. Restore
                // each exact prior value, including the case where they initially differed.
                ShadowApplication.setEnableOnBackInvokedCallback(originalAppBack)
                ReflectionHelpers.setStaticField(dispatcherClass(), "ENABLE_PREDICTIVE_BACK", originalPlatformBack)
            }
        }
    }

    @Test fun `physical scrim tap retains verifying sheet and dismisses the same ready sheet`() {
        open("scrim")
        assertVisible("initial-ready")
        compose.runOnIdle { verifying.value = true }
        val settledBusyPane = assertVisible("busy-before-tap")
        scrimTap()
        assertPaneRestored(settledBusyPane, "busy-after-tap")
        compose.runOnIdle { verifying.value = false }
        assertVisible("ready-before-tap")
        scrimTap()
        assertDismissed("ready-after-tap")
    }

    @Test fun `physical downward drag settles back while verifying and dismisses once ready`() {
        open("drag")
        assertVisible("initial-ready")
        compose.runOnIdle { verifying.value = true }
        val settledBusyPane = assertVisible("busy-before-drag")
        dragDown()
        assertPaneRestored(settledBusyPane, "busy-after-drag")
        compose.runOnIdle { verifying.value = false }
        assertVisible("ready-before-drag")
        dragDown()
        assertDismissed("ready-after-drag")
    }

    @Test fun `API34 registered predictive back callback cancels safely and obeys current verifying state`() {
        open("predictive-api34", predictive = true)
        assertVisible("initial-ready")
        compose.runOnIdle { verifying.value = true }
        val settledBusyPane = assertVisible("busy-before-back")
        predictiveBack(cancel = true)
        assertPaneRestored(settledBusyPane, "busy-after-cancel")
        predictiveBack(cancel = false)
        assertPaneRestored(settledBusyPane, "busy-after-commit")
        compose.runOnIdle { verifying.value = false }
        val settledReadyPane = assertVisible("ready-before-back")
        predictiveBack(cancel = true)
        assertPaneRestored(settledReadyPane, "ready-after-cancel")
        predictiveBack(cancel = false)
        assertDismissed("ready-after-commit")
    }

    private fun open(name: String, predictive: Boolean = false) {
        report = name
        output("$report.tsv").writeText("Native synthetic dialog; API34/M3 1.3.2/Robolectric 4.16.1; not a device/provider test\n")
        RuntimeEnvironment.setFontScale(1f)
        if (predictive) {
            ShadowApplication.setEnableOnBackInvokedCallback(true)
            val appEnabled = ReflectionHelpers.callInstanceMethod<Boolean>(app.applicationInfo, "isOnBackInvokedCallbackEnabled")
            val platformEnabled = ReflectionHelpers.getStaticField<Boolean>(dispatcherClass(), "ENABLE_PREDICTIVE_BACK")
            assertTrue("Predictive test application must be explicitly opted in", appEnabled)
            assertTrue("Predictive platform path must be enabled", platformEnabled)
            record("predictive-setup\toldApp=$originalAppBack\toldPlatform=$originalPlatformBack\tcurrentApp=$appEnabled\tcurrentPlatform=$platformEnabled")
        }
        host = Robolectric.buildActivity(ComponentActivity::class.java).setup().visible()
        host.get().setContent {
            activityView = LocalView.current
            EquipSevaTheme(darkTheme = false) {
                if (showing.value) {
                    EmailVerifySheet("qa.synthetic@example.invalid", code.value, false, verifying.value,
                        { code.value = it }, { submissions++ },
                        { dismissals++; showing.value = false }, { resends++ })
                }
            }
        }
        settle()
        dialog = requireNotNull(ShadowDialog.getLatestDialog()) { "Production sheet must create a native Dialog" }
        modalView = ownerView()
        assertNotSame("Actual dialog content is not the activity Compose view", activityView, modalView)
        assertNotSame("Actual dialog owns a separate Android window", host.get().window.decorView, modalView.rootView)
        assertSame("Captured modal is in the actual Dialog window", dialog.window!!.decorView, modalView.rootView)
        compose.runOnIdle {
            host.get().window.decorView.dispatchWindowFocusChanged(false)
            modalView.rootView.dispatchWindowFocusChanged(true)
        }
        record("window\tdialog=${dialog.javaClass.name}\tview=${modalView.javaClass.name}\twidth=${modalView.width}\theight=${modalView.height}")
    }

    private fun assertVisible(stage: String): Rect {
        settle()
        capture(stage)
        compose.onNode(editable).assertIsDisplayed().assertTextContains("001234")
        val area = paneBounds()
        assertTrue("A visible sheet occupies this modal viewport: $stage",
            area.width > 0 && area.height > 0 && area.top < modalView.height && area.bottom > 0)
        compose.runOnIdle {
            assertTrue("Actual dialog remains showing: $stage", dialog.isShowing)
            assertSame("Busy changes must not swap the Dialog", dialog, ShadowDialog.getLatestDialog())
            assertEquals(0, dismissals)
            assertTrue(showing.value)
            assertEquals("001234", code.value)
            assertEquals(0, submissions)
            assertEquals(0, resends)
            assertFalse("A dialog gesture must not finish its host", host.get().isFinishing)
        }
        assertSame("Busy changes retain the same native owner", modalView, ownerView())
        val clipped = compose.onNode(pane).fetchSemanticsNode().boundsInRoot
        record("$stage\tverifying=${verifying.value}\tpaneUnclipped=$area\tpaneClipped=$clipped\tdismissals=$dismissals\tdialogShowing=${dialog.isShowing}")
        return area
    }

    private fun assertPaneRestored(beforeGesture: Rect, stage: String) {
        val afterGesture = assertVisible(stage)
        // Retain the settled pre-gesture rectangle: a new or viewport-clipped baseline
        // could hide a partly displaced sheet and make a blocked dismissal falsely pass.
        record("$stage-geometry\texpected=$beforeGesture\tactual=$afterGesture\tphysicalPixelTolerance=1")
        assertEquals("Unclipped pane left restored: $stage", beforeGesture.left, afterGesture.left, 1f)
        assertEquals("Unclipped pane top restored: $stage", beforeGesture.top, afterGesture.top, 1f)
        assertEquals("Unclipped pane right restored: $stage", beforeGesture.right, afterGesture.right, 1f)
        assertEquals("Unclipped pane bottom restored: $stage", beforeGesture.bottom, afterGesture.bottom, 1f)
    }

    private fun assertDismissed(stage: String) {
        settle()
        capture(stage)
        compose.onAllNodes(editable).assertCountEquals(0)
        compose.runOnIdle {
            assertEquals("The ready positive control dismisses exactly once", 1, dismissals)
            assertFalse(showing.value)
            assertFalse("The native Dialog actually closes", dialog.isShowing)
            assertEquals("Gestures never edit the code", "001234", code.value)
            assertEquals(0, submissions)
            assertEquals(0, resends)
            assertFalse("Ready dialog dismissal must not finish its host", host.get().isFinishing)
        }
        record("$stage\tdismissals=$dismissals\tdialogShowing=${dialog.isShowing}")
    }

    private fun scrimTap() {
        val sheet = paneBounds()
        assertTrue("Scrim test requires a genuinely exposed area above the sheet", sheet.top >= 32f)
        val point = Offset(modalView.width / 2f, sheet.top / 2f)
        assertTrue(point.y > 0 && point.y < sheet.top - 8f)
        record("scrim-physical\tx=${point.x}\ty=${point.y}\tsheet=$sheet")
        nativeTouch(listOf(point, point), listOf(0L, 64L))
    }

    private fun dragDown() {
        val sheet = paneBounds()
        val start = Offset((sheet.left + sheet.right) / 2f, sheet.top + 12f)
        val end = Offset(start.x, modalView.height - 2f)
        assertTrue("Start lies on the sheet drag-handle area", start.y > sheet.top && start.y < sheet.bottom)
        assertTrue("Positive control travels most of the sheet's hide distance", end.y - start.y > sheet.height * 0.6f)
        val points = (0..14).map { index ->
            Offset(start.x, start.y + (end.y - start.y) * index / 14f)
        }
        record("drag-physical\tstart=$start\tend=$end\tsheet=$sheet\tsteps=${points.size}")
        nativeTouch(points, points.indices.map { it * 16L })
    }

    /** MotionEvents target the measured native modal view, not a semantics click/dismiss action. */
    private fun nativeTouch(points: List<Offset>, offsets: List<Long>) {
        require(points.size >= 2 && points.size == offsets.size)
        val downTime = compose.runOnIdle { SystemClock.uptimeMillis() }
        points.forEachIndexed { index, point ->
            val action = when (index) {
                0 -> MotionEvent.ACTION_DOWN
                points.lastIndex -> MotionEvent.ACTION_UP
                else -> MotionEvent.ACTION_MOVE
            }
            val handled = compose.runOnIdle {
                val event = MotionEvent.obtain(downTime, downTime + offsets[index], action, point.x, point.y, 0)
                try {
                    event.source = InputDevice.SOURCE_TOUCHSCREEN
                    modalView.dispatchTouchEvent(event)
                } finally { event.recycle() }
            }
            record("touch\taction=$action\tx=${point.x}\ty=${point.y}\thandled=$handled")
            if (index == 0 || index == points.lastIndex) assertTrue("Native modal must receive the gesture endpoints", handled)
            if (index < points.lastIndex) compose.mainClock.advanceTimeBy(offsets[index + 1] - offsets[index])
        }
        settle()
    }

    private fun predictiveBack(cancel: Boolean) {
        compose.runOnIdle {
            // The Dialog API returns a ProxyOnBackInvokedDispatcher. Inspect the real
            // dispatcher attached to the measured modal View instead of the proxy.
            val dispatcher = requireNotNull(modalView.findOnBackInvokedDispatcher()) {
                "The attached native modal must own a platform Back dispatcher"
            }
            assertTrue("Resolve the attached window dispatcher", dispatcherClass().isInstance(dispatcher))
            assertNotSame("The modal and activity have distinct attached dispatchers",
                host.get().window.decorView.findOnBackInvokedDispatcher(), dispatcher)
            val top = ReflectionHelpers.callInstanceMethod<OnBackInvokedCallback?>(dispatcher, "getTopCallback")
            assertNotNull("An actual callback must already be registered by production UI", top)
            assertTrue("API34 predictive lifecycle requires a real animation callback", top is OnBackAnimationCallback)
            record("predictive\tdispatcher=${dispatcher.javaClass.name}\tcallback=${top!!.javaClass.name}\tcancel=$cancel")
        }
        val gesture = compose.runOnIdle {
            requireNotNull(ShadowWindowManagerGlobal.startPredictiveBackGesture(BackEvent.EDGE_LEFT)) {
                "A real animation-capable callback must be registered; null is not a passing gesture"
            }
        }
        try {
            compose.mainClock.advanceTimeByFrame()
            compose.runOnIdle { gesture.moveBy(modalView.width * 0.5f, 0f) }
            compose.mainClock.advanceTimeByFrame()
            if (cancel) compose.runOnIdle { gesture.cancel() }
        } finally {
            // close commits an active gesture, or only releases an already cancelled one.
            compose.runOnIdle { gesture.close() }
        }
        settle()
    }

    private fun ownerView() = (compose.onNode(editable).fetchSemanticsNode().root as ViewRootForTest).view
    private fun paneBounds(): Rect {
        compose.onAllNodes(pane).assertCountEquals(1)
        val area = compose.onNode(pane).getUnclippedBoundsInRoot()
        val density = modalView.resources.displayMetrics.density
        return Rect(area.left.value * density, area.top.value * density,
            area.right.value * density, area.bottom.value * density)
    }
    private fun settle() { compose.mainClock.advanceTimeBy(900); compose.waitForIdle() }
    private fun dispatcherClass() = Class.forName("android.window.WindowOnBackInvokedDispatcher")
    private fun capture(stage: String) {
        compose.runOnIdle {
            if (modalView.width <= 0 || modalView.height <= 0) {
                record("capture-$stage\tno-sized-modal-view\twidth=${modalView.width}\theight=${modalView.height}")
                return@runOnIdle
            }
            val bitmap = Bitmap.createBitmap(modalView.width, modalView.height, Bitmap.Config.ARGB_8888)
            try {
                modalView.draw(Canvas(bitmap))
                output("$report-$stage.png").outputStream().use { check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) }
            } finally { bitmap.recycle() }
        }
    }
    private fun record(line: String) { output("$report.tsv").appendText(line + "\n") }
    private fun output(name: String) = File("build/reports/otp-dismissal/$name").also { checkNotNull(it.parentFile).mkdirs() }
}
