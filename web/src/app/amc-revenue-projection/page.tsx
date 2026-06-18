import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatRupees } from "@/lib/format";

export const metadata = { title: "AMC revenue projection — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  metric: string;
  metric_order: number;
  value_inr: number;
  notes: string;
};

export default async function AmcRevenueProjectionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_revenue_projection");
  if (error) throw new Error(`founder_amc_revenue_projection: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Metric", render: (r) => (
      <span className={`text-xs ${r.metric_order >= 6 ? "font-semibold" : ""} ${r.metric_order === 5 ? "text-[var(--color-ok)]" : r.metric_order >= 2 && r.metric_order <= 4 ? "text-[var(--color-warn)]" : ""}`}>{r.metric}</span>
    ) },
    { key: "v", header: "INR", render: (r) => <span className={`text-xs tabular-nums ${r.metric_order >= 6 ? "font-semibold" : ""}`}>{formatRupees(Number(r.value_inr))}</span> },
    { key: "n", header: "Notes", render: (r) => <span className="text-xs text-[var(--color-muted)]">{r.notes}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC revenue projection</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Current MRR · expiring windows · new MRR · 30d + 90d projections (no-renewal worst case)
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.metric_order)} emptyMessage="No AMC contracts." />
    </div>
  );
}
