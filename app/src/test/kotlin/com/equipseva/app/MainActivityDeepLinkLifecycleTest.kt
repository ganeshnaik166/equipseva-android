package com.equipseva.app

import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Bundle
import androidx.work.WorkManager
import com.equipseva.app.core.auth.AuthModule
import com.equipseva.app.core.auth.AuthRepository
import com.equipseva.app.core.auth.AuthSession
import com.equipseva.app.core.auth.LoginTicketSnapshot
import com.equipseva.app.core.auth.LoginTicketSource
import com.equipseva.app.core.data.analytics.AnalyticsClient
import com.equipseva.app.core.data.AppDatabase
import com.equipseva.app.core.data.DatabaseModule
import com.equipseva.app.core.data.dao.DeviceTokenDao
import com.equipseva.app.core.data.dao.OutboxDao
import com.equipseva.app.core.sync.OutboxScheduler
import com.equipseva.app.core.sync.SyncModule
import com.equipseva.app.navigation.DeepLinkRouter
import com.equipseva.app.navigation.Routes
import com.equipseva.app.testing.FakeAuthRepository
import dagger.hilt.android.testing.BindValue
import dagger.hilt.android.testing.HiltAndroidRule
import dagger.hilt.android.testing.HiltAndroidTest
import dagger.hilt.android.testing.HiltTestApplication
import dagger.hilt.android.testing.UninstallModules
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.shadows.ActivityReflector
import org.robolectric.util.ReflectionHelpers
import org.robolectric.util.ReflectionHelpers.ClassParameter
import org.robolectric.util.reflector.Reflector
import javax.inject.Inject

/**
 * Exercises MainActivity's real save/retain/destroy/create hooks. The router-only
 * tests cannot catch an Activity that forgets to pass its retained owner or
 * saved delivery identity to the router. Unknown auth keeps the Compose host
 * from claiming the tap, and the fake ticket source never contacts a server.
 *
 * Non-visible Robolectric lifecycle avoids draining the app's perpetual
 * Compose splash animation. This does not model OS task delivery, actual
 * process death, FCM, or AndroidKeyStore on a device.
 */
