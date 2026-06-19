import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Catalog coverage snapshot — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  metric: string;
  value_num: number | null;
  value_text: string | null;
};

const LABELS: Record<string, string> = {
  total_devices: "Devices indexed (catalog_devices)",
  devices_missing_image: "Devices missing image_url",
  devices_missing_description: "Devices missing description text",
  devices_ingested_last_7d: "Devices ingested in last 7 days",
  devices_ingested_last_30d: "Devices ingested in last 30 days",
  devices_newest_at: "Newest device ingested at (IST)",
  devices_oldest_at: "Oldest device ingested at (IST)",
  total_brands: "Brands indexed (catalog_brands)",
  brands_missing_logo: "Brands missing logo_url",
  brands_missing_country: "Brands missing country",
  brands_ingested_last_30d: "Brands ingested in last 30 days",
  brands_newest_at: "Newest brand ingested at (IST)",
  total_ref_items: "Curated reference SKUs (catalog_reference_items)",
  ref_missing_specs: "Reference SKUs missing key_specifications",
  ref_missing_brand: "Reference SKUs missing brand",
  ref_missing_model: "Reference SKUs missing model",
  ref_missing_price: "Reference SKUs missing INR price band",
};

export default async function CatalogCoverageSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_catalog_coverage_snapshot_summary");
  if (error) throw new Error(`founder_catalog_coverage_snapshot_summary: ${error.message}`);
  const rows = (data ?? []) as Row[];

  const byKey = new Map(rows.map((r) => [r.metric, r]));
  const totalDevices = Number(byKey.get("total_devices")?.value_num ?? 0);
  const devicesMissingImage = Number(byKey.get("devices_missing_image")?.value_num ?? 0);
  const totalRef = Number(byKey.get("total_ref_items")?.value_num ?? 0);
  const refMissingSpecs = Number(byKey.get("ref_missing_specs")?.value_num ?? 0);

  const imgGapPct = totalDevices > 0
    ? ((devicesMissingImage / totalDevices) * 100).toFixed(1)
    : "0.0";
  const specsGapPct = totalRef > 0
    ? ((refMissingSpecs / totalRef) * 100).toFixed(1)
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
          {r.value_num !== null ? formatNumber(Number(r.value_num)) : (r.value_text ?? "—")}
        </span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Catalog coverage snapshot</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {`Devices ${formatNumber(totalDevices)} · image-gap ${imgGapPct}% · ref SKUs ${formatNumber(totalRef)} · specs-gap ${specsGapPct}%`}
        </span>
      </header>
      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.metric}
        emptyMessage="No catalog data."
      />
      <p className="text-xs text-[var(--color-muted)]">
        Snapshot of catalog quality gaps at this instant: missing images on OpenFDA devices, missing specs/brand/model/price on the curated India reference catalog, plus freshness windows (last 7d/30d ingest counts + newest/oldest timestamps). Complements /catalog-coverage-summary, which reports totals and tag coverage. Gaps here drive the next ingest run.
      </p>
    </div>
  );
}
