package com.equipseva.app.features.amc

import com.equipseva.app.features.auth.UserRole
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MaintenanceContractsEmptySubtitleTest {

    @Test fun `engineer reads passive will appear here framing`() {
        // Critical pin — engineer is passive; hospital initiates.
        val out = maintenanceContractsEmptySubtitle(UserRole.ENGINEER)
        assertTrue(out.endsWith("will appear here."))
    }

    @Test fun `hospital reads active set up framing`() {
        // Critical pin — hospital is the initiator.
        val out = maintenanceContractsEmptySubtitle(UserRole.HOSPITAL)
        assertTrue(out.startsWith("Set up "))
    }

    @Test fun `null role defaults to hospital framing`() {
        // Cold-load before session resolves; hospital is the
        // majority case and the active-CTA copy.
        assertEquals(
            maintenanceContractsEmptySubtitle(UserRole.HOSPITAL),
            maintenanceContractsEmptySubtitle(null),
        )
    }

    @Test fun `engineer copy mentions primary or fallback`() {
        // Pin the role-vocabulary anchor — matches the
        // engineerRolePillLabel on the contract detail screen.
        val out = maintenanceContractsEmptySubtitle(UserRole.ENGINEER)
        assertTrue(out.contains("primary or fallback engineer"))
    }

    @Test fun `hospital copy mentions verified engineer`() {
        // Pin "verified" — implies KYC-checked, load-bearing trust
        // signal in the hospital's mental model.
        val out = maintenanceContractsEmptySubtitle(UserRole.HOSPITAL)
        assertTrue(out.contains("verified engineer"))
    }
}
