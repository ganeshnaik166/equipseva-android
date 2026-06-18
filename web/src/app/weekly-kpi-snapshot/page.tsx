import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Weekly KPI snapshot — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  signups: number;
  jobs_posted: number;
  jobs_done: number;
  bids: number;
  payouts_done: number;
  new_amcs: number;
  disputes: number;
  code_red: number;
};

export default async function WeeklyKpiSnapshotPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_weekly_kpi_snapshot");
  if (error) throw new Error(`founder_weekly_kpi_snapshot: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "s", header: "Signups", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.signups)}</span> },
    { key: "jp", header: "Jobs posted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_posted)}</span> },
    { key: "jd", header: "Jobs done", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.jobs_done)}</span> },
    { key: "b", header: "Bids", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.bids)}</span> },
    { key: "p", header: "Payouts", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.payouts_done)}</span> },
    { key: "a", header: "New AMCs", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.new_amcs)}</span> },
    { key: "d", header: "Disputes", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.disputes)}</span> },
    { key: "c", header: "Code Red", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.code_red)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Weekly KPI snapshot (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">8 raw KPIs per week · time series (paired with /pulse-extended for WoW deltas)</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No data." />
    </div>
  );
}
