package com.equipseva.app.core.data.secure

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** WP22.T03: the one-time notice survives a process death until it has been shown. */
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class LocalDataResetNoticeTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    @Test
    fun `a recorded reset is pending, also for a new process, until acknowledged`() {
        val first = LocalDataResetNotice(context)
        assertFalse(first.pending.value)
        first.markPending()
        assertTrue(first.pending.value)
        assertTrue("a new process sees it", LocalDataResetNotice(context).pending.value)

        first.acknowledge()
        assertFalse(first.pending.value)
        assertFalse("and it is shown once", LocalDataResetNotice(context).pending.value)
    }
}
