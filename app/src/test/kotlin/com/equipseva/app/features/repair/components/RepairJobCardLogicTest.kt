package com.equipseva.app.features.repair.components

import com.equipseva.app.core.data.repair.RepairBidStatus
import com.equipseva.app.core.data.repair.RepairEquipmentCategory
import com.equipseva.app.core.data.repair.RepairJob
import com.equipseva.app.core.data.repair.RepairJobStatus
import com.equipseva.app.core.data.repair.RepairJobUrgency
import com.equipseva.app.designsystem.components.StatusTone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * RepairJobCard packs four pure derivations: the equipment icon classifier
 * (keyword sniff + category fallback), the model line, the schedule label,
 * and the status/urgency/bid tone mappers. All four are visible at-a-glance
 * to the user before they tap into the job, so getting them wrong is a
 * trust hit. These tests pin the keyword precedence + fallback order +
 * empty-string handling so a refactor can't silently degrade them.
 */
class RepairJobCardLogicTest {

    // ─── equipmentIconKind ─────────────────────────────────────────────

    @Test fun `MRI keyword wins over category fallback`() {
        // Keyword sniff runs before category — a job whose equipmentLabel
        // mentions "MRI" must classify as Imaging even if the category is
        // Other (stale Postgrest data, free-text equipment).
        val job = job(brand = "MRI machine", category = RepairEquipmentCategory.Other)
        assertEquals(EquipmentIconKind.Imaging, equipmentIconKind(job))
        assertEquals(200, equipmentIconKind(job).hue)
    }

    @Test fun `xray with hyphen and without both match Imaging`() {
        // Two forms exist in the wild — "x-ray" and "xray" — pin both.
        assertEquals(EquipmentIconKind.Imaging, equipmentIconKind(job(brand = "Portable X-Ray")))
        assertEquals(EquipmentIconKind.Imaging, equipmentIconKind(job(brand = "Mobile xray unit")))
    }

    @Test fun `ultrasound keyword maps to Imaging`() {
        assertEquals(EquipmentIconKind.Imaging, equipmentIconKind(job(brand = "Ultrasound probe")))
    }

    @Test fun `ECG and EKG both map to Cardiac with hue 40`() {
        // Two spellings, same family — pin both. Hue 40 is the amber the
        // cardiac tile uses; drift would break the gradient palette.
        assertEquals(EquipmentIconKind.Cardiac, equipmentIconKind(job(brand = "ECG monitor")))
        assertEquals(EquipmentIconKind.Cardiac, equipmentIconKind(job(brand = "EKG cable")))
        assertEquals(40, EquipmentIconKind.Cardiac.hue)
    }

    @Test fun `ventilator keyword maps to LifeSupport`() {
        assertEquals(EquipmentIconKind.LifeSupport, equipmentIconKind(job(brand = "Ventilator filter")))
    }

    @Test fun `pump or infusion keyword maps to Infusion`() {
        assertEquals(EquipmentIconKind.Infusion, equipmentIconKind(job(brand = "Syringe pump")))
        assertEquals(EquipmentIconKind.Infusion, equipmentIconKind(job(brand = "Infusion line")))
    }

    @Test fun `defib variants map to Cardiac`() {
        // "defibrillator" + the colloquial "defib" must both route to
        // the heart icon family.
        assertEquals(EquipmentIconKind.Cardiac, equipmentIconKind(job(brand = "Defibrillator pads")))
        assertEquals(EquipmentIconKind.Cardiac, equipmentIconKind(job(brand = "Defib battery")))
    }

    @Test fun `keyword sniff is case-insensitive via lowercase pass`() {
        // The function lowercases the combined string once before scanning;
        // pin so a future tidy doesn't drop the .lowercase() and break for
        // shouty UPPERCASE labels we get from older PostgREST rows.
        assertEquals(EquipmentIconKind.Imaging, equipmentIconKind(job(brand = "MRI SCANNER")))
    }

    @Test fun `category fallback ImagingRadiology when no keyword hit`() {
        // The label has no diagnostic keyword — fall back to category.
        val j = job(brand = "Generic", model = "device", category = RepairEquipmentCategory.ImagingRadiology)
        assertEquals(EquipmentIconKind.Imaging, equipmentIconKind(j))
    }

