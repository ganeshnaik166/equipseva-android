package com.equipseva.app.features.catalog

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.outlined.Inbox
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.equipseva.app.core.data.catalog.CatalogReferenceRepository
import com.equipseva.app.designsystem.components.ESBackTopBar
import com.equipseva.app.designsystem.components.EmptyStateView
import com.equipseva.app.designsystem.theme.BrandGreen
import com.equipseva.app.designsystem.theme.Ink500
import com.equipseva.app.designsystem.theme.Ink700
import com.equipseva.app.designsystem.theme.Ink900
import com.equipseva.app.designsystem.theme.Spacing
import com.equipseva.app.designsystem.theme.Surface0
import com.equipseva.app.designsystem.theme.Surface200
import com.equipseva.app.designsystem.theme.Surface50
import java.text.NumberFormat
import java.util.Locale

@Composable
fun CatalogDetailScreen(
    onBack: () -> Unit,
    onRequestQuote: (CatalogReferenceRepository.Item) -> Unit,
    viewModel: CatalogDetailViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current

    Scaffold(
        topBar = { ESBackTopBar(title = "Catalogue item", onBack = onBack) },
        bottomBar = {
            state.item?.let { item ->
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Surface0)
                        .border(1.dp, Surface200)
                        .padding(Spacing.md),
                ) {
                    Button(
                        onClick = { onRequestQuote(item) },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Request a quote", fontWeight = FontWeight.Bold)
                    }
                }
            }
        },
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding).background(Surface50)) {
            when {
                state.loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
                state.error != null -> EmptyStateView(
                    icon = Icons.Outlined.Inbox,
                    title = "Couldn't load",
                    subtitle = state.error,
                )
                state.item == null -> EmptyStateView(
                    icon = Icons.Outlined.Inbox,
                    title = "Not found",
                    subtitle = "This catalogue item is missing.",
                )
                else -> DetailBody(
                    item = state.item!!,
                    onOpenImage = {
                        state.item!!.imageSearchUrl?.let { url ->
                            runCatching {
                                context.startActivity(
                                    android.content.Intent(
                                        android.content.Intent.ACTION_VIEW,
                                        android.net.Uri.parse(url),
                                    ),
                                )
                            }
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun DetailBody(
    item: CatalogReferenceRepository.Item,
    onOpenImage: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(Spacing.sm),
    ) {
        // Hero card
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(14.dp))
                .background(Surface0)
                .border(1.dp, Surface200, RoundedCornerShape(14.dp))
                .padding(Spacing.md),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(item.itemName, fontWeight = FontWeight.Bold, color = Ink900, fontSize = 18.sp)
            val brandLine = listOfNotNull(item.brand, item.model).joinToString(" · ")
            if (brandLine.isNotBlank()) {
                Text(brandLine, color = Ink700, fontSize = 14.sp)
            }
            Text(
                listOfNotNull(item.category, item.subCategory, item.type)
                    .joinToString(" · "),
                color = Ink500,
                fontSize = 12.sp,
            )
            Text(
                formatPriceRange(item.priceInrLow, item.priceInrHigh, item.market),
                color = BrandGreen,
                fontWeight = FontWeight.Bold,
                fontSize = 15.sp,
            )
            if (!item.imageSearchUrl.isNullOrBlank()) {
                OutlinedButton(onClick = onOpenImage, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Filled.Image, contentDescription = null)
                    Text("  Open Google Images for this product")
                }
            }
        }

        // Specs
        if (!item.keySpecifications.isNullOrBlank()) {
            DetailSection(title = "Key specifications") {
                Text(item.keySpecifications, color = Ink900, fontSize = 14.sp, lineHeight = 20.sp)
            }
        }

        // Notes
        if (!item.notes.isNullOrBlank()) {
            DetailSection(title = "Notes") {
                Text(item.notes, color = Ink700, fontSize = 13.sp, lineHeight = 18.sp)
            }
        }

        // Source badge
        DetailSection(title = "Source") {
            val sourceLine = when (item.source) {
                "curated" -> "Curated India working-set entry"
                "gudid" -> "FDA AccessGUDID registered device" +
                    (item.udi?.let { " · UDI: $it" } ?: "")
                else -> item.source
            }
            Text(sourceLine, color = Ink700, fontSize = 13.sp)
            Text("Market: ${item.market}", color = Ink500, fontSize = 12.sp)
        }

        Spacer(Modifier.height(80.dp)) // breathing room above bottom CTA
    }
}

@Composable
private fun DetailSection(title: String, content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Surface0)
            .border(1.dp, Surface200, RoundedCornerShape(14.dp))
            .padding(Spacing.md),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(title, color = Ink500, fontSize = 11.sp, fontWeight = FontWeight.Bold)
        content()
    }
}

private fun formatPriceRange(low: Long?, high: Long?, market: String): String {
    if (low == null && high == null) {
        return if (market == "India") "Price on request" else "Reference (no price)"
    }
    val nf = NumberFormat.getInstance(Locale("en", "IN"))
    val lo = low?.let { "₹${nf.format(it)}" } ?: "?"
    val hi = high?.let { "₹${nf.format(it)}" } ?: "?"
    return if (lo == hi) lo else "$lo – $hi"
}
