package com.medeq.app.data.remote

import retrofit2.http.GET
import retrofit2.http.Query

/**
 * OpenFDA Device UDI endpoint.  Documented at:
 * https://open.fda.gov/apis/device/udi/
 *
 * `search` syntax examples:
 *   brand_name:"IntelliVue"
 *   company_name.exact:"Mindray"
 *   _exists_:gmdn_terms.name
 *
 * No API key required for low traffic; rate limit 240 req/min, 1000 req/day per IP.
 * For higher quotas, add api_key= to query (free at https://open.fda.gov/apis/authentication/).
 */
interface OpenFdaApi {

    @GET("device/udi.json")
    suspend fun searchUdi(
        @Query("search") search: String,
        @Query("limit") limit: Int = 25,
        @Query("skip") skip: Int = 0,
        @Query("api_key") apiKey: String? = null,
    ): OpenFdaUdiResponse
}
