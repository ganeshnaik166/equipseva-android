package com.equipseva.app.features.repair

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the viewer-role resolution on the repair-job detail screen.
 * The chosen role drives almost everything visible: which CTA shows
 * (Place bid vs Mark complete vs Open dispute), which side rates
 * which counterpart, whether the Report CTA appears, whether the
 * escrow status card shows the dispute response composer. A
 * regression that mis-classified would cascade across the screen.
 */
class ResolveViewerRoleTest {

    private val hospital = "h-1"
    private val engineer = "e-1"

    @Test fun `null hospitalUserId yields Other (loading state)`() {
        assertEquals(
            RepairJobDetailViewModel.ViewerRole.Other,
            resolveViewerRole(
                hospitalUserId = null,
                selfId = engineer,
                selfEngineerRowId = "engRow-1",
                selfProfileRole = "engineer",
                selfActiveRole = "engineer",
            ),
        )
    }

    @Test fun `blank selfId yields Other (signed out)`() {
        assertEquals(
            RepairJobDetailViewModel.ViewerRole.Other,
            resolveViewerRole(
                hospitalUserId = hospital,
                selfId = "  ",
                selfEngineerRowId = "engRow-1",
                selfProfileRole = "engineer",
                selfActiveRole = "engineer",
            ),
        )
    }

    @Test fun `selfId equals hospitalUserId yields Hospital`() {
        assertEquals(
            RepairJobDetailViewModel.ViewerRole.Hospital,
            resolveViewerRole(
                hospitalUserId = hospital,
                selfId = hospital,
                selfEngineerRowId = null,
                selfProfileRole = "hospital_admin",
                selfActiveRole = "hospital_admin",
            ),
        )
    }

    @Test fun `Hospital wins over any engineer flag (poster is always Hospital)`() {
        // Edge case: a user who posted the job AND also has an engineers
        // row (multi-role) must see the Hospital flow on this job.
        assertEquals(
            RepairJobDetailViewModel.ViewerRole.Hospital,
            resolveViewerRole(
                hospitalUserId = hospital,
                selfId = hospital,
                selfEngineerRowId = "engRow-1",
                selfProfileRole = "engineer",
                selfActiveRole = "engineer",
            ),
        )
    }

    @Test fun `engineers row id alone yields Engineer`() {
        assertEquals(
            RepairJobDetailViewModel.ViewerRole.Engineer,
            resolveViewerRole(
                hospitalUserId = hospital,
                selfId = engineer,
                selfEngineerRowId = "engRow-1",
                selfProfileRole = null,
                selfActiveRole = null,
            ),
        )
    }

    @Test fun `profile role engineer (no engineers row yet) still yields Engineer`() {
        // KYC-incomplete engineer who picked the role at signup; the
        // server's RLS will gate bid submission, but the client lets
        // them see the Place bid CTA so they discover the KYC prompt.
        assertEquals(
            RepairJobDetailViewModel.ViewerRole.Engineer,
            resolveViewerRole(
                hospitalUserId = hospital,
                selfId = engineer,
                selfEngineerRowId = null,
                selfProfileRole = "engineer",
                selfActiveRole = null,
            ),
        )
    }

    @Test fun `device-local active role engineer also yields Engineer`() {
        // Multi-role hub: user can toggle to Engineer persona on this
        // device without writing to the auth profile.
        assertEquals(
            RepairJobDetailViewModel.ViewerRole.Engineer,
            resolveViewerRole(
                hospitalUserId = hospital,
                selfId = "u-multi",
                selfEngineerRowId = null,
                selfProfileRole = "hospital_admin",
                selfActiveRole = "engineer",
            ),
        )
    }

    @Test fun `unrelated viewer (different user, no engineer flags) yields Other`() {
        assertEquals(
            RepairJobDetailViewModel.ViewerRole.Other,
            resolveViewerRole(
                hospitalUserId = hospital,
                selfId = "u-stranger",
                selfEngineerRowId = null,
                selfProfileRole = "supplier",
                selfActiveRole = "supplier",
            ),
        )
    }

    @Test fun `blank engineers row id falls through to next signal`() {
        // Defensive — an empty string id must not be treated as
        // truthy and route the viewer to Engineer without any backing.
        assertEquals(
            RepairJobDetailViewModel.ViewerRole.Other,
            resolveViewerRole(
                hospitalUserId = hospital,
                selfId = "u-stranger",
                selfEngineerRowId = "   ",
                selfProfileRole = "supplier",
                selfActiveRole = "supplier",
            ),
        )
    }
}
