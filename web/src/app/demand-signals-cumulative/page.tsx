import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Demand signals cumulative — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; signals: number; cum_signals: number; resolved: number; cum_resolved: number };

export default async function DemandSignalsCumulativePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_demand_signals_cumulative");
  if (error) throw new Error(`founder_demand_signals_cumulative: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "s", header: "Signals (m)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">+{formatNumber(r.signals)}</span> },
    { key: "cs", header: "Cum signals", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cum_signals)}</span> },
    { key: "r", header: "Resolved (m)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">+{formatNumber(r.resolved)}</span> },
    { key: "cr", header: "Cum resolved", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cum_resolved)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Demand signals cumulative</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month cumulative spare-part demand</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No demand signals." />
    </div>
  );
}
