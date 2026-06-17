import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Code Red cumulative — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; opened: number; cum_opened: number; resolved: number; cum_resolved: number };

export default async function CodeRedCumulativePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_code_red_cumulative");
  if (error) throw new Error(`founder_code_red_cumulative: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "o", header: "Opened (m)", render: (r) => <span className="text-xs tabular-nums">+{formatNumber(r.opened)}</span> },
    { key: "co", header: "Cum opened", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cum_opened)}</span> },
    { key: "r", header: "Resolved (m)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">+{formatNumber(r.resolved)}</span> },
    { key: "cr", header: "Cum resolved", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cum_resolved)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Code Red cumulative</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month cumulative Code Red requests</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No Code Red activity." />
    </div>
  );
}
