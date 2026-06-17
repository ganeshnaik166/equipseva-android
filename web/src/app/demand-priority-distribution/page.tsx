import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Demand priority distribution — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { priority: string; cnt: number; resolved: number; open: number };

export default async function DemandPriorityDistributionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_demand_priority_distribution");
  if (error) throw new Error(`founder_demand_priority_distribution: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "p", header: "Priority", render: (r) => <span className="text-xs font-semibold">{r.priority}</span> },
    { key: "c", header: "Total (90d)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "r", header: "Resolved", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.resolved)}</span> },
    { key: "o", header: "Open", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.open)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Demand priority distribution</h1>
        <span className="text-xs text-[var(--color-muted)]">Spare-part demand signals by founder priority · 90d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.priority} emptyMessage="No demand signals." />
    </div>
  );
}
