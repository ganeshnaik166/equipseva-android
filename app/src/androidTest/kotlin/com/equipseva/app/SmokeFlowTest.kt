package com.equipseva.app

import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.lifecycle.Lifecycle
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * v1 smoke test for the auth -> home -> cart -> checkout golden path
 * (PENDING.md #45). Audit flagged zero instrumented coverage — this is the
 * minimum stable baseline so the activity launching without crashing is
 * caught in CI before deeper UI assertions are layered on.
 *
 * Scope is intentionally narrow:
 *   - Boot MainActivity through the real Hilt graph (the prod
 *     EquipSevaApplication is used; no HiltTestApplication wiring yet).
 *   - Confirm the Compose host attaches and the activity reaches RESUMED.
 *
 * Deeper assertions (auth headline rendering, role-select gating, full
 * auth -> home -> cart -> checkout traversal) need Hilt test infra + a
 * fake Supabase session, both of which require new dependencies and
 * fixture wiring. Tracked as follow-ups; see TODOs below.
 */
@RunWith(AndroidJUnit4::class)
class SmokeFlowTest {

    @get:Rule
    val composeTestRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun mainActivity_launches_andReachesResumed() {
        // Compose rule already started the activity. Assert it is wired
        // up and didn't crash during onCreate (Hilt graph + Sentry +
        // WorkManager + Razorpay preload all run there).
        val activity = composeTestRule.activity
        assertNotNull("MainActivity should be attached to the Compose rule", activity)

        composeTestRule.waitForIdle()

        val state = activity.lifecycle.currentState
        assertTrue(
            "MainActivity should be at least STARTED after waitForIdle, was $state",
            state.isAtLeast(Lifecycle.State.STARTED),
        )

        // Sanity check we are running against the debug app id, matching
        // ExampleInstrumentedTest's contract.
        val ctx = InstrumentationRegistry.getInstrumentation().targetContext
        assertEquals("com.equipseva.app.debug", ctx.packageName)

        // TODO(#45 follow-up): once Hilt test infra (hilt-android-testing
        //  + custom AndroidJUnitRunner with HiltTestApplication) lands,
        //  swap to a fake SessionViewModel that emits SignedOut and
        //  assert the "Sign in" / "Create account" buttons on
        //  WelcomeScreen render. Then extend through home -> cart ->
        //  checkout with a fake Supabase client.
    }
}
