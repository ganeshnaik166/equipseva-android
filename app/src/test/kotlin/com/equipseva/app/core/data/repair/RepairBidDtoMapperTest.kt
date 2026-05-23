package com.equipseva.app.core.data.repair

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins [RepairBidDto] → [RepairBid] mapping. The base mapper covers the
 * direct-table SELECT path (own-bid refresh, outbox); the
 * `WithDistance` variant carries the denorm columns from the
 * `list_repair_job_bids_with_distance` RPC. Both must converge on the
 * same domain shape so the bid card composable doesn't fork on data
 * source.
 */
class RepairBidDtoMapperTest {

    private fun baseDto(
        id: String = "b1",
        repairJobId: String = "j1",
        engineerUserId: String = "u1",
        amountRupees: Double = 2500.0,
    ) = RepairBidDto(
        id = id,
        repairJobId = repairJobId,
        engineerUserId = engineerUserId,
        amountRupees = amountRupees,
    )

    @Test fun `base dto with nulls maps to safe defaults`() {
        val bid = baseDto().toDomain()
        assertEquals("b1", bid.id)
        assertEquals("j1", bid.repairJobId)
        assertEquals("u1", bid.engineerUserId)
        assertEquals(2500.0, bid.amountRupees, 0.0)
        assertNull(bid.etaHours)
        assertNull(bid.note)
        assertEquals(RepairBidStatus.Unknown, bid.status)
        assertNull(bid.createdAtInstant)
        assertNull(bid.updatedAtInstant)
        // The WithDistance-only fields are null on this path. Pin so a
        // refactor that copy-paste's the wrong mapper would surface.
        assertNull(bid.engineerName)
        assertNull(bid.engineerAvatarUrl)
        assertNull(bid.engineerRatingAvg)
        assertNull(bid.engineerTotalJobs)
        assertNull(bid.engineerCity)
        assertNull(bid.distanceKm)
    }

    @Test fun `blank note folds to null`() {
        // Empty/whitespace bidder notes are NOT useful; the UI hides
        // the note row entirely when null.
        val bid = baseDto().copy(note = "   ").toDomain()
        assertNull(bid.note)
    }

    @Test fun `non-blank note passes through`() {
        val bid = baseDto().copy(note = "Will bring a spare bulb.").toDomain()
        assertEquals("Will bring a spare bulb.", bid.note)
    }

    @Test fun `known status keys map to enum entries`() {
        assertEquals(RepairBidStatus.Pending, baseDto().copy(status = "pending").toDomain().status)
        assertEquals(RepairBidStatus.Withdrawn, baseDto().copy(status = "withdrawn").toDomain().status)
        assertEquals(RepairBidStatus.Accepted, baseDto().copy(status = "accepted").toDomain().status)
        assertEquals(RepairBidStatus.Rejected, baseDto().copy(status = "rejected").toDomain().status)
    }

    @Test fun `unknown status key maps to Unknown enum value`() {
        val bid = baseDto().copy(status = "future_state").toDomain()
        assertEquals(RepairBidStatus.Unknown, bid.status)
    }

    @Test fun `createdAt and updatedAt ISO strings parse to instants`() {
        val bid = baseDto().copy(
            createdAt = "2026-05-21T10:00:00Z",
            updatedAt = "2026-05-21T10:05:00Z",
        ).toDomain()
        assertEquals("2026-05-21T10:00:00Z", bid.createdAtInstant?.toString())
        assertEquals("2026-05-21T10:05:00Z", bid.updatedAtInstant?.toString())
    }

    @Test fun `malformed ISO folds to null without crash`() {
        val bid = baseDto().copy(createdAt = "garbage", updatedAt = "also-garbage").toDomain()
        assertNull(bid.createdAtInstant)
        assertNull(bid.updatedAtInstant)
    }

    @Test fun `WithDistance dto passes engineer denorm fields through`() {
        val dto = RepairBidWithDistanceDto(
            id = "b1",
            repairJobId = "j1",
            engineerUserId = "u1",
            amountRupees = 2500.0,
            etaHours = 4,
            note = "On my way",
            status = "pending",
            createdAt = "2026-05-21T10:00:00Z",
            updatedAt = "2026-05-21T10:05:00Z",
            engineerFullName = "Ravi Kumar",
            engineerAvatarUrl = "https://cdn.x/u1.jpg",
            engineerRatingAvg = 4.7,
            engineerTotalJobs = 42,
            engineerCity = "Bengaluru",
            distanceKm = 3.2,
        )
        val bid = dto.toDomain()

        assertEquals(4, bid.etaHours)
        assertEquals("On my way", bid.note)
        assertEquals(RepairBidStatus.Pending, bid.status)
        assertEquals("Ravi Kumar", bid.engineerName)
        assertEquals("https://cdn.x/u1.jpg", bid.engineerAvatarUrl)
        assertEquals(4.7, bid.engineerRatingAvg!!, 0.001)
        assertEquals(42, bid.engineerTotalJobs)
        assertEquals("Bengaluru", bid.engineerCity)
        assertEquals(3.2, bid.distanceKm!!, 0.001)
    }

    @Test fun `WithDistance dto folds blank denorm strings to null`() {
        // Direct-table refresh of a bid that originally came from the
        // RPC might lose the engineer denorm via a row update; blank
        // strings on these fields should not render as "blank" rows.
        val dto = RepairBidWithDistanceDto(
            id = "b1",
            repairJobId = "j1",
            engineerUserId = "u1",
            amountRupees = 2500.0,
            engineerFullName = "  ",
            engineerAvatarUrl = "",
            engineerCity = "   ",
        )
        val bid = dto.toDomain()
        assertNull(bid.engineerName)
        assertNull(bid.engineerAvatarUrl)
        assertNull(bid.engineerCity)
    }
}
