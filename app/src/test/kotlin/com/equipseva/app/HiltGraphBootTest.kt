package com.equipseva.app

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import dagger.hilt.android.testing.HiltTestApplication
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import javax.inject.Inject

/**
 * Phase 2 of the SmokeFlowTest follow-up (PR #255):
 *
 * Boots the full Hilt object graph against [HiltTestApplication] on the
 * JVM via Robolectric. No emulator, no Compose, no Supabase — just
 * verifies the Hilt graph can construct in the test environment so
 * follow-up tests can layer ViewModel injection + fake-Supabase swaps
 * on top without re-debugging the boot.
 *
 * The test class injects a single field: [@ApplicationContext Context].
 * Hilt's resolver walks the graph from this entry point only — nothing
 * in the path requires a real SupabaseClient, so the boot completes
 * cleanly. ViewModels that DO depend on SupabaseClient should bind a
 * fake via [@TestInstallIn] in the same test source set; this skeleton
 * exists so that scaffolding has a working baseline to copy from.
 *
 * Pattern documented for follow-up:
 *   * `@HiltAndroidTest` on the class.
 *   * `@RunWith(RobolectricTestRunner::class)`.
 *   * `@Config(application = HiltTestApplication::class)` so Robolectric
 *     uses the Hilt-aware test Application instead of the prod
 *     [EquipSevaApplication] (which would boot the real Hilt graph
 *     including the real SupabaseClient that can't initialise here).
 *   * `@get:Rule val hiltRule = HiltAndroidRule(this)` + `hiltRule.inject()`
 *     in `@Before` to trigger field injection.
 *   * Add `@Inject lateinit var X: Y` for whatever the test needs.
 */
@HiltAndroidTest
@RunWith(RobolectricTestRunner::class)
@Config(application = HiltTestApplication::class)
class HiltGraphBootTest {

    @get:Rule
    val hiltRule = HiltAndroidRule(this)

    @Inject @ApplicationContext lateinit var context: Context

    @Before fun init() {
        hiltRule.inject()
    }

    @Test fun `hilt graph boots and injects ApplicationContext`() {
        assertNotNull(context)
        // The Application instance Robolectric stood up should be the
        // Hilt-aware test Application, not the prod EquipSevaApplication.
        val app = ApplicationProvider.getApplicationContext<android.app.Application>()
        assertEquals(
            "dagger.hilt.android.internal.testing.root.DaggerDefault_HiltComponents_SingletonC",
            app::class.java.name.let { name ->
                // We don't actually want to lock this exact class name —
                // Hilt regenerates internal class names on every codegen
                // pass. Just confirm it's NOT the prod Application class
                // by checking it doesn't end with the prod name.
                if (name.endsWith("EquipSevaApplication")) {
                    "<prod EquipSevaApplication leaked into the Hilt-aware test boot>"
                } else {
                    "dagger.hilt.android.internal.testing.root.DaggerDefault_HiltComponents_SingletonC"
                }
            },
        )
    }
}
