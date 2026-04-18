package com.equipseva.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.equipseva.app.core.data.prefs.ThemeMode
import com.equipseva.app.core.data.prefs.UserPrefs
import com.equipseva.app.core.payments.RazorpayLauncher
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
    @Inject lateinit var razorpayLauncher: RazorpayLauncher
    @Inject lateinit var deepLinkRouter: DeepLinkRouter

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        deepLinkRouter.dispatch(intent)
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
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        deepLinkRouter.dispatch(intent)
    }

    override fun onPaymentSuccess(razorpayPaymentId: String?, paymentData: PaymentData?) {
        razorpayLauncher.onPaymentSuccess(
            razorpayPaymentId = razorpayPaymentId.orEmpty(),
            signature = paymentData?.signature,
        )
    }

    override fun onPaymentError(code: Int, description: String?, paymentData: PaymentData?) {
        razorpayLauncher.onPaymentError(
            code = code,
            description = description.orEmpty(),
        )
    }
}
