package com.equipseva.app.uismoke

import android.content.pm.PackageManager
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.platform.app.InstrumentationRegistry
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

@HiltAndroidTest
class UiSmokeHostTest {
    @get:Rule(order = 0) val hiltRule = HiltAndroidRule(this)
    @get:Rule(order = 1) val compose = createAndroidComposeRule<UiSmokeHostActivity>()

    @Test
    fun isolatedHostHasNoNetworkPermissionAndMountsCompose() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        assertEquals("com.equipseva.app.uismoke", instrumentation.targetContext.packageName)
        listOf(instrumentation.targetContext, instrumentation.context).forEach { context ->
            assertEquals(
                PackageManager.PERMISSION_DENIED,
                context.packageManager.checkPermission(android.Manifest.permission.INTERNET, context.packageName),
            )
        }
        compose.onNodeWithText("Isolated UI smoke host").assertIsDisplayed()
    }
}
