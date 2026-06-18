import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs by month × status — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; posted: number; completed: number; cancelled: number; in_flight: number };

export default async function JobsByMonthByStatusPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_by_month_by_status");
  if (error) throw new Error(`founder_jobs_by_month_by_status: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "p", header: "Posted", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.posted)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.completed)}</span> },
    { key: "x", header: "Cancelled", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.cancelled)}</span> },
    { key: "f", header: "In flight", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.in_flight)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs by month × status (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">Keyed by creation month · cross-tab of repair_jobs.status</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No jobs." />
    </div>
  );
}
