import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs by day of week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { dow_num: number; dow_label: string; jobs: number };

export default async function JobsByDayOfWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_by_day_of_week");
  if (error) throw new Error(`founder_jobs_by_day_of_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const max = Math.max(1, ...rows.map((r) => r.jobs));
  const cols: Column<Row>[] = [
    { key: "d", header: "Day", render: (r) => <span className="text-xs font-semibold">{r.dow_label}</span> },
    { key: "j", header: "Jobs (90d)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs)}</span> },
    { key: "b", header: "",
      render: (r) => (
        <div className="h-2 w-48 rounded bg-[var(--color-bg-subtle)]">
          <div className="h-2 rounded bg-[var(--color-fg)]" style={{ width: `${(r.jobs / max) * 100}%` }} />
        </div>
      )
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs by day of week</h1>
        <span className="text-xs text-[var(--color-muted)]">last 90d · IST · grouped by weekday</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.dow_label} emptyMessage="No jobs." />
    </div>
  );
}
