package com.equipseva.app.core.data.openfda

import retrofit2.http.GET
import retrofit2.http.Query

/**
 * OpenFDA Device UDI endpoint.  Documented at
 *   https://open.fda.gov/apis/device/udi/
 *
 * No API key required for low traffic; rate limit ~240 req/min, 1000 req/day per
 * IP. For higher quotas, set OPENFDA_API_KEY in local.properties (free at
 * https://open.fda.gov/apis/authentication/) and pass it as the `apiKey` param.
 *
 * Search syntax examples:
 *   brand_name:"IntelliVue"
 *   company_name.exact:"Mindray"
 *   _exists_:gmdn_terms.name
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
