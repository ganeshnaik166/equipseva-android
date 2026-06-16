import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Code Red by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; opened: number; resolved: number; timed_out: number };

export default async function CodeRedByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_code_red_by_month");
  if (error) throw new Error(`founder_code_red_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "o", header: "Opened", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.opened)}</span> },
    { key: "r", header: "Resolved", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.resolved)}</span> },
    { key: "t", header: "Timed-out",
      render: (r) => <span className={`text-xs tabular-nums ${r.timed_out > 0 ? "text-[var(--color-danger)]" : "text-[var(--color-muted)]"}`}>{formatNumber(r.timed_out)}</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Code Red by month</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month trend</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No Code Red activity." />
    </div>
  );
}
