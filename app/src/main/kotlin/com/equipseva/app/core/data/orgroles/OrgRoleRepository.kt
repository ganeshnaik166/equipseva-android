package com.equipseva.app.core.data.orgroles

/**
 * Resolves role-linked row ids for the signed-in user:
 *  - `manufacturers.id` when the user's org is registered as a manufacturer
 *  - `logistics_partners.id` when the user is registered as a logistics partner
 *
 * These ids are distinct from user/org uuids and are used as FKs on role-specific
 * tables (rfq_bids, logistics_jobs). One lightweight query per call.
 */
interface OrgRoleRepository {
    /** Returns the manufacturer row id for the given organization, or null if none is registered. */
    suspend fun manufacturerIdForOrg(organizationId: String): Result<String?>

    /** Returns the manufacturer row's equipment_categories list for targeted RFQ matching. */
    suspend fun manufacturerCategoriesForOrg(organizationId: String): Result<List<String>>

    /** Returns the logistics partner row id for the given user, or null if none is registered. */
    suspend fun logisticsPartnerIdForUser(userId: String): Result<String?>
}
