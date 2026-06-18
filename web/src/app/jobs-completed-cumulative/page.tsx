import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs completed cumulative — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  month_ist: string;
  monthly_done: number;
  cumulative_done: number;
};

export default async function JobsCompletedCumulativePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_completed_cumulative");
  if (error) throw new Error(`founder_jobs_completed_cumulative: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const grand = rows.length > 0 ? Number(rows[0].cumulative_done ?? 0) : 0;
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "d", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.monthly_done)}</span> },
    { key: "c", header: "Cumulative", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cumulative_done)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs completed cumulative (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          12mo cumulative completed-job count · grand total: <span className="font-mono tabular-nums">{formatNumber(grand)}</span>
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No completed jobs in last 12 months." />
    </div>
  );
}
