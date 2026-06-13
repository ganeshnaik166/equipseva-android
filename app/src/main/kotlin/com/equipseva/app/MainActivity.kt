package com.equipseva.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.equipseva.app.core.data.analytics.AnalyticsClient
import com.equipseva.app.core.data.analytics.AnalyticsEvent
import com.equipseva.app.core.data.prefs.ThemeMode
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.observability.StartupTelemetry
import com.equipseva.app.core.payments.PaymentBridge
import com.equipseva.app.core.security.DevModeBlockingScreen
import com.equipseva.app.core.security.DeviceIntegrityCheck
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import com.equipseva.app.navigation.AppNavGraph
import com.equipseva.app.navigation.DeepLinkRouter
import com.razorpay.PaymentData
import com.razorpay.PaymentResultWithDataListener
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity(), PaymentResultWithDataListener {

    @Inject lateinit var userPrefs: UserPrefs
    @Inject lateinit var deepLinkRouter: DeepLinkRouter
    @Inject lateinit var analytics: AnalyticsClient

    // Round 470: dev-mode verdict driven by mutableStateOf so onResume
    // updates propagate to the Composition (Setting flipped in another
    // app → user returns → verdict updates → blocker shows/hides).
    private val devModeVerdict = mutableStateOf<DeviceIntegrityCheck.Verdict?>(null)

    // Android 13+ requires runtime grant for POST_NOTIFICATIONS. Without it
    // the app is silently muted — every push the server fires gets dropped
    // before we can render it. Result intentionally ignored: a denial just
    // means we won't post; we don't gate any other UX on this permission.
    private val notificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { /* result is fire-and-forget */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // Round 470: compute dev-mode verdict before setContent so the
        // first frame is either the blocker or the nav graph, not flicker.
        devModeVerdict.value = DeviceIntegrityCheck.run(this)
        deepLinkRouter.dispatch(intent)
        maybeRequestNotificationPermission()
        // r513 (v0.4 P5 #10 client wire) — fire-and-forget funnel ping.
        analytics.track(AnalyticsEvent.APP_OPEN)
        setContent {
            val themeMode by userPrefs.themeMode.collectAsStateWithLifecycle(initialValue = ThemeMode.Light)
            val systemDark = isSystemInDarkTheme()
            val isDark = when (themeMode) {
                ThemeMode.System -> systemDark
                ThemeMode.Light -> false
                ThemeMode.Dark -> true
            }
            EquipSevaTheme(darkTheme = isDark) {
                // Round 470: hard-block when device has USB debugging or
                // Developer Options enabled (release builds only).
                // devModeVerdict updates on onCreate + onResume, so toggling
                // the Setting in another app flips the blocker on next
                // app foreground.
                val verdict = devModeVerdict.value
                if (verdict != null && verdict.devModeBlocking) {
                    DevModeBlockingScreen(verdict = verdict)
                } else {
                    AppNavGraph()
                }
            }
        }
        StartupTelemetry.markReady()
    }

    override fun onResume() {
        super.onResume()
        // Round 470: re-evaluate dev-mode verdict on every resume so a
        // user toggling Developer Options in Settings while the app is
        // backgrounded gets the new state on return. The mutableState
        // write triggers Compose recompose; if the verdict flipped from
        // blocking → clean, the nav graph renders. Flipped clean →
        // blocking, the blocker renders. No recreate() needed.
        devModeVerdict.value = DeviceIntegrityCheck.run(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        deepLinkRouter.dispatch(intent)
    }

    // ---- Razorpay Standard Checkout result hooks (PR-C6 AMC payments).
    //  The Razorpay SDK posts checkout outcomes back to the *calling
    //  Activity*. Implementing PaymentResultWithDataListener here lets
    //  us forward both callbacks straight into PaymentBridge, which the
    //  RazorpayCheckoutLauncher uses to complete its CompletableDeferred.
    override fun onPaymentSuccess(razorpayPaymentId: String?, paymentData: PaymentData?) {
        PaymentBridge.completeSuccess(
            razorpayPaymentId = razorpayPaymentId,
            paymentDataJson = paymentData?.data?.toString(),
        )
    }

    override fun onPaymentError(code: Int, response: String?, paymentData: PaymentData?) {
        PaymentBridge.completeFailure(code = code, response = response)
    }

    private fun maybeRequestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) return
        // Don't re-prompt on every cold start once the user has already
        // declined. `shouldShowRequestPermissionRationale` returns true
        // only after the system has shown the dialog at least once and
        // the user picked "Don't allow." Honour that — a third prompt
        // is the kind of thing that gets uninstall-rated on Play.
        if (shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)) return
        notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
    }
}
