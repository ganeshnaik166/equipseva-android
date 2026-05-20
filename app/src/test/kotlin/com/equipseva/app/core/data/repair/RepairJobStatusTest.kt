package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the wire-key contract for the three repair-job enums against the
 * server-side enums + RPC return values. fromKey() must never throw — a new
 * server-side value should always degrade to the explicit "Unknown" /
 * fallback bucket so the feed keeps rendering.
 */
class RepairJobStatusTest {

    @Test fun `RepairJobStatus storage keys match server enum`() {
        assertEquals("requested", RepairJobStatus.Requested.storageKey)
        assertEquals("assigned", RepairJobStatus.Assigned.storageKey)
        assertEquals("en_route", RepairJobStatus.EnRoute.storageKey)
        assertEquals("in_progress", RepairJobStatus.InProgress.storageKey)
        assertEquals("completed", RepairJobStatus.Completed.storageKey)
        assertEquals("cancelled", RepairJobStatus.Cancelled.storageKey)
        assertEquals("disputed", RepairJobStatus.Disputed.storageKey)
    }

    @Test fun `RepairJobStatus fromKey round-trips`() {
        RepairJobStatus.entries
            .filter { it != RepairJobStatus.Unknown }
            .forEach { status ->
                assertEquals(
                    "round-trip failed for ${status.name}",
                    status,
                    RepairJobStatus.fromKey(status.storageKey),
                )
            }
    }

    @Test fun `RepairJobStatus fromKey degrades unknown values to Unknown`() {
        assertEquals(RepairJobStatus.Unknown, RepairJobStatus.fromKey(null))
        assertEquals(RepairJobStatus.Unknown, RepairJobStatus.fromKey("escalated"))
        assertEquals(RepairJobStatus.Unknown, RepairJobStatus.fromKey(""))
    }

    @Test fun `OpenForEngineers feed filter is exactly Requested plus Assigned`() {
        // The engineer-side job feed filters on this list. Pre-Assigned slips
        // the job off the feed once accepted; over-inclusion would resurface
        // stale jobs the engineer already moved past.
        assertEquals(
            listOf(RepairJobStatus.Requested, RepairJobStatus.Assigned),
            RepairJobStatus.OpenForEngineers,
        )
    }

    @Test fun `RepairJobUrgency falls back to Unknown (Standard) on null`() {
        assertEquals(RepairJobUrgency.Unknown, RepairJobUrgency.fromKey(null))
        assertEquals("Standard", RepairJobUrgency.Unknown.displayName)
    }

    @Test fun `RepairJobUrgency fromKey round-trips`() {
        RepairJobUrgency.entries
            .filter { it != RepairJobUrgency.Unknown }
            .forEach { urgency ->
                assertEquals(urgency, RepairJobUrgency.fromKey(urgency.storageKey))
            }
    }

    @Test fun `RepairEquipmentCategory unknown key falls back to Other`() {
        // Hospitals can pick any category at booking time; if the SQL enum
        // is bumped we still want to render the job with the "Other" bucket.
        assertEquals(RepairEquipmentCategory.Other, RepairEquipmentCategory.fromKey(null))
        assertEquals(RepairEquipmentCategory.Other, RepairEquipmentCategory.fromKey("autonomous_robot_surgeon"))
    }

    @Test fun `RepairEquipmentCategory covers the v1 catalog`() {
        // Sanity-check that the catalog the booking screen exposes is wide
        // enough — narrowing this list would orphan existing rows in the DB.
        val keys = RepairEquipmentCategory.entries.map { it.storageKey }
        assertTrue("imaging_radiology missing", keys.contains("imaging_radiology"))
        assertTrue("life_support missing", keys.contains("life_support"))
        assertTrue("dental missing", keys.contains("dental"))
        assertTrue("other fallback missing", keys.contains("other"))
    }

    @Test fun `RepairBidStatus default insert key is pending`() {
        // Pin the default that RepairBidInsertDto writes. If the DB enum is
        // renamed without updating the DTO default, every fresh bid would
        // INSERT with a stale label that fails the CHECK constraint.
        assertEquals("pending", RepairBidStatus.Pending.storageKey)
        assertEquals(RepairBidStatus.Pending, RepairBidStatus.fromKey("pending"))
    }

    @Test fun `RepairBidStatus fromKey round-trips except Unknown`() {
        RepairBidStatus.entries
            .filter { it != RepairBidStatus.Unknown }
            .forEach { status ->
                assertEquals(status, RepairBidStatus.fromKey(status.storageKey))
            }
        assertEquals(RepairBidStatus.Unknown, RepairBidStatus.fromKey(null))
        assertEquals(RepairBidStatus.Unknown, RepairBidStatus.fromKey("escalated"))
    }
}
