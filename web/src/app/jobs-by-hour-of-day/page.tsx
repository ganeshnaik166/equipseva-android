import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs by hour of day — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { hour_ist: number; jobs: number };

export default async function JobsByHourOfDayPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_by_hour_of_day");
  if (error) throw new Error(`founder_jobs_by_hour_of_day: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const max = Math.max(1, ...rows.map((r) => r.jobs));
  const cols: Column<Row>[] = [
    { key: "h", header: "Hour (IST)", render: (r) => <span className="text-xs font-mono">{String(r.hour_ist).padStart(2, "0")}:00</span> },
    { key: "j", header: "Jobs (30d)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs)}</span> },
    { key: "b", header: "",
      render: (r) => (
        <div className="h-2 w-32 rounded bg-[var(--color-bg-subtle)]">
          <div className="h-2 rounded bg-[var(--color-fg)]" style={{ width: `${(r.jobs / max) * 100}%` }} />
        </div>
      )
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs by hour of day</h1>
        <span className="text-xs text-[var(--color-muted)]">last 30d · IST · grouped by created_at hour</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.hour_ist)} emptyMessage="No jobs." />
    </div>
  );
}