@HiltAndroidTest
@UninstallModules(AuthModule::class, DatabaseModule::class, SyncModule::class)
@RunWith(RobolectricTestRunner::class)
@Config(application = HiltTestApplication::class, sdk = [32])
class MainActivityDeepLinkLifecycleTest {
    private val userId = "11111111-1111-4111-8111-111111111111"
    private val deliveryId = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
    private val ticket = LoginTicketSnapshot(
        userId,
        "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    )
    private val route = Routes.repairJobDetailRoute("RPR-00027")
    private var sdkTicket: LoginTicketSnapshot? = null
    private var storedTicket: LoginTicketSnapshot? = ticket

    @get:Rule val hiltRule = HiltAndroidRule(this)

    @BindValue @JvmField val authRepository: AuthRepository =
        FakeAuthRepository(AuthSession.Unknown)
    @BindValue @JvmField val ticketSource: LoginTicketSource = mockk()
    @BindValue @JvmField val analytics: AnalyticsClient = mockk(relaxed = true)
    // The production DB opens SQLCipher native code, unavailable on the JVM.
    // These unused UI-startup dependencies stay offline for lifecycle testing.
    @BindValue @JvmField val database: AppDatabase = mockk(relaxed = true)
    @BindValue @JvmField val outboxDao: OutboxDao = mockk(relaxed = true)
    @BindValue @JvmField val deviceTokenDao: DeviceTokenDao = mockk(relaxed = true)
    @BindValue @JvmField val workManager: WorkManager = mockk(relaxed = true)
    @BindValue @JvmField val outboxScheduler: OutboxScheduler = mockk(relaxed = true)

    @Inject lateinit var router: DeepLinkRouter

    @Before fun setUp() {
        every { ticketSource.currentTicket() } answers { sdkTicket }
        every { ticketSource.provisionalStoredTicketDuringInitializing() } answers { storedTicket }
        hiltRule.inject()
    }

    @Test fun configuration_recreation_transfers_one_pending_push_to_the_new_Activity() {
        val tap = notificationTap()
        val controller = Robolectric.buildActivity(MainActivity::class.java, tap)
            .create().start().resume()
        try {
            @Suppress("DEPRECATION")
            val oldOwner = controller.get().onRetainCustomNonConfigurationInstance()
                as DeepLinkRouter.LaunchOwner

            val saved = Bundle()
            val oldActivity = controller.get()
            val oldReflector = Reflector.reflector(ActivityReflector::class.java, oldActivity)
            oldReflector.setChangingConfigurations(true)
            controller.pause().stop().saveInstanceState(saved)
            val retained = oldReflector.retainNonConfigurationInstances()
            assertNotNull("The old Activity did not supply a nonconfiguration object", retained)
            val retainedActivity = ReflectionHelpers.getField<Any>(retained, "activity")
            assertNotNull("The platform did not retain ComponentActivity state", retainedActivity)
            assertSame(oldOwner, ReflectionHelpers.getField<Any>(retainedActivity, "custom"))
            controller.destroy()

            val replacement = Robolectric.buildActivity(MainActivity::class.java, Intent(tap))
            // ActivityController.create() performs attach when needed. Supply
            // the retained object to that attach, as recreate() does; setting
            // the field before create would be overwritten by default attach.
            ReflectionHelpers.callInstanceMethod<Any>(
                replacement, "attach",
                ClassParameter.from(Bundle::class.java, saved),
                ClassParameter.from(Any::class.java, retained),
                ClassParameter.from(Configuration::class.java, null),
            )
            Reflector.reflector(ActivityReflector::class.java, replacement.get())
                .setLastNonConfigurationInstances(retained)
            replacement.create(saved).start().resume()
            val recreated = replacement.get()
            @Suppress("DEPRECATION")
            val newOwner = recreated.onRetainCustomNonConfigurationInstance()
                as DeepLinkRouter.LaunchOwner
            assertNotSame("A replacement Activity reused its old owner", oldOwner, newOwner)
            // The framework clears lastNonConfigurationInstances after
            // onCreate. The router's transferred claim below verifies that
            // MainActivity read the retained owner during that hook.

            sdkTicket = ticket
            storedTicket = null
            assertNull("The destroyed Activity retained claim authority", router.takeStartupFor(oldOwner, userId))
            assertEquals(route, router.takeStartupFor(newOwner, userId)?.route)
            assertNull("The same push was delivered twice", router.takeStartupFor(newOwner, userId))
            replacement.close()
        } finally {
            controller.close()
        }
    }

    @Test fun restored_Activity_without_a_retained_owner_cannot_replay_its_old_push() {
        val tap = notificationTap()
        val oldController = Robolectric.buildActivity(MainActivity::class.java, tap)
            .create().start().resume()
        val saved = Bundle()
        oldController.pause().saveInstanceState(saved).stop().destroy()

        // A new controller with saved state but no non-configuration object
        // models the entry path after process death. The JVM application and
        // Hilt singleton still exist, so this is not an OS process-death test.
        val replacement = Robolectric.buildActivity(MainActivity::class.java, Intent(tap))
            .create(saved).start().resume()
        try {
            @Suppress("DEPRECATION")
            val newOwner = replacement.get().onRetainCustomNonConfigurationInstance()
                as DeepLinkRouter.LaunchOwner
            @Suppress("DEPRECATION")
            val retainedOwner = replacement.get().lastCustomNonConfigurationInstance
            assertNull("A new task unexpectedly inherited an old owner", retainedOwner)

            sdkTicket = ticket
            storedTicket = null
            assertNull("Saved state alone resurrected an old push", router.takeStartupFor(newOwner, userId))
        } finally {
            replacement.close()
            oldController.close()
        }
    }

    @Test fun saved_only_replacement_cannot_claim_even_if_old_singleton_pending_still_exists() {
        val tap = notificationTap()
        val oldController = Robolectric.buildActivity(MainActivity::class.java, tap).create()
        val saved = Bundle()
        oldController.saveInstanceState(saved)
        // Simulate the old process vanishing before onDestroy. Robolectric's
        // singleton remains, making this a stronger null-owner boundary test.
        val replacement = Robolectric.buildActivity(MainActivity::class.java, Intent(tap))
            .create(saved)
        try {
            val newOwner = replacement.get().onRetainCustomNonConfigurationInstance()
                as DeepLinkRouter.LaunchOwner
            sdkTicket = ticket
            storedTicket = null
            assertNull(router.takeStartupFor(newOwner, userId))
        } finally {
            replacement.close()
            oldController.close()
        }
    }

    private fun notificationTap(): Intent = Intent()
        .setData(Uri.parse("equipseva-internal-notification://tap/$deliveryId"))
        .putExtra(DeepLinkRouter.EXTRA_ROUTE, route)
        .putExtra(DeepLinkRouter.EXTRA_RECIPIENT_USER_ID, userId)
}
