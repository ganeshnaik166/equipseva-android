package com.equipseva.app.features.profile

import com.equipseva.app.designsystem.components.PillKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Pins for the r1392 invoice direction pill. */
class GstInvoiceLedgerHelpersTest {

    @Test fun `outgoing reads Outgoing with Forest tone`() {
        assertEquals("Outgoing" to PillKind.Forest, invoiceDirectionPill("outgoing"))
    }

    @Test fun `incoming reads Incoming with Info tone`() {
        assertEquals("Incoming" to PillKind.Info, invoiceDirectionPill("incoming"))
    }

    @Test fun `unknown direction capitalises with a Neutral tone`() {
        assertEquals("Weird" to PillKind.Neutral, invoiceDirectionPill("weird"))
    }
}
