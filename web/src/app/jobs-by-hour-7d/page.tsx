import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs by hour 7d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  hour_ist: number;
  jobs_posted: number;
  bids_placed: number;
  jobs_completed: number;
};

export default async function JobsByHour7dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_by_hour_7d");
  if (error) throw new Error(`founder_jobs_by_hour_7d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "h", header: "Hour IST", render: (r) => <span className="text-xs tabular-nums font-medium">{String(r.hour_ist).padStart(2, "0")}:00</span> },
    { key: "p", header: "Posted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_posted)}</span> },
    { key: "b", header: "Bids", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.bids_placed)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.jobs_completed)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs by hour (7d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          24-hour IST distribution · marketplace temporal pattern · informs cron + notification scheduling
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.hour_ist)} emptyMessage="No marketplace activity in last 7 days." />
    </div>
  );
}
