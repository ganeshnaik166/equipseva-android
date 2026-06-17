import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Supervised cumulative — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; assigned: number; cum_assigned: number; successful: number; cum_successful: number };

export default async function SupervisedCumulativePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_supervised_cumulative");
  if (error) throw new Error(`founder_supervised_cumulative: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "a", header: "Assigned (m)", render: (r) => <span className="text-xs tabular-nums">+{formatNumber(r.assigned)}</span> },
    { key: "ca", header: "Cum assigned", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cum_assigned)}</span> },
    { key: "s", header: "Successful (m)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">+{formatNumber(r.successful)}</span> },
    { key: "cs", header: "Cum successful", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cum_successful)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Supervised cumulative</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month cumulative supervised assignments</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No supervised activity." />
    </div>
  );
}
