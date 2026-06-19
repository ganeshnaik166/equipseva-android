import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Catalog coverage summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  metric: string;
  value_num: number | null;
  value_text: string | null;
};

const LABELS: Record<string, string> = {
  total_devices: "Devices indexed (catalog_devices)",
  devices_with_brand: "Devices linked to brand",
  devices_without_brand: "Devices missing brand link",
  devices_with_category: "Devices tagged with category",
  devices_without_category: "Devices untagged (no category)",
  devices_with_image: "Devices with image_url",
  distinct_manufacturers: "Distinct manufacturer strings",
  total_brands: "Brands in catalog_brands",
  active_brands: "Brands with manufacturer_count > 0",
  total_ref_items: "Reference SKUs (curated India catalog)",
  ref_items_priced: "Reference SKUs with INR price band",
  distinct_ref_categories: "Distinct reference categories",
  distinct_ref_brands: "Distinct reference brands",
  taxonomy_rows: "Taxonomy class rows",
  taxonomy_allowed_v04: "Taxonomy classes allowed in v0.4",
  active_equipment_categories: "Active equipment categories",
};

export default async function CatalogCoverageSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_catalog_coverage_summary");
  if (error) throw new Error(`founder_catalog_coverage_summary: ${error.message}`);
  const rows = (data ?? []) as Row[];

  const byKey = new Map(rows.map((r) => [r.metric, r]));
  const totalDevices = Number(byKey.get("total_devices")?.value_num ?? 0);
  const taggedDevices = Number(byKey.get("devices_with_category")?.value_num ?? 0);
  const brandedDevices = Number(byKey.get("devices_with_brand")?.value_num ?? 0);

  const tagCoveragePct = totalDevices > 0
    ? ((taggedDevices / totalDevices) * 100).toFixed(1)
    : "0.0";
  const brandCoveragePct = totalDevices > 0
    ? ((brandedDevices / totalDevices) * 100).toFixed(1)
    : "0.0";

  const cols: Column<Row>[] = [
    {
      key: "m",
      header: "Metric",
      render: (r) => (
        <span className="text-xs font-medium">{LABELS[r.metric] ?? r.metric}</span>
      ),
    },
    {
      key: "v",
      header: "Value",
      render: (r) => (
        <span className="text-xs tabular-nums">
          {r.value_num !== null ? formatNumber(Number(r.value_num)) : (r.value_text ?? `${"—"}`)}
        </span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Catalog coverage summary</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {`Devices ${formatNumber(totalDevices)} · category-tagged ${tagCoveragePct}% · brand-linked ${brandCoveragePct}% · search-fill-rate signal`}
        </span>
      </header>
      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.metric}
        emptyMessage="No catalog data."
      />
      <p className="text-xs text-[var(--color-muted)]">
        {`Coverage = fraction of indexed SKUs resolvable by category, brand, and image. Untagged devices fail downstream filter chips and supplier matching. Reference items are the curated India catalog (price bands ${"≥"} 0); openfda devices fill the long tail.`}
      </p>
    </div>
  );
}