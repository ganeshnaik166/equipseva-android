package com.equipseva.app.features.notifications

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the inbox notification-row icon style mapping. The Composable
 * resolves the abstract shape + tone into concrete Material icons +
 * theme colours; this test pins the kind→bucket routing
 * independent of the Compose runtime.
 *
 * Two regions worth defending:
 *   * Money / commerce kinds all share the Rupee shape and the
 *     GreenPositive tone (positive money news + bid lifecycle).
 *   * AMC renewal escalates by `data["stage"]`: stage "3" is the
 *     1-day window and gets the Danger tint so it stands apart in a
 *     backed-up inbox; everything else uses the Warn tint.
 */
class NotificationIconStyleTest {

    private fun style(kind: String, data: Map<String, String> = emptyMap()) =
        notificationIconStyle(kind, data)

    // ---- money / commerce kinds ----

    @Test fun `repair-bid kinds map to Rupee + GreenPositive`() {
        listOf(
            "repair_bid_new",
            "repair_bid_accepted",
            "repair_bid_rejected",
        ).forEach { kind ->
            val s = style(kind)
            assertEquals(
                "expected Rupee shape for $kind",
                NotificationIconShape.Rupee, s.shape,
            )
            assertEquals(
                "expected GreenPositive tone for $kind",
                NotificationIconTone.GreenPositive, s.tone,
            )
        }
    }

    @Test fun `cost-revision lifecycle uses Rupee + GreenPositive`() {
        listOf(
            "cost_revision_proposed",
            "cost_revision_approved",
            "cost_revision_rejected",
        ).forEach { kind ->
            val s = style(kind)
            assertEquals(NotificationIconShape.Rupee, s.shape)
            assertEquals(NotificationIconTone.GreenPositive, s.tone)
        }
    }

    // ---- chat ----

    @Test fun `chat_message_new uses Chat + GreenPositive`() {
        val s = style("chat_message_new")
        assertEquals(NotificationIconShape.Chat, s.shape)
        assertEquals(NotificationIconTone.GreenPositive, s.tone)
    }

    // ---- KYC ----

    @Test fun `kyc_status_changed uses Shield + InfoBlue`() {
        val s = style("kyc_status_changed")
        assertEquals(NotificationIconShape.Shield, s.shape)
        assertEquals(NotificationIconTone.InfoBlue, s.tone)
    }

    // ---- repair lifecycle ----

    @Test fun `repair_job_cancelled uses Bolt + DangerRed`() {
        val s = style("repair_job_cancelled")
        assertEquals(NotificationIconShape.Bolt, s.shape)
        assertEquals(NotificationIconTone.DangerRed, s.tone)
    }

    // ---- rating prompts ----

    @Test fun `rating prompts use Star + WarnAmber`() {
        listOf("rate_engineer", "rate_hospital").forEach { kind ->
            val s = style(kind)
            assertEquals(NotificationIconShape.Star, s.shape)
            assertEquals(NotificationIconTone.WarnAmber, s.tone)
        }
    }

    @Test fun `commission tier upgrade uses Star + GreenPositive (celebration)`() {
        val s = style("commission_tier_upgraded")
        assertEquals(NotificationIconShape.Star, s.shape)
        assertEquals(NotificationIconTone.GreenPositive, s.tone)
    }

    // ---- warranty ----

    @Test fun `warranty kinds use Verified + GreenPositive`() {
        listOf("warranty_covered", "warranty_fee_waived").forEach { kind ->
            val s = style(kind)
            assertEquals(NotificationIconShape.Verified, s.shape)
            assertEquals(NotificationIconTone.GreenPositive, s.tone)
        }
    }

    // ---- AMC visit lifecycle ----

    @Test fun `AMC visit lifecycle uses Build + InfoBlue`() {
        listOf(
            "amc_loyal_pair_nudge",
            "amc_visit_assigned",
            "amc_visit_engineer_assigned",
            "amc_visit_engineer_changed",
            "amc_visit_pending_assignment",
        ).forEach { kind ->
            val s = style(kind)
            assertEquals(NotificationIconShape.Build, s.shape)
            assertEquals(NotificationIconTone.InfoBlue, s.tone)
        }
    }

