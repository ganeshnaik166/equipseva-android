import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Demand by model — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { brand: string; model: string; signals_90d: number; resolved_90d: number };

export default async function DemandByModelPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_demand_by_model");
  if (error) throw new Error(`founder_demand_by_model: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "b", header: "Brand", render: (r) => <span className="text-xs">{r.brand}</span> },
    { key: "m", header: "Model", render: (r) => <span className="text-xs">{r.model}</span> },
    { key: "s", header: "Signals (90d)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.signals_90d)}</span> },
    { key: "r", header: "Resolved", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.resolved_90d)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Demand by model</h1>
        <span className="text-xs text-[var(--color-muted)]">top 50 (brand, model) by 90d demand</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => `${r.brand}|${r.model}`} emptyMessage="No demand signals." />
    </div>
  );
}
