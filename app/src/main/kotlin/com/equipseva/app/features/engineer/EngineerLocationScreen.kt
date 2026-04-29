package com.equipseva.app.features.engineer

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.ErrorBanner
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900
import com.equipseva.app.features.repair.components.LocationPickerMap
import com.google.android.gms.maps.model.LatLng

@Composable
fun EngineerLocationScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit = {},
    viewModel: EngineerLocationViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is EngineerLocationViewModel.Effect.ShowMessage -> onShowMessage(effect.text)
                EngineerLocationViewModel.Effect.NavigateBack -> onBack()
            }
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Service location", onBack = onBack)

            if (state.loading) {
                Box(
                    modifier = Modifier.fillMaxWidth().padding(40.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator()
                }
                return@Column
            }

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(
                    text = "Drag the pin or use the location button to set the centre of your service area. The radius circle on Available Jobs always anchors here.",
                    style = EsType.BodySm,
                    color = SevaInk500,
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
                )

                ErrorBanner(message = state.errorMessage)

                val selected = state.pickedLatitude?.let { lat ->
                    state.pickedLongitude?.let { lng -> LatLng(lat, lng) }
                }
                LocationPickerMap(
                    selected = selected,
                    onLocationPicked = { viewModel.onPick(it.latitude, it.longitude) },
                )

                Spacer(Modifier.height(8.dp))

                Box(modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp)) {
                    EsBtn(
                        text = if (state.saving) "Saving…" else "Save service location",
                        onClick = viewModel::onSave,
                        kind = EsBtnKind.Primary,
                        size = EsBtnSize.Lg,
                        full = true,
                        disabled = !state.canSave,
                    )
                }

                if (state.savedLatitude != null && state.savedLongitude != null) {
                    Text(
                        text = "Currently saved: %.5f, %.5f".format(
                            state.savedLatitude,
                            state.savedLongitude,
                        ),
                        style = EsType.Caption,
                        color = SevaInk900,
                        modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
                    )
                }

                Spacer(Modifier.height(24.dp))
            }
        }
    }
}
