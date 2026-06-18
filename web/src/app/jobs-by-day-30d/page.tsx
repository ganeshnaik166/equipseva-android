import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs by day 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  day_ist: string;
  posted: number;
  completed: number;
  cancelled: number;
  bids: number;
};

export default async function JobsByDay30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_by_day_30d");
  if (error) throw new Error(`founder_jobs_by_day_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalPosted = rows.reduce((a, r) => a + (r.posted ?? 0), 0);
  const totalDone = rows.reduce((a, r) => a + (r.completed ?? 0), 0);
  const totalBids = rows.reduce((a, r) => a + (r.bids ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Day", render: (r) => <span className="text-xs tabular-nums">{r.day_ist}</span> },
    { key: "p", header: "Posted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.posted)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.completed)}</span> },
    { key: "x", header: "Cancelled", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.cancelled)}</span> },
    { key: "b", header: "Bids", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.bids)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs by day (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          30d: <span className="font-mono tabular-nums">{formatNumber(totalPosted)}</span> posted · <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatNumber(totalDone)}</span> done · <span className="font-mono tabular-nums">{formatNumber(totalBids)}</span> bids
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No jobs in last 30 days." />
    </div>
  );
}
