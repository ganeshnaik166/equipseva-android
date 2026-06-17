import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Demand by city — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { city: string; signals_90d: number; reporters: number; distinct_skus: number };

export default async function DemandByCityPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_demand_by_city");
  if (error) throw new Error(`founder_demand_by_city: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "c", header: "City", render: (r) => <span className="text-xs">{r.city}</span> },
    { key: "s", header: "Signals", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.signals_90d)}</span> },
    { key: "r", header: "Reporters", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.reporters)}</span> },
    { key: "k", header: "Distinct SKUs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_skus)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Demand by city (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 cities by 90d demand signals</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.city} emptyMessage="No demand signals." />
    </div>
  );
}
