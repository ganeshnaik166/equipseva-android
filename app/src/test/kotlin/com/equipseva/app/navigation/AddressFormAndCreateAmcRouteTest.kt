package com.equipseva.app.navigation

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AddressFormAndCreateAmcRouteTest {

    // ---- Routes.addressFormRoute -------------------------------------

    @Test fun `null addressId returns base route (new address)`() {
        assertEquals(
            "profile/addresses/form",
            Routes.addressFormRoute(null),
        )
    }

    @Test fun `non-null addressId returns route with addressId query param`() {
        assertEquals(
            "profile/addresses/form?addressId=abc-123",
            Routes.addressFormRoute("abc-123"),
        )
    }

    @Test fun `empty addressId is taken verbatim (not folded to null)`() {
        // Pin exact null gate — empty string is preserved. The
        // address form upstream gates on this; pin total shape.
        assertEquals(
            "profile/addresses/form?addressId=",
            Routes.addressFormRoute(""),
        )
    }

    // ---- Routes.createAmcRoute ---------------------------------------

    @Test fun `createAmcRoute appends engineer id as path segment`() {
        assertEquals(
            "amc/create/eng-abc-123",
            Routes.createAmcRoute("eng-abc-123"),
        )
    }

    // ---- Routes.createAmcRouteWithSource -----------------------------

    @Test fun `createAmcRouteWithSource appends engineer id + sourceContractId query`() {
        assertEquals(
            "amc/create/eng-abc-123?sourceContractId=amc-old-456",
            Routes.createAmcRouteWithSource("eng-abc-123", "amc-old-456"),
        )
    }

    @Test fun `createAmcRouteWithSource preserves the sourceContractId query name`() {
        // Critical pin — the receiving screen reads the arg by name.
        val out = Routes.createAmcRouteWithSource("eng-X", "amc-Y")
        assertTrue(out.contains("sourceContractId=amc-Y"))
    }

    // ---- Routes.amcContractDetailRoute -------------------------------

    @Test fun `amcContractDetailRoute appends contract id as path segment`() {
        assertEquals(
            "amc/contract/contract-abc-123",
            Routes.amcContractDetailRoute("contract-abc-123"),
        )
    }
}
