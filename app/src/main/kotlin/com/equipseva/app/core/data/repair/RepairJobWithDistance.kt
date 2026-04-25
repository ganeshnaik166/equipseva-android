package com.equipseva.app.core.data.repair

/**
 * A repair-job row paired with its haversine distance (in km) from the
 * authenticated engineer's registered base coords, plus the hospital coords
 * resolved server-side. Returned by the `list_nearby_repair_jobs` RPC so
 * the feed can sort + filter + map by proximity without an extra round
 * trip.
 */
data class RepairJobWithDistance(
    val job: RepairJob,
    val distanceKm: Double,
    val hospitalLatitude: Double?,
    val hospitalLongitude: Double?,
)
