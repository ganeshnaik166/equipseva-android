package com.equipseva.app.designsystem.components

import com.equipseva.app.core.data.repair.RepairJobStatus
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * EsStatusStepper renders five circles + four connectors. The two pure
 * helpers — [stepperStepIndex] and [stepperStepState] — decide which
 * circles look done/active/pending and which connectors are green. Drift
 * here either erases progress (Done circles become Pending) or claims
 * progress that hasn't happened (Pending circles light up green) so we
 * pin the exact branch outcomes for every enum + boundary index.
 */
class EsStatusStepperLogicTest {

    @Test fun `StepperSteps has exactly five entries in the happy-path order`() {
        // The composable assumes 5 — drift would mismatch the Row's
        // weight math (1/5 cells) and break the alignment of label vs
        // circle below it.
        assertEquals(5, StepperSteps.size)
        assertEquals(RepairJobStatus.Requested, StepperSteps[0].second)
        assertEquals(RepairJobStatus.Assigned, StepperSteps[1].second)
        assertEquals(RepairJobStatus.EnRoute, StepperSteps[2].second)
        assertEquals(RepairJobStatus.InProgress, StepperSteps[3].second)
        assertEquals(RepairJobStatus.Completed, StepperSteps[4].second)
    }

    @Test fun `stepperStepIndex returns 0 for Requested`() {
        assertEquals(0, stepperStepIndex(RepairJobStatus.Requested))
    }

    @Test fun `stepperStepIndex returns 4 for Completed`() {
        // 4 is the last index — once a job is Completed every circle
        // before it must render Done. If this slid to 3, the final
        // circle would never light up green.
        assertEquals(4, stepperStepIndex(RepairJobStatus.Completed))
    }

    @Test fun `stepperStepIndex returns negative for off-track statuses`() {
        // Cancelled / Disputed / Unknown are not on the happy path; they
        // must collapse to -1 so the composable renders every circle as
        // Pending (no false sense of progress for a cancelled job).
        assertEquals(-1, stepperStepIndex(RepairJobStatus.Cancelled))
        assertEquals(-1, stepperStepIndex(RepairJobStatus.Disputed))
        assertEquals(-1, stepperStepIndex(RepairJobStatus.Unknown))
    }

    @Test fun `stepperStepState marks earlier indices Done`() {
        // current=3 (InProgress); indices 0..2 must be Done so the user
        // sees a continuous green trail behind them.
        assertEquals(StepperState.Done, stepperStepState(currentIdx = 3, index = 0))
        assertEquals(StepperState.Done, stepperStepState(currentIdx = 3, index = 1))
        assertEquals(StepperState.Done, stepperStepState(currentIdx = 3, index = 2))
    }

    @Test fun `stepperStepState marks the matching index Active`() {
        // The Active circle is the only one that gets the inner-dot
        // treatment — exactly one circle, at currentIdx.
        assertEquals(StepperState.Active, stepperStepState(currentIdx = 2, index = 2))
    }

    @Test fun `stepperStepState marks later indices Pending`() {
        // Nothing past current is reached yet; render as the empty
        // outlined circle.
        assertEquals(StepperState.Pending, stepperStepState(currentIdx = 1, index = 2))
        assertEquals(StepperState.Pending, stepperStepState(currentIdx = 1, index = 3))
        assertEquals(StepperState.Pending, stepperStepState(currentIdx = 1, index = 4))
    }

    @Test fun `off-track currentIdx renders every circle Pending`() {
        // A Cancelled job (-1) means no progress was made — every
        // circle including index 0 must be Pending, otherwise we'd
        // imply "Requested was achieved" even after cancellation.
        for (i in 0..4) {
            assertEquals(StepperState.Pending, stepperStepState(currentIdx = -1, index = i))
        }
    }

    @Test fun `stepperStepState handles the first step boundary`() {
        // index 0 with current 0 is Active (not Done) — the user is on
        // step 1, hasn't completed it yet.
        assertEquals(StepperState.Active, stepperStepState(currentIdx = 0, index = 0))
    }

    @Test fun `stepperStepState handles the last step boundary`() {
        // Completed: every prior circle Done, the last Active.
        assertEquals(StepperState.Done, stepperStepState(currentIdx = 4, index = 0))
        assertEquals(StepperState.Done, stepperStepState(currentIdx = 4, index = 3))
        assertEquals(StepperState.Active, stepperStepState(currentIdx = 4, index = 4))
    }
}
