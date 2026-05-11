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
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.equipseva.app.core.data.prefs.ThemeMode
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.observability.StartupTelemetry
import com.equipseva.app.core.payments.PaymentBridge
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
        deepLinkRouter.dispatch(intent)
        maybeRequestNotificationPermission()
        setContent {
            val themeMode by userPrefs.themeMode.collectAsState(initial = ThemeMode.Light)
            val systemDark = isSystemInDarkTheme()
            val isDark = when (themeMode) {
                ThemeMode.System -> systemDark
                ThemeMode.Light -> false
                ThemeMode.Dark -> true
            }
            EquipSevaTheme(darkTheme = isDark) {
                AppNavGraph()
            }
        }
        StartupTelemetry.markReady()
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
