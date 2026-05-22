package com.equipseva.app.features.repair

import com.equipseva.app.core.data.repair.RepairJobStatus
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the status-stepper timeline contract used by RepairJobDetail's
 * 5-step progress visualisation.
 *
 *   * StepLabels + StepStatuses must stay aligned (5 each), with the
 *     index of each enum entry equal to the index of its label.
 *   * statusStepIndex returns -1 for non-timeline statuses (Cancelled,
 *     Disputed, Unknown) so the rendering logic renders the timeline
 *     in its inactive state rather than crashing or picking a wrong
 *     position.
 */
class StatusStepperTest {

    @Test fun `StepLabels has 5 entries (Requested through Completed)`() {
        assertEquals(
            listOf("Requested", "Assigned", "En route", "In progress", "Completed"),
            StepLabels,
        )
    }

    @Test fun `StepStatuses has 5 entries matching the labels`() {
        assertEquals(
            listOf(
                RepairJobStatus.Requested,
                RepairJobStatus.Assigned,
                RepairJobStatus.EnRoute,
                RepairJobStatus.InProgress,
                RepairJobStatus.Completed,
            ),
            StepStatuses,
        )
    }

    @Test fun `StepStatuses and StepLabels are the same length`() {
        // Pin so a future addition to one without the other surfaces
        // — the indexed rendering would crash on the missing label.
        assertEquals(StepLabels.size, StepStatuses.size)
    }

    @Test fun `statusStepIndex returns 0 for Requested`() {
        assertEquals(0, statusStepIndex(RepairJobStatus.Requested))
    }

    @Test fun `statusStepIndex returns 4 for Completed (last step)`() {
        assertEquals(4, statusStepIndex(RepairJobStatus.Completed))
    }

    @Test fun `statusStepIndex returns -1 for Cancelled (not on the timeline)`() {
        // Cancelled is a terminal state but NOT part of the linear
        // progress timeline — pin so the stepper UI renders all dots
        // inactive instead of picking a position.
        assertEquals(-1, statusStepIndex(RepairJobStatus.Cancelled))
    }

    @Test fun `statusStepIndex returns -1 for Disputed (not on the timeline)`() {
        assertEquals(-1, statusStepIndex(RepairJobStatus.Disputed))
    }

    @Test fun `statusStepIndex returns -1 for Unknown (defensive)`() {
        // A future server-side status maps to Unknown via
        // RepairJobStatus.fromKey — the stepper must not crash.
        assertEquals(-1, statusStepIndex(RepairJobStatus.Unknown))
    }

    @Test fun `each on-timeline status maps to a distinct index`() {
        // Pin so a refactor that reordered StepStatuses surfaces.
        val indices = listOf(
            RepairJobStatus.Requested,
            RepairJobStatus.Assigned,
            RepairJobStatus.EnRoute,
            RepairJobStatus.InProgress,
            RepairJobStatus.Completed,
        ).map(::statusStepIndex)
        assertEquals(listOf(0, 1, 2, 3, 4), indices)
    }
}