    @Test fun `category fallback PatientMonitoring and Cardiology both route to Cardiac`() {
        // Two separate categories deliberately share the heart icon — pin
        // that union so it doesn't silently split.
        assertEquals(
            EquipmentIconKind.Cardiac,
            equipmentIconKind(job(brand = "thing", category = RepairEquipmentCategory.PatientMonitoring)),
        )
        assertEquals(
            EquipmentIconKind.Cardiac,
            equipmentIconKind(job(brand = "thing", category = RepairEquipmentCategory.Cardiology)),
        )
    }

    @Test fun `category fallback LifeSupport and Surgical use hue zero`() {
        // Both surgical and life-support tiles use the same neutral hue
        // 0 (greyscale gradient) — pin so a palette refactor doesn't
        // diverge them.
        assertEquals(
            EquipmentIconKind.LifeSupport,
            equipmentIconKind(job(brand = "x", category = RepairEquipmentCategory.LifeSupport)),
        )
        assertEquals(
            EquipmentIconKind.Surgical,
            equipmentIconKind(job(brand = "x", category = RepairEquipmentCategory.Surgical)),
        )
        assertEquals(0, EquipmentIconKind.LifeSupport.hue)
        assertEquals(0, EquipmentIconKind.Surgical.hue)
    }

    @Test fun `unknown category falls back to Generic with hue 150`() {
        // Anything not explicitly mapped (Dental, Laboratory, Other, etc.)
        // lands on the wrench-icon Generic bucket so the tile always
        // renders something.
        assertEquals(
            EquipmentIconKind.Generic,
            equipmentIconKind(job(brand = "thing", category = RepairEquipmentCategory.Dental)),
        )
        assertEquals(150, EquipmentIconKind.Generic.hue)
    }

    @Test fun `brand and model are scanned for keywords too`() {
        // The composite string includes brand + model + (computed)
        // equipmentLabel, so an MRI model on a non-imaging category
        // still classifies as Imaging.
        val j = job(brand = "Siemens", model = "MRI Magnetom", category = RepairEquipmentCategory.Other)
        assertEquals(EquipmentIconKind.Imaging, equipmentIconKind(j))
    }

    // ─── repairJobModelLine ────────────────────────────────────────────

    @Test fun `model line is null when brand and model duplicate equipmentLabel`() {
        // equipmentLabel computes brand + model when both are non-blank,
        // so the secondary line would just repeat the title. Suppress.
        // Pinning this prevents a "Posted GE Logiq P5 / GE Logiq P5"
        // visual duplicate in the card.
        val j = job(brand = "GE", model = "Logiq P5")
        assertNull(repairJobModelLine(j))
    }

    @Test fun `model line returns null when brand and model are both null`() {
        // listOfNotNull produces "" → isNotBlank() check skips the row.
        val j = job(brand = null, model = null)
        assertNull(repairJobModelLine(j))
    }

    @Test fun `model line returns null when brand alone duplicates equipmentLabel`() {
        // Only brand is set → equipmentLabel falls back to that single
        // value, so the combined string still matches. Suppress.
        val j = job(brand = "GE", model = null)
        assertNull(repairJobModelLine(j))
    }

    @Test fun `model line renders when blank brand makes combined string differ from equipmentLabel`() {
        // Whitespace-only brand: equipmentLabel filters it out via
        // takeIf{isNotBlank}, but the inline joinToString does not, so
        // combined still carries the leading-blank padding. The two
        // diverge and the row renders. This is the only realistic path
        // where the modelLine appears — pinning so a "tidy refactor"
        // that adds a takeIf to the helper doesn't silently kill the
        // entire branch.
        val j = job(brand = "   ", model = "Logiq P5")
        assertEquals("    Logiq P5", repairJobModelLine(j))
    }

    // ─── repairJobScheduleLabel ────────────────────────────────────────

    @Test fun `schedule label joins date and slot`() {
        val j = job(date = "Mon 12 May", slot = "10-12")
        assertEquals("Scheduled Mon 12 May 10-12", repairJobScheduleLabel(j))
    }

