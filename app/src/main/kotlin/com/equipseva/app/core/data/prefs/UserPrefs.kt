package com.equipseva.app.core.data.prefs

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.prefsStore by preferencesDataStore(name = "equipseva_prefs")

/**
 * `activeRole`, `onboardingDone`, and `favorites` are read from [SecurePrefs]
 * first; any value still in the legacy DataStore is surfaced as a fallback.
 * Writes land in [SecurePrefs] and clear the legacy DataStore key in the same
 * operation, so installs migrate silently on the first set/toggle. `theme`
 * stays in DataStore — not sensitive, keeping the theme toggle cheap.
 */
@Singleton
class UserPrefs @Inject constructor(
    @ApplicationContext private val context: Context,
    private val securePrefs: SecurePrefs,
) {
    private object Keys {
        val ACTIVE_ROLE = stringPreferencesKey("active_role")
        val THEME = stringPreferencesKey("theme")
        val ONBOARDING_DONE = stringPreferencesKey("onboarding_done")
        val FAVORITES = stringSetPreferencesKey("favorites")
        val MUTED_PUSH_CATEGORIES = stringSetPreferencesKey("muted_push_categories")
        val TOUR_SEEN = booleanPreferencesKey("tour_seen")
        val QUIET_HOURS_ENABLED = booleanPreferencesKey("quiet_hours_enabled")
        val QUIET_HOURS_START_MINUTES = intPreferencesKey("quiet_hours_start_minutes")
        val QUIET_HOURS_END_MINUTES = intPreferencesKey("quiet_hours_end_minutes")
    }

    private object QuietHoursDefaults {
        const val START_MINUTES = 22 * 60 // 22:00 local
        const val END_MINUTES = 7 * 60 // 07:00 local
    }

    private object SecureKeys {
        const val ACTIVE_ROLE = "active_role"
        const val ONBOARDING_DONE = "onboarding_done"
        const val FAVORITES = "favorites"
    }

    val activeRole: Flow<String?> = combine(
        securePrefs.stringFlow(SecureKeys.ACTIVE_ROLE),
        context.prefsStore.data.map { it[Keys.ACTIVE_ROLE] },
    ) { secure, legacy -> secure ?: legacy }

    val theme: Flow<String?> = context.prefsStore.data.map { it[Keys.THEME] }
    val themeMode: Flow<ThemeMode> =
        context.prefsStore.data.map { ThemeMode.fromKey(it[Keys.THEME]) }

    val onboardingDone: Flow<Boolean> = combine(
        securePrefs.stringFlow(SecureKeys.ONBOARDING_DONE),
        context.prefsStore.data.map { it[Keys.ONBOARDING_DONE] == "1" },
    ) { secure, legacy -> secure == "1" || legacy }

    val favorites: Flow<Set<String>> = combine(
        securePrefs.stringSetFlow(SecureKeys.FAVORITES),
        context.prefsStore.data.map { it[Keys.FAVORITES].orEmpty() },
    ) { secure, legacy -> if (secure.isNotEmpty()) secure else legacy }

    suspend fun setActiveRole(role: String) {
        securePrefs.putString(SecureKeys.ACTIVE_ROLE, role)
        context.prefsStore.edit { it.remove(Keys.ACTIVE_ROLE) }
    }

    suspend fun clearActiveRole() {
        securePrefs.putString(SecureKeys.ACTIVE_ROLE, null)
        context.prefsStore.edit { it.remove(Keys.ACTIVE_ROLE) }
    }

    suspend fun setThemeMode(mode: ThemeMode) {
        context.prefsStore.edit { it[Keys.THEME] = mode.storageKey }
    }

    suspend fun markOnboardingDone() {
        securePrefs.putString(SecureKeys.ONBOARDING_DONE, "1")
        context.prefsStore.edit { it.remove(Keys.ONBOARDING_DONE) }
    }

    suspend fun toggleFavorite(partId: String) {
        val cur = favorites.first()
        val next = if (partId in cur) cur - partId else cur + partId
        securePrefs.putStringSet(SecureKeys.FAVORITES, next)
        context.prefsStore.edit { it.remove(Keys.FAVORITES) }
    }

    suspend fun setFavorites(ids: Set<String>) {
        securePrefs.putStringSet(SecureKeys.FAVORITES, ids)
        context.prefsStore.edit { it.remove(Keys.FAVORITES) }
    }

    /**
     * Set of push notification channel ids the user has muted in Settings.
     * Empty set means no categories muted. Values align with
     * [com.equipseva.app.core.push.NotificationChannels] ids so
     * `EquipSevaMessagingService` can drop incoming messages client-side.
     */
    fun observeMutedPushCategories(): Flow<Set<String>> =
        context.prefsStore.data.map { it[Keys.MUTED_PUSH_CATEGORIES].orEmpty() }

    suspend fun setMutedPushCategories(categories: Set<String>) {
        context.prefsStore.edit { prefs ->
            if (categories.isEmpty()) {
                prefs.remove(Keys.MUTED_PUSH_CATEGORIES)
            } else {
                prefs[Keys.MUTED_PUSH_CATEGORIES] = categories
            }
        }
    }

    /**
     * First-run feature tour. Independent from [onboardingDone] (which gates
     * RoleSelect). Set once per device install — Skip and Get-started both
     * flip this so the tour never reappears.
     */
    fun observeTourSeen(): Flow<Boolean> =
        context.prefsStore.data.map { it[Keys.TOUR_SEEN] == true }

    suspend fun setTourSeen() {
        context.prefsStore.edit { it[Keys.TOUR_SEEN] = true }
    }

    /**
     * Daily quiet-hours window. Values are stored as ints in [0, 1439] for
     * local minutes-of-day so a timezone change reads naturally to the user
     * (e.g. "22:00 stays 22:00 wherever I land"). Wrap-around windows like
     * 22:00→07:00 are valid and interpreted by [QuietHours.isWithinWindow].
     * Pure client-side: never synced to Supabase.
     */
    fun observeQuietHours(): Flow<QuietHoursPrefs> = context.prefsStore.data.map { prefs ->
        QuietHoursPrefs(
            enabled = prefs[Keys.QUIET_HOURS_ENABLED] ?: false,
            startMinutes = prefs[Keys.QUIET_HOURS_START_MINUTES] ?: QuietHoursDefaults.START_MINUTES,
            endMinutes = prefs[Keys.QUIET_HOURS_END_MINUTES] ?: QuietHoursDefaults.END_MINUTES,
        )
    }

    suspend fun setQuietHoursEnabled(on: Boolean) {
        context.prefsStore.edit { it[Keys.QUIET_HOURS_ENABLED] = on }
    }

    suspend fun setQuietHoursWindow(startMin: Int, endMin: Int) {
        val safeStart = startMin.coerceIn(0, 24 * 60 - 1)
        val safeEnd = endMin.coerceIn(0, 24 * 60 - 1)
        context.prefsStore.edit { prefs ->
            prefs[Keys.QUIET_HOURS_START_MINUTES] = safeStart
            prefs[Keys.QUIET_HOURS_END_MINUTES] = safeEnd
        }
    }
}

/** Snapshot of the user's quiet-hours preferences. */
data class QuietHoursPrefs(
    val enabled: Boolean,
    val startMinutes: Int,
    val endMinutes: Int,
)

@Module
@InstallIn(SingletonComponent::class)
object PrefsModule {
    @Provides
    @Singleton
    fun provideUserPrefs(
        @ApplicationContext context: Context,
        securePrefs: SecurePrefs,
    ): UserPrefs = UserPrefs(context, securePrefs)
}
