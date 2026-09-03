package com.equipseva.app.features.amc

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the pure helpers behind [HospitalFleetHealthScreen] and
 * [HospitalAssetHistoryScreen] (round3771) — the first Android clients
 * of the round508 Equipment Fleet MTBF/MTTR backend.
 */
class HospitalFleetHealthHelpersTest {

    private fun item(
        equipmentType: String = "dental",
        equipmentBrand: String? = null,
        equipmentModel: String? = null,
        equipmentSerial: String? = null,
        failureCountWindow: Int = 1,
        mtbfDays: Double? = null,
        mttrHours: Double? = null,
        totalDowntimeHours: Double = 0.0,
        uptimePct: Double = 100.0,
        replacementCandidate: Boolean = false,
        lastFailureAt: String? = null,
        nextPmDueAt: String? = null,
    ) = HospitalFleetHealthRepository.FleetHealthItem(
        equipmentType = equipmentType,
        equipmentBrand = equipmentBrand,
        equipmentModel = equipmentModel,
        equipmentSerial = equipmentSerial,
        failureCountWindow = failureCountWindow,
        mtbfDays = mtbfDays,
        mttrHours = mttrHours,
        totalDowntimeHours = totalDowntimeHours,
        uptimePct = uptimePct,
        replacementCandidate = replacementCandidate,
        lastFailureAt = lastFailureAt,
        nextPmDueAt = nextPmDueAt,
    )

    // ---------------------------------------------------------------
    // fleetItemKey
    // ---------------------------------------------------------------

    @Test fun `key combines all 4 identity columns`() {
        assertEquals(
            "dental|Sirona|Intego|SN1",
            fleetItemKey(item(equipmentType = "dental", equipmentBrand = "Sirona", equipmentModel = "Intego", equipmentSerial = "SN1")),
        )
    }

    @Test fun `key tolerates null brand, model, and serial without crashing`() {
        assertEquals("dental|||", fleetItemKey(item(equipmentType = "dental")))
    }

    @Test fun `two whole-class rows of the same type stay distinguishable only by brand`() {
        val a = fleetItemKey(item(equipmentType = "dental", equipmentBrand = "Sirona"))
        val b = fleetItemKey(item(equipmentType = "dental", equipmentBrand = "GE"))
        assert(a != b)
    }

    // ---------------------------------------------------------------
    // fleetEquipmentSubtitle
    // ---------------------------------------------------------------

    @Test fun `subtitle blank when brand, model, serial all absent`() {
        assertEquals("", fleetEquipmentSubtitle(item()))
    }

    @Test fun `subtitle joins brand and model`() {
        assertEquals(
            "Sirona · Intego",
            fleetEquipmentSubtitle(item(equipmentBrand = "Sirona", equipmentModel = "Intego")),
        )
    }

    @Test fun `subtitle falls back to serial only`() {
        assertEquals("S/N XY1", fleetEquipmentSubtitle(item(equipmentSerial = "XY1")))
    }

    @Test fun `subtitle includes brand, model, and serial together`() {
        assertEquals(
            "Sirona · Intego · S/N XY1",
            fleetEquipmentSubtitle(item(equipmentBrand = "Sirona", equipmentModel = "Intego", equipmentSerial = "XY1")),
        )
    }

    // ---------------------------------------------------------------
    // assetHistoryEventKindLabel
    // ---------------------------------------------------------------

    @Test fun `known event kinds map to human labels`() {
        assertEquals("Repair job", assetHistoryEventKindLabel("repair_job"))
        assertEquals("Service report", assetHistoryEventKindLabel("dsr_report"))
        assertEquals("Preventive maintenance", assetHistoryEventKindLabel("pm_scheduled"))
    }

    @Test fun `unknown event kind falls back to capitalised raw value rather than crashing`() {
        assertEquals("Warranty_claim", assetHistoryEventKindLabel("warranty_claim"))
    }
}
