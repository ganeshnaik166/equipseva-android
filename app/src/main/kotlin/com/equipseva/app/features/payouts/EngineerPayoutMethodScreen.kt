package com.equipseva.app.features.payouts

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AccountBalance
import androidx.compose.material.icons.outlined.AccountBalanceWallet
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.equipseva.app.R
import com.equipseva.app.core.data.payouts.EngineerPayoutMethod
import com.equipseva.app.core.data.payouts.PayoutMethodKind
import com.equipseva.app.core.data.payouts.PayoutMethodVerification
import com.equipseva.app.designsystem.components.EsBtn
import com.equipseva.app.designsystem.components.EsBtnKind
import com.equipseva.app.designsystem.components.EsBtnSize
import com.equipseva.app.designsystem.components.EsField
import com.equipseva.app.designsystem.components.EsFieldType
import com.equipseva.app.designsystem.components.EsTopBar
import com.equipseva.app.designsystem.theme.BorderDefault
import com.equipseva.app.designsystem.theme.PaperDefault
import com.equipseva.app.designsystem.theme.SevaDanger50
import com.equipseva.app.designsystem.theme.SevaDanger500
import com.equipseva.app.designsystem.theme.SevaGreen50
import com.equipseva.app.designsystem.theme.SevaGreen700
import com.equipseva.app.designsystem.theme.SevaInk500
import com.equipseva.app.designsystem.theme.SevaInk900

@Composable
fun EngineerPayoutMethodScreen(
    onBack: () -> Unit,
    onShowMessage: (String) -> Unit,
    viewModel: EngineerPayoutMethodViewModel = hiltViewModel(),
) {
    val s by viewModel.state.collectAsStateWithLifecycle()

    LaunchedEffect(viewModel) {
        viewModel.effects.collect { e ->
            when (e) {
                is EngineerPayoutMethodViewModel.Effect.ShowMessage -> onShowMessage(e.text)
                EngineerPayoutMethodViewModel.Effect.Saved -> Unit
            }
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = PaperDefault) {
        Column(modifier = Modifier.fillMaxSize()) {
            EsTopBar(title = "Payout method", onBack = onBack)

            if (s.loading) {
                Column(
                    modifier = Modifier.fillMaxSize(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) { CircularProgressIndicator() }
                return@Surface
            }

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text(
                    stringResource(R.string.payout_method_send_earnings_question),
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = SevaInk900,
                )
                Text(
                    stringResource(R.string.payout_method_transfer_note),
                    fontSize = 13.sp,
                    color = SevaInk500,
                )

                if (s.current != null) {
                    CurrentDestinationCard(s.current!!)
                }

                Spacer(Modifier.height(4.dp))

                ModeToggle(selected = s.mode, onSelect = viewModel::onModeChange)

                when (s.mode) {
                    PayoutMethodKind.Upi -> UpiForm(
                        vpa = s.vpa,
                        vpaError = s.vpaError,
                        holderName = s.vpaHolderName,
                        saving = s.saving,
                        onVpaChange = viewModel::onVpaChange,
                        onHolderChange = viewModel::onVpaHolderChange,
                    )
                    PayoutMethodKind.Bank -> BankForm(
                        accountHolder = s.bankAccountHolder,
                        ifsc = s.bankIfsc,
                        accountNumber = s.bankAccountNumber,
                        accountNumberConfirm = s.bankAccountNumberConfirm,
                        bankName = s.bankName,
                        bankError = s.bankError,
                        saving = s.saving,
                        onHolderChange = viewModel::onBankAccountHolderChange,
                        onIfscChange = viewModel::onBankIfscChange,
                        onAccountChange = viewModel::onBankAccountNumberChange,
                        onAccountConfirmChange = viewModel::onBankAccountNumberConfirmChange,
                        onBankNameChange = viewModel::onBankNameChange,
                    )
                }

                if (s.errorMessage != null) {
                    Text(
                        s.errorMessage.orEmpty(),
                        fontSize = 13.sp,
                        color = SevaDanger500,
                    )
                }

                Spacer(Modifier.height(8.dp))

                val canSubmit = when (s.mode) {
                    PayoutMethodKind.Upi -> s.canSubmitUpi
                    PayoutMethodKind.Bank -> s.canSubmitBank
                }
                EsBtn(
                    text = if (s.saving) "Saving…" else "Save payout method",
                    onClick = viewModel::save,
                    kind = EsBtnKind.Primary,
                    size = EsBtnSize.Lg,
                    full = true,
                    disabled = !canSubmit,
                )

                Spacer(Modifier.height(8.dp))
                InfoNote()
            }
        }
    }
}

@Composable
private fun CurrentDestinationCard(method: EngineerPayoutMethod) {
    // r1459 — Chrome must match the verification status: a green success
    // card + green check next to red "Last payout failed" copy contradicts
    // itself.
    val isInvalid = method.verificationStatus == PayoutMethodVerification.Invalid
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (isInvalid) SevaDanger50 else SevaGreen50)
            .border(
                width = 1.dp,
                color = if (isInvalid) SevaDanger500 else BorderDefault,
                shape = RoundedCornerShape(12.dp),
            )
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            imageVector = if (isInvalid) Icons.Outlined.ErrorOutline else Icons.Outlined.CheckCircle,
            contentDescription = null,
            tint = if (isInvalid) SevaDanger500 else SevaGreen700,
            modifier = Modifier.size(20.dp),
        )
        Column(modifier = Modifier.fillMaxWidth()) {
            Text(
                when (method.kind) {
                    PayoutMethodKind.Upi -> stringResource(R.string.payout_method_current_upi)
                    PayoutMethodKind.Bank -> stringResource(R.string.payout_method_current_bank)
                },
                fontSize = 12.sp,
                color = SevaInk500,
            )
            Text(method.displayLine(), fontSize = 15.sp, color = SevaInk900, fontWeight = FontWeight.Medium)
            val statusText = when (method.verificationStatus) {
                PayoutMethodVerification.Unverified -> "Will be verified on your first payout."
                PayoutMethodVerification.Verified -> "Verified. Ready to receive payouts."
                PayoutMethodVerification.Invalid -> "Last payout failed — re-enter or pick a different method."
            }
            val tint = when (method.verificationStatus) {
                PayoutMethodVerification.Invalid -> SevaDanger500
                else -> SevaInk500
            }
            Text(statusText, fontSize = 12.sp, color = tint)
        }
    }
}

