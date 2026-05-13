package com.equipseva.app.designsystem.util

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect

/**
 * Calls [refresh] every time the host lifecycle hits ON_RESUME *except*
 * the very first one. The first ON_RESUME is skipped because the
 * corresponding ViewModel's init block (or first-emission of a
 * sessionState flow) usually already loaded the data — firing again
 * immediately would round-trip Supabase twice on cold start.
 *
 * Subsequent resumes pick up server-side state changes that happened
 * while the screen was backgrounded (e.g. another tab in the app
 * cancelled a job, an admin resolved a dispute, an AMC contract was
 * paused). Without this, the screen would render stale data until the
 * user pull-to-refreshes or the process is killed.
 *
 * Originally inlined in HospitalActiveJobsScreen (PR #556), then
 * copy-pasted into MaintenanceContractsScreen (PR #596) and the two
 * engineer-side lists (PR #597). Hoisted here so future screens get
 * the same behavior in one line.
 */
@Composable
fun RefreshOnReturn(refresh: () -> Unit) {
    var isFirstResume by remember { mutableStateOf(true) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) {
        if (isFirstResume) {
            isFirstResume = false
        } else {
            refresh()
        }
    }
}
