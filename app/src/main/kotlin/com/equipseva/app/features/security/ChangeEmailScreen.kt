package com.equipseva.app.features.security

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.components.SecureScreen
import com.equipseva.app.designsystem.theme.BorderDefault
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
        Box(modifier = Modifier.fillMaxSize()) {
            Column(modifier = Modifier.fillMaxSize()) {
                EsTopBar(title = "Change email", onBack = onBack)
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(16.dp)
                        .padding(bottom = 90.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    Text(
                        text = "Updates the contact email shown on your profile. " +
                            "Your sign-in email stays unchanged.",
                        style = EsType.BodySm,
                        color = SevaInk500,
                    )

                    OutlinedTextField(
                        value = state.currentPassword,
                        onValueChange = viewModel::onPasswordChange,
                        label = { Text("Current password") },
                        singleLine = true,
                        enabled = !state.submitting,
                        isError = state.passwordError != null,
                        supportingText = {
                            state.passwordError?.let { Text(it) }
                        },
                        visualTransformation = PasswordVisualTransformation(),
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Password,
                            imeAction = ImeAction.Next,
                        ),
                        modifier = Modifier.fillMaxWidth(),
                    )

                    OutlinedTextField(
                        value = state.newEmail,
                        onValueChange = viewModel::onEmailChange,
                        // The body above is explicit that this updates
                        // the contact email and the sign-in email is
                        // separate — but the field label still said the
                        // bare "New email", which read as "the email I
                        // sign in with". Naming the field for the
                        // narrower thing keeps the two emails distinct
                        // for users skimming.
                        label = { Text("New contact email") },
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
                }
            }

            // Sticky-bottom CTA matching design's fixed-bottom pattern.
            Column(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .background(Color.White),
            ) {
                Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(BorderDefault))
                Box(modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
                    EsBtn(
                        text = if (state.submitting) "Saving…" else "Save email",
                        onClick = viewModel::onSubmit,
                        kind = EsBtnKind.Primary,
                        size = EsBtnSize.Lg,
                        full = true,
                        disabled = state.submitting || state.newEmail.isBlank() || state.currentPassword.isBlank(),
                    )
                }
            }
        }
    }
}