@Composable
private fun ModeToggle(
    selected: PayoutMethodKind,
    onSelect: (PayoutMethodKind) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(44.dp)
            .clip(RoundedCornerShape(10.dp))
            .border(width = 1.dp, color = BorderDefault, shape = RoundedCornerShape(10.dp)),
    ) {
        TogglePill(
            label = "UPI",
            icon = Icons.Outlined.AccountBalanceWallet,
            selected = selected == PayoutMethodKind.Upi,
            onClick = { onSelect(PayoutMethodKind.Upi) },
            modifier = Modifier.weight(1f),
        )
        TogglePill(
            label = "Bank",
            icon = Icons.Outlined.AccountBalance,
            selected = selected == PayoutMethodKind.Bank,
            onClick = { onSelect(PayoutMethodKind.Bank) },
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun TogglePill(
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxHeight()
            .clickable(onClick = onClick)
            .background(if (selected) SevaGreen50 else PaperDefault),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = if (selected) SevaGreen700 else SevaInk500,
            modifier = Modifier.size(16.dp),
        )
        Spacer(Modifier.size(6.dp))
        Text(
            label,
            fontSize = 14.sp,
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Medium,
            color = if (selected) SevaGreen700 else SevaInk500,
        )
    }
}

@Composable
private fun UpiForm(
    vpa: String,
    vpaError: String?,
    holderName: String,
    saving: Boolean,
    onVpaChange: (String) -> Unit,
    onHolderChange: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        EsField(
            value = vpa,
            onChange = onVpaChange,
            label = "UPI ID (VPA)",
            placeholder = "name@oksbi",
            hint = "Same as the UPI ID you'd put on a payment request.",
            error = vpaError,
            type = EsFieldType.Text,
            enabled = !saving,
        )
        EsField(
            value = holderName,
            onChange = onHolderChange,
            label = "Name on UPI (optional)",
            placeholder = "Your name as it appears in your bank's UPI app",
            type = EsFieldType.Text,
            enabled = !saving,
        )
    }
}

@Composable
private fun BankForm(
    accountHolder: String,
    ifsc: String,
    accountNumber: String,
    accountNumberConfirm: String,
    bankName: String,
    bankError: String?,
    saving: Boolean,
    onHolderChange: (String) -> Unit,
    onIfscChange: (String) -> Unit,
    onAccountChange: (String) -> Unit,
    onAccountConfirmChange: (String) -> Unit,
    onBankNameChange: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        EsField(
            value = accountHolder,
            onChange = onHolderChange,
            label = "Account holder name",
            placeholder = "Name on the bank account",
            enabled = !saving,
        )
        EsField(
            value = ifsc,
            onChange = onIfscChange,
            label = "IFSC code",
            placeholder = "SBIN0001234",
            hint = "Look at the front of your cheque book or net-banking dashboard.",
            enabled = !saving,
        )
        EsField(
            value = accountNumber,
            onChange = onAccountChange,
            label = "Account number",
            placeholder = "9 to 18 digits",
            type = EsFieldType.Number,
            enabled = !saving,
        )
        EsField(
            value = accountNumberConfirm,
            onChange = onAccountConfirmChange,
            label = "Re-type account number",
            type = EsFieldType.Number,
            enabled = !saving,
        )
        EsField(
            value = bankName,
            onChange = onBankNameChange,
            label = "Bank name (optional)",
            placeholder = "State Bank of India",
            enabled = !saving,
        )
        if (bankError != null) {
            Text(bankError, fontSize = 13.sp, color = SevaDanger500)
        }
    }
}

@Composable
private fun InfoNote() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(PaperDefault)
            .border(width = 1.dp, color = BorderDefault, shape = RoundedCornerShape(10.dp))
            .padding(12.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = Icons.Outlined.Info,
            contentDescription = null,
            tint = SevaInk500,
            modifier = Modifier.size(18.dp),
        )
        Column {
            Text(
                stringResource(R.string.payout_method_how_it_works_title),
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = SevaInk900,
            )
            Text(
                stringResource(R.string.payout_method_how_it_works_body),
                fontSize = 12.sp,
                color = SevaInk500,
            )
        }
    }
}
