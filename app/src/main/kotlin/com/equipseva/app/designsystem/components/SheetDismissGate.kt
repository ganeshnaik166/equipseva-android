package com.equipseva.app.designsystem.components

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SheetValue

/**
 * `confirmValueChange` policy for a [androidx.compose.material3.ModalBottomSheet]
 * whose action cannot be interrupted once it is in flight.
 *
 * Refusing the callback (`onDismissRequest = { if (!busy) onDismiss() }`) does
 * NOT keep such a sheet open: the drag gesture still animates it to
 * [SheetValue.Hidden] and Material fires the request exactly once. The
 * composable then stays in composition at `Hidden`, where the dialog window is
 * still full-screen but the scrim is invisible and its tap handler disabled —
 * the screen looks idle while swallowing every touch until the user presses
 * Back. Any error the action wanted to show (a wrong re-auth password, a
 * missing rejection reason) is rendered behind that hidden sheet and never
 * seen.
 *
 * So the gesture itself has to be refused while the action runs. Every other
 * target — expanding, or hiding once the action has finished — is allowed, so
 * the sheet still closes normally the moment `busy` goes false.
 */
@OptIn(ExperimentalMaterial3Api::class)
internal fun sheetDismissAllowed(target: SheetValue, busy: Boolean): Boolean =
    target != SheetValue.Hidden || !busy
