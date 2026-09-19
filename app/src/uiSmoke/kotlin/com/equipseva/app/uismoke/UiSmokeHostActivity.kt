package com.equipseva.app.uismoke

import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import com.equipseva.app.designsystem.theme.EquipSevaTheme
import dagger.hilt.android.AndroidEntryPoint

/** No production startup, repositories, navigation or account is mounted here. */
@AndroidEntryPoint
class UiSmokeHostActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        check(packageName == "com.equipseva.app.uismoke")
        check(application.javaClass.name == "dagger.hilt.android.testing.HiltTestApplication")
        check(checkSelfPermission(android.Manifest.permission.INTERNET) == PackageManager.PERMISSION_DENIED)
        super.onCreate(savedInstanceState)
        mount { Text("Isolated UI smoke host") }
    }

    /** Tests install explicit fixtures before mounting any real screen. */
    fun mount(content: @Composable () -> Unit) {
        setContent { EquipSevaTheme { content() } }
    }
}
