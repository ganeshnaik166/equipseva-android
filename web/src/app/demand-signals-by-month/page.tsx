import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Demand signals by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; signals: number; distinct_skus: number; resolved: number };

export default async function DemandSignalsByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_demand_signals_by_month");
  if (error) throw new Error(`founder_demand_signals_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "s", header: "Signals", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.signals)}</span> },
    { key: "k", header: "Distinct SKUs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_skus)}</span> },
    { key: "r", header: "Resolved", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.resolved)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Demand signals by month</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month trend · IST</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No demand signals." />
    </div>
  );
}