    @Test fun `schedule label returns null when both fields are null`() {
        // No schedule info → no row, no dangling "Scheduled " text.
        val j = job(date = null, slot = null)
        assertNull(repairJobScheduleLabel(j))
    }

    @Test fun `schedule label handles slot only`() {
        // Hospital sometimes provides a slot without a date (asap-this-
        // week behaviour); we still want the row, no leading space.
        val j = job(date = null, slot = "Morning")
        assertEquals("Scheduled Morning", repairJobScheduleLabel(j))
    }

    @Test fun `schedule label returns null when both fields are blank`() {
        // Empty strings from a Postgrest row are treated as missing, not
        // as a label of "Scheduled ".
        val j = job(date = "   ", slot = "")
        assertNull(repairJobScheduleLabel(j))
    }

    // ─── tone mappers ──────────────────────────────────────────────────

    @Test fun `RepairJobStatus toTone covers every enum case with the right bucket`() {
        // Tone affects which colour the chip renders. EnRoute and
        // InProgress share Warn (amber) because they're both "in
        // motion"; Cancelled and Disputed share Danger (red) because
        // both are unhappy terminal states.
        assertEquals(StatusTone.Info, RepairJobStatus.Requested.toTone())
        assertEquals(StatusTone.Info, RepairJobStatus.Assigned.toTone())
        assertEquals(StatusTone.Warn, RepairJobStatus.EnRoute.toTone())
        assertEquals(StatusTone.Warn, RepairJobStatus.InProgress.toTone())
        assertEquals(StatusTone.Success, RepairJobStatus.Completed.toTone())
        assertEquals(StatusTone.Danger, RepairJobStatus.Cancelled.toTone())
        assertEquals(StatusTone.Danger, RepairJobStatus.Disputed.toTone())
        assertEquals(StatusTone.Neutral, RepairJobStatus.Unknown.toTone())
    }

    @Test fun `RepairJobUrgency toTone Emergency is Danger`() {
        // Emergency is the only urgency that gets Danger — pin so a
        // gentler refactor doesn't soften it to Warn.
        assertEquals(StatusTone.Danger, RepairJobUrgency.Emergency.toTone())
        assertEquals(StatusTone.Warn, RepairJobUrgency.SameDay.toTone())
        assertEquals(StatusTone.Success, RepairJobUrgency.Scheduled.toTone())
        assertEquals(StatusTone.Neutral, RepairJobUrgency.Unknown.toTone())
    }

    @Test fun `RepairBidStatus toTone Withdrawn and Unknown both Neutral`() {
        // Withdrawn bids stay visible on engineer history but shouldn't
        // shout; they share Neutral with Unknown.
        assertEquals(StatusTone.Info, RepairBidStatus.Pending.toTone())
        assertEquals(StatusTone.Success, RepairBidStatus.Accepted.toTone())
        assertEquals(StatusTone.Danger, RepairBidStatus.Rejected.toTone())
        assertEquals(StatusTone.Neutral, RepairBidStatus.Withdrawn.toTone())
        assertEquals(StatusTone.Neutral, RepairBidStatus.Unknown.toTone())
    }

    // ─── job builder ───────────────────────────────────────────────────

    private fun job(
        label: String? = "Imaging & radiology",
        brand: String? = null,
        model: String? = null,
        category: RepairEquipmentCategory = RepairEquipmentCategory.Other,
        date: String? = null,
        slot: String? = null,
    ): RepairJob = RepairJob(
        id = "id",
        jobNumber = null,
        title = label ?: "title",
        issueDescription = label ?: "issue",
        equipmentCategory = category,
        equipmentBrand = brand,
        equipmentModel = model,
        status = RepairJobStatus.Requested,
        urgency = RepairJobUrgency.Unknown,
        estimatedCostRupees = null,
        scheduledDate = date,
        scheduledTimeSlot = slot,
        siteLocation = null,
        isAssignedToEngineer = false,
        engineerId = null,
        hospitalUserId = null,
        startedAtInstant = null,
        completedAtInstant = null,
        hospitalRating = null,
        hospitalReview = null,
        engineerRating = null,
        engineerReview = null,
        createdAtInstant = null,
        updatedAtInstant = null,
    )
}
