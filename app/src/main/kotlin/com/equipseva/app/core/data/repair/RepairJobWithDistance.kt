package com.equipseva.app.core.data.repair

/**
 * A repair-job row paired with its haversine distance (in km) from the
 * authenticated engineer's registered base coords. Returned by the
 * `list_nearby_repair_jobs` RPC so the feed can sort + filter by proximity
 * without an extra round trip.
 */
data class RepairJobWithDistance(
    val job: RepairJob,
    val distanceKm: Double,
)
