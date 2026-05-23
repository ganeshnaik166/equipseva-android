package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the [RepairJobStatus] + [RepairJobUrgency] + [RepairBidStatus]
 * + [RepairEquipmentCategory] enum contracts: the `storageKey`
 * strings (wire format) and the `fromKey(null)` fallback per enum.
 *
 * The storage keys mirror server-side Postgres `job_status` /
 * `job_urgency` / `bid_status` / equipment-category enums. A
 * client-side rename would silently misclassify every incoming row
 * (Postgrest decode tolerates strings → falls through to the
 * fallback bucket) — caught here so the wire shape stays frozen.
 */
class RepairJobStatusEnumTest {

    // ---- RepairJobStatus ----

    @Test fun `RepairJobStatus keys match the pinned wire strings`() {
        assertEquals("requested", RepairJobStatus.Requested.storageKey)
        assertEquals("assigned", RepairJobStatus.Assigned.storageKey)
        assertEquals("en_route", RepairJobStatus.EnRoute.storageKey)
        assertEquals("in_progress", RepairJobStatus.InProgress.storageKey)
        assertEquals("completed", RepairJobStatus.Completed.storageKey)
        assertEquals("cancelled", RepairJobStatus.Cancelled.storageKey)
        assertEquals("disputed", RepairJobStatus.Disputed.storageKey)
        assertEquals("", RepairJobStatus.Unknown.storageKey)
    }

    @Test fun `RepairJobStatus display names match the pinned product copy`() {
        // user-facing strings on the JobCard + detail screen; pin so
        // a copy tweak is intentional.
        assertEquals("Open", RepairJobStatus.Requested.displayName)
        assertEquals("Assigned", RepairJobStatus.Assigned.displayName)
        assertEquals("En route", RepairJobStatus.EnRoute.displayName)
        assertEquals("In progress", RepairJobStatus.InProgress.displayName)
        assertEquals("Completed", RepairJobStatus.Completed.displayName)
        assertEquals("Cancelled", RepairJobStatus.Cancelled.displayName)
        assertEquals("Disputed", RepairJobStatus.Disputed.displayName)
        assertEquals("Unknown", RepairJobStatus.Unknown.displayName)
    }

    @Test fun `RepairJobStatus fromKey null falls back to Unknown`() {
        assertEquals(RepairJobStatus.Unknown, RepairJobStatus.fromKey(null))
        assertEquals(RepairJobStatus.Unknown, RepairJobStatus.fromKey("future_status"))
    }

    @Test fun `RepairJobStatus OpenForEngineers is requested plus assigned`() {
        assertEquals(
            listOf(RepairJobStatus.Requested, RepairJobStatus.Assigned),
            RepairJobStatus.OpenForEngineers,
        )
    }

    // ---- RepairJobUrgency ----

    @Test fun `RepairJobUrgency keys match the pinned wire strings`() {
        assertEquals("emergency", RepairJobUrgency.Emergency.storageKey)
        assertEquals("same_day", RepairJobUrgency.SameDay.storageKey)
        assertEquals("scheduled", RepairJobUrgency.Scheduled.storageKey)
        assertEquals("", RepairJobUrgency.Unknown.storageKey)
    }

    @Test fun `RepairJobUrgency Unknown display name is Standard (UX softening)`() {
        // UX choice: the server may emit an unknown urgency on legacy
        // rows; rather than rendering "Unknown" verbatim, the pill
        // reads "Standard". Pin so the softening stays.
        assertEquals("Standard", RepairJobUrgency.Unknown.displayName)
    }

    @Test fun `RepairJobUrgency fromKey null falls back to Unknown`() {
        assertEquals(RepairJobUrgency.Unknown, RepairJobUrgency.fromKey(null))
    }

    // ---- RepairBidStatus ----

    @Test fun `RepairBidStatus keys match the pinned wire strings`() {
        assertEquals("pending", RepairBidStatus.Pending.storageKey)
        assertEquals("withdrawn", RepairBidStatus.Withdrawn.storageKey)
        assertEquals("accepted", RepairBidStatus.Accepted.storageKey)
        assertEquals("rejected", RepairBidStatus.Rejected.storageKey)
        assertEquals("", RepairBidStatus.Unknown.storageKey)
    }

    @Test fun `RepairBidStatus fromKey null and unknown fall back to Unknown`() {
        assertEquals(RepairBidStatus.Unknown, RepairBidStatus.fromKey(null))
        assertEquals(RepairBidStatus.Unknown, RepairBidStatus.fromKey("future"))
    }

    // ---- RepairEquipmentCategory ----

    @Test fun `RepairEquipmentCategory has the pinned 16 entries`() {
        // 15 specific categories + Other; pin the count so a stealth
        // deletion is caught. The KYC specialization picker filters
        // out Other, leaving 15 user-selectable entries.
        assertEquals(16, RepairEquipmentCategory.entries.size)
    }

    @Test fun `RepairEquipmentCategory Other is the fallback bucket`() {
        assertEquals(RepairEquipmentCategory.Other, RepairEquipmentCategory.fromKey(null))
        assertEquals(RepairEquipmentCategory.Other, RepairEquipmentCategory.fromKey("future_kind"))
    }

    @Test fun `RepairEquipmentCategory known keys round-trip via fromKey`() {
        // Spot-check a few known keys to pin the storage-key lookup.
        assertEquals(
            RepairEquipmentCategory.ImagingRadiology,
            RepairEquipmentCategory.fromKey("imaging_radiology"),
        )
        assertEquals(
            RepairEquipmentCategory.Dental,
            RepairEquipmentCategory.fromKey("dental"),
        )
        assertEquals(
            RepairEquipmentCategory.Ent,
            RepairEquipmentCategory.fromKey("ent"),
        )
    }

    @Test fun `every RepairEquipmentCategory has a non-empty displayName`() {
        // Defensive — a missing displayName would render an empty
        // chip in the directory filter row.
        RepairEquipmentCategory.entries.forEach { cat ->
            assertTrue(
                "${cat.name} has empty displayName",
                cat.displayName.isNotBlank(),
            )
        }
    }
}
