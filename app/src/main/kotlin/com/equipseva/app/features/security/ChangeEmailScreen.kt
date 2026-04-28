package com.equipseva.app.features.security

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.SecureScreen
import com.equipseva.app.designsystem.theme.EsType
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaInk500

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChangeEmailScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: ChangeEmailViewModel = hiltViewModel(),
) {
    SecureScreen()
    val state by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is ChangeEmailViewModel.Effect.Success -> {
                    onShowMessage(effect.message)
                    onBack()
                }
            }
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Change email", onBack = onBack)
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = "We'll send a confirmation link to the new address. " +
                        "Your email stays the same until you click it.",
                    style = EsType.BodySm,
                    color = SevaInk500,
                )

                OutlinedTextField(
                    value = state.newEmail,
                    onValueChange = viewModel::onEmailChange,
                    label = { Text("New email") },
                    singleLine = true,
                    enabled = !state.submitting,
                    isError = state.emailError != null,
                    supportingText = {
                        state.emailError?.let { Text(it) }
                    },
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.None,
                        autoCorrect = false,
                        keyboardType = KeyboardType.Email,
                        imeAction = ImeAction.Done,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                )

                if (state.errorMessage != null) {
                    Text(
                        state.errorMessage!!,
                        style = EsType.Caption,
                        color = SevaDanger500,
                    )
                }

                Spacer(Modifier.size(8.dp))

                EsBtn(
                    text = if (state.submitting) "Sending…" else "Send confirmation link",
                    onClick = viewModel::onSubmit,
                    kind = EsBtnKind.Primary,
                    size = EsBtnSize.Lg,
                    full = true,
                    disabled = state.submitting || state.newEmail.isBlank(),
                )
            }
        }
    }
}
