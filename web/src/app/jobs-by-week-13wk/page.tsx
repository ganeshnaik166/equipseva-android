import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs by week 13wk — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  posted: number;
  completed: number;
  cancelled: number;
  bids: number;
};

export default async function JobsByWeek13wkPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_by_week_13wk");
  if (error) throw new Error(`founder_jobs_by_week_13wk: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalPosted = rows.reduce((a, r) => a + (r.posted ?? 0), 0);
  const totalDone = rows.reduce((a, r) => a + (r.completed ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "p", header: "Posted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.posted)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.completed)}</span> },
    { key: "x", header: "Cancelled", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.cancelled)}</span> },
    { key: "b", header: "Bids", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.bids)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          13wk: <span className="font-mono tabular-nums">{formatNumber(totalPosted)}</span> posted · <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatNumber(totalDone)}</span> done
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No jobs in last 13 weeks." />
    </div>
  );
}
