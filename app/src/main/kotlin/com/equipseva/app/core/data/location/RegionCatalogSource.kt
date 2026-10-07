package com.equipseva.app.core.data.location

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.FileNotFoundException
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/** Reads the bundled catalogue asset's text; null when no asset is bundled. */
fun interface RegionAssetReader {
    @Throws(IOException::class)
    fun read(): String?
}

class AndroidRegionAssetReader @Inject constructor(
    @ApplicationContext private val context: Context,
) : RegionAssetReader {
    override fun read(): String? = try {
        context.assets.open(ASSET_PATH).bufferedReader(Charsets.UTF_8).use { it.readText() }
    } catch (_: FileNotFoundException) {
        null
    }

    companion object {
        const val ASSET_PATH = "regions/india_regions.json"
    }
}

/** Whether a synthetic (test) catalogue may be used; only debug builds allow it. */
data class RegionCatalogPolicy(val allowSynthetic: Boolean)

fun interface RegionCatalogProblemReporter {
    fun report(problem: Throwable)
}

/**
 * The device's region catalogue, loaded once from the bundled asset. Returns null when no
 * asset is bundled (the state until an owner-approved, dated LGD snapshot ships), when the
 * asset is unreadable or invalid (reported, never repaired), or when a synthetic catalogue
 * would reach a release build. Callers fall back to their existing label-based flow on null.
 */
@Singleton
class RegionCatalogSource @Inject constructor(
    private val reader: RegionAssetReader,
    private val policy: RegionCatalogPolicy,
    private val reporter: RegionCatalogProblemReporter,
) {
    private val mutex = Mutex()

    /** Where the asset is read; tests may run it inline. */
    internal var ioDispatcher: CoroutineDispatcher = Dispatchers.IO

    @Volatile
    private var loaded = false
    private var cached: RegionCatalog? = null

    suspend fun catalog(): RegionCatalog? {
        if (loaded) return cached
        return mutex.withLock {
            if (!loaded) {
                cached = withContext(ioDispatcher) { load() }
                loaded = true
            }
            cached
        }
    }

    internal fun load(): RegionCatalog? {
        val text = try {
            reader.read()
        } catch (e: IOException) {
            reporter.report(e)
            return null
        } catch (e: RuntimeException) {
            // Any other reader failure is also reported once and cached as "no catalogue".
            reporter.report(e)
            return null
        } ?: return null
        val catalog = try {
            RegionCatalogParser.parse(text)
        } catch (e: RegionCatalogFormatException) {
            reporter.report(e)
            return null
        }
        if (catalog.isSynthetic && !policy.allowSynthetic) {
            reporter.report(RegionCatalogFormatException("synthetic catalogue ${catalog.version} refused in this build"))
            return null
        }
        return catalog
    }
}