    // ---- AMC renewal stage escalation ----

    @Test fun `AMC renewal stage 1 or 2 uses Build + WarnAmber`() {
        val s1 = style("amc_renewal_due", mapOf("stage" to "1"))
        assertEquals(NotificationIconShape.Build, s1.shape)
        assertEquals(NotificationIconTone.WarnAmber, s1.tone)

        val s2 = style("amc_renewal_due", mapOf("stage" to "2"))
        assertEquals(NotificationIconTone.WarnAmber, s2.tone)
    }

    @Test fun `AMC renewal stage 3 escalates to Build + DangerRed`() {
        // 1-day window before the contract lapses — the loudest tint
        // so a backed-up inbox still surfaces it.
        val s = style("amc_renewal_due", mapOf("stage" to "3"))
        assertEquals(NotificationIconShape.Build, s.shape)
        assertEquals(NotificationIconTone.DangerRed, s.tone)
    }

    @Test fun `AMC renewal with missing stage falls back to WarnAmber`() {
        // Server payloads pre-Round-326 didn't attach the stage key;
        // those should fall back to the safer non-Danger tint.
        val s = style("amc_renewal_due", emptyMap())
        assertEquals(NotificationIconTone.WarnAmber, s.tone)
    }

    @Test fun `AMC SLA breach + admin escalation use Build + DangerRed`() {
        listOf("amc_sla_breach", "amc_admin_escalation_raised").forEach { kind ->
            val s = style(kind)
            assertEquals(NotificationIconShape.Build, s.shape)
            assertEquals(NotificationIconTone.DangerRed, s.tone)
        }
    }

    // ---- D-series flows ----

    @Test fun `cash_survey uses HelpOutline + WarnAmber`() {
        val s = style("cash_survey")
        assertEquals(NotificationIconShape.HelpOutline, s.shape)
        assertEquals(NotificationIconTone.WarnAmber, s.tone)
    }

    @Test fun `spot_audit_invited uses Star + InfoBlue`() {
        val s = style("spot_audit_invited")
        assertEquals(NotificationIconShape.Star, s.shape)
        assertEquals(NotificationIconTone.InfoBlue, s.tone)
    }

    @Test fun `auto_suspend kinds use Block + DangerRed`() {
        listOf("engineer_auto_suspended", "admin_engineer_auto_suspended").forEach { kind ->
            val s = style(kind)
            assertEquals(NotificationIconShape.Block, s.shape)
            assertEquals(NotificationIconTone.DangerRed, s.tone)
        }
    }

    // ---- escrow disputes ----

    @Test fun `dispute_opened kinds use Gavel + DangerRed`() {
        listOf("escrow_dispute_opened", "admin_escrow_dispute_opened").forEach { kind ->
            val s = style(kind)
            assertEquals(NotificationIconShape.Gavel, s.shape)
            assertEquals(NotificationIconTone.DangerRed, s.tone)
        }
    }

    @Test fun `dispute_resolved uses Gavel + GreenPositive (positive resolution)`() {
        val s = style("escrow_dispute_resolved")
        assertEquals(NotificationIconShape.Gavel, s.shape)
        assertEquals(NotificationIconTone.GreenPositive, s.tone)
    }

    // ---- fallback ----

    @Test fun `unknown kind falls back to Bolt + GreenPositive`() {
        val s = style("future_kind")
        assertEquals(NotificationIconShape.Bolt, s.shape)
        assertEquals(NotificationIconTone.GreenPositive, s.tone)
    }

    @Test fun `null kind falls back to the same generic style`() {
        val s = notificationIconStyle(null)
        assertEquals(NotificationIconShape.Bolt, s.shape)
        assertEquals(NotificationIconTone.GreenPositive, s.tone)
    }
}
