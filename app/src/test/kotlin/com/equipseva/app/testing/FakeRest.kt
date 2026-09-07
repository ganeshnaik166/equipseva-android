package com.equipseva.app.testing

import io.github.jan.supabase.exceptions.RestException
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.post
import io.ktor.client.statement.HttpResponse
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.runBlocking

/**
 * round3816 — supabase-kt >= 3.1 made [RestException] carry the real ktor
 * [HttpResponse] (its `statusCode` and the URL/headers/method diagnostics
 * in `message` all derive from it), so tests can no longer build one from
 * bare (statusCode, message) arguments. This helper produces a response
 * through ktor's own MockEngine, which is the faithful way to get one
 * without a network.
 *
 * Note for assertions: `RestException.message` is now ALWAYS
 * `"<error>\n<description>\nURL: …\nHeaders: …\nHttp Method: POST"` —
 * never blank and never equal to the description alone.
 */
object FakeRest {

    const val URL = "https://fake.supabase.co/rest/v1/rpc/test_fn"

    fun response(statusCode: Int, body: String = ""): HttpResponse = runBlocking {
        val client = HttpClient(
            MockEngine { respond(content = body, status = HttpStatusCode.fromValue(statusCode)) },
        )
        try {
            client.post(URL)
        } finally {
            client.close()
        }
    }

    /**
     * A PostgREST-shaped [RestException]: `error` is the status text the SDK
     * fills in, `description` is the response body (where RAISE EXCEPTION
     * literals and SQLSTATE codes live).
     */
    fun rest(
        statusCode: Int,
        description: String?,
        error: String = "PostgrestError",
    ): RestException = RestException(error = error, description = description, response = response(statusCode))
}
