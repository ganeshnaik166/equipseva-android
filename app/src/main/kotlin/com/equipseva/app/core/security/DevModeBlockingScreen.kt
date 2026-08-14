package com.equipseva.app.core.security

import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.equipseva.app.R

/**
 * Round 470: full-screen blocker shown when the device has Developer Options
 * or USB debugging enabled (release builds only — debug builds skip).
 *
 * Why: USB debugging + Developer Options give MITM tools (Frida, mitmproxy,
 * adb proxy injection) free access to instrument the app's network traffic
 * and process memory. EquipSeva handles real-money flows (Razorpay payments,
 * Cashfree dispatch, GST invoices) — letting the app run under those
 * conditions is a fraud surface. The blocker isn't unbypassable (rooted
 * users can spoof the Settings values) but it's a strong deterrent for
 * casual abuse + a clear UX signal that something needs disabling.
 *
 * Behavior:
 *   - One headline "Developer Options must be disabled" + body explaining
 *     why for payments security
 *   - "Open Settings" button → Intent(ACTION_DEVELOPMENT_SETTINGS) deep
 *     link to the user's Developer Options page
 *   - Re-checks on MainActivity.onResume so as soon as the user disables
 *     and returns to the app, they're let through
 */
@Composable
fun DevModeBlockingScreen(verdict: DeviceIntegrityCheck.Verdict) {
    val context = LocalContext.current
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.surface)
            .systemBarsPadding()
            .padding(horizontal = 24.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Icon(
                imageVector = Icons.Filled.Warning,
                contentDescription = null,
                tint = Color(0xFFE0A800),
                modifier = Modifier
                    .height(72.dp)
                    .padding(bottom = 24.dp),
            )
            Text(
                text = stringResource(R.string.devmode_block_title),
                style = MaterialTheme.typography.headlineSmall,
                fontSize = 22.sp,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(16.dp))
            Text(
                text = stringResource(R.string.devmode_block_reason),
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(Modifier.height(24.dp))
            // What's currently on (debug detail; helps user know what to switch off)
            val detailLines = buildList {
                if (verdict.usbDebuggingEnabled) add("• USB debugging is ON")
                if (verdict.devOptionsEnabled) add("• Developer Options is ON")
            }
            if (detailLines.isNotEmpty()) {
                Text(
                    text = detailLines.joinToString("\n"),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(24.dp))
            }
            Text(
                text = stringResource(R.string.devmode_block_steps),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(32.dp))
            Button(
                onClick = {
                    runCatching {
                        val intent = Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(intent)
                    }.onFailure {
                        // Fallback if the device hides the direct deep link.
                        runCatching {
                            context.startActivity(
                                Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                            )
                        }
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                ),
            ) {
                Text(stringResource(R.string.devmode_open_settings_button))
            }
            Spacer(Modifier.height(12.dp))
            Text(
                text = stringResource(R.string.devmode_return_note),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}
